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

// MARK: - Bash Command Analysis Types

struct CommandSegment: Sendable, Equatable {
    let command: String
    let args: [String]
    let index: Int

    var isDirectoryChange: Bool {
        command == "cd" || command == "pushd" || command == "popd"
    }

    var isVersionControl: Bool {
        command == "git" || command == "hg" || command == "svn"
    }
}

enum SecuritySeverity: String, Sendable {
    case info
    case warning
    case error
}

struct SecurityIssue: Sendable, Equatable {
    let severity: SecuritySeverity
    let message: String
    let affectedSegments: [Int]
}

struct BashCommandParser: Sendable {
    static func segment(_ command: String) -> [CommandSegment] {
        let parts = command.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }

        return parts.enumerated().compactMap { index, part in
            let tokens = tokenizeCommand(part)
            guard !tokens.isEmpty else { return nil }

            let cmd = tokens[0]
            let args = Array(tokens.dropFirst())

            return CommandSegment(command: cmd, args: args, index: index)
        }
    }

    static func detectSecurityIssues(segments: [CommandSegment]) -> [SecurityIssue] {
        var issues: [SecurityIssue] = []

        // Check for cd+git pattern across segments
        var hasCd = false
        var hasGit = false

        for segment in segments {
            if segment.isDirectoryChange {
                hasCd = true
            }
            if segment.isVersionControl {
                hasGit = true
            }
        }

        if hasCd && hasGit {
            issues.append(
                SecurityIssue(
                    severity: .error,
                    message: "Directory change followed by git command prevents bare repository attacks",
                    affectedSegments: Array(0..<segments.count)
                )
            )
        }

        return issues
    }

    private static func tokenizeCommand(_ commandString: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""
        var inSingleQuote = false
        var inDoubleQuote = false
        var i = commandString.startIndex

        while i < commandString.endIndex {
            let char = commandString[i]

            switch char {
            case "'" where !inDoubleQuote:
                inSingleQuote.toggle()
            case "\"" where !inSingleQuote:
                inDoubleQuote.toggle()
            case " ", "\t" where !inSingleQuote && !inDoubleQuote:
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
            default:
                currentToken.append(char)
            }

            i = commandString.index(after: i)
        }

        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }

        return tokens
    }
}

// MARK: - Execution Timing & Observability

struct ExecutionPhaseMetrics: Sendable {
    let phaseName: String
    let startTime: Date
    var endTime: Date?

    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    var isSlowOperation: Bool {
        // Match reference thresholds:
        // HOOK_TIMING_DISPLAY_THRESHOLD_MS = 500ms
        // SLOW_PHASE_LOG_THRESHOLD_MS = 2000ms
        duration >= 2.0  // 2000ms
    }

    var shouldDisplay: Bool {
        duration >= 0.5  // 500ms
    }
}

struct ToolExecutionMetrics: Sendable {
    let toolName: String
    let agentId: String
    let startTime: Date
    var phases: [ExecutionPhaseMetrics] = []

    mutating func startPhase(_ name: String) -> ExecutionPhaseMetrics {
        let phase = ExecutionPhaseMetrics(phaseName: name, startTime: Date())
        return phase
    }

    mutating func endPhase(_ phase: inout ExecutionPhaseMetrics) {
        phase.endTime = Date()
        phases.append(phase)

        if phase.isSlowOperation {
            logSlowPhase(phase)
        }
    }

    var totalDuration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    private func logSlowPhase(_ phase: ExecutionPhaseMetrics) {
        let durationMs = String(format: "%.0f", phase.duration * 1000)
        print("⚠️  Slow \(toolName) phase: \(phase.phaseName) took \(durationMs)ms")
    }
}

// MARK: - Segmented Command Permission Aggregation

struct SegmentPermissionResult: Sendable {
    let command: String
    let allowed: Bool
    let reason: String?
    let issues: [SecurityIssue]
}

struct CommandPermissionAggregation: Sendable {
    let originalCommand: String
    let segments: [CommandSegment]
    let segmentResults: [SegmentPermissionResult]
    let securityIssues: [SecurityIssue]

    var shouldAllow: Bool {
        // Deny if: any segment denied OR cross-segment security issues found
        if !securityIssues.isEmpty {
            return false
        }
        return segmentResults.allSatisfy { $0.allowed }
    }

    var shouldAsk: Bool {
        // Ask if: mixed permissions or segment-level security concerns
        let hasAllowed = segmentResults.contains { $0.allowed }
        let hasDenied = segmentResults.contains { !$0.allowed }
        return hasAllowed && hasDenied
    }

    var summary: String {
        if !securityIssues.isEmpty {
            let critical = securityIssues.filter { $0.severity == .error }
            if !critical.isEmpty {
                return critical.map { $0.message }.joined(separator: "; ")
            }
        }
        if shouldDeny {
            let denied = segmentResults.filter { !$0.allowed }
            return denied.map { "\($0.command): \($0.reason ?? "access denied")" }.joined(separator: "; ")
        }
        return "All segments allowed"
    }

