# Neptune Architecture Analysis & Reference Learnings

**Date:** April 1, 2026  
**Scope:** Clean-room architectural improvements inspired by Claude Code (v2+) design patterns  
**Constraint:** No direct code copying; patterns studied and reimplemented in Neptune-native ways

---

## A. Neptune Architecture Summary

### Current State
Neptune is a **dual-platform agent orchestration system** for macOS/Windows:

**macOS Frontend (SwiftUI):**
- Multi-agent dashboard with pixel pet metaphor
- Agent lifecycle: idle → planning → research → coding → review → shipping
- Project creator and task graph visualization
- Provider detection (Claude Code, VS Code, Claude Desktop)
- Skill registry and task dependency management
- State persistence via StateManager

**Windows Backend (Tauri + Rust):**
- Parallel provider implementations (Claude Code, VS Code, Claude Desktop)
- Cross-platform file system and process management
- TCP server for macOS←→Windows communication
- Provider adapters abstracted behind trait-based interface
- Tauri commands for UI invocation

**Orchestration Core:**
- AgentOrchestrator: actor-based main loop managing task assignment
- TaskGraph: directed acyclic graph with dependency resolution
- SkillRegistry: skill pack loading per project type
- ClaudeCodeRunner: task-to-provider invocation
- ProcessManager: PTY session and process lifecycle

### Architecture Strengths
✅ Clean separation: adapters, state, services, models  
✅ Actor pattern for thread-safe state (Swift actors)  
✅ Trait-based polymorphism (Rust providers)  
✅ Observable state propagation to UI  
✅ Skill-driven task context  
✅ Idempotent provider detection  

### Identified Gaps
- **No structured context window management** — tasks don't track token budget or adapt to available context
- **Shallow retry logic** — fixed `maxRetries=3`, no exponential backoff or circuit breaker
- **Missing permission/safety gating** — no tool-level authorization checks or user prompts before sensitive operations
- **No session compression** — long-running projects accumulate unbounded message history
- **Single agent loop** — no delegation to sub-agents; all tasks run in main orchestration loop
- **Weak error recovery** — failed tasks mark as failed; no resumption from checkpoint
- **No cost tracking** — agents don't know budget; no spend monitoring across turns
- **Minimal observability** — status messages only; no structured metrics or hook points

---

## B. Five Key Learnings from Claude Code

### 1. **Query Engine Pattern** ⭐ High Impact
**What it does:**  
Claude Code's `QueryEngine` class owns the entire query lifecycle: message persistence, tool invocation, permission gating, cost tracking, and history compaction. One engine per conversation; state persists across turns.

**Why it matters:**  
Decouples session management from the main loop. Enables:
- Resumable sessions (save/load message history)
- Progressive history compaction (snip boundaries)
- Per-turn budget enforcement
- Structured error recovery (permission denials, tool failures)
- Clear ownership of conversation state

**How Neptune could adopt:**
Create a `SessionEngine` (or rename `AgentOrchestrator` → `ProjectEngine`) that owns:
- Message log (task → agent → output chains)
- Turn counter (session progress)
- Cost/token budget tracking
- Checkpoint/resumption state
- Permission decision log

Current `AgentOrchestrator` already has pieces; refactor to centralize session lifecycle.

**Risk/Complexity:** Medium. Requires threading session context through orchestration loop. Payoff: unlocked resumption, cost bounds, audit trails.

---

### 2. **Tool Invocation Context** ⭐ High Impact
**What it does:**  
Claude Code wraps every tool call in a `ToolUseContext` that carries:
- Tool permissions (allow/deny/ask rules)
- File read/glob limits (prevent runaway I/O)
- AbortController (cancellation)
- Budget constraints (max USD, max turns)
- Permission decision history (denial tracking for fallback-to-prompting)
- Structured callbacks (elicitation, progress, notifications)

