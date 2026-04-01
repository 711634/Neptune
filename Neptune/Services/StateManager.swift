import Foundation
import Combine
import os

// MARK: - Centralized Execution State

/// Centralized execution state holder for a task/project execution session.
/// This actor owns complete lifecycle state including messages, permission decisions,
/// usage metrics, and file modifications tracking.
actor SessionState: Sendable {
    // MARK: - Message History

    private(set) var executionMessages: [ExecutionMessage] = []
    private(set) var compressedHistory: String?  // Summarized older messages

    // MARK: - Permission Tracking

    private(set) var permissionDecisions: [PermissionDecision] = []
    private(set) var permissionDenials: [PermissionDenial] = []

    // MARK: - Usage Tracking

    private(set) var totalTokensUsed: Int = 0
    private(set) var totalCostUSD: Double = 0.0

    // MARK: - Execution Budgets

    private(set) var tokenBudget: Int = Int.max
    private(set) var usdBudget: Double = Double.infinity
    private(set) var isOverBudget: Bool = false
    private(set) var stopReason: ExecutionStopReason?

    // MARK: - Execution Guardrails

    private var guardrails: ExecutionGuardrails?

    // MARK: - File Modification Tracking

    private(set) var fileModifications: [FileModification] = []

    // MARK: - Cancellation

    private(set) var abortController: AbortController?

    // MARK: - Initialization

    init(tokenBudget: Int = Int.max, usdBudget: Double = Double.infinity) {
        self.tokenBudget = tokenBudget
        self.usdBudget = usdBudget
    }

    // MARK: - Message Management

    func appendMessage(_ message: ExecutionMessage) {
        executionMessages.append(message)
    }

    func getAllMessages() -> [ExecutionMessage] {
        executionMessages
    }

    /// Compacts old messages, keeping recent ones and summarizing the rest
    func compactMessages(keepRecent: Int = 50) {
        guard executionMessages.count > keepRecent else {
            return  // Not enough messages to compact
        }

        let recentMessages = Array(executionMessages.suffix(keepRecent))
        let oldMessages = Array(executionMessages.prefix(executionMessages.count - keepRecent))

        // Summarize old messages
        let summary = summarizeMessages(oldMessages)
        compressedHistory = summary

        // Keep only recent messages
        executionMessages = recentMessages
    }

    /// Returns messages including compressed history
    func getCompactedMessages() -> [ExecutionMessage] {
        if let compressed = compressedHistory {
            let summaryMessage = ExecutionMessage(
                id: UUID().uuidString,
                timestamp: Date(),
                type: .status,
                content: "[Context Compaction]\n" + compressed,
                agentId: nil,
                taskId: nil,
                metadata: ["isCompressed": "true"]
            )
            return [summaryMessage] + executionMessages
        }
        return executionMessages
    }

    /// Summarizes messages for context compaction
    private func summarizeMessages(_ messages: [ExecutionMessage]) -> String {
        guard !messages.isEmpty else { return "" }

        var summary = "=== Execution Summary (First \(messages.count) messages) ===\n"

        // Count by type
        var counts: [ExecutionMessageType: Int] = [:]
        for message in messages {
            counts[message.type, default: 0] += 1
        }

        summary += "Message counts: "
        summary += counts.map { "\($0.key.rawValue)=\($0.value)" }.joined(separator: ", ")
        summary += "\n"

        // Extract key events (errors, task completions)
        let errors = messages.filter { $0.type == .error }
        let decisions = messages.filter { $0.type == .decision }

        if !errors.isEmpty {
            summary += "Errors encountered: \(errors.count)\n"
            if let firstError = errors.first {
                summary += "  First error: \(firstError.content.prefix(100))...\n"
            }
        }

        if !decisions.isEmpty {
            summary += "Decisions made: \(decisions.count)\n"
        }

        summary += "Timeline: \(messages.first?.timestamp ?? Date()) → \(messages.last?.timestamp ?? Date())\n"

        return summary
    }

    // MARK: - Permission Decision Management

    func recordPermissionDecision(_ decision: PermissionDecision) {
        permissionDecisions.append(decision)
    }

    func recordPermissionDenial(_ denial: PermissionDenial) {
        permissionDenials.append(denial)
    }

    func getAllPermissionDecisions() -> [PermissionDecision] {
        permissionDecisions
    }

    func getAllDenials() -> [PermissionDenial] {
        permissionDenials
    }

    // MARK: - Usage Tracking

    func addTokenUsage(_ tokens: Int) {
        totalTokensUsed += tokens
        checkBudgets()
    }

    func addCost(_ amount: Double) {
        totalCostUSD += amount
        checkBudgets()
    }

    func getUsageMetrics() -> (tokens: Int, costUSD: Double) {
        (totalTokensUsed, totalCostUSD)
    }

    // MARK: - Budget Management

    func setBudgets(tokenBudget: Int, usdBudget: Double) {
        self.tokenBudget = tokenBudget
        self.usdBudget = usdBudget
        checkBudgets()
    }

    func checkBudgets() {
        let tokenExceeded = totalTokensUsed >= tokenBudget
        let costExceeded = totalCostUSD >= usdBudget

        if tokenExceeded || costExceeded {
            isOverBudget = true
            if tokenExceeded && stopReason == nil {
                stopReason = .tokenBudgetExceeded
            } else if costExceeded && stopReason == nil {
                stopReason = .costBudgetExceeded
            }
        }
    }

    func getRemainingBudget() -> (tokensRemaining: Int, costRemaining: Double) {
        (max(0, tokenBudget - totalTokensUsed), max(0, usdBudget - totalCostUSD))
    }

    func getStopReason() -> ExecutionStopReason? {
        stopReason
    }

    func setStopReason(_ reason: ExecutionStopReason) {
        stopReason = reason
    }

    // MARK: - Guardrails Management

    func initializeGuardrails(config: GuardrailConfig = .default) {
        guardrails = ExecutionGuardrails(config: config)
    }

    func checkIterationAllowed() async throws {
        guard let guardrails else { return }
        let (allowed, reason) = try await guardrails.checkIterationAllowed()
        if !allowed {
            stopReason = .maxIterationsExceeded
            throw NSError(domain: "Guardrails", code: -1, userInfo: [NSLocalizedDescriptionKey: reason ?? "Iteration limit reached"])
        }
    }

    func checkToolCallAllowed() async throws {
        guard let guardrails else { return }
        let (allowed, reason) = try await guardrails.checkToolCallAllowed()
        if !allowed {
            throw NSError(domain: "Guardrails", code: -1, userInfo: [NSLocalizedDescriptionKey: reason ?? "Tool call limit reached"])
        }
    }

    func recordTaskCompletion() async {
        if let guardrails {
            await guardrails.recordTaskCompletion()
        }
    }

    func recordTaskFailure() async {
        if let guardrails {
            await guardrails.recordTaskFailure()
        }
    }

    func getExecutionHealth() async -> ExecutionHealth? {
        guard let guardrails else { return nil }
        return await guardrails.checkHealth()
    }

    func getGuardrailsSummary() async -> GuardrailsSummary? {
        guard let guardrails else { return nil }
        return await guardrails.getSummary()
    }

    // MARK: - File Modification Tracking

    func recordFileModification(_ modification: FileModification) {
        fileModifications.append(modification)
    }

    func getFileModifications() -> [FileModification] {
        fileModifications
    }

    func getFileModifications(for toolId: String) -> [FileModification] {
        fileModifications.filter { $0.toolId == toolId }
    }

    // MARK: - Abort/Cancellation

    func setAbortController(_ controller: AbortController) {
        abortController = controller
    }

    func isAborted() -> Bool {
        abortController?.isCancelled ?? false
    }

    // MARK: - State Reset

    func reset() {
        executionMessages.removeAll()
        permissionDecisions.removeAll()
        permissionDenials.removeAll()
        totalTokensUsed = 0
        totalCostUSD = 0.0
        fileModifications.removeAll()
        abortController = nil
    }
}

// MARK: - Supporting Types for SessionState

/// Represents a single execution message (prompt, output, etc.)
struct ExecutionMessage: Codable, Sendable {
    let id: String
    let timestamp: Date
    let type: ExecutionMessageType
    let content: String
    let agentId: String?
    let taskId: String?
    let metadata: [String: String]?
}

enum ExecutionMessageType: String, Codable, Sendable {
    case prompt
    case output
    case error
    case decision
    case status
}

/// Permission denial record (user explicitly denied or security check blocked)
struct PermissionDenial: Codable, Sendable {
    let toolName: String
    let reason: String
    let timestamp: Date
    let agentId: String
    let projectId: String
    let metadata: [String: String]?
}

/// File modification record for audit trail
struct FileModification: Codable, Sendable {
    let toolId: String
    let path: String
    let operation: FileOperation  // "create", "modify", "delete"
    let timestamp: Date
    let contentHash: String?  // SHA256 hash if available
}

enum FileOperation: String, Codable, Sendable {
    case create
    case modify
    case delete
}

/// Abort/cancellation controller
final class AbortController: @unchecked Sendable {
    private let _isCancelled = OSAllocatedUnfairLock(initialState: false)

    var isCancelled: Bool {
        _isCancelled.withLock { $0 }
    }

    func cancel() {
        _isCancelled.withLock { $0 = true }
    }
}

// MARK: - Tool Execution Boundary

/// Unified execution boundary for tools with permission checking, telemetry, and file tracking
actor ToolExecutor: Sendable {
    private let sessionState: SessionState
    private let stateManager: StateManager

    init(sessionState: SessionState, stateManager: StateManager) {
        self.sessionState = sessionState
        self.stateManager = stateManager
    }

    /// Log tool execution with telemetry and file tracking
    func recordToolExecution(
        toolName: String,
        agentId: String,
        projectId: String,
        taskId: String?,
        duration: TimeInterval,
        status: String,  // "success", "failed", "blocked"
        filesModified: [String],
        error: Error? = nil
    ) async throws {
        let executionId = UUID().uuidString

        // Record file modifications
        for filePath in filesModified {
            let modification = FileModification(
                toolId: toolName,
                path: filePath,
                operation: .modify,
                timestamp: Date(),
                contentHash: nil
            )
            await sessionState.recordFileModification(modification)
        }

        // Log execution message
        let message = ExecutionMessage(
            id: UUID().uuidString,
            timestamp: Date(),
            type: status == "success" ? .status : .error,
            content: """
            Tool \(toolName) \(status == "success" ? "completed" : "failed") \
            in \(String(format: "%.2f", duration))s
            \(error.map { "Error: \($0.localizedDescription)" } ?? "")
            """,
            agentId: agentId,
            taskId: taskId,
            metadata: [
                "toolName": toolName,
                "status": status,
                "duration": String(format: "%.2f", duration),
                "filesModified": String(filesModified.count),
                "executionId": executionId
            ]
        )
        await sessionState.appendMessage(message)

        // Log permission decision based on execution outcome
        try await stateManager.logPermissionDecision(
            toolName: toolName,
            decision: status == "success" ? "allow" : "deny",
            source: status == "success" ? .config : .classifier,
            reasonType: status == "success" ? "execution_success" : "execution_error",
            reason: status == "success" ? "Tool completed successfully" : (error?.localizedDescription ?? "Tool execution failed"),
            agentId: agentId,
            projectId: projectId,
            metadata: [
                "executionId": executionId,
                "status": status,
                "duration": String(format: "%.2f", duration),
                "filesModified": String(filesModified.count)
            ]
        )
    }
}

