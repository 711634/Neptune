import Foundation

struct ProjectContext: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let goal: String
    let projectType: ProjectType
    let workspaceDir: URL
    let createdAt: Date
    var updatedAt: Date

    var agents: [String: Agent] = [:]
    var taskGraph: TaskGraph = TaskGraph()
    var skillPacks: [String] = []
    var transcripts: [String: [String]] = [:]  // agentId → lines

    var isRunning: Bool = false
    var completedAt: Date?
    var buildArtifacts: [String] = []  // paths to built files
    var currentStatus: ProjectStatus = .created

    enum CodingKeys: String, CodingKey {
        case id, name, description, goal, projectType, workspaceDir, createdAt, updatedAt
        case agents, taskGraph, skillPacks, transcripts
        case isRunning, completedAt, buildArtifacts, currentStatus
    }

    init(id: String, name: String, description: String, goal: String, projectType: ProjectType, workspaceDir: URL) {
        self.id = id
        self.name = name
        self.description = description
        self.goal = goal
        self.projectType = projectType
        self.workspaceDir = workspaceDir
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum ProjectType: String, Codable, CaseIterable {
    case webApp = "web_app"
    case pythonCLI = "python_cli"
    case iOSApp = "ios_app"
    case macOSApp = "macos_app"
    case chromeExtension = "chrome_extension"
    case dataAnalysis = "data_analysis"
    case rustLib = "rust_lib"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .webApp: return "Web App (React/Next.js)"
        case .pythonCLI: return "Python CLI"
        case .iOSApp: return "iOS App"
        case .macOSApp: return "macOS App"
        case .chromeExtension: return "Chrome Extension"
        case .dataAnalysis: return "Data Analysis Tool"
        case .rustLib: return "Rust Library"
        case .unknown: return "Unknown"
        }
    }

    var skillPackNames: [String] {
        switch self {
        case .webApp: return ["frontend", "backend", "deployment", "testing"]
        case .pythonCLI: return ["core", "testing", "packaging"]
        case .iOSApp: return ["swiftui", "xcode-build", "testing"]
        case .macOSApp: return ["swiftui", "appkit", "xcode-build", "signing"]
        case .chromeExtension: return ["manifest", "content-scripts", "permissions"]
        case .dataAnalysis: return ["pandas", "visualization", "reporting"]
        case .rustLib: return ["cargo", "testing", "documentation"]
        case .unknown: return ["generic"]
        }
    }

    static func detect(from directory: URL) -> ProjectType {
        let fileManager = FileManager.default
        let contents = try? fileManager.contentsOfDirectory(atPath: directory.path)

        guard let contents = contents else { return .unknown }

        // Check for characteristic files
        if contents.contains("package.json") || contents.contains("tsconfig.json") {
            return .webApp
        }
        if contents.contains("requirements.txt") || contents.contains("pyproject.toml") {
            return .pythonCLI
        }
        if contents.contains("Cargo.toml") {
            return .rustLib
        }
        if contents.contains("pubspec.yaml") {
            return .unknown  // Flutter
        }
        if contents.contains("manifest.json") {
            return .chromeExtension
        }

        return .unknown
    }
}

enum ProjectStatus: String, Codable, CaseIterable {
    case created
    case initializing
    case planning
    case inProgress
    case paused
    case completed
    case failed
    case archived
}
