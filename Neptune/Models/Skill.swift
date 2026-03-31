import Foundation

struct Skill: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let category: String  // "frontend", "backend", "testing", etc.

    let projectTypes: [String]  // Which ProjectTypes use this skill
    let supportedRoles: [AgentRole]  // Which agent roles use this skill

    // Prompts
    let systemPrompt: String  // Base system context
    let rolePrompts: [String: String]  // AgentRole.rawValue → specific prompt
    let completionPrompt: String  // How to signal completion

    // Configuration
    let allowedTools: [String]  // Constraints on what agent can do
    let completionCriteria: [String]  // Success indicators
    let relatedSkills: [String]  // IDs of skills that pair well
    let estimatedDuration: TimeInterval  // How long typically (seconds)
    let priority: Int  // 1-10, higher = more important
    let fallbackSkill: String?  // ID to use if this skill unavailable

    func rolePrompt(for role: AgentRole) -> String {
        rolePrompts[role.rawValue] ?? systemPrompt
    }
}

struct SkillPack: Codable {
    let projectType: String
    let skills: [Skill]
}

// YAML/JSON format on disk:
// web_app/
//   frontend.yaml
//   backend.yaml
//   deployment.yaml
// Parsed into Skill objects at load time

extension Skill {
    static var exampleFrontend: Skill {
        Skill(
            id: "web_app:frontend",
            name: "Frontend Development",
            description: "Build responsive React/Vue frontends with modern tooling",
            category: "frontend",
            projectTypes: ["web_app"],
            supportedRoles: [.coding, .review, .research],
            systemPrompt: """
                You are an expert frontend engineer. Your role is to design and implement
                responsive, performant web UI using modern frameworks like React, Vue, or Next.js.
                Focus on component architecture, accessibility, and user experience.
                """,
            rolePrompts: [
                "coding": """
                    Write clean, idiomatic frontend code. Use TypeScript where available.
                    Create reusable components. Include proper error handling and loading states.
                    """,
                "review": """
                    Review the frontend code for performance, accessibility, component reusability,
                    and adherence to design systems. Suggest improvements.
                    """
            ],
            completionPrompt: """
                Output completion status as JSON:
                {
                  "status": "success|failed|blocked",
                  "summary": "What was accomplished",
                  "filesModified": ["file1.tsx", "file2.tsx"],
                  "componentsCreated": ["Component1", "Component2"],
                  "nextStep": "backend|testing|review"
                }
                """,
            allowedTools: ["file_edit", "run_npm", "preview_browser"],
            completionCriteria: [
                "All components render without errors",
                "TypeScript types are correct",
                "Responsive design verified",
                "Accessibility checklist passed"
            ],
            relatedSkills: ["web_app:testing", "web_app:backend"],
            estimatedDuration: 3600,
            priority: 8,
            fallbackSkill: nil
        )
    }

    static var exampleBackend: Skill {
        Skill(
            id: "web_app:backend",
            name: "Backend Development",
            description: "Build scalable APIs and services",
            category: "backend",
            projectTypes: ["web_app"],
            supportedRoles: [.coding, .review],
            systemPrompt: """
                You are an expert backend engineer. Design and implement RESTful APIs,
                database schemas, and server-side logic. Focus on security, performance,
                and scalability.
                """,
            rolePrompts: [
                "coding": """
                    Implement the backend using Node.js/Express, Python/FastAPI, or similar.
                    Write clean, well-tested code. Include proper error handling and validation.
                    Use environment variables for configuration.
                    """
            ],
            completionPrompt: """
                Output completion status as JSON:
                {
                  "status": "success|failed|blocked",
                  "apiEndpoints": ["/api/users", "/api/items"],
                  "databaseSchema": "Describe tables/collections",
                  "nextStep": "testing|deployment|frontend"
                }
                """,
            allowedTools: ["file_edit", "run_tests", "database"],
            completionCriteria: [
                "All endpoints tested",
                "Database migrations pass",
                "Error handling comprehensive"
            ],
            relatedSkills: ["web_app:testing", "web_app:frontend"],
            estimatedDuration: 5400,
            priority: 8,
            fallbackSkill: nil
        )
    }

    static var exampleSwiftUI: Skill {
        Skill(
            id: "macos_app:swiftui",
            name: "SwiftUI Development",
            description: "Build macOS apps with SwiftUI",
            category: "ui",
            projectTypes: ["macos_app"],
            supportedRoles: [.coding, .review],
            systemPrompt: """
                You are an expert macOS developer using SwiftUI.
                Build modern, efficient UIs following Apple's design guidelines.
                """,
            rolePrompts: [
                "coding": """
                    Write SwiftUI code that is idiomatic and performant.
                    Use @State, @StateObject, and Combine appropriately.
                    Include proper error handling and accessibility features.
                    """
            ],
            completionPrompt: """
                Output completion status as JSON:
                {
                  "status": "success|failed|blocked",
                  "viewsCreated": ["ContentView", "DetailView"],
                  "stateManagement": "MVVM|MVC description",
                  "nextStep": "testing|build"
                }
                """,
            allowedTools: ["file_edit", "xcode_build", "simulator"],
            completionCriteria: [
                "SwiftUI code compiles",
                "Views render correctly",
                "State management is clean"
            ],
            relatedSkills: ["macos_app:xcode_build"],
            estimatedDuration: 3600,
            priority: 9,
            fallbackSkill: nil
        )
    }

    static var examplePython: Skill {
        Skill(
            id: "python_cli:core",
            name: "Python CLI Development",
            description: "Build Python command-line tools",
            category: "core",
            projectTypes: ["python_cli"],
            supportedRoles: [.coding, .review],
            systemPrompt: """
                You are an expert Python developer. Build clean, well-tested CLI applications
                using Click or Typer. Follow Python best practices and PEP 8 conventions.
                """,
            rolePrompts: [
                "coding": """
                    Write Python code that is idiomatic and well-documented.
                    Use type hints throughout. Include comprehensive error handling.
                    Use logging for debugging output.
                    """
            ],
            completionPrompt: """
                Output completion status as JSON:
                {
                  "status": "success|failed|blocked",
                  "commandsCreated": ["command1", "command2"],
                  "testsPassed": true,
                  "nextStep": "testing|packaging"
                }
                """,
            allowedTools: ["file_edit", "run_python", "run_tests"],
            completionCriteria: [
                "All tests pass",
                "Code follows PEP 8",
                "CLI is usable"
            ],
            relatedSkills: ["python_cli:testing"],
            estimatedDuration: 3600,
            priority: 8,
            fallbackSkill: nil
        )
    }
}
