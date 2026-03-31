import Foundation
import Combine

/// Protocol for environment adapters (Claude Code CLI, Claude Desktop, VS Code, etc.)
protocol ProviderAdapter: AnyObject, Sendable {
    var id: String { get }
    var displayName: String { get }
    var icon: String { get }
    var isInstalled: Bool { get async }
    var isAuthenticated: Bool { get async }
    var currentProject: String? { get async }
    var activeSession: String? { get async }

    func executeTask(prompt: String, in workDir: String) async throws -> ProviderOutput
    func getAvailableSessions() async throws -> [ProviderSession]
    func openProject(_ path: String) async throws
    func stop() async throws
}

/// Output from a provider's task execution
struct ProviderOutput: Sendable, Codable {
    let sessionId: String
    let status: String  // "success", "failed", "blocked"
    let output: String
    let filesModified: [String]
    let errors: [String]
    let duration: TimeInterval
}

/// Active session in a provider
struct ProviderSession: Sendable, Identifiable, Codable {
    let id: String
    let displayName: String
    let projectPath: String?
    let createdAt: Date
    let lastActivity: Date?
    let status: String  // "idle", "running", "blocked"
}

/// Unified provider registry
actor ProviderRegistry: ObservableObject {
    @Published var providers: [String: ProviderAdapter] = [:]
    @Published var activeProvider: String? = nil

    private let stateManager: StateManager

    init(stateManager: StateManager) {
        self.stateManager = stateManager
    }

    /// Register a provider adapter
    func register(_ provider: ProviderAdapter) {
        providers[provider.id] = provider
    }

    /// Get the best available provider based on installation and authentication
    func getAvailableProvider() async -> ProviderAdapter? {
        for (_, provider) in providers {
            let installed = await provider.isInstalled
            let authenticated = await provider.isAuthenticated
            if installed && authenticated {
                return provider
            }
        }
        return nil
    }

    /// Detect all installed and configured providers
    func detectProviders() async {
        var detected: [String: ProviderAdapter] = [:]

        // Check each registered provider
        for (id, provider) in providers {
            if await provider.isInstalled {
                detected[id] = provider
            }
        }

        providers = detected
    }

    /// Get status of all providers
    func getStatus() async -> [ProviderStatus] {
        var statuses: [ProviderStatus] = []

        for (_, provider) in providers {
            let installed = await provider.isInstalled
            let authenticated = await provider.isAuthenticated
            let project = await provider.currentProject
            let session = await provider.activeSession

            statuses.append(ProviderStatus(
                providerId: provider.id,
                displayName: provider.displayName,
                installed: installed,
                authenticated: authenticated,
                currentProject: project,
                activeSession: session
            ))
        }

        return statuses
    }
}

/// Status snapshot of a single provider
struct ProviderStatus: Sendable, Identifiable {
    var id: String { providerId }
    let providerId: String
    let displayName: String
    let installed: Bool
    let authenticated: Bool
    let currentProject: String?
    let activeSession: String?
}
