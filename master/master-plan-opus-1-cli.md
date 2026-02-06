# MASTER PLAN: obot CLI Harmonization (opus-1)

**Agent:** opus-1
**Product:** obot CLI (Go)
**Date:** 2026-02-05
**Strategy:** Protocols over Code -- shared contracts, native Go implementation

---

## 1. CURRENT STATE

obot CLI is a Go-based command-line tool (~27,114 LOC) providing:
- 5-schedule orchestration framework (Knowledge/Plan/Implement/Scale/Production)
- 3-process navigation with strict adjacent-only rules (1-2-3)
- Human consultation with 60-second timeout and AI fallback
- Flow code tracking (S1P123S2P12...)
- RAM-based model tier detection (5 tiers: minimal through advanced)
- Session persistence with bash restoration
- Quality presets (fast/balanced/thorough)
- Cost savings tracking vs commercial APIs
- Line range editing (-start +end)
- Diff modes (--diff, --dry-run, --print)

### Key Files

| File | LOC | Purpose |
|------|-----|---------|
| `internal/orchestrate/orchestrator.go` | ~580 | 5-schedule state machine, navigation rules, flow code |
| `internal/agent/agent.go` | ~400 | Action execution (12 write-only actions) |
| `internal/fixer/engine.go` | ~800 | Code fix engine, prompt building |
| `internal/ollama/client.go` | ~500 | Ollama API client (non-streaming) |
| `internal/tier/detect.go` | ~200 | RAM-based model tier selection |
| `internal/context/summary.go` | ~250 | Basic file listing context builder |
| `internal/config/config.go` | ~300 | JSON config at ~/.config/obot/ |

### What CLI Has That IDE Lacks

1. 5-schedule orchestration (Knowledge/Plan/Implement/Scale/Production)
2. 3-process navigation with strict 1-2-3 rules
3. Human consultation with timeout and AI fallback
4. Flow code tracking (S1P123S2P12...)
5. Quality presets (fast/balanced/thorough)
6. Cost savings tracking
7. Line range editing (-start +end)
8. Diff/dry-run/print modes
9. RAM-based tier detection
10. Session persistence with bash restoration

### What CLI Lacks That IDE Has

1. Multi-model orchestration (only uses single tier-selected model)
2. Token-budget context management (basic prompt building only)
3. Semantic compression (no compression at all)
4. Conversation memory and error pattern learning
5. @Mention system
6. OBot rules system (.obotrules, custom bots)
7. Read/search file tools (agent is write-only executor)
8. Web search and URL fetch tools
9. Git integration tools (status, diff, commit)
10. Multi-model delegation (delegate_to_coder, researcher, vision)
11. Streaming responses
12. External API routing (Claude/GPT/Gemini)

---

## 2. CLI ENHANCEMENTS REQUIRED

### 2.1 Enhanced Context Manager (UCP) -- CRITICAL

Port from IDE's `Sources/Services/ContextManager.swift` (700 LOC).

**New file:** `internal/context/manager.go`

```go
type Manager struct {
    config          Config
    memory          *Memory
    errorPatterns   map[string]int
    toolResultCache *lru.Cache
    projectRules    *ProjectRules
}

type TokenBudget struct {
    Total     int
    Allocated map[SectionType]int
}

func (m *Manager) BuildOrchestratorContext(task string, workDir string, steps []Step) *OrchestratorContext
func (m *Manager) BuildDelegationContext(model Model, task string, ctx string, files map[string]string) *DelegationContext
func (m *Manager) RecordMemory(entry MemoryEntry)
func (m *Manager) RecordError(errStr string, context string)
func (m *Manager) CompressCode(code string, maxTokens int) string
```

Token budget allocation: system 8%, rules 10%, task 15%, files 35%, structure 10%, history 10%, memory 8%, errors 4%.

**New file:** `internal/context/compression.go` -- Semantic truncation preserving imports, signatures, error lines
**New file:** `internal/context/memory.go` -- Conversation memory with relevance scoring and LRU pruning
**New file:** `internal/context/errors.go` -- Error pattern tracking with frequency counting

