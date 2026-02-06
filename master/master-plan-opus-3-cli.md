# Master Plan: opus-3 -- CLI Harmonization (obot)

**Agent:** Claude Opus (opus-3)
**Round:** 2
**Date:** 2026-02-05
**Product:** obot CLI (Go/Cobra)
**Status:** MASTER VERSION

---

## 1. Architecture Consensus

After 138+ polls observing 94 plan files from 5 agent families (sonnet, opus, composer, gemini, gpt), all agents converged on:

**"Engine & Cockpit"** -- obot CLI (Go) serves as execution engine; ollamabot IDE (Swift) serves as visualization layer. Both products share behavioral contracts through JSON/YAML schemas. Neither shares compiled code.

This architecture was originated by opus-1 and universally adopted. It was later refined by sonnet-3, who proved that the CLI-as-JSON-RPC-server variant was premature for the March release window due to the orchestrator's closure-based callback structure.

---

## 2. The 6 Unified Protocols

All master plans in `plans_2` referenced these protocols:

| # | Protocol | Abbrev | Purpose |
|---|----------|--------|---------|
| 1 | Agent Execution Protocol | AEP | Tool call/result format, execution flow |
| 2 | Orchestration Protocol | OP | 5 schedules x 3 processes, navigation rules, flow codes |
| 3 | Context Management Protocol | CMP | Token budgets, semantic compression, memory, error learning |
| 4 | Tool Registry Specification | TRS | 22 standardized tools with aliases and platform markers |
| 5 | Configuration Schema | CS | Shared `~/.config/ollamabot/config.yaml` |
| 6 | Session Format | SF | Cross-platform session portability (JSON) |

---

## 3. CLI-Specific Implementation Plans

### CLI Core Improvements (C-01 through C-10)

| Plan | Title | Priority | Effort | Dependencies |
|------|-------|----------|--------|--------------|
| C-01 | Package Consolidation (27 to 12) | P1 | Large | None |
| C-02 | Multi-Model Coordinator | P0 | Medium | P-05 |
| C-03 | Intent-Based Routing | P1 | Small | C-02 |
| C-04 | Context Manager Implementation | P0 | Large | P-03 |
| C-05 | OBot Integration (.obotrules) | P1 | Medium | P-05 |
| C-06 | Web Tools (search, fetch) | P2 | Small | P-04 |
| C-07 | AI Delegation Tools | P1 | Medium | C-02, P-04 |
| C-08 | Tool Registry Loader | P0 | Small | P-04 |
| C-09 | Configuration Loader (YAML) | P0 | Small | P-05 |
| C-10 | Git Tools (status, diff, commit) | P2 | Small | P-04 |

### CLI Server Mode (S-01 through S-07) -- DEFERRED TO v2.0

| Plan | Title | Priority | Status |
|------|-------|----------|--------|
| S-01 | HTTP Server Infrastructure | P0 | DEFERRED |
| S-02 | Agent Execute API Endpoint | P0 | DEFERRED |
| S-03 | Orchestration API Endpoints | P1 | DEFERRED |
| S-04 | Context API Endpoints | P1 | DEFERRED |
| S-05 | Session API Endpoints | P1 | DEFERRED |
| S-06 | WebSocket Streaming | P0 | DEFERRED |
| S-07 | Server Mode Configuration | P1 | DEFERRED |

**Reason for deferral:** sonnet-3 demonstrated that `internal/orchestrate/orchestrator.go` uses closure-injected Go function callbacks (`selectScheduleFn`, `selectProcessFn`, `executeProcessFn`). These are not serializable into JSON-RPC request-response pairs without a multi-week rewrite of the most critical CLI component. This is incompatible with the ~7-week March release window.

### CLI Enhancements (from consensus)

The following features were identified as missing from the CLI and needed for March parity:

1. **Multi-Model Coordinator** -- Support 4 model roles (orchestrator, coder, researcher, vision) with tier-based fallbacks. Currently CLI uses 1 model per tier.

2. **Context Manager** -- Port IDE's token-budgeted context management to Go. Budget: task 25%, files 33%, project 16%, conversation 12%, memory 12%, errors 6%. Use `github.com/pkoukk/tiktoken-go` for token counting (zero Rust FFI).

3. **Tier 2 Tool Migration** -- The CLI agent (`internal/agent/agent.go`) currently has 12 write-only executor actions. Add read capabilities:
   - `file.read` -- Read file contents
   - `file.search` -- Search files by content/pattern
   - `dir.list` -- List directory contents
   - `web.search` -- DuckDuckGo integration
   - `web.fetch` -- URL content retrieval
   - `git.status`, `git.diff`, `git.commit` -- Git operations
   - `delegate.coder`, `delegate.researcher`, `delegate.vision` -- Multi-model delegation

