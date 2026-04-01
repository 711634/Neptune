import Foundation

struct ClaudeOutput: Codable {
    let status: String  // "success", "failed", "blocked", "incomplete"
    let summary: String
    let output: String?
    let filesModified: [String]
    let nextRole: String?  // Which role to hand off to
    let errors: [String]
}

// MARK: - Provider Error Classification

enum ProviderError: LocalizedError, Sendable {
    case rateLimited(retryAfterSeconds: Int? = nil)
    case timeout(duration: TimeInterval)
    case networkUnreachable
    case temporaryFailure(reason: String)
    case invalidConfiguration(detail: String)
    case authenticationFailed(detail: String)
    case permissionDenied(detail: String)
    case invalidInput(detail: String)
    case resourceNotFound(detail: String)
    case unsupported(feature: String)
    case internalServerError(detail: String)
    case unknown(underlyingError: Error)

    var isRetryable: Bool {
        switch self {
        case .rateLimited, .timeout, .networkUnreachable, .temporaryFailure:
            return true
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .rateLimited(let retryAfter):
            let afterStr = retryAfter.map { "retry after \($0)s" } ?? "retry later"
            return "Rate limited: \(afterStr)"
        case .timeout(let duration):
            return "Request timed out after \(String(format: "%.1f", duration))s"
        case .networkUnreachable:
            return "Network is unreachable"
        case .temporaryFailure(let reason):
            return "Temporary failure: \(reason)"
        case .invalidConfiguration(let detail):
            return "Invalid configuration: \(detail)"
        case .authenticationFailed(let detail):
            return "Authentication failed: \(detail)"
        case .permissionDenied(let detail):
            return "Permission denied: \(detail)"
        case .invalidInput(let detail):
            return "Invalid input: \(detail)"
        case .resourceNotFound(let detail):
            return "Resource not found: \(detail)"
        case .unsupported(let feature):
            return "Unsupported feature: \(feature)"
        case .internalServerError(let detail):
            return "Internal server error: \(detail)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }

    static func classify(_ error: Error) -> ProviderError {
        if let providerError = error as? ProviderError {
            return providerError
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut:
                return .timeout(duration: 30)
            case NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet:
                return .networkUnreachable
            default:
                return .temporaryFailure(reason: nsError.localizedDescription)
            }
        }
        let description = nsError.localizedDescription.lowercased()
        if description.contains("timeout") {
            return .timeout(duration: 30)
        }
        if description.contains("rate limit") {
            return .rateLimited()
        }
        if description.contains("unauthorized") || description.contains("authentication") {
            return .authenticationFailed(detail: nsError.localizedDescription)
        }
        return .temporaryFailure(reason: nsError.localizedDescription)
    }
}

// MARK: - Provider Health & Circuit Breaker

struct ProviderHealth: Sendable {
    var consecutiveFailures: Int = 0
    var lastFailureTime: Date?
    var totalFailures: Int = 0
    var totalRequests: Int = 0
}

actor ProviderHealthRegistry: Sendable {
    private var providers: [String: ProviderHealth] = [:]
    private let failureThreshold: Int = 3
    private let recoveryTimeSeconds: TimeInterval = 60

    init() {
        providers["claude-code"] = ProviderHealth()
    }

    func recordSuccess(provider: String) {
        var health = providers[provider] ?? ProviderHealth()
        health.consecutiveFailures = 0
        health.totalRequests += 1
        providers[provider] = health
    }

    func recordFailure(provider: String, error: ProviderError) {
        var health = providers[provider] ?? ProviderHealth()
        if !error.isRetryable {
            health.consecutiveFailures += 1
            health.totalFailures += 1
            health.lastFailureTime = Date()
        }
        health.totalRequests += 1
        providers[provider] = health
    }

    func getHealth(provider: String) -> ProviderHealth {
        providers[provider] ?? ProviderHealth()
    }

    func canAttempt(provider: String) -> Bool {
        let health = getHealth(provider: provider)
        if health.consecutiveFailures >= failureThreshold {
            if let lastFailure = health.lastFailureTime,
               Date().timeIntervalSince(lastFailure) <= recoveryTimeSeconds {
                return false
            }
        }
        return true
    }
}

actor ClaudeCodeRunner {
    let processManager: ProcessManager
    let stateManager: StateManager
    let providerHealthRegistry: ProviderHealthRegistry

    private let claudePath: String
    private let providerName: String = "claude-code"

    init(
        processManager: ProcessManager,
        stateManager: StateManager,
        providerHealthRegistry: ProviderHealthRegistry? = nil,
        claudePath: String = "/opt/homebrew/bin/claude"
    ) {
        self.processManager = processManager
        self.stateManager = stateManager
        self.providerHealthRegistry = providerHealthRegistry ?? ProviderHealthRegistry()
        self.claudePath = claudePath
    }

    // MARK: - Public API

    func runTask(
        agentId: String,
        role: AgentRole,
        projectId: String,
        task: Task,
        skillPrompt: String,
        workDir: URL,
        context: TaskExecutionContext? = nil
    ) async throws -> ClaudeOutput {
        // Check circuit breaker
        let canAttempt = await providerHealthRegistry.canAttempt(provider: providerName)
        if !canAttempt {
            let health = await providerHealthRegistry.getHealth(provider: providerName)
            throw ProviderError.temporaryFailure(reason: "Provider circuit breaker open: \(health.consecutiveFailures) consecutive failures")
        }

        do {
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

            // 5. Truncate output if too large
            let truncatedOutput = truncateOutput(output, maxLines: 500)

            // 6. Save transcript
            try await stateManager.appendTranscript(agentId: agentId, projectId: projectId, lines: truncatedOutput)

            // 7. Parse output to extract completion signal
            let claudeOutput = try parseClaudeOutput(truncatedOutput)

            // Record success
            await providerHealthRegistry.recordSuccess(provider: providerName)

            return claudeOutput
        } catch {
            // Classify error for retry logic
            let classifiedError = ProviderError.classify(error)

            // Record failure in provider registry
            await providerHealthRegistry.recordFailure(provider: providerName, error: classifiedError)

            throw classifiedError
        }
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

    private func truncateOutput(_ lines: [String], maxLines: Int = 500) -> [String] {
        guard lines.count > maxLines else {
            return lines
        }

        var truncated = Array(lines.prefix(maxLines))
        let truncatedCount = lines.count - maxLines

        truncated.append("")
        truncated.append("... [\(truncatedCount) lines truncated] ...")

        return truncated
    }

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
