import Foundation

class MockDataGenerator {
    private var timer: Timer?
    private var agents: [Agent] = []
    private var baseTime: Date = Date()

    private let agentNames = ["Planner", "Researcher", "Builder", "Reviewer", "Shipper", "Debugger", "Designer"]
    private let roles: [AgentRole] = [.planning, .research, .coding, .review, .shipping]
    private let tasks = [
        "Planning tasks",
        "Researching solutions",
        "Building features",
        "Reviewing code",
        "Deploying changes",
        "Fixing bugs",
        "Designing UI"
    ]
    private let logs = [
        "Analyzing requirements",
        "Writing code",
        "Running tests",
        "Debugging issue",
        "Reviewing output",
        "Processing data",
        "Generating response",
        "Testing implementation"
    ]
    private let anchors: [AnchorHint] = [.terminal, .browser, .figma, .notes, .generic]
    private let colorVariants: [ColorVariant] = [.purple, .blue, .green, .orange, .pink, .cyan]

    func startMockGeneration(interval: TimeInterval = 3.0, completion: @escaping (AgentState) -> Void) {
        stopMockGeneration()
        generateInitialState()

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateRandomly()
            let state = AgentState(updatedAt: Date(), agents: self?.agents ?? [])
            completion(state)
        }
    }

    func stopMockGeneration() {
        timer?.invalidate()
        timer = nil
    }

    private func generateInitialState() {
        let numAgents = 4
        agents = (0..<numAgents).map { index in
            Agent(
                id: "agent-\(index + 1)",
                name: agentNames[index % agentNames.count],
                role: roles[index % roles.count],
                task: tasks[index % tasks.count],
                status: [.coding, .thinking, .idle].randomElement() ?? .idle,
                elapsedSeconds: Int.random(in: 10...600),
                lastLog: logs.randomElement() ?? "Working",
                updatedAt: Date(),
                colorVariant: colorVariants[index % colorVariants.count],
                anchorHint: anchors[index % anchors.count],
                slotIndex: index
            )
        }
    }

    private func updateRandomly() {
        for i in agents.indices {
            let roll = Double.random(in: 0...1)

            if roll < 0.15 {
                agents[i].status = [.coding, .thinking, .idle, .success, .failed].randomElement() ?? .coding
            }

            agents[i].elapsedSeconds += Int.random(in: 1...5)
            agents[i].lastLog = logs.randomElement() ?? "Working"
            agents[i].updatedAt = Date()
        }

        if Double.random(in: 0...1) < 0.05 {
            if agents.count < 5 {
                let newId = "agent-\(agents.count + 1)"
                let newAgent = Agent(
                    id: newId,
                    name: agentNames[agents.count % agentNames.count],
                    role: roles[agents.count % roles.count],
                    task: tasks[agents.count % tasks.count],
                    status: [.coding, .thinking].randomElement() ?? .idle,
                    elapsedSeconds: 0,
                    lastLog: "Starting new task",
                    updatedAt: Date(),
                    colorVariant: colorVariants[agents.count % colorVariants.count],
                    anchorHint: anchors[agents.count % anchors.count],
                    slotIndex: agents.count
                )
                agents.append(newAgent)
            }
        }

        if Double.random(in: 0...1) < 0.05 && agents.count > 1 {
            agents.removeLast()
        }
    }

    func generateSingleState() -> AgentState {
        generateInitialState()
        return AgentState(updatedAt: Date(), agents: agents)
    }
}