// MARK: - Permission Decision Types

// OTel-compliant permission decision source
enum PermissionSource: String, Codable, Sendable {
    case userTemporary = "user_temporary"  // Session-scoped allow
    case userPermanent = "user_permanent"  // On-disk allow
    case userReject = "user_reject"        // User deny (session or permanent)
    case config                            // Config, policy, or rule-based
    case hook                              // Pre/post-tool hook decision
    case classifier                        // Security classifier (e.g., bash)
    case other                             // Other sources
}

// Permission decision with source and classification
struct PermissionDecision: Codable, Sendable {
    let toolName: String
    let decision: String  // "allow", "deny", "ask"
    let source: PermissionSource  // Where the decision came from
    let reasonType: String?  // "rule", "hook", "classifier", "userPrompt", etc.
    let reason: String?  // Details about why the decision was made
    let timestamp: Date
    let agentId: String
    let projectId: String
    let metadata: [String: String]?  // Extensible metadata (segments, affected paths, etc.)
}

// Session checkpoint for resumability
struct SessionCheckpoint: Codable {
    let projectId: String
    let timestamp: Date
    let completedTaskIds: [String]
    let totalTokensUsed: Int
    let totalCostUSD: Double
    let agents: [Agent]
    let taskGraph: TaskGraph

    init(
        projectId: String,
        agents: [String: Agent],
        taskGraph: TaskGraph,
        totalTokensUsed: Int = 0,
        totalCostUSD: Double = 0
    ) {
        self.projectId = projectId
        self.timestamp = Date()
        self.completedTaskIds = taskGraph.tasks.values
            .filter { $0.status == .completed }
            .map { $0.id }
        self.totalTokensUsed = totalTokensUsed
        self.totalCostUSD = totalCostUSD
        self.agents = Array(agents.values)
        self.taskGraph = taskGraph
    }
}

