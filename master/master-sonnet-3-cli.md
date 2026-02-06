# THE DEFINITIVE HARMONIZATION PLAN — CLI
## obot (Go) Implementation Scope

**Agent:** sonnet-3
**Round:** 2+ (Competitive Final)
**Date:** 2026-02-05
**Scope:** CLI-specific changes required for harmonization with OllamaBot IDE

---

## ARCHITECTURE: Protocol-Native, Zero Shared Code

The CLI reads shared contracts from `~/.config/ollamabot/` and implements all logic natively in Go. No Rust FFI. No JSON-RPC server mode (deferred to v2.1). The CLI remains a standalone tool.

```
~/.config/ollamabot/
├── config.yaml              (UC: Unified Config)
├── schemas/
│   ├── tools.schema.json    (UTR)
│   ├── context.schema.json  (UCP)
│   ├── session.schema.json  (USF)
│   └── orchestration.schema.json (UOP)
├── prompts/                 (Shared prompt templates)
└── sessions/                (Cross-platform sessions)
```

---

## CRITICAL FINDINGS FROM SOURCE CODE

### Finding 1: The Agent Is Write-Only

`internal/agent/agent.go` implements exactly 12 actions:

```
CreateFile, DeleteFile, EditFile, RenameFile, MoveFile, CopyFile,
CreateDir, DeleteDir, RenameDir, MoveDir, CopyDir, RunCommand
```

There are ZERO read operations. The agent cannot read files, search, or query git. The fixer engine (`internal/fixer/engine.go`) handles all reads and feeds content to the model as context before the agent runs.

This means the tool gap is not a naming problem — it is an architectural gap. The agent needs new capabilities in two tiers:
- **Tier 1 (existing):** File mutations + commands
- **Tier 2 (new):** Read, search, delegate, web, git

### Finding 2: The Orchestrator Uses Closure Callbacks

`internal/orchestrate/orchestrator.go` line 480:

```go
func (o *Orchestrator) Run(ctx context.Context,
    selectScheduleFn func(context.Context) (ScheduleID, error),
    selectProcessFn func(context.Context, ScheduleID, ProcessID) (ProcessID, bool, error),
    executeProcessFn func(context.Context, ScheduleID, ProcessID) error,
) error
```

These are Go closures injected at runtime, not serializable interfaces. Making this a JSON-RPC server would require refactoring ALL callbacks into request-response pairs — a multi-week rewrite. This is why the "CLI as Engine" proposals from other agents are premature for March.

### Finding 3: Config Uses JSON at ~/.config/obot/

`internal/config/config.go` line 47:

```go
func getConfigDir() string {
    return filepath.Join(homeDir, ".config", "obot")
}
```

The current config format is JSON with these fields: tier, model, auto_detect_tier, ollama_url, verbose, temperature, max_tokens. Migration to YAML at the new shared path is straightforward.

### Finding 4: No Token Budgeting in Context

`internal/context/summary.go` builds context as plain text concatenation. No token counting, no budget allocation, no compression. The IDE's ContextManager with its 25/33/16/12/12/6 budget split is far more sophisticated.

### Finding 5: 27 Internal Packages Is Over-Packaged

The CLI has packages for: actions, agent, analyzer, cli, config, consultation, context, fixer, fsutil, index, judge, model, monitor, oberror, obotgit, ollama, orchestrate, planner, resource, review, session, stats, summary, tier, ui, version. Many of these are thin wrappers. Target consolidation to ~12 packages.

---

## CLI CHANGES BY WEEK

### Week 1: Configuration Migration

**Modified Files:**
- `internal/config/config.go` — Replace JSON parsing with YAML (`gopkg.in/yaml.v3`). Change path from `~/.config/obot/config.json` to `~/.config/ollamabot/config.yaml`. Expand Config struct to include all shared fields (models, quality, context, orchestration sections).

**New Files:**
- `internal/config/migrate.go` — On first run: detect `~/.config/obot/config.json`, read it, convert to YAML Config struct, write to new path, create symlink `~/.config/obot/` -> `~/.config/ollamabot/` for backward compatibility.
- `internal/config/schema.go` — Load and validate JSON schemas from `~/.config/ollamabot/schemas/`. Validate config.yaml against config schema on load.

**Behavior:**
- `obot` command reads new YAML config
- All existing CLI flags continue to work as overrides
- Old config.json is migrated automatically, original preserved as backup

### Week 2: Context Management (Biggest Quality Improvement)

**New Files:**
- `internal/context/manager.go` — Port IDE's ContextManager logic to Go:
  - Token budget allocation: task 25%, files 33%, project 16%, history 12%, memory 12%, errors 6%
  - Token counting via `github.com/pkoukk/tiktoken-go` (pure Go, no FFI)
  - File relevance scoring: explicit mentions > recently modified > import relationships > git diff context
  - Semantic compression: preserve imports, exports, class/function signatures, error comments. Truncate method bodies.

- `internal/context/compression.go` — Compression strategies:
  - `semantic_truncation`: Keep file structure, remove implementation details
  - `summary`: For very large files, keep first 50 + last 20 lines + signature outline
  - Priority: selected code > open/mentioned files > project structure > history

