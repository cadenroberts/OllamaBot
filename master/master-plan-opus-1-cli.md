# ITERATION-2 FINAL MASTER PLAN — CLI (obot)

**Agent**: opus-1
**Round**: 4 (Iteration 2 of consolidation loop)
**Date**: 2026-02-05
**Scope**: obot CLI (Go)
**Inputs Consumed**: 20+ plan documents across plans_0 through plans_4, from agents sonnet-1, sonnet-2, opus-1, opus-2, composer-1, composer-2, gemini-1 through gemini-7
**Status**: MASTER VERSION

---

## A. Cross-Round Delta Analysis

### Round 0 (5 plans): Fragmentation Discovery
- Identified 47 shortcomings, 90 optimizations, 10 areas of duplicated implementation
- Three competing architectures proposed: Rust Core (sonnet), Go Core (gemini), Protocol-Only (composer/opus)
- Key CLI files analyzed: internal/tier/detect.go, internal/orchestrate/orchestrator.go, internal/fixer/agent.go, internal/cli/root.go, internal/session/session.go, internal/ollama/client.go

### Round 1 (4 plans): First Consolidation
- "CLI-as-Engine" philosophy adopted (from gemini-1)
- Rust core still on the table (from sonnet/composer consolidation)
- 90 optimizations prioritized P0-P4
- 22 Unified Tools defined

### Round 2: Convergence
- Rust rewrite rejected on risk grounds
- Go Core + Strict Protocols selected as winning hybrid

### Round 3 (8 plans per repo): Refinement
- 6 Unified Protocols formalized: UOP, UTR, UCP, UMC, UC, USF
- Implementation plan counts ranged from 8 to 52 depending on agent

### Round 4 (pre-existing + opus-1): Stabilization
- consolidated-master-plan-round-4.md established the 13-Plan Strategy
- All agents endorsed "Pragmatic Go Core" with JSON-RPC server
- opus-1 expanded to 40-agent decomposition for parallel execution

### What Changed Between Rounds
- DROPPED: Rust rewrite (Round 0-1), deemed too risky
- EVOLVED: Protocol-Only (Round 0) -> Hybrid Protocol+Engine (Round 2+)
- STABILIZED: 6 Protocols, Go Engine + Swift View, 13 -> 40 Atomic Plans

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

## D. CLI-Specific Architecture Changes

### What the CLI Gains
1. **Token-budgeted context** — Ported from Swift ContextManager; replaces simple text summary
2. **Intent routing** — Automatic model selection based on task type, not just tier
3. **.obotrules support** — CLI respects project-level AI rules
4. **@mention system** — @file, @folder, @codebase, @context, @bot, @git syntax in CLI input
5. **22-tool registry** — Adds web search, delegation, vision tools that CLI currently lacks
6. **JSON-RPC server mode** — `obot server` exposes all engine functionality for IDE consumption
7. **LLM-as-Judge** — Multi-expert analysis with TLDR synthesis at session end
8. **Full GitHub/GitLab integration** — Repository creation, PR/MR, auto-push on completion

### What the CLI Restructures
- `internal/` packages move to `pkg/` for reusability
- CLI-specific wiring stays in `internal/cli/`
- New `cmd/server/` entry point for JSON-RPC mode

### New CLI Directory Structure

```
obot/
  cmd/
    obot/main.go              — Existing CLI entry point
    server/main.go            — NEW: JSON-RPC server entry point
  pkg/
    config/
      loader.go               — YAML config loader + validation
      schema.go               — Schema conformance checking
      migrate.go              — Legacy config migration
    context/
      manager.go              — Token budgeting engine
      budget.go               — Budget allocation logic
      compress.go             — Semantic compression
    tier/
      detect.go               — Cross-platform RAM detection
      models.go               — Tier-to-model mapping
      router.go               — Intent-based model routing
    tools/
      think.go                — Internal reasoning tool
      complete.go             — Process completion signal
      ask_user.go             — User input with timeout
      file_read.go            — File read
      file_create.go          — File create with auto-mkdir
      file_edit.go            — Search-and-replace editing
      file_delete.go          — File deletion
      file_list.go            — Directory listing
      file_search.go          — Text search (ripgrep-style)
      file_rename.go          — Rename file/dir
      file_move.go            — Move file/dir
      file_copy.go            — Copy file/dir
      dir_create.go           — Create directory
      dir_delete.go           — Delete directory
      run_command.go           — Shell command execution
      screenshot.go            — Screenshot capture
      delegate_coder.go        — Delegate to coder model
      delegate_researcher.go   — Delegate to researcher model
      delegate_vision.go       — Delegate to vision model
      web_search.go            — DuckDuckGo search
      fetch_url.go             — HTTP GET with content extraction
      git_status.go            — Git status
      git_diff.go              — Git diff
      git_commit.go            — Git commit
    orchestrator/
      orchestrator.go          — 5-schedule state machine
      navigator.go             — 1-2-3 process navigation
      terminator.go            — Prompt termination logic
    session/
      session.go               — USF persistence
      recurrence.go            — State recurrence relations (BFS)
      restore.go               — Restore script generation
      migrate.go               — Legacy session migration
    server/
      handler.go               — JSON-RPC 2.0 handler
      methods.go               — RPC method implementations
      transport.go             — Stdio transport layer
    rules/
      parser.go                — .obotrules markdown parser
      loader.go                — Rules file discovery + loading
    mention/
      parser.go                — @mention syntax parser
      resolver.go              — Mention-to-content resolution
    judge/
      coordinator.go           — Multi-expert analysis orchestration
      expert.go                — Individual expert analysis
      synthesis.go             — Orchestrator TLDR synthesis
    consultation/
      handler.go               — Human consultation framework
      timeout.go               — 60s timeout + 15s countdown
      substitute.go            — AI substitute generation
    git/
      manager.go               — Git operation coordinator
      github.go                — GitHub API client
      gitlab.go                — GitLab API client
  internal/
    cli/                       — CLI-specific wiring (thin, delegates to pkg/)
```

