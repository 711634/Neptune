import Foundation
import Combine
import SwiftUI

/// Monitors coding/agent activity and determines if overlay should be visible.
/// Pets appear only when there's active coding work happening.
class ActivityMonitor: ObservableObject {
    enum ActivityLevel {
        case inactive
        case dormant
        case active
    }

    @Published var activityLevel: ActivityLevel = .inactive
    @Published var isOverlayVisible: Bool = false

    private var lastActiveTime: Date = Date()
    private var inactivityTimeout: TimeInterval = 30 // seconds
    private var lastAgentStates: [String: AgentStatus] = [:]
    private var activityCheckTimer: Timer?

    private let settings = AppSettings.shared

    init() {
        startActivityMonitoring()
    }

    deinit {
        stopActivityMonitoring()
    }

    /// Update activity based on current agent states and timestamps.
    func updateActivity(with agents: [Agent]) {
        let hasActiveAgents = agents.contains { isAgentActive($0) }
        let hasRecentUpdates = agents.contains { agent in
            let timeSinceUpdate = Date().timeIntervalSince(agent.updatedAt)
            return timeSinceUpdate < 10 // Updated in last 10 seconds
        }

        if hasActiveAgents || hasRecentUpdates {
            lastActiveTime = Date()
            updateActivityLevel(to: .active)
        } else {
            let timeSinceLastActivity = Date().timeIntervalSince(lastActiveTime)
            if timeSinceLastActivity < inactivityTimeout {
                updateActivityLevel(to: .dormant)
            } else {
                updateActivityLevel(to: .inactive)
            }
        }
    }

    /// Determine if a single agent is considered active.
    private func isAgentActive(_ agent: Agent) -> Bool {
        switch agent.status {
        case .coding, .thinking, .planning, .researching, .reviewing, .shipping, .waking:
            return true
        case .success:
            // Show success briefly (2 seconds window)
            let timeSinceUpdate = Date().timeIntervalSince(agent.updatedAt)
            return timeSinceUpdate < 2
        case .idle, .failed, .sleeping, .blocked:
            return false
        }
    }

    private func updateActivityLevel(to newLevel: ActivityLevel) {
        if activityLevel != newLevel {
            activityLevel = newLevel

            // Update overlay visibility with animation
            withAnimation(.easeInOut(duration: 0.6)) {
                isOverlayVisible = (newLevel == .active || newLevel == .dormant)
            }
        }
    }

    private func startActivityMonitoring() {
        activityCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkForTimeoutInactivity()
        }
    }

    private func stopActivityMonitoring() {
        activityCheckTimer?.invalidate()
        activityCheckTimer = nil
    }

    private func checkForTimeoutInactivity() {
        let timeSinceLastActivity = Date().timeIntervalSince(lastActiveTime)
        if activityLevel != .inactive && timeSinceLastActivity > inactivityTimeout {
            updateActivityLevel(to: .inactive)
        }
    }

    /// Configure the inactivity timeout (in seconds).
    func setInactivityTimeout(_ seconds: TimeInterval) {
        inactivityTimeout = max(5, min(300, seconds)) // Clamp 5-300s
    }
}

/// Extension to compare activity levels for animations.
extension ActivityMonitor.ActivityLevel: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.inactive, .inactive), (.dormant, .dormant), (.active, .active):
            return true
        default:
            return false
        }
    }
}
