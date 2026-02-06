# MASTER PLAN: obot CLI Harmonization
# Agent: opus-1 | Round: 2 (Final) | 2026-02-05

**Status**: CONVERGENCE ACHIEVED  
**Canonical Reference**: `consolidated-master-plan-sonnet-2.md`  
**Scope**: obot CLI (Go 1.21 command-line tool)

---

## 1. Architecture Decision

**CLI already has separated architecture. Formalize it.**

Current state:
- `internal/orchestrate/orchestrator.go` = DecisionEngine (5-schedule x 3-process)
- `internal/agent/agent.go` = ExecutionEngine (12 write-only actions)

Key insight: The orchestrator uses **closure-injected callbacks**, not serializable RPC:
```go
func (o *Orchestrator) Run(ctx context.Context,
    selectScheduleFn func(context.Context) (ScheduleID, error),
    selectProcessFn func(context.Context, ScheduleID, ProcessID) (ProcessID, bool, error),
    executeProcessFn func(context.Context, ScheduleID, ProcessID) error,
) error
```

This means CLI-as-JSON-RPC-server requires refactoring all callbacks into request-response pairs. **Deferred to v2.0.**

Formalize interfaces:
```go
type DecisionEngine interface {
    Plan(ctx context.Context, task string, context *Context) (*ExecutionPlan, error)
    SelectTools(step *ExecutionStep) []*ToolCall
    Verify(results []*ToolResult) (*VerificationStatus, error)
    ShouldTerminate() bool
}

type ExecutionEngine interface {
    Execute(ctx context.Context, tool *ToolCall) (*ToolResult, error)
    ExecuteParallel(ctx context.Context, tools []*ToolCall) ([]*ToolResult, error)
}
```

---

## 2. Package Consolidation (27 -> 12)

```
BEFORE (27 packages):                    AFTER (12 packages):
internal/actions      ─┐
internal/agent        ─┤─> internal/agent/
internal/analyzer     ─┤
internal/oberror      ─┤
internal/recorder     ─┘
internal/cli/         ──── internal/cli/
internal/config/      ─┐
internal/tier/        ─┤─> internal/config/
internal/model/       ─┘
internal/consultation ──── internal/consultation/
internal/context/     ─┐
internal/summary/     ─┤─> internal/context/
internal/fixer/       ─┐
internal/review/      ─┤─> internal/fixer/
internal/quality/     ─┘
internal/git/         ──── internal/git/
internal/judge/       ──── internal/judge/
internal/ollama/      ──── internal/ollama/
internal/orchestrate/ ──── internal/orchestrate/
internal/session/     ─┐
internal/stats/       ─┤─> internal/session/
internal/ui/          ─┐
internal/display/     ─┤─> internal/ui/
internal/memory/      ─┤
internal/ansi/        ─┘
```

---

## 3. Critical Gap: Agent is Write-Only

The CLI agent currently implements **12 executor actions**, all write operations:
```
CreateFile, DeleteFile, EditFile, RenameFile, MoveFile, CopyFile,
CreateDir, DeleteDir, RenameDir, MoveDir, CopyDir, RunCommand
```

The agent **cannot read files**. The fixer engine reads files and feeds content to the model as context. This is the fundamental Tier 1 vs Tier 2 gap.

### Tier 2 Tools to Add

New file: `internal/agent/tools_tier2.go`

| Tool ID | Go Name | Description |
|---------|---------|-------------|
| `file.read` | ReadFile | Read file contents |
| `file.search` | SearchFiles | Grep/ripgrep across codebase |
| `file.list` | ListDirectory | List directory contents |
| `web.search` | WebSearch | DuckDuckGo integration |
| `web.fetch` | FetchURL | HTTP GET with content extraction |
| `ai.delegate.coder` | DelegateToCoder | Route to coder model |
| `ai.delegate.researcher` | DelegateToResearcher | Route to researcher model |
| `ai.delegate.vision` | DelegateToVision | Route to vision model |
| `core.think` | Think | Internal reasoning step |
| `core.ask` | AskUser | Request user input (via consultation) |

---

## 4. New CLI Features (Port from IDE)

### 4.1 Multi-Model Coordinator

New file: `internal/ollama/coordinator.go`

```go
type ModelCoordinator struct {
    orchestratorModel string  // qwen3:32b
    coderModel        string  // qwen2.5-coder:32b
    researcherModel   string  // command-r:35b
    visionModel       string  // qwen3-vl:32b
}

func (mc *ModelCoordinator) Route(intent Intent) string
```

Model roles loaded from shared config:
```yaml
models:
  orchestrator:
    primary: "qwen3:32b"
    tier_mapping:
      minimal: "qwen3:8b"
      balanced: "qwen3:14b"
      performance: "qwen3:32b"
  coder:
    primary: "qwen2.5-coder:32b"
  researcher:
    primary: "command-r:35b"
  vision:
    primary: "qwen3-vl:32b"
```

### 4.2 Multi-Model Delegation

New file: `internal/agent/delegation.go`