**Why it matters:**  
Prevents tool misuse without runtime surprises. Enables:
- Fine-grained permissioning (e.g., "allow Bash only in src/")
- Resource budgeting (don't let one runaway tool consume all tokens)
- Cancellation safety (abort ongoing operations gracefully)
- User intervention via prompts (interactive tool approvals)
- Audit logging (who authorized what, when)

**How Neptune could adopt:**
Introduce `TaskExecutionContext` (Swift struct) threaded through `runTask()`:
```
struct TaskExecutionContext {
    let budgetTokens: Int
    let budgetUSD: Double
    let allowedWorkDirs: Set<String>
    let permissions: PermissionMode  // "allow", "ask", "deny"
    let cancelSignal: () -> Bool
    let decisions: [String: Decision]  // Tool name → approved/denied
}
```

Pass context to `ClaudeCodeRunner.runTask()`; runner enforces limits before delegating.

**Risk/Complexity:** Medium. Requires threading context; payment systems don't exist yet so USD budget can stub to `Double.infinity` initially.

---

### 3. **Structured Retry & Backoff** ⭐ Medium Impact
**What it does:**  
Claude Code categorizes API errors (retryable vs permanent), applies exponential backoff, respects retry budgets per task, and logs retry attempts with reason.

**Why it matters:**  
Transient failures (rate limits, timeouts) shouldn't cascade into failed projects. Enables:
- Automatic recovery from flaky providers
- Cost savings (batch retries, avoid thundering herd)
- Observable retry history (debug "why did the task fail?")
- Circuit breakers (stop retrying after N consecutive failures)

**How Neptune could adopt:**
Extend `Task` model with:
```swift
struct RetryPolicy {
    let maxAttempts: Int = 3
    let initialBackoffMs: Int = 100
    let maxBackoffMs: Int = 10_000
    let backoffMultiplier: Double = 2.0
    var attempts: [(Date, Error)]? = nil
}
```

In `runTask()`, wrap `claudeRunner.runTask()` with retry loop:
```swift
let policy = RetryPolicy()
var lastError: Error?
for attempt in 0..<policy.maxAttempts {
    do {
        return try await claudeRunner.runTask(...)
    } catch let error as ProviderError {
        guard error.isRetryable else { throw error }
        lastError = error
        let backoff = min(
            policy.initialBackoffMs * pow(policy.backoffMultiplier, Double(attempt)),
            Double(policy.maxBackoffMs)
        )
        try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000))
    }
}
throw lastError ?? OrchestratorError.maxRetriesExceeded
```

**Risk/Complexity:** Low. Isolated to `runTask()` method. Can start with simple exponential backoff.

---

### 4. **History Compaction & Snipping** ⭐ Medium Impact
**What it does:**  
Claude Code periodically "snips" (compacts) long message histories at logical boundaries (e.g., after a tool succeeds). The snip operation:
- Extracts a summary of past turns
- Replays snipped messages through a compaction model
- Injects compressed summary back into context
- Clears old messages from memory
- Records snip boundary for audit

**Why it matters:**  
Long-running projects accumulate unbounded message history → token waste. Enables:
- Fixed context window usage (snip when > 80% full)
- Transparent compression (model doesn't see snipped detail)
- Session resumption without replaying 100 turns
- Cost savings (fewer input tokens on next turn)

**How Neptune could adopt:**
Add to `TaskGraph`:
```swift
struct SnipCheckpoint {
    let taskId: String
    let messagesUntil: Int
    let summaryPrompt: String?  // Optional compaction instruction
    let timestamp: Date
}
```

In `runOrchestrationLoop()`, after every 10 tasks or > 50KB history:
```swift
if shouldSnip(taskGraph: taskGraph) {
    let summary = try await claudeRunner.summarizeProgress(taskGraph)
    taskGraph.snips.append(SnipCheckpoint(...))
    taskGraph.clearOldMessages(before: lastSnipTime)
}
```

**Risk/Complexity:** Medium. Requires coordination with Claude API. Can stub with a simple token counter first.

---

### 5. **Permission Decision Tracking & Fallback Prompting** ⭐ Low-Medium Impact
**What it does:**  
Claude Code maintains a denial counter: if a tool is denied > 3 times in a session, it falls back to interactive prompt mode (ask user). Decisions are logged with source (hook auto-deny, permission rule, user prompt).

**Why it matters:**  
Tools fail silently when permissions are misconfigured. Enables:
- Fail-safe UX (if tool keeps being denied, ask user instead of silent failures)
- Configuration debugging (see which rules block which tools)
- User override capability (interactive approval even if rules deny)

**How Neptune could adopt:**
Add to `StateManager`:
```swift
struct PermissionLog: Codable {
    let toolName: String
    let source: String  // "hook", "rule", "user_prompt"
    let decision: String  // "allow", "deny"
    let timestamp: Date
}

struct ProjectState {
    var permissionLog: [PermissionLog] = []
    var denialCountByTool: [String: Int] = [:]
}
```

In `ClaudeCodeRunner.runTask()`:
```swift
let denialCount = await stateManager.getDenialCount(for: tool)
if denialCount > 3 {
    // Fallback: show interactive approval dialog instead of auto-reject
    let approved = await PermissionPrompt.show(toolName: tool)
}
```

**Risk/Complexity:** Low. Can be added after permission system exists.

---

## C. Impact Assessment Matrix

| Learning | Adoption Effort | Impact | Dependencies | Timeline |
|----------|-----------------|--------|--------------|----------|
| Query Engine Pattern | High | ⭐⭐⭐ Unblocks resumption, cost tracking | None | Phase 2 |
| Tool Context | High | ⭐⭐⭐ Enables budgeting, permissioning | Payment system design | Phase 2 |
| Retry & Backoff | Low | ⭐⭐ Robustness | None | Phase 1 |
| History Compaction | Medium | ⭐⭐ Long-session efficiency | Claude API integration | Phase 2 |
| Permission Tracking | Low | ⭐ UX polish, debugging | Permission system MVP | Phase 1 |

---

## D. Prioritized Implementation Roadmap

### **NOW** (Week 1)
1. **Structured Retry with Exponential Backoff**
   - Extend `Task` model with `RetryPolicy`
   - Add retry loop to `runTask()` in `AgentOrchestrator`
   - Log retry attempts with backoff durations
   - **Why:** Low friction, immediate robustness gain, no breaking changes

### **NEXT** (Week 2–3)
2. **SessionEngine Refactor (Phase 1)**
   - Rename `AgentOrchestrator` → `ProjectEngine` (or create `SessionEngine` wrapper)
   - Add message log, checkpoint tracking, cost accumulator
   - Thread session context through orchestration loop
   - Save/load session state to disk (JSON file per project)
   - **Why:** Foundation for resumption, cost tracking, audit logging

3. **Task Execution Context**
   - Define `TaskExecutionContext` struct
   - Pass through `runTask()` → `claudeRunner.runTask()`
   - Enforce budget checks before tool invocation
   - Log decisions (allowed, denied, etc.)
   - **Why:** Permission gating, resource limits, audit trail

### **LATER** (Week 4+)
4. **History Compaction**
   - Token counting per task
   - Snip trigger (80% window full)
   - Stub "summarizeProgress" API call (defer to later)
   
5. **Permission Fallback Prompting**
   - Track denial counts per tool
   - Show interactive approval UI after threshold

---

## E. Top 3 Changes to Implement Immediately

### **Change 1: Structured Retry Loop** ⭐ Start Here
**File:** `Neptune/Services/AgentOrchestrator.swift`  
**Lines:** 214–292 (runTask method)  

**What:** Add exponential backoff + retry policy to task execution

**Why:** Immediate robustness (recovers from transient provider failures) + zero risk (isolated change)

---

### **Change 2: Session Checkpointing** ⭐ High Value
**File:** `Neptune/Services/StateManager.swift`  
**New:** Add checkpoint save/load methods

**What:** Save task graph + agent state + message log at key points (task completion, project pause)

**Why:** Enables resumption (core feature for long-running projects)

---

### **Change 3: Task Execution Context** ⭐ Foundation
**File:** `Neptune/Services/AgentOrchestrator.swift`  
**New:** Define `TaskExecutionContext` struct; thread through `runTask()`

**What:** Centralize permissions, budgets, cancellation in one struct passed to tool invocation

**Why:** Unblocks tool-level permissioning and cost tracking

---

## F. Implementation Plan: Change 1 (Retry Loop)

See next section for minimal, production-ready implementation.

---

## Summary

Neptune has solid fundamentals: clean architecture, actor-based concurrency, provider abstraction. The reference source reveals three high-leverage patterns:

1. **Centralized session engine** — owns message history, cost tracking, resumption
2. **Context-threaded tool invocation** — permissions, budgets, cancellation in one struct
3. **Structured retry with backoff** — transient failures don't cascade

Implementing these three in order (retry → session → context) would add:
- ✅ Automatic recovery from flaky providers
- ✅ Long-session cost tracking
- ✅ Resumable projects (save/load state)
- ✅ Tool-level permission gating
- ✅ Observable operation history

All feasible without rewriting core; all aligned with Neptune's clean architecture.
