# Neptune Documentation

Welcome to Neptune — local autonomous agent orchestration for your Mac.

---

## 📚 Quick Navigation

### Getting Started
- **[Main README](../README.md)** — Product overview, installation, quick start
- **[CONTRIBUTING.md](../CONTRIBUTING.md)** — Development setup, contribution guidelines

### Architecture & Design
- **[Provider Adapters](architecture/PROVIDER_ADAPTERS.md)** — How Claude Code CLI, Claude Desktop, VS Code integrate
- **[Task Graphs & Dependencies](architecture/TASK_GRAPHS.md)** — Dependency resolution, task scheduling
- **[State Management](architecture/STATE_MANAGEMENT.md)** — File-based persistence, state durability

### Platform Support
- **[Windows Roadmap](WINDOWS_ROADMAP.md)** — Multi-phase plan (Q2–Q4 2026)
- **[macOS Status](../README.md#-development-status)** — Current v1.0-beta status

### Reference
- **[Release Notes](../RELEASE_NOTES.md)** — v1.0-beta highlights
- **[Changelog](../CHANGELOG.md)** — Full version history
- **[License](../LICENSE)** — MIT License

---

## 🎯 Key Features

| Feature | Details |
|---------|---------|
| **Multi-Agent Orchestration** | Real task graphs with dependencies, autonomous loops, no human intervention |
| **Dock Companions** | Tamagotchi-style pets that visualize real agent work |
| **No API Billing** | Uses Claude Code CLI (local auth) — no cloud APIs, no per-token costs |
| **Battery Efficient** | Event-driven, Low Power Mode, minimal polling |
| **Local State** | File-based JSON in `~/.neptune/`, crash-safe, inspectable |
| **Skill System** | YAML-based prompts for Planner, Coder, Reviewer, Shipper agents |
| **Provider System** | Supports Claude Code CLI, Claude Desktop, VS Code detection |

---

## 🚀 Installation

1. Download `Neptune.dmg` from [Releases](https://github.com/anthropics/neptune/releases)
2. Drag `Neptune.app` to `/Applications`
3. Launch and configure Claude Code CLI path
4. Create a project → Watch autonomous agents work

**Requirements:**
- macOS 13.0+
- Claude Code CLI installed and authenticated
- Active Claude subscription

---

## 🏗️ System Design

Neptune separates **orchestration core** (platform-agnostic) from **UI shells** (platform-specific):

```
┌─────────────────────────────┐
│  Orchestration Core         │
│  (Agent Lifecycle,          │
│   Task Graph, Provider API) │
└────────┬──────────┬─────────┘
         │          │
    ┌────▼──┐   ┌───▼────┐
    │ macOS │   │Windows  │
    │SwiftUI│   │WPF/MAUI │
    └───────┘   └─────────┘
```

**macOS:** SwiftUI app with dock pet companions, dashboard, settings.  
**Windows:** Coming Q3 2026 — WPF/MAUI with tray icon integration.

---

## 🔄 Windows Development Status

**Current:** Roadmap complete, implementation roadmap drafted.  
**Phase 1 (Q2 2026):** Extract orchestration core to Rust.  
**Phase 2–3 (Q3 2026):** Windows shell (WPF/MAUI).  
**Phase 4 (Q4 2026):** Testing, hardening, release.  

See [WINDOWS_ROADMAP.md](WINDOWS_ROADMAP.md) for detailed plan.

---

## 🛠️ Development

### Project Structure

```
Neptune/
├── Neptune/                  # macOS app (SwiftUI)
│   ├── App/                  # Entry point
│   ├── Models/               # Agent, TaskGraph, ProjectContext
│   ├── Services/             # Orchestration, state, providers
│   ├── Views/                # Dashboard, dock pets, settings
│   └── Resources/            # Icons, assets
├── Scripts/                  # Icon generation, mock data
├── docs/                     # Documentation
├── project.yml               # Xcode project spec
├── README.md                 # Main landing page
└── LICENSE                   # MIT
```

### Building Locally

```bash
xcodebuild -project Neptune.xcodeproj -scheme Neptune \
  -destination 'platform=macOS' -configuration Debug build
```

### Code Quality

All code follows [CONTRIBUTING.md](../CONTRIBUTING.md) guidelines:
- Swift idioms (immutability, value types, actors)
- Async/await concurrency
- Comprehensive error handling
- 80%+ test coverage (when available)

---

## 🐛 Known Limitations

- **Windows** — Not available; roadmap in progress
- **Offline mode** — Requires Claude Code CLI (always-on requirement)
- **Custom agents** — YAML-based skills only
- **Mobile** — macOS/Windows only
- **Blueprints** — MVP set; expansion in progress

---

## 📞 Support & Feedback

- **Issues** — [GitHub Issues](https://github.com/anthropics/neptune/issues)
- **Discussions** — [GitHub Discussions](https://github.com/anthropics/neptune/discussions)
- **Email** — neptune@anthropic.com (future)

---

## 📄 License

Neptune is released under the [MIT License](../LICENSE).

---

<div align="center">

**Neptune v1.0-beta** — *Local autonomous agents, no cloud required*

</div>
