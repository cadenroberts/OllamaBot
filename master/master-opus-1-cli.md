# obot CLI Master Plan — Protocol-First Harmonization

**Agent:** opus-1
**Product:** obot CLI (Go)
**Date:** 2026-02-05
**Architecture:** Protocol-First with CLI as Engine, IDE as Cockpit

---

## Executive Summary

obot CLI becomes the canonical execution engine ("Engine") in a harmonized two-product architecture. The CLI retains its native Go strengths — orchestration state machine, tier detection, session persistence, cost tracking — while gaining context management, multi-model delegation, and read/search tools ported from the IDE. A new `obot server` mode exposes all capabilities via JSON-RPC for IDE consumption.

---

## Part 1: Current CLI State (Source-Grounded)

### Codebase Statistics
- **LOC:** ~27,114
- **Files:** 61 Go files
- **Packages:** 27 (recommended reduction to ~12)
- **Agent Tools:** 12 (write-only executor actions)
- **Models Supported:** 1 per tier (tier-selected coder only)
- **Token Management:** None
- **Orchestration:** Full 5-schedule x 3-process state machine
- **Config:** JSON at `~/.config/obot/config.json`
- **Session Persistence:** Bash scripts with flow code

### Key Files

| File | LOC | Role |
|------|-----|------|
| `internal/orchestrate/orchestrator.go` | ~580 | 5-schedule x 3-process state machine |
| `internal/agent/agent.go` | ~400 | Write-only executor (12 actions) |
| `internal/fixer/engine.go` | ~350 | File reader, context feeder |
| `internal/ollama/client.go` | ~300 | Ollama API client (non-streaming) |
| `internal/config/config.go` | ~200 | JSON config at `~/.config/obot/` |
| `internal/tier/detect.go` | ~150 | RAM-based model tier detection |
| `internal/summary/summary.go` | ~250 | Basic file listing for context |

### What CLI Has That IDE Lacks
1. **5-schedule orchestration** — Knowledge/Plan/Implement/Scale/Production
2. **3-process navigation** — Strict P1↔P2↔P3 with flow code tracking
3. **Human consultation** — Timeout with AI fallback (clarify=optional, feedback=mandatory)
4. **Session persistence** — Bash restoration scripts, flow code in manifest
5. **Cost tracking** — Token savings vs commercial API calculations
6. **Tier detection** — Automatic RAM-based model tier selection (minimal/compact/balanced/performance/advanced)

### What CLI Lacks That IDE Has
1. **Context management** — No token budgeting, no compression, no memory, no error learning
2. **Multi-model delegation** — Only 1 model (coder), no orchestrator/researcher/vision roles
3. **Read/search tools** — Agent is write-only (12 executor actions, zero read capabilities)
4. **External API support** — No Claude/GPT/Gemini routing
5. **Streaming** — Non-streaming requests only
6. **Parallel tool execution** — Sequential only, no caching
7. **Web search** — No web tools
8. **Git tools** — No git status/diff/commit integration

### Critical Discovery: Agent Is Write-Only

The CLI agent (`internal/agent/agent.go`) implements exactly 12 actions:
```
CreateFile, DeleteFile, EditFile, RenameFile, MoveFile, CopyFile,
CreateDir, DeleteDir, RenameDir, MoveDir, CopyDir, RunCommand
```

The agent CANNOT read files. The fixer engine (`internal/fixer/engine.go`) reads files and feeds content to the model as context. This is a fundamental architectural difference from the IDE agent which has full read-write capabilities.

### Critical Discovery: Orchestrator Uses Closures

The orchestrator's `Run()` method uses closure-injected callbacks:
```go
func (o *Orchestrator) Run(ctx context.Context,
    selectScheduleFn func(context.Context) (ScheduleID, error),
    selectProcessFn func(context.Context, ScheduleID, ProcessID) (ProcessID, bool, error),
    executeProcessFn func(context.Context, ScheduleID, ProcessID) error,
) error
```

These are Go function closures, NOT serializable RPC interfaces. Making this a JSON-RPC server requires refactoring all callbacks into request-response pairs. This is a multi-week effort deferred to post-March v2.0.

