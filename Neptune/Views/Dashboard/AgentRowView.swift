import SwiftUI

struct AgentRowView: View {
    let agent: Agent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(agent.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                Text(agent.formattedElapsedTime)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(hex: "6B7280"))
            }

            Text(agent.task)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "9CA3AF"))
                .lineLimit(1)

            HStack {
                Image(systemName: statusIcon)
                    .font(.system(size: 10))
                    .foregroundColor(statusColor)

                Text(agent.lastLog)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "6B7280"))
                    .lineLimit(1)

                Spacer()
            }
        }
        .padding(10)
        .background(Color(hex: "374151").opacity(0.5))
        .cornerRadius(6)
    }

    private var statusColor: Color {
        switch agent.status {
        case .idle:
            return Color(hex: "6B7280")
        case .thinking:
            return Color(hex: "F59E0B")
        case .coding:
            return Color(hex: "10B981")
        case .success:
            return Color(hex: "10B981")
        case .failed:
            return Color(hex: "EF4444")
        case .sleeping:
            return Color(hex: "3B82F6")
        default:
            return Color(hex: "6B7280")
        }
    }

    private var statusIcon: String {
        switch agent.status {
        case .idle:
            return "moon.fill"
        case .thinking:
            return "brain"
        case .coding:
            return "chevron.left.forwardslash.chevron.right"
        case .success:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .sleeping:
            return "zzz"
        default:
            return "circle.fill"
        }
    }
}
