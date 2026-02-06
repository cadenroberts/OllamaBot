# Master Plan: obot CLI Harmonization

**Agent:** sonnet-4
**Date:** 2026-02-05
**Product:** obot CLI (Go)
**Scope:** CLI-side changes required for harmonization with OllamaBot IDE

---

## Current CLI State

- ~27,114 LOC Go across 61 files
- 27 internal packages
- 12 agent actions (write-only: CreateFile, DeleteFile, EditFile, RenameFile, MoveFile, CopyFile, CreateDir, DeleteDir, RenameDir, MoveDir, CopyDir, RunCommand)
- Agent cannot read files — fixer engine reads and feeds context
- Single model per tier (no multi-model delegation)
- 5-schedule x 3-process orchestration framework (already implemented)
- Quality presets: fast/balanced/thorough (already implemented)
- Flow code tracking (S1P123S2P12 format, already implemented)
- Session persistence via bash scripts
- Configuration: JSON at `~/.config/obot/config.json`
- Context building: simple text summary, no token budgeting
- No OBot ecosystem support (.obotrules, bots, context snippets)
- No multi-model delegation
- No intent routing
- No web search or vision tools

## 6 Protocols — CLI Implementation Requirements

### 1. Unified Configuration (UC)

**Current:** JSON config at `~/.config/obot/config.json`
**Target:** YAML config at `~/.config/ollamabot/config.yaml` with backward-compatible symlink

**Modified File:** `internal/config/config.go`
- Change config path to `~/.config/ollamabot/config.yaml`
- Replace JSON parsing with YAML (`gopkg.in/yaml.v3`)

**New File:** `internal/config/migrate.go`

```go
package config

// MigrateFromLegacy reads ~/.config/obot/config.json
// and writes ~/.config/ollamabot/config.yaml
func MigrateFromLegacy() error {
    oldPath := filepath.Join(homeDir, ".config", "obot", "config.json")
    newPath := filepath.Join(homeDir, ".config", "ollamabot", "config.yaml")

    if !fileExists(oldPath) {
        return nil // Nothing to migrate
    }

    oldConfig, err := readJSONConfig(oldPath)
    if err != nil {
        return fmt.Errorf("reading legacy config: %w", err)
    }

    newConfig := convertToUnified(oldConfig)
    if err := writeYAMLConfig(newPath, newConfig); err != nil {
        return fmt.Errorf("writing new config: %w", err)
    }

    // Create backward-compat symlink
    return os.Symlink(
        filepath.Dir(newPath),
        filepath.Join(homeDir, ".config", "obot"),
    )
}
```

### 2. Unified Tool Registry (UTR)

**Current:** 12 write-only actions in `internal/agent/types.go`
**Target:** Two-tier tool system with read/search/delegate capabilities

**Tier 1 (Existing — Executor Actions):**
- file.write (CreateFile)
- file.edit (EditFile)
- file.delete (DeleteFile)
- file.rename, file.move, file.copy
- dir.create, dir.delete, dir.rename, dir.move, dir.copy
- system.execute (RunCommand)

**Tier 2 (New — Autonomous Tools, must be added):**
- file.read
- file.search
- file.list
- core.think
- core.complete
- core.ask_user
- ai.delegate.coder
- ai.delegate.researcher
- ai.delegate.vision
- web.search
- web.fetch
- git.status
- git.diff
- git.commit

**New File:** `internal/agent/tools_tier2.go`

```go
package agent

// ReadFile reads file contents and returns them to the model
func (a *Agent) ReadFile(ctx context.Context, path string) (string, error) {
    content, err := os.ReadFile(filepath.Join(a.workDir, path))
    if err != nil {
        return "", fmt.Errorf("reading file: %w", err)
    }
    return string(content), nil
}

// SearchFiles searches for pattern across codebase using ripgrep
func (a *Agent) SearchFiles(ctx context.Context, query string, glob string) ([]SearchResult, error) {
    args := []string{"--json", query}
    if glob != "" {
        args = append(args, "--glob", glob)
    }
    cmd := exec.CommandContext(ctx, "rg", args...)
    cmd.Dir = a.workDir
    output, err := cmd.Output()
    // Parse ripgrep JSON output
    return parseRipgrepJSON(output), err
}
```

