# OllamaBot IDE Master Plan (gemini-4)

**Agent:** gemini-4
**Product:** OllamaBot IDE (Swift/SwiftUI)
**Architecture:** Go Bridge + 6 Unified Protocols
**Status:** FINAL MASTER

---

## 1. Executive Summary

OllamaBot IDE will be refactored from a standalone application into a lightweight **UI client** that communicates with the `obot` Go engine via JSON-RPC. All complex logic (orchestration, context management, model coordination) will be delegated to the Go engine. The IDE retains ownership of rendering, OS integration, and user interaction.

---

## 2. The 6 Unified Protocols (IDE Compliance)

### UOP (Unified Orchestration Protocol)
- **Current:** Infinite Mode loop in `AgentExecutor.swift`.
- **Target:** Implement `OrchestratorService.swift` mirroring the CLI's 5-schedule state machine (Knowledge, Plan, Implement, Scale, Production) with strict 1-2-3 process navigation.
- **Files:** `Sources/Services/OrchestratorService.swift` (NEW), `Sources/Views/OrchestrationView.swift` (NEW).

### UTR (Unified Tool Registry)
- **Current:** 18 tools with IDE-specific names (`write_file`, `delegate_to_coder`).
- **Target:** Normalize all tool IDs to the canonical 22-tool registry (`file.write`, `delegate.coder`). Add `ToolValidator.swift` to verify compliance at runtime.
- **Files:** `Sources/Agent/AgentTools.swift` (MODIFY), `Sources/Agent/ToolValidator.swift` (NEW).

### UCP (Unified Context Protocol)
- **Current:** Sophisticated `ContextManager.swift` with token budgeting.
- **Target:** Export context snapshots in UCP JSON format. This is the IDE's **strength** — the Go engine will port this logic, and the IDE validates compliance.
- **Files:** `Sources/Services/ContextManager.swift` (MODIFY to emit UCP JSON).

### UMC (Unified Model Coordinator)
- **Current:** `ModelTierManager.swift` with 6 tiers, `IntentRouter.swift` for routing.
- **Target:** Read tier definitions from shared `~/.ollamabot/config.yaml`. Add RAM-aware fallback logic from CLI.
- **Files:** `Sources/Services/ModelTierManager.swift` (MODIFY).

### UC (Unified Configuration)
- **Current:** `ConfigurationService.swift` using UserDefaults/AppStorage.
- **Target:** Read/write `~/.ollamabot/config.yaml` as the single source of truth. UI settings override and sync back to YAML.
- **Files:** `Sources/Services/ConfigurationService.swift` (REWRITE). Add `Yams` dependency.

### USF (Unified State Format)
- **Current:** Internal session storage via `SessionStateService.swift`.
- **Target:** Import/export sessions as `session.json` files conforming to USF schema. Enable "Open Session" and "Save Session As" for CLI interop.
- **Files:** `Sources/Services/SessionStateService.swift` (MODIFY), `Sources/Services/SessionPersistence.swift` (NEW).

---

## 3. Feature Additions (CLI -> IDE Transfers)

| Feature | Priority | File |
|---------|----------|------|
| 5-Schedule Orchestration | P0 | `OrchestratorService.swift` |
| Quality Presets (fast/balanced/thorough) | P1 | `ChatView.swift` (Picker) |
| Human Consultation (timeout + fallback) | P1 | `ConsultationView.swift` (NEW) |
| Flow Code Tracking (S1P123) | P1 | `StatusBarView.swift` (label) |
| Dry-Run Preview Mode | P1 | `FileSystemService.swift` (flag) |
| Cost Savings Tracker | P2 | `CostTrackingService.swift` (NEW) |
| Line Range Editing | P2 | `EditorView.swift` (range UI) |

---

## 4. Architecture: Go Bridge Integration

The IDE optionally delegates heavy orchestration tasks to the `obot` CLI running in server mode (`obot bridge`), communicating via JSON-RPC over stdio.

```
OllamaBot IDE (Swift)
    |
    v
CLIBridgeService.swift  <-- JSON-RPC Client
    |
    v (stdio pipe)
obot bridge              <-- JSON-RPC Server (Go)
    |
    v
Ollama API (localhost:11434)
```

- **Fast Path (native):** Typing, inline completions, file browsing stay in Swift.
- **Heavy Path (bridge):** Orchestration, multi-model delegation, context building route through Go.

---

## 5. Implementation Phases

### Phase 1: Foundation (Weeks 1-4)
- Add `Yams` dependency for YAML parsing.
- Rewrite `ConfigurationService` to read `~/.ollamabot/config.yaml`.
- Normalize tool IDs in `AgentTools.swift` to UTR.
- Create `OrchestratorService.swift` with UOP state machine.

### Phase 2: Integration (Weeks 5-8)
- Implement `CLIBridgeService.swift` (JSON-RPC client).
- Add Quality Preset picker to `ChatView`.
- Add `ConsultationView` for human-in-the-loop.
- Implement USF session export/import.

### Phase 3: Polish (Weeks 9-12)
- Add `OrchestrationView` (schedule/process visualization).
- Add Cost Tracking dashboard.
- Add Dry-Run preview mode.
- Protocol compliance testing.

---

## 6. Success Metrics

- **Config Parity:** 100% settings shared with CLI via `config.yaml`.
- **Session Portability:** CLI sessions open in IDE without data loss.
- **Tool Parity:** 22/22 UTR tools functional.
- **Orchestration:** Full 5-schedule support with flow code tracking.
- **Performance:** No regression in UI responsiveness.

---

## 7. Key Existing Files Reference

- `Sources/Agent/AgentExecutor.swift` — Current agent loop (to be refactored).
- `Sources/Services/OllamaService.swift` — Ollama API client (remains for direct calls).
- `Sources/Services/ContextManager.swift` — Token budgeting (reference implementation for Go port).
- `Sources/Services/ModelTierManager.swift` — Tier detection (to align with shared config).
- `Sources/Services/IntentRouter.swift` — Intent classification (to align with UMC).
- `Sources/Views/ChatView.swift` — Primary chat interface (add Quality Preset picker).
- `Sources/Views/StatusBarView.swift` — Status bar (add Flow Code display).

---

**END OF IDE MASTER PLAN (gemini-4)**