actor StateManager {
    private let projectsDir: URL
    private var fileWatcher: DispatchSourceFileSystemObject?
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private var changeCallback: ((String, Agent) -> Void)?

    nonisolated let fileQueue = DispatchQueue(label: "com.neptune.state-manager", attributes: .concurrent)

    init(projectsDir: URL? = nil) {
        let baseDir = projectsDir ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".neptune/projects")

        // Create directories if needed
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)

        self.projectsDir = baseDir
    }

    // MARK: - Project Persistence

    func saveProject(_ project: ProjectContext) async throws {
        let projectDir = projectsDir.appendingPathComponent(project.id)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let projectFile = projectDir.appendingPathComponent("project.json")
        let data = try jsonEncoder.encode(project)
        try data.write(to: projectFile)
    }

    func loadProject(id: String) async throws -> ProjectContext {
        let projectFile = projectsDir.appendingPathComponent(id).appendingPathComponent("project.json")
        let data = try Data(contentsOf: projectFile)
        return try jsonDecoder.decode(ProjectContext.self, from: data)
    }

    func listProjects() async throws -> [ProjectContext] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil)

        var projects: [ProjectContext] = []
        for dir in contents where dir.hasDirectoryPath {
            if let project = try? await loadProject(id: dir.lastPathComponent) {
                projects.append(project)
            }
        }

        return projects.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Agent State Persistence

    func saveAgentState(_ agent: Agent, projectId: String) async throws {
        let agentDir = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("agents")
            .appendingPathComponent(agent.id)

        try FileManager.default.createDirectory(at: agentDir, withIntermediateDirectories: true)

        let stateFile = agentDir.appendingPathComponent("state.json")
        let data = try jsonEncoder.encode(agent)
        try data.write(to: stateFile)
    }

    func loadAgentState(agentId: String, projectId: String) async throws -> Agent {
        let stateFile = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("agents")
            .appendingPathComponent(agentId)
            .appendingPathComponent("state.json")

        let data = try Data(contentsOf: stateFile)
        return try jsonDecoder.decode(Agent.self, from: data)
    }

    // MARK: - Transcript Management

    func appendTranscript(agentId: String, projectId: String, lines: [String]) async throws {
        let transcriptFile = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("agents")
            .appendingPathComponent(agentId)
            .appendingPathComponent("transcript.log")

        let content = lines.joined(separator: "\n") + "\n"

        if FileManager.default.fileExists(atPath: transcriptFile.path) {
            if let fileHandle = FileHandle(forWritingAtPath: transcriptFile.path) {
                defer { try? fileHandle.close() }
                fileHandle.seekToEndOfFile()
                if let data = content.data(using: .utf8) {
                    fileHandle.write(data)
                }
            }
        } else {
            try content.write(to: transcriptFile, atomically: true, encoding: .utf8)
        }
    }

    func getTranscript(agentId: String, projectId: String) async throws -> [String] {
        let transcriptFile = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("agents")
            .appendingPathComponent(agentId)
            .appendingPathComponent("transcript.log")

        guard FileManager.default.fileExists(atPath: transcriptFile.path) else {
            return []
        }

        let content = try String(contentsOf: transcriptFile, encoding: .utf8)
        return content.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    // MARK: - Checkpoint Management (for resumability)

    func saveCheckpoint(agentId: String, projectId: String, data: [String: String]) async throws {
        let checkpointFile = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("agents")
            .appendingPathComponent(agentId)
            .appendingPathComponent("checkpoint.json")

        let encoded = try jsonEncoder.encode(data)
        try encoded.write(to: checkpointFile)
    }

    func loadCheckpoint(agentId: String, projectId: String) async throws -> [String: String]? {
        let checkpointFile = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("agents")
            .appendingPathComponent(agentId)
            .appendingPathComponent("checkpoint.json")

        guard FileManager.default.fileExists(atPath: checkpointFile.path) else {
            return nil
        }

        let data = try Data(contentsOf: checkpointFile)
        return try jsonDecoder.decode([String: String].self, from: data)
    }

    // MARK: - Task Graph Persistence

    func saveTaskGraph(_ graph: TaskGraph, projectId: String) async throws {
        let graphFile = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("task-graph.json")

        let data = try jsonEncoder.encode(graph)
        try data.write(to: graphFile)
    }

    func loadTaskGraph(projectId: String) async throws -> TaskGraph {
        let graphFile = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("task-graph.json")

        guard FileManager.default.fileExists(atPath: graphFile.path) else {
            return TaskGraph()
        }

        let data = try Data(contentsOf: graphFile)
        return try jsonDecoder.decode(TaskGraph.self, from: data)
    }

    // MARK: - Artifact Tracking

    func recordArtifact(projectId: String, path: String) async throws {
        let artifactDir = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("artifacts")

        try FileManager.default.createDirectory(at: artifactDir, withIntermediateDirectories: true)

        // Just record the path in a manifest
        let manifestFile = artifactDir.appendingPathComponent("manifest.json")
        var artifacts: [String] = []

        if FileManager.default.fileExists(atPath: manifestFile.path) {
            if let data = try? Data(contentsOf: manifestFile) {
                artifacts = (try? jsonDecoder.decode([String].self, from: data)) ?? []
            }
        }

        if !artifacts.contains(path) {
            artifacts.append(path)
        }

        let data = try jsonEncoder.encode(artifacts)
        try data.write(to: manifestFile)
    }

    // MARK: - Session Checkpoint (for resumability)

    func saveSessionCheckpoint(
        projectId: String,
        agents: [String: Agent],
        taskGraph: TaskGraph,
        totalTokensUsed: Int = 0,
        totalCostUSD: Double = 0
    ) async throws {
        let checkpoint = SessionCheckpoint(
            projectId: projectId,
            agents: agents,
            taskGraph: taskGraph,
            totalTokensUsed: totalTokensUsed,
            totalCostUSD: totalCostUSD
        )

        let checkpointFile = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("session-checkpoint.json")

        let data = try jsonEncoder.encode(checkpoint)
        try data.write(to: checkpointFile)
    }

    func loadSessionCheckpoint(projectId: String) async throws -> SessionCheckpoint? {
        let checkpointFile = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("session-checkpoint.json")

        guard FileManager.default.fileExists(atPath: checkpointFile.path) else {
            return nil
        }

        let data = try Data(contentsOf: checkpointFile)
        return try jsonDecoder.decode(SessionCheckpoint.self, from: data)
    }

    // MARK: - Permission Decision Tracking

    func logPermissionDecision(
        toolName: String,
        decision: String,
        source: PermissionSource,
        reasonType: String? = nil,
        reason: String? = nil,
        agentId: String,
        projectId: String,
        metadata: [String: String]? = nil
    ) async throws {
        let decisionRecord = PermissionDecision(
            toolName: toolName,
            decision: decision,
            source: source,
            reasonType: reasonType,
            reason: reason,
            timestamp: Date(),
            agentId: agentId,
            projectId: projectId,
            metadata: metadata
        )

        let decisionFile = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("permissions")
            .appendingPathComponent("decisions.jsonl")

        // Ensure directory exists
        try FileManager.default.createDirectory(
            at: decisionFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Append as JSONL (one JSON object per line)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(decisionRecord)
        let jsonLine = String(data: data, encoding: .utf8) ?? ""

        if FileManager.default.fileExists(atPath: decisionFile.path) {
            if let fileHandle = FileHandle(forWritingAtPath: decisionFile.path) {
                defer { try? fileHandle.close() }
                fileHandle.seekToEndOfFile()
                if let lineData = (jsonLine + "\n").data(using: .utf8) {
                    fileHandle.write(lineData)
                }
            }
        } else {
            try (jsonLine + "\n").write(to: decisionFile, atomically: true, encoding: .utf8)
        }
    }

    func getPermissionDecisions(agentId: String, projectId: String) async throws -> [PermissionDecision] {
        let decisionFile = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("permissions")
            .appendingPathComponent("decisions.jsonl")

        guard FileManager.default.fileExists(atPath: decisionFile.path) else {
            return []
        }

        let content = try String(contentsOf: decisionFile, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var decisions: [PermissionDecision] = []
        for line in lines {
            if let data = line.data(using: .utf8),
               let decision = try? decoder.decode(PermissionDecision.self, from: data) {
                if decision.agentId == agentId {
                    decisions.append(decision)
                }
            }
        }

        return decisions.sorted { $0.timestamp < $1.timestamp }
    }

    func getPermissionDecisions(projectId: String) async throws -> [PermissionDecision] {
        let decisionFile = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("permissions")
            .appendingPathComponent("decisions.jsonl")

        guard FileManager.default.fileExists(atPath: decisionFile.path) else {
            return []
        }

        let content = try String(contentsOf: decisionFile, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var decisions: [PermissionDecision] = []
        for line in lines {
            if let data = line.data(using: .utf8),
               let decision = try? decoder.decode(PermissionDecision.self, from: data) {
                decisions.append(decision)
            }
        }

        return decisions.sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Directory Access

    nonisolated func projectDirectory(for projectId: String) -> URL {
        projectsDir.appendingPathComponent(projectId)
    }

    nonisolated func agentDirectory(for agentId: String, in projectId: String) -> URL {
        projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("agents")
            .appendingPathComponent(agentId)
    }

    nonisolated func workspaceDirectory(for projectId: String) -> URL {
        projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("workspace")
    }
}

// MARK: - File Safety Validation

/// Validates file operations against scope rules before tool execution
actor SafetyValidator: Sendable {
    // Configuration: allowed directories per project
    private var projectScopes: [String: [String]] = [:]  // projectId → allowedDirs

    init() {}

    // MARK: - Configuration

    func configureProjectScope(
        projectId: String,
        allowedDirectories: [String]
    ) async {
        projectScopes[projectId] = allowedDirectories
    }

    func addAllowedDirectory(
        projectId: String,
        directory: String
    ) async {
        if projectScopes[projectId] != nil {
            projectScopes[projectId]?.append(directory)
        } else {
            projectScopes[projectId] = [directory]
        }
    }

    // MARK: - Validation

    /// Validate a file operation against scope rules
    func validateFileOperation(
        projectId: String,
        filePath: String,
        operation: FileOperationType,
        workspaceRoot: String
    ) -> FileValidationResult {
        // Normalize paths for comparison
        let normalizedPath = normalizePath(filePath)
        let normalizedRoot = normalizePath(workspaceRoot)

        // Get allowed directories for this project
        let allowedDirs = projectScopes[projectId] ?? [normalizedRoot]

        // Check if file is within allowed scope
        let isInScope = allowedDirs.contains { allowedDir in
            let normalizedAllowed = normalizePath(allowedDir)
            return normalizedPath.hasPrefix(normalizedAllowed) ||
                   normalizedPath == normalizedAllowed
        }

        guard isInScope else {
            return FileValidationResult(
                isAllowed: false,
                filePath: filePath,
                operation: operation,
                reason: "File path '\(filePath)' is outside allowed project scope",
                severity: .deny,
                allowedScope: allowedDirs
            )
        }

        // Check for dangerous patterns based on operation type
        let dangerousPatterns = detectDangerousPatterns(
            filePath: normalizedPath,
            operation: operation
        )

        if !dangerousPatterns.isEmpty {
            return FileValidationResult(
                isAllowed: false,
                filePath: filePath,
                operation: operation,
                reason: "Dangerous file operation detected: \(dangerousPatterns.joined(separator: ", "))",
                severity: .deny,
                allowedScope: allowedDirs,
                detectedIssues: dangerousPatterns
            )
        }

        // Operation is allowed
        return FileValidationResult(
            isAllowed: true,
            filePath: filePath,
            operation: operation,
            reason: "File operation is within allowed scope",
            severity: .allow,
            allowedScope: allowedDirs
        )
    }

    /// Validate multiple file operations in a batch
    func validateBatch(
        projectId: String,
        operations: [FileOperationRequest],
        workspaceRoot: String
    ) -> BatchValidationResult {
        var results: [FileValidationResult] = []
        var hasErrors = false

        for op in operations {
            let result = validateFileOperation(
                projectId: projectId,
                filePath: op.filePath,
                operation: op.operation,
                workspaceRoot: workspaceRoot
            )

            results.append(result)

            if !result.isAllowed {
                hasErrors = true
            }
        }

        return BatchValidationResult(
            operations: results,
            allAllowed: !hasErrors,
            deniedCount: results.filter { !$0.isAllowed }.count
        )
    }

    // MARK: - Private Helpers

    private func normalizePath(_ path: String) -> String {
        // Expand ~ to home directory
        let expanded = path.replacingOccurrences(of: "~", with: NSHomeDirectory())

        // Resolve symlinks and relative paths
        let url = URL(fileURLWithPath: expanded)
        return (try? url.standardizedFileURL.path) ?? expanded
    }

    private func detectDangerousPatterns(
        filePath: String,
        operation: FileOperationType
    ) -> [String] {
        var issues: [String] = []

        // Check for system directories (macOS)
        let systemDirs = ["/System", "/Library", "/Applications", "/bin", "/sbin", "/usr/bin", "/usr/sbin"]
        for sysDir in systemDirs {
            if filePath.hasPrefix(sysDir) {
                issues.append("Attempt to write to system directory: \(sysDir)")
            }
        }

        // Check for dangerous file extensions based on operation
        if operation == .create || operation == .modify {
            let dangerousExtensions = [".plist", ".launchd", ".sh", ".bash"]
            for ext in dangerousExtensions {
                if filePath.hasSuffix(ext) {
                    issues.append("Dangerous file type: \(ext)")
                }
            }
        }

        // Check for path traversal attempts
        if filePath.contains("/../") || filePath.contains("/..\\") {
            issues.append("Potential path traversal attack detected")
        }

        return issues
    }
}

// MARK: - File Operation Types

enum FileOperationType: String, Codable, Sendable, Equatable {
    case read
    case create
    case modify
    case delete
}

struct FileOperationRequest: Sendable {
    let filePath: String
    let operation: FileOperationType
}

struct FileValidationResult: Sendable, Equatable {
    let isAllowed: Bool
    let filePath: String
    let operation: FileOperationType
    let reason: String
    let severity: ValidationSeverity
    let allowedScope: [String]
    let detectedIssues: [String]?

    init(
        isAllowed: Bool,
        filePath: String,
        operation: FileOperationType,
        reason: String,
        severity: ValidationSeverity,
        allowedScope: [String],
        detectedIssues: [String]? = nil
    ) {
        self.isAllowed = isAllowed
        self.filePath = filePath
        self.operation = operation
        self.reason = reason
        self.severity = severity
        self.allowedScope = allowedScope
        self.detectedIssues = detectedIssues
    }
}

enum ValidationSeverity: String, Sendable {
    case allow
    case ask
    case deny
}

struct BatchValidationResult: Sendable {
    let operations: [FileValidationResult]
    let allAllowed: Bool
    let deniedCount: Int

    var summary: String {
        if allAllowed {
            return "All \(operations.count) file operations are allowed"
        } else {
            return "\(deniedCount) of \(operations.count) operations were denied"
        }
    }
}

// MARK: - Permission Enforcement Gate

/// Enforces permission decisions for tool execution
actor PermissionGate: Sendable {
    private let sessionState: SessionState
    private let stateManager: StateManager
    private let safetyValidator: SafetyValidator

    private var permissionMode: PermissionMode = .allow
    private var deniedTools: Set<String> = []  // Tools explicitly denied by user
    private var approvedTools: Set<String> = []  // Tools explicitly approved by user

    init(
        sessionState: SessionState,
        stateManager: StateManager,
        safetyValidator: SafetyValidator
    ) {
        self.sessionState = sessionState
        self.stateManager = stateManager
        self.safetyValidator = safetyValidator
    }

    // MARK: - Configuration

    func setPermissionMode(_ mode: PermissionMode) {
        permissionMode = mode
    }

    func denyTool(_ toolName: String) {
        deniedTools.insert(toolName)
        approvedTools.remove(toolName)
    }

    func approveTool(_ toolName: String) {
        approvedTools.insert(toolName)
        deniedTools.remove(toolName)
    }

    // MARK: - Permission Checks

    /// Check if a tool execution is allowed
    func checkToolExecution(
        toolName: String,
        projectId: String,
        agentId: String
    ) async throws -> PermissionDecision {
        // Check explicit denials first (highest priority)
        if deniedTools.contains(toolName) {
            let denial = PermissionDenial(
                toolName: toolName,
                reason: "Tool explicitly denied by user or policy",
                timestamp: Date(),
                agentId: agentId,
                projectId: projectId,
                metadata: nil
            )
            await sessionState.recordPermissionDenial(denial)

            try await stateManager.logPermissionDecision(
                toolName: toolName,
                decision: "deny",
                source: .userTemporary,
                reasonType: "tool_denied",
                reason: "Tool \(toolName) is on deny list",
                agentId: agentId,
                projectId: projectId,
                metadata: nil
            )

            throw PermissionError.toolDenied(toolName)
        }

        // Check approvals
        if approvedTools.contains(toolName) {
            try await stateManager.logPermissionDecision(
                toolName: toolName,
                decision: "allow",
                source: .userTemporary,
                reasonType: "tool_approved",
                reason: "Tool \(toolName) is on approval list",
                agentId: agentId,
                projectId: projectId,
                metadata: nil
            )
            return PermissionDecision(
                toolName: toolName,
                decision: "allow",
                source: .userTemporary,
                reasonType: "tool_approved",
                reason: "Tool is approved",
                timestamp: Date(),
                agentId: agentId,
                projectId: projectId,
                metadata: nil
            )
        }

        // Check permission mode
        switch permissionMode {
        case .allow:
            try await stateManager.logPermissionDecision(
                toolName: toolName,
                decision: "allow",
                source: .config,
                reasonType: "permission_mode",
                reason: "Permission mode is 'allow'",
                agentId: agentId,
                projectId: projectId,
                metadata: nil
            )
            return PermissionDecision(
                toolName: toolName,
                decision: "allow",
                source: .config,
                reasonType: "permission_mode",
                reason: "Permission mode allows all",
                timestamp: Date(),
                agentId: agentId,
                projectId: projectId,
                metadata: nil
            )

        case .deny:
            let denial = PermissionDenial(
                toolName: toolName,
                reason: "Permission mode is 'deny'",
                timestamp: Date(),
                agentId: agentId,
                projectId: projectId,
                metadata: nil
            )
            await sessionState.recordPermissionDenial(denial)

            try await stateManager.logPermissionDecision(
                toolName: toolName,
                decision: "deny",
                source: .config,
                reasonType: "permission_mode",
                reason: "Permission mode is 'deny'",
                agentId: agentId,
                projectId: projectId,
                metadata: nil
            )

            throw PermissionError.deniedByPolicy("Permission mode is deny")

        case .ask:
            // In ask mode, we would show a UI prompt (stub for now)
            try await stateManager.logPermissionDecision(
                toolName: toolName,
                decision: "ask",
                source: .config,
                reasonType: "permission_mode",
                reason: "Permission mode is 'ask'",
                agentId: agentId,
                projectId: projectId,
                metadata: nil
            )
            return PermissionDecision(
                toolName: toolName,
                decision: "ask",
                source: .config,
                reasonType: "permission_mode",
                reason: "User approval required",
                timestamp: Date(),
                agentId: agentId,
                projectId: projectId,
                metadata: nil
            )
        }
    }

    /// Check if file operations are allowed
    func checkFileOperations(
        projectId: String,
        operations: [FileOperationRequest],
        workspaceRoot: String,
        agentId: String
    ) async throws -> BatchValidationResult {
        let validationResult = await safetyValidator.validateBatch(
            projectId: projectId,
            operations: operations,
            workspaceRoot: workspaceRoot
        )

        // Log each validation
        for result in validationResult.operations {
            try await stateManager.logPermissionDecision(
                toolName: "fileOperation",
                decision: result.severity.rawValue,
                source: .classifier,
                reasonType: "file_scope_validation",
                reason: result.reason,
                agentId: agentId,
                projectId: projectId,
                metadata: [
                    "filePath": result.filePath,
                    "operation": result.operation.rawValue,
                    "severity": result.severity.rawValue
                ]
            )
        }

        // If any operations were denied, throw error with details
        if !validationResult.allAllowed {
            let deniedOps = validationResult.operations.filter { !$0.isAllowed }
            let reasons = deniedOps.map { $0.reason }.joined(separator: "; ")
            throw PermissionError.fileOperationDenied(reasons)
        }

        return validationResult
    }
}

// MARK: - Permission Errors

enum PermissionError: LocalizedError, Sendable {
    case toolDenied(String)
    case deniedByPolicy(String)
    case fileOperationDenied(String)

    var errorDescription: String? {
        switch self {
        case .toolDenied(let tool):
            return "Tool '\(tool)' is not permitted to execute"
        case .deniedByPolicy(let reason):
            return "Permission denied: \(reason)"
        case .fileOperationDenied(let reason):
            return "File operation denied: \(reason)"
        }
    }
}

// MARK: - Permission Mode

enum PermissionMode: String, Sendable {
    case allow    // All tools allowed
    case deny     // All tools denied
    case ask      // User approval required
}

// MARK: - Execution Stop Reasons

/// Classifies why execution stopped
enum ExecutionStopReason: String, Codable, Sendable {
    case completed              // Task completed successfully
    case failed                 // Task failed with error
    case tokenBudgetExceeded    // Token limit reached
    case costBudgetExceeded     // Cost limit reached
    case userCancelled          // User cancelled execution
    case timeout                // Execution timed out
    case permissionDenied       // Permission check failed
    case circuitBreakerOpen     // Circuit breaker prevented retry
    case maxRetriesExceeded     // Retry limit reached
    case contextLimitExceeded   // Context window limit reached
    case maxIterationsExceeded  // Iteration limit reached
    case maxToolCallsExceeded   // Tool call limit reached
    case noProgressDetected     // No progress for timeout period
    case maxConsecutiveFailures // Too many consecutive failures
    case resourceUnavailable    // Required resource unavailable
    case unknown                // Unknown reason

    var description: String {
        switch self {
        case .completed:
            return "Completed successfully"
        case .failed:
            return "Failed with error"
        case .tokenBudgetExceeded:
            return "Token budget exceeded"
        case .costBudgetExceeded:
            return "Cost budget exceeded"
        case .userCancelled:
            return "Cancelled by user"
        case .timeout:
            return "Execution timeout"
        case .permissionDenied:
            return "Permission denied"
        case .circuitBreakerOpen:
            return "Circuit breaker open"
        case .maxRetriesExceeded:
            return "Max retries exceeded"
        case .contextLimitExceeded:
            return "Context limit exceeded"
        case .maxIterationsExceeded:
            return "Iteration limit exceeded"
        case .maxToolCallsExceeded:
            return "Tool call limit exceeded"
        case .noProgressDetected:
            return "No progress detected"
        case .maxConsecutiveFailures:
            return "Max consecutive failures"
        case .resourceUnavailable:
            return "Resource unavailable"
        case .unknown:
            return "Unknown reason"
        }
    }

    var isFailure: Bool {
        switch self {
        case .completed:
            return false
        default:
            return true
        }
    }
}

// MARK: - Delegation Boundaries

/// Represents a delegated task to a sub-agent or specialized tool
struct DelegatedTask: Codable, Sendable {
    let id: String
    let delegatingAgentId: String
    let delegateType: DelegateType
    let prompt: String
    let context: [String: String]?
    let expectedOutputFormat: String?
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var result: String?
    var error: String?
    var status: DelegationStatus = .pending
}

enum DelegateType: String, Codable, Sendable {
    case agent
    case tool
    case service
}

enum DelegationStatus: String, Codable, Sendable {
    case pending
    case inProgress
    case completed
    case failed
}

/// Lightweight interface for agent delegation
actor DelegationBoundary: Sendable {
    private var delegatedTasks: [String: DelegatedTask] = [:]
    private let sessionState: SessionState
    private let logger = Logger(subsystem: "com.neptune.delegation", category: "boundary")

    init(sessionState: SessionState) {
        self.sessionState = sessionState
    }

    /// Creates a delegation request
    func delegate(
        fromAgent: String,
        type: DelegateType,
        prompt: String,
        context: [String: String]? = nil,
        expectedFormat: String? = nil
    ) -> DelegatedTask {
        let task = DelegatedTask(
            id: UUID().uuidString,
            delegatingAgentId: fromAgent,
            delegateType: type,
            prompt: prompt,
            context: context,
            expectedOutputFormat: expectedFormat,
            createdAt: Date()
        )

        delegatedTasks[task.id] = task
        logger.debug("Delegation \(task.id) created for agent \(fromAgent)")

        return task
    }

    /// Records delegation result
    func recordResult(taskId: String, result: String) async throws {
        guard var task = delegatedTasks[taskId] else {
            throw NSError(domain: "Delegation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Task not found"])
        }

        task.result = result
        task.status = .completed
        task.completedAt = Date()
        delegatedTasks[taskId] = task

        let message = ExecutionMessage(
            id: UUID().uuidString,
            timestamp: Date(),
            type: .output,
            content: "Delegation completed: \(result.prefix(200))",
            agentId: task.delegatingAgentId,
            taskId: taskId,
            metadata: ["status": "completed"]
        )
        await sessionState.appendMessage(message)

        logger.debug("Delegation \(taskId) completed")
    }

    /// Records delegation failure
    func recordError(taskId: String, error: Error) async throws {
        guard var task = delegatedTasks[taskId] else {
            throw NSError(domain: "Delegation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Task not found"])
        }

        task.error = error.localizedDescription
        task.status = .failed
        task.completedAt = Date()
        delegatedTasks[taskId] = task

        let message = ExecutionMessage(
            id: UUID().uuidString,
            timestamp: Date(),
            type: .error,
            content: "Delegation failed: \(error.localizedDescription)",
            agentId: task.delegatingAgentId,
            taskId: taskId,
            metadata: ["status": "failed"]
        )
        await sessionState.appendMessage(message)

        logger.error("Delegation \(taskId) failed: \(error.localizedDescription)")
    }

    /// Gets delegation status
    func getStatus(taskId: String) -> DelegationStatus? {
        delegatedTasks[taskId]?.status
    }

    /// Gets all pending delegations
    func getPending() -> [DelegatedTask] {
        delegatedTasks.values.filter { $0.status == .pending }.sorted { $0.createdAt < $1.createdAt }
    }

    /// Gets delegation history
    func getHistory() -> [DelegatedTask] {
        Array(delegatedTasks.values).sorted { $0.createdAt > $1.createdAt }
    }
}

// MARK: - Error Classification for Retry/Recovery

/// Classifies errors as transient (retryable) or permanent (fatal)
enum ErrorClassification: Sendable, CustomStringConvertible {
    case transient(reason: String)  // Network timeouts, rate limits, temporary failures
    case permanent(reason: String)  // Permission errors, invalid input, resource not found
    case unknown(reason: String)    // Errors we haven't classified yet

    /// Determines if error is retryable
    var isRetryable: Bool {
        if case .transient = self {
            return true
        }
        return false
    }

    var description: String {
        switch self {
        case .transient(let reason):
            return "Transient: \(reason)"
        case .permanent(let reason):
            return "Permanent: \(reason)"
        case .unknown(let reason):
            return "Unknown: \(reason)"
        }
    }

    /// Classifies a generic Swift error
    static func classify(_ error: Error) -> ErrorClassification {
        let nsError = error as NSError

        // Network/transport errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet, NSURLErrorServerCertificateUntrusted:
                return .transient(reason: "Network error: \(error.localizedDescription)")
            case NSURLErrorCancelled, NSURLErrorBadURL, NSURLErrorUnsupportedURL:
                return .permanent(reason: "URL error: \(error.localizedDescription)")
            default:
                return .transient(reason: "Unknown network error: \(error.localizedDescription)")
            }
        }

        // Permission/policy errors
        if case .toolDenied = error as? PermissionError {
            return .permanent(reason: "Tool permission denied")
        }
        if case .deniedByPolicy = error as? PermissionError {
            return .permanent(reason: "Permission policy denial")
        }

        // Rate limiting (often in userInfo)
        if nsError.code == 429 || error.localizedDescription.contains("rate limit") {
            return .transient(reason: "Rate limited")
        }

        // Default: assume transient (better to retry than fail permanently)
        return .unknown(reason: error.localizedDescription)
    }
}


