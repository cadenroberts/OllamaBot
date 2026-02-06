# FINAL CONSOLIDATED MASTER PLAN: obot CLI Harmonization
## Agent: opus-2 | Round: 2+ | CLI-Specific View

**Agent:** Claude Opus (opus-2)
**Date:** 2026-02-05
**Scope:** obot CLI (Go/Cobra) harmonization with ollamabot IDE
**Intelligence Source:** 230+ agent contributions across 21 rounds, direct source code analysis
**Status:** FLOW EXIT COMPLETE

---

## Executive Summary

Protocol-first harmonization strategy for the March 2026 release. Shared behavioral contracts (YAML/JSON schemas) between CLI and IDE -- no shared code, no Rust FFI. The CLI implements all protocols natively in Go while reading the same shared configuration and schemas as the IDE.

**Key Decisions:**
1. Protocol-First Architecture -- shared YAML/JSON schemas, NOT shared code
2. Zero Rust for March -- pure Go, no FFI complexity
3. CLI-as-Server is OPTIONAL -- deferred to v2.0 (orchestrator uses closure callbacks, not serializable)
4. XDG-Compliant Config -- `~/.config/ollamabot/config.yaml` with backward-compat symlink from `~/.config/obot/`
5. 6-Week Realistic Timeline -- respects ~7 weeks remaining before March release
6. Tool Tier Migration -- CLI has 12 write-only tools; must add Tier 2 (read/search/delegate) incrementally

---

## CLI Current State

| Metric | Value |
|--------|-------|
| LOC | ~27,114 |
| Files | 61 |
| Packages | 27 |
| Agent Tools | 12 (write-only executor) |
| Models Supported | 1 (per tier) |
| Token Management | None |
| Orchestration | 5-schedule x 3-process (mature) |
| Config Format | JSON at `~/.config/obot/` |
| Session Persistence | Bash scripts |

### Critical Code-Grounded Finding: CLI Agent Is Write-Only

The CLI agent (`internal/agent/agent.go`) implements **12 executor actions**:
```
CreateFile, DeleteFile, EditFile, RenameFile, MoveFile, CopyFile,
CreateDir, DeleteDir, RenameDir, MoveDir, CopyDir, RunCommand
```

The agent has **zero read operations**. The fixer engine (`internal/fixer/engine.go`) reads files and feeds content to the model as context. The agent is an EXECUTOR ONLY.

This means the "22 unified tools" consensus from many plans is incorrect. Tool unification requires a **migration path** with two tiers:
- **Tier 1 (Executor):** File mutations + commands (current CLI capability)
- **Tier 2 (Autonomous):** Read, search, delegate, web, git (needs porting from IDE)

### Critical Code-Grounded Finding: Orchestrator Uses Closures

The CLI orchestrator (`internal/orchestrate/orchestrator.go`) uses **closure-injected callbacks**:
```go
func (o *Orchestrator) Run(ctx context.Context,
    selectScheduleFn func(context.Context) (ScheduleID, error),
    selectProcessFn func(context.Context, ScheduleID, ProcessID) (ProcessID, bool, error),
    executeProcessFn func(context.Context, ScheduleID, ProcessID) error,
) error
```

These are Go function closures, NOT serializable RPC interfaces. Making this a JSON-RPC server requires refactoring all callbacks into request-response pairs, serializing orchestrator state after every step, handling connection drops, and managing concurrent sessions. That is a multi-week rewrite deferred to v2.0.

---

## CLI Architecture: What Changes

### Shared Contracts Layer

The CLI reads shared specifications from `~/.config/ollamabot/`:
```
~/.config/ollamabot/
+-- config.yaml              (UC: Unified Config)
+-- schemas/
|   +-- tools.schema.json    (UTR: Tool Registry)
|   +-- context.schema.json  (UCP: Context Protocol)
|   +-- session.schema.json  (USF: Session Format)
|   +-- orchestration.schema.json (UOP: Orchestration Protocol)
+-- prompts/                 (Shared prompt templates)
+-- sessions/                (Cross-platform sessions)
```

Backward-compat symlink: `~/.config/obot/` -> `~/.config/ollamabot/`

### Agent Architecture (Already Aligned)

CLI already has the DecisionEngine + ExecutionEngine separation:
- `internal/orchestrate/` = DecisionEngine
- `internal/agent/` = ExecutionEngine

