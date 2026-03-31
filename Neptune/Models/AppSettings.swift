import Foundation

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var petName: String {
        didSet { defaults.set(petName, forKey: Keys.petName) }
    }

    @Published var idleTimeoutMinutes: Int {
        didSet { defaults.set(idleTimeoutMinutes, forKey: Keys.idleTimeout) }
    }

    @Published var pollingIntervalSeconds: Double {
        didSet { defaults.set(pollingIntervalSeconds, forKey: Keys.pollingInterval) }
    }

    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Keys.soundEnabled) }
    }

    @Published var reducedMotion: Bool {
        didSet { defaults.set(reducedMotion, forKey: Keys.reducedMotion) }
    }

    @Published var useMockData: Bool {
        didSet { defaults.set(useMockData, forKey: Keys.useMockData) }
    }

    @Published var syncPetAnimations: Bool {
        didSet { defaults.set(syncPetAnimations, forKey: Keys.syncPetAnimations) }
    }

    @Published var inactivityTimeoutSeconds: Int {
        didSet { defaults.set(inactivityTimeoutSeconds, forKey: Keys.inactivityTimeout) }
    }

    @Published var claudeExecutablePath: String {
        didSet { defaults.set(claudeExecutablePath, forKey: Keys.claudeExecutablePath) }
    }

    @Published var defaultWorkspacePath: String {
        didSet { defaults.set(defaultWorkspacePath, forKey: Keys.defaultWorkspacePath) }
    }

    @Published var lowPowerMode: Bool {
        didSet { defaults.set(lowPowerMode, forKey: Keys.lowPowerMode) }
    }

    @Published var aggressiveEfficiency: Bool {
        didSet { defaults.set(aggressiveEfficiency, forKey: Keys.aggressiveEfficiency) }
    }

    @Published var maxConcurrentAgents: Int {
        didSet { defaults.set(maxConcurrentAgents, forKey: Keys.maxConcurrentAgents) }
    }

    @Published var preferredProvider: String {
        didSet { defaults.set(preferredProvider, forKey: Keys.preferredProvider) }
    }

    @Published var enabledProviders: Set<String> {
        didSet { defaults.set(Array(enabledProviders), forKey: Keys.enabledProviders) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    private enum Keys {
        static let petName = "petName"
        static let idleTimeout = "idleTimeout"
        static let pollingInterval = "pollingInterval"
        static let soundEnabled = "soundEnabled"
        static let reducedMotion = "reducedMotion"
        static let useMockData = "useMockData"
        static let syncPetAnimations = "syncPetAnimations"
        static let inactivityTimeout = "inactivityTimeout"
        static let claudeExecutablePath = "claudeExecutablePath"
        static let defaultWorkspacePath = "defaultWorkspacePath"
        static let lowPowerMode = "lowPowerMode"
        static let aggressiveEfficiency = "aggressiveEfficiency"
        static let maxConcurrentAgents = "maxConcurrentAgents"
        static let preferredProvider = "preferredProvider"
        static let enabledProviders = "enabledProviders"
        static let launchAtLogin = "launchAtLogin"
    }

    private init() {
        self.petName = defaults.string(forKey: Keys.petName) ?? "Neptune"
        self.idleTimeoutMinutes = defaults.object(forKey: Keys.idleTimeout) as? Int ?? 5
        self.pollingIntervalSeconds = defaults.object(forKey: Keys.pollingInterval) as? Double ?? 2.0
        self.soundEnabled = defaults.object(forKey: Keys.soundEnabled) as? Bool ?? true
        self.reducedMotion = defaults.object(forKey: Keys.reducedMotion) as? Bool ?? false
        self.useMockData = defaults.object(forKey: Keys.useMockData) as? Bool ?? true
        self.syncPetAnimations = defaults.object(forKey: Keys.syncPetAnimations) as? Bool ?? false
        self.inactivityTimeoutSeconds = defaults.object(forKey: Keys.inactivityTimeout) as? Int ?? 30
        self.claudeExecutablePath = defaults.string(forKey: Keys.claudeExecutablePath) ?? "/opt/homebrew/bin/claude"
        self.defaultWorkspacePath = defaults.string(forKey: Keys.defaultWorkspacePath) ?? NSHomeDirectory()
        self.lowPowerMode = defaults.object(forKey: Keys.lowPowerMode) as? Bool ?? false
        self.aggressiveEfficiency = defaults.object(forKey: Keys.aggressiveEfficiency) as? Bool ?? false
        self.maxConcurrentAgents = defaults.object(forKey: Keys.maxConcurrentAgents) as? Int ?? 3
        self.preferredProvider = defaults.string(forKey: Keys.preferredProvider) ?? "claude-code-cli"
        let enabledArray = defaults.array(forKey: Keys.enabledProviders) as? [String] ?? ["claude-code-cli"]
        self.enabledProviders = Set(enabledArray)
        self.launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
    }

    func reset() {
        petName = "Neptune"
        idleTimeoutMinutes = 5
        pollingIntervalSeconds = 2.0
        soundEnabled = true
        reducedMotion = false
        useMockData = true
        syncPetAnimations = false
        inactivityTimeoutSeconds = 30
        claudeExecutablePath = "/opt/homebrew/bin/claude"
        defaultWorkspacePath = NSHomeDirectory()
        lowPowerMode = false
        aggressiveEfficiency = false
        maxConcurrentAgents = 3
        preferredProvider = "claude-code-cli"
        enabledProviders = Set(["claude-code-cli"])
        launchAtLogin = false
    }
}