**Modified File:** `internal/agent/agent.go`
- Add Tier 2 tool methods
- Register all tools with Ollama tool-calling format

### 3. Unified Context Protocol (UCP)

**Current:** `internal/context/summary.go` — simple text concatenation, no token awareness
**Target:** Token-budgeted context building matching IDE's ContextManager

**New File:** `internal/context/manager.go`

```go
package context

type Manager struct {
    maxTokens     int
    budgetAlloc   BudgetAllocation
    compression   bool
    memoryEnabled bool
    errorLearning bool
}

type BudgetAllocation struct {
    SystemPrompt  float64 // 0.07
    ProjectRules  float64 // 0.04
    Task          float64 // 0.14
    FileContent   float64 // 0.42
    ProjectStruct float64 // 0.10
    History       float64 // 0.14
    Memory        float64 // 0.05
    Errors        float64 // 0.04
}

func (m *Manager) BuildContext(params ContextParams) (*UCPContext, error) {
    taskBudget := int(float64(m.maxTokens) * m.budgetAlloc.Task)
    fileBudget := int(float64(m.maxTokens) * m.budgetAlloc.FileContent)
    // Allocate and compress each section to fit budget
    // ...
    return ctx, nil
}
```

**New File:** `internal/context/compression.go`
- Semantic truncation: preserve imports, signatures, type definitions, error handling
- Compress middle sections when over budget

**New File:** `internal/context/memory.go`
- Conversation memory with relevance scoring
- Error pattern tracking

### 4. Unified Orchestration Protocol (UOP)

**Current:** Already implemented in `internal/orchestrate/`
**Target:** Validate against UOP schema, ensure navigation rules match specification exactly

**Verification required for existing files:**
- `internal/orchestrate/orchestrator.go` — schedule/process state machine
- `internal/orchestrate/navigator.go` — P1↔P2↔P3 navigation rules
- `internal/orchestrate/flowcode.go` — S{n}P{n} tracking
- `internal/orchestrate/types.go` — schedule and process types

Navigation rules (verify match):
- P1 -> P1 or P2
- P2 -> P1, P2, or P3
- P3 -> P2, P3, or TERMINATE
- Termination requires Schedule 5, Process 3

No new files needed. Validation only.

### 5. Unified Session Format (USF)

**Current:** Bash-script-based session persistence in `internal/session/`
**Target:** Add USF JSON format alongside existing bash scripts

**New File:** `internal/session/unified.go`

```go
package session

type UnifiedSession struct {
    Version          string              `json:"version"`
    SessionID        string              `json:"session_id"`
    CreatedAt        time.Time           `json:"created_at"`
    SourcePlatform   string              `json:"source_platform"` // "cli"
    Task             TaskDescription     `json:"task"`
    Workspace        WorkspaceInfo       `json:"workspace"`
    Orchestration    OrchestrationState  `json:"orchestration_state"`
    History          []Message           `json:"conversation_history"`
    FilesModified    []string            `json:"files_modified"`
    Checkpoints      []Checkpoint        `json:"checkpoints"`
    Stats            SessionStats        `json:"stats"`
}

func SaveUnifiedSession(sess *UnifiedSession, dir string) error {
    path := filepath.Join(dir, sess.SessionID+".json")
    data, err := json.MarshalIndent(sess, "", "  ")
    if err != nil {
        return err
    }
    return os.WriteFile(path, data, 0644)
}

func LoadUnifiedSession(path string) (*UnifiedSession, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }
    var sess UnifiedSession
    return &sess, json.Unmarshal(data, &sess)
}
```

**Modified File:** `internal/session/session.go`
- Write USF JSON alongside existing bash restoration scripts
- Store at `~/.ollamabot/sessions/{session_id}.json`

### 6. Unified Model Coordinator (UMC)

**Current:** Single model per tier in `internal/tier/models.go`, no intent routing
**Target:** 4-model roles with intent-based routing

**New File:** `internal/router/intent.go`