- `DelegateToCoder(task, context)` — Calls coder model with coding-specific prompt
- `DelegateToResearcher(task)` — Calls researcher model for analysis/explanation
- `DelegateToVision(task, imagePath)` — Calls vision model for image analysis

### 4.3 Intent Router

New file: `internal/router/intent.go`

```go
type Intent string
const (
    IntentCoding   Intent = "coding"
    IntentResearch Intent = "research"
    IntentWriting  Intent = "writing"
    IntentVision   Intent = "vision"
)

func Route(input string, hasImage bool, hasCodeContext bool) Intent {
    // Keyword matching: "implement", "fix" -> coding
    // "what is", "explain" -> research
    // Image attached -> vision
    // Default -> writing
}
```

### 4.4 Context Manager (Port from IDE)

New files:
- `internal/context/manager.go` — Token-budget-aware context builder
- `internal/context/compression.go` — Semantic truncation

Token budget allocation (matching IDE):
```go
type BudgetAllocation struct {
    SystemPrompt       float64 // 0.07
    ProjectRules       float64 // 0.04
    TaskDescription    float64 // 0.14
    FileContent        float64 // 0.42
    ProjectStructure   float64 // 0.10
    ConversationHistory float64 // 0.14
    MemoryPatterns     float64 // 0.05
    ErrorWarnings      float64 // 0.04
}
```

### 4.5 OBot Integration

New file: `internal/config/obotrules.go`

- Parse `.obotrules` files from project root
- Apply rules as system prompt additions
- Support: custom prompts, file ignore patterns, quality overrides, model overrides
- Same format as IDE implementation

### 4.6 Web Tools

New file: `internal/tools/web.go`

- `WebSearch(query)` — DuckDuckGo HTML scraping
- `FetchURL(url)` — HTTP GET with HTML-to-text extraction

### 4.7 Git Tools

New file: `internal/tools/git.go`

- `GitStatus()` — `git status --porcelain`
- `GitDiff(file)` — `git diff` or `git diff -- file`
- `GitCommit(message, files)` — `git add` + `git commit`
- `GitPush(remote, branch)` — Already exists, formalize as tool

### 4.8 Checkpoint System

New file: `internal/cli/checkpoint.go`

Commands:
- `obot checkpoint save [name]` — Save current file states
- `obot checkpoint restore [name]` — Restore to checkpoint
- `obot checkpoint list` — List available checkpoints

Storage: `~/.config/ollamabot/checkpoints/{project_hash}/`

---

## 5. Configuration Migration

### Current
```go
func getConfigDir() string {
    return filepath.Join(homeDir, ".config", "obot")
}
// Format: JSON at ~/.config/obot/config.json
```

### Target
```go
func getConfigDir() string {
    return filepath.Join(homeDir, ".config", "ollamabot")
}
// Format: YAML at ~/.config/ollamabot/config.yaml
```

New files:
- `internal/config/config.go` — YAML parser (replace JSON)
- `internal/config/migrate.go` — Detect `~/.config/obot/config.json`, convert to YAML, create backward-compat symlink
- `internal/config/schema.go` — Validate against JSON Schema

Migration:
1. Check for `~/.config/obot/config.json` (legacy)
2. If exists: convert to `~/.config/ollamabot/config.yaml`
3. Create symlink: `~/.config/obot/` -> `~/.config/ollamabot/`
4. Both products now read from same location

---

## 6. Unified Session Format (USF)

New file: `internal/session/unified.go`

```go
type UnifiedSession struct {
    Version          string             `json:"version"`           // "1.0"
    SessionID        string             `json:"session_id"`
    CreatedAt        time.Time          `json:"created_at"`
    SourcePlatform   string             `json:"source_platform"`   // "cli"
    Task             SessionTask        `json:"task"`
    Workspace        SessionWorkspace   `json:"workspace"`
    OrchState        OrchestrationState `json:"orchestration_state"`
    History          []HistoryEntry     `json:"conversation_history"`
    FilesModified    []ModifiedFile     `json:"files_modified"`
    Checkpoints      []Checkpoint       `json:"checkpoints"`
}

func NewSession(task, workspace string) *UnifiedSession
func (s *UnifiedSession) Save(path string) error
func LoadSession(path string) (*UnifiedSession, error)
func ListSessions(dir string) ([]*UnifiedSession, error)
func (s *UnifiedSession) AddAction(action Action) 
func (s *UnifiedSession) AddNote(content, dest string)
```

Cross-platform: IDE can import CLI sessions and vice versa.

---

## 7. Error Handling Standardization

```go
type OBError struct {
    Code    string                 `json:"code"`
    Message string                 `json:"message"`
    Details map[string]interface{} `json:"details,omitempty"`
}

// Error codes (matching IDE):
// OB-E-0001: Tool execution failed
// OB-E-0002: Model connection lost
// OB-E-0003: Invalid tool parameters
// OB-E-0004: File operation failed
// OB-E-0005: Permission denied
// OB-E-0006: Context overflow
// OB-E-0007: Verification failed
// OB-E-0008: User cancelled
// OB-E-0009: Configuration invalid
// OB-E-0010: Session recovery failed
// OB-E-0011: Model not available
// OB-E-0012: Orchestration failed
// OB-E-0013: Git operation failed
// OB-E-0014: Network error
// OB-E-0015: Checkpoint corruption

func (e *OBError) Error() string {
    return fmt.Sprintf("[%s] %s", e.Code, e.Message)
}
```

