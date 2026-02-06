# MASTER PLAN: obot CLI Harmonization
## Agent: opus-2 | Final Consolidation | March 2026 Release

---

## Executive Summary

This is the CLI-specific master plan for harmonizing obot (Go CLI) with OllamaBot (Swift/macOS IDE) into a unified product ecosystem. It covers all CLI enhancements, refactoring, and protocol adoption required for the March 2026 release.

**Architecture:** Protocol-First -- shared YAML/JSON behavioral contracts, zero shared code, independent Go implementation.

---

## Part 1: CLI Current State

| Metric | Value |
|--------|-------|
| LOC | ~27,114 |
| Files | 61 |
| Packages | 27 |
| Agent Actions | 12 (write-only) |
| Models | 1 (per RAM tier) |
| Token Management | None |
| Orchestration | 5-schedule x 3-process |
| Config | JSON at `~/.config/obot/` |
| Session Persistence | Bash scripts |

**Key Strengths:**
- Formal 5-schedule orchestration framework (Knowledge, Plan, Implement, Scale, Production)
- Quality presets (fast/balanced/thorough)
- Cost savings tracking vs commercial APIs
- Session persistence with bash-only restoration
- Human consultation with AI fallback (60s timeout)
- Flow code tracking (S1P123S2P12...)
- Line-range editing (-start +end)
- Diff/dry-run/print modes

**Key Gaps:**
- Agent is write-only (12 actions, no read/search/web/git/delegation)
- Single model per operation (no multi-model coordination)
- No token-budgeted context management
- No intent-based model routing
- No .obotrules support
- No @mention system
- No checkpoint system
- Orchestration partially stubbed (process execution sleeps/logs without real tool execution)
- 27 packages is excessive (should be ~12)

---

## Part 2: The 6 Protocols (CLI Perspective)

### UC -- Unified Configuration
- **CLI Action:** Migrate from JSON to YAML at `~/.config/ollamabot/config.yaml`
- **Backward compat:** Symlink `~/.config/obot/` -> `~/.config/ollamabot/`
- **Library:** `gopkg.in/yaml.v3`
- **Migration:** Auto-detect old JSON config, convert, create symlink

### UTR -- Unified Tool Registry
- **CLI Action:** Expand agent from 12 write-only actions to include Tier 2 tools
- **Tier 1 (existing):** CreateFile, DeleteFile, EditFile, RenameFile, MoveFile, CopyFile, CreateDir, DeleteDir, RenameDir, MoveDir, CopyDir, RunCommand
- **Tier 2 (new):** ReadFile, SearchFiles, ListFiles, DelegateToCoder, DelegateToResearcher, DelegateToVision, WebSearch, FetchURL, GitStatus, GitDiff, GitCommit, Think, Complete, AskUser

### UCP -- Unified Context Protocol
- **CLI Action:** NEW `internal/context/manager.go` porting IDE's token budget system
- **Budget allocation:** system_prompt 7%, project_rules 4%, task 14%, files 42%, project 10%, history 14%, memory 5%, errors 4%
- **Features:** Semantic truncation, conversation memory, error pattern learning
- **Library:** `github.com/pkoukk/tiktoken-go` for token counting

### UOP -- Unified Orchestration Protocol
- **CLI Action:** Fix stubbed orchestration -- replace sleep/log with real tool execution
- **Already has:** 5-schedule state machine, navigation rules, flow code tracking
- **Fix needed:** `internal/cli/orchestrate.go` and `internal/agent/agent.go` stubs

### USF -- Unified Session Format
- **CLI Action:** NEW `internal/session/unified.go` for JSON session read/write
- **Enable:** Session export compatible with IDE import
- **Retain:** Existing bash restore scripts as fallback

### UMC -- Unified Model Coordinator
- **CLI Action:** Expand from single-model to 4-model coordination
- **Roles:** orchestrator, coder, researcher, vision
- **Tier mapping:** Read from shared config.yaml per-role
- **Intent routing:** NEW keyword-based classification

