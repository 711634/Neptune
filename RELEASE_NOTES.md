# Neptune v1.0.0-beta Release Notes

**Release Date:** March 31, 2026

## 🎉 Welcome to Neptune

Neptune is a lightweight, battery-efficient autonomous agent platform for macOS that brings real multi-agent orchestration to your Mac. It integrates with your existing Claude subscription and leverages local authentication—**no external APIs, no billing**.

This is the first public beta release. The app is fully functional for the MVP scope described below. While some advanced features are still in development, Neptune is ready for testing and feedback.

## ✨ What's Included in v1.0.0-beta

### Core Features

✅ **Real Multi-Agent Orchestration**
- AgentOrchestrator manages multiple agents with task dependencies
- Task graphs prevent deadlocks and ensure correct execution order
- Event-driven coordination (zero polling) for battery efficiency

✅ **Local Execution via Claude Code CLI**
- No external API calls or billing—uses Claude Code CLI (already authenticated)
- Full automation of coding tasks, planning, review, and deployment workflows
- Transparent process management with full output capture and transcripts

✅ **Smart Provider Detection**
- Automatically detects Claude Code CLI, Claude Desktop, and VS Code
- Selects the best available provider based on user preferences
- Extensible adapter system for future integrations (Codex, etc.)

✅ **Battery-Efficient Design**
- Low Power Mode: Reduces animation frame rates, limits concurrent agents
- Aggressive Efficiency Mode: Single active agent with minimal UI updates
- Event-driven architecture (no polling) prevents wake-ups when idle
- Smart inactivity timeout with user-configurable delays

✅ **Dock Pets + Dashboard**
- Animated dock companions reflect actual agent work (not mock data)
- Real-time dashboard showing task progress, agent status, and logs
- Click dock pet to open agent detail panel with transcript
- Menu bar quick-access to project status

✅ **Skills + Auto-Detection**
- YAML-based skill packs for different roles (planner, coder, reviewer, shipper)
- Auto-detect project type (web app, Python CLI, macOS app, etc.)
- Load role-specific prompts based on project context
- Included skill packs: web_app, macos_app, python_cli

✅ **Local-First State Management**
- All state saved to `~/.neptune/` (no cloud, no external storage)
- File-based coordination enables future multi-machine orchestration
- Survives app crashes with resumable checkpoints
- Atomic state updates prevent corruption

### Architecture Highlights

- **Swift 5.9+ with Strict Concurrency** — Type-safe async/await throughout
- **Actor-Based** — ProcessManager, StateManager, AgentOrchestrator use actors for thread-safe state
- **Protocol-Oriented** — ProviderAdapter pattern enables pluggable backends
- **Separation of Concerns** — Core orchestration decoupled from UI
- **Cross-Platform Ready** — Architecture designed for Windows (Rust core + C FFI + WPF shell)

### Documentation

Comprehensive documentation is included:

- **[README.md](README.md)** — Internal development guide
- **[README_GITHUB.md](README_GITHUB.md)** — Feature overview and quick start
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — Development setup and contribution guidelines
- **[CHANGELOG.md](CHANGELOG.md)** — Version history and feature timeline
- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** — Technical summary of what was built
- **[docs/architecture/PROVIDER_ADAPTERS.md](docs/architecture/PROVIDER_ADAPTERS.md)** — Deep dive on provider system
- **[docs/WINDOWS_ROADMAP.md](docs/WINDOWS_ROADMAP.md)** — 4-phase plan for Windows + cross-platform core

## 📋 System Requirements

- **macOS 13.0** (Ventura) or later
- **Claude Code CLI** installed and authenticated
- **4GB+ RAM** (8GB recommended for concurrent agent workflows)
- **Stable internet** (for Claude API calls via local CLI)

## 🚀 Installation

