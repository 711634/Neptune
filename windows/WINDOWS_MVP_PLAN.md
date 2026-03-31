# Neptune Windows MVP Implementation Plan

**Status:** Implementation in progress  
**Stack:** Tauri v2 + React + TypeScript  
**Target:** Windows 10/11 (x64)  
**Deliverable:** .msi installer  

---

## 1. Architecture Decision: Tauri v2

### Why Tauri?
- ✅ **Lightweight** — Uses system WebView2, not Chromium (small installer, low memory)
- ✅ **Native Performance** — Rust backend for orchestration logic
- ✅ **Real Windows App** — Produces .msi/.exe, not Electron wrapper
- ✅ **Battery Efficient** — No constant polling framework overhead
- ✅ **Cross-platform Capable** — Reusable for macOS/Linux later if needed
- ✅ **Small Bundle** — Typically 30-50MB installer vs. 150MB+ for Electron

### Stack Breakdown
```
┌────────────────────────────────┐
│  Tauri Window (WebView2)       │
│  Frontend: React + TypeScript   │
│  Styling: Tailwind CSS         │
└────────────────────────────────┘
            ▲
            │ IPC (JSON-RPC)
            ▼
┌────────────────────────────────┐
│  Tauri Rust Backend            │
│  - State Management            │
│  - Provider Adapters           │
│  - Orchestration               │
│  - File Persistence            │
└────────────────────────────────┘
```

---

## 2. Shared Logic Strategy

### SHARE: Data Models
```typescript
// Windows version: TypeScript interfaces
interface ProjectContext {
  id: string
  name: string
  description: string
  goal: string
  projectType: ProjectType
  workspaceDir: string
  agents: Record<string, Agent>
  taskGraph: TaskGraph
  // ... same structure as macOS Swift
}

enum ProjectType {
  WEB_APP = 'web_app',
  PYTHON_CLI = 'python_cli',
  MACOS_APP = 'macos_app',
  RUST_LIB = 'rust_lib',
  // ... same enum values
}
```

### SHARE: State Persistence
```
Windows equivalent of ~/.neptune/:
  C:\Users\{username}\AppData\Local\Neptune\
  ├── projects/
  │   └── {projectId}/
  │       ├── project.json
  │       ├── task-graph.json
  │       └── agents/
  ├── skills/
  └── logs/
```

### WINDOWS-SPECIFIC: UI Rendering
- React components (Windows-native look, not macOS dock pets)
- Tray icon integration (Windows paradigm)
- Floating companion optional (VS. required)

### WINDOWS-SPECIFIC: Provider Adapters
- VS Code detection (Windows environment paths)
- Claude Desktop detection (Windows registry/file paths)
- Claude Code CLI detection (Windows PATH searching)

---

## 3. Windows MVP Features (MVP Scope Only)

### ✅ In Scope
1. **Dashboard Home** — Project list, quick stats
2. **Project Manager** — Create, view, delete projects
3. **Agent Status Panel** — Current agents, task progress
4. **Task Graph Viewer** — Simplified task list + dependencies
5. **Settings Panel** — Claude path, workspace dir, low-power mode
6. **Tray Icon** — Minimize to tray, context menu, quick status
7. **Provider Status** — Detect Claude, VS Code, show status
8. **Logs/Transcripts** — View agent activity, task output
9. **Local State Persistence** — File-based JSON, Windows AppData
10. **Low-Power Mode** — Reduce UI refresh, throttle checks

### ❌ NOT in Scope (v2+)
- Complex task graph visualization (simplified list OK)
- Custom agents via code (YAML skills only)
- Deep provider execution integration (detection + launch for now)
- Dock-equivalent overlay (tray icon sufficient)
- Mobile clients
- Blueprint templates (use basic project type detection only)

---

## 4. Provider Integration Levels for Windows

### Claude Code / VS Code
- ✅ **Detect:** Search Windows PATH, check installation
- ✅ **Launch:** Open workspace in VS Code if available
- ✅ **Link:** Map VS Code workspaces to Neptune projects
- 🔄 **Execute:** Planned for v2 (if VS Code extension API allows)

### Claude Desktop
- ✅ **Detect:** Check Windows AppData/program files
- ✅ **Status:** Show if installed/running
- 🔄 **Launch:** Open Claude Desktop for user
- ❌ **Direct Execution:** Not officially available on Windows yet

### Local Execute Path
- 🔄 **Future:** Claude API for local execution
- 🔄 **Future:** Ollama/local models support

---

## 5. Windows UI Layout

### Main Dashboard
```
┌─────────────────────────────────────┐
│ Neptune (Tray Icon: ⊕)              │
├─────────────────────────────────────┤
│ ⌂ Home │ Projects │ Settings        │
├─────────────────────────────────────┤
│                                     │
│ Projects:                           │
│ ┌─────────────────────────────────┐ │
│ │ [+] New Project                 │ │
│ │                                 │ │
│ │ • React Dashboard (planning)    │ │
│ │ • Python CLI Tool (coding)      │ │
│ │ • Rust Library (idle)           │ │
│ └─────────────────────────────────┘ │
│                                     │
│ Active Agents: 2                    │
│ └─ Planner (planning)               │
│ └─ Coder (coding)                   │
│                                     │
└─────────────────────────────────────┘
```

### Agent Details
```
┌─────────────────────────────────────┐
│ Agent: Coder (coding)               │
├─────────────────────────────────────┤
│                                     │
│ Status: 🟢 CODING                   │
│ Role: CODING                        │
│ Progress: Task 3/5                  │
│                                     │
│ Task Graph:                         │
│ ✓ Planning → In Progress → ...      │
│ ✓ Research → Completed              │
│ ○ Coding → In Progress              │
│ ○ Review → Pending                  │
│                                     │
│ Recent Output:                      │
│ ----                                │
│ > Implementing Button.tsx           │
│ > Running build...                  │
│                                     │
└─────────────────────────────────────┘
```