// MARK: - Circuit Breaker

/// Prevents cascading failures using circuit breaker pattern
actor CircuitBreaker: Sendable {
    enum State: Sendable {
        case closed           // Normal operation
        case open             // Failing, reject new attempts
        case halfOpen          // Testing if recovered
    }

    private var state: State = .closed
    private var failureCount: Int = 0
    private var successCount: Int = 0
    private var lastFailureTime: Date?

    private let failureThreshold: Int
    private let successThreshold: Int
    private let resetTimeoutSeconds: TimeInterval

    init(
        failureThreshold: Int = 5,
        successThreshold: Int = 2,
        resetTimeoutSeconds: TimeInterval = 60.0
    ) {
        self.failureThreshold = failureThreshold
        self.successThreshold = successThreshold
        self.resetTimeoutSeconds = resetTimeoutSeconds
    }

    /// Records a failure attempt
    func recordFailure() {
        failureCount += 1
        lastFailureTime = Date()

        if failureCount >= failureThreshold {
            state = .open
        }
    }

    /// Records a success attempt
    func recordSuccess() {
        switch state {
        case .closed:
            failureCount = max(0, failureCount - 1)
        case .halfOpen:
            successCount += 1
            if successCount >= successThreshold {
                state = .closed
                failureCount = 0
                successCount = 0
            }
        case .open:
            break  // No action on open state
        }
    }

    /// Checks if operation can be attempted
    func canAttempt() -> Bool {
        switch state {
        case .closed:
            return true
        case .open:
            // Check if reset timeout has elapsed
            if let lastFailureTime, Date().timeIntervalSince(lastFailureTime) >= resetTimeoutSeconds {
                state = .halfOpen
                successCount = 0
                return true
            }
            return false
        case .halfOpen:
            return true
        }
    }

    /// Gets current state for monitoring
    func getState() -> State {
        state
    }

    /// Resets circuit breaker to closed state
    func reset() {
        state = .closed
        failureCount = 0
        successCount = 0
        lastFailureTime = nil
    }
}

