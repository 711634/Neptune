import Foundation
import AppKit

/// Provider adapter for Claude Desktop app (detection and launch)
actor ClaudeDesktopAdapter: ProviderAdapter {
    let id = "claude-desktop"
    let displayName = "Claude Desktop"
    let icon = "sparkles"

    private let appBundleId = "com.anthropic.claude"

    nonisolated var isInstalled: Bool {
        get async {
            NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: appBundleId) != nil
        }
    }

    nonisolated var isAuthenticated: Bool {
        get async {
            // Claude Desktop typically has persistent authentication
            // We assume it's authenticated if installed
            await isInstalled
        }
    }

    nonisolated var currentProject: String? {
        get async {
            // Claude Desktop doesn't expose project context easily
            nil
        }
    }

    nonisolated var activeSession: String? {
        get async {
            // Check if Claude Desktop is running
            let running = NSWorkspace.shared.runningApplications
                .contains { $0.bundleIdentifier == appBundleId }
            return running ? "active" : nil
        }
    }

    nonisolated func executeTask(prompt: String, in workDir: String) async throws -> ProviderOutput {
        // Claude Desktop execution is not directly supported
        // This adapter focuses on detection and launching
        throw AdapterError.notSupported("Direct execution through Claude Desktop requires manual interaction")
    }

    nonisolated func getAvailableSessions() async throws -> [ProviderSession] {
        let isRunning = NSWorkspace.shared.runningApplications
            .contains { $0.bundleIdentifier == appBundleId }

        return isRunning ? [
            ProviderSession(
                id: "claude-desktop-main",
                displayName: "Claude Desktop",
                projectPath: nil,
                createdAt: Date(),
                lastActivity: Date(),
                status: "idle"
            )
        ] : []
    }

    nonisolated func openProject(_ path: String) async throws {
        // Open the project in Claude Desktop if possible
        let url = URL(fileURLWithPath: path)
        try? NSWorkspace.shared.open([url], withAppBundleIdentifier: appBundleId, options: [], additionalEventParamDescriptor: nil, launchIdentifiers: nil)
    }

    nonisolated func stop() async throws {
        // Can't directly stop Claude Desktop
    }
}

enum AdapterError: LocalizedError {
    case notSupported(String)

    var errorDescription: String? {
        switch self {
        case .notSupported(let message):
            return message
        }
    }
}
