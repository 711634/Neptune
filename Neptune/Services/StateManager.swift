import Foundation
import Combine

actor StateManager {
    private let projectsDir: URL
    private var fileWatcher: DispatchSourceFileSystemObject?
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private var changeCallback: ((String, Agent) -> Void)?

    nonisolated let fileQueue = DispatchQueue(label: "com.neptune.state-manager", attributes: .concurrent)

    init(projectsDir: URL? = nil) {
        let baseDir = projectsDir ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".neptune/projects")

        // Create directories if needed
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)

        self.projectsDir = baseDir
    }

    // MARK: - Project Persistence

    func saveProject(_ project: ProjectContext) async throws {
        let projectDir = projectsDir.appendingPathComponent(project.id)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let projectFile = projectDir.appendingPathComponent("project.json")
        let data = try jsonEncoder.encode(project)
        try data.write(to: projectFile)
    }

    func loadProject(id: String) async throws -> ProjectContext {
        let projectFile = projectsDir.appendingPathComponent(id).appendingPathComponent("project.json")
        let data = try Data(contentsOf: projectFile)
        return try jsonDecoder.decode(ProjectContext.self, from: data)
    }

    func listProjects() async throws -> [ProjectContext] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil)

        var projects: [ProjectContext] = []
        for dir in contents where dir.hasDirectoryPath {
            if let project = try? await loadProject(id: dir.lastPathComponent) {
                projects.append(project)
            }
        }

        return projects.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Agent State Persistence

    func saveAgentState(_ agent: Agent, projectId: String) async throws {
        let agentDir = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("agents")
            .appendingPathComponent(agent.id)

        try FileManager.default.createDirectory(at: agentDir, withIntermediateDirectories: true)

        let stateFile = agentDir.appendingPathComponent("state.json")
        let data = try jsonEncoder.encode(agent)
        try data.write(to: stateFile)
    }

    func loadAgentState(agentId: String, projectId: String) async throws -> Agent {
        let stateFile = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("agents")
            .appendingPathComponent(agentId)
            .appendingPathComponent("state.json")

        let data = try Data(contentsOf: stateFile)
        return try jsonDecoder.decode(Agent.self, from: data)
    }

    // MARK: - Transcript Management

    func appendTranscript(agentId: String, projectId: String, lines: [String]) async throws {
        let transcriptFile = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("agents")
            .appendingPathComponent(agentId)
            .appendingPathComponent("transcript.log")

        let content = lines.joined(separator: "\n") + "\n"

        if FileManager.default.fileExists(atPath: transcriptFile.path) {
            if let fileHandle = FileHandle(forWritingAtPath: transcriptFile.path) {
                defer { try? fileHandle.close() }
                fileHandle.seekToEndOfFile()
                if let data = content.data(using: .utf8) {
                    fileHandle.write(data)
                }
            }
        } else {
            try content.write(to: transcriptFile, atomically: true, encoding: .utf8)
        }
    }

    func getTranscript(agentId: String, projectId: String) async throws -> [String] {
        let transcriptFile = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("agents")
            .appendingPathComponent(agentId)
            .appendingPathComponent("transcript.log")

        guard FileManager.default.fileExists(atPath: transcriptFile.path) else {
            return []
        }

        let content = try String(contentsOf: transcriptFile, encoding: .utf8)
        return content.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    // MARK: - Checkpoint Management (for resumability)

    func saveCheckpoint(agentId: String, projectId: String, data: [String: String]) async throws {
        let checkpointFile = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("agents")
            .appendingPathComponent(agentId)
            .appendingPathComponent("checkpoint.json")

        let encoded = try jsonEncoder.encode(data)
        try encoded.write(to: checkpointFile)
    }

    func loadCheckpoint(agentId: String, projectId: String) async throws -> [String: String]? {
        let checkpointFile = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("agents")
            .appendingPathComponent(agentId)
            .appendingPathComponent("checkpoint.json")

        guard FileManager.default.fileExists(atPath: checkpointFile.path) else {
            return nil
        }

        let data = try Data(contentsOf: checkpointFile)
        return try jsonDecoder.decode([String: String].self, from: data)
    }

    // MARK: - Task Graph Persistence

    func saveTaskGraph(_ graph: TaskGraph, projectId: String) async throws {
        let graphFile = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("task-graph.json")

        let data = try jsonEncoder.encode(graph)
        try data.write(to: graphFile)
    }

    func loadTaskGraph(projectId: String) async throws -> TaskGraph {
        let graphFile = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("task-graph.json")

        guard FileManager.default.fileExists(atPath: graphFile.path) else {
            return TaskGraph()
        }

        let data = try Data(contentsOf: graphFile)
        return try jsonDecoder.decode(TaskGraph.self, from: data)
    }

    // MARK: - Artifact Tracking

    func recordArtifact(projectId: String, path: String) async throws {
        let artifactDir = projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("artifacts")

        try FileManager.default.createDirectory(at: artifactDir, withIntermediateDirectories: true)

        // Just record the path in a manifest
        let manifestFile = artifactDir.appendingPathComponent("manifest.json")
        var artifacts: [String] = []

        if FileManager.default.fileExists(atPath: manifestFile.path) {
            if let data = try? Data(contentsOf: manifestFile) {
                artifacts = (try? jsonDecoder.decode([String].self, from: data)) ?? []
            }
        }

        if !artifacts.contains(path) {
            artifacts.append(path)
        }

        let data = try jsonEncoder.encode(artifacts)
        try data.write(to: manifestFile)
    }

    // MARK: - Directory Access

    nonisolated func projectDirectory(for projectId: String) -> URL {
        projectsDir.appendingPathComponent(projectId)
    }

    nonisolated func agentDirectory(for agentId: String, in projectId: String) -> URL {
        projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("agents")
            .appendingPathComponent(agentId)
    }

    nonisolated func workspaceDirectory(for projectId: String) -> URL {
        projectsDir
            .appendingPathComponent(projectId)
            .appendingPathComponent("workspace")
    }
}