4. **YAML Configuration** -- Migrate from `~/.config/obot/config.json` to `~/.config/ollamabot/config.yaml`. Create backward-compat symlink from `~/.config/obot/`. Implement migration tool that detects old JSON config, converts to YAML, creates symlink.

5. **OBot System Support** -- Parse `.obotrules` files for project-specific AI rules, code style, and patterns.

6. **Intent Routing** -- Keyword-based intent classification (coding/research/general/vision) to auto-select model role.

### CLI Package Consolidation

Reduce from 27 packages to 12:
- Merge `actions` into `agent`
- Merge `analyzer` into `fixer`
- Merge `model` into `ollama`
- Merge `tier` into `config`
- Consolidate scattered utility packages

### CLI Configuration Migration

Specific file changes:
- `internal/config/config.go` -- Replace JSON with YAML, change path to `~/.config/ollamabot/`
- `internal/config/migrate.go` -- NEW: Detect old `config.json`, convert to YAML, create backward-compat symlink
- `internal/config/schema.go` -- NEW: Validate config against JSON Schema

### CLI Context Manager (New)

Specific file changes:
- `internal/context/manager.go` -- NEW: Token-budget-aware context builder (~500 LOC port from IDE)
- `internal/context/compression.go` -- NEW: Semantic truncation preserving imports, signatures, key sections

### CLI Multi-Model Delegation (New)

Specific file changes:
- `internal/agent/delegation.go` -- NEW: Call different Ollama models per role
- `internal/model/coordinator.go` -- Enhance to support 4 model roles
- `internal/router/intent.go` -- NEW: Keyword-based intent classification

---

## 4. Critical Path for CLI

```
Protocol Schemas (P-01..P-06) [Week 1]
    |
    +--> Config Migration C-09 [Week 1]
    |
    +--> Context Manager C-04 [Week 2, largest effort]
    |
    +--> Multi-Model C-02, C-03 [Week 2-3, parallel with C-04]
    |
    +--> Tier 2 Tools C-06, C-07, C-10 [Week 3-4]
    |
    +--> Package Consolidation C-01 [Week 4]
    |
    +--> OBot Integration C-05 [Week 4]
    |
    +--> Session Format [Week 5]
    |
    +--> Testing T-01, T-04 [Week 6]
```

---

## 5. Key Findings from Comparative Analysis

### What Sonnet Saw That Affected CLI Plans

1. **CLI agent is write-only.** `internal/agent/agent.go` implements 12 executor actions: CreateFile, DeleteFile, EditFile, RenameFile, MoveFile, CopyFile, CreateDir, DeleteDir, RenameDir, MoveDir, CopyDir, RunCommand. Zero read operations. The fixer engine reads files and feeds content to the model. A Tier 2 migration is required to add read/search/web/git/delegation tools.

2. **Orchestrator closure callbacks.** `internal/orchestrate/orchestrator.go`'s `Run()` method takes closure-injected `func` parameters. These cannot be trivially wrapped in JSON-RPC. Server mode deferred to v2.0.

3. **Config path is `~/.config/obot/`.** The actual code at `internal/config/config.go` line 47 uses this path. Migration to `~/.config/ollamabot/` with backward-compat symlink.

4. **Zero Rust for March.** Token counting uses pure Go (`github.com/pkoukk/tiktoken-go`). The bottleneck is Ollama inference at 2-10 seconds, not counting at 5ms.

### What Opus Got Right for CLI

1. **Engine & Cockpit framing** -- The CLI is the "Engine." Its existing orchestration framework (5-schedule x 3-process) is the canonical model that the IDE ports to Swift.

2. **Package consolidation** -- 27 packages to 12. The CLI is over-packaged for its current complexity.

3. **Protocol enumeration** -- Clean definitions that the CLI validates against using `github.com/xeipuuv/gojsonschema`.

---

## 6. Verification

- [x] CLI-specific plans enumerated (C-01..C-10, S-01..S-07 deferred)
- [x] Tier 2 tool migration path defined (12 write-only to 22+ read-write)
- [x] Configuration migration path specified with exact file changes
- [x] Context manager port scoped (~500 LOC)
- [x] Server mode explicitly deferred with code-grounded justification
- [x] Package consolidation targets identified
- [x] Dependency chain mapped
- [x] 6-week timeline fits March 2026 release

---

**MASTER VERSION COMPLETE -- CLI**

*Agent: Claude Opus (opus-3) | 2026-02-05*
