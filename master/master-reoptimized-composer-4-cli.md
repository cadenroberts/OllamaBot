# obot CLI Master Harmonization Plan (Round 2 - Re-Optimized)

**Agent:** Composer-4
**Round:** 2 (Re-Optimized Consolidation)
**Date:** 2026-02-05
**Target:** obot CLI (Go)
**Sources:** 18 Round 1 consolidation plans from Sonnet-2, Opus-1, Composer-2/3/5, Gemini-1/4/5, GPT-1, Unified Implementation Strategy

---

## Executive Summary

Protocol-first harmonization strategy for the obot CLI. Shared YAML/JSON schemas ensure behavioral equivalence with OllamaBot IDE without forcing code sharing. The CLI maintains its native Go implementation while reading shared contracts from `~/.config/ollamabot/`.

**Core Principle:** Establish behavioral equivalence through shared contracts, allowing the CLI to maintain its Go strengths while ensuring consistent user experience with the IDE.

---

## Part 1: CLI Architecture

```
obot CLI (Go)
├── CLI Interface (existing internal/cli/)
├── SharedConfig (NEW - reads ~/.config/ollamabot/config.yaml)
├── ToolRegistry (NEW - validates against UTR)
├── Orchestrator (existing internal/orchestrate/)
├── Agent (existing internal/agent/)
├── ContextManager (NEW - port from IDE)
├── IntentRouter (NEW - port from IDE)
├── DelegationService (NEW - multi-model)
├── UnifiedSession (NEW - USF import/export)
├── ReadTools (NEW - file.read, file.search, file.list)
├── WebTools (NEW - web.search)
└── GitTools (NEW - git.status, git.diff, git.commit)
```

---

## Part 2: Unified Configuration (CLI Side)

Replace `~/.config/obot/config.json` with `~/.config/ollamabot/config.yaml`:

```yaml
version: "2.0"
created_by: "obot" | "ollamabot"

models:
  tier_detection:
    auto: true
    thresholds:
      minimal: [0, 15]
      compact: [16, 23]
      balanced: [24, 31]
      performance: [32, 63]
      advanced: [64, 999]
  orchestrator:
    default: qwen3:32b
    tier_mapping:
      minimal: qwen3:8b
      balanced: qwen3:14b
      performance: qwen3:32b
  coder:
    default: qwen2.5-coder:32b
    tier_mapping:
      minimal: deepseek-coder:1.3b
      balanced: qwen2.5-coder:14b
      performance: qwen2.5-coder:32b
  researcher:
    default: command-r:35b
    tier_mapping:
      minimal: command-r:7b
      performance: command-r:35b
  vision:
    default: qwen3-vl:32b
    tier_mapping:
      minimal: llava:7b
      performance: qwen3-vl:32b

orchestration:
  default_mode: "orchestration"
  schedules:
    - id: knowledge
      processes: [research, crawl, retrieve]
      model: researcher
    - id: plan
      processes: [brainstorm, clarify, plan]
      model: coder
      consultation:
        clarify: {type: optional, timeout: 60}
    - id: implement
      processes: [implement, verify, feedback]
      model: coder
      consultation:
        feedback: {type: mandatory, timeout: 300}
    - id: scale
      processes: [scale, benchmark, optimize]
      model: coder
    - id: production
      processes: [analyze, systemize, harmonize]
      model: [coder, vision]

context:
  max_tokens: 32768
  budget_allocation:
    task: 0.25
    files: 0.33
    project: 0.16
    history: 0.12
    memory: 0.12
    errors: 0.06
    reserve: 0.06
  compression:
    enabled: true
    strategy: semantic_truncate
    preserve: [imports, exports, signatures, errors]

quality:
  fast:
    iterations: 1
    verification: none
  balanced:
    iterations: 2
    verification: llm_review
  thorough:
    iterations: 3
    verification: expert_judge

platforms:
  cli:
    verbose: true
    mem_graph: true
    color_output: true

ollama:
  url: http://localhost:11434
  timeout_seconds: 120
```

**Go Interface:**

```go
package config

type UnifiedConfig struct {
    Version       string              `yaml:"version"`
    AI            AIConfig            `yaml:"ai"`
    Orchestration OrchestrationConfig `yaml:"orchestration"`
    Context       ContextConfig       `yaml:"context"`
    Quality       QualityConfig       `yaml:"quality"`
    Platforms     PlatformConfig      `yaml:"platforms"`
}

func LoadUnifiedConfig() (*UnifiedConfig, error)
func MigrateFromJSON(oldPath string) error
func ValidateConfig(cfg *UnifiedConfig) error
```

