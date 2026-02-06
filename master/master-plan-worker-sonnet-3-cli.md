# obot CLI Harmonization Master Plan

**Agent:** sonnet-3
**Product:** obot CLI (Go)
**Date:** 2026-02-05
**Status:** Canonical Master — CLI Component

---

## Architecture Role

The CLI is the Execution Engine in the "One Brain, Two Interfaces" model. It provides formal orchestration, session persistence, and fast headless execution while consuming shared behavioral contracts defined by the 6 Unified Protocols.

```
┌──────────────────────────────────────────────┐
│               obot CLI (Go)                  │
│                                              │
│  EXISTING:              NEW:                 │
│  - Orchestrator (5x3)   + Multi-model deleg. │
│  - Agent (12 actions)   + Context manager    │
│  - Tier detection       + Read/search tools  │
│  - FlowCode tracking   + Web search tool     │
│  - Session persistence  + YAML config loader │
│  - Quality presets      + Intent routing     │
│  - Cost tracking        + .obotrules parser  │
│  - Human consultation   + Checkpoint system  │
└──────────────────┬───────────────────────────┘
                   │
                   ▼
        ~/.config/ollamabot/
        ├── config.yaml     (UC)
        ├── schemas/        (UOP, UTR, UCP, USF)
        ├── prompts/
        └── sessions/
```

---

## Critical Code Findings

### agent/agent.go — Write-Only Executor
The CLI agent implements exactly 12 actions:
```
CreateFile, DeleteFile, EditFile, RenameFile, MoveFile, CopyFile,
CreateDir, DeleteDir, RenameDir, MoveDir, CopyDir, RunCommand
```
All are file/directory mutations plus RunCommand. Zero read operations. The fixer engine (fixer/engine.go) reads files and feeds content to the model as context. The agent is an executor only.

This means the "22 unified tools" consensus is wrong for CLI. Tool migration must happen in tiers:
- **Tier 1 (existing):** 12 mutation actions + RunCommand
- **Tier 2 (new):** ReadFile, SearchFiles, ListDirectory
- **Tier 3 (new):** delegate.coder, delegate.researcher, web.search, git.status/diff/commit

### orchestrate/orchestrator.go — Closure-Based State Machine
```go
func (o *Orchestrator) Run(ctx context.Context,
    selectScheduleFn func(context.Context) (ScheduleID, error),
    selectProcessFn func(context.Context, ScheduleID, ProcessID) (ProcessID, bool, error),
    executeProcessFn func(context.Context, ScheduleID, ProcessID) error,
) error
```
Uses Go closure callbacks, not serializable RPC interfaces. Cannot be trivially wrapped as JSON-RPC server. CLI-as-server is deferred to v2.1. IDE must port the state machine natively to Swift.

### config/config.go — Current Config Location
```go
func getConfigDir() string {
    return filepath.Join(homeDir, ".config", "obot")
}
```
Uses ~/.config/obot/config.json. Must migrate to ~/.config/ollamabot/config.yaml with backward-compatible symlink.

### context/summary.go — Basic Context
Simple text-based context building. No token budgeting, no compression, no memory, no learning. Must port IDE's ContextManager logic (token budgets, semantic compression, error pattern learning).

### 27 Internal Packages — Over-Packaged
Current structure has 27 packages. Target: 12 consolidated packages:
- agent/ (executor + actions + recorder)
- cli/ (commands + theme + flags)
- config/ (settings + tier detection + YAML)
- consultation/ (human-in-loop)
- context/ (summary + compression + UCP)
- coordinator/ (NEW: multi-model)
- fixer/ (engine + diff + quality)
- git/ (git operations)
- judge/ (LLM-as-judge)
- ollama/ (client + connection)
- orchestrate/ (orchestrator + schedules + navigator)
- session/ (persistence + stats + USF)

---

## CLI Enhancement Plan (6 Weeks)

### Week 1: Configuration Migration

**Modified Files:**
- `internal/config/config.go` — Replace JSON with YAML (gopkg.in/yaml.v3), change path to ~/.config/ollamabot/

**New Files:**
- `internal/config/migrate.go` — Detect old ~/.config/obot/config.json, convert to YAML, create symlink
- `internal/config/schema.go` — Validate config against JSON Schema (xeipuuv/gojsonschema)

**Deliverables:**
- [ ] CLI reads shared config.yaml
- [ ] Old JSON config auto-migrated
- [ ] Symlink ~/.config/obot/ -> ~/.config/ollamabot/ created
- [ ] Schema validation on load

### Week 2: Context Management + Intent Routing

**New Files:**
- `internal/context/manager.go` (~400 lines) — Token-budget-aware context builder
  ```go
  type ContextManager struct {
      MaxTokens   int
      Budget      TokenBudget  // task:25%, files:33%, project:16%, history:12%, memory:12%, errors:6%
      Compression bool
      Memory      []MemoryEntry
      ErrorPatterns map[string]int
  }

  func (cm *ContextManager) BuildContext(task string, workDir string, steps []Step) *Context
  ```
  Port from IDE's ContextManager.swift: token allocation, semantic compression (preserve imports/signatures/error lines), conversation memory with relevance scoring, error pattern learning.