```go
package router

type Intent string

const (
    IntentCoding   Intent = "coding"
    IntentResearch Intent = "research"
    IntentGeneral  Intent = "general"
    IntentVision   Intent = "vision"
)

var codingKeywords = []string{"implement", "fix", "refactor", "debug", "optimize", "test", "build", "compile"}
var researchKeywords = []string{"what is", "explain", "compare", "document", "search", "find", "why"}

func ClassifyIntent(input string, hasImage bool) Intent {
    if hasImage {
        return IntentVision
    }
    lower := strings.ToLower(input)
    for _, kw := range codingKeywords {
        if strings.Contains(lower, kw) {
            return IntentCoding
        }
    }
    for _, kw := range researchKeywords {
        if strings.Contains(lower, kw) {
            return IntentResearch
        }
    }
    return IntentGeneral
}
```

**New File:** `internal/ollama/coordinator.go`

```go
package ollama

type ModelCoordinator struct {
    orchestrator *Client
    coder        *Client
    researcher   *Client
    vision       *Client
}

func (c *ModelCoordinator) SelectModel(intent router.Intent) *Client {
    switch intent {
    case router.IntentCoding:
        return c.coder
    case router.IntentResearch:
        return c.researcher
    case router.IntentVision:
        return c.vision
    default:
        return c.orchestrator
    }
}

func (c *ModelCoordinator) DelegateToCoder(ctx context.Context, task string) (string, error)
func (c *ModelCoordinator) DelegateToResearcher(ctx context.Context, task string) (string, error)
func (c *ModelCoordinator) DelegateToVision(ctx context.Context, task string, imagePath string) (string, error)
```

**Modified File:** `internal/tier/models.go`
- Read model tier mappings from shared YAML config
- Support 4 model roles per tier instead of single model

---

## Additional CLI Features (From IDE)

### .obotrules Parser

**New File:** `internal/obotrules/parser.go`
- Parse `.obotrules` markdown format
- Extract project description, code style, patterns to follow/avoid
- Inject into system prompts

### Web Search Tool

**New File:** `internal/tools/web.go`
- DuckDuckGo API integration
- Rate limiting (5 requests/minute)
- Result caching

### Git Tools

**New File:** `internal/tools/git.go`
- git.status: parse `git status --porcelain`
- git.diff: parse `git diff` output
- git.commit: stage and commit with message

### Checkpoint System

**New File:** `internal/cli/checkpoint.go`
- `obot checkpoint save [name]`
- `obot checkpoint restore [id]`
- `obot checkpoint list`
- Store file snapshots with git state metadata

---

## CLI File Change Summary

| File | Action | Purpose |
|------|--------|---------|
| internal/config/migrate.go | NEW | Legacy JSON to YAML migration |
| internal/agent/tools_tier2.go | NEW | Read/search/delegate tools |
| internal/context/manager.go | NEW | Token-budgeted context |
| internal/context/compression.go | NEW | Semantic truncation |
| internal/context/memory.go | NEW | Conversation memory |
| internal/session/unified.go | NEW | USF JSON persistence |
| internal/router/intent.go | NEW | Intent classification |
| internal/ollama/coordinator.go | NEW | Multi-model delegation |
| internal/obotrules/parser.go | NEW | .obotrules support |
| internal/tools/web.go | NEW | Web search tool |
| internal/tools/git.go | NEW | Git tools |
| internal/cli/checkpoint.go | NEW | Checkpoint commands |
| internal/config/config.go | MODIFY | YAML config, new path |
| internal/agent/agent.go | MODIFY | Register Tier 2 tools |
| internal/tier/models.go | MODIFY | 4 model roles from config |
| internal/session/session.go | MODIFY | Write USF alongside bash |
| internal/fixer/prompts.go | MODIFY | Include .obotrules |

---

## Verification Criteria

- Config loads from `~/.config/ollamabot/config.yaml`
- Legacy `~/.config/obot/config.json` migrated automatically on first run
- Backward-compat symlink created at `~/.config/obot/`
- Agent can read files, search files, list directories (Tier 2 tools)
- Multi-model delegation routes to correct model per intent
- Context building respects token budgets with semantic compression
- Sessions save in USF JSON format loadable by IDE
- .obotrules parsed and injected into system prompts
- Orchestration validates against UOP schema (existing implementation)
- Web search returns results via DuckDuckGo
- Git tools execute status/diff/commit operations
- Checkpoint save/restore works with file snapshots