**Migration:**
- Detect old `~/.config/obot/config.json`
- Convert to YAML automatically
- Create symlink `~/.config/obot/ -> ~/.config/ollamabot/` for backward compat

---

## Part 3: CLI Enhancements

### C-01: Context Manager (Port from IDE)

The single highest-leverage change. Port IDE's ContextManager token budgeting to Go.

```go
package context

type Manager struct {
    config   ContextConfig
    budget   *Budget
    memory   *Memory
    errors   *ErrorLearner
}

type BuildOptions struct {
    Task        string
    Files       []FileContent
    ProjectInfo string
    History     []HistoryEntry
    MaxTokens   int
    Intent      string
}

type BuiltContext struct {
    SystemPrompt  string
    UserPrompt    string
    TokensUsed    int
    TokenBudget   int
    FilesIncluded int
    Compressed    bool
}

func NewManager(cfg ContextConfig) *Manager
func (m *Manager) Build(opts BuildOptions) (*BuiltContext, error)
func (m *Manager) CompressContent(content string, maxTokens int) string
func (m *Manager) CountTokens(text string) int
```

**New files:**
- `internal/context/manager.go` -- Main context builder
- `internal/context/budget.go` -- Token budget allocation
- `internal/context/compression.go` -- Semantic truncation (preserve imports/signatures)
- `internal/context/tokens.go` -- Token counting (simple heuristic: len/4)
- `internal/context/memory.go` -- Conversation memory
- `internal/context/errors.go` -- Error pattern learning

### C-02: Intent Routing

Classify task intent from keywords, route to appropriate model role.

```go
package router

type Intent string
const (
    IntentCoding   Intent = "coding"
    IntentResearch Intent = "research"
    IntentWriting  Intent = "writing"
    IntentVision   Intent = "vision"
)

func NewIntentRouter(cfg ModelConfig) *IntentRouter
func (r *IntentRouter) Classify(task string) Intent
func (r *IntentRouter) SelectModel(intent Intent, tier string) string
```

### C-03: Multi-Model Delegation

Add delegate.coder, delegate.researcher, delegate.vision tools to agent.

```go
package agent

func (a *Agent) DelegateToCoder(task string, context string) (*DelegationResult, error)
func (a *Agent) DelegateToResearcher(query string) (*DelegationResult, error)
func (a *Agent) DelegateToVision(task string, imagePath string) (*DelegationResult, error)
```

### C-04: Read and Search Tools

Move CLI agent from executor-only to autonomous. Add file.read, file.search, file.list.

```go
func (a *Agent) ReadFile(path string) (string, error)
func (a *Agent) SearchFiles(query string, scope string) ([]SearchResult, error)
func (a *Agent) ListDirectory(path string) ([]DirEntry, error)
```

### C-05: Web Search

DuckDuckGo integration for research tasks.

```go
func WebSearch(query string) ([]SearchResult, error)
```

### C-06: Git Tools

Structured git operations (status, diff, commit) instead of raw RunCommand.

```go
func GitStatus() (*GitStatusResult, error)
func GitDiff(path string) (string, error)
func GitCommit(message string) error
```

### C-12: Session USF

Save sessions in USF JSON to `~/.config/ollamabot/sessions/`. Add checkpoint commands.

```go
type UnifiedSession struct {
    Version        string       `json:"version"`
    SessionID      string       `json:"session_id"`
    CreatedAt      time.Time    `json:"created_at"`
    PlatformOrigin string       `json:"platform_origin"`
    Task           TaskInfo     `json:"task"`
    Orchestration  OrchState    `json:"orchestration"`
    Steps          []StepRecord `json:"steps"`
    Checkpoints    []Checkpoint `json:"checkpoints"`
    Stats          SessionStats `json:"stats"`
}

func SaveUSF(session *UnifiedSession) error
func LoadUSF(sessionID string) (*UnifiedSession, error)
```

### C-13: Config Migration Tool

`obot config migrate` command to convert old JSON config to new YAML format.

---

## Part 4: Unified Tool Registry (CLI Side)

CLI validates agent actions against shared registry at `~/.config/ollamabot/tools/registry.yaml`. Migration from 12 executor-only actions to 21+ tools:

**Tier 1 (Existing - Executor Tools):**

| Tool ID | Category | CLI Status |
|---------|----------|------------|
| file.write | file | existing (CreateFile) |
| file.edit | file | existing (EditFile) |
| file.delete | file | existing (DeleteFile) |
| file.rename | file | existing (RenameFile) |
| file.move | file | existing (MoveFile) |
| file.copy | file | existing (CopyFile) |
| dir.create | file | existing (CreateDir) |
| system.run | system | existing (RunCommand) |