---

## 6-Week CLI Implementation Plan

### Week 1: Configuration + Schemas (Foundation)

**CLI File Changes:**
- `internal/config/config.go` -- Replace JSON with YAML, change path from `~/.config/obot/` to `~/.config/ollamabot/`
- `internal/config/migrate.go` -- NEW: Migrate from old JSON config, create backward-compat symlink
- `internal/config/schema.go` -- NEW: Schema validation against JSON Schema

**Current config path** (`internal/config/config.go` line 47):
```go
func getConfigDir() string {
    return filepath.Join(homeDir, ".config", "obot")
}
```

Changes to:
```go
func getConfigDir() string {
    return filepath.Join(homeDir, ".config", "ollamabot")
}
```

With migration creating symlink: `~/.config/obot/` -> `~/.config/ollamabot/`

**Config Schema (v2.0):**
```yaml
# ~/.config/ollamabot/config.yaml
version: "2.0"

platform:
  os: darwin
  arch: arm64
  ram_gb: 32
  detected_tier: performance
  ollama_available: true

models:
  orchestrator:
    primary: "qwen3:32b"
    tier_mapping:
      minimal: "qwen3:8b"
      balanced: "qwen3:14b"
      performance: "qwen3:32b"
  coder:
    primary: "qwen2.5-coder:32b"
    tier_mapping:
      minimal: "deepseek-coder:1.3b"
      compact: "deepseek-coder:6.7b"
      balanced: "qwen2.5-coder:14b"
      performance: "qwen2.5-coder:32b"
  researcher:
    primary: "command-r:35b"
    tier_mapping:
      minimal: "command-r:7b"
      performance: "command-r:35b"
  vision:
    primary: "qwen3-vl:32b"
    tier_mapping:
      minimal: "llava:7b"
      balanced: "llava:13b"
      performance: "qwen3-vl:32b"

quality:
  presets:
    fast:
      pipeline: ["execute"]
      verification: none
      target_time_seconds: 30
    balanced:
      pipeline: ["plan", "execute", "review"]
      verification: llm_review
      target_time_seconds: 180
    thorough:
      pipeline: ["plan", "execute", "review", "revise"]
      verification: expert_judge
      target_time_seconds: 600

context:
  token_limits:
    max_context: 32768
    reserve_response: 4096
    available_input: 28672
  budget_allocation:
    system_prompt: 0.07
    project_rules: 0.04
    task_description: 0.14
    file_content: 0.42
    project_structure: 0.10
    conversation_history: 0.14
    memory_patterns: 0.05
    error_warnings: 0.04

orchestration:
  default_schedules: ["knowledge", "plan", "implement"]
  full_schedules: ["knowledge", "plan", "implement", "scale", "production"]
  navigation_rules:
    within_schedule: "1<->2<->3"
    between_schedules: "any_P3_to_any_P1"
  consultation:
    clarify: {type: optional, timeout_seconds: 60, fallback: assume_best_practice}
    feedback: {type: mandatory, timeout_seconds: 300, fallback: assume_approval}

platforms:
  cli:
    verbose_output: true
    progress_indicators: true
    color_output: true
```

### Week 2: Context Management + Model Coordination