---

## Part 2: Architecture — CLI as Engine

```
┌─────────────────────────────────────────────────────────────┐
│                    obot CLI (Go)                             │
│                    "The Engine"                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐  ┌─────────────────────────────────┐  │
│  │  CLI Interface   │  │  Server Interface (v2.0)        │  │
│  │  (Cobra commands)│  │  (JSON-RPC over stdio)          │  │
│  └────────┬────────┘  └──────────┬──────────────────────┘  │
│           └──────────────────────┤                          │
│                                  ▼                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Orchestrator (5×3 State Machine)          │  │
│  │  Schedule: Knowledge → Plan → Implement → Scale → Prod│  │
│  │  Process:  P1 ↔ P2 ↔ P3                              │  │
│  │  FlowCode: S1P123S2P12S3P123S4P123S5P123             │  │
│  └───────────────────────┬───────────────────────────────┘  │
│                          │                                  │
│  ┌───────────┐  ┌───────┴───────┐  ┌───────────────────┐  │
│  │  Context   │  │  Model        │  │  Agent Engine     │  │
│  │  Manager   │  │  Coordinator  │  │                   │  │
│  │  (NEW)     │  │  (Enhanced)   │  │  Tier 1: Write    │  │
│  │            │  │               │  │  Tier 2: Read/Srch│  │
│  │  Token     │  │  4 Roles:     │  │  Tier 3: Web/Git  │  │
│  │  Budget    │  │  Orchestrator │  │  Tier 4: Delegate  │  │
│  │  Compress  │  │  Coder        │  │                   │  │
│  │  Memory    │  │  Researcher   │  │                   │  │
│  │  Errors    │  │  Vision       │  │                   │  │
│  └───────────┘  └───────────────┘  └───────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Shared Config (YAML)                      │  │
│  │  ~/.config/ollamabot/config.yaml                      │  │
│  │  + symlink ~/.config/obot/ → ~/.config/ollamabot/     │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Part 3: Unified Protocols — CLI Implementation

### 3.1 Unified Configuration (UC)

**Current:** JSON at `~/.config/obot/config.json`
**Target:** YAML at `~/.config/ollamabot/config.yaml`

**CLI Implementation:**
- MODIFY: `internal/config/config.go` — Replace JSON with YAML, change path
- NEW: `internal/config/migrate.go` (~200 LOC) — Detect old JSON, convert, create symlink
- NEW: `internal/config/schema.go` (~150 LOC) — Validate against JSON Schema

```go
// internal/config/config.go (modified)
func getConfigDir() string {
    // Primary: XDG-compliant shared path
    primary := filepath.Join(homeDir, ".config", "ollamabot")
    
    // Backward compat symlink
    legacy := filepath.Join(homeDir, ".config", "obot")
    if _, err := os.Lstat(legacy); os.IsNotExist(err) {
        os.Symlink(primary, legacy)
    }
    
    return primary
}