---

## 8. Tool Registry (UTS v1.0)

Load tools from `~/.config/ollamabot/tools.yaml` at startup.

New file: `internal/tools/registry.go`

```go
func LoadRegistry() (*ToolRegistry, error) {
    data, err := os.ReadFile(os.ExpandEnv("$HOME/.config/ollamabot/tools.yaml"))
    var registry ToolRegistry
    err = yaml.Unmarshal(data, &registry)
    return &registry, err
}
```

22 tools total. CLI currently has 12 (Tier 1 write-only). Adding 10 Tier 2 tools.

Tool tiers:
- **Tier 1 (Executor):** CreateFile, DeleteFile, EditFile, RenameFile, MoveFile, CopyFile, CreateDir, DeleteDir, RenameDir, MoveDir, CopyDir, RunCommand
- **Tier 2 (Autonomous):** ReadFile, SearchFiles, ListDirectory, Think, AskUser, DelegateToCoder, DelegateToResearcher, DelegateToVision, WebSearch, FetchURL

---

## 9. CLI File Structure (Final)

```
internal/
  agent/
    agent.go              (executor + Tier 1 actions)
    tools_tier2.go        (NEW: Tier 2 read/search/delegate tools)
    delegation.go         (NEW: multi-model delegation)
    actions.go            (consolidated from internal/actions)
    recorder.go           (consolidated)
    types.go
  cli/
    root.go
    interactive.go
    orchestrate.go
    plan.go
    review.go
    session.go
    checkpoint.go         (NEW)
    theme.go
    version.go
  config/
    config.go             (UPDATED: YAML, new path)
    migrate.go            (NEW: JSON->YAML migration)
    schema.go             (NEW: validation)
    obotrules.go          (NEW: .obotrules support)
  consultation/
    handler.go
  context/
    summary.go
    manager.go            (NEW: token-budget context builder)
    compression.go        (NEW: semantic truncation)
    protocol.go           (NEW: UCP export/import)
    budgets.go            (NEW: budget allocation)
  fixer/
    agent.go
    diff.go
    engine.go
    extract.go
    quality.go
    prompts.go
  git/
    git.go
  judge/
    analyzer.go
  ollama/
    client.go
    coordinator.go        (NEW: multi-model coordination)
  orchestrate/
    orchestrator.go
    types.go
    navigator.go
    flowcode.go
    schedules.go          (NEW: 5 schedule implementations)
    consultation.go       (NEW: human-in-loop during P2)
  router/
    intent.go             (NEW: intent-based model routing)
  session/
    manager.go
    unified.go            (NEW: USF implementation)
    stats.go
    recovery.go
  tools/
    registry.go           (NEW: UTS loader)
    web.go                (NEW: web_search, fetch_url)
    git.go                (NEW: git_status, git_diff, git_commit as tools)
  ui/
    app.go
    display.go
    memory.go
    ansi.go
```

---

## 10. Implementation Timeline (CLI Track)

| Week | Deliverable |
|------|------------|
| 1 | Config migration (JSON->YAML), shared config path, backward-compat symlink |
| 2 | Context manager (token budgets, compression), intent router |
| 3 | Multi-model coordinator, delegation tools, Tier 2 read/search tools |
| 4 | Web tools, git tools, .obotrules support |
| 5 | USF session implementation, checkpoint system |
| 6 | Testing, package consolidation (27->12), documentation |

---

## 11. Success Criteria

| Metric | Target |
|--------|--------|
| Package count | 12 (down from 27) |
| All 22 UTS tools available | 100% |
| Config reads from shared YAML | 100% |
| Multi-model delegation working | 100% |
| Token-budget context management | 100% |
| .obotrules support | 100% |
| Session export/import round-trips | 100% |
| Error codes match ECS v1.0 | 100% |
| Tier 2 tools functional | 100% |

---

## 12. Performance Gates

- No regression > 5% in existing functionality
- Config loading: < 50ms additional overhead
- Session save/load: < 200ms
- Context build time: < 500ms for 500-file project
- CLI startup: < 50ms

---

## Consensus Points (Verified Across 274 Agent Plans)

1. Protocol-first architecture (shared schemas, not shared code)
2. Zero Rust for March release (bottleneck is inference, not counting)
3. CLI-as-server deferred to v2.0 (closure-callback barrier)
4. XDG-compliant config at ~/.config/ollamabot/ with symlink from ~/.config/obot/
5. 6-week realistic timeline
6. Two-tier tool migration (Tier 1 write-only -> add Tier 2 autonomous)

---

**END OF CLI MASTER PLAN**

**Agent opus-1 | Round 2 Final | CONVERGENCE ACHIEVED**

<!-- Recovery verified by opus-1 agent: 2026-02-06T01:15:22Z -->