// MARK: - Recoverable Task Execution

/// Wraps operation with retry logic and circuit breaker protection
actor RetryableTaskExecution: Sendable {
    private let circuitBreaker: CircuitBreaker
    private let policy: RetryPolicy
    private let logger = Logger(subsystem: "com.neptune.retry", category: "execution")

    init(policy: RetryPolicy = RetryPolicy()) {
        self.policy = policy
        self.circuitBreaker = CircuitBreaker()
    }

    /// Executes operation with retry logic and circuit breaker
    func execute<T: Sendable>(
        id: String,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        // Check circuit breaker
        guard await circuitBreaker.canAttempt() else {
            let error = NSError(
                domain: "CircuitBreaker",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Circuit breaker is open"]
            )
            throw error
        }

        var lastError: Error?
        var lastClassification: ErrorClassification?
        let policy = self.policy  // Capture for use in closure

        for attempt in 0..<policy.maxAttempts {
            do {
                let result = try await operation()

                // Success
                await circuitBreaker.recordSuccess()
                logger.debug("Operation \(id) succeeded on attempt \(attempt + 1)/\(policy.maxAttempts)")
                return result

            } catch {
                lastError = error
                let classification = ErrorClassification.classify(error)
                lastClassification = classification

                // Permanent error: fail immediately
                if case .permanent = classification {
                    await circuitBreaker.recordFailure()
                    logger.warning("Operation \(id) failed with permanent error: \(classification)")
                    throw error
                }

                // Last attempt: fail
                if attempt == policy.maxAttempts - 1 {
                    await circuitBreaker.recordFailure()
                    logger.error("Operation \(id) failed after \(policy.maxAttempts) attempts")
                    throw error
                }

                // Retryable error: wait and retry
                let backoffMs = policy.backoffForAttempt(attempt)
                logger.debug("Operation \(id) attempt \(attempt + 1) failed, retrying in \(backoffMs)ms")

                // Sleep using ContinuousClock
                try await ContinuousClock().sleep(for: .milliseconds(backoffMs))
            }
        }

        // Should not reach here
        throw lastError ?? NSError(domain: "Unknown", code: -1)
    }

    /// Resets circuit breaker for testing
    func resetCircuitBreaker() async {
        await circuitBreaker.reset()
    }

    /// Gets circuit breaker state
    func getCircuitBreakerState() async -> CircuitBreaker.State {
        await circuitBreaker.getState()
    }
}

// MARK: - Observability & Telemetry

/// Lightweight telemetry span for operation tracing
struct ExecutionSpan: Codable, Sendable {
    let id: String
    let name: String
    let parentId: String?
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval? { endTime.map { $0.timeIntervalSince(startTime) } }
    var status: SpanStatus = .inProgress
    var attributes: [String: String] = [:]
    var events: [SpanEvent] = []

    enum SpanStatus: String, Codable, Sendable {
        case inProgress
        case completed
        case failed
        case cancelled
    }
}

/// Event within an execution span
struct SpanEvent: Codable, Sendable {
    let timestamp: Date
    let name: String
    let attributes: [String: String]?
}

/// Lightweight observability system for execution tracing
actor ExecutionObserver: Sendable {
    private var spans: [String: ExecutionSpan] = [:]
    private var spanStack: [String] = []
    private let logger = Logger(subsystem: "com.neptune.observability", category: "spans")

    /// Creates a new span
    func startSpan(name: String, attributes: [String: String]? = nil) -> String {
        let spanId = UUID().uuidString
        let parentId = spanStack.last

        var span = ExecutionSpan(
            id: spanId,
            name: name,
            parentId: parentId,
            startTime: Date()
        )
        if let attrs = attributes {
            span.attributes = attrs
        }

        spans[spanId] = span
        spanStack.append(spanId)

        logger.debug("Span started: \(name) [\(spanId)]")
        return spanId
    }

    /// Ends a span
    func endSpan(_ spanId: String, status: ExecutionSpan.SpanStatus = .completed) async {
        guard var span = spans[spanId] else {
            logger.warning("Span not found: \(spanId)")
            return
        }

        span.endTime = Date()
        span.status = status
        spans[spanId] = span

        if spanStack.last == spanId {
            spanStack.removeLast()
        }

        logger.debug("Span ended: \(span.name) [\(spanId)] - \(String(format: "%.3f", span.duration ?? 0))s")
    }

    /// Adds an event to a span
    func addEvent(to spanId: String, name: String, attributes: [String: String]? = nil) async {
        guard var span = spans[spanId] else { return }

        let event = SpanEvent(timestamp: Date(), name: name, attributes: attributes)
        span.events.append(event)
        spans[spanId] = span
    }

    /// Gets span summary for monitoring
    func getSummary() -> ExecutionSummary {
        let allSpans = Array(spans.values)
        let totalDuration = allSpans
            .compactMap { $0.duration }
            .reduce(0, +)

        let failedCount = allSpans.filter { $0.status == .failed }.count
        let completedCount = allSpans.filter { $0.status == .completed }.count

        return ExecutionSummary(
            totalSpans: allSpans.count,
            completedSpans: completedCount,
            failedSpans: failedCount,
            totalDurationSeconds: totalDuration,
            spans: allSpans
        )
    }

    /// Gets critical path (deepest chain of spans)
    func getCriticalPath() -> [ExecutionSpan] {
        func buildChain(spanId: String?) -> [ExecutionSpan] {
            guard let id = spanId else { return [] }
            guard let span = spans[id] else { return [] }

            let children = spans.values.filter { $0.parentId == id }
            let deepestChild = children.max { a, b in
                buildChain(spanId: a.id).count < buildChain(spanId: b.id).count
            }

            return [span] + buildChain(spanId: deepestChild?.id)
        }

        let roots = spans.values.filter { $0.parentId == nil }
        let deepestRoot = roots.max { a, b in
            buildChain(spanId: a.id).count < buildChain(spanId: b.id).count
        }

        return buildChain(spanId: deepestRoot?.id)
    }

    /// Exports telemetry for external systems
    func export() -> ExecutionTelemetry {
        let spans = Array(spans.values)
        let summary = getSummary()
        let criticalPath = getCriticalPath()

        return ExecutionTelemetry(
            timestamp: Date(),
            summary: summary,
            criticalPath: criticalPath,
            allSpans: spans
        )
    }
}

/// Summary of execution telemetry
struct ExecutionSummary: Codable, Sendable {
    let totalSpans: Int
    let completedSpans: Int
    let failedSpans: Int
    let totalDurationSeconds: TimeInterval
    let spans: [ExecutionSpan]

    var successRate: Double {
        guard totalSpans > 0 else { return 0 }
        return Double(completedSpans) / Double(totalSpans)
    }

    var averageDurationPerSpan: TimeInterval {
        guard completedSpans > 0 else { return 0 }
        return totalDurationSeconds / Double(completedSpans)
    }
}

/// Complete telemetry export
struct ExecutionTelemetry: Codable, Sendable {
    let timestamp: Date
    let summary: ExecutionSummary
    let criticalPath: [ExecutionSpan]
    let allSpans: [ExecutionSpan]
}

// MARK: - Execution Guardrails

/// Configuration for execution limits and safety thresholds
struct GuardrailConfig: Sendable {
    let maxIterations: Int
    let maxToolCallsPerTask: Int
    let maxWallClockSeconds: TimeInterval
    let noProgressTimeoutSeconds: TimeInterval
    let maxConsecutiveFailures: Int

    static let `default` = GuardrailConfig(
        maxIterations: 100,
        maxToolCallsPerTask: 50,
        maxWallClockSeconds: 3600,  // 1 hour
        noProgressTimeoutSeconds: 300,  // 5 minutes
        maxConsecutiveFailures: 5
    )

    static let conservative = GuardrailConfig(
        maxIterations: 20,
        maxToolCallsPerTask: 10,
        maxWallClockSeconds: 600,  // 10 minutes
        noProgressTimeoutSeconds: 120,  // 2 minutes
        maxConsecutiveFailures: 3
    )

    static let aggressive = GuardrailConfig(
        maxIterations: 500,
        maxToolCallsPerTask: 200,
        maxWallClockSeconds: 7200,  // 2 hours
        noProgressTimeoutSeconds: 600,  // 10 minutes
        maxConsecutiveFailures: 10
    )
}

/// Monitors execution health and enforces safety guardrails
actor ExecutionGuardrails: Sendable {
    private let config: GuardrailConfig
    private let startTime: Date
    private let logger = Logger(subsystem: "com.neptune.guardrails", category: "execution")

    private var iterationCount: Int = 0
    private var toolCallCount: Int = 0
    private var lastProgressTime: Date
    private var consecutiveFailures: Int = 0
    private var lastFailureTime: Date?
    private var taskCompletionTimes: [Date] = []

    init(config: GuardrailConfig = .default) {
        self.config = config
        self.startTime = Date()
        self.lastProgressTime = Date()
    }

    /// Checks if iteration can proceed
    func checkIterationAllowed() async throws -> (allowed: Bool, reason: String?) {
        iterationCount += 1

        // Check iteration limit
        if iterationCount >= config.maxIterations {
            return (false, "Iteration limit (\(config.maxIterations)) reached")
        }

        // Check wall-clock time
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed >= config.maxWallClockSeconds {
            return (false, "Wall-clock time limit (\(config.maxWallClockSeconds)s) exceeded")
        }

        // Check for no-progress condition
        let timeSinceProgress = Date().timeIntervalSince(lastProgressTime)
        if timeSinceProgress >= config.noProgressTimeoutSeconds {
            return (false, "No progress for \(Int(timeSinceProgress))s (limit: \(Int(config.noProgressTimeoutSeconds))s)")
        }

        return (true, nil)
    }

    /// Checks if tool call can proceed
    func checkToolCallAllowed() async throws -> (allowed: Bool, reason: String?) {
        toolCallCount += 1

        if toolCallCount >= config.maxToolCallsPerTask {
            return (false, "Tool call limit (\(config.maxToolCallsPerTask)) reached")
        }

        return (true, nil)
    }

    /// Records task completion (progress indicator)
    func recordTaskCompletion() async {
        lastProgressTime = Date()
        taskCompletionTimes.append(Date())
        consecutiveFailures = 0
        logger.debug("Task completed; resetting failure counter")
    }

    /// Records task failure
    func recordTaskFailure() async {
        consecutiveFailures += 1
        lastFailureTime = Date()

        logger.warning("Task failed (\(self.consecutiveFailures)/\(self.config.maxConsecutiveFailures))")

        if consecutiveFailures >= config.maxConsecutiveFailures {
            logger.error("Max consecutive failures reached")
        }
    }

    /// Checks overall execution health
    func checkHealth() async -> ExecutionHealth {
        let elapsed = Date().timeIntervalSince(startTime)
        let timeSinceProgress = Date().timeIntervalSince(lastProgressTime)
        let completionRate = Double(taskCompletionTimes.count) / Double(iterationCount == 0 ? 1 : iterationCount)

        let status: ExecutionHealthStatus
        if consecutiveFailures >= config.maxConsecutiveFailures {
            status = .criticalFailureLoop
        } else if timeSinceProgress >= config.noProgressTimeoutSeconds {
            status = .stalled
        } else if elapsed >= config.maxWallClockSeconds * 0.9 {
            status = .timeWarning
        } else if iterationCount >= Int(Double(config.maxIterations) * 0.9) {
            status = .iterationWarning
        } else if completionRate < 0.3 {
            status = .lowProgressRate
        } else {
            status = .healthy
        }

        return ExecutionHealth(
            status: status,
            iterationProgress: (iterationCount, config.maxIterations),
            toolCallProgress: (toolCallCount, config.maxToolCallsPerTask),
            wallClockProgress: (elapsed, config.maxWallClockSeconds),
            completionRate: completionRate,
            consecutiveFailures: consecutiveFailures,
            timeSinceProgress: timeSinceProgress
        )
    }

    /// Gets execution summary
    func getSummary() -> GuardrailsSummary {
        return GuardrailsSummary(
            iterationCount: iterationCount,
            toolCallCount: toolCallCount,
            elapsedSeconds: Date().timeIntervalSince(startTime),
            tasksCompleted: taskCompletionTimes.count,
            consecutiveFailures: consecutiveFailures,
            config: config
        )
    }
}

