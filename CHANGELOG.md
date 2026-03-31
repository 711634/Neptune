# Changelog

All notable changes to Neptune will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0-beta] - 2026-03-31

### Added

#### Core Orchestration
- **AgentOrchestrator** — Multi-agent lifecycle management with autonomous task execution
- **ProcessManager** — PTY session management for Claude Code CLI integration
- **StateManager** — File-based persistence with event-driven coordination
- **TaskGraph** — Dependency-aware task scheduling with circular dependency detection
- **SkillRegistry** — YAML-based skill pack loading with project type auto-detection
- **ClaudeCodeRunner** — Local Claude Code CLI execution with output capture

#### Provider System
- **ProviderAdapter protocol** — Pluggable execution backend interface
- **ClaudeCodeCLIAdapter** — Full task execution via Claude Code CLI (primary MVP backend)
- **ClaudeDesktopAdapter** — Detection-only adapter for Claude Desktop app
- **VSCodeAdapter** — Detection and workspace integration for VS Code + Claude
- **ProviderRegistry** — Dynamic provider registration and selection

#### User Interface
- **Dashboard** — Real-time project status, task graph visualization, agent monitoring
- **Floating Dock Window** — Animated dock pets tied to actual agent activity
- **Menu Bar Integration** — Quick status and navigation
- **Settings Panel** — Configuration for providers, efficiency modes, launch behavior
- **Project Creator** — Guided project setup with auto-detection
- **Agent Detail View** — Per-agent task status, output logs, transcript inspection

#### Battery Efficiency
- **Low Power Mode** — Reduces animation frame rate, limits concurrent agents
- **Aggressive Efficiency Mode** — Single active agent with minimal UI updates
- **Event-driven Coordination** — Zero-polling architecture for resource efficiency
- **Smart Inactivity Timeout** — Auto-pause when user inactive for configured duration

#### Configuration & Data
- **Persistent Settings** — Claude path, workspace, efficiency modes, provider preferences
- **Skill Packs** — Pre-built role prompts for web_app, macos_app, python_cli
- **Local State Storage** — `~/.neptune/` directory with project context and agent state
- **Mock Data Generator** — Development/testing support with realistic agent state

### Project Structure

```
Neptune/
├── App/                   # SwiftUI app entry point
├── Models/               # Data models (Agent, Task, ProjectContext, etc.)
├── Services/             # Core services (Orchestrator, ProcessManager, ProviderRegistry, etc.)
├── Views/
│   ├── Dashboard/        # Project and task management UI
│   ├── Pet/             # Dock pet visual system
│   ├── Settings/        # Configuration UI
│   └── MenuBar/         # Menu bar integration
└── Resources/           # Assets and default state files

docs/
├── WINDOWS_ROADMAP.md   # 4-phase cross-platform implementation plan
└── architecture/
    └── PROVIDER_ADAPTERS.md  # Technical deep-dive on provider system
```

### Documentation

- **README.md** — Internal development guide
- **README_GITHUB.md** — Public GitHub README with features, quick start, architecture
- **CONTRIBUTING.md** — Contribution guidelines and development setup
- **IMPLEMENTATION_SUMMARY.md** — Comprehensive technical summary of what was built
- **WINDOWS_ROADMAP.md** — Detailed plan for Windows (Qt/WPF) and cross-platform core (Rust)

### Build & Packaging

- **Neptune.app** — Fully functional macOS application
- **Neptune.dmg** — Distributable disk image for installation
- **Code Signing** — "Sign to Run Locally" for development
- **Release Build** — Optimized Release configuration

### Known Limitations

- **MVP Scope** — Orchestration core complete; autonomous long-running workflows in progress
- **Windows** — Roadmap documented, implementation planned for Q3 2026
- **Provider Depth**:
  - Claude Code CLI: Full execution support ✅
  - Claude Desktop: Detection + launch only (deeper integration planned)
  - VS Code: Detection + launch only (extension integration planned)
- **Skill Packs** — 3 included (web_app, macos_app, python_cli); more coming
- **Blueprint Templates** — Basic set included; project templates in progress

### Technical Details

- **Language**: Swift 5.9+ with strict concurrency enabled
- **Frameworks**: SwiftUI, AppKit, Combine
- **Architecture**: Actor-based concurrency, protocol-oriented design
- **State**: File-based (~/.neptune/) for zero external dependencies
- **Minimum macOS**: 13.0 (Ventura)

### Next Steps (Post-MVP)

- [ ] Windows implementation (Q3 2026)
- [ ] Deeper provider integration (Claude Desktop API, VS Code extension)
- [ ] Extended skill packs (web3, data science, embedded systems, etc.)
- [ ] Blueprint/template system for project scaffolding
- [ ] Real-time agent transcription and streaming
- [ ] Distributed multi-machine orchestration
- [ ] GitHub integration (auto-commit, PR creation)
- [ ] Mobile companion app (iOS/iPadOS)

---

**Neptune v1.0-beta** — *Local autonomous agents, no cloud required.*
## [v1.0.0] - 2026-03-31
- Initial production release
- Cross-platform macOS DMG + Windows MSI
- Swift macOS app + Tauri Windows app

