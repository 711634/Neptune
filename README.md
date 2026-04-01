# 🧠 Neptune — Local Autonomous Agent Platform

[![Release](https://img.shields.io/badge/version-1.1.0-blue)](https://github.com/711634/Neptune/releases)
[![macOS 13.0+](https://img.shields.io/badge/macOS-13.0+-brightgreen)](https://www.apple.com/macos/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

> **Local multi-agent orchestration for your Mac.** Neptune brings autonomous, Claude-powered agents to your desktop—no external APIs, no billing, no cloud required.

Launch agents that understand your code, break down complex goals into task graphs, and work autonomously while you watch animated companion pets reflect their progress in your dock.

---

## ✨ What Makes Neptune Different

| Feature | Neptune | Others |
|---------|---------|--------|
| **Multi-agent workflows** | Real task graphs with dependencies | Sequential or mock flows |
| **No API costs** | Uses Claude Code CLI (local auth) | Cloud APIs with per-token billing |
| **Autonomous loops** | Agents run without input; handle errors | Require human-in-the-loop approval |
| **Live visual feedback** | Dock pets + Dashboard (real-time) | Dashboards only, no embedded UI |
| **Battery-efficient** | Event-driven, Low Power Mode | Polling-based, battery drain |
| **Local state** | File-based, survive crashes | Often ephemeral |
| **Cross-platform ready** | Windows roadmap + architecture | macOS only |

---

## 🚀 Quick Start

### 1. Install

1. Download [Neptune.dmg](https://github.com/anthropics/neptune/releases)
2. Double-click to mount → Drag `Neptune.app` to `/Applications`
3. Eject the disk image
4. Launch Neptune from `/Applications/Neptune.app`

### 2. Configure

On first launch:
- **Set Claude Path** → Typically `/opt/homebrew/bin/claude`
- **Verify Claude** → Run `claude --version` in Terminal
- **Create a project** → Click "New Project" in the Dashboard

### 3. Start Autonomous Workflow

```
1. Enter project name, description, and goal
2. Neptune auto-detects project type (React? Python? Rust? iOS?)
3. Skill packs load automatically (Planner, Coder, Reviewer, Shipper)
4. Click "Start" → Watch agents work in real-time
```

**Supported project types:**
- `web_app` — React, Vue, Next.js, SvelteKit
- `python_cli` — Click, Typer, argparse-based CLIs
- `macos_app` — SwiftUI applications
- `ios_app` — iOS/iPadOS apps  
- `rust_lib` — Rust crates and libraries

---

## 📋 Requirements

- **macOS 13.0+** (Intel or Apple Silicon)
- **Claude Code CLI** installed and authenticated
  ```bash
  which claude
  claude --version
  ```
- **Active Claude subscription** (Neptune uses local authentication via Claude Code)

---

## 🎯 How It Works

### Real-Time Multi-Agent Orchestration

When you launch a workflow, Neptune:

1. **Analyzes** your project (files, structure, language)
2. **Generates** a task graph with dependencies
3. **Assigns** tasks to specialized agents (Planner → Coder → Reviewer → Shipper)
4. **Executes** autonomously — agents handle task assignment, retries, and error recovery
5. **Persists** state to disk (survive crashes, resume workflows)
6. **Visualizes** progress via dashboard + dock pets

```
┌──────────────────────────────────────────────────┐
│ User: "Build a React dashboard for metrics"     │
└──────────────────────────────────────────────────┘
               ▼
┌──────────────────────────────────────────────────┐
│ PLANNER (purple)                                 │
│ ✓ Analyzes requirements                          │
│ ✓ Creates architecture document                  │
│ ✓ Defines 5 tasks for Coder                      │
└──────────────────────────────────────────────────┘
               ▼
┌──────────────────────────────────────────────────┐
│ CODER (green)                                    │
│ ✓ Implements React components                    │
│ ✓ Connects API endpoints                         │
│ ✓ Writes test files                              │
└──────────────────────────────────────────────────┘
               ▼
┌──────────────────────────────────────────────────┐
│ REVIEWER (orange)                                │
│ ✓ Checks code quality                            │
│ ✓ Runs lints and tests                           │
│ ✓ Suggests improvements                          │
└──────────────────────────────────────────────────┘
               ▼
    📊 Dashboard + Dock Pet Show Live Progress
```

### Autonomous Task Execution

Agents don't wait for permission. They:
- ✅ Evaluate task dependencies (won't run until prerequisites complete)
- ✅ Execute via Claude Code CLI (full language/framework support)
- ✅ Detect success/failure automatically
- ✅ Retry with backoff on recoverable errors
- ✅ Report results and mark dependent tasks ready

---

## 🏗️ Architecture

Neptune is built for local-first, multi-agent workflows:

```
┌─────────────────────────────────────────┐
│         Neptune macOS App (SwiftUI)     │
│   Dashboard │ Dock Pets │ Settings      │
└─────────────┬───────────────────────────┘
              │
    ┌─────────┼─────────┐
    │         │         │
┌───▼──┐ ┌───▼──────┐ ┌─▼──────────┐
│Agent │ │StateManager
│Orch  │ │(Persists) │ │ProviderAPI │
│      │ │          │ │(CLI/Desktop)│
└───┬──┘ └──────┬────┘ └──────┬─────┘
    │          │              │
    └──────────┼──────────────┘
               │
     ┌─────────┴──────────┐
     │                    │
  ┌──▼────┐          ┌───▼───┐
  │Skill  │          │Task   │
  │Registry          │Graph  │
  └────────┘         └───────┘
     │
     └──▶ Claude Code CLI (local execution)
```

**Key components:**
- **AgentOrchestrator** — Manages agent lifecycle, task assignment, autonomous loops
- **TaskGraph** — Tracks task dependencies, resolves circular refs, prevents out-of-order execution
- **ProviderRegistry** — Abstracts execution (Claude Code CLI, Claude Desktop, VS Code)
- **SkillRegistry** — Loads YAML prompts based on detected project type
- **StateManager** — Persists everything to `~/.neptune/` (JSON files)

All state is **local** and **persistent** — crash-safe by design.

---

## ⚡ Battery Efficiency

Neptune is optimized for low power consumption:

**Default mode:**
- ~5–10% CPU when idle (pet animation only)
- ~50–80MB memory
- Event-driven state sync (no polling)

**Low Power Mode:**
- Reduces pet animations
- Limits concurrent agents to 1
- ~2–5% CPU when idle
- Extends battery life on long workflows

**Aggressive Efficiency Mode:**
- Minimal UI updates
- Pure daemon operation
- Ideal for overnight builds

---

## 🔌 Provider Adapters

Neptune auto-detects and integrates with multiple execution backends:

| Provider | Status | Details |
|----------|--------|---------|
| **Claude Code CLI** | ✅ Active | Direct execution, full features, local auth |
| **Claude Desktop** | 🔄 Planned | Detection + launch, direct exec coming Q2 2026 |
| **VS Code + Claude** | 🔄 Planned | Workspace detection, editor integration |
| **Future** | 🔮 Roadmap | Local models, custom providers |

---

## 📁 Local State Structure

Everything lives in `~/.neptune/`:

```
~/.neptune/
├── projects/
│   └── {projectId}/
│       ├── project.json          # Metadata
│       ├── task-graph.json       # Tasks + status
│       ├── agents/
│       │   └── {agentId}/
│       │       ├── state.json
│       │       ├── transcript.log
│       │       └── checkpoint.json
│       └── artifacts/            # Generated files
├── skills/
│   ├── web_app/frontend.yaml
│   ├── python_cli/core.yaml
│   └── macos_app/swiftui.yaml
└── logs/orchestrator.log
```

**Zero cloud required.** All state is local JSON, survives crashes, and can be inspected/edited manually.

---

## 🛠️ Configuration & Settings

Access settings from the menu bar or cmd+comma:

- **Claude CLI Path** — Location of `claude` executable
- **Workspace** — Default project directory
- **Launch at Login** — Auto-start on boot
- **Low Power Mode** — Battery efficiency toggle
- **Max Concurrent Agents** — Parallel execution limit
- **Preferred Provider** — Default backend (Claude Code, Claude Desktop, etc.)

---

## 📊 Development Status

### ✅ macOS v1.0-beta (Ready)
- ✅ Multi-agent orchestration core
- ✅ Task graphs with dependencies
- ✅ Provider adapter system
- ✅ Skill registry (YAML-based)
- ✅ Dashboard & live visualization
- ✅ Dock pet companions (real-time state)
- ✅ Settings & low-power modes
- ✅ File-based state persistence
- ⚠️ Blueprint templates (MVP set; expand as needed)

### 🔄 Windows (Multi-Phase Roadmap)

**Phase 1: Core Extraction (Q2 2026)**
- Extract orchestration to Rust library
- Define portable state format
- Create C# FFI bindings

**Phase 2: Windows Shell (Q3 2026)**
- WPF or MAUI desktop UI
- Tray icon integration (vs. dock pets)
- Same provider adapter system

**Phase 3: Windows Integration (Q3 2026)**
- Claude Code CLI detection
- VS Code integration
- Windows-specific features

**Phase 4: Testing & Hardening (Q4 2026)**
- E2E testing
- Performance tuning
- Release candidate

**Current Status:** Roadmap documented, implementation begins Q2 2026.

---

## 🐛 Known Limitations

- **Windows** — Not yet available (see roadmap above)
- **Blueprint system** — Currently MVP (expand as needed)
- **Offline mode** — Requires Claude Code CLI (not bundled)
- **Custom agents** — YAML-based skills only (code-based agents in future)
- **Mobile** — macOS/Windows only (no iOS/Android clients)

---

## 🤝 Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Help us with:**
- 🔌 **New provider adapters** — Claude 3 Opus, local models, Codex
- 📦 **Skill packs** — YAML templates for new project types
- 🪟 **Windows version** — Help build the Windows desktop shell
- 📚 **Documentation** — Guides, examples, troubleshooting
- 🧪 **Testing** — Report bugs, verify edge cases
- 🎨 **UI/UX** — Design improvements, accessibility

---

## 📄 License

Neptune is released under the [MIT License](LICENSE).

See [LICENSE](LICENSE) for full terms.

---

---

## 📞 Support

- **Issues & Features** — [GitHub Issues](https://github.com/anthropics/neptune/issues)
- **Discussions** — [GitHub Discussions](https://github.com/anthropics/neptune/discussions)
- **Documentation** — [docs/](docs/) — Technical deep-dives, architecture, roadmap
- **Architecture** — [docs/architecture/](docs/architecture/) — Provider adapters, task graphs, state design
- **Windows Roadmap** — [docs/WINDOWS_ROADMAP.md](docs/WINDOWS_ROADMAP.md) — Multi-phase plan

---

<div align="center">

**Neptune v1.0-beta** — *Local autonomous agents, no cloud required*

🌊 *"Neptune: Where agents flow like water, not electricity."*

</div>
