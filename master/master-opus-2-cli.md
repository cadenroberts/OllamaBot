# obot CLI Harmonization Master Plan
## Agent: opus-2 | Platform: CLI (Go)

**Date:** 2026-02-05
**Round:** Final Consolidation
**Scope:** All CLI-side changes required for OllamaBot/obot harmonization
**Target:** March 2026 Release

---

## Executive Summary

This plan specifies every CLI-side change needed to harmonize obot (Go CLI) with OllamaBot (Swift/macOS IDE) under a protocol-first, zero-shared-code architecture. The CLI gains multi-model delegation, token-budgeted context management, read/search tools, web search, git tools, and shared configuration -- while preserving its existing strengths in orchestration, quality presets, session persistence, and human consultation.

---

## Architecture Decision

**Protocol-Native, Zero Shared Code.** Both products implement the same behavioral contracts (JSON schemas, YAML configuration) in their native languages. The CLI does NOT become a JSON-RPC server for the IDE (deferred to v2.0). Instead, it continues as a standalone tool that reads the same shared configuration and writes sessions in a cross-compatible format.

### Code-Grounded Reality

The CLI agent (`internal/agent/agent.go`) currently implements **12 write-only executor actions**:
```
CreateFile, DeleteFile, EditFile, RenameFile, MoveFile, CopyFile,
CreateDir, DeleteDir, RenameDir, MoveDir, CopyDir, RunCommand
```

The agent cannot read files. The fixer engine (`internal/fixer/engine.go`) reads files and feeds content to the model. This means tool unification requires a **migration path** with two tiers:
- **Tier 1 (Executor):** File mutations + commands (current CLI capability)
- **Tier 2 (Autonomous):** Read, search, delegate, web, git (needs porting from IDE)

The CLI orchestrator (`internal/orchestrate/orchestrator.go`) uses closure-injected callbacks in its `Run()` method. These are Go function closures, NOT serializable RPC interfaces. Making this a JSON-RPC server would require refactoring all callbacks -- a multi-week rewrite deferred to v2.0.

---

## Part 1: Configuration Migration

### 1.1 YAML Config Replacement

**File:** `internal/config/config.go`
**Change:** Replace JSON config at `~/.config/obot/config.json` with YAML at `~/.config/ollamabot/config.yaml`

```go
import "gopkg.in/yaml.v3"

type UnifiedConfig struct {
    Version       string           `yaml:"version"`
    Platform      PlatformConfig   `yaml:"platform"`
    Models        ModelsConfig     `yaml:"models"`
    Quality       QualityConfig    `yaml:"quality"`
    Context       ContextConfig    `yaml:"context"`
    Orchestration OrchConfig       `yaml:"orchestration"`
    Platforms     PlatformsConfig  `yaml:"platforms"`
}

type ModelsConfig struct {
    Orchestrator ModelEntry `yaml:"orchestrator"`
    Coder        ModelEntry `yaml:"coder"`
    Researcher   ModelEntry `yaml:"researcher"`
    Vision       ModelEntry `yaml:"vision"`
}

type ModelEntry struct {
    Primary     string            `yaml:"primary"`
    TierMapping map[string]string `yaml:"tier_mapping"`
}

func LoadConfig() (*UnifiedConfig, error) {
    configPath := filepath.Join(homeDir, ".config", "ollamabot", "config.yaml")
    data, err := os.ReadFile(configPath)
    if err != nil {
        return nil, err
    }
    var cfg UnifiedConfig
    return &cfg, yaml.Unmarshal(data, &cfg)
}
```

### 1.2 Migration Tool (NEW)

**File:** `internal/config/migrate.go`
**Purpose:** Detect old `~/.config/obot/config.json`, convert to YAML, create backward-compatible symlink

### 1.3 Schema Validation (NEW)

**File:** `internal/config/schema.go`
**Purpose:** Validate config against JSON Schema definitions

---

## Part 2: Context Management (NEW)

### 2.1 Token-Budgeted Context Manager

**File:** `internal/context/manager.go`
**Purpose:** Port IDE's ContextManager token budgeting to Go

```go
type Manager struct {
    maxTokens     int
    budgetAlloc   BudgetAllocation
    compression   bool
    memoryEnabled bool
    errorLearning bool
    tokenizer     Tokenizer
}

type BudgetAllocation struct {
    SystemPrompt  float64 // 0.07
    ProjectRules  float64 // 0.04
    Task          float64 // 0.14
    Files         float64 // 0.42
    Project       float64 // 0.10
    History       float64 // 0.14
    Memory        float64 // 0.05
    Errors        float64 // 0.04
}

func (m *Manager) BuildContext(task string, workspace string,
    files []FileContext, history []Step) (*UCPContext, error) {
    // Allocate token budgets per section
    // Compress sections to fit within budgets
    // Select files by relevance score
    // Return UCP-compliant context object
}
```