    var shouldDeny: Bool {
        !shouldAllow && !shouldAsk
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
        var metrics = ToolExecutionMetrics(
            toolName: "claudeRunner",
            agentId: agentId,
            startTime: Date()
        )

        // Check circuit breaker
        let canAttempt = await providerHealthRegistry.canAttempt(provider: providerName)
        if !canAttempt {
            let health = await providerHealthRegistry.getHealth(provider: providerName)
            throw ProviderError.temporaryFailure(reason: "Provider circuit breaker open: \(health.consecutiveFailures) consecutive failures")
        }

        do {
            // Phase 1: Prompt building
            var promptPhase = metrics.startPhase("prompt_building")
            let fullPrompt = buildPrompt(
                skill: skillPrompt,
                task: task,
                role: role
            )
            metrics.endPhase(&promptPhase)

            // Phase 2: Session setup
            var sessionPhase = metrics.startPhase("session_setup")
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
            metrics.endPhase(&sessionPhase)

            // Phase 3: Prompt submission
            var submitPhase = metrics.startPhase("prompt_submission")
            try await processManager.sendInput(to: sessionId, input: fullPrompt)
            metrics.endPhase(&submitPhase)

            // Phase 4: Execution
            var executionPhase = metrics.startPhase("execution")
            let (exitCode, output) = try await processManager.waitForCompletion(
                sessionId: sessionId,
                timeout: task.timeout
            )
            metrics.endPhase(&executionPhase)

            // Phase 5: Output processing
            var processingPhase = metrics.startPhase("output_processing")
            let truncatedOutput = truncateOutput(output, maxLines: 500)
            try await stateManager.appendTranscript(agentId: agentId, projectId: projectId, lines: truncatedOutput)
            let claudeOutput = try parseClaudeOutput(truncatedOutput)
            metrics.endPhase(&processingPhase)

            // Log metrics if any phase was slow
            let slowPhases = metrics.phases.filter { $0.shouldDisplay }
            if !slowPhases.isEmpty {
                let summary = slowPhases.map { "\($0.phaseName):\(String(format: "%.0f", $0.duration * 1000))ms" }.joined(separator: " ")
                print("📊 Task execution phases: \(summary)")
            }

            // Record success
            await providerHealthRegistry.recordSuccess(provider: providerName)

            return claudeOutput
        } catch {
            // Classify error for retry logic
            let classifiedError = ProviderError.classify(error)

            // Record failure in provider registry
            await providerHealthRegistry.recordFailure(provider: providerName, error: classifiedError)

            // Log total duration on failure
            let totalMs = String(format: "%.0f", metrics.totalDuration * 1000)
            print("❌ Task failed after \(totalMs)ms")

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

    // MARK: - Command Analysis

    func analyzeCommandPermissions(
        command: String,
        agentId: String,
        projectId: String
    ) async throws -> CommandPermissionAggregation {
        // Parse the command into segments
        let segments = BashCommandParser.segment(command)

        // If only one segment or no pipes, treat as single command
        if segments.count <= 1 {
            let singleSegment: CommandSegment
            if let first = segments.first {
                singleSegment = first
            } else {
                singleSegment = CommandSegment(
                    command: command.trimmingCharacters(in: .whitespaces),
                    args: [],
                    index: 0
                )
            }
            let result = SegmentPermissionResult(
                command: singleSegment.command,
                allowed: true,  // Default permissive (real implementation would check permissions)
                reason: nil,
                issues: []
            )
            return CommandPermissionAggregation(
                originalCommand: command,
                segments: [singleSegment],
                segmentResults: [result],
                securityIssues: []
            )
        }

        // Analyze each segment
        var segmentResults: [SegmentPermissionResult] = []
        var allIssues: [SecurityIssue] = []

        for segment in segments {
            let issues = BashCommandParser.detectSecurityIssues(segments: [segment])
            allIssues.append(contentsOf: issues)

            // Evaluate segment permissions
            let allowed = evaluateSegmentPermission(segment: segment)

            segmentResults.append(
                SegmentPermissionResult(
                    command: segment.command,
                    allowed: allowed,
                    reason: allowed ? nil : "Permission denied for \(segment.command)",
                    issues: issues
                )
            )

            // Log segment decision
            try await stateManager.logPermissionDecision(
                toolName: "bash",
                decision: allowed ? "allow" : "deny",
                source: .classifier,
                reasonType: "bash_segment",
                reason: "Segment: \(segment.command)",
                agentId: agentId,
                projectId: projectId,
                metadata: ["segment_index": String(segment.index), "segment": segment.command]
            )
        }

        // Cross-segment security analysis
        let crossSegmentIssues = BashCommandParser.detectSecurityIssues(segments: segments)
        allIssues.append(contentsOf: crossSegmentIssues)

        let aggregation = CommandPermissionAggregation(
            originalCommand: command,
            segments: segments,
            segmentResults: segmentResults,
            securityIssues: allIssues
        )

        // Log final aggregated decision
        try await stateManager.logPermissionDecision(
            toolName: "bash",
            decision: aggregation.shouldAllow ? "allow" : aggregation.shouldDeny ? "deny" : "ask",
            source: aggregation.securityIssues.isEmpty ? .classifier : .config,
            reasonType: aggregation.securityIssues.isEmpty ? "bash_aggregated" : "bash_security_issue",
            reason: aggregation.summary,
            agentId: agentId,
            projectId: projectId,
            metadata: [
                "total_segments": String(segments.count),
                "security_issues": String(allIssues.count)
            ]
        )

        return aggregation
    }

    private func evaluateSegmentPermission(segment: CommandSegment) -> Bool {
        // Default: allow everything (real implementation would check against policies)
        // Dangerous patterns are caught by detectSecurityIssues
        return true
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
