import SwiftUI

struct TaskGraphView: View {
    let taskGraph: TaskGraph
    let onTaskSelected: ((Task) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Task Graph").font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(taskGraph.tasks.values.sorted { $0.createdAt < $1.createdAt }, id: \.id) { task in
                        TaskGraphItemView(task: task)
                            .onTapGesture {
                                onTaskSelected?(task)
                            }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                let completed = taskGraph.tasks.values.filter { $0.status == .completed }.count
                let total = taskGraph.tasks.values.count
                Text("Progress: \(completed)/\(total)").font(.caption).foregroundColor(.gray)

                ProgressView(value: total > 0 ? Double(completed) / Double(total) : 0)
            }

            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct TaskGraphItemView: View {
    let task: Task

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(Color(hex: task.status.color))
                .frame(width: 8, height: 8)

            // Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.description)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(task.roleRequired.displayName)
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text(task.status.displayName)
                        .font(.caption)
                        .foregroundColor(.gray)

                    if !task.dependencies.isEmpty {
                        Text("↑ \(task.dependencies.count) dep")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Duration
            if task.completedAt != nil {
                Text(task.formattedDuration())
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(4)
    }
}

#Preview {
    TaskGraphView(taskGraph: TaskGraph(), onTaskSelected: { _ in })
}