- `internal/router/intent.go` — Keyword-based intent classification ported from IDE's IntentRouter:
  - coding: implement, fix, refactor, debug, optimize, test, code
  - research: what, why, how, explain, compare, research, find
  - writing: write, document, create, draft, generate
  - vision: image, screenshot, analyze, describe, visual
  - Default: coding

**Modified Files:**
- `internal/tier/models.go` — Read model tier mappings from shared config.yaml instead of hardcoded Go map. Fall back to hardcoded values if config unavailable.
- `internal/fixer/engine.go` — Use new context manager for building prompts instead of basic text concatenation.

### Week 3: Multi-Model Delegation + Agent Tier 2 Tools

**New Files:**
- `internal/agent/delegation.go` — Multi-model delegation support:
  - `DelegateToCoder(ctx, task, files)` — Call coder model (qwen2.5-coder) with code-focused context
  - `DelegateToResearcher(ctx, query)` — Call researcher model (command-r) with research-focused context
  - `DelegateToVision(ctx, task, imagePath)` — Call vision model (qwen3-vl) with image data
  - Model selection respects tier mappings from shared config

**Modified Files:**
- `internal/agent/agent.go` — Add Tier 2 tool methods:
  - `ReadFile(ctx, path) (string, error)` — Read and return file contents
  - `SearchFiles(ctx, query, scope) ([]SearchResult, error)` — Grep/ripgrep wrapper for content search
  - `ListDirectory(ctx, path) ([]DirEntry, error)` — List directory contents
  - `GitStatus(ctx) (string, error)` — Run git status
  - `GitDiff(ctx, path) (string, error)` — Run git diff
  - `WebSearch(ctx, query) ([]SearchResult, error)` — DuckDuckGo search

- `internal/model/coordinator.go` — Enhance to support 4 model roles (orchestrator, coder, researcher, vision). Select model per role using tier mapping from config. Support intent-based routing when not in orchestration mode.

- `internal/ollama/client.go` — Add methods for calling different models by role. Support concurrent model calls for delegation.

### Week 4: Feature Parity (Remaining Gaps)

**New Files:**
- `internal/tools/web.go` — DuckDuckGo HTML search integration. Parse results into structured format. Cache results for 5 minutes.
- `internal/tools/git.go` — Git tool implementations: status, diff, commit, log. Thin wrappers around git CLI with structured output parsing.

**Modified Files:**
- `internal/fixer/quality.go` — Ensure quality presets read from shared config. Add "expert" preset that triggers full 5-schedule orchestration.
- `internal/cli/root.go` — Add `obot chat` command for interactive multi-turn mode (matches IDE chat experience).

### Week 5: Session Portability

**New Files:**
- `internal/session/unified.go` — USF (Unified Session Format) implementation:
  - Serialize session state to JSON matching `session.schema.json`
  - Include: orchestration state, flow code, action history, context snapshot, checkpoints, consultation history, token stats
  - Write to `~/.config/ollamabot/sessions/{id}.json`
  - Generate `restore.sh` bash script alongside JSON for CLI-only restoration

- `internal/cli/checkpoint.go` — Checkpoint commands:
  - `obot checkpoint save [name]` — Snapshot current file states + git state
  - `obot checkpoint restore [id]` — Restore files from checkpoint
  - `obot checkpoint list` — List available checkpoints
  - Checkpoints stored in USF format for IDE compatibility

**Modified Files:**
- `internal/session/session.go` — Update to write USF format instead of custom format. Maintain backward compatibility: read old format, write new format.
- `internal/cli/session.go` — Add `obot session export` and `obot session import` commands. Enable resuming IDE sessions from CLI.

### Week 6: Polish and Release

- Integration tests: config migration, session round-trip, schema validation
- Performance validation: no startup regression > 5%, context building < 500ms for 500-file project
- Package consolidation: merge thin wrapper packages where practical
- Documentation: updated README, migration guide, CLI help text updates

---

## SUCCESS CRITERIA (CLI)

### Must-Have for March
- [ ] Reads `~/.config/ollamabot/config.yaml` on launch
- [ ] Auto-migrates old `~/.config/obot/config.json` on first run
- [ ] Token-budget context management (25/33/16/12/12/6 allocation)
- [ ] Multi-model delegation (coder, researcher, vision)
- [ ] Intent-based model routing
- [ ] Agent has Tier 2 tools (read, search, git, web)
- [ ] Session export in USF format
- [ ] Session import from IDE USF files
- [ ] Checkpoint save/restore/list commands

### Performance Gates
- Config loading: < 50ms additional overhead
- Context building: < 500ms for 500-file project
- Session save/load: < 200ms
- No startup regression > 5%
- Token counting: < 10ms per file (pure Go tiktoken)

### Quality Gates
- Config migration preserves all existing settings
- Session export/import round-trips with IDE successfully
- All JSON schemas pass validation
- Intent routing matches IDE keyword classification
- Orchestration session state is portable to IDE
