import SwiftUI

struct DashboardView: View {
    @ObservedObject var agentWatcher: AgentStateWatcher
    @ObservedObject var petMapper: PetStateMapper
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .background(Color(hex: "374151"))

            if agentWatcher.lastError != nil {
                errorBanner
            }

            ScrollView {
                VStack(spacing: 16) {
                    petSection
                    agentsSection
                    statusSection
                }
                .padding(20)
            }
        }
        .frame(width: 360, height: 480)
        .background(Color(hex: "111827"))
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                PixelPetView(petState: petMapper.currentPetState, settings: settings)
                    .scaleEffect(0.5)

                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.petName)
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(.white)

                    Text(petMapper.currentPetState.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(petMapper.currentPetState.color)
                }
            }

            Spacer()

            Button(action: {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "9CA3AF"))
            }
            .buttonStyle(.plain)
            .help("Open Settings")
        }
        .padding(16)
        .background(Color(hex: "1F2937"))
    }

    private var errorBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(hex: "F59E0B"))

            Text(agentWatcher.lastError ?? "Unknown error")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "F59E0B"))

            Spacer()
        }
        .padding(8)
        .background(Color(hex: "F59E0B").opacity(0.1))
    }

    private var petSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PET STATUS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "6B7280"))
                .tracking(1)

            HStack(spacing: 16) {
                PixelPetView(petState: petMapper.currentPetState, settings: settings)
                    .scaleEffect(0.8)

                VStack(alignment: .leading, spacing: 6) {
                    statusRow(icon: "heart.fill", label: "State", value: petMapper.currentPetState.displayName, color: petMapper.currentPetState.color)
                    statusRow(icon: "clock", label: "Last change", value: formatTimeAgo(petMapper.lastStateChange), color: Color(hex: "9CA3AF"))
                    statusRow(icon: "clock.badge.checkmark", label: "Last update", value: formatTimeAgo(agentWatcher.agentState.updatedAt), color: Color(hex: "9CA3AF"))
                }
            }
        }
        .padding(12)
        .background(Color(hex: "1F2937"))
        .cornerRadius(8)
    }

    private func statusRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "6B7280"))
                .frame(width: 14)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "9CA3AF"))

            Spacer()

            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
        }
    }

    private var agentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AGENTS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "6B7280"))
                    .tracking(1)

                Spacer()

                Text("\(agentWatcher.agentState.agents.count) total")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "6B7280"))
            }

            if agentWatcher.agentState.agents.isEmpty {
                Text("No agents connected")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "6B7280"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(agentWatcher.agentState.agents) { agent in
                    AgentRowView(agent: agent)
                }
            }
        }
        .padding(12)
        .background(Color(hex: "1F2937"))
        .cornerRadius(8)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CONNECTION")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "6B7280"))
                .tracking(1)

            HStack {
                Circle()
                    .fill(agentWatcher.isWatching ? Color(hex: "10B981") : Color(hex: "EF4444"))
                    .frame(width: 8, height: 8)

                Text(agentWatcher.isWatching ? "Watching state file" : "Not watching")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "9CA3AF"))

                Spacer()

                Text("Polling: \(String(format: "%.1f", settings.pollingIntervalSeconds))s")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "6B7280"))
            }
        }
        .padding(12)
        .background(Color(hex: "1F2937"))
        .cornerRadius(8)
    }

    private func formatTimeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "\(seconds)s ago"
        } else if seconds < 3600 {
            return "\(seconds / 60)m ago"
        } else {
            return "\(seconds / 3600)h ago"
        }
    }
}
