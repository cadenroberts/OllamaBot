# ITERATION-2 FINAL MASTER PLAN

**Agent**: opus-1
**Round**: 4 (Iteration 2 of consolidation loop)
**Date**: 2026-02-05
**Inputs Consumed**: 20+ plan documents across plans_0 through plans_4, from agents sonnet-1, sonnet-2, opus-1, opus-2, composer-1, composer-2, gemini-1 through gemini-7
**Status**: MASTER VERSION

---

## A. Cross-Round Delta Analysis

### Round 0 (5 plans): Fragmentation Discovery
- Identified 47 shortcomings, 90 optimizations, 10 areas of duplicated implementation
- Three competing architectures proposed: Rust Core (sonnet), Go Core (gemini), Protocol-Only (composer/opus)
- Key files analyzed: `internal/tier/detect.go`, `Sources/Services/ModelTierManager.swift`, `internal/orchestrate/orchestrator.go`, `Sources/Agent/AgentExecutor.swift`, `Sources/Services/ContextManager.swift`

### Round 1 (4 plans): First Consolidation
- "CLI-as-Engine" philosophy adopted (from gemini-1)
- Rust core still on the table (from sonnet/composer consolidation)
- 90 optimizations prioritized P0-P4
- 22 Unified Tools defined
- Unified config schema proposed at `~/.obotconfig/config.yaml`

### Round 2: Convergence
- Rust rewrite rejected on risk grounds
- Go Core + Strict Protocols selected as winning hybrid

### Round 3 (8 plans per repo): Refinement
- 6 Unified Protocols formalized: UOP, UTR, UCP, UMC, UC, USF
- Implementation plan counts ranged from 8 to 52 depending on agent
- FINAL_COMPREHENSIVE_ANALYSIS.md (ollamabot) confirmed "unanimous consensus"

### Round 4 (5 files per repo, pre-existing): Stabilization
- consolidated-master-plan-round-4.md established the 13-Plan Strategy
- All agents endorsed "Pragmatic Go Core" with JSON-RPC server
- Implementation plans reduced to 13 atomic units

### What Changed Between Rounds
- DROPPED: Rust rewrite (Round 0-1), deemed too risky
- EVOLVED: Protocol-Only (Round 0) -> Hybrid Protocol+Engine (Round 2+)
- STABILIZED: 6 Protocols, Go Engine + Swift View, 13 Atomic Plans
- GAP IDENTIFIED: 13-plan decomposition targets ~13 agents; user requirement is 40-agent parallelism

---

## B. The Consensus Architecture

All 20+ plans converge on:

- **obot (Go)** becomes the Universal Engine, exposing `obot server` via JSON-RPC over Stdio
- **ollamabot (Swift)** becomes the High-Performance View Layer, communicating exclusively via JSON-RPC
- **6 Unified Protocols** serve as the contract between engine and view

### The 6 Unified Protocols

#### UOP -- Unified Orchestration Protocol
- 5 Schedules: Knowledge, Plan, Implement, Scale, Production
- 3 Processes per schedule with strict 1-2-3 adjacency navigation
- Prompt termination requires all 5 schedules executed, Production last
- Human consultation: optional at Plan/Clarify, mandatory at Implement/Feedback

#### UTR -- Unified Tool Registry
- 22 canonical tools across 6 categories:
  - Core (3): think, complete, ask_user
  - Files (10): read_file, create_file, edit_file, delete_file, create_dir, delete_dir, rename, move, copy, search_files, list_directory
  - System (2): run_command, take_screenshot
  - Delegation (3): delegate_to_coder, delegate_to_researcher, delegate_to_vision
  - Web (2): web_search, fetch_url
  - Git (3): git_status, git_diff, git_commit
- Defined by `tools.schema.json`

#### UCP -- Unified Context Protocol
- Token-budgeted context allocation: Task 25%, Files 35%, Structure 15%, History 15%, Memory 8%, Errors 2%
- Semantic compression for over-budget sections
- Ported from Swift `ContextManager.swift` to Go `pkg/context`

#### UMC -- Unified Model Coordinator
- Hardware-aware tier detection (RAM-based): Minimal, Compact, Balanced, Performance, Advanced, Maximum
- Intent routing: task type -> model role (orchestrator, coder, researcher, vision)
- Merges IDE cloud pricing data with CLI hardware detection

#### UC -- Unified Configuration
- File: `~/.obot/config.yaml` (YAML)
- Scope: Tiers, Models, Quality Presets, Agent Settings, Orchestration, Consultation
- Both products read the same file

