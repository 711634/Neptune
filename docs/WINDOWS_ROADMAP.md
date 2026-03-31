# Neptune Windows Implementation Roadmap

## Overview

Neptune is architected for cross-platform support. The orchestration core (agents, task graphs, skills, providers) is platform-agnostic. Only the UI shell and native integrations are platform-specific.

## Architecture Strategy

```
┌──────────────────────────────────────────────────┐
│        Platform-Agnostic Core (Rust/Swift)      │
│  - AgentOrchestrator                            │
│  - StateManager (file-based)                    │
│  - SkillRegistry                                │
│  - TaskGraph                                    │
│  - ProviderRegistry                             │
└──────────────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
    ┌───▼─────────┐      ┌──────▼──────┐
    │  macOS UI   │      │ Windows UI   │
    │ (SwiftUI)   │      │ (WPF/MAUI)   │
    └─────────────┘      └──────────────┘
```

## Phase 1: Shared Core Extraction (Q2 2026)

### Goals
- Extract orchestration logic from macOS app
- Create platform-agnostic library
- Define clear interface for UI shells
- Support both Swift and other languages

### Deliverables

#### 1. Core Orchestration Library

**Language**: Rust (maximal platform compatibility)

```
neptune-core/
├── src/
│   ├── lib.rs                 # Library entry point
│   ├── orchestrator.rs        # AgentOrchestrator logic
│   ├── state.rs              # StateManager (file ops)
│   ├── skills.rs             # SkillRegistry
│   ├── task_graph.rs         # Task dependency tracking
│   └── providers.rs          # Provider adapter traits
├── Cargo.toml
└── tests/
```

**Key Traits**:
```rust
pub trait ProviderAdapter {
    async fn execute(&self, prompt: &str, workdir: &Path) -> ProviderOutput;
    async fn get_sessions(&self) -> Vec<ProviderSession>;
}

pub trait StateManager {
    async fn save_agent(&self, agent: &Agent) -> Result<()>;
    async fn load_project(&self, id: &str) -> Result<ProjectContext>;
}

pub struct Orchestrator {
    state: Box<dyn StateManager>,
    providers: Vec<Box<dyn ProviderAdapter>>,
    // ...
}
```

#### 2. C Bridge (FFI)

```c
// neptune-core/include/neptune.h
typedef struct {
    char* id;
    char* status;
    char* output;
} ProviderOutput;

// Create orchestrator
OrchRef orchestrator_new(const char* state_dir);

// Run workflow
int orchestrator_run(OrchRef orch, const char* project_json);

// Get agent status
char* agent_get_status(OrchRef orch, const char* agent_id);
```

This allows:
- **C# / .NET** (Windows) to call via DllImport
- **Swift** to continue using native code
- **Node/Electron** to use via Node-FFI if needed

#### 3. Shared State Schema

Formalize `~/.neptune/` structure as a versioned schema:

```json
{
  "version": "1.0",
  "projects": {
    "{projectId}": {
      "metadata": {...},
      "agents": {...},
      "tasks": {...},
      "skills_config": {...}
    }
  }
}
```

