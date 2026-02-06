# Master Plan: obot CLI Harmonization
## opus-2 | CLI-Specific Implementation

**Agent:** Claude Opus (opus-2)
**Date:** 2026-02-05
**Product:** obot CLI (Go)
**Round:** 2 (plans_2)
**Status:** FLOW EXIT COMPLETE

---

## Architecture

Protocol-native, zero shared code. CLI implements behavioral contracts natively in Go. Shared schemas at `~/.config/ollamabot/` define the behavioral contracts that both CLI and IDE conform to independently.

---

## 6 Core Protocols

| Protocol | Abbrev | Format | Location |
|----------|--------|--------|----------|
| Unified Configuration | UC | YAML | `~/.config/ollamabot/config.yaml` |
| Unified Tool Registry | UTR | JSON Schema | `~/.config/ollamabot/schemas/tools.schema.json` |
| Unified Context Protocol | UCP | JSON Schema | `~/.config/ollamabot/schemas/context.schema.json` |
| Unified Orchestration Protocol | UOP | JSON Schema | `~/.config/ollamabot/schemas/orchestration.schema.json` |
| Unified Session Format | USF | JSON Schema | `~/.config/ollamabot/schemas/session.schema.json` |
| Unified Model Coordinator | UMC | YAML (in config) | Part of `config.yaml` models section |

---

## CLI Current State

| Metric | Value |
|--------|-------|
| LOC | ~27,114 |
| Files | 61 |
| Packages | 27 |
| Agent Tools | 12 (write-only) |
| Models Supported | 1 (per tier) |
| Token Management | None |
| Orchestration | 5-schedule x 3-process (canonical) |
| Config Format | JSON at `~/.config/obot/` |
| Session Persistence | Bash scripts |

---

## CLI Enhancements (10 Plans)

### C-01: YAML Config Migration
- **File:** `internal/config/config.go` (UPDATE)
- **File:** `internal/config/migrate.go` (NEW)
- **File:** `internal/config/schema.go` (NEW)
- Replace JSON with YAML, change path to `~/.config/ollamabot/`
- Detect old `~/.config/obot/config.json`, convert, create backward-compat symlink
- Schema validation against JSON Schema

### C-02: Context Manager (port from IDE)
- **File:** `internal/context/manager.go` (NEW)
- Port IDE's ContextManager token budgeting to Go
- Token budget allocation: system 7%, project rules 4%, task 14%, files 42%, structure 10%, history 14%, memory 5%, errors 4%
- Use pure Go (`github.com/pkoukk/tiktoken-go`), zero Rust FFI

### C-03: Semantic Compression
- **File:** `internal/context/compression.go` (NEW)
- Preserve imports, function signatures, type definitions, error handling, critical comments
- Semantic truncation strategy matching IDE's compression logic

### C-04: Intent Router
- **File:** `internal/router/intent.go` (NEW)
- Keyword-based intent classification: coding, research, general, vision
- Port from IDE's IntentRouter

### C-05: Multi-Model Coordinator (4 roles)
- **File:** `internal/model/coordinator.go` (UPDATE)
- Enhance to support 4 model roles: orchestrator, coder, researcher, vision
- Read tier mappings from shared config
- RAM-tier detection already exists; add intent routing on top

### C-06: Multi-Model Delegation Tools
- **File:** `internal/agent/delegation.go` (NEW)
- `delegate_to_coder`, `delegate_to_researcher`, `delegate_to_vision`
- Call different Ollama models per role

### C-07: Read/Search/List Tools (Tier 2)
- **File:** `internal/agent/agent.go` (UPDATE)
- Add ReadFile, SearchFiles, ListFiles methods
- Tier 2 autonomous tools -- CLI agent transitions from write-only to read-write

### C-08: Web Search Tool
- **File:** `internal/tools/web.go` (NEW)
- DuckDuckGo search integration

### C-09: Git Tools
- **File:** `internal/tools/git.go` (NEW)
- git status, diff, commit tools

### C-10: Checkpoint System
- **File:** `internal/cli/checkpoint.go` (NEW)
- `obot checkpoint save/restore/list` commands
- Persist using USF format

