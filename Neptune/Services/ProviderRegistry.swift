import Foundation

/// Circuit breaker state for a provider
enum CircuitBreakerState: Sendable {
    case closed  // Normal operation
    case open    // Too many failures; reject requests
    case halfOpen  // Testing if provider recovered

    var canAttemptRequest: Bool {
        switch self {
        case .closed, .halfOpen:
            return true
        case .open:
            return false
        }
    }
}

/// Provider health tracking with circuit breaker
struct ProviderHealth: Sendable {
    var consecutiveFailures: Int = 0
    var lastFailureTime: Date?
    var state: CircuitBreakerState = .closed
    var totalFailures: Int = 0
    var totalRequests: Int = 0

    var failureRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(totalFailures) / Double(totalRequests)
    }
}

/// Registry for managing provider health and circuit breaker state
actor ProviderHealthRegistry: Sendable {
    private var providers: [String: ProviderHealth] = [:]

    private let failureThreshold: Int = 3
    private let recoveryTimeSeconds: TimeInterval = 60
    private let halfOpenAttempts: Int = 1

    init() {
        // Register known providers
        providers["claude-code"] = ProviderHealth()
        providers["shell"] = ProviderHealth()
        providers["filesystem"] = ProviderHealth()
    }

    // MARK: - Health Tracking

    func recordSuccess(provider: String) {
        var health = providers[provider] ?? ProviderHealth()

        health.consecutiveFailures = 0
        health.totalRequests += 1

        // If in half-open state and request succeeds, close circuit
        if health.state == .halfOpen {
            health.state = .closed
        }

        providers[provider] = health
    }

    func recordFailure(provider: String, error: ProviderError) {
        var health = providers[provider] ?? ProviderHealth()

        // Only count non-retryable errors toward circuit breaker
        if !error.isRetryable {
            health.consecutiveFailures += 1
            health.totalFailures += 1
            health.lastFailureTime = Date()

            // Transition to open if threshold exceeded
            if health.consecutiveFailures >= failureThreshold && health.state == .closed {
                health.state = .open
            }
        }

        health.totalRequests += 1
        providers[provider] = health
    }

    func getHealth(provider: String) -> ProviderHealth {
        providers[provider] ?? ProviderHealth()
    }

    func canAttempt(provider: String) -> Bool {
        let health = getHealth(provider: provider)

        switch health.state {
        case .closed:
            return true
        case .open:
            // Check if recovery time has elapsed; if so, try half-open
            if let lastFailure = health.lastFailureTime,
               Date().timeIntervalSince(lastFailure) > recoveryTimeSeconds {
                return true  // Allow attempt to test recovery
            }
            return false
        case .halfOpen:
            return true
        }
    }

    func getHealthReport(provider: String) -> String {
        let health = getHealth(provider: provider)
        return """
        Provider: \(provider)
        State: \(health.state)
        Consecutive Failures: \(health.consecutiveFailures)
        Total Failures: \(health.totalFailures) / \(health.totalRequests)
        Failure Rate: \(String(format: "%.1f", health.failureRate * 100))%
        """
    }

    func getAllHealthReports() -> [String: String] {
        var reports: [String: String] = [:]
        for provider in providers.keys {
            reports[provider] = getHealthReport(provider: provider)
        }
        return reports
    }

    func reset(provider: String) {
        var health = providers[provider] ?? ProviderHealth()
        health.consecutiveFailures = 0
        health.state = .closed
        providers[provider] = health
    }

    func resetAll() {
        for provider in providers.keys {
            reset(provider: provider)
        }
    }
}