### 2.2 Multi-Model Delegation -- CRITICAL

**Enhanced file:** `internal/model/coordinator.go`

```go
type Coordinator struct {
    orchestrator *ollama.Client  // qwen3:32b
    coder        *ollama.Client  // qwen2.5-coder:32b
    researcher   *ollama.Client  // command-r:35b
    vision       *ollama.Client  // qwen3-vl:32b
    warmupState  map[string]bool
    mu           sync.RWMutex
}

func (c *Coordinator) DelegateToCoder(ctx context.Context, task string, files map[string]string) (string, error)
func (c *Coordinator) DelegateToResearcher(ctx context.Context, query string) (string, error)
func (c *Coordinator) DelegateToVision(ctx context.Context, task string, imageData []byte) (string, error)
```

Model selection combines existing RAM-tier detection with intent routing ported from IDE's `IntentRouter.swift`.

**New file:** `internal/router/intent.go` -- Keyword-based intent classification for automatic model routing

### 2.3 Agent Tool Expansion -- HIGH

The current CLI agent (`internal/agent/agent.go`) has 12 write-only actions. It cannot read files, search, or delegate. Expand to support the full 22-tool unified registry.

**New tools to add:**

| Tool | Category | Implementation |
|------|----------|----------------|
| `think` | Core | Record internal reasoning step |
| `ask_user` | Core | Request user input with configurable timeout |
| `read_file` | File | Read file contents (agent currently cannot read) |
| `search_files` | File | Grep/ripgrep codebase search |
| `list_directory` | File | List directory contents |
| `delegate_to_coder` | Delegation | Send task to coder model |
| `delegate_to_researcher` | Delegation | Send task to researcher model |
| `delegate_to_vision` | Delegation | Send task to vision model |
| `web_search` | Web | DuckDuckGo search integration |
| `fetch_url` | Web | Fetch and extract web page content |
| `git_status` | Git | Repository status |
| `git_diff` | Git | View file/repo changes |
| `git_commit` | Git | Stage and commit changes |

**Modified file:** `internal/agent/agent.go` -- Add ReadFile, SearchFiles, ListDirectory methods
**New file:** `internal/agent/delegation.go` -- Multi-model delegation actions
**New file:** `internal/tools/web.go` -- Web search and URL fetch
**New file:** `internal/tools/git.go` -- Git status, diff, commit

### 2.4 OBot Rules System -- HIGH

Port from IDE's `Sources/Services/OBotService.swift`.

**New file:** `internal/obot/rules.go`

```go
type Rules struct {
    GlobalRules  []string            `yaml:"global_rules"`
    FileRules    map[string][]string `yaml:"file_rules"`
    ProjectRules []string            `yaml:"project_rules"`
}

func LoadRules(projectRoot string) (*Rules, error)  // Reads .obotrules
```

**New file:** `internal/obot/bots.go` -- Load and execute custom bots from `.obot/bots/*.yaml`
**New file:** `internal/obot/templates.go` -- Template support for prompt customization

### 2.5 Mention Resolution -- MEDIUM

Port from IDE's `Sources/Services/MentionService.swift`.

**New file:** `internal/context/mentions.go`

```go
type MentionType string

const (
    MentionFile      MentionType = "file"
    MentionBot       MentionType = "bot"
    MentionContext   MentionType = "context"
    MentionWeb       MentionType = "web"
    MentionGit       MentionType = "git"
    MentionSelection MentionType = "selection"
    MentionFolder    MentionType = "folder"
    MentionDocs      MentionType = "docs"
)

type MentionResolver struct {
    projectRoot     string
    bots            map[string]*Bot
    contextSnippets map[string]string
}

func (r *MentionResolver) ResolveMentions(text string) ([]Mention, error)
```

### 2.6 Streaming Support -- MEDIUM

**Enhanced file:** `internal/ollama/client.go`

Add HTTP streaming support with cancellation to match IDE's `OllamaService.swift`. Currently CLI uses non-streaming requests only.