---

## CLI File Changes by Week

### Week 1
- `internal/config/config.go` -- UPDATE: YAML instead of JSON, new path
- `internal/config/migrate.go` -- NEW: legacy migration + symlink
- `internal/config/schema.go` -- NEW: JSON Schema validation

### Week 2
- `internal/context/manager.go` -- NEW: token-budget context builder
- `internal/context/compression.go` -- NEW: semantic truncation
- `internal/router/intent.go` -- NEW: intent classification
- `internal/tier/models.go` -- UPDATE: read from shared config

### Week 3
- `internal/agent/agent.go` -- UPDATE: add Tier 2 tools (read/search/list)
- `internal/agent/delegation.go` -- NEW: multi-model delegation
- `internal/model/coordinator.go` -- UPDATE: 4 model roles

### Week 4
- `internal/tools/web.go` -- NEW: DuckDuckGo integration
- `internal/tools/git.go` -- NEW: git tools

### Week 5
- `internal/session/unified.go` -- NEW: USF serialization
- `internal/cli/checkpoint.go` -- NEW: checkpoint commands
- `internal/session/session.go` -- UPDATE: USF format alongside bash scripts

### Week 6
- Integration testing and documentation

---

## Code-Grounded Insights (CLI-Specific)

1. **CLI agent is write-only.** `internal/agent/agent.go` implements 12 executor actions: CreateFile, DeleteFile, EditFile, RenameFile, MoveFile, CopyFile, CreateDir, DeleteDir, RenameDir, MoveDir, CopyDir, RunCommand. It cannot read files itself. The fixer engine reads files and feeds content as context.

2. **Orchestrator uses closure callbacks.** `internal/orchestrate/orchestrator.go` accepts Go function closures (`func(context.Context) (ScheduleID, error)`). These are not serializable over RPC. JSON-RPC server mode requires multi-week refactoring, deferred to v2.0.

3. **Config lives at `~/.config/obot/`.** `internal/config/config.go` line 47: `filepath.Join(homeDir, ".config", "obot")`. Migration creates symlink from old path to new `~/.config/ollamabot/`.

4. **Token counting is not bottlenecked.** CLI does not count tokens at all. Ollama inference (2-10 seconds per call) is the actual bottleneck. Pure Go tiktoken is sufficient.

5. **CLI has 27 packages.** Target reduction to ~12 packages: consolidate actions->agent, analyzer->fixer, model->ollama, tier->config.

6. **CLI has canonical orchestration.** The 5-schedule x 3-process framework in `internal/orchestrate/` is the reference implementation that IDE ports from.

---

## Tool Tier Migration

The CLI agent must transition from Tier 1 (write-only) to Tier 2 (autonomous):

**Tier 1 (Executor) -- Current CLI:**
- File mutations: CreateFile, DeleteFile, EditFile, RenameFile, MoveFile, CopyFile
- Directory mutations: CreateDir, DeleteDir, RenameDir, MoveDir, CopyDir
- System: RunCommand

**Tier 2 (Autonomous) -- To Add:**
- Read: ReadFile, ListFiles
- Search: SearchFiles (regex, glob)
- Delegation: delegate_to_coder, delegate_to_researcher, delegate_to_vision
- Web: web_search, web_fetch
- Git: git_status, git_diff, git_commit
- Planning: think

---

## Success Criteria (CLI)

- [ ] YAML config at `~/.config/ollamabot/` with migration from old JSON
- [ ] Multi-model delegation (4 roles)
- [ ] Token-budget context management
- [ ] Read/search tools (Tier 2 migration started)
- [ ] Web search and git tools
- [ ] Checkpoint system
- [ ] Session format cross-compatible (USF)
- [ ] No regression > 5% in existing functionality
- [ ] Package count reduced toward ~12

---

## Provenance

Distilled from `~/ollamabot/plans_2/FINAL-CONSOLIDATED-MASTER-opus-2.md`. That document synthesized 230+ agent contributions across 21 consolidation rounds with direct source code analysis.

---

*Agent: Claude Opus (opus-2) | CLI Master Plan*
