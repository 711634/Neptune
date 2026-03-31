# Neptune Windows MVP

A lightweight local autonomous agent platform for Windows, built with Tauri v2, Rust, and React.

## System Requirements

- Windows 10 (build 19041) or Windows 11
- Node.js 18+
- Rust 1.70+

## Quick Start

### 1. Install Dependencies

```bash
# Install Rust (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install Node dependencies
npm install
```

### 2. Run in Development Mode

```bash
npm run tauri-dev
```

This launches the Tauri development server with hot reload for the React frontend.

### 3. Build for Distribution

```bash
npm run tauri-build
```

This produces:
- `src-tauri/target/release/neptune.exe` — Standalone executable
- `src-tauri/target/release/bundle/msi/Neptune_1.0.0_x64_en-US.msi` — Windows installer

## Architecture

### Backend (Rust + Tauri)

**State Management** (`src-tauri/state/mod.rs`)
- File-based persistence in `C:\Users\{username}\AppData\Local\Neptune\`
- Projects stored as JSON in `projects/{projectId}/project.json`
- Agent state stored in `projects/{projectId}/agents/{agentId}/state.json`
- Transcripts logged to `projects/{projectId}/agents/{agentId}/transcript.log`

**Provider Detection** (`src-tauri/providers/`)
- `claude_code.rs`: Detects Claude Code CLI via `where` command
- `vscode.rs`: Registry lookup + common path detection
- `claude_desktop.rs`: AppData and Program Files detection
- All providers expose `id()`, `name()`, `detect()`, `get_status()` interface

**IPC Commands** (`src-tauri/commands/`)
- `projects.rs`: Create, list, update, delete projects
- `agents.rs`: Manage agent lifecycle and output
- `settings.rs`: Load/save application settings
- `providers.rs`: Detect and query provider status

### Frontend (React + TypeScript + Tailwind)

**Pages**
- `Dashboard.tsx`: Overview with project stats and recent projects
- `Projects.tsx`: Project management (create, list, delete)
- `Settings.tsx`: Application configuration

**Styling**
- Tailwind CSS with dark theme
- Neptune color scheme (sky blue #0ea5e9)
- Responsive layout with sidebar navigation

## Development Workflow

### Adding a New IPC Command

1. **Define command in Rust** (`src-tauri/commands/your_module.rs`)
   ```rust
   #[tauri::command]
   pub fn cmd_your_command(param: String, state: State<NeptuneState>) -> Result<String, String> {
       // Implementation
       Ok(result)
   }
   ```

2. **Export from `commands/mod.rs`**
   ```rust
   pub use your_module::*;
   ```

3. **Register in `main.rs`**
   ```rust
   .invoke_handler(tauri::generate_handler![
       commands::cmd_your_command,
   ])
   ```

4. **Call from React**
   ```typescript
   import { invoke } from '@tauri-apps/api/tauri'
   const result = await invoke('cmd_your_command', { param: 'value' })
   ```

### Adding a New Provider

1. **Create provider adapter** (`src-tauri/providers/your_provider.rs`)
   ```rust
   pub struct YourProvider { installed: bool }
   
   impl Provider for YourProvider {
       fn id(&self) -> &str { "your_provider" }
       fn name(&self) -> &str { "Your Provider Name" }
       fn detect(&self) -> bool { /* Detection logic */ }
       fn get_status(&self) -> ProviderStatus { /* Status */ }
   }
   ```

2. **Register in `providers/mod.rs`**
   ```rust
   pub use your_provider::YourProvider;
   
   pub fn init_providers() -> ProviderRegistry {
       providers.push(Arc::new(YourProvider::new()));
       // ...
   }
   ```

## Building the Installer

The Windows MVP builds a professional MSI installer:

```bash
npm run tauri-build
```

Output location:
```
src-tauri/target/release/bundle/msi/Neptune_1.0.0_x64_en-US.msi
```

The installer:
- Registers Neptune in Windows Add/Remove Programs
- Creates Start Menu shortcuts
- Installs to `C:\Program Files\Neptune\`
- Handles upgrades and uninstallation

## File Locations

### Application Data
- **Base**: `C:\Users\{username}\AppData\Local\Neptune\`
- **Projects**: `AppData\Local\Neptune\projects\`
- **Settings**: `AppData\Local\Neptune\settings.json`
- **Logs**: `AppData\Local\Neptune\logs\`

### Application Files (Post-Install)
- **Installation**: `C:\Program Files\Neptune\`
- **Executable**: `C:\Program Files\Neptune\neptune.exe`
- **Resources**: `C:\Program Files\Neptune\resources\`

## Performance Optimization

Neptune is designed to be lightweight:

- **Tauri**: ~200MB on disk vs ~400MB for Electron
- **Memory**: ~100-150MB idle vs ~300MB for Electron
- **CPU**: <5% idle with low-power mode enabled
- **Battery**: Optimized for laptop use with background activity controls

Size optimizations applied:
- `opt-level = "z"` for binary size
- Link-time optimization (LTO) enabled
- Symbols stripped from release builds

## Testing

### Unit Tests (Rust)
```bash
cargo test --lib
```

### Integration Tests
```bash
cargo test
```

### Frontend Testing
Add Jest/Vitest configuration as needed.

## Security

- No hardcoded credentials or API keys
- All secrets via environment variables
- Windows registry access only for app detection
- Safe file path handling (no path traversal)
- Process detection via `tasklist` (non-privileged)

## Known Limitations

- Windows 10 build 19041+ required (WebView2 dependency)
- Claude Desktop detection requires specific installation paths
- VS Code detection uses registry (Windows-specific)
- Single-user mode (system-wide installation planned)

## Contributing

Follow Rust style guidelines:
```bash
cargo fmt
cargo clippy -- -D warnings
```

## License

© Neptune Contributors. See LICENSE in root.