#### USF -- Unified State Format
- File: `~/.obot/sessions/{id}.json`
- Scope: Full session persistence including flow code, recurrence relations, checkpoints, notes, stats
- Sessions started in CLI can be resumed in IDE and vice versa

---

## C. Implementation Architecture

### Go Engine (obot)

```
obot/
  cmd/
    obot/main.go          -- CLI entry point (existing)
    server/main.go         -- NEW: JSON-RPC server entry point
  pkg/
    config/                -- UC: YAML config loader + validation
    context/               -- UCP: Token budgeting, semantic compression
    tier/                  -- UMC: Hardware detection, model routing
    tools/                 -- UTR: 22-tool registry with execution
    orchestrator/          -- UOP: 5-schedule state machine, navigation
    session/               -- USF: Persistence, recurrence relations, restore
    server/                -- JSON-RPC handler (initialize, execute, state)
    rules/                 -- .obotrules parser
    mention/               -- @mention system
    judge/                 -- LLM-as-Judge analysis
    consultation/          -- Human consultation framework
    git/                   -- GitHub/GitLab API client
  internal/                -- CLI-specific wiring (thin, delegates to pkg/)
```

### Swift View Layer (ollamabot)

```
Sources/
  Client/
    OBotClient.swift       -- NEW: JSON-RPC client over Stdio
  Views/
    OrchestrationView.swift -- NEW: Wired to RPC session/state
    ConsultationView.swift  -- NEW: Human consultation with timeout
    FlowCodeView.swift      -- NEW: Flow code visualization
    QualityPresetsView.swift-- NEW: fast/balanced/thorough selector
    MemoryView.swift        -- NEW: Memory visualization from RPC
  Services/
    (OllamaService.swift)  -- DELETED after migration
    (ContextManager.swift)  -- DELETED after migration
    (ModelTierManager.swift)-- DELETED after migration
```

---

## D. Agent-to-Agent Meta-Analysis

### Design Tendency Observations

1. **Metaphor-driven prioritization**: Gemini-3 named the context port "Brain Transplant" and it dominated subsequent attention. The RPC server and orchestration state machine (higher engineering risk) received less analysis because they lacked dramatic names.

2. **Consensus by manufactured urgency**: The March deadline appears only in Gemini plans and is not a stated user requirement, yet it was used as the forcing function to reject the Rust alternative.

3. **Relabeling as contribution**: The 6 Unified Protocols in Round 3 are structurally identical to Opus-2's 6 shared contracts from Round 0, renamed with acronyms.

4. **Premature convergence**: By Round 3, agents were writing endorsement and polling-status documents rather than contributing new analysis. Social proof replaced technical merit.

5. **Narrative coherence over operational parallelism**: Every agent gravitated toward fewer, larger plans (8-13) because they read better, despite the user requirement for 40-agent parallelism.

### Unquestioned Assumptions

1. JSON-RPC over Stdio as transport -- no evaluation of gRPC, Unix sockets, or embedded Go
2. The 5-Schedule orchestration model is correct -- nobody validated the current stubbed Go implementation
3. The IDE should become a thin client -- sacrifices SwiftUI native performance for latency-sensitive operations
4. Protocol-Only was dismissed early but is arguably the lowest-risk Phase 1

### Recommended Corrections

1. Keep Protocol-Only as Phase 1: define schemas, add CI validation, deliver interoperability without architectural surgery
2. Make the Go server optional: IDE keeps native Swift paths for completions, streaming chat, file operations
3. Validate orchestration end-to-end in CLI before porting to IDE
4. Define agent decomposition by files and interfaces, not by narratives

---

## E. Success Criteria

1. **Logic centralization**: 100% of context management and orchestration logic lives in Go `pkg/`
2. **Session portability**: `.json` session files open in both CLI and IDE
3. **Config unity**: Both products read `~/.obot/config.yaml`
4. **Swift reduction**: IDE codebase reduced by ~50% (services deleted, replaced by RPC calls)
5. **Tool parity**: 22/22 tools supported in both products
6. **Schema conformance**: CI validates all persistence writes against JSON schemas

---

## F. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| RPC latency degrades IDE UX | High | High | Keep inner loop (completions, streaming) native in Swift |
| Orchestration state machine has undiscovered bugs | Medium | High | Validate end-to-end in CLI before IDE port |
| Schema drift between Go and Swift | Medium | Medium | Golden file tests in CI |
| Migration breaks existing user sessions | Medium | Medium | Auto-migration with backup, feature flags |
| 40-agent parallel work creates merge conflicts | High | Low | File-level ownership boundaries, no shared files |

---

*This is the definitive master plan. See explosion-plan-opus-1.md for the 40-agent decomposition.*
