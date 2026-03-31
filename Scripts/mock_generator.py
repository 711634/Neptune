#!/usr/bin/env python3
"""
Mock Agent State Generator for Clonk

This script continuously updates the agent state JSON file with mock data
to simulate multiple AI coding agents working in real-time.

Usage:
    python3 mock_generator.py [--interval SECONDS]

The script will create the ~/agent-pet directory and state.json file if they don't exist.
Press Ctrl+C to stop.
"""

import json
import os
import random
import time
import argparse
from datetime import datetime, timezone
from pathlib import Path

AGENT_CONFIGS = [
    {
        "name": "Planner",
        "role": "planning",
        "colorVariant": "purple",
        "anchorHint": "terminal",
        "slotIndex": 0,
    },
    {
        "name": "Researcher",
        "role": "research",
        "colorVariant": "cyan",
        "anchorHint": "browser",
        "slotIndex": 1,
    },
    {
        "name": "Builder",
        "role": "coding",
        "colorVariant": "green",
        "anchorHint": "terminal",
        "slotIndex": 2,
    },
    {
        "name": "Reviewer",
        "role": "review",
        "colorVariant": "orange",
        "anchorHint": "figma",
        "slotIndex": 3,
    },
    {
        "name": "Shipper",
        "role": "shipping",
        "colorVariant": "pink",
        "anchorHint": "notes",
        "slotIndex": 4,
    },
]

TASKS = {
    "planning": [
        "Analyzing requirements",
        "Breaking down user stories",
        "Creating technical spec",
        "Estimating effort",
    ],
    "research": [
        "Searching documentation",
        "Finding best practices",
        "Exploring alternatives",
        "Analyzing tradeoffs",
    ],
    "coding": [
        "Implementing features",
        "Fixing bugs",
        "Writing tests",
        "Refactoring code",
        "Optimizing performance",
    ],
    "review": [
        "Code review",
        "Testing changes",
        "Checking edge cases",
        "Verifying security",
    ],
    "shipping": [
        "Running CI/CD",
        "Deploying to staging",
        "Monitoring metrics",
        "Rolling back if needed",
    ],
}

LOGS = {
    "planning": [
        "Planning approach",
        "Defining milestones",
        "Identifying dependencies",
        "Estimating timeline",
    ],
    "research": [
        "Reading docs",
        "Comparing options",
        "Analyzing patterns",
        "Gathering requirements",
    ],
    "coding": [
        "Writing code",
        "Running tests",
        "Debugging issues",
        "Reviewing output",
        "Refactoring",
    ],
    "review": [
        "Analyzing code",
        "Testing edge cases",
        "Checking coverage",
        "Validating security",
    ],
    "shipping": [
        "Building artifacts",
        "Running pipeline",
        "Deploying",
        "Monitoring health",
    ],
}

STATUSES = ["idle", "thinking", "coding", "success", "failed"]


def get_status_for_role(role, previous_status=None):
    """Return a status based on role and previous status."""
    if previous_status == "success":
        return random.choices(["idle", "coding"], weights=[0.3, 0.7])[0]
    elif previous_status == "failed":
        return random.choices(["coding", "thinking"], weights=[0.6, 0.4])[0]
    elif role in ["planning"]:
        return random.choices(["thinking", "idle"], weights=[0.7, 0.3])[0]
    elif role in ["review"]:
        return random.choices(["thinking", "idle"], weights=[0.5, 0.5])[0]
    elif role in ["shipping"]:
        return random.choices(["coding", "success", "idle"], weights=[0.5, 0.3, 0.2])[0]
    else:
        return random.choices(["coding", "thinking", "idle"], weights=[0.6, 0.3, 0.1])[
            0
        ]


def generate_agent_state(num_agents=4):
    """Generate a random agent state with proper role assignments."""
    agents = []

    for i in range(min(num_agents, len(AGENT_CONFIGS))):
        config = AGENT_CONFIGS[i]
        status = get_status_for_role(config["role"])

        role_tasks = TASKS.get(config["role"], TASKS["coding"])
        role_logs = LOGS.get(config["role"], LOGS["coding"])

        agent = {
            "id": f"agent-{i + 1}",
            "name": config["name"],
            "role": config["role"],
            "task": random.choice(role_tasks),
            "status": status,
            "elapsedSeconds": random.randint(5, 1800),
            "lastLog": random.choice(role_logs),
            "updatedAt": datetime.now(timezone.utc).isoformat(),
            "colorVariant": config["colorVariant"],
            "anchorHint": config["anchorHint"],
            "slotIndex": config["slotIndex"],
        }
        agents.append(agent)

    return {"updatedAt": datetime.now(timezone.utc).isoformat(), "agents": agents}


def ensure_state_directory():
    """Ensure the agent-pet directory exists."""
    home = Path.home()
    state_dir = home / "agent-pet"
    state_dir.mkdir(exist_ok=True)
    return state_dir / "state.json"


def write_state(state_file, state):
    """Write state to JSON file."""
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)


def run_generator(interval=3.0, num_agents=4):
    """Main generator loop."""
    print("=" * 50)
    print("Clonk Mock Agent Generator")
    print("=" * 50)
    state_file = ensure_state_directory()
    print(f"Writing to: {state_file}")
    print(f"Update interval: {interval} seconds")
    print(f"Number of agents: {num_agents}")
    print("Press Ctrl+C to stop")
    print("=" * 50)

    previous_statuses = {}

    try:
        while True:
            state = generate_agent_state(num_agents)
            write_state(state_file, state)

            for agent in state["agents"]:
                previous_statuses[agent["id"]] = agent["status"]

            active_count = sum(1 for a in state["agents"] if a["status"] != "idle")
            status_str = ", ".join(
                f"{a['name']}({a['status']})" for a in state["agents"]
            )
            print(
                f"[{datetime.now().strftime('%H:%M:%S')}] "
                f"Updated: {len(state['agents'])} agents, "
                f"{active_count} active - {status_str}"
            )

            time.sleep(interval)

    except KeyboardInterrupt:
        print("\nGenerator stopped.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Clonk mock agent state generator")
    parser.add_argument(
        "--interval",
        "-i",
        type=float,
        default=3.0,
        help="Update interval in seconds (default: 3.0)",
    )
    parser.add_argument(
        "--agents",
        "-a",
        type=int,
        default=4,
        help="Number of agents to simulate (default: 4)",
    )
    args = parser.parse_args()

    run_generator(args.interval, args.agents)
