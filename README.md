# Clonk

A Tamagotchi-style macOS desktop companion for AI coding agents. Clonk renders multiple pixel-art pets above your Dock, each representing a different AI agent with its own role, color, and animation.

![Platform](https://img.shields.io/badge/Platform-macOS-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Multi-Pet Dock Overlay** - Multiple pixel pets floating above your Dock
- **Role Badges** - Each pet has a colored badge showing its role (PLANNING, RESEARCH, CODING, REVIEW, SHIPPING)
- **Menu Bar Integration** - Tiny pet icon shows overall state at a glance
- **Dynamic Dock Icon** - Dock icon reflects overall agent activity
- **Dashboard Window** - Compact view of all agents and their tasks
- **Independent Animations** - Each pet animates based on its own state
- **Mock Mode** - Works out of the box with simulated agent data
- **Settings** - Customize polling interval, idle timeout, reduced motion, and more

## Pet States

| State | Description | Color |
|-------|-------------|-------|
| Idle | Waiting for work | Gray |
| Thinking | Agent is planning/analyzing | Amber |
| Coding | Agent is actively coding | Green |
| Success | Task completed | Bright Green |
| Failed | Error occurred | Red |
| Sleeping | No activity for timeout | Blue |

## Quick Start

### 1. Open the Project in Xcode

```bash
cd /Users/misbah/Clonk
open Clonk.xcodeproj
```

### 2. Build and Run

In Xcode, press `Cmd+R` to build and run the app.

The app will:
- Create the `~/agent-pet/` directory with sample state
- Show a floating dock overlay with multiple pixel pets
- Appear in the menu bar with a tiny pet icon
- Open a small dashboard window
- Start mock data generation (enabled by default)

### 3. Watch the Pets

The floating dock overlay appears just above your Dock showing:
- **Planner** (purple) - thinking/planning
- **Builder** (green) - coding
- **Reviewer** (blue) - reviewing
- **Shipper** (pink) - deploying

Each pet animates independently based on its agent's state.

### 4. Run the Mock Generator (Optional)

To see dynamic updates, run the mock generator in a separate terminal:

```bash
cd /Users/misbah/Clonk
python3 Scripts/mock_generator.py
```

This continuously updates the state file with randomized agent states.

## Project Structure

```
Clonk/
├── Clonk/
│   ├── App/
│   │   ├── ClonkApp.swift          # Main app entry + AppDelegate
│   │   └── ContentView.swift       # Root SwiftUI view
│   ├── Models/
│   │   ├── Agent.swift             # Agent + AgentState models
│   │   ├── PetState.swift          # Pet state enum
│   │   └── AppSettings.swift       # User preferences
│   ├── Services/
│   │   ├── AgentStateWatcher.swift # JSON file monitoring
│   │   ├── PetStateMapper.swift    # State mapping logic
│   │   └── MockDataGenerator.swift # Built-in mock data
│   ├── Views/
│   │   ├── Pet/
│   │   │   ├── PixelPetView.swift       # Pixel art pet renderer
│   │   │   └── FloatingDockWindow.swift  # Dock overlay window
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift      # Main dashboard
│   │   │   └── AgentRowView.swift       # Agent list item
│   │   ├── MenuBar/
│   │   │   └── MenuBarView.swift        # Menu bar popover
│   │   └── Settings/
│   │       └── SettingsView.swift       # Settings panel
│   └── Resources/
│       ├── Assets.xcassets/
│       └── state.json                   # Sample state file
├── Scripts/
│   └── mock_generator.py              # Python mock data generator
├── project.yml                        # XcodeGen configuration
└── README.md
```

## Connecting Real Agents

To connect real AI coding agents to Clonk, modify the JSON file at:

```
~/agent-pet/state.json
```

### JSON Format

```json
{
  "updatedAt": "2026-03-30T02:41:00Z",
  "agents": [
    {
      "id": "agent-1",
      "name": "Planner",
      "role": "planning",
      "task": "Analyzing requirements",
      "status": "thinking",
      "elapsedSeconds": 120,
      "lastLog": "Parsing user story",
      "updatedAt": "2026-03-30T02:41:00Z",
      "colorVariant": "purple",
      "anchorHint": "terminal",
      "slotIndex": 0
    },
    {
      "id": "agent-2",
      "name": "Builder",
      "role": "coding",
      "task": "Building features",
      "status": "coding",
      "elapsedSeconds": 320,
      "lastLog": "Implementing hero section",
      "updatedAt": "2026-03-30T02:40:50Z",
      "colorVariant": "green",
      "anchorHint": "browser",
      "slotIndex": 1
    }
  ]
}
```

### Agent Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique agent identifier |
| `name` | string | Agent display name |
| `role` | string | Role: planning, research, coding, review, shipping |
| `task` | string | Current task description |
| `status` | string | State: idle, thinking, coding, success, failed, sleeping |
| `elapsedSeconds` | int | Seconds since agent started |
| `lastLog` | string | Recent activity log |
| `updatedAt` | string | ISO8601 timestamp |
| `colorVariant` | string | Color: green, blue, purple, orange, pink, cyan, red |
| `anchorHint` | string | Hint: terminal, browser, figma, notes, generic |
| `slotIndex` | int | Position in dock overlay (0-5) |

### Status Values

- `idle` - Agent is waiting
- `thinking` - Agent is planning/analyzing
- `coding` - Agent is actively coding
- `success` - Task completed successfully
- `failed` - Task failed or error occurred
- `sleeping` - Agent idle too long

### Color Variants

- `green` - Default coding color
- `blue` - Research/analysis
- `purple` - Planning
- `orange` - Warning/thinking
- `pink` - Shipping/deployment
- `cyan` - Research
- `red` - Error/failed

## Integration Example (Python)

Add this to your agent's code to update Clonk:

```python
import json
from datetime import datetime, timezone
from pathlib import Path

def update_clonk_state(agent_id, name, role, task, status, elapsed_seconds, last_log, 
                      color_variant="green", slot_index=0):
    """Update agent state for Clonk dock overlay."""
    state_file = Path.home() / "agent-pet" / "state.json"
    
    # Read existing state
    if state_file.exists():
        with open(state_file) as f:
            state = json.load(f)
    else:
        state = {"updatedAt": None, "agents": []}
    
    # Build agent data
    agent_data = {
        "id": agent_id,
        "name": name,
        "role": role,
        "task": task,
        "status": status,
        "elapsedSeconds": elapsed_seconds,
        "lastLog": last_log,
        "updatedAt": datetime.now(timezone.utc).isoformat(),
        "colorVariant": color_variant,
        "anchorHint": "terminal",
        "slotIndex": slot_index
    }
    
    # Update or append agent
    for i, agent in enumerate(state["agents"]):
        if agent["id"] == agent_id:
            state["agents"][i] = agent_data
            break
    else:
        state["agents"].append(agent_data)
    
    state["updatedAt"] = datetime.now(timezone.utc).isoformat()
    
    # Write back
    with open(state_file, 'w') as f:
        json.dump(state, f, indent=2)

# Example usage
update_clonk_state(
    agent_id="my-agent",
    name="Builder",
    role="coding",
    task="Implementing login",
    status="coding",
    elapsed_seconds=45,
    lastLog="Adding OAuth flow",
    color_variant="green",
    slot_index=0
)
```

## Settings

Access settings via the menu bar popover or **Clonk > Settings**:

- **Use Mock Data** - Toggle between mock and real data
- **Idle Timeout** - Minutes before agent sleeps (1-15 min)
- **Polling Interval** - How often to check for updates (1-10s)
- **Reduced Motion** - Disable animations for accessibility
- **Launch at Login** - Start app when you log in (TODO)

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Clonk App                         │
├─────────────────────────────────────────────────────┤
│  AppDelegate                                        │
│  ├── FloatingDockWindow (NSPanel)                  │
│  │   └── Renders all pets in dock overlay          │
│  ├── Menu Bar (NSStatusItem)                       │
│  │   └── Shows overall state icon                   │
│  ├── Dashboard Window                               │
│  │   └── Lists all agents and their states          │
│  └── Settings Window                                │
│      └── User preferences                           │
├─────────────────────────────────────────────────────┤
│  Services                                           │
│  ├── AgentStateWatcher                              │
│  │   ├── Watches ~/agent-pet/state.json            │
│  │   └── Polls every N seconds                      │
│  ├── PetStateMapper                                 │
│  │   └── Maps agent states to pet states           │
│  └── MockDataGenerator                              │
│      └── Generates demo agent data                  │
└─────────────────────────────────────────────────────┘
```

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Python 3.x (for mock generator)

## Building

The project uses XcodeGen. If you need to regenerate:

```bash
cd /Users/misbah/Clonk
xcodegen generate
```

Then open `Clonk.xcodeproj` in Xcode and build with `Cmd+R`.

## Next Steps

To integrate with real agents:

1. **OpenCode** - Add `update_clonk_state()` calls to your agent's main loop
2. **Claude/Groq/Gemini** - Create a wrapper that writes state after each tool use
3. **Custom Agents** - Any agent can write to `~/agent-pet/state.json`

The app automatically watches the file and updates all pets in real-time!

## License

MIT License - See LICENSE file for details.