**Tier 2 (NEW - Autonomous Tools):**

| Tool ID | Category | CLI Status |
|---------|----------|------------|
| think | core | NEW |
| complete | core | NEW |
| ask_user | core | NEW |
| file.read | file | NEW |
| file.search | file | NEW |
| file.list | file | NEW |
| file.edit_range | file | NEW |
| ai.delegate.coder | delegation | NEW |
| ai.delegate.researcher | delegation | NEW |
| ai.delegate.vision | delegation | NEW |
| web.search | web | NEW |
| git.status | git | NEW |
| git.diff | git | NEW |
| git.commit | git | NEW |
| checkpoint.save | session | NEW |
| checkpoint.restore | session | NEW |

---

## Part 5: Context Protocol (CLI Side)

New context manager builds UCP-compliant context objects:

```json
{
  "version": "1.0",
  "context_id": "uuid",
  "timestamp": "ISO-8601",
  "type": "orchestrator",
  "task": {"original": "fix bug in auth", "intent": "coding"},
  "files": [{"path": "auth.go", "relevance": 0.95}],
  "budget": {
    "total_tokens": 32768,
    "used_tokens": 12000,
    "allocation": {"task": 0.25, "files": 0.33, "history": 0.12}
  }
}
```

---

## Part 6: Session Format (CLI Side)

UnifiedSession writes USF JSON to `~/.config/ollamabot/sessions/`:

```json
{
  "version": "1.0",
  "session_id": "uuid",
  "created_at": "ISO-8601",
  "platform_origin": "cli",
  "task": {"original": "fix auth bug", "status": "completed"},
  "orchestration": {"current_schedule": 3, "flow_code": "S1P123S2P123S3P123"},
  "steps": [{"step_number": 1, "tool_id": "file.read", "success": true}],
  "checkpoints": [{"id": "cp-1", "git_commit": "abc123"}],
  "stats": {"total_tokens": 25000, "files_modified": 5, "estimated_cost_saved": 0.42}
}
```

**New commands:**
- `obot session list`
- `obot session export {id}`
- `obot checkpoint save/restore/list`

---

## Part 7: Implementation Roadmap (CLI)

### Week 1: Foundation
- YAML config loader (replace JSON)
- Config migration tool (`obot config migrate`)
- Backward-compat symlink
- Schema validation

### Week 2: Context & Routing
- Context manager (port from IDE ContextManager.swift)
- Token counting, budget allocation, semantic compression
- Intent router (keyword-based classification)

### Week 3: Multi-Model & Tools
- Multi-model delegation (delegate.coder, delegate.researcher, delegate.vision)
- Read/search tools (file.read, file.search, file.list)
- Tool registry validation

### Week 4: Feature Completion
- Web search (DuckDuckGo)
- Git tools (status, diff, commit)
- Think and complete tools

### Week 5: Session Portability
- USF session format
- Checkpoint commands
- Session export/import

---

## Part 8: Files to Modify

### Existing Files
- `internal/config/config.go` -- Replace JSON with YAML, change path
- `internal/tier/detect.go` -- Read thresholds from shared config
- `internal/agent/agent.go` -- Register new tools, use context manager
- `internal/fixer/engine.go` -- Use new context manager
- `internal/orchestrate/orchestrator.go` -- Pass context between steps
- `internal/model/coordinator.go` -- Support 4 model roles
- `internal/session/session.go` -- Use USF format

### New Files
- `internal/config/yaml_loader.go`
- `internal/config/migrate.go`
- `internal/config/schema.go`
- `internal/context/manager.go`
- `internal/context/budget.go`
- `internal/context/compression.go`
- `internal/context/tokens.go`
- `internal/context/memory.go`
- `internal/context/errors.go`
- `internal/router/intent.go`
- `internal/agent/delegation.go`
- `internal/agent/tools_read.go`
- `internal/agent/tools_search.go`
- `internal/tools/registry.go`
- `internal/tools/web.go`
- `internal/tools/git.go`
- `internal/session/unified.go`
- `internal/cli/checkpoint.go`

---

## Part 9: Success Metrics (CLI)

- Configuration reads from shared config.yaml
- Context manager uses token budgeting
- Multi-model delegation functional
- Agent has read/search capabilities (Tier 2 tools)
- Sessions saved in USF format
- All tool calls validated against shared registry
- Sessions importable by IDE
- No performance regression > 5%

---

**This plan represents composer-4's final CLI-specific master output from the 3-round, 150+ plan consolidation process.**