---

## E. CLI Agent Assignments (From 40-Agent Explosion)

The following agents are CLI-scoped:

| Agent | Plan | Owns | Est. Lines |
|-------|------|------|-----------|
| A04 | CORE-REFACTOR | pkg/core/, cmd restructure | ~600 |
| A05 | CONFIG-GO | pkg/config/ (loader, schema, migrate) | ~400 |
| A06 | TIER-GO | pkg/tier/ (detect, models, router) | ~500 |
| A07 | CONTEXT-GO | pkg/context/ (manager, budget, compress) | ~700 |
| A08 | SESSION-GO | pkg/session/ (session, recurrence, restore) | ~600 |
| A09 | ORCHESTRATOR-GO | pkg/orchestrator/ (orchestrator, navigator, terminator) | ~800 |
| A10 | TOOLS-CORE | pkg/tools/ (think, complete, ask_user) | ~200 |
| A11 | TOOLS-FILE-CRUD | pkg/tools/ (read, create, edit, delete) | ~350 |
| A12 | TOOLS-FILE-MGMT | pkg/tools/ (list, search, rename, move, copy, dirs) | ~450 |
| A13 | TOOLS-SYSTEM | pkg/tools/ (run_command, screenshot) | ~200 |
| A14 | TOOLS-DELEGATION | pkg/tools/ (delegate_coder/researcher/vision) | ~300 |
| A15 | TOOLS-WEB | pkg/tools/ (web_search, fetch_url) | ~300 |
| A16 | TOOLS-GIT | pkg/tools/ (git_status, git_diff, git_commit) | ~250 |
| A17 | RPC-SERVER | pkg/server/, cmd/server/ | ~600 |
| A18 | OBOTRULES-GO | pkg/rules/ (parser, loader) | ~300 |
| A19 | MENTION-GO | pkg/mention/ (parser, resolver) | ~400 |
| A20 | JUDGE-GO | pkg/judge/ (coordinator, expert, synthesis) | ~500 |
| A21 | CONSULTATION-GO | pkg/consultation/ (handler, timeout, substitute) | ~350 |
| A22 | GIT-INTEGRATION | pkg/git/ (manager, github, gitlab) | ~500 |
| A34 | SESSION-MIGRATION | pkg/session/migrate.go | ~250 |

**Total new Go**: ~7,850 lines
**Total moved (internal -> pkg)**: ~2,000 lines

---

## F. Success Criteria (CLI-Specific)

1. `go build ./...` passes with new pkg/ structure
2. `go test ./...` passes with >70% coverage on pkg/
3. `obot server` starts and responds to JSON-RPC `initialize` call
4. All 22 tools execute via both CLI and RPC paths
5. Token-budgeted context produces output within budget for 32K window
6. Orchestration state machine rejects P1->P3 navigation, accepts P1->P2
7. Prompt termination blocked until all 5 schedules have run
8. .obotrules parsed and injected into system prompts
9. @mention syntax resolves @file:main.go to file content
10. Session round-trips through save/load with correct flow code
11. Config migration converts legacy JSON to unified YAML
12. LLM-as-Judge produces structured TLDR with scores

---

## G. Risk Register (CLI-Specific)

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| pkg/ refactor breaks existing CLI commands | High | High | Keep internal/cli/ as thin wrapper; comprehensive integration tests |
| Orchestration state machine has undiscovered bugs | Medium | High | Validate end-to-end before IDE port; navigation rule unit tests |
| Context port from Swift introduces semantic drift | Medium | Medium | Golden tests comparing Go output to Swift reference output |
| RPC server Stdio transport limits concurrency | Medium | Medium | Single-request pipelining initially; evaluate multiplexing if needed |
| Legacy config migration loses user settings | Low | High | Back up originals to ~/.obot/legacy/; dry-run mode for migration |
| 22-tool registry increases attack surface | Low | Medium | Sandbox run_command; validate all file paths against project root |

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
3. Protocol-Only was dismissed early but remains the lowest-risk Phase 1 option

---

*This is the definitive CLI master plan. See explosion-plan-opus-1.md for the full 40-agent decomposition.*