### 2.2 Semantic Compression (NEW)

**File:** `internal/context/compression.go`
**Purpose:** Truncate large content while preserving structure (imports, signatures, key sections)

### 2.3 Tokenizer

**Dependency:** `github.com/pkoukk/tiktoken-go` (pure Go, no FFI)

No Rust. No C bindings. The bottleneck is Ollama inference (2-10s per call), not token counting.

---

## Part 3: Multi-Model Delegation (NEW)

### 3.1 Model Coordinator Enhancement

**File:** `internal/model/coordinator.go`
**Change:** Support 4 model roles instead of single-model-per-tier

```go
type Coordinator struct {
    orchestrator *ollama.Client
    coder        *ollama.Client
    researcher   *ollama.Client
    vision       *ollama.Client
    config       *config.ModelsConfig
}

func NewCoordinator(cfg *config.ModelsConfig, tier string) *Coordinator {
    return &Coordinator{
        orchestrator: ollama.NewClient(cfg.Orchestrator.ModelForTier(tier)),
        coder:        ollama.NewClient(cfg.Coder.ModelForTier(tier)),
        researcher:   ollama.NewClient(cfg.Researcher.ModelForTier(tier)),
        vision:       ollama.NewClient(cfg.Vision.ModelForTier(tier)),
    }
}
```

### 3.2 Delegation Tools (NEW)

**File:** `internal/agent/delegation.go`
**Purpose:** Add `delegate_to_coder`, `delegate_to_researcher`, `delegate_to_vision` actions

```go
func (a *Agent) DelegateToCoder(ctx context.Context, task string,
    files map[string]string) (string, error) {
    // Build context using ContextManager, call coder model
}

func (a *Agent) DelegateToResearcher(ctx context.Context,
    query string) (string, error) {
    // Build research context, call researcher model
}

func (a *Agent) DelegateToVision(ctx context.Context,
    imagePath string, question string) (string, error) {
    // Load image, call vision model
}
```

---

## Part 4: Tier 2 Tools (NEW)

### 4.1 Read/Search/List Tools

**File:** `internal/agent/agent.go`
**Change:** Add Tier 2 autonomous tools to the agent

```go
func (a *Agent) ReadFile(path string) (string, error)
func (a *Agent) SearchFiles(pattern string, dir string) ([]SearchResult, error)
func (a *Agent) ListFiles(dir string) ([]FileEntry, error)
```

These transform the CLI agent from a write-only executor into a read-write autonomous system.

### 4.2 Web Search Tool (NEW)

**File:** `internal/tools/web.go`
**Purpose:** DuckDuckGo search integration

### 4.3 Git Tools (NEW)

**File:** `internal/tools/git.go`
**Purpose:** Git status, diff, commit operations

```go
func GitStatus(dir string) (*GitStatusResult, error)
func GitDiff(dir string, staged bool) (string, error)
func GitCommit(dir string, message string) error
```

---

## Part 5: Intent Router (NEW)

**File:** `internal/router/intent.go`
**Purpose:** Route tasks to appropriate model based on content analysis

```go
type Intent string
const (
    IntentCoding   Intent = "coding"
    IntentResearch Intent = "research"
    IntentGeneral  Intent = "general"
    IntentVision   Intent = "vision"
)

func ClassifyIntent(task string) Intent {
    // Keyword-based classification
}

func (r *Router) SelectModel(intent Intent, coord *Coordinator) *ollama.Client {
    switch intent {
    case IntentCoding:   return coord.coder
    case IntentResearch: return coord.researcher
    case IntentVision:   return coord.vision
    default:             return coord.orchestrator
    }
}
```

---

## Part 6: Session Format (NEW)

### 6.1 Unified Session Format

**File:** `internal/session/unified.go`
**Purpose:** Read/write USF JSON files compatible with IDE

```go
type UnifiedSession struct {
    Version            string      `json:"version"`
    SessionID          string      `json:"session_id"`
    CreatedAt          time.Time   `json:"created_at"`
    SourcePlatform     string      `json:"source_platform"`
    Task               TaskState   `json:"task"`
    OrchestrationState *OrchState  `json:"orchestration_state,omitempty"`
    ConversationHistory []Message  `json:"conversation_history"`
    FilesModified      []string    `json:"files_modified"`
    Checkpoints        []Checkpoint `json:"checkpoints"`
    Stats              SessionStats `json:"stats"`
}

func SaveUSF(session *UnifiedSession) error
func LoadUSF(sessionID string) (*UnifiedSession, error)
```