---

## Part 3: CLI Implementation Plans (C-01 through C-10)

### C-01: YAML Config Migration
- **Modify:** `internal/config/config.go` -- Replace JSON with YAML, change path
- **New file:** `internal/config/migrate.go` -- Auto-migration from old JSON
- **New file:** `internal/config/schema.go` -- Schema validation
- **Library:** `gopkg.in/yaml.v3`
- **Priority:** P0 | **Effort:** Small | **Week:** 1

### C-02: Context Manager (Port from IDE)
- **New file:** `internal/context/manager.go`
- **Purpose:** Token-budget-aware context builder
- **Port from:** IDE's `ContextManager.swift` (behavioral port)
- **Features:** Budget allocation, priority-based pruning, memory
- **Priority:** P0 | **Effort:** Large | **Week:** 2

### C-03: Semantic Compression
- **New file:** `internal/context/compression.go`
- **Purpose:** Smart truncation preserving imports, signatures, key sections
- **Strategy:** Remove function bodies first, then comments, then whitespace
- **Priority:** P1 | **Effort:** Medium | **Week:** 2

### C-04: Intent Router
- **New file:** `internal/router/intent.go`
- **Purpose:** Keyword-based intent classification
- **Intents:** coding (implement, fix, refactor), research (what is, explain), general (write, help), vision (image, screenshot)
- **Priority:** P0 | **Effort:** Medium | **Week:** 2

### C-05: Multi-Model Coordinator (4 Roles)
- **Modify:** `internal/model/coordinator.go`
- **Purpose:** Support orchestrator, coder, researcher, vision model roles
- **Read:** Per-role tier mappings from shared config
- **Fallback:** Auto-select based on available RAM
- **Priority:** P0 | **Effort:** Medium | **Week:** 3

### C-06: Multi-Model Delegation Tools
- **New file:** `internal/agent/delegation.go`
- **Purpose:** delegate_to_coder, delegate_to_researcher, delegate_to_vision
- **Mechanism:** Call different Ollama models per role with task-specific prompts
- **Priority:** P0 | **Effort:** Large | **Week:** 3

### C-07: Read/Search/List Tools (Tier 2)
- **Modify:** `internal/agent/agent.go`
- **Add:** ReadFile, SearchFiles, ListFiles methods
- **Purpose:** Agent can now read the codebase autonomously (not just write)
- **Priority:** P0 | **Effort:** Medium | **Week:** 3

### C-08: Web Search Tool
- **New file:** `internal/tools/web.go`
- **Purpose:** DuckDuckGo search integration
- **Implementation:** HTTP GET to DuckDuckGo HTML, parse results
- **Priority:** P1 | **Effort:** Medium | **Week:** 4

### C-09: Git Tools
- **New file:** `internal/tools/git.go`
- **Purpose:** git status, diff, commit as agent tools
- **Implementation:** Shell out to git binary, parse output
- **Priority:** P1 | **Effort:** Medium | **Week:** 4

### C-10: Checkpoint System
- **New file:** `internal/cli/checkpoint.go`
- **Commands:** `obot checkpoint save`, `obot checkpoint restore`, `obot checkpoint list`
- **Storage:** `~/.config/ollamabot/sessions/{session_id}/checkpoints/`
- **Priority:** P2 | **Effort:** Medium | **Week:** 5

---

## Part 4: CLI Refactoring

### Package Consolidation (27 -> 12)

**Current (27 packages):**
```
internal/actions, internal/agent, internal/analyzer, internal/cli,
internal/color, internal/config, internal/context, internal/diff,
internal/fixer, internal/git, internal/model, internal/monitor,
internal/oberror, internal/ollama, internal/orchestrate, internal/planner,
internal/resource, internal/review, internal/session, internal/stats,
internal/summary, internal/tier, internal/tools, internal/ui,
internal/version, internal/web, cmd/obot
```

