# ITERATION-2 FINAL MASTER PLAN — IDE (OllamaBot)

**Agent**: opus-1
**Round**: 4 (Iteration 2 of consolidation loop)
**Date**: 2026-02-05
**Scope**: ollamabot IDE (Swift/SwiftUI)
**Inputs Consumed**: 20+ plan documents across plans_0 through plans_4, from agents sonnet-1, sonnet-2, opus-1, opus-2, composer-1, composer-2, gemini-1 through gemini-7
**Status**: MASTER VERSION

---

## A. Cross-Round Delta Analysis

### Round 0 (5 plans): Fragmentation Discovery
- Identified 47 shortcomings, 90 optimizations, 10 areas of duplicated implementation
- Three competing architectures proposed: Rust Core (sonnet), Go Core (gemini), Protocol-Only (composer/opus)
- Key IDE files analyzed: Sources/Services/ModelTierManager.swift, Sources/Agent/AgentExecutor.swift, Sources/Services/ContextManager.swift, Sources/Services/OBotService.swift, Sources/Services/MentionService.swift, Sources/Services/OllamaService.swift

### Round 1 (4 plans): First Consolidation
- "CLI-as-Engine" philosophy adopted (from gemini-1)
- Rust core still on the table (from sonnet/composer consolidation)
- 90 optimizations prioritized P0-P4
- 22 Unified Tools defined
- Unified config schema proposed at ~/.obotconfig/config.yaml

### Round 2: Convergence
- Rust rewrite rejected on risk grounds
- Go Core + Strict Protocols selected as winning hybrid

### Round 3 (8 plans per repo): Refinement
- 6 Unified Protocols formalized: UOP, UTR, UCP, UMC, UC, USF
- Implementation plan counts ranged from 8 to 52 depending on agent
- FINAL_COMPREHENSIVE_ANALYSIS.md confirmed "unanimous consensus"

### Round 4 (pre-existing + opus-1): Stabilization
- consolidated-master-plan-round-4.md established the 13-Plan Strategy
- All agents endorsed "Pragmatic Go Core" with JSON-RPC server
- opus-1 expanded to 40-agent decomposition for parallel execution

### What Changed Between Rounds
- DROPPED: Rust rewrite (Round 0-1), deemed too risky
- EVOLVED: Protocol-Only (Round 0) -> Hybrid Protocol+Engine (Round 2+)
- STABILIZED: 6 Protocols, Go Engine + Swift View, 13 -> 40 Atomic Plans
- GAP IDENTIFIED: 13-plan decomposition targets ~13 agents; user requirement is 40-agent parallelism

---

## B. The Consensus Architecture

- **obot (Go)** becomes the Universal Engine, exposing `obot server` via JSON-RPC over Stdio
- **ollamabot (Swift)** becomes the High-Performance View Layer, communicating exclusively via JSON-RPC
- **6 Unified Protocols** serve as the contract between engine and view

---

## C. The 6 Unified Protocols

### UOP — Unified Orchestration Protocol
- 5 Schedules: Knowledge, Plan, Implement, Scale, Production
- 3 Processes per schedule with strict 1-2-3 adjacency navigation
- Prompt termination requires all 5 schedules executed, Production last
- Human consultation: optional at Plan/Clarify, mandatory at Implement/Feedback

### UTR — Unified Tool Registry
- 22 canonical tools across 6 categories:
  - Core (3): think, complete, ask_user
  - Files (10): read_file, create_file, edit_file, delete_file, create_dir, delete_dir, rename, move, copy, search_files, list_directory
  - System (2): run_command, take_screenshot
  - Delegation (3): delegate_to_coder, delegate_to_researcher, delegate_to_vision
  - Web (2): web_search, fetch_url
  - Git (3): git_status, git_diff, git_commit
- Defined by tools.schema.json

### UCP — Unified Context Protocol
- Token-budgeted context allocation: Task 25%, Files 35%, Structure 15%, History 15%, Memory 8%, Errors 2%
- Semantic compression for over-budget sections
- Ported from Swift ContextManager.swift to Go pkg/context

### UMC — Unified Model Coordinator
- Hardware-aware tier detection (RAM-based): Minimal, Compact, Balanced, Performance, Advanced, Maximum
- Intent routing: task type -> model role (orchestrator, coder, researcher, vision)
- Merges IDE cloud pricing data with CLI hardware detection

### UC — Unified Configuration
- File: ~/.obot/config.yaml (YAML)
- Scope: Tiers, Models, Quality Presets, Agent Settings, Orchestration, Consultation
- Both products read the same file

### USF — Unified State Format
- File: ~/.obot/sessions/{id}.json
- Scope: Full session persistence including flow code, recurrence relations, checkpoints, notes, stats
- Sessions started in CLI can be resumed in IDE and vice versa

---

## D. IDE-Specific Architecture Changes

### What the IDE Gains
1. **Formal orchestration framework** — 5-schedule workflow with navigation rules, flow code tracking
2. **Quality presets** — fast/balanced/thorough pipeline modes
3. **Human consultation UI** — Structured questions with 60s timeout and AI substitute
4. **Flow code visualization** — Real-time S1P123S2P12 rendering with color coding
5. **Memory prediction** — Predictive memory bars from server resource data
6. **Session portability** — Sessions started in CLI resumable in IDE

### What the IDE Loses (Migrated to Go Engine)
1. **OllamaService.swift** — Replaced by OBotClient RPC calls
2. **ContextManager.swift** — Logic ported to Go pkg/context; IDE calls client.buildContext()
3. **ModelTierManager.swift** — Logic ported to Go pkg/tier; IDE reads config from server

### New IDE Files