Session directory: `~/.config/ollamabot/sessions/{session_id}.json`

### 6.2 Checkpoint Commands (NEW)

**File:** `internal/cli/checkpoint.go`
**Purpose:** `obot checkpoint save/restore/list`

### 6.3 Existing Session Update

**File:** `internal/session/session.go`
**Change:** Write USF format alongside existing bash restoration scripts for backward compatibility.

---

## Part 7: Tier Detection Update

**File:** `internal/tier/models.go`
**Change:** Read model tier mappings from shared `config.yaml` instead of hardcoded Go map

---

## Part 8: Fixer Engine Integration

### 8.1 Prompt Enhancement

**File:** `internal/fixer/prompts.go`
**Change:** Use ContextManager for prompt building instead of string concatenation

### 8.2 .obotrules Support

**File:** `internal/fixer/prompts.go`
**Change:** Read `.obotrules` from project root and inject into system prompt

---

## Part 9: New Files Summary

| File | Lines (est.) | Purpose |
|------|-------------|---------|
| `internal/config/migrate.go` | ~100 | JSON to YAML migration |
| `internal/config/schema.go` | ~80 | Schema validation |
| `internal/context/manager.go` | ~300 | Token-budgeted context |
| `internal/context/compression.go` | ~150 | Semantic truncation |
| `internal/agent/delegation.go` | ~200 | Multi-model delegation |
| `internal/tools/web.go` | ~100 | Web search |
| `internal/tools/git.go` | ~150 | Git operations |
| `internal/router/intent.go` | ~100 | Intent classification |
| `internal/session/unified.go` | ~200 | USF read/write |
| `internal/cli/checkpoint.go` | ~150 | Checkpoint commands |

**Total new code:** ~1,530 lines

## Part 10: Modified Files Summary

| File | Change |
|------|--------|
| `internal/config/config.go` | Replace JSON with YAML, change path |
| `internal/agent/agent.go` | Add ReadFile, SearchFiles, ListFiles |
| `internal/model/coordinator.go` | Support 4 model roles |
| `internal/tier/models.go` | Read from shared config |
| `internal/fixer/prompts.go` | Use ContextManager, load .obotrules |
| `internal/session/session.go` | Write USF alongside bash scripts |
| `internal/cli/root.go` | Load shared config on startup |

---

## Part 11: Success Criteria

- [ ] CLI reads `~/.config/ollamabot/config.yaml` for all shared settings
- [ ] Migration from old `config.json` works with symlink backward compat
- [ ] Token-budgeted context management produces UCP-compliant output
- [ ] Multi-model delegation routes to 4 specialist models
- [ ] Agent can read files, search, and list directories (Tier 2)
- [ ] Web search returns results
- [ ] Git tools provide status, diff, commit
- [ ] Intent router classifies tasks and selects appropriate model
- [ ] Sessions save in USF format readable by IDE
- [ ] IDE sessions import and resume in CLI
- [ ] Checkpoint save/restore/list commands work
- [ ] .obotrules loaded and injected into prompts
- [ ] No regression > 5% in existing CLI performance

---

## Part 12: Protocol Schemas (CLI Implements)

| Protocol | Schema | CLI Responsibility |
|----------|--------|-------------------|
| UC (Unified Config) | `config.yaml` | Read and apply (migrate from JSON) |
| UTR (Tool Registry) | `tools.schema.json` | Validate actions against registry |
| UCP (Context Protocol) | `context.schema.json` | Build compliant context objects |
| UOP (Orchestration Protocol) | `orchestration.schema.json` | Already implemented (validate) |
| USF (Session Format) | `session.schema.json` | Write sessions in USF format |
| UMC (Model Coordinator) | Part of config.yaml | Route to 4 model roles |

---

## Part 13: Dependencies

### New Go Dependencies
- `gopkg.in/yaml.v3` -- YAML parsing for shared config
- `github.com/pkoukk/tiktoken-go` -- Pure Go token counting (no Rust/C FFI)

### Deferred to v2.0
- CLI JSON-RPC server mode
- Behavioral equivalence test framework
- Interactive migration wizard
- Rust performance libraries

---

*Agent: opus-2 | Platform: CLI | Final Consolidation*