### 2.7 Session State Management (USF) -- MEDIUM

**New file:** `internal/session/unified.go`

Implement the Unified Session Format (JSON schema) for cross-platform session portability. Sessions created in CLI can be opened in IDE and vice versa.

**New file:** `internal/cli/checkpoint.go` -- `obot checkpoint save/restore/list` commands

### 2.8 Configuration Migration -- LOW

**Modified file:** `internal/config/config.go`

Migrate from `~/.config/obot/config.json` to shared `~/.ollamabot/config.yaml` (or `~/.config/ollamabot/config.yaml`).

**New file:** `internal/config/migrate.go` -- Auto-detect old config, convert to YAML, create symlink for backward compatibility

---

## 3. PROTOCOL COMPLIANCE

### 3.1 Unified Orchestration Protocol (UOP)

CLI already implements the 5-schedule orchestration. Validate against UOP JSON schema. Ensure navigation rules, termination prerequisites, and flow code format match the schema exactly.

### 3.2 Unified Tool Registry (UTR)

CLI expands from 12 actions to 22 tools matching the canonical registry. Tool names, parameter schemas, and return formats validated against shared JSON schema.

### 3.3 Unified Context Protocol (UCP)

CLI's basic `summary.go` replaced by full context manager implementing UCP. Token budgeting, compression, memory, and error learning match IDE behavior validated through golden tests.

### 3.4 Unified Model Coordinator (UMC)

CLI's existing tier detection enhanced with intent routing. 4-model coordination (orchestrator, coder, researcher, vision) with RAM-aware fallback chains per the UMC schema.

### 3.5 Unified Configuration (UC)

CLI reads `~/.ollamabot/config.yaml`. All model, agent, context, quality, orchestration settings from shared config. CLI-specific section for terminal preferences (verbose, color, mem_graph).

### 3.6 Unified State Format (USF)

CLI sessions serialize to USF JSON format. Existing session persistence updated to use USF. Sessions are portable to IDE.

---

## 4. IMPLEMENTATION ROADMAP

| Week | Deliverable | Files |
|------|-------------|-------|
| 1 | Config migration + schema validation | `config/migrate.go`, `validator/schema.go` |
| 2 | Context manager port (token budgets, compression, memory) | `context/manager.go`, `context/compression.go`, `context/memory.go`, `context/errors.go` |
| 3 | Multi-model delegation + intent routing | `model/coordinator.go`, `agent/delegation.go`, `router/intent.go` |
| 4 | Tool expansion (read, search, web, git) + OBot rules | `tools/web.go`, `tools/git.go`, `obot/rules.go`, `obot/bots.go` |
| 5 | USF sessions + streaming + integration tests | `session/unified.go`, `ollama/stream.go` |
| 6 | Polish, documentation, release | Migration guide, user docs |

---

## 5. SUCCESS METRICS

| Metric | Target |
|--------|--------|
| Tool parity with IDE | 100% -- all 22 tools available |
| Context quality match | 95%+ -- golden test comparison with IDE output |
| Multi-model support | 4 models with delegation |
| Config portability | 100% -- shared config works |
| Session portability | 100% -- CLI sessions loadable in IDE |
| Performance regression | Less than 5% |
| Streaming support | Full HTTP streaming with cancellation |

---

## 6. RISK MITIGATION

| Risk | Mitigation |
|------|------------|
| Context manager port complexity (700 LOC) | Start early (Week 2); extensive golden tests comparing Go output to Swift output |
| Agent architecture change (write-only to read-write) | Incremental -- add read tools first, then search, then delegation |
| Multi-model coordination complexity | Each model client is independent; coordinator is thin routing layer |
| Streaming retrofit | Add alongside existing non-streaming path; feature flag |
| Config migration breaking existing users | Auto-detect old format, convert silently, symlink for backward compat |

---

**Agent:** opus-1
**Scope:** CLI enhancements only
**Dependencies:** Shared protocol schemas (UOP, UTR, UCP, UMC, UC, USF)