```
Sources/
  Client/
    OBotClient.swift            — JSON-RPC client over Stdio pipe to obot server
    RPCTypes.swift              — Type-safe Swift wrappers for all RPC methods
  Views/
    OrchestrationView.swift     — Wired to RPC session/state stream
    ConsultationView.swift      — Human consultation with timeout + countdown
    FlowCodeView.swift          — Flow code visualization (S=white, P=blue, X=red)
    QualityPresetsView.swift    — fast/balanced/thorough segmented control
    MemoryVisualizationView.swift — Current/Peak/Predict memory bars
  Services/
    OrchestrationBridge.swift   — Maps RPC state to SwiftUI @Observable
    ToolBridge.swift            — Replaces local tool dispatch with client.executeTool()
    ContextBridge.swift         — Replaces ContextManager with client.buildContext()
    ConsultationBridge.swift    — Manages consultation RPC lifecycle
    MemoryBridge.swift          — Streams resource data from server
    ConfigMigration.swift       — Auto-migrates ~/.config/ollamabot/ to ~/.obot/
```

### Deleted IDE Files (After Migration)
- Sources/Services/OllamaService.swift
- Sources/Services/ContextManager.swift
- Sources/Services/ModelTierManager.swift

### Modified IDE Files
- Sources/Agent/AgentExecutor.swift — Replace direct Ollama calls with RPC; replace local tool dispatch with ToolBridge
- Sources/Views/ChatView.swift — Add quality preset selector; wire to RPC context
- Sources/OllamaBotApp.swift — Initialize OBotClient; spawn obot server process

---

## E. IDE Agent Assignments (From 40-Agent Explosion)

The following agents are IDE-scoped:

| Agent | Plan | Owns | Est. Lines |
|-------|------|------|-----------|
| A23 | SWIFT-CLIENT | OBotClient.swift, RPCTypes.swift | ~500 |
| A24 | SWIFT-ORCHESTRATION | OrchestrationView.swift, OrchestrationBridge.swift | ~600 |
| A25 | SWIFT-TOOLS | ToolExecutionView.swift, ToolBridge.swift | ~400 |
| A26 | SWIFT-CONTEXT | ContextBridge.swift, ChatView.swift mods | ~400 |
| A27 | SWIFT-CONSULTATION | ConsultationView.swift, ConsultationBridge.swift | ~300 |
| A28 | SWIFT-MEMORY | MemoryVisualizationView.swift, MemoryBridge.swift | ~250 |
| A29 | SWIFT-FLOWCODE | FlowCodeView.swift | ~150 |
| A30 | SWIFT-QUALITY | QualityPresetsView.swift | ~150 |
| A31 | SWIFT-CLEANUP-SERVICES | Delete OllamaService, ContextManager, ModelTierManager | ~3000 deleted |
| A32 | SWIFT-CLEANUP-AGENTS | Refactor AgentExecutor.swift to thin client | ~200 modified |
| A33 | CONFIG-MIGRATION | ConfigMigration.swift | ~150 |

**Total new Swift**: ~3,100 lines
**Total deleted Swift**: ~3,000 lines
**Net change**: Approximately neutral line count, but 100% of complex logic centralized in Go

---

## F. Success Criteria (IDE-Specific)

1. Swift codebase reduced by ~50% in service layer
2. All 22 tools function through RPC bridge
3. Infinite Mode works end-to-end via OBotClient
4. Session files (.json) from CLI open in IDE
5. Orchestration UI displays live schedule/process state from server
6. Quality presets (fast/balanced/thorough) selectable in chat UI
7. Human consultation renders with countdown timer
8. Flow code renders with correct color coding
9. swift build passes with zero references to deleted services

---

## G. Risk Register (IDE-Specific)

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| RPC latency degrades streaming chat UX | High | High | Keep inner loop (keystroke handling, streaming token display) native in Swift; only offload macro tasks |
| OBotClient process management complexity | Medium | Medium | Robust process lifecycle: spawn on app launch, restart on crash, graceful shutdown on quit |
| Loss of SwiftUI reactivity through RPC | Medium | Medium | OrchestrationBridge uses @Observable with Combine publishers mapped from RPC events |
| Migration breaks existing IDE users | Low | High | Feature flags: new RPC path opt-in during beta; legacy path preserved until stable |
| take_screenshot tool requires native access | Low | Low | Keep screenshot as native Swift call; pass result to server as base64 |

---

## H. Agent-to-Agent Meta-Analysis

### Design Tendencies Observed

1. **Metaphor-driven prioritization**: Gemini-3 named the context port "Brain Transplant" and it dominated subsequent attention, while the RPC server (higher engineering risk) received less analysis.

2. **Consensus by manufactured urgency**: A March deadline appears only in Gemini plans and was never a stated user requirement, yet it was the forcing function to reject Rust.

3. **Relabeling as contribution**: The 6 Unified Protocols in Round 3 are structurally identical to Opus-2's 6 shared contracts from Round 0, renamed with acronyms.

4. **Premature convergence**: By Round 3, agents were writing endorsement and polling-status documents rather than contributing new analysis.

5. **Narrative coherence over operational parallelism**: Every agent gravitated toward fewer, larger plans (8-13) despite the 40-agent requirement.

### Unquestioned Assumptions Worth Revisiting

1. JSON-RPC over Stdio — no evaluation of alternatives (gRPC, Unix sockets, embedded Go)
2. The 5-Schedule model — the current Go implementation is largely stubbed
3. IDE as thin client — sacrifices SwiftUI native performance for latency-sensitive operations
4. Protocol-Only was dismissed early but remains the lowest-risk Phase 1 option

---

*This is the definitive IDE master plan. See explosion-plan-opus-1.md for the full 40-agent decomposition.*
