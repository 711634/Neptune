import Foundation
import Combine

private typealias ConcurrencyTask = _Concurrency.Task

actor AgentOrchestrator: ObservableObject {
    @MainActor @Published var currentProject: ProjectContext?
    @MainActor @Published var agents: [String: Agent] = [:]
    @MainActor @Published var isRunning: Bool = false
    @MainActor @Published var statusMessage: String = "Ready"

    private let processManager: ProcessManager
    private let stateManager: StateManager
    private let skillRegistry: SkillRegistry
    private let claudeRunner: ClaudeCodeRunner

    private var orchestrationTask: ConcurrencyTask<Void, Never>?
    private var agentUpdateTask: ConcurrencyTask<Void, Never>?

    init(
        processManager: ProcessManager,
        stateManager: StateManager,
        skillRegistry: SkillRegistry,
        claudeRunner: ClaudeCodeRunner
    ) {
        self.processManager = processManager
        self.stateManager = stateManager
        self.skillRegistry = skillRegistry
        self.claudeRunner = claudeRunner
    }

    deinit {
        orchestrationTask?.cancel()
        agentUpdateTask?.cancel()
    }

    // MARK: - Project Management

    func createProject(
        name: String,
        description: String,
        goal: String,
        workDir: URL? = nil
    ) async throws -> ProjectContext {
        let projectId = UUID().uuidString
        let projectType = ProjectType.detect(from: workDir ?? URL(fileURLWithPath: NSHomeDirectory()))
        let workspace = workDir ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("neptune-\(projectId)")

        // Create workspace
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)

        var project = ProjectContext(
            id: projectId,
            name: name,
            description: description,
            goal: goal,
            projectType: projectType,
            workspaceDir: workspace
        )

        // Load relevant skills
        project.skillPacks = skillRegistry.loadSkillPack(for: projectType).map { $0.id }

        // Create initial agents
        project.agents = createInitialAgents(for: projectId, workDir: workspace)

        // Create initial task graph (simple linear flow)
        project.taskGraph = createInitialTaskGraph(for: projectType, goal: goal)

        // Save project
        try await stateManager.saveProject(project)

        await MainActor.run {
            self.currentProject = project
            self.agents = project.agents
        }

        return project
    }

    func startProject(_ project: ProjectContext) async {
        await MainActor.run {
            self.currentProject = project
            self.agents = project.agents
            self.isRunning = true
            self.statusMessage = "Starting project: \(project.name)"
        }

        // Start the orchestration loop
        orchestrationTask = ConcurrencyTask {
            await self.runOrchestrationLoop(projectId: project.id)
        }
    }

    func pauseProject() async {
        orchestrationTask?.cancel()

        await MainActor.run {
            self.isRunning = false
            self.statusMessage = "Project paused"
        }
    }

    func resumeProject() async {
        guard let project = await currentProject else { return }

        await MainActor.run {
            self.isRunning = true
            self.statusMessage = "Project resumed"
        }

        orchestrationTask = ConcurrencyTask {
            await self.runOrchestrationLoop(projectId: project.id)
        }
    }

    func stopProject() async {
        orchestrationTask?.cancel()
        await processManager.killAllSessions()

        await MainActor.run {
            self.isRunning = false
            self.statusMessage = "Project stopped"
        }
    }

    // MARK: - Agent Management

    func assignTask(taskId: String, to agentId: String, projectId: String) async throws {
        guard var agent = await MainActor.run(body: { self.agents[agentId] }) else {
            throw OrchestratorError.agentNotFound(agentId)
        }

        agent.currentTaskId = taskId
        agent.status = .planning

        try await stateManager.saveAgentState(agent, projectId: projectId)

        await MainActor.run {
            self.agents[agentId] = agent
        }
    }

    func updateAgentStatus(_ agentId: String, to status: AgentStatus, projectId: String) async throws {
        guard var agent = await MainActor.run(body: { self.agents[agentId] }) else {
            throw OrchestratorError.agentNotFound(agentId)
        }

        agent.status = status
        agent.updatedAt = Date()

        try await stateManager.saveAgentState(agent, projectId: projectId)

        await MainActor.run {
            self.agents[agentId] = agent
        }
    }

    // MARK: - Main Orchestration Loop

    private func runOrchestrationLoop(projectId: String) async {
        guard let project = await currentProject else { return }

        var taskGraph = project.taskGraph
        var agents = await MainActor.run(body: { self.agents })

        while !ConcurrencyTask.isCancelled {
            // Get next ready tasks
            let readyTasks = taskGraph.getReadyTasks()

            if readyTasks.isEmpty {
                // Check if all tasks are completed
                let allTasks = taskGraph.tasks.values
                let allCompleted = allTasks.allSatisfy { $0.status == .completed }

                if allCompleted {
                    await MainActor.run {
                        self.statusMessage = "Project complete!"
                        self.isRunning = false
                    }
                    break
                }

                // Wait a bit before checking again
                try? await ConcurrencyTask.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
                continue
            }

            // Assign tasks to available agents
            for task in readyTasks {
                guard !ConcurrencyTask.isCancelled else { break }

                // Find agent for this role
                let availableAgents = agents.values.filter { agent in
                    agent.role == task.roleRequired && agent.isRunnableState && agent.currentTaskId == nil
                }

                guard let agent = availableAgents.first else {
                    continue  // Wait for an agent to become available
                }

                // Run the task
                await runTask(task, for: agent, in: projectId, taskGraph: &taskGraph, agents: &agents)
            }

            // Save progress periodically
            if !ConcurrencyTask.isCancelled {
                try? await stateManager.saveTaskGraph(taskGraph, projectId: projectId)
                try? await ConcurrencyTask.sleep(nanoseconds: 1_000_000_000)  // 1 second
            }
        }
    }

    private func runTask(
        _ task: Task,
        for agent: Agent,
        in projectId: String,
        taskGraph: inout TaskGraph,
        agents: inout [String: Agent]
    ) async {
        await MainActor.run {
            self.statusMessage = "Agent \(agent.name) starting task: \(task.description)"
        }

        var updatedAgent = agent
        updatedAgent.currentTaskId = task.id
        updatedAgent.status = .coding
        updatedAgent.startedAt = Date()

        agents[agent.id] = updatedAgent

        do {
            try await updateAgentStatus(agent.id, to: .coding, projectId: projectId)

            // Get skill prompt for this task
            let skillId = skillRegistry.getSkillsForRole(agent.role).first?.id ?? "generic:fallback"
            let skillPrompt = skillRegistry.getSkillPrompt(skillId: skillId, role: agent.role)

            // Run the task through Claude
            let output = try await claudeRunner.runTask(
                agentId: agent.id,
                role: agent.role,
                projectId: projectId,
                task: task,
                skillPrompt: skillPrompt,
                workDir: stateManager.workspaceDirectory(for: projectId)
            )

            // Mark task as completed
            try taskGraph.markCompleted(taskId: task.id, output: output.output ?? output.summary)

            updatedAgent.status = output.status == "success" ? .success : .failed
            updatedAgent.lastOutput = output.summary
            updatedAgent.currentTaskId = nil

            agents[agent.id] = updatedAgent

            try await stateManager.saveTaskGraph(taskGraph, projectId: projectId)
            try await stateManager.saveAgentState(updatedAgent, projectId: projectId)

            await MainActor.run {
                self.statusMessage = "Agent \(agent.name) completed task: \(output.summary)"
                self.agents = agents
            }
        } catch {
            updatedAgent.status = .failed
            updatedAgent.errorMessage = error.localizedDescription
            updatedAgent.retryCount += 1

            agents[agent.id] = updatedAgent

            do {
                if updatedAgent.retryCount < updatedAgent.maxRetries {
                    // Mark task for retry
                    try taskGraph.markFailed(taskId: task.id, error: error.localizedDescription)
                } else {
                    // Mark task as failed permanently
                    try taskGraph.markFailed(taskId: task.id, error: "Max retries exceeded: \(error.localizedDescription)")
                }

                try await stateManager.saveTaskGraph(taskGraph, projectId: projectId)
                try await stateManager.saveAgentState(updatedAgent, projectId: projectId)
            } catch {
                // Silently fail to save, will retry next iteration
            }

            await MainActor.run {
                self.statusMessage = "Agent \(agent.name) failed: \(error.localizedDescription)"
                self.agents = agents
            }
        }
    }

    // MARK: - Helpers

    private func createInitialAgents(for projectId: String, workDir: URL) -> [String: Agent] {
        let roles: [AgentRole] = [.planning, .research, .coding, .review, .shipping]
        var agents: [String: Agent] = [:]

        for (index, role) in roles.enumerated() {
            let agentId = "\(projectId)-\(role.rawValue)"
            let agent = Agent(
                id: agentId,
                name: role.displayName,
                role: role,
                task: "Awaiting task",
                status: .idle,
                elapsedSeconds: 0,
                lastLog: "Ready",
                updatedAt: Date(),
                colorVariant: ColorVariant.all[index % ColorVariant.all.count],
                anchorHint: AnchorHint.allCases[index % AnchorHint.allCases.count],
                slotIndex: index,
                workingDirectory: workDir.path
            )

            agents[agentId] = agent
        }

        return agents
    }

    private func createInitialTaskGraph(for projectType: ProjectType, goal: String) -> TaskGraph {
        var graph = TaskGraph()

        let taskDescriptions: [(role: AgentRole, desc: String)] = [
            (.planning, "Create a detailed project plan and architecture for: \(goal)"),
            (.research, "Research technologies and best practices for: \(goal)"),
            (.coding, "Implement the project based on the plan"),
            (.review, "Review code quality, tests, and functionality"),
            (.shipping, "Prepare project for delivery")
        ]

        var previousTaskId: String?

        for (index, (role, desc)) in taskDescriptions.enumerated() {
            let taskId = "task-\(index)"
            var task = Task(
                id: taskId,
                description: desc,
                roleRequired: role,
                prompt: desc,
                acceptanceCriteria: ["Task completed to specification"]
            )

            if let prevId = previousTaskId {
                task.dependencies = [prevId]
            }

            try? graph.addTask(task)
            previousTaskId = taskId
        }

        return graph
    }
}

enum OrchestratorError: LocalizedError {
    case agentNotFound(String)
    case projectNotFound(String)
    case invalidState(String)

    var errorDescription: String? {
        switch self {
        case .agentNotFound(let id):
            return "Agent not found: \(id)"
        case .projectNotFound(let id):
            return "Project not found: \(id)"
        case .invalidState(let msg):
            return "Invalid state: \(msg)"
        }
    }
}
