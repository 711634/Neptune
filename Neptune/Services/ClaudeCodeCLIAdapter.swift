import Foundation
import AppKit

/// Provider adapter for Claude Code CLI (local, authenticated)
actor ClaudeCodeCLIAdapter: ProviderAdapter {
    let id = "claude-code-cli"
    let displayName = "Claude Code CLI"
    let icon = "terminal.fill"

    private let executablePath: String
    private var lastSession: String?
    private var authenticatedAt: Date?

    init(executablePath: String = "/opt/homebrew/bin/claude") {
        self.executablePath = executablePath
    }

    nonisolated var isInstalled: Bool {
        get async {
            FileManager.default.fileExists(atPath: executablePath)
        }
    }

    nonisolated var isAuthenticated: Bool {
        get async {
            // Claude Code CLI uses existing authentication from system
            // Check by attempting a simple version command
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = ["--version"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }
    }

    nonisolated var currentProject: String? {
        get async {
            // Check current working directory context
            // Can be enhanced to detect from environment or active files
            nil
        }
    }

    var activeSession: String? {
        get async {
            lastSession
        }
    }

    func executeTask(prompt: String, in workDir: String) async throws -> ProviderOutput {
        let sessionId = UUID().uuidString
        let startTime = Date()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.currentDirectoryURL = URL(fileURLWithPath: workDir)
        process.arguments = []  // Claude Code CLI reads from stdin in interactive mode

        let inputPipe = Pipe()
        let outputPipe = Pipe()

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()

        // Send the prompt
        if let promptData = prompt.data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(promptData)
        }

        // Send EOF to indicate end of input
        try inputPipe.fileHandleForWriting.close()

        // Read output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        process.waitUntilExit()

        let duration = Date().timeIntervalSince(startTime)

        // Parse the output to detect success/failure
        let status = output.contains("\"status\": \"success\"") ? "success" :
                     output.contains("\"status\": \"failed\"") ? "failed" : "blocked"

        lastSession = sessionId

        return ProviderOutput(
            sessionId: sessionId,
            status: status,
            output: output,
            filesModified: [],
            errors: [],
            duration: duration
        )
    }

    nonisolated func getAvailableSessions() async throws -> [ProviderSession] {
        // Claude Code CLI doesn't maintain persistent sessions
        // Return a virtual session if currently active
        if let sessionId = await activeSession {
            return [
                ProviderSession(
                    id: sessionId,
                    displayName: "Active Session",
                    projectPath: nil,
                    createdAt: Date(),
                    lastActivity: Date(),
                    status: "running"
                )
            ]
        }
        return []
    }

    nonisolated func openProject(_ path: String) async throws {
        // Can open project in the default editor or Claude Code if available
        // For now, just open in Finder or default app
        try? NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func stop() async throws {
        // Not applicable for CLI - process terminates on completion
        lastSession = nil
    }
}