### Tray Menu
```
Neptune v1.0-beta
────────────────
📊 Show Dashboard
🟢 Active: 2 agents
⚙️  Settings
────────────
Quit Neptune
```

---

## 6. Project Structure

```
windows/
├── README.md                          # Windows build instructions
├── Cargo.toml                         # Rust backend manifest
├── tauri.conf.json                    # Tauri configuration
├── src-tauri/
│   ├── main.rs                        # Tauri app entry
│   ├── providers/                     # Windows provider adapters
│   │   ├── claude_code.rs
│   │   ├── vscode.rs
│   │   └── claude_desktop.rs
│   ├── state/                         # State management
│   │   ├── manager.rs
│   │   ├── models.rs                  # Shared models
│   │   └── persistence.rs
│   ├── orchestration/                 # Core logic
│   │   ├── orchestrator.rs
│   │   ├── task_graph.rs
│   │   └── skill_registry.rs
│   └── commands/                      # Tauri IPC commands
│       ├── projects.rs
│       ├── agents.rs
│       ├── settings.rs
│       └── providers.rs
├── src/                               # React frontend
│   ├── main.tsx
│   ├── App.tsx
│   ├── pages/
│   │   ├── Dashboard.tsx
│   │   ├── Projects.tsx
│   │   ├── Settings.tsx
│   │   └── AgentDetail.tsx
│   ├── components/
│   │   ├── TrayIcon.tsx
│   │   ├── ProjectList.tsx
│   │   ├── AgentPanel.tsx
│   │   ├── TaskGraphView.tsx
│   │   └── LogsViewer.tsx
│   └── styles/
│       └── globals.css                # Tailwind + custom theme
├── package.json
└── vite.config.ts                     # Build config
```

---

## 7. Build & Release Process

### Development
```bash
# Install dependencies
npm install

# Build Tauri app (dev)
npm run tauri dev

# Watch & rebuild on changes
npm run tauri dev -- --watch
```

### Release
```bash
# Build distributable
npm run tauri build

# Output: 
# src-tauri/target/release/Neptune.msi
# src-tauri/target/release/Neptune_1.0.0_x64.msi
```

### Package Details
- **Installer:** Neptune-1.0.0-setup.exe or Neptune.msi
- **Size:** ~40-50MB (including WebView2 bundled)
- **Location:** `src-tauri/target/release/`
- **Auto-Updater:** Configured for future releases

---

## 8. State Management & Persistence

### Windows AppData Path
```python
# Python equivalent for reference
import os
appdata_local = os.getenv('LOCALAPPDATA')  # C:\Users\{user}\AppData\Local
neptune_dir = os.path.join(appdata_local, 'Neptune')

# Structure:
# C:\Users\misbah\AppData\Local\Neptune\
# ├── projects\
# │   ├── {projectId}\
# │   │   ├── project.json
# │   │   ├── task-graph.json
# │   │   ├── agents\
# │   │   │   └── {agentId}\
# │   │   │       ├── state.json
# │   │   │       └── transcript.log
# │   │   └── artifacts\
# │   └── ...
# ├── skills\
# │   ├── web_app\
# │   │   └── frontend.yaml
# │   └── ...
# └── logs\
#     └── orchestrator.log
```

### File Format
- All JSON (same as macOS)
- ISO 8601 dates
- UTF-8 encoding

---

## 9. Lightweight/Low Battery Design

### Implementation
1. **Event-Driven State** — File watchers instead of polling
2. **UI Throttling** — Max 1 update/second when idle
3. **Background Priority** — Low-priority queue for non-critical tasks
4. **Animation Disable** — Optional in settings
5. **Pause on Battery** — Low Power Mode detection (Windows)
6. **Lazy Loading** — Load logs/transcripts on demand

### Settings for Power
```
☐ Low Power Mode (reduces UI updates, pauses animations)
☐ Aggressive Efficiency (minimal background activity)
☐ Minimize to Tray on Idle
□ Launch at Windows Startup
```

---

## 10. First Release Checklist

- [ ] Tauri project scaffolded
- [ ] React frontend structure created
- [ ] Core data models defined (TypeScript)
- [ ] StateManager ported to Rust
- [ ] Provider adapters for Windows implemented
- [ ] Dashboard page functional
- [ ] Projects CRUD working
- [ ] Settings page functional
- [ ] Tray icon integration complete
- [ ] Local persistence tested
- [ ] Build to .msi tested
- [ ] Installer tested on Windows 10/11
- [ ] Documentation for Windows build updated
- [ ] Known limitations documented
- [ ] Ready for internal testing

---

## 11. Known Limitations (Honest)

- **No Deep Provider Execution** — Detection + launch only (execution v2)
- **No Blueprint Templates** — Use basic project type detection
- **No Custom Agents** — YAML skills only
- **Simplified Task Visualization** — List view, not full graph
- **No Floating Pets** — Tray icon only (Windows paradigm)

---

## 12. Future Phases

### v1.1 (Q3 2026)
- [ ] Claude API local execution backend
- [ ] Deep VS Code extension integration
- [ ] More skill packs

### v1.2 (Q4 2026)
- [ ] Ollama/local model support
- [ ] Advanced task graph visualization
- [ ] Template blueprints

### v2.0 (Q1 2027)
- [ ] macOS parity (all features)
- [ ] Cross-platform shared core library
- [ ] Advanced customization

---

**Next Steps:**
1. Create Tauri project scaffold
2. Port data models to TypeScript
3. Implement provider adapters for Windows
4. Build React UI components
5. Test build and packaging
6. Prepare Windows beta release

