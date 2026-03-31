import Foundation

actor ProcessManager {
    struct PTYSession: Identifiable {
        let id: String
        let agentId: String
        let process: Process
        let outputPipe: Pipe
        let inputPipe: Pipe
        var isRunning: Bool { process.isRunning }
        var transcript: [String] = []
        var completedAt: Date?
        var exitCode: Int32 = 0
    }

    private var sessions: [String: PTYSession] = [:]
    private var processQueue = DispatchQueue(label: "com.neptune.process-manager", attributes: .concurrent)

    // MARK: - Session Management

    func startSession(
        agentId: String,
        workDir: String,
        command: String,
        args: [String] = [],
        env: [String: String] = [:]
    ) async throws -> String {
        let sessionId = UUID().uuidString
        let process = Process()

        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: workDir)

        // Set environment
        var environment = ProcessInfo.processInfo.environment
        for (key, value) in env {
            environment[key] = value
        }
        process.environment = environment

        // Setup pipes
        let outputPipe = Pipe()
        let inputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        process.standardInput = inputPipe

        try process.run()

        // Start reading output
        startReadingOutput(from: outputPipe, sessionId: sessionId)

        let session = PTYSession(
            id: sessionId,
            agentId: agentId,
            process: process,
            outputPipe: outputPipe,
            inputPipe: inputPipe
        )

        sessions[sessionId] = session

        return sessionId
    }

    func sendInput(to sessionId: String, input: String) async throws {
        guard let session = sessions[sessionId] else {
            throw ProcessError.sessionNotFound(sessionId)
        }

        guard let data = (input + "\n").data(using: .utf8) else {
            throw ProcessError.encodingFailed
        }

        session.inputPipe.fileHandleForWriting.write(data)
    }

    func getOutput(from sessionId: String) -> [String] {
        guard let session = sessions[sessionId] else {
            return []
        }
        return session.transcript
    }

    func waitForCompletion(sessionId: String, timeout: TimeInterval = 3600) async throws -> (exitCode: Int32, output: [String]) {
        guard let session = sessions[sessionId] else {
            throw ProcessError.sessionNotFound(sessionId)
        }

        let deadline = Date().addingTimeInterval(timeout)

        while session.process.isRunning && Date() < deadline {
            try await _Concurrency.Task.sleep(nanoseconds: 500_000_000)  // 0.5s
        }

        if session.process.isRunning {
            session.process.terminate()
            throw ProcessError.timeout(sessionId)
        }

        var updated = sessions[sessionId]!
        updated.exitCode = session.process.terminationStatus
        updated.completedAt = Date()
        sessions[sessionId] = updated

        return (updated.exitCode, updated.transcript)
    }

    func stopSession(sessionId: String) async throws {
        guard let session = sessions[sessionId] else {
            throw ProcessError.sessionNotFound(sessionId)
        }

        if session.process.isRunning {
            session.process.terminate()
        }

        var updated = session
        updated.completedAt = Date()
        sessions[sessionId] = updated
    }

    func killAllSessions() async {
        for (_, session) in sessions {
            if session.process.isRunning {
                session.process.terminate()
            }
        }
    }

    // MARK: - Private Helpers

    private func startReadingOutput(from pipe: Pipe, sessionId: String) {
        let queue = DispatchQueue(label: "com.neptune.process-output.\(sessionId)")
        let workItem = DispatchWorkItem {
            let fileHandle = pipe.fileHandleForReading

            while true {
                let data = fileHandle.availableData

                if data.isEmpty {
                    break
                }

                if let line = String(data: data, encoding: .utf8) {
                    let lines = line.components(separatedBy: .newlines).filter { !$0.isEmpty }

                    _Concurrency.Task {
                        await self.appendOutput(to: sessionId, lines: lines)
                    }
                }
            }
        }
        queue.async(execute: workItem)
    }

    private func appendOutput(to sessionId: String, lines: [String]) {
        guard var session = sessions[sessionId] else {
            return
        }

        session.transcript.append(contentsOf: lines)
        sessions[sessionId] = session
    }
}

enum ProcessError: LocalizedError {
    case sessionNotFound(String)
    case timeout(String)
    case encodingFailed
    case failedToStart

    var errorDescription: String? {
        switch self {
        case .sessionNotFound(let id):
            return "Process session not found: \(id)"
        case .timeout(let id):
            return "Process session timed out: \(id)"
        case .encodingFailed:
            return "Failed to encode input"
        case .failedToStart:
            return "Failed to start process"
        }
    }
}
