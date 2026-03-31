# Neptune — Local Autonomous Agent Platform

[![Release](https://img.shields.io/badge/version-1.0.0--beta-blue)]((https://github.com/your-org/neptune/releases))
[![macOS 13.0+](https://img.shields.io/badge/macOS-13.0+-green)](https://www.apple.com/macos/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-blue)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue)](#license)

Neptune is a **lightweight, battery-efficient autonomous agent platform** that brings real multi-agent orchestration to your Mac. It integrates with your existing Claude subscription and leverages local authentication—**no external APIs, no billing**.

## ✨ Key Highlights

- **Real Multi-Agent Orchestration** — Task graphs, dependency tracking, autonomous workflows
- **Dock-Native Companions** — Transparent Tamagotchi-style pets that reflect actual agent work
- **No API Billing** — Uses Claude Code CLI (locally authenticated) as the execution backend
- **Skills + Blueprints** — Auto-detect project type, load role-specific prompts
- **Battery-Efficient** — Low Power Mode, event-driven coordination, minimal polling
- **Provider Adapters** — Detect Claude Desktop, VS Code, future tools
- **Cross-Platform Architecture** — Designed for macOS today, Windows coming soon

## 🚀 Quick Start

### Installation

1. Download `Neptune.dmg` from [Releases](https://github.com/anthropics/neptune/releases)
2. Double-click `Neptune.dmg` to mount
3. Drag `Neptune.app` to `/Applications`
4. Unmount the disk image (eject from Finder)
5. Launch Neptune from `/Applications/Neptune.app`
6. On first launch, configure Claude Code CLI path in Settings (typically `/opt/homebrew/bin/claude`)

### Create a Project

```
1. Click "New Project" in Neptune Dashboard
2. Enter project name, description, and goal
3. Neptune auto-detects project type
4. Skills and blueprints load automatically
5. Click "Start" to begin autonomous workflows
```

### Supported Project Types

- **web_app** — React, Vue, Next.js, SvelteKit
- **python_cli** — Click, Typer, argparse-based CLIs
- **macos_app** — SwiftUI applications
- **ios_app** — iOS / iPadOS apps
- **rust_lib** — Rust libraries and crates

## 📋 Requirements

- **macOS 13.0** or later
- **Claude Code CLI** installed and authenticated
  ```bash
  which claude
  claude --version
  ```
- **Active Claude Subscription** (Neptune leverages local authentication)

## 🏗️ Architecture Overview

Neptune is built on a modular, local-first architecture:

```
┌─────────────────────────────────────────────────────┐
│              Neptune macOS App                       │
│  ┌──────────────┐  ┌──────────┐  ┌──────────────┐  │
│  │  Dashboard   │  │ Dock Pets│  │  Settings    │  │
│  │  (SwiftUI)   │  │  (Live)  │  │  (UI)        │  │
│  └──────────────┘  └──────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
    ┌───▼───┐   ┌──────▼──────┐   ┌───▼────────┐
    │Orchest│   │ Persistence  │   │Provider    │
    │rator  │   │(State Mgr)   │   │Adapters    │
    └───┬───┘   └──────┬──────┘   └───┬────────┘
        │               │               │
        └───────────────┼───────────────┘
                        │
        ┌───────────────┴───────────────┐
        │                               │
    ┌───▼────────┐          ┌──────────▼───┐
    │Process     │          │Skill         │
    │Manager     │          │Registry      │
    │(PTY/CLI)   │          │(YAML)        │
    └────────────┘          └──────────────┘
                        │
        ┌───────────────┴──────────────────┐
        │                                  │
    ┌───▼──────────┐            ┌────────▼───────┐
    │Claude Code   │            │Claude Desktop  │
    │CLI           │            │VS Code + Claude│
    │(Execution)   │            │Codex (future)  │
    └──────────────┘            └────────────────┘
```

### Core Components

| Component | Purpose | Location |
|-----------|---------|----------|
| **AgentOrchestrator** | Multi-agent lifecycle, task queue, autonomous loops | `Services/AgentOrchestrator.swift` |
| **ProcessManager** | PTY sessions, Claude Code CLI execution | `Services/ProcessManager.swift` |
| **StateManager** | File-based persistence (~/.neptune/) | `Services/StateManager.swift` |
| **SkillRegistry** | Auto-detect project type, load role prompts | `Services/SkillRegistry.swift` |
| **ProviderRegistry** | Adapter system for Claude, VS Code, etc. | `Services/ProviderAdapter.swift` |
| **TaskGraph** | Dependency tracking, task scheduling | `Models/TaskGraph.swift` |
| **ActivityMonitor** | Dock pet state from real agent work | `Services/ActivityMonitor.swift` |

## 🎯 How It Works

### Autonomous Workflow Example

```
User Input: "Build a React dashboard"
        │
        ▼
┌─────────────────────────┐
│ ProjectContext Created  │  Type: web_app
│ Skills Loaded           │  Planner, Coder, Reviewer skills
└─────────────────────────┘
        │
        ▼
┌─────────────────────────┐
│ Task Graph Generated    │  5 tasks: plan → research → code → review → ship
└─────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────┐
│ Agent 1: Planner                        │  Breaks down requirements
│ Status: planning                        │  Generates architecture doc
│ Output: architecture.md                 │  Next: Task for Coder
└─────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────┐
│ Agent 2: Coder                          │  Implements components
│ Status: coding                          │  Writes code files
│ Output: src/components/...              │  Next: Task for Reviewer
└─────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────┐
│ Agent 3: Reviewer                       │  Reviews code quality
│ Status: reviewing                       │  Checks for issues
│ Output: review-report.md                │  Next: Task for Shipper
└─────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────┐
│ Agent 4: Shipper                        │  Packages, deploys
│ Status: shipping                        │  Creates build artifacts
│ Output: build/, deployment logs         │
└─────────────────────────────────────────┘
        │
        ▼
    PROJECT COMPLETE
```

Throughout this workflow:
- **Dashboard** shows real-time task graph progress
- **Dock pets** visually represent agent activity
- **Logs** are captured for inspection
- **State persists** to disk (survives crashes)
- **Dependency rules** prevent out-of-order execution

## 📁 Local State Structure

Neptune stores everything locally under `~/.neptune/`:

```
~/.neptune/
├── projects/
│   └── {projectId}/
│       ├── project.json          # Project metadata
│       ├── task-graph.json       # Task definitions & status
│       ├── agents/
│       │   └── {agentId}/
│       │       ├── state.json    # Agent metadata
│       │       ├── transcript.log # Session output
│       │       └── checkpoint.json# Resumption point
│       └── artifacts/            # Generated files
├── skills/
│   ├── web_app/
│   │   ├── frontend.yaml
│   │   ├── backend.yaml
│   │   └── deployment.yaml
│   ├── python_cli/
│   │   ├── core.yaml
│   │   └── testing.yaml
│   └── ...
├── blueprints/                   # Project templates
└── logs/
    └── orchestrator.log          # Global activity log
```

### Zero External Dependencies

- ✅ Uses Claude Code CLI (already authenticated locally)
- ✅ All state saved to disk in JSON format
- ✅ No cloud backend required
- ✅ No external API calls (except to Claude via local CLI)
- ✅ No billing or account setup needed

## ⚡ Performance & Battery Efficiency

Neptune is optimized for low battery impact:

### Features
- **Event-driven** state coordination (not polling)
- **Low Power Mode** reduces pet animation, concurrent agents
- **Aggressive Efficiency Mode** for 1 active agent + minimal UI
- **Smart animation** pauses when idle or on battery

### Performance Metrics
- ~5-15% CPU when idle (dock pet animation only)
- ~50-100MB memory usage
- Minimal wake-ups when no active projects
- Recommended max 3 concurrent agents for battery health

## 🔌 Provider Adapters

Neptune detects and integrates with multiple execution backends:

| Provider | Status | Capabilities |
|----------|--------|--------------|
| **Claude Code CLI** | ✅ Full | Direct task execution, session management |
| **Claude Desktop** | ⚡ Detection | Launch detection, project opening |
| **VS Code + Claude** | ⚡ Detection | Workspace awareness, editor integration |
| **Codex Workflows** | 🔮 Planned | Local Codex CLI support |

## 🛠️ Settings & Configuration

Neptune Settings include:

- **Claude Path** — Location of Claude Code CLI executable
- **Workspace Path** — Default project directory
- **Low Power Mode** — Battery efficiency toggle
- **Aggressive Efficiency** — Maximum performance savings
- **Max Concurrent Agents** — Parallel execution limit
- **Preferred Provider** — Default execution backend
- **Launch at Login** — Auto-start on macOS login

## 📊 Development Status

### macOS (v1.0-beta)
- ✅ Orchestration core
- ✅ Provider adapters
- ✅ Skills system
- ✅ Task graphs with dependencies
- ✅ Dock pets (live state)
- ✅ Dashboard & settings
- ✅ Low Power Mode
- ⚠️ Blueprint templates (MVP set)

### Windows (Roadmap)
- 🔮 Shared orchestration core (in progress)
- 🔮 Native Windows desktop shell
- 🔮 Tray icon variant
- 🔮 Same provider adapter system
- 🔮 Estimated: Q3 2026

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines, development setup, and areas we're looking for help:

- **Provider adapters** — Add support for new tools (Codex, local models, etc.)
- **Skill packs** — Create YAML blueprints for more project types
- **Windows version** — Help build the Windows desktop shell
- **Documentation** — Improve guides, examples, and technical docs
- **Testing** — Report bugs, verify workflows, test edge cases
- **UI/UX** — Design improvements, accessibility enhancements

## 📄 License

Neptune is released under the [MIT License](LICENSE).

## 🙏 Acknowledgments

Neptune draws inspiration from:
- **[Lil Agents](https://github.com/rynschm/lil-agents)** — Dock companion UI design
- **Clonk** — Autonomous orchestration architecture
- **Claude Code CLI** — Local execution foundation

## 📞 Support & Feedback

- **Issues & Feature Requests** — [GitHub Issues](https://github.com/anthropics/neptune/issues)
- **Discussions** — [GitHub Discussions](https://github.com/anthropics/neptune/discussions)
- **Documentation** — See [docs/](docs/) for technical deep-dives
- **Architecture** — [docs/architecture/PROVIDER_ADAPTERS.md](docs/architecture/PROVIDER_ADAPTERS.md)
- **Windows Roadmap** — [docs/WINDOWS_ROADMAP.md](docs/WINDOWS_ROADMAP.md)

---

**Neptune v1.0-beta** — *Local autonomous agents, no cloud required.*
