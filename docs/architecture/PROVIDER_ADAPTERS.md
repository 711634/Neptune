# Provider Adapters Architecture

## Overview

Neptune uses a **provider adapter system** to support multiple execution backends and tool integrations. Each adapter implements the `ProviderAdapter` protocol, enabling Neptune to:

1. **Detect** tool availability and authentication
2. **Execute** tasks via the tool's CLI/API
3. **Monitor** active sessions and projects
4. **Launch** projects in the tool
5. **Capture** output and logs

## Protocol Definition

```swift
protocol ProviderAdapter: AnyObject, Sendable {
    var id: String { get }
    var displayName: String { get }
    var icon: String { get }

    // Detection
    var isInstalled: Bool { get async }
    var isAuthenticated: Bool { get async }

    // Context
    var currentProject: String? { get async }
    var activeSession: String? { get async }

    // Operations
    func executeTask(prompt: String, in workDir: String) async throws -> ProviderOutput
    func getAvailableSessions() async throws -> [ProviderSession]
    func openProject(_ path: String) async throws
    func stop() async throws
}
```

## Implemented Adapters

### 1. Claude Code CLI Adapter

**File**: `Services/ClaudeCodeCLIAdapter.swift`

**Purpose**: Direct task execution via locally-authenticated Claude Code CLI

**Implementation Details**:
- Detects: `/opt/homebrew/bin/claude` or custom path
- Authenticates: System authentication (already signed in)
- Executes: Spawns PTY session, sends prompt, captures output
- Sessions: Virtual (CLI processes terminate on completion)

**Example**:
```swift
let adapter = ClaudeCodeCLIAdapter(
    executablePath: "/opt/homebrew/bin/claude"
)

// Check if available
let installed = await adapter.isInstalled
let authenticated = await adapter.isAuthenticated

// Execute a task
let output = try await adapter.executeTask(
    prompt: "Build a React component...",
    in: "/path/to/project"
)
```

**Capabilities**:
- ✅ Full task execution
- ✅ Arbitrary prompts and goals
- ✅ File modification and artifact creation
- ✅ Real-time output capture
- ✅ Process termination on timeout

### 2. Claude Desktop Adapter

**File**: `Services/ClaudeDesktopAdapter.swift`

**Purpose**: Detection and integration with Claude Desktop app

**Implementation Details**:
- Detects: Bundle ID `com.anthropic.claude`
- Authenticates: Persistent app authentication
- Executes: **Not directly supported** (requires manual interaction)
- Sessions: Detects if app is running

**Use Cases**:
- Show Claude Desktop as available provider
- Detect when user is actively using Claude Desktop
- Launch projects for manual Claude Desktop editing
- Visual indicator in Neptune dashboard

**Capabilities**:
- ✅ Installation detection
- ✅ Running status detection
- ✅ Project launch
- ⚠️ Limited direct execution (future via Claude Desktop extensions)

### 3. VS Code Adapter

**File**: `Services/VSCodeAdapter.swift`

**Purpose**: Detect VS Code with Claude extension, workspace integration

**Implementation Details**:
- Detects: Bundle ID `com.microsoft.VSCode` or insiders build
- Authenticates: Extension authentication (local)
- Executes: Via VS Code command line
- Sessions: Active editor/workspace detection

**Use Cases**:
- Show VS Code as available provider
- Detect when user is in a project with VS Code open
- Launch projects in VS Code
- Map active editor state to Neptune pet state

**Capabilities**:
- ✅ Installation detection
- ✅ Running status detection
- ✅ Project launch
- ⚠️ Workspace detection (future via workspace state file)

### 4. Codex Adapter (Planned)

**Purpose**: Support local Codex workflows and CLI

**Implementation Strategy**:
- Detect: Local `.codex/` config or Codex CLI
- Execute: Via local Codex environment
- Monitor: Codex workflow logs
- Integrate: Shared project context

## Provider Registry

**File**: `Services/ProviderAdapter.swift`

The `ProviderRegistry` actor manages all registered adapters:

```swift
let registry = ProviderRegistry(stateManager: stateManager)

// Register adapters
await registry.register(claudeAdapter)
await registry.register(desktopAdapter)
await registry.register(vscodeAdapter)

// Detect available providers
await registry.detectProviders()

// Get best available provider
if let provider = await registry.getAvailableProvider() {
    let output = try await provider.executeTask(...)
}

// Get status of all providers
let statuses = await registry.getStatus()
```

## Adding a New Provider Adapter

### Step 1: Create Adapter Class

```swift
actor NewToolAdapter: ProviderAdapter {
    let id = "new-tool"
    let displayName = "New Tool"
    let icon = "star.fill"

    nonisolated var isInstalled: Bool { get async { ... } }
    nonisolated var isAuthenticated: Bool { get async { ... } }
    nonisolated var currentProject: String? { get async { ... } }
    nonisolated var activeSession: String? { get async { ... } }

    func executeTask(prompt: String, in workDir: String) async throws -> ProviderOutput {
        // Implementation
    }

    func getAvailableSessions() async throws -> [ProviderSession] {
        // Implementation
    }

    func openProject(_ path: String) async throws {
        // Implementation
    }

    func stop() async throws {
        // Implementation
    }
}
```

### Step 2: Register in AppDelegate

```swift
// In NeptuneApp.swift applicationDidFinishLaunching:
let newAdapter = NewToolAdapter()
await providerRegistry.register(newAdapter)
```

### Step 3: Add to pbxproj

Update `Neptune.xcodeproj/project.pbxproj` to include the new file in build target.

### Step 4: Test

```swift
// Test installation detection
let installed = await newAdapter.isInstalled
assert(installed)

// Test authentication
let authenticated = await newAdapter.isAuthenticated
assert(authenticated)

// Test execution
let output = try await newAdapter.executeTask(
    prompt: "test",
    in: "/tmp"
)
```

## Provider Selection Strategy

Neptune uses this strategy to select the best provider:

1. **User preference** — Use `AppSettings.preferredProvider` if available
2. **Availability** — Check `isInstalled && isAuthenticated`
3. **Priority order** — Default: Claude Code CLI > Claude Desktop > VS Code
4. **Fallback** — If none available, show configuration error

```swift
func selectProvider() async -> ProviderAdapter? {
    // Check preferred provider first
    if let prefId = AppSettings.shared.preferredProvider,
       let preferred = await registry.providers[prefId],
       await preferred.isInstalled && await preferred.isAuthenticated {
        return preferred
    }

    // Fall back to available providers in priority order
    return await registry.getAvailableProvider()
}
```

## Output Standardization

All providers return normalized `ProviderOutput`:

```swift
struct ProviderOutput: Sendable, Codable {
    let sessionId: String          // Unique session ID
    let status: String             // "success", "failed", "blocked"
    let output: String             // Full stdout/stderr
    let filesModified: [String]    // Paths of changed files
    let errors: [String]           // Extracted error messages
    let duration: TimeInterval     // Execution time
}
```

This allows Neptune to:
- Track execution time consistently
- Extract files for artifact storage
- Parse errors for retry logic
- Display results uniformly in dashboard

## Future Extensibility

Neptune's adapter system supports:

- **Custom local tools** — Any CLI that accepts prompts
- **Remote agents** — SSH-based remote execution
- **Distributed workflows** — Multiple machines via shared state
- **Hybrid execution** — Mix of local and remote agents

The key is that adapters are **stateless** (except for session tracking) and coordinate through **file-based state** in `~/.neptune/`.

---

**Neptune Provider Adapters** — Decoupled execution backends via clean protocol interfaces.
