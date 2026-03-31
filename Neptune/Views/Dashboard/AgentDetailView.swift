import SwiftUI

struct AgentDetailView: View {
    let agent: Agent
    let transcript: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(agent.colorVariant.primaryColor)
                    .font(.system(size: 24))

                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name).font(.headline)
                    Text(agent.role.displayName).font(.caption).foregroundColor(.gray)
                }

                Spacer()

                Text(agent.status.rawValue).font(.caption)
                    .foregroundColor(agent.status.color)
                    .padding(6)
                    .background(agent.status.color.opacity(0.1))
                    .cornerRadius(4)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Current Task").font(.caption).foregroundColor(.gray)
                if let taskId = agent.currentTaskId {
                    Text(taskId).font(.body)
                } else {
                    Text("No task assigned").font(.body).foregroundColor(.gray)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Recent Output").font(.caption).foregroundColor(.gray)
                if let output = agent.lastOutput {
                    Text(output)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(3)
                } else {
                    Text("No output yet").font(.body).foregroundColor(.gray)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Transcript (\(transcript.count) lines)").font(.caption).foregroundColor(.gray)
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(transcript.suffix(10), id: \.self) { line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 120)
                .background(Color.black.opacity(0.1))
                .cornerRadius(4)
            }

            HStack {
                Button(action: {}) {
                    Label("Retry", systemImage: "arrow.clockwise")
                }

                Button(action: {}) {
                    Label("Pause", systemImage: "pause.circle")
                }

                Spacer()

                Button(role: .destructive, action: {}) {
                    Label("Stop", systemImage: "xmark.circle")
                }
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

#Preview {
    let agent = Agent(
        id: "test-1",
        name: "Planner",
        role: .planning,
        task: "Create project plan",
        status: .coding,
        elapsedSeconds: 125,
        lastLog: "Planning architecture...",
        updatedAt: Date(),
        colorVariant: .purple,
        anchorHint: .terminal,
        slotIndex: 0
    )

    AgentDetailView(agent: agent, transcript: ["Line 1", "Line 2", "Line 3"])
}