type UnifiedConfig struct {
    Version       string              `yaml:"version"`
    Models        ModelConfig         `yaml:"models"`
    Ollama        OllamaConfig        `yaml:"ollama"`
    Quality       QualityConfig       `yaml:"quality"`
    Orchestration OrchestrationConfig `yaml:"orchestration"`
    Agent         AgentConfig         `yaml:"agent"`
    Context       ContextConfig       `yaml:"context"`
    Sessions      SessionConfig       `yaml:"sessions"`
    CLI           CLIConfig           `yaml:"cli"`
}
```

### 3.2 Unified Tool Registry (UTR)

**Current:** 12 write-only actions
**Target:** 22+ tools across 4 tiers

**Tool Migration Path:**

| Tier | Tools | Status |
|------|-------|--------|
| Tier 1 (Executor) | CreateFile, DeleteFile, EditFile, RenameFile, MoveFile, CopyFile, CreateDir, DeleteDir, RenameDir, MoveDir, CopyDir, RunCommand | EXISTING |
| Tier 2 (Read/Search) | file.read, file.search, dir.list | NEW — Week 3 |
| Tier 3 (Web/Git) | web.search, web.fetch, git.status, git.diff, git.commit | NEW — Week 4 |
| Tier 4 (Delegation) | delegate.coder, delegate.researcher, delegate.vision | NEW — Week 3 |

**CLI Implementation:**
- MODIFY: `internal/agent/agent.go` — Add ReadFile, SearchFiles, ListFiles methods
- NEW: `internal/agent/delegation.go` (~300 LOC) — Multi-model delegation
- NEW: `internal/tools/web.go` (~200 LOC) — DuckDuckGo search
- NEW: `internal/tools/git.go` (~250 LOC) — Git operations

### 3.3 Unified Orchestration Protocol (UOP)

**CLI already has the canonical orchestration implementation.** Changes needed:
- Validate state transitions against UOP JSON Schema
- Export flow code in standardized format
- Ensure navigation rules match protocol spec exactly

### 3.4 Unified Context Protocol (UCP)

**This is the largest new capability for CLI.**

- NEW: `internal/context/manager.go` (~500 LOC)
- NEW: `internal/context/compression.go` (~200 LOC)
- NEW: `internal/context/memory.go` (~200 LOC)
- NEW: `internal/context/errors.go` (~150 LOC)

Port from IDE's `ContextManager.swift`:

```go
// internal/context/manager.go
package context

type Manager struct {
    config        ContextConfig
    memory        *Memory
    errorPatterns map[string]*ErrorPattern
    cache         *lru.Cache
    rules         *ProjectRules
}

type TokenBudget struct {
    Total     int
    Allocated map[SectionType]int
    Used      map[SectionType]int
}

type SectionType string

const (
    SectionTask         SectionType = "task"
    SectionFileContent  SectionType = "file_content"
    SectionStructure    SectionType = "project_structure"
    SectionConversation SectionType = "conversation"
    SectionMemory       SectionType = "memory"
    SectionErrors       SectionType = "errors"
)

func NewManager(config ContextConfig) *Manager {
    budget := &TokenBudget{
        Total: config.MaxTokens,
        Allocated: map[SectionType]int{
            SectionTask:         int(float64(config.MaxTokens) * config.Budget.Task),
            SectionFileContent:  int(float64(config.MaxTokens) * config.Budget.FileContent),
            SectionStructure:    int(float64(config.MaxTokens) * config.Budget.Structure),
            SectionConversation: int(float64(config.MaxTokens) * config.Budget.Conversation),
            SectionMemory:       int(float64(config.MaxTokens) * config.Budget.Memory),
            SectionErrors:       int(float64(config.MaxTokens) * config.Budget.Errors),
        },
    }
    // ...
}

func (m *Manager) BuildOrchestratorContext(task string, workDir string, steps []Step) *OrchestratorContext
func (m *Manager) BuildDelegationContext(model ModelRole, task string, ctx string, files map[string]string) *DelegationContext
func (m *Manager) CompressCode(code string, maxTokens int) string
func (m *Manager) RecordMemory(entry MemoryEntry)
func (m *Manager) RecordError(err string, context string)
```

**Compression strategy (port from IDE):**
```go
// internal/context/compression.go
func (m *Manager) CompressCode(code string, maxTokens int) string {
    lines := strings.Split(code, "\n")
    if estimateTokens(code) <= maxTokens {
        return code
    }
    
    // Keep: imports, exports, function signatures, error lines
    // Remove: function bodies, comments, blank lines
    // Preserve: first 33% and last 67% (configurable ratios)
    
    var preserved []string
    for i, line := range lines {
        if isImport(line) || isExport(line) || isFunctionSignature(line) || isErrorLine(line) {
            preserved = append(preserved, line)
        } else if i < len(lines)/3 || i > len(lines)*2/3 {
            preserved = append(preserved, line)
        }
    }
    
    result := strings.Join(preserved, "\n")
    if estimateTokens(result) > maxTokens {
        // Further truncate from middle
        result = truncateMiddle(result, maxTokens)
    }
    return result
}
```

### 3.5 Unified Model Coordinator (UMC)

**Current:** Single model (tier-selected coder)
**Target:** 4 model roles with intent routing

- NEW: `internal/model/coordinator.go` enhanced (~400 LOC)
- NEW: `internal/router/intent.go` (~200 LOC) — Keyword-based intent classification

```go
// internal/model/coordinator.go
type Coordinator struct {
    models   map[ModelRole]*ollama.Client
    warmup   map[string]bool
    tierMgr  *TierManager
    mu       sync.RWMutex
}

