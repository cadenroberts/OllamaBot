# Master Plan: Gemini-2 — OllamaBot IDE

**Agent:** gemini-2
**Product:** OllamaBot IDE (Swift/SwiftUI)
**Status:** COMPLETE
**Date:** 2026-02-05

## Architecture Role

OllamaBot IDE becomes the **View Layer** — a native macOS frontend that communicates with the obot Go engine via JSON-RPC over Stdio.

```
ollamabot (Swift) = The View
  OBotClient.swift        - RPC client (manages obot server subprocess)
  ToolRouter.swift        - Routes tools to RPC or local execution
  OrchestrationView.swift - Renders 5-Schedule state machine
  (remaining UI)          - Editor, chat, panels, settings
```

## 6 Unified Protocols

1. **UOP** - Unified Orchestration Protocol: 5 Schedules (Knowledge, Plan, Implement, Scale, Production), 3 Processes each, navigation rules (1-2-3)
2. **UTR** - Unified Tool Registry: 22 tools across 6 categories (Core, Files, System, Delegation, Web, Git)
3. **UCP** - Unified Context Protocol: Token-budgeted context with priority sections and compression
4. **UMC** - Unified Model Coordinator: 6 RAM tiers, 4 model roles (orchestrator, coder, researcher, vision)
5. **UC** - Unified Configuration: Single ~/.obot/config.yaml for both products
6. **USF** - Unified State Format: JSON session persistence at ~/.obot/sessions/{id}.json

## IDE-Specific Implementation Plans

### PLAN-SWIFT-CLIENT
Create `OBotClient.swift` — a Swift class that manages the `obot server` subprocess and provides type-safe async RPC calls.

- Spawns `obot server` as a child process
- Communicates via stdin/stdout pipes using JSON-RPC 2.0
- Provides async methods: `startSession()`, `executeTool()`, `detectTier()`, `getConfig()`
- Dispatches notification handlers: `onOrchestratorState`, `onAgentAction`, `onAgentOutput`, `onConsultationRequest`, `onMemoryUpdate`

### PLAN-SWIFT-ORCHESTRATION
Wire IDE orchestration UI to the engine's state machine via RPC.

- New `OrchestrationView.swift`: renders Schedule name, Process indicator (P1/P2/P3), state bar, live flow code
- Dual-mode toggle: Quick Mode (local, single model) vs Orchestrated Mode (RPC to engine)
- Listen to `orchestrator/state` notifications to update UI
- Listen to `consultation/request` to show human feedback dialog
- Keep Infinite Mode working for simple tasks

### PLAN-SWIFT-TOOLS
Replace local tool implementations with RPC calls in Orchestrated Mode.

- New `ToolRouter.swift`: routes based on execution mode
- Orchestrated Mode: `delegate_to_coder`, `delegate_to_researcher`, `delegate_to_vision`, `web_search`, `fetch_url`, `git_*`, `think`, `complete`, `ask_user` go through RPC
- Quick Mode: `read_file`, `write_file`, `edit_file`, `list_directory`, `search_files` stay local for low latency

### PLAN-SWIFT-CONTEXT
Replace local ContextManager with RPC calls in Orchestrated Mode.

- Orchestrated Mode: all context building delegated to engine via `context/build` RPC
- Quick Mode: local ContextManager stays for low-latency single-model chat
- Memory visualization bars updated from `context/update` and `memory/update` RPC notifications

### PLAN-CLEANUP
Delete legacy Swift services replaced by the Go engine.

Files to delete:
1. `Sources/Services/OllamaService.swift` — replaced by engine's `pkg/ollama/`
2. `Sources/Services/ContextManager.swift` — replaced by engine's `pkg/context/`
3. `Sources/Services/ModelTierManager.swift` — replaced by engine's `pkg/tier/`
4. `Sources/Services/IntentRouter.swift` — replaced by engine's model coordinator
5. `Sources/Services/SystemMonitorService.swift` — replaced by engine's `pkg/monitor/`

Files to simplify:
6. `Sources/Services/SessionStateService.swift` — read USF format only
7. `Sources/Services/GitService.swift` — delegate to engine git tools
8. `Sources/Services/WebSearchService.swift` — delegate to engine web tools

Files to keep (IDE-specific):
- FileSystemService.swift, ChatHistoryService.swift, PanelConfiguration.swift
- InlineCompletionService.swift, CheckpointService.swift, APIKeyStore.swift
- ConfigurationService.swift (reads ~/.obot/config.yaml)

## Key Decisions

1. Rust rewrite rejected — too risky for March deadline
2. Go chosen as engine — refactor existing code, not rewrite
3. JSON-RPC over Stdio — proven pattern (LSP, DAP, MCP)
4. Dual-mode operation — Quick Mode (local) + Orchestrated Mode (RPC)
5. IDE's context management ported TO Go (not the other way)
6. CLI's orchestration framework becomes the standard for both products

## Model Contribution Summary

| Model | Primary Contribution | Adopted |
|-------|---------------------|---------|
| Sonnet | Rust core proposal, 90 optimizations, thoroughness | Analysis adopted, Rust rejected |
| Opus | 6 Unified Protocols, 22-tool registry | Fully adopted |
| GPT | Honest stub assessment, incremental approach | Assessment adopted, approach rejected |
| Gemini | Go Engine + JSON-RPC architecture | Fully adopted (core decision) |
| Composer | 10-area component gap analysis | Fully adopted (informed porting decisions) |