enum ExecutionHealthStatus: String, Sendable {
    case healthy
    case lowProgressRate
    case timeWarning
    case iterationWarning
    case stalled
    case criticalFailureLoop
}

struct ExecutionHealth: Sendable {
    let status: ExecutionHealthStatus
    let iterationProgress: (current: Int, max: Int)
    let toolCallProgress: (current: Int, max: Int)
    let wallClockProgress: (current: TimeInterval, max: TimeInterval)
    let completionRate: Double
    let consecutiveFailures: Int
    let timeSinceProgress: TimeInterval

    var isHealthy: Bool {
        status == .healthy
    }

    var requiresReview: Bool {
        status != .healthy && status != .lowProgressRate
    }

    var shouldStop: Bool {
        status == .stalled || status == .criticalFailureLoop
    }
}

struct GuardrailsSummary: Sendable {
    let iterationCount: Int
    let toolCallCount: Int
    let elapsedSeconds: TimeInterval
    let tasksCompleted: Int
    let consecutiveFailures: Int
    let config: GuardrailConfig

    var completionRate: Double {
        guard iterationCount > 0 else { return 0 }
        return Double(tasksCompleted) / Double(iterationCount)
    }

    var toolsPerIteration: Double {
        guard iterationCount > 0 else { return 0 }
        return Double(toolCallCount) / Double(iterationCount)
    }
}

// MARK: - Checkpoint Validation & Resumability

/// Validates checkpoint integrity and resumability
struct CheckpointValidation: Sendable {
    let isValid: Bool
    let reason: String?
    let agentCount: Int
    let taskCount: Int
    let completedTaskCount: Int
    let lastTimestamp: Date?
    let contextSize: Int
    let warnings: [String]
}

/// Validates and restores from checkpoints
actor CheckpointValidator: Sendable {
    private let logger = Logger(subsystem: "com.neptune.checkpoint", category: "validation")

    /// Validates a checkpoint for integrity and resumability
    func validate(checkpoint: SessionCheckpoint) -> CheckpointValidation {
        var warnings: [String] = []

        // Validate agents
        guard !checkpoint.agents.isEmpty else {
            return CheckpointValidation(
                isValid: false,
                reason: "No agents in checkpoint",
                agentCount: 0,
                taskCount: 0,
                completedTaskCount: 0,
                lastTimestamp: checkpoint.timestamp,
                contextSize: 0,
                warnings: warnings
            )
        }

        // Validate task graph
        if checkpoint.taskGraph.tasks.isEmpty {
            warnings.append("Task graph is empty")
        }

        let completedTasks = checkpoint.taskGraph.tasks.values.filter { $0.status == .completed }.count
        let blockingTasks = checkpoint.taskGraph.tasks.values.filter { $0.status == .blocked }.count

        if blockingTasks > 0 {
            warnings.append("Found \(blockingTasks) blocked tasks - may require human intervention")
        }

        // Validate metrics
        if checkpoint.totalTokensUsed < 0 {
            return CheckpointValidation(
                isValid: false,
                reason: "Invalid token count: \(checkpoint.totalTokensUsed)",
                agentCount: checkpoint.agents.count,
                taskCount: checkpoint.taskGraph.tasks.count,
                completedTaskCount: completedTasks,
                lastTimestamp: checkpoint.timestamp,
                contextSize: 0,
                warnings: warnings
            )
        }

        if checkpoint.totalCostUSD < 0 {
            return CheckpointValidation(
                isValid: false,
                reason: "Invalid cost: \(checkpoint.totalCostUSD)",
                agentCount: checkpoint.agents.count,
                taskCount: checkpoint.taskGraph.tasks.count,
                completedTaskCount: completedTasks,
                lastTimestamp: checkpoint.timestamp,
                contextSize: 0,
                warnings: warnings
            )
        }

        // Check for stale data (checkpoint > 24 hours old)
        let age = Date().timeIntervalSince(checkpoint.timestamp)
        if age > 86400 {
            warnings.append("Checkpoint is \(Int(age / 3600)) hours old - consider fresh run")
        }

        // Validate agent states
        for agent in checkpoint.agents {
            if agent.currentTaskId != nil && agent.status == .success {
                warnings.append("Agent \(agent.name) has active task but success status - unclear state")
            }
        }

        logger.info("Checkpoint validation: valid=true, agents=\(checkpoint.agents.count), tasks=\(checkpoint.taskGraph.tasks.count), completed=\(completedTasks)")

        return CheckpointValidation(
            isValid: true,
            reason: nil,
            agentCount: checkpoint.agents.count,
            taskCount: checkpoint.taskGraph.tasks.count,
            completedTaskCount: completedTasks,
            lastTimestamp: checkpoint.timestamp,
            contextSize: 0,
            warnings: warnings
        )
    }

    /// Determines if safe to resume from checkpoint
    func isSafeToResume(validation: CheckpointValidation) -> Bool {
        // Safe to resume if:
        // 1. Checkpoint is valid
        // 2. Not too many blocked tasks
        // 3. Metrics are intact
        guard validation.isValid else { return false }

        let blockedRatio = Double(validation.taskCount - validation.completedTaskCount) / Double(validation.taskCount)
        if blockedRatio > 0.5 {
            logger.warning("Too many incomplete tasks: \(blockedRatio.formatted())")
            return false
        }

        return true
    }

    /// Analyzes checkpoint for resumption readiness
    func analyzeForResumption(checkpoint: SessionCheckpoint) -> (readyAgents: Int, problematicTasks: Int) {
        // Count agents that are in a safe state for resumption
        let readyAgents = checkpoint.agents.filter { agent in
            agent.status != .coding && agent.status != .thinking && agent.status != .reviewing && agent.currentTaskId == nil
        }.count

        // Count tasks that are ambiguous
        let problematicTasks = checkpoint.taskGraph.tasks.values.filter { task in
            task.status == .running || task.status == .queued
        }.count

        logger.info("Resumption analysis: ready_agents=\(readyAgents)/\(checkpoint.agents.count), problematic_tasks=\(problematicTasks)")

        return (readyAgents, problematicTasks)
    }
}

// MARK: - Task Batching Infrastructure

/// Represents a batch of related tasks for delegated execution
struct TaskBatch: Sendable {
    let id: String
    let batchName: String
    let taskIds: [String]
    let strategy: TaskBatchingStrategy
    var priority: Int  // Higher = execute sooner
    let estimatedDuration: TimeInterval
    let maxParallelism: Int  // Max concurrent tasks in batch
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?

    var isRunning: Bool {
        startedAt != nil && completedAt == nil
    }

    var duration: TimeInterval {
        guard let started = startedAt, let completed = completedAt else {
            return 0
        }
        return completed.timeIntervalSince(started)
    }

    init(
        taskIds: [String],
        strategy: TaskBatchingStrategy,
        priority: Int = 0,
        maxParallelism: Int = 3
    ) {
        self.id = UUID().uuidString
        self.taskIds = taskIds
        self.strategy = strategy
        self.priority = priority
        self.maxParallelism = maxParallelism
        self.createdAt = Date()
        self.batchName = "batch_\(strategy.rawValue)_\(taskIds.count)tasks"
        self.estimatedDuration = TimeInterval(taskIds.count * 30)  // Estimate ~30s per task
    }
}

/// Strategy for grouping tasks into batches
enum TaskBatchingStrategy: String, Sendable {
    case byRole  // Group tasks requiring same agent role
    case byDependencyDepth  // Group tasks at same dependency level
    case byModule  // Group tasks working on same module/file
    case byUrgency  // Group urgent tasks together
    case hybrid  // Combine multiple strategies
}

/// Metrics for batch execution performance
struct BatchingMetrics: Sendable {
    let batchId: String
    let taskCount: Int
    let successCount: Int
    let failureCount: Int
    let totalDuration: TimeInterval
    let averageTaskDuration: TimeInterval
    let parallelismAchieved: Double  // Actual vs max

    var successRate: Double {
        guard taskCount > 0 else { return 0 }
        return Double(successCount) / Double(taskCount)
    }
}

