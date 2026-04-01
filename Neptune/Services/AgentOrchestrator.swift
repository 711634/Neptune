import Foundation
import Combine
import os

private typealias ConcurrencyTask = _Concurrency.Task

/// Context for task execution including permissions, budgets, and cancellation
struct TaskExecutionContext: Sendable {
    let budgetTokens: Int
    let budgetUSD: Double
    let allowedWorkDirs: Set<String>
    let permissionMode: String  // "allow", "ask", "deny"
    let cancelledCheck: @Sendable () -> Bool
    let decisions: [String: Decision]

    struct Decision: Sendable, Codable {
        let toolName: String
        let decision: String  // "allow", "deny"
        let timestamp: Date
    }

    static func defaultContext(for task: Task, workDir: String) -> TaskExecutionContext {
        TaskExecutionContext(
            budgetTokens: 200_000,  // Default 200k token budget per task
            budgetUSD: Double.infinity,  // No USD limit initially
            allowedWorkDirs: [workDir],
            permissionMode: "allow",  // Default to permissive
            cancelledCheck: { false },
            decisions: [:]
        )
    }
}

actor AgentOrchestrator: ObservableObject {
    @MainActor @Published var currentProject: ProjectContext?
    @MainActor @Published var agents: [String: Agent] = [:]
    @MainActor @Published var isRunning: Bool = false
    @MainActor @Published var statusMessage: String = "Ready"

    private let processManager: ProcessManager
    private let stateManager: StateManager
    private let skillRegistry: SkillRegistry
    private let claudeRunner: ClaudeCodeRunner
    private let logger = os.Logger(subsystem: "com.neptune.orchestration", category: "AgentOrchestrator")

    // Centralized execution state for current project
    private var sessionState: SessionState?

    // Tool execution boundary with permission checking and telemetry
    private var toolExecutor: ToolExecutor?

    // File safety validator for scope enforcement
    private var safetyValidator: SafetyValidator?

    // Safety enforcement gate for runtime validation
    private var safetyEnforcementGate: SafetyEnforcementGate?

    // Permission enforcement gate
    private var permissionGate: PermissionGate?

    // Retry/recovery with circuit breaker
    private var retryableExecution: RetryableTaskExecution?

    // Delegation boundaries for multi-agent coordination
    private var delegationBoundary: DelegationBoundary?

    // Observability and telemetry (span-based tracing)
    private var executionObserver: ExecutionObserver?

    // Execution diagnostics observer (failure tracking and metrics)
    private var diagnosticsObserver: ExecutionDiagnosticsObserver?

    // Task batching for efficient delegation
    private var taskBatcher: TaskBatcher?

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

        // Initialize centralized session state for this project
        let tokenBudget = Int(ProcessInfo.processInfo.environment["NEPTUNE_TOKEN_BUDGET"].flatMap(Int.init) ?? Int.max)
        let costBudget = Double(ProcessInfo.processInfo.environment["NEPTUNE_COST_BUDGET"].flatMap(Double.init) ?? Double.infinity)
        let newSessionState = SessionState(tokenBudget: tokenBudget, usdBudget: costBudget)
        sessionState = newSessionState

        // Initialize execution guardrails (iteration/tool/time limits)
        let guardrailMode = ProcessInfo.processInfo.environment["NEPTUNE_GUARDRAIL_MODE"] ?? "default"
        let guardrailConfig: GuardrailConfig
        switch guardrailMode {
        case "conservative":
            guardrailConfig = .conservative
        case "aggressive":
            guardrailConfig = .aggressive
        default:
            guardrailConfig = .default
        }
        await newSessionState.initializeGuardrails(config: guardrailConfig)

        // Initialize tool execution boundary with unified permission checking and telemetry
        let executor = ToolExecutor(sessionState: newSessionState, stateManager: stateManager)
        toolExecutor = executor

        // Initialize file safety validator with project scope
        let validator = SafetyValidator()
        await validator.configureProjectScope(
            projectId: project.id,
            allowedDirectories: [project.workspaceDir.path]
        )
        safetyValidator = validator

        // Initialize safety enforcement gate for runtime validation
        let enforcementGate = SafetyEnforcementGate(validator: validator)
        await enforcementGate.registerProject(
            projectId: project.id,
            workspaceRoot: project.workspaceDir.path,
            allowedDirectories: [project.workspaceDir.path]
        )
        safetyEnforcementGate = enforcementGate

        // Initialize permission enforcement gate
        let gate = PermissionGate(
            sessionState: newSessionState,
            stateManager: stateManager,
            safetyValidator: validator
        )
        // Set default permission mode from environment or configuration
        let defaultMode: PermissionMode = .allow  // Can be overridden by settings
        await gate.setPermissionMode(defaultMode)
        permissionGate = gate

        // Initialize retry/recovery with circuit breaker
        retryableExecution = RetryableTaskExecution()

        // Initialize delegation boundaries for multi-agent coordination
        delegationBoundary = DelegationBoundary(sessionState: newSessionState)

        // Initialize observability and telemetry
        executionObserver = ExecutionObserver()

        // Initialize execution diagnostics observer for failure tracking
        diagnosticsObserver = ExecutionDiagnosticsObserver()

        // Initialize task batching for efficient delegation
        taskBatcher = TaskBatcher()

        // Check for existing checkpoint and resume if available
        if let checkpoint = try? await stateManager.loadSessionCheckpoint(projectId: project.id) {
            await MainActor.run {
                self.statusMessage = "Resuming project from checkpoint at \(checkpoint.timestamp)"
            }

            // Resume from checkpoint
            await MainActor.run {
                self.agents = Dictionary(uniqueKeysWithValues: checkpoint.agents.map { ($0.id, $0) })
            }

            // Restore session state metrics from checkpoint
            await newSessionState.addTokenUsage(checkpoint.totalTokensUsed)
            await newSessionState.addCost(checkpoint.totalCostUSD)
        }

        // Start the orchestration loop
        orchestrationTask = ConcurrencyTask {
            await self.runOrchestrationLoop(projectId: project.id)
        }
    }

    func pauseProject() async {
        orchestrationTask?.cancel()

        // Save checkpoint before pausing (including session state metrics)
        if let project = await currentProject {
            let agents = await MainActor.run { self.agents }
            if let taskGraph = try? await stateManager.loadTaskGraph(projectId: project.id),
               let state = self.sessionState {
                let (totalTokens, totalCost) = await state.getUsageMetrics()
                try? await stateManager.saveSessionCheckpoint(
                    projectId: project.id,
                    agents: agents,
                    taskGraph: taskGraph,
                    totalTokensUsed: totalTokens,
                    totalCostUSD: totalCost
                )
            }
        }

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
            // Check execution guardrails (iteration, time, progress limits)
            if let state = self.sessionState {
                do {
                    try await state.checkIterationAllowed()
                } catch {
                    await MainActor.run {
                        self.statusMessage = "Execution stopped: \(error.localizedDescription)"
                        self.isRunning = false
                    }
                    break
                }

                // Check overall health
                if let health = await state.getExecutionHealth(), health.shouldStop {
                    await MainActor.run {
                        self.statusMessage = "Execution stopped: \(health.status.rawValue)"
                        self.isRunning = false
                    }
                    break
                }
            }

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

            // Use batching for multiple ready tasks, direct assignment for single task
            if readyTasks.count > 2, let batcher = self.taskBatcher {
                // Create batch using hybrid strategy
                let batches = await batcher.createBatches(from: taskGraph, strategy: .hybrid)

                if !batches.isEmpty {
                    // Get pending batches sorted by priority
                    let pendingBatches = await batcher.getPendingBatches()

                    // Assign each batch to agents
                    for batch in pendingBatches.prefix(agents.values.filter(\.isRunnableState).count) {
                        guard !ConcurrencyTask.isCancelled else { break }

                        let batchStartTime = Date()

                        // Find agents capable of handling batch tasks
                        let requiredRoles = Set(
                            batch.taskIds.compactMap { taskId in
                                taskGraph.getTask(taskId)?.roleRequired
                            }
                        )

                        var batchSuccessCount = 0
                        var batchFailureCount = 0

                        // Execute batch tasks (respecting maxParallelism)
                        for (index, taskId) in batch.taskIds.enumerated() {
                            guard !ConcurrencyTask.isCancelled else { break }

                            if let task = taskGraph.getTask(taskId), task.status == .pending {
                                let availableAgents = agents.values.filter { agent in
                                    agent.role == task.roleRequired && agent.isRunnableState && agent.currentTaskId == nil
                                }

                                if let agent = availableAgents.first {
                                    if let state = self.sessionState {
                                        let priorStatus = task.status
                                        await runTask(
                                            task,
                                            for: agent,
                                            in: projectId,
                                            taskGraph: &taskGraph,
                                            agents: &agents,
                                            sessionState: state
                                        )
                                        let postStatus = taskGraph.getTask(taskId)?.status ?? .failed
                                        if postStatus == .completed {
                                            batchSuccessCount += 1
                                        } else {
                                            batchFailureCount += 1
                                        }
                                    }
                                } else if index < batch.maxParallelism {
                                    // Not enough agents yet, skip sequential task assignment
                                    break
                                }
                            }
                        }

                        // Record batch metrics
                        let batchDuration = Date().timeIntervalSince(batchStartTime)
                        await batcher.recordBatchCompletion(
                            batchId: batch.id,
                            successCount: batchSuccessCount,
                            failureCount: batchFailureCount,
                            duration: batchDuration
                        )

                        // Update status with batch info
                        let (totalBatches, completedBatches, avgSuccessRate) = await batcher.getBatchingMetrics()
                        await MainActor.run {
                            self.statusMessage = "Batching: \(completedBatches)/\(totalBatches) complete, \(Int(avgSuccessRate * 100))% success rate"
                        }
                    }
                } else {
                    // Fallback to direct assignment if batching fails
                    for task in readyTasks {
                        guard !ConcurrencyTask.isCancelled else { break }

                        let availableAgents = agents.values.filter { agent in
                            agent.role == task.roleRequired && agent.isRunnableState && agent.currentTaskId == nil
                        }

                        guard let agent = availableAgents.first else { continue }

                        if let state = self.sessionState {
                            await runTask(
                                task,
                                for: agent,
                                in: projectId,
                                taskGraph: &taskGraph,
                                agents: &agents,
                                sessionState: state
                            )
                        }
                    }
                }
            } else {
                // Direct assignment for single or few tasks
                for task in readyTasks {
                    guard !ConcurrencyTask.isCancelled else { break }

                    let availableAgents = agents.values.filter { agent in
                        agent.role == task.roleRequired && agent.isRunnableState && agent.currentTaskId == nil
                    }

                    guard let agent = availableAgents.first else { continue }

                    if let state = self.sessionState {
                        await runTask(
                            task,
                            for: agent,
                            in: projectId,
                            taskGraph: &taskGraph,
                            agents: &agents,
                            sessionState: state
                        )
                    }
                }
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
        agents: inout [String: Agent],
        sessionState: SessionState
    ) async {
        // Log task start to session state
        let taskStartMessage = ExecutionMessage(
            id: UUID().uuidString,
            timestamp: Date(),
            type: .status,
            content: "Task started: \(task.description)",
            agentId: agent.id,
            taskId: task.id,
            metadata: ["role": agent.role.rawValue]
        )
        await sessionState.appendMessage(taskStartMessage)

        await MainActor.run {
            self.statusMessage = "Agent \(agent.name) starting task: \(task.description)"
        }

        var updatedAgent = agent
        updatedAgent.currentTaskId = task.id
        updatedAgent.status = .coding
        updatedAgent.startedAt = Date()
        agents[agent.id] = updatedAgent

        // Prepare execution context with budget and permission info
        let executionContext = TaskExecutionContext.defaultContext(
            for: task,
            workDir: stateManager.workspaceDirectory(for: projectId).path
        )

        // Attempt task with exponential backoff retry
        var currentTask = task
        var lastError: Error?
        var executionStart = Date()

        for attemptIndex in 0..<task.retryPolicy.maxAttempts {
            do {
                // Record task start for diagnostics
                if attemptIndex == 0 {
                    await self.diagnosticsObserver?.recordTaskStart(task.id)
                }

                // Pre-flight safety validation
                if let enforcementGate = self.safetyEnforcementGate {
                    let (allowed, violations) = await enforcementGate.validateTaskExecution(
                        taskId: task.id,
                        projectId: projectId,
                        role: agent.role,
                        description: task.description
                    )

                    if !allowed {
                        throw NSError(
                            domain: "SafetyValidator",
                            code: 403,
                            userInfo: [
                                NSLocalizedDescriptionKey: "Task execution blocked by safety validation: \(violations.map { $0.message }.joined(separator: "; "))"
                            ]
                        )
                    }

                    // Log any non-critical violations but continue
                    for violation in violations.filter({ $0.severity == .ask }) {
                        logger.warning("Safety warning: \(violation.message)")
                    }
                }

                try await updateAgentStatus(agent.id, to: .coding, projectId: projectId)

                // Check permission before executing tool
                if let gate = self.permissionGate {
                    _ = try await gate.checkToolExecution(
                        toolName: "claudeRunner",
                        projectId: projectId,
                        agentId: agent.id
                    )
                }

                // Get skill prompt for this task
                let skillId = skillRegistry.getSkillsForRole(agent.role).first?.id ?? "generic:fallback"
                let skillPrompt = skillRegistry.getSkillPrompt(skillId: skillId, role: agent.role)

                // Run the task through Claude with execution context
                executionStart = Date()
                let output = try await claudeRunner.runTask(
                    agentId: agent.id,
                    role: agent.role,
                    projectId: projectId,
                    task: currentTask,
                    skillPrompt: skillPrompt,
                    workDir: stateManager.workspaceDirectory(for: projectId),
                    context: executionContext
                )
                let executionDuration = Date().timeIntervalSince(executionStart)

                // Log tool execution through unified boundary
                if let executor = self.toolExecutor {
                    try await executor.recordToolExecution(
                        toolName: "claudeRunner",
                        agentId: agent.id,
                        projectId: projectId,
                        taskId: task.id,
                        duration: executionDuration,
                        status: output.status,
                        filesModified: output.filesModified
                    )
                }

                // Success: mark task as completed
                try taskGraph.markCompleted(taskId: task.id, output: output.output ?? output.summary)

                // Record task completion for guardrails
                await sessionState.recordTaskCompletion()

                // Record task success in diagnostics observer
                await self.diagnosticsObserver?.recordTaskSuccess(task.id)

                // Log completion to session state
                let completionMessage = ExecutionMessage(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    type: .output,
                    content: output.summary,
                    agentId: agent.id,
                    taskId: task.id,
                    metadata: ["status": output.status]
                )
                await sessionState.appendMessage(completionMessage)

                updatedAgent.status = output.status == "success" ? .success : .failed
                updatedAgent.lastOutput = output.summary
                updatedAgent.currentTaskId = nil
                updatedAgent.retryCount = 0
                agents[agent.id] = updatedAgent

                try await stateManager.saveTaskGraph(taskGraph, projectId: projectId)
                try await stateManager.saveAgentState(updatedAgent, projectId: projectId)

                // Get current usage metrics from session state
                let (totalTokens, totalCost) = await sessionState.getUsageMetrics()

                // Save session checkpoint after successful task completion (with session state metrics)
                try await stateManager.saveSessionCheckpoint(
                    projectId: projectId,
                    agents: agents,
                    taskGraph: taskGraph,
                    totalTokensUsed: totalTokens,
                    totalCostUSD: totalCost
                )

                await MainActor.run {
                    self.statusMessage = "Agent \(agent.name) completed task: \(output.summary)"
                    self.agents = agents
                }
                return  // Success; exit retry loop
            } catch {
                lastError = error
                let isLastAttempt = attemptIndex == task.retryPolicy.maxAttempts - 1
                let executionDuration = Date().timeIntervalSince(executionStart)

                // Log tool execution failure through unified boundary
                if let executor = self.toolExecutor {
                    try? await executor.recordToolExecution(
                        toolName: "claudeRunner",
                        agentId: agent.id,
                        projectId: projectId,
                        taskId: task.id,
                        duration: executionDuration,
                        status: "failed",
                        filesModified: [],
                        error: error
                    )
                }

                // Check if error is retryable
                let providerError = error as? ProviderError ?? ProviderError.classify(error)
                let shouldRetry = !isLastAttempt && providerError.isRetryable

                if shouldRetry {
                    // Calculate backoff duration
                    let backoffDuration = task.retryPolicy.nextBackoffDuration(for: attemptIndex)

                    await MainActor.run {
                        self.statusMessage = "Agent \(agent.name) retry \(attemptIndex + 1)/\(task.retryPolicy.maxAttempts) after \(String(format: "%.1f", backoffDuration))s: \(error.localizedDescription)"
                    }

                    // Wait before retrying
                    try? await ConcurrencyTask.sleep(nanoseconds: UInt64(backoffDuration * 1_000_000_000))
                } else {
                    // Error is permanent or final attempt; fail immediately
                    updatedAgent.status = .failed
                    updatedAgent.errorMessage = error.localizedDescription
                    updatedAgent.currentTaskId = nil
                    agents[agent.id] = updatedAgent

                    // Log error to session state
                    let errorMessage = ExecutionMessage(
                        id: UUID().uuidString,
                        timestamp: Date(),
                        type: .error,
                        content: error.localizedDescription,
                        agentId: agent.id,
                        taskId: task.id,
                        metadata: ["isRetryable": String(providerError.isRetryable)]
                    )
                    await sessionState.appendMessage(errorMessage)

                    do {
                        try taskGraph.markFailed(taskId: task.id, error: error.localizedDescription)

                        // Record task failure for guardrails
                        await sessionState.recordTaskFailure()

                        // Record detailed failure diagnostic
                        var contextSnapshot: [String: String] = [
                            "agentRole": agent.role.rawValue,
                            "taskDescription": task.description,
                            "attemptNumber": String(attemptIndex + 1),
                            "maxAttempts": String(task.retryPolicy.maxAttempts)
                        ]
                        if let lastOutput = agent.lastOutput {
                            contextSnapshot["lastOutput"] = lastOutput
                        }

                        let suggestion: String?
                        if providerError.isRetryable {
                            suggestion = "This error is transient. The task will be retried automatically."
                        } else if error.localizedDescription.contains("permission") {
                            suggestion = "Check file permissions and access rights for the working directory."
                        } else if error.localizedDescription.contains("timeout") {
                            suggestion = "Increase task timeout or check for long-running operations."
                        } else {
                            suggestion = nil
                        }

                        await self.diagnosticsObserver?.recordTaskFailure(
                            taskId: task.id,
                            agentId: agent.id,
                            error: error,
                            isRetryable: providerError.isRetryable,
                            suggestion: suggestion,
                            context: contextSnapshot
                        )

                        try await stateManager.saveTaskGraph(taskGraph, projectId: projectId)
                        try await stateManager.saveAgentState(updatedAgent, projectId: projectId)
                    } catch {
                        // Silently fail to save; will retry next iteration
                    }

                    let attemptMessage = isLastAttempt ? "after \(task.retryPolicy.maxAttempts) attempts" : "permanent error"
                    let retryable = providerError.isRetryable ? "" : " (non-retryable)"
                    await MainActor.run {
                        self.statusMessage = "Agent \(agent.name) failed \(attemptMessage)\(retryable): \(error.localizedDescription)"
                        self.agents = agents
                    }

                    // Exit retry loop immediately for permanent errors
                    if !providerError.isRetryable {
                        break
                    }
                }
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