Both macOS (Swift) and Windows (C#) read/write the same schema.

### Implementation Priority

1. **Extract StateManager** → Rust file operations
2. **Extract SkillRegistry** → YAML parsing (serde)
3. **Extract TaskGraph** → Dependency logic
4. **Define ProviderAdapter trait** → Abstract CLI execution
5. **Build C bridge** → Expose key functions
6. **Write integration tests** → Verify cross-platform state

### Estimated Effort
- **Core extraction**: 40 hours
- **Rust implementation**: 60 hours
- **C bridge & testing**: 30 hours
- **Total**: ~130 hours (3-4 weeks with focused effort)

## Phase 2: Windows Desktop Shell (Q3 2026)

### Technology Stack

**Option A: WPF (Windows Presentation Foundation)**
- Pros: Native Windows feel, XAML, mature ecosystem
- Cons: .NET Framework only (not cross-platform)
- Estimate: 80 hours

**Option B: MAUI (.NET Multi-platform App UI)**
- Pros: .NET 8+, cross-platform capable, modern
- Cons: Newer, less mature on Windows
- Estimate: 100 hours

**Recommendation**: **Start with WPF** (native Windows feel), migrate to MAUI if cross-platform needed later.

### Shell Architecture

```csharp
// neptune-core.dll (Rust via C bridge)
[DllImport("neptune_core")]
private static extern IntPtr orchestrator_new(string state_dir);

// NeptuneApp.xaml.cs
public class NeptuneApp : Application {
    private OrchestrationContext orchContext;

    protected override void OnStartup(StartupEventArgs e) {
        // Load orchestrator core
        orchContext = new OrchestrationContext("/home/user/.neptune");

        // Initialize UI
        MainWindow = new DashboardWindow { DataContext = new DashboardViewModel(orchContext) };
        MainWindow.Show();
    }
}

// UI Components
// - Dashboard (task graph, agent status)
// - Tray Icon (system tray integration, not dock)
// - Settings Panel
// - Project Creator
```

### Windows-Specific Features

1. **Tray Icon** (instead of Dock)
   ```csharp
   var trayIcon = new NotifyIcon {
       Icon = new Icon("Resources/neptune.ico"),
       Visible = true
   };
   ```

2. **System Integration**
   - Launch at startup via Registry
   - File associations (.neptune project files)
   - Context menu in Explorer

3. **Visual Differences**
   - Minimize to tray instead of hide
   - No dock pets (tray icon animations instead)
   - Windows taskbar integration

4. **Provider Adapters (Windows)**
   ```csharp
   // Detect Claude Code CLI
   // Detect Claude Desktop (check AppData)
   // Detect VS Code (check Program Files, chocolatey, scoop)
   // Detect Codex (check local paths)
   ```

### Deliverables

```
neptune-windows/
├── NeptuneApp/
│   ├── App.xaml
│   ├── App.xaml.cs
│   ├── DashboardWindow.xaml
│   ├── Views/
│   │   ├── ProjectCreator.xaml
│   │   ├── AgentDetail.xaml
│   │   └── TaskGraph.xaml
│   ├── ViewModels/
│   │   ├── DashboardViewModel.cs
│   │   └── SettingsViewModel.cs
│   ├── Models/
│   │   ├── OrchestrationContext.cs
│   │   └── ProviderDetector.cs
│   └── Resources/
│       └── neptune.ico
├── NeptuneCore/
│   ├── Interop.cs         # P/Invoke declarations
│   └── Extensions.cs      # Rust bridge helpers
└── NeptuneApp.csproj
```

### Estimated Effort
- **WPF UI Shell**: 80 hours
- **Provider detection**: 20 hours
- **Settings & config**: 15 hours
- **Testing & polish**: 25 hours
- **Total**: ~140 hours (3-4 weeks)

## Phase 3: Feature Parity (Q4 2026)

### Windows MVP Requirements

- ✅ Create new projects
- ✅ Auto-detect project type
- ✅ Load skills and blueprints
- ✅ Run autonomous workflows
- ✅ View task graph and agent status
- ✅ Inspect logs and transcripts
- ✅ Pause/resume/stop projects
- ✅ Low Power Mode settings
- ✅ Claude Code CLI execution
- ✅ Claude Desktop detection
- ✅ VS Code integration

### Remaining Gaps vs macOS

| Feature | macOS | Windows | Notes |
|---------|-------|---------|-------|
| Dock pets | ✅ | Tray icon | Different OS paradigm |
| Notifications | ✅ System | ✅ Win Toast | Windows notification API |
| Launch at login | ✅ | ✅ Registry | Standard Windows approach |
| File watcher | ✅ | ✅ FileSystemWatcher | Built-in C# support |
| Process mgmt | ✅ PTY | ⚠️ Pipes | Windows uses pipes, not TTY |

**Critical Implementation**: Windows process management must handle:
- No PTY support (use anonymous pipes)
- Different environment variables
- Path separators (\\ vs /)
- Line endings (CRLF vs LF)

### Estimated Effort
- **Process bridge**: 30 hours
- **Windows-specific fixes**: 40 hours
- **Testing & QA**: 30 hours
- **Total**: ~100 hours

## Phase 4: Distribution & CI/CD (Q4 2026)

### Windows Packaging

**Option 1: MSIX (Windows Store)**
```
Neptune (app)
├── Manifest
├── Assets/
├── NeptuneApp.exe
└── neptune_core.dll
```

Pros: Windows Store distribution, auto-updates
Cons: Store submission process

**Option 2: Portable EXE**
```
Neptune-Setup.exe (WiX installer)
  → Installs to Program Files\Neptune\
  → Adds registry entries
  → Creates Start Menu shortcuts
```

Pros: Traditional Windows installer
Cons: Manual updates

**Option 3: Chocolatey / Winget**
```
choco install neptune
# or
winget install Neptune
```

Pros: Package manager integration
Cons: Requires package review

**Recommendation**: Start with **Portable EXE + GitHub Releases**, add **Chocolatey** once stable.

### CI/CD Pipeline

```yaml
# .github/workflows/build-windows.yml
name: Build Windows

on: [push, pull_request]

jobs:
  build:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3

      # Build Rust core
      - uses: actions-rs/toolchain@v1
      - run: cargo build --release --manifest-path neptune-core/Cargo.toml

      # Build .NET app
      - uses: actions/setup-dotnet@v3
      - run: dotnet build NeptuneApp/NeptuneApp.csproj -c Release

      # Create installer
      - name: Build WiX installer
        run: heat.exe dir ...

      # Sign executable (optional)
      - name: Sign neptune.exe
        uses: signpath/github-action@v1

      # Upload artifacts
      - uses: actions/upload-artifact@v3
        with:
          name: Neptune-Windows-${{ github.ref_name }}
          path: dist/Neptune-*.exe
```

### Estimated Effort
- **WiX installer setup**: 20 hours
- **CI/CD pipeline**: 15 hours
- **Code signing infrastructure**: 10 hours
- **Total**: ~45 hours

## Full Roadmap Timeline

| Phase | Dates | Effort | Deliverables |
|-------|-------|--------|--------------|
| **Phase 1** | Q2 2026 | 130h | Rust core, C bridge, state schema |
| **Phase 2** | Q3 2026 | 140h | WPF shell, providers, settings |
| **Phase 3** | Q4 2026 | 100h | Process handling, Windows fixes |
| **Phase 4** | Q4 2026 | 45h | Installer, CI/CD, distribution |
| **Total** | ~9 months | ~415h | Fully functional Windows MVP |

## Critical Success Factors

1. **Shared State** — Windows and macOS must read/write identical project state
2. **Provider Detection** — Reliably detect Claude Code CLI, Claude Desktop, VS Code on Windows
3. **Process Management** — Handle Windows process model (pipes vs PTY)
4. **Performance** — Keep resource usage low on Windows (battery isn't a concern but CPU is)
5. **Testing** — Verify workflows work identically on both platforms

## Open Questions & Decisions

1. **Language for core** — Rust vs C vs Go?
   - Decision: Rust (max compatibility, strong type safety)

2. **UI framework** — WPF vs MAUI vs Electron?
   - Decision: WPF (native Windows, mature), migrate to MAUI if cross-platform needed

3. **Process management** — How to handle Windows pipes vs macOS PTY?
   - Decision: Separate process wrapper per platform, shared state format

4. **Distribution** — MSI/EXE/Chocolatey/MSIX?
   - Decision: Portable EXE first (lowest friction), add others after MVP

5. **Feature parity** — Dock pets on Windows?
   - Decision: Tray icon animations instead (different OS paradigm)

---

**Neptune Windows Roadmap** — Local-first cross-platform agents.