type ModelRole string

const (
    RoleOrchestrator ModelRole = "orchestrator"
    RoleCoder        ModelRole = "coder"
    RoleResearcher   ModelRole = "researcher"
    RoleVision       ModelRole = "vision"
)

func NewCoordinator(config ModelConfig, tierMgr *TierManager) *Coordinator {
    tier := tierMgr.DetectTier()
    return &Coordinator{
        models: map[ModelRole]*ollama.Client{
            RoleOrchestrator: ollama.NewClient(config.Orchestrator.TierMapping[tier]),
            RoleCoder:        ollama.NewClient(config.Coder.TierMapping[tier]),
            RoleResearcher:   ollama.NewClient(config.Researcher.TierMapping[tier]),
            RoleVision:       ollama.NewClient(config.Vision.TierMapping[tier]),
        },
    }
}

func (c *Coordinator) DelegateTo(ctx context.Context, role ModelRole, task string) (string, error) {
    client := c.models[role]
    // Build context appropriate for role
    // Send request
    // Return response
}
```

### 3.6 Unified Session Format (USF)

**Current:** Bash scripts
**Target:** JSON matching USF schema + backward-compat bash scripts

- NEW: `internal/session/unified.go` (~250 LOC) — USF JSON serialization
- NEW: `internal/cli/checkpoint.go` (~200 LOC) — Checkpoint commands
- MODIFY: `internal/session/session.go` — Use USF format alongside existing bash

```go
// internal/session/unified.go
type UnifiedSession struct {
    Version       string                `json:"version"`
    Session       SessionInfo           `json:"session"`
    Orchestration OrchestrationState    `json:"orchestration"`
    Context       json.RawMessage       `json:"context"`
    Actions       []ActionRecord        `json:"actions"`
    Checkpoints   []Checkpoint          `json:"checkpoints"`
    Consultation  ConsultationHistory   `json:"consultation"`
    Stats         SessionStats          `json:"stats"`
}