**CLI File Changes:**
- `internal/context/manager.go` -- NEW: Token-budget-aware context builder (port from IDE's ContextManager)
- `internal/context/compression.go` -- NEW: Semantic truncation (preserve imports, signatures, key sections)
- `internal/router/intent.go` -- NEW: Keyword-based intent classification (coding/research/general/vision)
- `internal/tier/models.go` -- Update to read model tier mappings from shared config

**Token counting:** Use pure Go `github.com/pkoukk/tiktoken-go` (no Rust FFI). The bottleneck is Ollama inference (2-10s per call), not token counting.

**Context Manager interface:**
```go
type Manager struct {
    config        Config
    memory        []MemoryEntry
    projectCache  *ProjectCache
    errorPatterns map[string]int
}

func NewManager(cfg Config) *Manager
func (m *Manager) BuildContext(task string, workspace string, files []FileContext) (*UCPContext, error)
func (m *Manager) RecordMemory(entry MemoryEntry)
func (m *Manager) RecordError(err string, ctx string)
```

### Week 3: Multi-Model in CLI

**CLI File Changes:**
- `internal/agent/agent.go` -- Add ReadFile, SearchFiles, ListFiles methods (Tier 2 tools)
- `internal/agent/delegation.go` -- NEW: Multi-model delegation (call different Ollama models per role)
- `internal/model/coordinator.go` -- Enhance to support 4 model roles (orchestrator, coder, researcher, vision)

**Model Coordinator interface:**
```go
type Coordinator struct {
    config  *config.Config
    tier    string
    models  map[ModelRole]string
}

type ModelRole string
const (
    RoleOrchestrator ModelRole = "orchestrator"
    RoleCoder        ModelRole = "coder"
    RoleResearcher   ModelRole = "researcher"
    RoleVision       ModelRole = "vision"
)

func (c *Coordinator) SelectModel(role ModelRole, intent Intent) (string, error)
```

### Week 4: Feature Parity

**CLI File Changes:**
- `internal/tools/web.go` -- NEW: DuckDuckGo search integration
- `internal/tools/git.go` -- NEW: git status/diff/commit tools

### Week 5: Session Format + Integration

**CLI File Changes:**
- `internal/session/unified.go` -- NEW: USF JSON serialization/deserialization
- `internal/cli/checkpoint.go` -- NEW: Checkpoint commands (save, restore, list)
- `internal/session/session.go` -- Update to use USF format alongside existing bash scripts

**USF Schema:**
```json
{
  "version": "1.0",
  "session_id": "sess_20260205_153045",
  "created_at": "2026-02-05T15:30:45Z",
  "source_platform": "cli",
  "task": {
    "description": "Implement JWT authentication",
    "intent": "coding",
    "quality_preset": "balanced"
  },
  "workspace": {
    "path": "/Users/dev/project",
    "git_branch": "feature/auth"
  },
  "orchestration_state": {
    "flow_code": "S1P123S2P12",
    "current_schedule": "implement",
    "current_process": 2,
    "completed_schedules": ["knowledge", "plan"]
  },
  "conversation_history": [],
  "files_modified": [],
  "checkpoints": []
}
```

### Week 6: Polish + Documentation + Release

**Deliverables:**
1. User migration guide (how to update from old config)
2. Protocol specification documentation
3. Integration test suite (schema compliance + session portability)
4. Performance validation (no regression > 5%)
5. Release build and packaging

---

## CLI Enhancement Plans (C-01 through C-10)

- **C-01:** YAML Config Migration (replace JSON, symlink)
- **C-02:** Context Manager (port from IDE)
- **C-03:** Semantic Compression
- **C-04:** Intent Router
- **C-05:** Multi-Model Coordinator (4 roles)
- **C-06:** Multi-Model Delegation Tools
- **C-07:** Read/Search/List Tools (Tier 2)
- **C-08:** Web Search Tool
- **C-09:** Git Tools (status, diff, commit)
- **C-10:** Checkpoint System

---

## Success Criteria (CLI)

### Must-Have for March Release
- [ ] Shared `config.yaml` read by CLI (replacing JSON)
- [ ] CLI has multi-model delegation
- [ ] CLI has token-budget context management
- [ ] CLI has read/search tools (Tier 2 migration started)
- [ ] Session format is cross-compatible (file-based USF)
- [ ] All 6 protocol schemas defined and validated
- [ ] Backward-compat symlink from `~/.config/obot/`

### Performance Gates
- No regression > 5%
- Config loading: < 50ms additional overhead
- Session save/load: < 200ms
- Context build time: < 500ms for 500-file project

---

## Consensus

All agents agreed on:
1. Protocol-first over code-sharing
2. Feature parity goal
3. Phased, backward-compatible approach
4. Session portability
5. 5-schedule orchestration as canonical model
6. Shared YAML configuration

Resolved disagreements:
- CLI-as-Server: **Deferred to v2.0** (orchestrator uses closures, not serializable)
- Rust FFI: **Zero Rust** (bottleneck is inference, not counting)
- Config Location: **XDG-compliant** `~/.config/ollamabot/` with symlink
- Tool Count: **Two tiers** (12 executor + 18 autonomous, migrate incrementally)
- Timeline: **6 weeks** (March deadline non-negotiable)

---

*Agent: Claude Opus (opus-2) | CLI Master Plan | FLOW EXIT COMPLETE*
