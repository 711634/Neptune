import Foundation
import Combine

class SkillRegistry: ObservableObject {
    @Published var loadedSkills: [Skill] = []
    @Published var skillPacksDir: URL
    @Published var lastError: String?

    private let fileManager = FileManager.default

    init(skillPacksDir: URL? = nil) {
        let baseDir = skillPacksDir ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".neptune/skills")
        self.skillPacksDir = baseDir

        // Create directory if needed
        try? fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true)

        // Load built-in example skills
        loadExampleSkills()
    }

    // MARK: - Public API

    func detectProjectType(in directory: URL) -> ProjectType {
        ProjectType.detect(from: directory)
    }

    func loadSkillPack(for projectType: ProjectType) -> [Skill] {
        loadedSkills.filter { skill in
            skill.projectTypes.contains(projectType.rawValue)
        }
    }

    func getSkill(id: String) -> Skill? {
        loadedSkills.first { $0.id == id }
    }

    func getSkillsForRole(_ role: AgentRole) -> [Skill] {
        loadedSkills.filter { $0.supportedRoles.contains(role) }
    }

    func getSkillPrompt(skillId: String, role: AgentRole) -> String {
        guard let skill = getSkill(id: skillId) else {
            return "You are an AI assistant. Complete the assigned task."
        }

        return skill.rolePrompt(for: role)
    }

    func loadSkillsFromDisk() {
        var skills: [Skill] = []

        // Load from YAML/JSON files in ~/.neptune/skills/
        do {
            let contents = try fileManager.contentsOfDirectory(at: skillPacksDir, includingPropertiesForKeys: nil)

            for packageDir in contents where packageDir.hasDirectoryPath {
                let packageName = packageDir.lastPathComponent

                // Load all YAML/JSON files in this directory
                if let packageSkills = try loadSkillPackage(from: packageDir, packageName: packageName) {
                    skills.append(contentsOf: packageSkills)
                }
            }

            loadedSkills = skills
        } catch {
            lastError = "Failed to load skills from disk: \(error.localizedDescription)"
        }
    }

    // MARK: - Private Helpers

    private func loadExampleSkills() {
        loadedSkills = [
            .exampleFrontend,
            .exampleBackend,
            .exampleSwiftUI,
            .examplePython,
            // Add generic fallback skill
            genericSkill()
        ]
    }

    private func loadSkillPackage(from directory: URL, packageName: String) throws -> [Skill]? {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)

        var skills: [Skill] = []

        for file in contents {
            if file.pathExtension == "yaml" || file.pathExtension == "yml" || file.pathExtension == "json" {
                // Try to parse as skill file
                // For now, this is a placeholder since we're using hardcoded skills
                // In production, you'd parse YAML/JSON here
            }
        }

        return skills.isEmpty ? nil : skills
    }

    private func genericSkill() -> Skill {
        Skill(
            id: "generic:fallback",
            name: "Generic Assistant",
            description: "Fallback generic skill for unknown project types",
            category: "generic",
            projectTypes: ["unknown"],
            supportedRoles: [.planning, .research, .coding, .review, .shipping],
            systemPrompt: """
                You are a helpful AI assistant. Your task is to help with software development
                and project work. Be thorough, follow best practices, and provide clear output.
                """,
            rolePrompts: [
                "planning": "Create a detailed plan for the project.",
                "research": "Research and gather information about the task.",
                "coding": "Write clean, well-documented code.",
                "review": "Review the work and suggest improvements.",
                "shipping": "Prepare the project for delivery."
            ],
            completionPrompt: """
                Output completion status as JSON:
                {
                  "status": "success|failed|blocked",
                  "summary": "What was done",
                  "filesModified": [],
                  "nextRole": null,
                  "errors": []
                }
                """,
            allowedTools: ["file_edit", "file_read", "run_command"],
            completionCriteria: [
                "Task completed successfully"
            ],
            relatedSkills: [],
            estimatedDuration: 1800,
            priority: 1,
            fallbackSkill: nil
        )
    }
}

// MARK: - Skill YAML/JSON Loading (Placeholder for future)

extension SkillRegistry {
    // In a full implementation, these would parse YAML/JSON
    // For now, we use hardcoded example skills loaded above

    func loadSkillFromYAML(_ path: URL) throws -> Skill? {
        // TODO: Implement YAML parsing
        // For production, use a YAML library like YAMLEncoder
        return nil
    }

    func loadSkillFromJSON(_ path: URL) throws -> Skill? {
        let data = try Data(contentsOf: path)
        let decoder = JSONDecoder()
        return try decoder.decode(Skill.self, from: data)
    }
}