1. Download `Neptune.dmg` from [Releases](https://github.com/anthropics/neptune/releases)
2. Double-click to mount the disk image
3. Drag `Neptune.app` to `/Applications`
4. Eject the disk image
5. Launch Neptune from `/Applications/Neptune.app`

On first launch:
- Neptune will create `~/.neptune/` directory
- Configure Claude Code CLI path (usually `/opt/homebrew/bin/claude`)
- Load default skill packs automatically

## 🆕 What's New Since Last Version

This is the first release. See [CHANGELOG.md](CHANGELOG.md) for the complete feature list.

## 🐛 Known Issues & Limitations

### MVP Scope
- **Autonomous Workflows** — Orchestration core complete; long-running autonomous loops in progress
- **Skill Packs** — 3 included (web_app, macos_app, python_cli); more coming in updates
- **Blueprint Templates** — Basic set included; full project scaffolding in development

### Provider Depth
- **Claude Code CLI** — Full execution support ✅
- **Claude Desktop** — Detection + launch only (deeper API integration planned)
- **VS Code** — Detection + launch only (extension integration planned)

### Planned for Future Releases
- Windows version (Q3 2026) with Rust core library + C FFI bridge
- Extended skill packs (web3, data science, embedded systems, etc.)
- Real-time agent streaming and transcription
- GitHub integration for auto-commits and PR creation
- Multi-machine distributed workflows
- iOS/iPadOS companion app

## 📊 Build Information

- **Architecture** — Apple Silicon (arm64) + Intel (x86_64) universal binary
- **Build Tool** — Xcode 15.0+
- **Swift Version** — 5.9+
- **Minimum Deployment** — macOS 13.0

**Build Status:** ✅ Passed
**Code Coverage:** ✅ Tested
**Signing** — Ad-hoc "Sign to Run Locally"

## 🔧 Configuration

Neptune stores all user settings in:
- **Settings Location** — `~/Library/Preferences/com.anthropic.neptune.plist`
- **State Location** — `~/.neptune/` (projects, agents, skills, logs)

### Configurable Options

- **Claude Executable Path** — Auto-detected or manually specified
- **Workspace Directory** — Default location for new projects
- **Low Power Mode** — Toggle battery efficiency
- **Aggressive Efficiency** — Single active agent mode
- **Max Concurrent Agents** — Limit parallel execution (recommended: 3)
- **Preferred Provider** — Select default execution backend
- **Launch at Login** — Auto-start on macOS login
- **Inactivity Timeout** — Pause agents when idle (default: 5 minutes)

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Development setup and build instructions
- Code standards (Swift style, testing, documentation)
- Areas where we need help (providers, skills, Windows, docs, testing)
- Pull request process

### Areas We Need Help With

- **Provider Adapters** — Add support for Codex, local LLMs, custom tools
- **Skill Packs** — Create YAML blueprints for additional project types
- **Windows** — Help build the Windows desktop shell and provider detection
- **Testing** — Report bugs, verify workflows, suggest improvements
- **Documentation** — Expand guides, examples, and technical docs
- **UI/UX** — Design enhancements, accessibility improvements

## 📝 License

Neptune is released under the [MIT License](LICENSE).

## 🙏 Acknowledgments

Neptune builds on:
- **[Lil Agents](https://github.com/rynschm/lil-agents)** — Inspiring dock companion UI design
- **Claude Code CLI** — Local execution foundation
- **SwiftUI & Swift concurrency** — Modern app development tools
- **The Claude community** — Feedback and inspiration

## 📞 Support

- **Issues & Bugs** — [GitHub Issues](https://github.com/anthropics/neptune/issues)
- **Feature Requests** — [GitHub Discussions](https://github.com/anthropics/neptune/discussions)
- **Documentation** — See [docs/](docs/) for technical guides

---

**Thank you for trying Neptune!**

We're excited to see what you build with autonomous agents. This is the beginning of a new chapter in local-first AI development.

*Neptune v1.0.0-beta — Local autonomous agents, no cloud required.*
