# OllamaBot FINAL MASTER PLAN — IDE

**Version:** 3.0 (The "Pragmatic Bridge" Consensus)
**Author:** Gemini-7 (Consolidating Sonnet-3, Composer-2, Gemini-6)
**Date:** 2026-02-05
**Scope:** OllamaBot IDE (Swift/SwiftUI)
**Philosophy:** Protocols for Standards, Go for Engine. No Rust Rewrite.

---

## 1. The Core Decision: Architecture

We analyzed three competing architectures:
1. **Rust Core (Sonnet):** Write a new shared library in Rust. (Rejected: Too high risk for March).
2. **Pure Protocols (Composer):** No shared code, just shared JSON schemas. (Rejected: Duplicates complex logic like Context Management).
3. **Go Bridge (Gemini):** Use the mature `obot` CLI as the shared engine via JSON-RPC. (Accepted: Best balance of code reuse and safety).

**Verdict:** We proceed with the **Go Bridge Architecture** reinforced by **Strict Protocols**.

---

## 2. System Architecture: The "One Brain"

### 2.1 The Engine (`obot`)
The `obot` CLI (Go) is refactored to expose its internals as a service.
- **Service Layer:** `pkg/service/` wraps Orchestrator, Context, and Tools.
- **Bridge Mode:** `obot bridge` starts a JSON-RPC 2.0 server over Stdio.

### 2.2 The Interface (`ollamabot`)
The IDE (Swift) becomes a lightweight UI layer.
- **Protocol:** Communicates exclusively via JSON-RPC.
- **State:** Mirrors the Engine's state (Session, Orchestration status).

### 2.3 The Protocols (The Contract)
We adopt the **6 Unified Protocols**:
1. **UOP (Orchestration):** 5 Schedules (Knowledge, Plan, Implement, Scale, Production).
2. **UTR (Tools):** 22 Standardized Tools (File, Git, Search, System).
3. **UCP (Context):** Token Budgeting & Semantic Compression (Ported from Swift to Go).
4. **UMC (Models):** Tier Detection & Intent Routing.
5. **UC (Config):** Shared YAML Configuration.
6. **USF (State):** Unified Session Format.

---

## 3. IDE-Specific Implementation

### 3.1 BridgeService (Swift JSON-RPC Client)
- **File:** `Sources/Services/BridgeService.swift`
- **Role:** Spawns `obot bridge --stdio`, manages the subprocess lifecycle.
- **Protocol:** Sends JSON-RPC requests, receives streamed JSON-RPC notifications.
- **Crash Recovery:** If the `obot` process crashes, BridgeService restarts it transparently.

### 3.2 Swift Refactoring

**Services to DEPRECATE (replaced by Bridge calls):**
- `OllamaService.swift` — Replaced by `BridgeService` calling the Go engine.
- `ContextManager.swift` — Token budgeting logic moves to Go `pkg/context`.
- `ModelTierManager.swift` — Tier detection moves to Go `pkg/model`.
- `IntentRouter.swift` — Intent routing moves to Go `pkg/model`.

**Services to KEEP (UI-only, not duplicated in Go):**
- `DesignSystem.swift` — UI tokens, colors, typography.
- `SyntaxHighlighter.swift` — Editor rendering.
- `FileSystemService.swift` — Local file watching for the editor.
- `PerformanceCore.swift` — LRU cache, throttle/debounce for UI.

**Views to UPDATE:**
- `AgentView.swift` — Wire to BridgeService stream instead of local AgentExecutor.
- `ChatView.swift` — Render thoughts/tool calls from JSON-RPC notifications.
- `SettingsView.swift` — Read/write shared `~/.obot/config.yaml`.

### 3.3 New IDE Features (from CLI parity)
- **Quality Presets UI:** Add Fast/Balanced/Thorough selector to Infinite Mode.
- **Orchestration Visualization:** Render the 5-Schedule state from the Bridge stream.
- **Cost Tracking Panel:** Display token costs streamed from the Go engine.
- **Dry-Run Mode:** Preview changes without applying (toggle in UI).
- **Session Import:** Load CLI-created sessions from `~/.obot/sessions/`.

---

## 4. Implementation Roadmap

### Phase 1: Foundation (Weeks 1-4)
- P1.09: Create Swift `BridgeService` client.
- P1.05: Implement shared YAML config loader in Swift (`Yams`).

### Phase 2: Migration (Weeks 5-8)
- P2.04: Update IDE to use `BridgeService` for Task Execution.
- P2.05: Wire `AgentView` to BridgeService stream.
- P2.06: Deprecate local `OllamaService` calls.

### Phase 3: Unification (Weeks 9-12)
- P3.02: Ensure IDE `AgentView` renders tool calls from Bridge.
- P3.04: Add Orchestration Visualization panel.
- P3.05: Add Quality Presets selector.
- P3.06: Session import/export (USF).
- P3.07: Remove deprecated services.

---

## 5. Success Criteria
1. **Zero Logic Duplication:** Complex algorithms (Context, Orchestration) exist ONLY in Go.
2. **Perfect Fidelity:** IDE shows exactly what the CLI is thinking/doing.
3. **March Release:** Achievable because we are refactoring, not rewriting.
4. **Swift LOC Reduction:** ~50% reduction in service-layer Swift code.
5. **Latency:** JSON-RPC over stdio adds < 1ms overhead per call (negligible vs LLM inference).
