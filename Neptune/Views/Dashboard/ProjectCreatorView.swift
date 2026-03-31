import SwiftUI

struct ProjectCreatorView: View {
    @State var projectName: String = ""
    @State var projectDescription: String = ""
    @State var projectGoal: String = ""
    @State var isCreating: Bool = false
    @State var errorMessage: String?

    var onProjectCreated: ((ProjectContext) -> Void)?
    var onCancel: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create New Project").font(.title)

            VStack(alignment: .leading, spacing: 4) {
                Text("Project Name").font(.caption).foregroundColor(.gray)
                TextField("My App", text: $projectName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Description").font(.caption).foregroundColor(.gray)
                TextField("What is this project about?", text: $projectDescription)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("High-Level Goal").font(.caption).foregroundColor(.gray)
                TextEditor(text: $projectGoal)
                    .frame(height: 80)
                    .border(Color.gray.opacity(0.3))
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Button("Cancel") {
                    onCancel?()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    createProject()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(projectName.isEmpty || projectGoal.isEmpty || isCreating)
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }

    private func createProject() {
        errorMessage = nil
        isCreating = true

        _Concurrency.Task(priority: .userInitiated) { @MainActor in
            do {
                let projectType = ProjectType.unknown

                let workspaceDir = URL(fileURLWithPath: NSHomeDirectory())
                    .appendingPathComponent("neptune-projects")
                    .appendingPathComponent(UUID().uuidString)

                try FileManager.default.createDirectory(at: workspaceDir, withIntermediateDirectories: true)

                let project = ProjectContext(
                    id: UUID().uuidString,
                    name: projectName,
                    description: projectDescription,
                    goal: projectGoal,
                    projectType: projectType,
                    workspaceDir: workspaceDir
                )

                isCreating = false
                onProjectCreated?(project)
            } catch {
                errorMessage = error.localizedDescription
                isCreating = false
            }
        }
    }
}

#Preview {
    ProjectCreatorView()
}