**Target (12 packages):**
```
internal/
  agent/         (executor + actions + recorder + delegation)
  cli/           (commands + theme + flags)
  config/        (settings + tier detection + shared YAML)
  consultation/  (human-in-loop)
  context/       (summary + compression + UCP)
  fixer/         (engine + diff + quality + analyzer)
  git/           (git operations)
  judge/         (LLM-as-judge)
  ollama/        (client + model coordination + routing)
  orchestrate/   (orchestrator + schedules + navigator)
  session/       (persistence + stats + recovery)
  ui/            (display + memory viz + ANSI)
```

**Merge plan:**
- `actions` -> `agent`
- `analyzer` -> `fixer`
- `oberror` -> stdlib errors
- `model` -> `ollama`
- `resource` -> `monitor` -> `ui`
- `stats` -> `session`
- `summary` -> `context`
- `tier` -> `config`
- `tools` + `web` -> new `tools/` or inline into `agent`

### Fix Stubbed Orchestration (CRITICAL)
- **File:** `internal/cli/orchestrate.go`
- **Problem:** Process execution sleeps and logs without real tool execution
- **Fix:** Wire `executeProcessFn` callback to actual agent tool execution
- **Depends on:** C-06 (delegation) and C-07 (read tools) completing first

---

## Part 5: Success Criteria (CLI)

### Must-Have for March
- [ ] Reads shared `config.yaml` from `~/.config/ollamabot/`
- [ ] Backward-compat symlink from `~/.config/obot/`
- [ ] Multi-model delegation (4 roles)
- [ ] Token-budgeted context management
- [ ] Intent-based model routing
- [ ] Read/search tools (Tier 2 migration)
- [ ] Orchestration executes real tools (not stubs)
- [ ] Session export in USF format

### Performance Gates
- CLI startup: <50ms
- Config loading: <50ms additional overhead
- Context build: <500ms for 500-file project
- Session save/load: <200ms
- No regression >5% in fix speed

### Quality Gates
- All schemas validate against JSON Schema
- Session round-trip (export -> import) preserves all data
- Config migration preserves all existing settings
- Orchestration produces valid flow codes

---

## Part 6: File Change Summary

### New Files (11)
| File | Purpose | Week |
|------|---------|------|
| `internal/config/migrate.go` | JSON->YAML migration | 1 |
| `internal/config/schema.go` | Schema validation | 1 |
| `internal/context/manager.go` | Token-budget context | 2 |
| `internal/context/compression.go` | Semantic truncation | 2 |
| `internal/router/intent.go` | Intent classification | 2 |
| `internal/agent/delegation.go` | Multi-model delegation | 3 |
| `internal/tools/web.go` | Web search | 4 |
| `internal/tools/git.go` | Git tools | 4 |
| `internal/session/unified.go` | USF serialization | 5 |
| `internal/cli/checkpoint.go` | Checkpoint commands | 5 |
| `.obotrules` | Project rules support | 3 |

### Modified Files (5)
| File | Change | Week |
|------|--------|------|
| `internal/config/config.go` | JSON->YAML, new path | 1 |
| `internal/tier/models.go` | Read from shared config | 2 |
| `internal/model/coordinator.go` | 4-role support | 3 |
| `internal/agent/agent.go` | Add Tier 2 tools | 3 |
| `internal/cli/orchestrate.go` | Fix stubs, real execution | 3 |

---

## Part 7: CLI-Specific Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Context manager port complexity | Medium | High | Start Week 2, allow overflow into Week 3 |
| Orchestration stub fix cascading | Medium | High | Fix after delegation tools land |
| YAML migration breaks existing users | Low | High | Auto-migrate + symlink + keep JSON fallback |
| 27->12 package merge conflicts | Medium | Medium | Do incrementally, not all at once |
| Multi-model RAM pressure | Medium | Medium | Only load active model, swap on delegate |

---

*Agent: Claude Opus (opus-2) | CLI Master Plan | FLOW EXIT COMPLETE*