/// Batch execution actor managing batching strategy and metrics
actor TaskBatcher: Sendable {
    private let logger = os.Logger(subsystem: "com.neptune.batching", category: "TaskBatcher")
    private(set) var batches: [String: TaskBatch] = [:]
    private(set) var completedBatches: [String: TaskBatch] = [:]
    private(set) var metrics: [String: BatchingMetrics] = [:]

    private var batchingEnabled: Bool = true
    private let minBatchSize = 2
    private let maxBatchSize = 10

    nonisolated init() {}

    /// Analyzes task graph and creates optimal batches
    func createBatches(
        from taskGraph: TaskGraph,
        strategy: TaskBatchingStrategy
    ) -> [TaskBatch] {
        let readyTasks = taskGraph.getReadyTasks()

        guard !readyTasks.isEmpty else { return [] }

        switch strategy {
        case .byRole:
            return createBatchesByRole(readyTasks)
        case .byDependencyDepth:
            return createBatchesByDependencyDepth(readyTasks, taskGraph: taskGraph)
        case .byModule:
            return createBatchesByModule(readyTasks)
        case .byUrgency:
            return createBatchesByUrgency(readyTasks)
        case .hybrid:
            return createHybridBatches(readyTasks, taskGraph: taskGraph)
        }
    }

    /// Group tasks by required agent role
    private func createBatchesByRole(_ tasks: [Task]) -> [TaskBatch] {
        var batches: [TaskBatch] = []
        var tasksByRole: [AgentRole: [Task]] = [:]

        for task in tasks {
            if tasksByRole[task.roleRequired] == nil {
                tasksByRole[task.roleRequired] = []
            }
            tasksByRole[task.roleRequired]?.append(task)
        }

        for (_, roleTasks) in tasksByRole {
            let chunks = roleTasks.chunked(into: maxBatchSize)
            for (index, chunk) in chunks.enumerated() {
                let batch = TaskBatch(
                    taskIds: chunk.map { $0.id },
                    strategy: .byRole,
                    priority: 100 - index,  // First batches higher priority
                    maxParallelism: min(3, chunk.count)
                )
                batches.append(batch)
            }
        }

        logger.info("Created \(batches.count) batches by role from \(tasks.count) tasks")
        return batches
    }

    /// Group tasks at same dependency level
    private func createBatchesByDependencyDepth(
        _ tasks: [Task],
        taskGraph: TaskGraph
    ) -> [TaskBatch] {
        var batches: [TaskBatch] = []
        var tasksByDepth: [Int: [Task]] = [:]

        for task in tasks {
            let depth = calculateDependencyDepth(task.id, taskGraph: taskGraph)
            if tasksByDepth[depth] == nil {
                tasksByDepth[depth] = []
            }
            tasksByDepth[depth]?.append(task)
        }

        let sortedDepths = tasksByDepth.keys.sorted()
        for depth in sortedDepths {
            if let depthTasks = tasksByDepth[depth], !depthTasks.isEmpty {
                let chunks = depthTasks.chunked(into: maxBatchSize)
                for (index, chunk) in chunks.enumerated() {
                    let batch = TaskBatch(
                        taskIds: chunk.map { $0.id },
                        strategy: .byDependencyDepth,
                        priority: 100 - (depth * 10) - index,
                        maxParallelism: min(4, chunk.count)
                    )
                    batches.append(batch)
                }
            }
        }

        logger.info("Created \(batches.count) batches by dependency depth")
        return batches
    }

    /// Group tasks by module/file they modify
    private func createBatchesByModule(_ tasks: [Task]) -> [TaskBatch] {
        var batches: [TaskBatch] = []
        var tasksByModule: [String: [Task]] = [:]

        for task in tasks {
            let module = extractModuleFromTask(task)
            if tasksByModule[module] == nil {
                tasksByModule[module] = []
            }
            tasksByModule[module]?.append(task)
        }

        for (_, moduleTasks) in tasksByModule.sorted(by: { $0.key < $1.key }) {
            guard moduleTasks.count >= minBatchSize else { continue }

            let chunks = moduleTasks.chunked(into: maxBatchSize)
            for (index, chunk) in chunks.enumerated() {
                let batch = TaskBatch(
                    taskIds: chunk.map { $0.id },
                    strategy: .byModule,
                    priority: 50 - index,
                    maxParallelism: min(2, chunk.count)  // Sequential for same module
                )
                batches.append(batch)
            }
        }

        logger.info("Created \(batches.count) batches by module")
        return batches
    }

    /// Group urgent tasks together
    private func createBatchesByUrgency(_ tasks: [Task]) -> [TaskBatch] {
        let urgentTasks = tasks.filter { task in
            task.acceptanceCriteria.contains { criteria in
                criteria.lowercased().contains("urgent") ||
                criteria.lowercased().contains("critical") ||
                criteria.lowercased().contains("blocking")
            }
        }

        var batches: [TaskBatch] = []

        if !urgentTasks.isEmpty {
            let chunks = urgentTasks.chunked(into: maxBatchSize)
            for (index, chunk) in chunks.enumerated() {
                let batch = TaskBatch(
                    taskIds: chunk.map { $0.id },
                    strategy: .byUrgency,
                    priority: 200 - index,  // Very high priority
                    maxParallelism: min(5, chunk.count)
                )
                batches.append(batch)
            }
        }

        // Remaining tasks as secondary batch
        let remainingTasks = tasks.filter { !urgentTasks.contains($0) }
        if !remainingTasks.isEmpty {
            let chunks = remainingTasks.chunked(into: maxBatchSize)
            for (index, chunk) in chunks.enumerated() {
                let batch = TaskBatch(
                    taskIds: chunk.map { $0.id },
                    strategy: .byUrgency,
                    priority: 50 - index,
                    maxParallelism: 3
                )
                batches.append(batch)
            }
        }

        logger.info("Created \(batches.count) urgency batches: \(urgentTasks.count) urgent, \(remainingTasks.count) normal")
        return batches
    }

    /// Hybrid batching combining role, depth, and urgency
    private func createHybridBatches(
        _ tasks: [Task],
        taskGraph: TaskGraph
    ) -> [TaskBatch] {
        var batches: [TaskBatch] = []

        // First, separate urgent from normal
        let urgentTasks = tasks.filter { $0.acceptanceCriteria.contains { $0.lowercased().contains("urgent") } }
        let normalTasks = tasks.filter { !urgentTasks.contains($0) }

        // Process urgent first (by role)
        if !urgentTasks.isEmpty {
            batches.append(contentsOf: createBatchesByRole(urgentTasks))
            for batch in batches.dropFirst(batches.count - urgentTasks.count) {
                var updated = batch
                updated.priority = 150  // High priority
                batches[batches.firstIndex { $0.id == updated.id }!] = updated
            }
        }

        // Then normal tasks by dependency depth
        if !normalTasks.isEmpty {
            batches.append(contentsOf: createBatchesByDependencyDepth(normalTasks, taskGraph: taskGraph))
        }

        logger.info("Created \(batches.count) hybrid batches from \(tasks.count) tasks")
        return batches
    }

    /// Records batch completion and metrics
    func recordBatchCompletion(
        batchId: String,
        successCount: Int,
        failureCount: Int,
        duration: TimeInterval
    ) {
        guard var batch = batches.removeValue(forKey: batchId) else { return }

        batch.completedAt = Date()
        completedBatches[batchId] = batch

        let metric = BatchingMetrics(
            batchId: batchId,
            taskCount: batch.taskIds.count,
            successCount: successCount,
            failureCount: failureCount,
            totalDuration: duration,
            averageTaskDuration: duration / Double(batch.taskIds.count),
            parallelismAchieved: Double(successCount + failureCount) / Double(batch.maxParallelism)
        )
        metrics[batchId] = metric

        logger.info("Batch \(batchId) completed: \(successCount) success, \(failureCount) failed, \(metric.successRate.formatted(.percent)) success rate")
    }

    /// Gets pending batches sorted by priority
    func getPendingBatches() -> [TaskBatch] {
        batches.values.sorted { $0.priority > $1.priority }
    }

    /// Gets batching metrics summary
    func getBatchingMetrics() -> (totalBatches: Int, completedBatches: Int, averageSuccessRate: Double) {
        let completed = metrics.values
        let totalBatches = batches.count + completed.count
        let completedCount = completed.count
        let avgSuccessRate = completed.isEmpty ? 0 : completed.map(\.successRate).reduce(0, +) / Double(completed.count)

        return (totalBatches, completedCount, avgSuccessRate)
    }

    // MARK: - Helper Functions

    private func calculateDependencyDepth(_ taskId: String, taskGraph: TaskGraph) -> Int {
        guard let task = taskGraph.getTask(taskId) else { return 0 }

        if task.dependencies.isEmpty {
            return 0
        }

        let maxDepth = task.dependencies.map { depId in
            calculateDependencyDepth(depId, taskGraph: taskGraph)
        }.max() ?? 0

        return maxDepth + 1
    }

    private func extractModuleFromTask(_ task: Task) -> String {
        // Parse task description to extract module name
        let parts = task.description.split(separator: " ")
        if parts.count > 1 {
            return String(parts[1])
        }
        return "default"
    }
}

// MARK: - Execution Observability & Diagnostics

/// Detailed failure diagnostic information
struct FailureDiagnostic: Sendable {
    let taskId: String
    let agentId: String
    let errorType: String
    let errorMessage: String
    let timestamp: Date
    let duration: TimeInterval
    let attemptNumber: Int
    let isRetryable: Bool
    let suggestionForRecovery: String?
    let contextSnapshot: [String: String]  // Task context at failure time

    var summary: String {
        """
        Failure: \(errorType)
        Task: \(taskId) (attempt \(attemptNumber))
        Agent: \(agentId)
        Duration: \(String(format: "%.1f", duration))s
        Retryable: \(isRetryable)
        \(suggestionForRecovery.map { "Suggestion: \($0)" } ?? "No recovery suggestion")
        """
    }
}

/// Execution performance metrics
struct ExecutionMetrics: Sendable {
    var totalTasksStarted: Int
    var totalTasksCompleted: Int
    var totalTasksFailed: Int
    var averageTaskDuration: TimeInterval
    var totalExecutionTime: TimeInterval
    var failureRate: Double
    var retryRate: Double
    var memoryPeakMB: Int
    var successfulBatches: Int
    var failedBatches: Int

    var successRate: Double {
        guard totalTasksStarted > 0 else { return 0 }
        return Double(totalTasksCompleted) / Double(totalTasksStarted)
    }

