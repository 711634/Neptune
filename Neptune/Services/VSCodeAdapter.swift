import Foundation
import AppKit

/// Provider adapter for VS Code with Claude Code extension
actor VSCodeAdapter: ProviderAdapter {
    let id = "vscode"
    let displayName = "VS Code (Claude)"
    let icon = "curlybraces"

    private let appBundleId = "com.microsoft.VSCode"
    private let appBundleIdInsiders = "com.microsoft.VSCodeInsiders"

    nonisolated var isInstalled: Bool {
        get async {
            let standard = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: appBundleId) != nil
            let insiders = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: appBundleIdInsiders) != nil
            return standard || insiders
        }
    }

    nonisolated var isAuthenticated: Bool {
        get async {
            // VS Code is available if installed; authentication is in the Claude extension
            await isInstalled
        }
    }

    nonisolated var currentProject: String? {
        get async {
            // Try to detect active workspace from VS Code's state
            // This would require accessing VS Code's storage or workspace file
            nil
        }
    }

    nonisolated var activeSession: String? {
        get async {
            // Check if VS Code is running
            let runningApps = NSWorkspace.shared.runningApplications
            let isRunning = runningApps.contains { app in
                app.bundleIdentifier == appBundleId || app.bundleIdentifier == appBundleIdInsiders
            }
            return isRunning ? "vscode-active" : nil
        }
    }

    nonisolated func executeTask(prompt: String, in workDir: String) async throws -> ProviderOutput {
        // Direct execution through VS Code is not supported
        // This adapter focuses on detection and workspace awareness
        throw AdapterError.notSupported("Execute task in VS Code Claude extension manually")
    }

    nonisolated func getAvailableSessions() async throws -> [ProviderSession] {
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains { app in
            app.bundleIdentifier == appBundleId || app.bundleIdentifier == appBundleIdInsiders
        }

        return isRunning ? [
            ProviderSession(
                id: "vscode-main",
                displayName: "VS Code",
                projectPath: nil,
                createdAt: Date(),
                lastActivity: Date(),
                status: "idle"
            )
        ] : []
    }

    nonisolated func openProject(_ path: String) async throws {
        // Open the project in VS Code
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/code")

        // Try alternate path if /usr/local/bin doesn't exist
        if !FileManager.default.fileExists(atPath: "/usr/local/bin/code") {
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/code")
        }

        process.arguments = [path]

        try? process.run()
    }

    nonisolated func stop() async throws {
        // Can't directly stop VS Code
    }
}
