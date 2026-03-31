import Foundation
import Combine

class PetStateMapper: ObservableObject {
    @Published var currentPetState: PetState = .idle
    @Published var lastStateChange: Date = Date()

    private let settings = AppSettings.shared
    private var lastAgentUpdate: Date = Date()
    private var recentSuccessTime: Date?
    private var recentFailureTime: Date?

    func updatePetState(from agentState: AgentState) {
        let newState = calculatePetState(from: agentState)

        if newState != currentPetState {
            currentPetState = newState
            lastStateChange = Date()
        }

        if !agentState.agents.isEmpty {
            lastAgentUpdate = Date()
        }

        if agentState.agents.contains(where: { $0.status == .success }) {
            recentSuccessTime = Date()
        }
        if agentState.agents.contains(where: { $0.status == .failed }) {
            recentFailureTime = Date()
        }
    }

    private func calculatePetState(from agentState: AgentState) -> PetState {
        let idleTimeoutSeconds = TimeInterval(settings.idleTimeoutMinutes * 60)
        let timeSinceUpdate = Date().timeIntervalSince(lastAgentUpdate)
        let timeSinceSuccess = recentSuccessTime.map { Date().timeIntervalSince($0) } ?? .infinity
        let timeSinceFailure = recentFailureTime.map { Date().timeIntervalSince($0) } ?? .infinity

        if timeSinceUpdate > idleTimeoutSeconds {
            return .sleeping
        }

        if agentState.agents.isEmpty {
            return .idle
        }

        let hasCoding = agentState.agents.contains { $0.status == .coding }
        if hasCoding {
            return .coding
        }

        let hasThinking = agentState.agents.contains { $0.status == .thinking }
        if hasThinking {
            return .thinking
        }

        if timeSinceFailure < 30 {
            return .failed
        }

        if timeSinceSuccess < 30 {
            return .success
        }

        let hasSuccess = agentState.agents.contains { $0.status == .success }
        if hasSuccess {
            return .success
        }

        let hasFailed = agentState.agents.contains { $0.status == .failed }
        if hasFailed {
            return .failed
        }

        return .idle
    }

    func reset() {
        currentPetState = .idle
        lastStateChange = Date()
        lastAgentUpdate = Date()
        recentSuccessTime = nil
        recentFailureTime = nil
    }
}