func NewSession(prompt string, platform string) *UnifiedSession
func (s *UnifiedSession) Save(path string) error
func LoadSession(path string) (*UnifiedSession, error)
func ListSessions(dir string) ([]*UnifiedSession, error)
func (s *UnifiedSession) AddAction(action ActionRecord)
func (s *UnifiedSession) AddCheckpoint(cp Checkpoint)
```

---

## Part 4: Package Consolidation

**Current:** 27 packages (over-packaged)
**Target:** ~12 focused packages

| Current Packages | Consolidated Into |
|-----------------|-------------------|
| `internal/agent/` | `internal/agent/` (keep, expand with Tier 2-4 tools) |
| `internal/orchestrate/` | `internal/orchestrate/` (keep) |
| `internal/config/` | `internal/config/` (keep, migrate to YAML) |
| `internal/ollama/` | `internal/ollama/` (keep) |
| `internal/fixer/` + `internal/summary/` | `internal/context/` (merge into new context manager) |
| `internal/tier/` | `internal/model/` (merge into model coordinator) |
| `internal/session/` | `internal/session/` (keep, add USF) |
| `internal/cli/` | `internal/cli/` (keep) |
| NEW | `internal/router/` (intent routing) |
| NEW | `internal/tools/` (web, git) |
| NEW (v2.0) | `internal/rpc/` (JSON-RPC server) |

---

## Part 5: Implementation Timeline (CLI Track)

### Week 1: Configuration Migration
- `internal/config/config.go` — Replace JSON with YAML, new path
- `internal/config/migrate.go` — Legacy JSON detection, conversion, symlink
- `internal/config/schema.go` — Schema validation

### Week 2: Context Manager (Highest Leverage)
- `internal/context/manager.go` — Token-budget-aware context builder
- `internal/context/compression.go` — Semantic truncation
- `internal/context/memory.go` — Conversation memory with pruning
- `internal/context/errors.go` — Error pattern learning

### Week 3: Multi-Model + Read Tools
- `internal/model/coordinator.go` — 4-role model coordinator
- `internal/router/intent.go` — Intent classification
- `internal/agent/agent.go` — Add ReadFile, SearchFiles, ListFiles
- `internal/agent/delegation.go` — Delegation tools

### Week 4: Web/Git Tools + Feature Parity
- `internal/tools/web.go` — DuckDuckGo search
- `internal/tools/git.go` — Git status/diff/commit
- Validate orchestration against UOP schema

### Week 5: Session Format + Integration
- `internal/session/unified.go` — USF implementation
- `internal/cli/checkpoint.go` — Checkpoint commands
- Cross-platform session tests

### Week 6: Polish + Documentation
- Package consolidation (27 → 12)
- Integration test suite
- Performance benchmarks
- Release build

---

## Part 6: File Change Manifest

### New Files (12)

| File | LOC | Week |
|------|-----|------|
| `internal/config/migrate.go` | ~200 | 1 |
| `internal/config/schema.go` | ~150 | 1 |
| `internal/context/manager.go` | ~500 | 2 |
| `internal/context/compression.go` | ~200 | 2 |
| `internal/context/memory.go` | ~200 | 2 |
| `internal/context/errors.go` | ~150 | 2 |
| `internal/model/coordinator.go` | ~400 | 3 |
| `internal/router/intent.go` | ~200 | 3 |
| `internal/agent/delegation.go` | ~300 | 3 |
| `internal/tools/web.go` | ~200 | 4 |
| `internal/tools/git.go` | ~250 | 4 |
| `internal/session/unified.go` | ~250 | 5 |
| `internal/cli/checkpoint.go` | ~200 | 5 |

### Modified Files (4)

| File | Changes | Week |
|------|---------|------|
| `internal/config/config.go` | YAML migration, new path, symlink | 1 |
| `internal/agent/agent.go` | Add Tier 2 read/search tools | 3 |
| `internal/tier/models.go` | Read from shared config | 3 |
| `internal/session/session.go` | USF format support | 5 |

**Total: ~3,200 new LOC + ~500 modified LOC**

---

## Part 7: Server Mode (v2.0 — Post-March)

Deferred due to orchestrator closure-callback barrier. Planned for v2.0:

```go
// internal/rpc/server.go (v2.0)
type Server struct {
    orchestrator *orchestrate.Orchestrator
    agent        *agent.Agent
    context      *context.Manager
    coordinator  *model.Coordinator
    sessions     *session.Manager
}

// JSON-RPC methods:
// - startTask(task, context) -> session_id
// - getState(session_id) -> orchestration_state
// - cancelTask(session_id) -> ok
// - listSessions() -> sessions[]
// - restoreSession(session_id) -> ok

// Events (streaming):
// - tool_call(tool, params)
// - tool_result(tool, result)
// - model_response(chunk)
// - schedule_change(schedule, process)
// - consultation_request(question, timeout)
```

**Prerequisites for v2.0:**
1. Refactor orchestrator callbacks into request-response pairs
2. Serialize orchestrator state for connection recovery
3. Handle concurrent sessions
4. Add event streaming over stdio

---

## Part 8: Success Criteria

### Must-Have for March
- [ ] YAML config at `~/.config/ollamabot/` with symlink from `~/.config/obot/`
- [ ] Token-budget context manager operational
- [ ] Multi-model coordinator with 4 roles
- [ ] Read/search tools added to agent (Tier 2)
- [ ] Web search and git tools (Tier 3)
- [ ] USF session format with export/import
- [ ] All protocol schemas validated

### Performance Gates
- Config loading: < 50ms additional overhead
- Context build time: < 500ms for 500-file project
- Session save/load: < 200ms
- No regression > 5% in existing operations

### Quality Gates
- All JSON schemas pass validation
- Session export/import round-trips with IDE
- Config migration preserves all existing JSON settings
- Context output matches IDE ContextManager for same inputs (golden tests)

---

*Agent: opus-1 | CLI Master Plan | Protocol-First Harmonization*