    var summary: String {
        """
        === Execution Metrics ===
        Tasks: \(totalTasksCompleted)/\(totalTasksStarted) completed (\(Int(successRate * 100))% success)
        Failed: \(totalTasksFailed) (\(Int(failureRate * 100))% failure rate)
        Average Task Duration: \(String(format: "%.1f", averageTaskDuration))s
        Total Execution Time: \(ExecutionMetrics.formatDuration(totalExecutionTime))
        Memory Peak: \(memoryPeakMB) MB
        Batch Success: \(successfulBatches), Failures: \(failedBatches)
        """
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else if minutes > 0 {
            return String(format: "%d:%02d", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
}

/// Comprehensive execution diagnostics observer for failure tracking and metrics
actor ExecutionDiagnosticsObserver: Sendable {
    private let logger = os.Logger(subsystem: "com.neptune.diagnostics", category: "ExecutionDiagnosticsObserver")

    private(set) var failures: [String: FailureDiagnostic] = [:]
    private(set) var metrics: ExecutionMetrics = ExecutionMetrics(
        totalTasksStarted: 0,
        totalTasksCompleted: 0,
        totalTasksFailed: 0,
        averageTaskDuration: 0,
        totalExecutionTime: 0,
        failureRate: 0,
        retryRate: 0,
        memoryPeakMB: 0,
        successfulBatches: 0,
        failedBatches: 0
    )

    private var taskStartTimes: [String: Date] = [:]
    private var taskAttempts: [String: Int] = [:]
    private var executionStartTime: Date?

    nonisolated init() {}

    /// Record task start for duration tracking
    func recordTaskStart(_ taskId: String) {
        if executionStartTime == nil {
            executionStartTime = Date()
        }
        taskStartTimes[taskId] = Date()
        taskAttempts[taskId, default: 0] += 1
        logger.debug("Task \(taskId) started (attempt \(self.taskAttempts[taskId]!))")
    }

    /// Record task success with duration
    func recordTaskSuccess(_ taskId: String) {
        let startTime = taskStartTimes[taskId] ?? Date()
        let duration = Date().timeIntervalSince(startTime)

        var updated = metrics
        updated.totalTasksCompleted += 1
        updated.totalTasksStarted = max(metrics.totalTasksStarted, updated.totalTasksCompleted + metrics.totalTasksFailed)
        updated.averageTaskDuration = (metrics.averageTaskDuration * Double(metrics.totalTasksCompleted - 1) + duration) / Double(updated.totalTasksCompleted)
        metrics = updated

        taskStartTimes.removeValue(forKey: taskId)
        logger.info("Task \(taskId) succeeded in \(String(format: "%.2f", duration))s")
    }

    /// Record task failure with diagnostic information
    func recordTaskFailure(
        taskId: String,
        agentId: String,
        error: Error,
        isRetryable: Bool,
        suggestion: String? = nil,
        context: [String: String] = [:]
    ) {
        let startTime = taskStartTimes[taskId] ?? Date()
        let duration = Date().timeIntervalSince(startTime)
        let attemptNumber = taskAttempts[taskId] ?? 1

        let errorType = String(describing: type(of: error))
        let diagnostic = FailureDiagnostic(
            taskId: taskId,
            agentId: agentId,
            errorType: errorType,
            errorMessage: error.localizedDescription,
            timestamp: Date(),
            duration: duration,
            attemptNumber: attemptNumber,
            isRetryable: isRetryable,
            suggestionForRecovery: suggestion,
            contextSnapshot: context
        )

        failures[taskId] = diagnostic

        var updated = metrics
        updated.totalTasksFailed += 1
        updated.totalTasksStarted = max(metrics.totalTasksStarted, metrics.totalTasksCompleted + updated.totalTasksFailed)
        updated.failureRate = Double(updated.totalTasksFailed) / Double(updated.totalTasksStarted)
        updated.retryRate = isRetryable ? metrics.retryRate + (1.0 / Double(updated.totalTasksStarted)) : metrics.retryRate
        metrics = updated

        logger.warning("Task \(taskId) failed after \(String(format: "%.2f", duration))s: \(error.localizedDescription)")
        if let suggestion = suggestion {
            logger.info("Recovery suggestion: \(suggestion)")
        }
    }

    /// Record batch execution result
    func recordBatchExecution(successful: Bool, taskCount: Int) {
        var updated = metrics
        if successful {
            updated.successfulBatches += 1
        } else {
            updated.failedBatches += 1
        }
        metrics = updated

        logger.info("Batch execution \(successful ? "succeeded" : "failed") with \(taskCount) tasks")
    }

    /// Get detailed failure summary
    func getFailureSummary() -> String {
        guard !failures.isEmpty else {
            return "No failures recorded"
        }

        let failuresByType = Dictionary(grouping: failures.values) { $0.errorType }
        var summary = "Failure Summary (\(failures.count) total):\n"

        for (errorType, typeFailures) in failuresByType.sorted(by: { $0.key < $1.key }) {
            summary += """
            \n\(errorType): \(typeFailures.count) occurrences
            """
            let retryable = typeFailures.filter(\.isRetryable).count
            summary += " (\(retryable) retryable)"

            if let suggestion = typeFailures.compactMap(\.suggestionForRecovery).first {
                summary += "\n  → \(suggestion)"
            }
        }

        return summary
    }

    /// Get comprehensive execution report
    func getExecutionReport() -> String {
        let metricsReport = metrics.summary
        let failureReport = getFailureSummary()

        let totalDuration = executionStartTime.map { Date().timeIntervalSince($0) } ?? 0

        var updated = metrics
        updated.totalExecutionTime = totalDuration
        metrics = updated

        return """
        \(metricsReport)

        \(failureReport)

        === Diagnostic Details ===
        """
    }

    /// Get critical failures requiring immediate attention
    func getCriticalFailures() -> [FailureDiagnostic] {
        failures.values.filter { failure in
            failure.isRetryable == false &&
            failure.errorType.contains("safety") || failure.errorType.contains("permission") ||
            failure.errorType.contains("validation") || failure.errorType.contains("security")
        }.sorted { $0.timestamp > $1.timestamp }
    }

    /// Clear old failure records (for memory management)
    func clearOldFailures(olderThan interval: TimeInterval) {
        let cutoff = Date().addingTimeInterval(-interval)
        failures = failures.filter { $0.value.timestamp > cutoff }
        logger.info("Cleared failures older than \(String(format: "%.0f", interval))s")
    }
}

// MARK: - Safety Enforcement Gate

/// Enforces safety constraints during task execution
actor SafetyEnforcementGate: Sendable {
    private let logger = os.Logger(subsystem: "com.neptune.safety", category: "SafetyEnforcementGate")
    private let validator: SafetyValidator
    private(set) var violationLog: [SafetyViolation] = []
    private(set) var validationHistory: [ValidationCheckpoint] = []

    private var projectContext: [String: ProjectSafetyContext] = [:]

    struct ProjectSafetyContext: Sendable {
        let projectId: String
        let workspaceRoot: String
        var allowedDirectories: [String]
        var fileAccessLog: [FileAccessRecord] = []
        var violationThreshold: Int = 5  // Fail project after N violations
    }

    struct FileAccessRecord: Sendable {
        let timestamp: Date
        let filePath: String
        let operation: FileOperationType
        let allowed: Bool
    }

    struct ValidationCheckpoint: Sendable {
        let timestamp: Date
        let taskId: String
        let validationsPassed: Int
        let validationsFailed: Int
    }

    struct SafetyViolation: Sendable {
        let timestamp: Date
        let taskId: String
        let severity: ValidationSeverity
        let message: String
        let filePath: String?
        let details: [String: String]
    }

    nonisolated init(validator: SafetyValidator) {
        self.validator = validator
    }

    /// Register a project for safety enforcement
    func registerProject(
        projectId: String,
        workspaceRoot: String,
        allowedDirectories: [String]
    ) async {
        projectContext[projectId] = ProjectSafetyContext(
            projectId: projectId,
            workspaceRoot: workspaceRoot,
            allowedDirectories: allowedDirectories
        )
        logger.info("Registered project \(projectId) for safety enforcement")
    }

    /// Validate task execution pre-flight checks
    func validateTaskExecution(
        taskId: String,
        projectId: String,
        role: AgentRole,
        description: String
    ) async -> (allowed: Bool, violations: [SafetyViolation]) {
        guard var context = projectContext[projectId] else {
            let violation = SafetyViolation(
                timestamp: Date(),
                taskId: taskId,
                severity: .deny,
                message: "Project \(projectId) not registered for safety enforcement",
                filePath: nil,
                details: [:]
            )
            return (false, [violation])
        }

        var violations: [SafetyViolation] = []

        // Check for suspicious role combinations
        if description.lowercased().contains("system") && role != .shipping {
            violations.append(SafetyViolation(
                timestamp: Date(),
                taskId: taskId,
                severity: .ask,
                message: "Non-shipping role attempting system-level operation",
                filePath: nil,
                details: ["role": role.rawValue, "description": description]
            ))
        }

        // Check if we're approaching violation threshold
        if context.fileAccessLog.filter({ !$0.allowed }).count >= context.violationThreshold - 1 {
            violations.append(SafetyViolation(
                timestamp: Date(),
                taskId: taskId,
                severity: .ask,
                message: "Safety violation threshold approaching",
                filePath: nil,
                details: ["currentViolations": String(context.fileAccessLog.filter({ !$0.allowed }).count)]
            ))
        }

        projectContext[projectId] = context

        let checkpoint = ValidationCheckpoint(
            timestamp: Date(),
            taskId: taskId,
            validationsPassed: 1,
            validationsFailed: violations.count
        )
        validationHistory.append(checkpoint)

        let allowed = violations.filter({ $0.severity == .deny }).isEmpty
        if !allowed {
            violationLog.append(contentsOf: violations)
        }

        return (allowed, violations)
    }

    /// Validate file operations during task execution
    func validateFileOperation(
        taskId: String,
        projectId: String,
        filePath: String,
        operation: FileOperationType
    ) async -> FileValidationResult {
        guard var context = projectContext[projectId] else {
            return FileValidationResult(
                isAllowed: false,
                filePath: filePath,
                operation: operation,
                reason: "Project not registered for safety enforcement",
                severity: .deny,
                allowedScope: []
            )
        }

        // Validate against safety rules
        let validationResult = await validator.validateFileOperation(
            projectId: projectId,
            filePath: filePath,
            operation: operation,
            workspaceRoot: context.workspaceRoot
        )

        // Log the access
        let accessRecord = FileAccessRecord(
            timestamp: Date(),
            filePath: filePath,
            operation: operation,
            allowed: validationResult.isAllowed
        )
        context.fileAccessLog.append(accessRecord)

        // Track violations
        if !validationResult.isAllowed {
            let violation = SafetyViolation(
                timestamp: Date(),
                taskId: taskId,
                severity: validationResult.severity,
                message: validationResult.reason,
                filePath: filePath,
                details: [
                    "operation": operation.rawValue,
                    "allowedScope": context.allowedDirectories.joined(separator: ", ")
                ]
            )
            violationLog.append(violation)

            logger.warning("Safety violation: \(violation.message)")
        } else {
            logger.debug("File operation validated: \(filePath)")
        }

        projectContext[projectId] = context
        return validationResult
    }

    /// Get safety status for a project
    func getProjectSafetyStatus(projectId: String) -> (isHealthy: Bool, violationCount: Int, status: String) {
        guard let context = projectContext[projectId] else {
            return (false, 0, "Project not registered")
        }

        let violations = violationLog.filter { $0.taskId.hasPrefix(projectId) }
        let isHealthy = violations.filter({ $0.severity == .deny }).count < context.violationThreshold

        return (isHealthy, violations.count, isHealthy ? "OK" : "VIOLATIONS DETECTED")
    }

    /// Get detailed safety report
    func generateSafetyReport(projectId: String) -> String {
        let violations = violationLog.filter { $0.taskId.hasPrefix(projectId) }
        let denials = violations.filter { $0.severity == .deny }

        let askItems = violations.filter { $0.severity == .ask }
        var report = """
        === Safety Report for Project \(projectId) ===
        Total Violations: \(violations.count)
        Denials: \(denials.count), Requires Review: \(askItems.count)

        """

        if !denials.isEmpty {
            report += "DENIALS:\n"
            for denial in denials.prefix(10) {
                report += "  - \(denial.message) (\(denial.filePath ?? "N/A"))\n"
            }
            report += "\n"
        }

        if !askItems.isEmpty {
            report += "REQUIRES REVIEW:\n"
            for item in askItems.prefix(10) {
                report += "  - \(item.message)\n"
            }
        }

        return report
    }
}

// MARK: - Array Chunking Extension

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
