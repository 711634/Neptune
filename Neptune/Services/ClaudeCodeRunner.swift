import Foundation

struct ClaudeOutput: Codable {
    let status: String  // "success", "failed", "blocked", "incomplete"
    let summary: String
    let output: String?
    let filesModified: [String]
    let nextRole: String?  // Which role to hand off to
    let errors: [String]
}

actor ClaudeCodeRunner {
    let processManager: ProcessManager
    let stateManager: StateManager

    private let claudePath: String

    init(processManager: ProcessManager, stateManager: StateManager, claudePath: String = "/opt/homebrew/bin/claude") {
        self.processManager = processManager
        self.stateManager = stateManager
        self.claudePath = claudePath
    }

    // MARK: - Public API

    func runTask(
        agentId: String,
        role: AgentRole,
        projectId: String,
        task: Task,
        skillPrompt: String,
        workDir: URL
    ) async throws -> ClaudeOutput {
        // 1. Create the full prompt
        let fullPrompt = buildPrompt(
            skill: skillPrompt,
            task: task,
            role: role
        )

        // 2. Start a Claude Code session
        let sessionId = try await processManager.startSession(
            agentId: agentId,
            workDir: workDir.path,
            command: claudePath,
            args: [],
            env: [
                "CLAUDE_NO_CACHE": "1",
                "CLAUDE_WORKSPACE": workDir.path
            ]
        )

        // 3. Send the task prompt
        try await processManager.sendInput(to: sessionId, input: fullPrompt)

        // 4. Wait for completion with timeout
        let (exitCode, output) = try await processManager.waitForCompletion(
            sessionId: sessionId,
            timeout: task.timeout
        )

        // 5. Save transcript
        try await stateManager.appendTranscript(agentId: agentId, projectId: projectId, lines: output)

        // 6. Parse output to extract completion signal
        let claudeOutput = try parseClaudeOutput(output)

        return claudeOutput
    }

    func checkClaudeAvailability() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = ["--version"]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Private Helpers

    private func buildPrompt(skill: String, task: Task, role: AgentRole) -> String {
        """
        \(skill)

        TASK: \(task.description)

        REQUIREMENTS:
        \(task.acceptanceCriteria.map { "- \($0)" }.joined(separator: "\n"))

        INSTRUCTIONS:
        1. Analyze the task thoroughly
        2. Complete the work step by step
        3. Test/verify your work
        4. Output completion status as JSON at the end

        COMPLETION JSON FORMAT:
        {
          "status": "success|failed|blocked|incomplete",
          "summary": "What you accomplished",
          "output": "Detailed explanation",
          "filesModified": ["file1", "file2"],
          "nextRole": "coding|review|shipping|null",
          "errors": []
        }

        Begin working now. Output the completion JSON when done.
        """
    }

    private func parseClaudeOutput(_ lines: [String]) throws -> ClaudeOutput {
        // Look for JSON in the output
        let text = lines.joined(separator: "\n")

        // Find JSON block (look for { ... })
        guard let jsonStartIndex = text.firstIndex(of: "{"),
              let jsonEndIndex = text.lastIndex(of: "}") else {
            // No JSON found, assume incomplete
            return ClaudeOutput(
                status: "incomplete",
                summary: "No completion JSON found",
                output: text,
                filesModified: [],
                nextRole: nil,
                errors: ["No completion status received"]
            )
        }

        let jsonString = String(text[jsonStartIndex...jsonEndIndex])

        let decoder = JSONDecoder()
        let output = try decoder.decode(ClaudeOutput.self, from: jsonString.data(using: .utf8) ?? Data())

        return output
    }
}

// MARK: - Testing Extensions

extension ClaudeCodeRunner {
    static func mock(
        processManager: ProcessManager,
        stateManager: StateManager
    ) -> ClaudeCodeRunner {
        ClaudeCodeRunner(
            processManager: processManager,
            stateManager: stateManager,
            claudePath: "/usr/bin/echo"  // Use echo for testing
        )
    }
}
