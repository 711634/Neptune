import SwiftUI
import AppKit
import Combine

@main
struct NeptuneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Neptune Dashboard", id: "dashboard") {
            ContentView()
                .environmentObject(appDelegate.agentWatcher)
                .environmentObject(appDelegate.petMapper)
                .environmentObject(appDelegate.settings)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Settings {
            SettingsView(settings: appDelegate.settings)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var floatingDockWindow: FloatingDockWindow?

    let settings = AppSettings.shared
    let agentWatcher = AgentStateWatcher()
    let petMapper = PetStateMapper()
    let mockGenerator = MockDataGenerator()
    let activityMonitor = ActivityMonitor()

    // NEW: Orchestration services
    let processManager = ProcessManager()
    let stateManager = StateManager()
    let skillRegistry = SkillRegistry()
    var orchestrator: AgentOrchestrator?
    var claudeRunner: ClaudeCodeRunner?
    var providerRegistry: ProviderRegistry?

    @Published var isOrchestratingProject: Bool = false
    @Published var currentProjectId: String?

    var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        createInitialStateFile()
        setupFloatingDock()
        setupMenuBar()
        setupBindings()
        setupNotifications()
        setupMockData()

        // Configure activity monitor with settings
        activityMonitor.setInactivityTimeout(TimeInterval(settings.inactivityTimeoutSeconds))

        // Initialize orchestration services
        let claudeRunner = ClaudeCodeRunner(
            processManager: processManager,
            stateManager: stateManager,
            claudePath: settings.claudeExecutablePath
        )
        self.claudeRunner = claudeRunner

        let orchestrator = AgentOrchestrator(
            processManager: processManager,
            stateManager: stateManager,
            skillRegistry: skillRegistry,
            claudeRunner: claudeRunner
        )
        self.orchestrator = orchestrator

        // Initialize provider registry
        let providerRegistry = ProviderRegistry(stateManager: stateManager)
        self.providerRegistry = providerRegistry

        // Register provider adapters
        _Concurrency.Task {
            let claudeAdapter = ClaudeCodeCLIAdapter(executablePath: settings.claudeExecutablePath)
            let desktopAdapter = ClaudeDesktopAdapter()
            let vscodeAdapter = VSCodeAdapter()

            await providerRegistry.register(claudeAdapter)
            await providerRegistry.register(desktopAdapter)
            await providerRegistry.register(vscodeAdapter)

            // Detect available providers
            await providerRegistry.detectProviders()
        }
    }

    private func setupFloatingDock() {
        floatingDockWindow = FloatingDockWindow(activityMonitor: activityMonitor)
        floatingDockWindow?.orderFront(nil)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateMenuBarIcon()
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupBindings() {
        agentWatcher.$agentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.petMapper.updatePetState(from: state)
                self?.floatingDockWindow?.updateAgents(state.agents)
                self?.updateDockIcon()
            }
            .store(in: &cancellables)

        petMapper.$currentPetState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
                self?.updateDockIcon()
            }
            .store(in: &cancellables)

        // Subscribe to activity visibility changes
        activityMonitor.$activityLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.floatingDockWindow?.setVisibility(to: level)
            }
            .store(in: &cancellables)

        // Update activity monitor when inactivity timeout setting changes
        settings.$inactivityTimeoutSeconds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] seconds in
                self?.activityMonitor.setInactivityTimeout(TimeInterval(seconds))
            }
            .store(in: &cancellables)

        settings.$useMockData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] useMock in
                if useMock {
                    self?.setupMockData()
                } else {
                    self?.mockGenerator.stopMockGeneration()
                    self?.agentWatcher.refresh()
                }
            }
            .store(in: &cancellables)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showSettings),
            name: .openSettings,
            object: nil
        )
    }

    private func createInitialStateFile() {
        let fileManager = FileManager.default
        let stateDir = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("agent-pet")
        let stateFile = stateDir.appendingPathComponent("state.json")

        if !fileManager.fileExists(atPath: stateFile.path) {
            do {
                try fileManager.createDirectory(at: stateDir, withIntermediateDirectories: true)
                let initialState = createInitialAgentState()

                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(initialState)
                try data.write(to: stateFile)
            } catch {
                print("Failed to create initial state file: \(error)")
            }
        }
    }

    private func createInitialAgentState() -> AgentState {
        let agents = [
            Agent(
                id: "agent-1",
                name: "Planner",
                role: .planning,
                task: "Planning tasks",
                status: .thinking,
                elapsedSeconds: 0,
                lastLog: "Initializing...",
                updatedAt: Date(),
                colorVariant: .purple,
                anchorHint: .terminal,
                slotIndex: 0
            ),
            Agent(
                id: "agent-2",
                name: "Builder",
                role: .coding,
                task: "Building features",
                status: .coding,
                elapsedSeconds: 0,
                lastLog: "Starting...",
                updatedAt: Date(),
                colorVariant: .green,
                anchorHint: .browser,
                slotIndex: 1
            ),
            Agent(
                id: "agent-3",
                name: "Reviewer",
                role: .review,
                task: "Reviewing code",
                status: .idle,
                elapsedSeconds: 0,
                lastLog: "Waiting...",
                updatedAt: Date(),
                colorVariant: .blue,
                anchorHint: .figma,
                slotIndex: 2
            ),
            Agent(
                id: "agent-4",
                name: "Shipper",
                role: .shipping,
                task: "Deploying",
                status: .idle,
                elapsedSeconds: 0,
                lastLog: "Ready...",
                updatedAt: Date(),
                colorVariant: .pink,
                anchorHint: .notes,
                slotIndex: 3
            )
        ]
        return AgentState(updatedAt: Date(), agents: agents)
    }

    private func setupMockData() {
        guard settings.useMockData else { return }

        mockGenerator.startMockGeneration(interval: 3.0) { [weak self] state in
            DispatchQueue.main.async {
                self?.writeStateToFile(state)
            }
        }
    }

    private func writeStateToFile(_ state: AgentState) {
        let fileManager = FileManager.default
        let stateFile = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("agent-pet/state.json")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            try data.write(to: stateFile)
        } catch {
            print("Failed to write state: \(error)")
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if popover == nil {
            popover = NSPopover()
            popover?.contentSize = NSSize(width: 260, height: 320)
            popover?.behavior = .transient
            popover?.delegate = self

            let menuBarView = MenuBarView(
                agentWatcher: agentWatcher,
                petMapper: petMapper,
                settings: settings
            )
            popover?.contentViewController = NSHostingController(rootView: menuBarView)
        }

        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover?.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func showSettings() {
        if #available(macOS 13.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    private func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }

        let activeAgents = agentWatcher.agentState.agents.filter { $0.status != .idle }
        let activeColors = activeAgents.map { $0.colorVariant }

        let menuBarIcon = MenuBarPetIcon(petState: petMapper.currentPetState, activeAgentColors: activeColors, size: 18)
        let hostingView = NSHostingView(rootView: menuBarIcon)
        hostingView.frame = NSRect(x: 0, y: 0, width: 18, height: 18)

        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            hostingView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            hostingView.widthAnchor.constraint(equalToConstant: 18),
            hostingView.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    private func updateDockIcon() {
        let icon = createDockIcon(for: petMapper.currentPetState)
        let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
        imageView.image = icon
        NSApp.dockTile.contentView = imageView
        NSApp.dockTile.display()
    }

    private func createDockIcon(for state: PetState) -> NSImage {
        let size = NSSize(width: 128, height: 128)
        let appSettings = self.settings
        let image = NSImage(size: size, flipped: false) { bounds in
            NSColor(red: 0.122, green: 0.161, blue: 0.216, alpha: 1.0).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 20, yRadius: 20).fill()

            let petView = PixelPetView(petState: state, settings: appSettings)
            let hostingView = NSHostingView(rootView: petView)
            hostingView.frame = NSRect(x: 24, y: 24, width: 80, height: 80)
            hostingView.display()

            return true
        }
        return image
    }
}

