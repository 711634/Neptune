import Foundation
import Combine

class AgentStateWatcher: ObservableObject {
    @Published var agentState: AgentState = .empty
    @Published var lastError: String?
    @Published var isWatching: Bool = false

    private var fileWatcher: DispatchSourceFileSystemObject?
    private var timer: Timer?
    private var lastKnownModificationDate: Date?
    private let settings = AppSettings.shared
    private var settingsObserver: AnyCancellable?

    var stateFileURL: URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        if settings.useMockData {
            return homeDir.appendingPathComponent("agent-pet/state.json")
        }
        return homeDir.appendingPathComponent("agent-pet/state.json")
    }

    var alternativeMockURL: URL {
        Bundle.main.url(forResource: "state", withExtension: "json") ?? stateFileURL
    }

    init() {
        setupSettingsObserver()
        startWatching()
    }

    deinit {
        stopWatching()
    }

    func startWatching() {
        isWatching = true
        setupFileWatcher()
        setupTimer()
        refresh()
    }

    func stopWatching() {
        isWatching = false
        fileWatcher?.cancel()
        fileWatcher = nil
        timer?.invalidate()
        timer = nil
        settingsObserver = nil
    }

    private func setupFileWatcher() {
        let filePath = stateFileURL.path

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard FileManager.default.fileExists(atPath: filePath) else {
                DispatchQueue.main.async {
                    self?.lastError = "State file not found, will retry"
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                        self?.setupFileWatcher()
                    }
                }
                return
            }

            let descriptor = open(filePath, O_EVTONLY)
            guard descriptor >= 0 else {
                DispatchQueue.main.async {
                    self?.lastError = "Could not open file for watching"
                }
                return
            }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .extend, .attrib],
                queue: .main
            )

            source.setEventHandler { [weak self] in
                self?.refresh()
            }

            source.setCancelHandler {
                close(descriptor)
            }

            DispatchQueue.main.async {
                self?.fileWatcher = source
                source.resume()
            }
        }
    }

    private func setupSettingsObserver() {
        settingsObserver = settings.$pollingIntervalSeconds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.restartTimer()
            }
    }

    private func setupTimer() {
        timer = Timer.scheduledTimer(
            withTimeInterval: settings.pollingIntervalSeconds,
            repeats: true
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    private func restartTimer() {
        timer?.invalidate()
        timer = nil
        setupTimer()
    }

    func refresh() {
        guard FileManager.default.fileExists(atPath: stateFileURL.path) else {
            lastError = "State file not found"
            agentState = .empty
            return
        }

        do {
            let data = try Data(contentsOf: stateFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            agentState = try decoder.decode(AgentState.self, from: data)
            lastError = nil
        } catch {
            lastError = "Failed to parse state: \(error.localizedDescription)"
            agentState = .empty
        }
    }

    func getActiveAgentCount() -> Int {
        return agentState.agents.filter { $0.status != .idle }.count
    }

    func getSummaryText() -> String {
        let count = getActiveAgentCount()
        if count == 0 {
            return "No active agents"
        } else if count == 1 {
            return "1 agent active"
        } else {
            return "\(count) agents active"
        }
    }
}