- `internal/context/compression.go` (~200 lines) — Semantic truncation preserving imports, exports, function signatures, error lines

- `internal/router/intent.go` (~150 lines) — Keyword-based intent classification
  ```go
  type Intent string
  const (
      IntentCoding   Intent = "coding"    // implement, fix, refactor, debug
      IntentResearch Intent = "research"  // what is, explain, compare
      IntentWriting  Intent = "writing"   // write, create, generate
      IntentVision   Intent = "vision"    // image, screenshot, analyze
  )
  func ClassifyIntent(input string) Intent
  ```

**Modified Files:**
- `internal/tier/models.go` — Read tier definitions from shared config instead of hardcoded values

**Deliverables:**
- [ ] Token-budgeted context building working
- [ ] Semantic compression functional
- [ ] Intent routing classifying tasks
- [ ] Tiers read from shared config

### Week 3: Multi-Model Delegation + Read Tools

**New Files:**
- `internal/agent/delegation.go` (~250 lines) — Multi-model delegation
  ```go
  func (a *Agent) DelegateToCoder(ctx context.Context, task string, context string) (string, error)
  func (a *Agent) DelegateToResearcher(ctx context.Context, task string) (string, error)
  ```
  Calls different Ollama models based on role. Uses intent routing to auto-select when model not specified.

**Modified Files:**
- `internal/agent/agent.go` — Add Tier 2 tools:
  - ReadFile(path) — Read and return file contents
  - SearchFiles(query, pattern) — Regex search across codebase
  - ListDirectory(path) — List directory contents
- `internal/model/coordinator.go` — Enhance to support 4 model roles (orchestrator, coder, researcher, vision) with fallback chains

**Deliverables:**
- [ ] Multi-model delegation working
- [ ] Agent can read files (no longer write-only)
- [ ] Agent can search codebase
- [ ] Model coordinator supports 4 roles

### Week 4: Feature Parity (Web, Git, OBot)

**New Files:**
- `internal/tools/web.go` (~200 lines) — DuckDuckGo search integration, URL fetch with content extraction
- `internal/tools/git.go` (~200 lines) — git status, git diff, git commit tools
- `internal/obot/parser.go` (~250 lines) — Parse .obotrules markdown format
  ```go
  type ProjectRules struct {
      Raw         string
      Description string
      CodeStyle   []string
      Patterns    struct { Follow, Avoid []string }
  }
  func ParseOBotRules(projectRoot string) (*ProjectRules, error)
  ```
- `internal/mention/resolver.go` (~200 lines) — @mention resolution
  ```
  @file:path/to/file   -> Include file content
  @context:snippet-id  -> Include context snippet
  @codebase            -> Include project structure
  @bot:bot-name        -> Reference bot definition
  ```

**Modified Files:**
- `internal/fixer/prompts.go` — Include .obotrules content in system prompts
- `internal/cli/root.go` — Add @mention syntax to input parsing

**Deliverables:**
- [ ] Web search tool functional
- [ ] Git tools functional
- [ ] .obotrules parsed and applied
- [ ] @mentions resolved in CLI input

### Week 5: Session Portability + Checkpoints

**New Files:**
- `internal/session/unified.go` (~300 lines) — USF serialization/deserialization
  - Save to ~/.config/ollamabot/sessions/{id}/session.json
  - Validate against USF JSON Schema
  - Include flow code, orchestration state, steps, checkpoints, stats
- `internal/cli/checkpoint.go` (~200 lines) — Checkpoint commands
  ```
  obot checkpoint save "before-refactor"
  obot checkpoint restore "before-refactor"
  obot checkpoint list
  ```

**Modified Files:**
- `internal/session/session.go` — Update to use USF format instead of current format

**Deliverables:**
- [ ] Sessions saved in USF format
- [ ] IDE sessions importable
- [ ] CLI sessions visible in IDE
- [ ] Checkpoint save/restore working

### Week 6: Package Consolidation + Polish

**Package Merges:**
- `internal/actions/` + `internal/fixer/` -> consolidated `internal/agent/`
- `internal/summary/` + `internal/resource/` -> consolidated `internal/context/`
- `internal/oberror/` absorbed into relevant packages
- `internal/fsutil/` absorbed into agent/

**Testing:**
- Integration test: config migration round-trip
- Integration test: session export/import between products
- Integration test: schema validation for all 6 protocols
- Performance benchmark: no regression > 5%

**Deliverables:**
- [ ] 27 packages reduced toward 12
- [ ] All schemas validate
- [ ] Integration tests passing
- [ ] Performance gates met

---

## Success Criteria

### Must-Have for March
- [ ] Shared config.yaml read by CLI
- [ ] Multi-model delegation working
- [ ] Token-budget context management
- [ ] Session format cross-compatible with IDE
- [ ] .obotrules parsed and applied
- [ ] All protocol schemas validated

### Performance Gates
- Config loading: < 50ms overhead
- Session save/load: < 200ms
- Context build: < 500ms for 500-file project
- No regression > 5% in fix speed

### Deferred to v2.1
- CLI JSON-RPC server mode (requires orchestrator refactor)
- Behavioral equivalence test suite
- Interactive migration wizard
- CI/CD pipeline

---

*CLI component of the sonnet-3 canonical master plan.*
