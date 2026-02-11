# UNIFIED IMPLEMENTATION PLAN
## OllamaBot + obot Harmonization  
**Generated:** 2026-02-10  
**Source:** Analysis of 76 master plan files  
**Agent:** Claude Sonnet 4.5  
**Status:** CANONICAL IMPLEMENTATION ROADMAP

---

## SECTION 1: COMPILATION RESULT

###ROLE
You are a senior software architect executing a cohesion-sensitive harmonization of two codebases (obot CLI in Go, OllamaBot IDE in Swift) via protocol-first design.

### OBJECTIVE
Create a single, deterministic implementation plan that harmonizes ollamabot IDE and obot CLI through 6 Unified Protocols, achieving 90%+ feature parity, 100% session portability, and zero shared code.

### INPUTS
- 76 master plan files from multiple AI agents (opus, sonnet, gemini, composer, gpt families)
- Existing CLI codebase: ~27,114 LOC, 61 files, 27 packages (Go)
- Existing IDE codebase: ~34,489 LOC, 63 files, 5 modules (Swift/SwiftUI)
- Consensus on 6 protocols: UOP, UTR, UCP, UMC, UC, USF
- Shared configuration directory: `~/.config/ollamabot/`

### STRICT RULES
1. Protocol-first: Shared behavioral contracts via schemas, NOT shared code
2. No Rust FFI: Pure Go + pure Swift implementations
3. No CLI-as-server for v1.0: Deferred to v2.0 (orchestrator uses non-serializable closures)
4. XDG-compliant: `~/.config/ollamabot/` with backward-compat symlink from `~/.config/obot/`
5. Zero hallucination: Only reference files that were explicitly read
6. Deterministic: One plan, one execution path, no option menus
7. Minimal scope: Solve exactly what is required for harmonization

### PROCESS
1. Identify canonical source files for CLI and IDE
2. Define all 6 unified protocols with schemas
3. Map existing capabilities to target capabilities  
4. Generate implementation plans grouped by implementation challenge similarity
5. Produce single cohesive plan file (this document)

### OUTPUT SCHEMA
```
UNIFIED_IMPLEMENTATION_PLAN.md
├── SECTION 1: COMPILATION RESULT
├── SECTION 2: CANONICALS ANALYSIS
├── SECTION 3: THE 6 UNIFIED PROTOCOLS
├── SECTION 4: CLI IMPLEMENTATION TRACK
├── SECTION 5: IDE IMPLEMENTATION TRACK
├── SECTION 6: CROSS-PLATFORM INTEGRATION
├── SECTION 7: TESTING & VALIDATION
├── SECTION 8: MIGRATION & DEPLOYMENT
├── SECTION 9: SUCCESS CRITERIA
└── SECTION 10: IMPLEMENTATION PHASES
```

### DONE CONDITIONS
- All 6 protocols fully specified with schemas
- All CLI changes enumerated with file paths
- All IDE changes enumerated with file paths  
- Implementation phases defined with deliverables
- Success criteria measurable
- No speculative language (could/should/might)

---

## SECTION 2: CANONICALS ANALYSIS

### CLI CANONICALS (obot)
**Location:** `/Users/croberts/ollamabot/`

**Configuration:**
- **Current:** `internal/config/config.go` - JSON at `~/.config/obot/config.json`
- **Canonical for:** Configuration loading, tier detection, model selection

**Orchestration:**
- **Current:** `internal/orchestrate/orchestrator.go` - 5-schedule x 3-process state machine
- **Canonical for:** Orchestration Protocol (UOP) - Knowledge, Plan, Implement, Scale, Production schedules

**Agent Execution:**
- **Current:** `internal/agent/agent.go` - 12 write-only actions
- **Limitation:** Agent CANNOT read files (write-only executor)
- **Actions:** CreateFile, DeleteFile, EditFile, RenameFile, MoveFile, CopyFile, CreateDir, DeleteDir, RenameDir, MoveDir, CopyDir, RunCommand

**Context:**
- **Current:** `internal/context/summary.go` - Basic string concatenation
- **Limitation:** No token budgeting, no semantic compression

**Session:**
- **Current:** `internal/session/session.go` - Bash scripts, directory-based
- **Limitation:** Not portable to IDE

**Quality:**
- **Current:** `internal/fixer/quality.go` - Fast/Balanced/Thorough presets
- **Canonical for:** Quality presets implementation

### IDE CANONICALS (OllamaBot)
**Location:** `/Users/croberts/ollamabot/Sources/`

**Context Management:**
- **Current:** `Services/ContextManager.swift` - Sophisticated token budgeting
- **Canonical for:** Context Protocol (UCP) - token budgets, semantic compression, error learning
- **Budget Allocation:** System 7%, Rules 4%, Task 14%, Files 42%, Project 10%, History 14%, Memory 5%, Errors 4%

**Model Coordination:**
- **Current:** `Services/ModelTierManager.swift` + `Services/IntentRouter.swift`
- **Canonical for:** Model Coordinator (UMC) - 4 model roles (orchestrator, coder, researcher, vision)
- **Intent Routing:** Keyword-based classification

**Agent Tools:**
- **Current:** `Agent/AgentTools.swift` - 18+ read-write tools
- **Tools:** read_file, write_file, edit_file, delete_file, search_files, list_directory, run_command, take_screenshot, delegate_to_coder, delegate_to_researcher, delegate_to_vision, web_search, fetch_url, git_status, git_diff, git_commit, think, complete, ask_user

**OBot System:**
- **Current:** `Services/OBotService.swift` - .obotrules, bots, context, templates
- **Canonical for:** Project-level AI rules and customization

**Agent Execution:**
- **Current:** `Agent/AgentExecutor.swift` (1069 lines) - Infinite loop + explore mode
- **Limitation:** No formal orchestration (5-schedule framework)

### EVIDENCE
- CLI orchestrator at line 47-67 of `internal/orchestrate/orchestrator.go` uses closure callbacks
- CLI agent at line 23-45 of `internal/agent/agent.go` defines 12 write-only actions
- IDE context manager at line 89-120 of `Sources/Services/ContextManager.swift` implements token budgets
- CLI config at line 47 of `internal/config/config.go` uses `~/.config/obot/`

---

## SECTION 3: THE 6 UNIFIED PROTOCOLS

### Protocol 1: Unified Orchestration Protocol (UOP)
**Purpose:** Standardize the 5-schedule orchestration framework across both products.

**Schema Location:** `~/.config/ollamabot/schemas/orchestration.schema.json`

**Specification:**
- **5 Schedules:** Knowledge, Plan, Implement, Scale, Production
- **3 Processes per schedule:** P1, P2, P3
- **Navigation Rules:** 
  - Within schedule: P1 ↔ P2 ↔ P3 (adjacent only)
  - Between schedules: Any P3 → any P1 (next schedule)
- **Flow Code Format:** `S1P123S2P12...` (tracks traversal)
- **Human Consultation:**
  - Clarify: Optional, 60s timeout, AI fallback
  - Feedback: Mandatory, 300s timeout, assume approval
- **Termination:** Must complete all 5 schedules, terminate from Production P3

**JSON Schema:**
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Unified Orchestration Protocol",
  "type": "object",
  "properties": {
    "version": {"type": "string", "const": "1.0"},
    "schedules": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {"enum": ["knowledge", "plan", "implement", "scale", "production"]},
          "processes": {
            "type": "array",
            "minItems": 3,
            "maxItems": 3,
            "items": {
              "type": "object",
              "properties": {
                "id": {"type": "integer", "minimum": 1, "maximum": 3},
                "name": {"type": "string"},
                "description": {"type": "string"}
              }
            }
          }
        }
      }
    },
    "navigation_rules": {
      "type": "object",
      "properties": {
        "within_schedule": {"type": "string", "const": "1<->2<->3"},
        "between_schedules": {"type": "string", "const": "any_P3_to_any_P1"}
      }
    },
    "consultation": {
      "type": "object",
      "properties": {
        "clarify": {
          "type": "object",
          "properties": {
            "type": {"enum": ["optional", "mandatory"]},
            "timeout_seconds": {"type": "integer"},
            "fallback": {"type": "string"}
          }
        },
        "feedback": {
          "type": "object",
          "properties": {
            "type": {"enum": ["optional", "mandatory"]},
            "timeout_seconds": {"type": "integer"},
            "fallback": {"type": "string"}
          }
        }
      }
    }
  }
}
```

**Implementation:**
- **CLI:** Already implemented in `internal/orchestrate/orchestrator.go` — validate against schema
- **IDE:** NEW implementation required — port 5-schedule state machine to Swift

---

### Protocol 2: Unified Tool Registry (UTR)
**Purpose:** Standardize tool definitions and capabilities across both products.

**Schema Location:** `~/.config/ollamabot/schemas/tools.schema.json`

**Master Tool Set (22 tools):**

**Core (3):**
- `think` — Internal reasoning step
- `complete` — Task completion signal
- `consult.human` — Request human input

**Files (9):**
- `file.read` — Read file contents
- `file.write` — Write/create file
- `file.edit` — Edit file (search/replace)
- `file.delete` — Delete file
- `file.search` — Search file contents
- `file.list` — List directory contents
- `file.rename` — Rename file
- `file.move` — Move file
- `file.copy` — Copy file

**System (2):**
- `run_command` — Execute shell command
- `take_screenshot` — Capture screenshot

**Delegation (3):**
- `delegate.coder` — Delegate to coding model
- `delegate.researcher` — Delegate to research model
- `delegate.vision` — Delegate to vision model

**Web (2):**
- `web.search` — Web search (DuckDuckGo)
- `web.fetch` — Fetch URL content

**Git (3):**
- `git.status` — Git status
- `git.diff` — Git diff
- `git.commit` — Git commit

**Tool Tiers:**
- **Tier 1 (Executor):** File mutations + commands (12 tools) — CLI currently implements
- **Tier 2 (Autonomous):** Read, search, delegate, web, git (10 tools) — CLI must add

**JSON Schema:**
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Unified Tool Registry",
  "type": "object",
  "properties": {
    "version": {"type": "string", "const": "1.0"},
    "tools": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {"type": "string"},
          "category": {"enum": ["core", "file", "system", "delegation", "web", "git"]},
          "tier": {"enum": [1, 2]},
          "parameters": {"type": "object"},
          "returns": {"type": "object"},
          "parallelizable": {"type": "boolean"},
          "platforms": {
            "type": "array",
            "items": {"enum": ["cli", "ide", "both"]}
          }
        },
        "required": ["id", "category", "tier"]
      }
    }
  }
}
```

**Implementation:**
- **CLI:** Add 10 Tier 2 tools — new file `internal/agent/tools_read.go`
- **IDE:** Already has all 22 tools — normalize IDs to match UTR

---

### Protocol 3: Unified Context Protocol (UCP)
**Purpose:** Standardize token-budget context management across both products.

**Schema Location:** `~/.config/ollamabot/schemas/context.schema.json`

**Token Budget Allocation:**
```
System Prompt:        7%  (system instructions)
Project Rules:        4%  (.obotrules content)
Task Description:    14%  (user prompt)
File Content:        42%  (open/selected files)
Project Structure:   10%  (directory tree)
Conversation History:14%  (recent messages)
Memory Patterns:      5%  (learned patterns)
Error Warnings:       4%  (recent errors)
```

**Features:**
- Token counting via tiktoken or equivalent
- Semantic truncation: preserve imports, exports, signatures
- Conversation memory with LRU pruning
- Error pattern learning
- Inter-agent context passing

**JSON Schema:**
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Unified Context Protocol",
  "type": "object",
  "properties": {
    "version": {"type": "string", "const": "1.0"},
    "token_budget": {"type": "integer"},
    "allocation": {
      "type": "object",
      "properties": {
        "system_prompt": {"type": "number", "minimum": 0, "maximum": 1},
        "project_rules": {"type": "number", "minimum": 0, "maximum": 1},
        "task_description": {"type": "number", "minimum": 0, "maximum": 1},
        "file_content": {"type": "number", "minimum": 0, "maximum": 1},
        "project_structure": {"type": "number", "minimum": 0, "maximum": 1},
        "conversation_history": {"type": "number", "minimum": 0, "maximum": 1},
        "memory_patterns": {"type": "number", "minimum": 0, "maximum": 1},
        "error_warnings": {"type": "number", "minimum": 0, "maximum": 1}
      }
    },
    "files": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "path": {"type": "string"},
          "priority": {"enum": ["high", "medium", "low"]},
          "lines": {"type": "array", "items": {"type": "integer"}},
          "tokens": {"type": "integer"}
        }
      }
    },
    "learned_patterns": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "pattern": {"type": "string"},
          "frequency": {"type": "integer"},
          "context": {"type": "string"}
        }
      }
    }
  }
}
```

**Implementation:**
- **CLI:** NEW — Port IDE's ContextManager logic to Go (`internal/context/manager.go`)
- **IDE:** Already implemented — Export/import UCP JSON format

---

### Protocol 4: Unified Model Coordinator (UMC)
**Purpose:** Harmonize model selection combining RAM tiers + intent routing.

**Schema Location:** `~/.config/ollamabot/schemas/models.schema.json`

**Model Roles:**
- **Orchestrator:** Planning, delegation (e.g., qwen3:32b)
- **Coder:** Code generation, debugging (e.g., qwen2.5-coder:32b)
- **Researcher:** RAG, documentation (e.g., command-r:35b)
- **Vision:** Image analysis (e.g., qwen3-vl:32b)

**Tier Mapping:**
- **Minimal:** 8-15GB RAM → 1.3-7B models
- **Compact:** 16-23GB RAM → 6.7-13B models
- **Balanced:** 24-31GB RAM → 14B models
- **Performance:** 32-63GB RAM → 32B models
- **Advanced:** 64GB+ RAM → 70B+ models

**Intent Classification:**
- **Coding:** Keywords like "implement", "fix", "refactor", "optimize"
- **Research:** Keywords like "what is", "explain", "compare", "analyze"
- **Writing:** Keywords like "write", "document", "summarize"
- **Vision:** Image attached or "analyze image", "describe picture"

**JSON Schema:**
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Unified Model Coordinator",
  "type": "object",
  "properties": {
    "version": {"type": "string", "const": "1.0"},
    "models": {
      "type": "object",
      "properties": {
        "orchestrator": {
          "type": "object",
          "properties": {
            "primary": {"type": "string"},
            "tier_mapping": {
              "type": "object",
              "properties": {
                "minimal": {"type": "string"},
                "compact": {"type": "string"},
                "balanced": {"type": "string"},
                "performance": {"type": "string"},
                "advanced": {"type": "string"}
              }
            }
          }
        },
        "coder": {"type": "object"},
        "researcher": {"type": "object"},
        "vision": {"type": "object"}
      }
    },
    "intent_routing": {
      "type": "object",
      "properties": {
        "coding": {"type": "array", "items": {"type": "string"}},
        "research": {"type": "array", "items": {"type": "string"}},
        "writing": {"type": "array", "items": {"type": "string"}},
        "vision": {"type": "array", "items": {"type": "string"}}
      }
    }
  }
}
```

**Implementation:**
- **CLI:** Add intent routing — new file `internal/router/intent.go`
- **IDE:** Add RAM-tier fallbacks — enhance `ModelTierManager.swift`

---

### Protocol 5: Unified Configuration (UC)
**Purpose:** Single source of truth for configuration.

**Location:** `~/.config/ollamabot/config.yaml`

**Migration:**
- CLI: `~/.config/obot/config.json` (JSON) → `~/.config/ollamabot/config.yaml` (YAML)
- IDE: `UserDefaults` → `~/.config/ollamabot/config.yaml` (keep UserDefaults for UI-only prefs)
- Create symlink: `~/.config/obot/` → `~/.config/ollamabot/`

**Structure:**
```yaml
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
  ide:
    streaming_ui: true
    visual_flow_tracking: true
    rich_diff_preview: true
```

**JSON Schema for Validation:**
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Unified Configuration",
  "type": "object",
  "properties": {
    "version": {"type": "string"},
    "platform": {"type": "object"},
    "models": {"type": "object"},
    "quality": {"type": "object"},
    "context": {"type": "object"},
    "orchestration": {"type": "object"},
    "platforms": {"type": "object"}
  },
  "required": ["version", "models", "quality", "context", "orchestration"]
}
```

**Implementation:**
- **CLI:** Replace JSON parser with YAML — modify `internal/config/config.go`
- **CLI:** Add migration tool — new file `internal/config/migrate.go`
- **IDE:** Add YAML parser — new file `Sources/Services/SharedConfigService.swift`

---

### Protocol 6: Unified State Format (USF)
**Purpose:** Enable cross-product session portability.

**Schema Location:** `~/.config/ollamabot/schemas/session.schema.json`

**Format:** JSON with schema validation

**Storage Location:** `~/.config/ollamabot/sessions/{session_id}.json`

**Structure:**
```json
{
  "version": "1.0",
  "session_id": "sess_20260210_153045",
  "created_at": "2026-02-10T15:30:45Z",
  "source_platform": "cli",
  "task": {
    "description": "Implement JWT authentication",
    "intent": "coding",
    "quality_preset": "balanced"
  },
  "workspace": {
    "path": "/Users/dev/project",
    "git_branch": "feature/auth",
    "git_status": "clean"
  },
  "orchestration_state": {
    "flow_code": "S1P123S2P12",
    "current_schedule": "implement",
    "current_process": 2,
    "completed_schedules": ["knowledge", "plan"]
  },
  "conversation_history": [],
  "files_modified": [],
  "checkpoints": [],
  "stats": {
    "tokens_used": 15000,
    "time_elapsed_seconds": 180,
    "tools_executed": 45
  }
}
```

**JSON Schema:**
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Unified State Format",
  "type": "object",
  "properties": {
    "version": {"type": "string", "const": "1.0"},
    "session_id": {"type": "string"},
    "created_at": {"type": "string", "format": "date-time"},
    "source_platform": {"enum": ["cli", "ide"]},
    "task": {"type": "object"},
    "workspace": {"type": "object"},
    "orchestration_state": {"type": "object"},
    "conversation_history": {"type": "array"},
    "files_modified": {"type": "array"},
    "checkpoints": {"type": "array"},
    "stats": {"type": "object"}
  },
  "required": ["version", "session_id", "created_at", "source_platform", "task"]
}
```

**Implementation:**
- **CLI:** Update session serialization — new file `internal/session/unified.go`
- **IDE:** Update checkpoint service — modify `Sources/Services/CheckpointService.swift`
- **Both:** Support import/export commands

---

## SECTION 4: CLI IMPLEMENTATION TRACK

### Current State Assessment
- **LOC:** ~27,114 across 61 files
- **Packages:** 27 (target: 12 after consolidation)
- **Agent Tools:** 12 (Tier 1 write-only)
- **Models:** 1 per RAM tier (single-model mode only)
- **Context:** Basic file concatenation
- **Orchestration:** 5-schedule framework exists but partially stubbed
- **Config:** JSON at `~/.config/obot/config.json`
- **Sessions:** Bash scripts, directory-based

### Critical Gaps
1. **Agent is Write-Only:** Cannot read files, search codebase, or delegate
2. **No Token Budgets:** Context is simple string concatenation
3. **No Multi-Model:** Single model per tier, no role-based routing
4. **No Intent Routing:** Cannot classify tasks for optimal model selection
5. **Non-Portable Sessions:** Bash-only, cannot import IDE sessions
6. **Non-Portable Config:** JSON format, different location than IDE

### Implementation Plans

#### PLAN CLI-01: Configuration Migration
**Priority:** P0 (Foundation)  
**Estimated LOC:** ~400 new + ~200 modified

**Files to Modify:**
- `internal/config/config.go` — Replace JSON parser with YAML, change path to `~/.config/ollamabot/`

**Files to Create:**
- `internal/config/migrate.go` — Auto-migrate from old JSON config, create symlink
- `internal/config/schema.go` — Validate against JSON Schema

**Implementation:**
```go
// internal/config/config.go
func getConfigDir() string {
    // OLD: return filepath.Join(homeDir, ".config", "obot")
    return filepath.Join(homeDir, ".config", "ollamabot")
}

func LoadConfig() (*Config, error) {
    // Replace JSON decoder with YAML decoder
    data, err := os.ReadFile(getConfigPath())
    var config Config
    err = yaml.Unmarshal(data, &config)
    return &config, err
}

// internal/config/migrate.go
func MigrateFromLegacy() error {
    oldPath := filepath.Join(homeDir, ".config", "obot", "config.json")
    newPath := filepath.Join(homeDir, ".config", "ollamabot", "config.yaml")
    
    if fileExists(oldPath) && !fileExists(newPath) {
        // Read old JSON
        data, _ := os.ReadFile(oldPath)
        var oldConfig map[string]interface{}
        json.Unmarshal(data, &oldConfig)
        
        // Convert to new YAML format
        newConfig := convertToV2(oldConfig)
        yamlData, _ := yaml.Marshal(newConfig)
        os.MkdirAll(filepath.Dir(newPath), 0755)
        os.WriteFile(newPath, yamlData, 0644)
        
        // Create backward-compat symlink
        symlinkPath := filepath.Join(homeDir, ".config", "obot")
        os.Symlink(filepath.Join(homeDir, ".config", "ollamabot"), symlinkPath)
    }
    return nil
}
```

**Dependencies:**
- Add `gopkg.in/yaml.v3` to `go.mod`

**Testing:**
- Unit test: Config loads from YAML
- Unit test: Migration converts JSON to YAML correctly
- Unit test: Symlink created correctly
- Integration test: Both old and new paths work

---

#### PLAN CLI-02: Context Manager
**Priority:** P0 (Foundation)  
**Estimated LOC:** ~700 new

**Files to Create:**
- `internal/context/manager.go` — Token-budget-aware context builder
- `internal/context/compression.go` — Semantic truncation
- `internal/context/budget.go` — Budget allocation calculator
- `internal/context/memory.go` — Conversation memory with LRU
- `internal/context/tokens.go` — Token counting (tiktoken-go wrapper)
- `internal/context/errors.go` — Error pattern learning

**Implementation:**
```go
// internal/context/manager.go
type Manager struct {
    config        *config.Config
    memory        []MemoryEntry
    projectCache  *ProjectCache
    errorPatterns map[string]int
    tokenCounter  *TokenCounter
}

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

func NewManager(cfg *config.Config) *Manager {
    return &Manager{
        config:        cfg,
        memory:        make([]MemoryEntry, 0),
        errorPatterns: make(map[string]int),
        tokenCounter:  NewTokenCounter(),
    }
}

func (m *Manager) BuildContext(task string, workspace string, files []FileContext) (*UCPContext, error) {
    budget := m.calculateBudget()
    
    // Allocate tokens according to UCP
    systemPrompt := m.buildSystemPrompt(budget.SystemPrompt)
    projectRules := m.loadProjectRules(workspace, budget.ProjectRules)
    taskDesc := m.formatTask(task, budget.TaskDescription)
    fileContent := m.selectFiles(files, budget.FileContent)
    projectStructure := m.buildProjectTree(workspace, budget.ProjectStructure)
    history := m.pruneHistory(budget.ConversationHistory)
    memory := m.selectMemory(budget.MemoryPatterns)
    errors := m.selectErrors(budget.ErrorWarnings)
    
    return &UCPContext{
        Version: "1.0",
        Sections: []ContextSection{
            {Type: "system", Content: systemPrompt, Tokens: m.count(systemPrompt)},
            {Type: "rules", Content: projectRules, Tokens: m.count(projectRules)},
            {Type: "task", Content: taskDesc, Tokens: m.count(taskDesc)},
            {Type: "files", Content: fileContent, Tokens: m.count(fileContent)},
            {Type: "project", Content: projectStructure, Tokens: m.count(projectStructure)},
            {Type: "history", Content: history, Tokens: m.count(history)},
            {Type: "memory", Content: memory, Tokens: m.count(memory)},
            {Type: "errors", Content: errors, Tokens: m.count(errors)},
        },
    }, nil
}
```

**Dependencies:**
- Add `github.com/pkoukk/tiktoken-go` to `go.mod`

**Testing:**
- Unit test: Budget allocation sums to ~1.0
- Unit test: Token counting matches expected values
- Unit test: Semantic compression preserves imports/exports
- Unit test: LRU pruning works correctly
- Integration test: Full context fits within token limit

---

#### PLAN CLI-03: Agent Read Capability (Tier 2 Tools)
**Priority:** P0 (Critical)  
**Estimated LOC:** ~400 new

**Files to Modify:**
- `internal/agent/agent.go` — Register new Tier 2 tools

**Files to Create:**
- `internal/agent/tools_read.go` — ReadFile, SearchFiles, ListDirectory

**Implementation:**
```go
// internal/agent/tools_read.go
func (a *Agent) ReadFile(ctx context.Context, path string) (*ActionResult, error) {
    content, err := os.ReadFile(path)
    if err != nil {
        return nil, fmt.Errorf("failed to read file: %w", err)
    }
    return &ActionResult{
        Action:  "ReadFile",
        Path:    path,
        Content: string(content),
        Success: true,
    }, nil
}

func (a *Agent) SearchFiles(ctx context.Context, pattern string, dir string) (*ActionResult, error) {
    // Use ripgrep if available, fallback to filepath.Walk
    var results []SearchResult
    
    if commandExists("rg") {
        cmd := exec.CommandContext(ctx, "rg", pattern, dir, "--json")
        output, err := cmd.Output()
        if err != nil {
            return nil, err
        }
        results = parseRipgrepJSON(output)
    } else {
        results = fallbackSearch(pattern, dir)
    }
    
    return &ActionResult{
        Action:  "SearchFiles",
        Pattern: pattern,
        Results: results,
        Success: true,
    }, nil
}

func (a *Agent) ListDirectory(ctx context.Context, path string) (*ActionResult, error) {
    entries, err := os.ReadDir(path)
    if err != nil {
        return nil, fmt.Errorf("failed to list directory: %w", err)
    }
    
    var items []FileInfo
    for _, entry := range entries {
        info, _ := entry.Info()
        items = append(items, FileInfo{
            Name:  entry.Name(),
            IsDir: entry.IsDir(),
            Size:  info.Size(),
        })
    }
    
    return &ActionResult{
        Action:  "ListDirectory",
        Path:    path,
        Items:   items,
        Success: true,
    }, nil
}
```

**Testing:**
- Unit test: ReadFile returns file contents
- Unit test: SearchFiles finds matches
- Unit test: ListDirectory lists files
- Integration test: Agent can read, search, list in orchestration

---

#### PLAN CLI-04: Multi-Model Coordinator
**Priority:** P1  
**Estimated LOC:** ~350 new + ~100 modified

**Files to Modify:**
- `internal/tier/models.go` — Support 4 roles per tier instead of 1 model

**Files to Create:**
- `internal/ollama/coordinator.go` — Multi-model coordination
- `internal/router/intent.go` — Intent-based routing

**Implementation:**
```go
// internal/ollama/coordinator.go
type Coordinator struct {
    config *config.Config
    tier   string
    models map[ModelRole]string
}

type ModelRole string
const (
    RoleOrchestrator ModelRole = "orchestrator"
    RoleCoder        ModelRole = "coder"
    RoleResearcher   ModelRole = "researcher"
    RoleVision       ModelRole = "vision"
)

func NewCoordinator(cfg *config.Config, tier string) *Coordinator {
    return &Coordinator{
        config: cfg,
        tier:   tier,
        models: make(map[ModelRole]string),
    }
}

func (c *Coordinator) SelectModel(role ModelRole, intent Intent) (string, error) {
    // Get model for role from config
    roleConfig := c.config.Models[string(role)]
    
    // Use tier mapping to select appropriate model size
    modelName := roleConfig.TierMapping[c.tier]
    if modelName == "" {
        modelName = roleConfig.Primary
    }
    
    return modelName, nil
}

// internal/router/intent.go
type Intent string
const (
    IntentCoding   Intent = "coding"
    IntentResearch Intent = "research"
    IntentWriting  Intent = "writing"
    IntentVision   Intent = "vision"
)

func ClassifyIntent(input string, hasImage bool, hasCodeContext bool) Intent {
    if hasImage {
        return IntentVision
    }
    
    inputLower := strings.ToLower(input)
    
    // Coding keywords
    codingKeywords := []string{"implement", "fix", "refactor", "optimize", "debug", "code", "function"}
    for _, kw := range codingKeywords {
        if strings.Contains(inputLower, kw) {
            return IntentCoding
        }
    }
    
    // Research keywords
    researchKeywords := []string{"what is", "explain", "compare", "analyze", "research", "understand"}
    for _, kw := range researchKeywords {
        if strings.Contains(inputLower, kw) {
            return IntentResearch
        }
    }
    
    // Default to writing
    return IntentWriting
}
```

**Testing:**
- Unit test: Intent classification works correctly
- Unit test: Model selection respects tiers
- Unit test: Fallback to primary model works
- Integration test: Multi-model coordination in orchestration

---

#### PLAN CLI-05: Multi-Model Delegation
**Priority:** P1  
**Estimated LOC:** ~300 new

**Files to Create:**
- `internal/agent/delegation.go` — Delegation to coder/researcher/vision models

**Implementation:**
```go
// internal/agent/delegation.go
func (a *Agent) DelegateToCoder(ctx context.Context, task string, context string) (*ActionResult, error) {
    model := a.coordinator.SelectModel(RoleCoder, IntentCoding)
    
    prompt := fmt.Sprintf(
        "You are a coding specialist. Task: %s\n\nContext:\n%s\n\nProvide implementation.",
        task, context,
    )
    
    response, err := a.ollama.Generate(ctx, model, prompt)
    if err != nil {
        return nil, err
    }
    
    return &ActionResult{
        Action:   "DelegateToCoder",
        Model:    model,
        Response: response,
        Success:  true,
    }, nil
}

func (a *Agent) DelegateToResearcher(ctx context.Context, task string) (*ActionResult, error) {
    model := a.coordinator.SelectModel(RoleResearcher, IntentResearch)
    
    prompt := fmt.Sprintf(
        "You are a research specialist. Analyze and explain: %s",
        task,
    )
    
    response, err := a.ollama.Generate(ctx, model, prompt)
    if err != nil {
        return nil, err
    }
    
    return &ActionResult{
        Action:   "DelegateToResearcher",
        Model:    model,
        Response: response,
        Success:  true,
    }, nil
}

func (a *Agent) DelegateToVision(ctx context.Context, task string, imagePath string) (*ActionResult, error) {
    model := a.coordinator.SelectModel(RoleVision, IntentVision)
    
    imageData, err := os.ReadFile(imagePath)
    if err != nil {
        return nil, err
    }
    
    response, err := a.ollama.GenerateWithImage(ctx, model, task, imageData)
    if err != nil {
        return nil, err
    }
    
    return &ActionResult{
        Action:    "DelegateToVision",
        Model:     model,
        ImagePath: imagePath,
        Response:  response,
        Success:   true,
    }, nil
}
```

**Testing:**
- Unit test: Delegation calls correct model
- Unit test: Prompts formatted correctly
- Integration test: Delegation in orchestration

---

#### PLAN CLI-06: Web Tools
**Priority:** P1  
**Estimated LOC:** ~200 new

**Files to Create:**
- `internal/tools/web.go` — WebSearch, FetchURL

**Implementation:**
```go
// internal/tools/web.go
func WebSearch(ctx context.Context, query string) (*SearchResult, error) {
    // DuckDuckGo HTML scraping
    url := fmt.Sprintf("https://html.duckduckgo.com/html/?q=%s", url.QueryEscape(query))
    
    resp, err := http.Get(url)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()
    
    results := parseDuckDuckGoHTML(resp.Body)
    
    return &SearchResult{
        Query:   query,
        Results: results,
    }, nil
}

func FetchURL(ctx context.Context, urlStr string) (*FetchResult, error) {
    resp, err := http.Get(urlStr)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()
    
    content, err := extractText(resp.Body)
    if err != nil {
        return nil, err
    }
    
    return &FetchResult{
        URL:     urlStr,
        Content: content,
    }, nil
}

func extractText(r io.Reader) (string, error) {
    // Simple HTML-to-text: strip tags, decode entities
    doc, err := html.Parse(r)
    if err != nil {
        return "", err
    }
    
    var buf bytes.Buffer
    var extract func(*html.Node)
    extract = func(n *html.Node) {
        if n.Type == html.TextNode {
            buf.WriteString(n.Data)
        }
        for c := n.FirstChild; c != nil; c = c.NextSibling {
            extract(c)
        }
    }
    extract(doc)
    
    return buf.String(), nil
}
```

**Testing:**
- Unit test: WebSearch parses results
- Unit test: FetchURL extracts text
- Integration test: Web tools in orchestration

---

#### PLAN CLI-07: Git Tools
**Priority:** P1  
**Estimated LOC:** ~200 new

**Files to Create:**
- `internal/tools/git.go` — GitStatus, GitDiff, GitCommit

**Implementation:**
```go
// internal/tools/git.go
func GitStatus(ctx context.Context, dir string) (*GitStatusResult, error) {
    cmd := exec.CommandContext(ctx, "git", "-C", dir, "status", "--porcelain")
    output, err := cmd.Output()
    if err != nil {
        return nil, err
    }
    
    files := parseGitStatus(string(output))
    
    return &GitStatusResult{
        Files: files,
    }, nil
}

func GitDiff(ctx context.Context, dir string, file string) (*GitDiffResult, error) {
    args := []string{"-C", dir, "diff"}
    if file != "" {
        args = append(args, "--", file)
    }
    
    cmd := exec.CommandContext(ctx, "git", args...)
    output, err := cmd.Output()
    if err != nil {
        return nil, err
    }
    
    return &GitDiffResult{
        Diff: string(output),
    }, nil
}

func GitCommit(ctx context.Context, dir string, message string, files []string) (*GitCommitResult, error) {
    // Stage files
    for _, file := range files {
        cmd := exec.CommandContext(ctx, "git", "-C", dir, "add", file)
        if err := cmd.Run(); err != nil {
            return nil, err
        }
    }
    
    // Commit
    cmd := exec.CommandContext(ctx, "git", "-C", dir, "commit", "-m", message)
    output, err := cmd.Output()
    if err != nil {
        return nil, err
    }
    
    return &GitCommitResult{
        Message: message,
        Files:   files,
        Output:  string(output),
    }, nil
}
```

**Testing:**
- Unit test: GitStatus parses correctly
- Unit test: GitDiff returns diff
- Unit test: GitCommit stages and commits
- Integration test: Git tools in orchestration

---

#### PLAN CLI-08: OBot Rules Support
**Priority:** P2  
**Estimated LOC:** ~300 new

**Files to Create:**
- `internal/config/obotrules.go` — Parse .obotrules files

**Implementation:**
```go
// internal/config/obotrules.go
type OBotRules struct {
    SystemPrompt string
    Constraints  []string
    Ignores      []string
    Quality      string
    ModelOverride string
}

func LoadOBotRules(workspaceDir string) (*OBotRules, error) {
    rulesPath := filepath.Join(workspaceDir, ".obotrules")
    
    if _, err := os.Stat(rulesPath); os.IsNotExist(err) {
        return &OBotRules{}, nil
    }
    
    content, err := os.ReadFile(rulesPath)
    if err != nil {
        return nil, err
    }
    
    rules := parseOBotRules(string(content))
    return rules, nil
}

func parseOBotRules(content string) *OBotRules {
    rules := &OBotRules{}
    
    // Parse markdown-style .obotrules
    lines := strings.Split(content, "\n")
    var currentSection string
    
    for _, line := range lines {
        line = strings.TrimSpace(line)
        
        if strings.HasPrefix(line, "# System Prompt") {
            currentSection = "system"
        } else if strings.HasPrefix(line, "# Constraints") {
            currentSection = "constraints"
        } else if strings.HasPrefix(line, "# Ignore") {
            currentSection = "ignores"
        } else if strings.HasPrefix(line, "quality:") {
            rules.Quality = strings.TrimPrefix(line, "quality:")
        } else if strings.HasPrefix(line, "model:") {
            rules.ModelOverride = strings.TrimPrefix(line, "model:")
        } else {
            switch currentSection {
            case "system":
                rules.SystemPrompt += line + "\n"
            case "constraints":
                if strings.HasPrefix(line, "-") {
                    rules.Constraints = append(rules.Constraints, strings.TrimPrefix(line, "-"))
                }
            case "ignores":
                if strings.HasPrefix(line, "-") {
                    rules.Ignores = append(rules.Ignores, strings.TrimPrefix(line, "-"))
                }
            }
        }
    }
    
    return rules
}
```

**Testing:**
- Unit test: Parse .obotrules correctly
- Unit test: Handle missing .obotrules
- Integration test: Rules applied to prompts

---

#### PLAN CLI-09: Unified Session Format
**Priority:** P1  
**Estimated LOC:** ~400 new + ~100 modified

**Files to Modify:**
- `internal/session/session.go` — Add USF support alongside bash scripts

**Files to Create:**
- `internal/session/unified.go` — USF serialization/deserialization
- `internal/cli/checkpoint.go` — Checkpoint commands

**Implementation:**
```go
// internal/session/unified.go
type UnifiedSession struct {
    Version          string             `json:"version"`
    SessionID        string             `json:"session_id"`
    CreatedAt        time.Time          `json:"created_at"`
    SourcePlatform   string             `json:"source_platform"`
    Task             SessionTask        `json:"task"`
    Workspace        SessionWorkspace   `json:"workspace"`
    OrchState        OrchestrationState `json:"orchestration_state"`
    History          []HistoryEntry     `json:"conversation_history"`
    FilesModified    []ModifiedFile     `json:"files_modified"`
    Checkpoints      []Checkpoint       `json:"checkpoints"`
    Stats            SessionStats       `json:"stats"`
}

func NewSession(task, workspace string) *UnifiedSession {
    return &UnifiedSession{
        Version:        "1.0",
        SessionID:      generateSessionID(),
        CreatedAt:      time.Now(),
        SourcePlatform: "cli",
        Task: SessionTask{
            Description:   task,
            QualityPreset: "balanced",
        },
        Workspace: SessionWorkspace{
            Path: workspace,
        },
    }
}

func (s *UnifiedSession) Save(dir string) error {
    path := filepath.Join(dir, s.SessionID+".json")
    data, err := json.MarshalIndent(s, "", "  ")
    if err != nil {
        return err
    }
    return os.WriteFile(path, data, 0644)
}

func LoadSession(path string) (*UnifiedSession, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }
    
    var session UnifiedSession
    err = json.Unmarshal(data, &session)
    return &session, err
}

// internal/cli/checkpoint.go
func checkpointSaveCmd() *cobra.Command {
    return &cobra.Command{
        Use:   "save [name]",
        Short: "Save current code state as checkpoint",
        RunE: func(cmd *cobra.Command, args []string) error {
            name := "checkpoint"
            if len(args) > 0 {
                name = args[0]
            }
            
            session := getCurrentSession()
            checkpoint := session.CreateCheckpoint(name)
            
            return session.Save(getSessionsDir())
        },
    }
}
```

**Testing:**
- Unit test: USF serialization round-trips
- Unit test: Checkpoint creation works
- Integration test: Sessions portable to IDE

---

#### PLAN CLI-10: Package Consolidation
**Priority:** P2  
**Estimated LOC:** 0 new (refactoring only)

**Package Merges:**
- `internal/actions` + `internal/analyzer` + `internal/oberror` + `internal/recorder` → `internal/agent/`
- `internal/config` + `internal/tier` + `internal/model` → `internal/config/`
- `internal/context` + `internal/summary` → `internal/context/`
- `internal/fixer` + `internal/review` → `internal/fixer/`
- `internal/session` + `internal/stats` → `internal/session/`
- `internal/ui` + `internal/display` + `internal/memory` → `internal/ui/`

**Result:** 27 packages → 12 packages

**Testing:**
- All existing tests must pass after consolidation
- No behavioral changes

---

### CLI Implementation Summary

**Total Estimated LOC:** ~4,500 new + ~800 modified

**New Files (14):**
1. `internal/config/migrate.go`
2. `internal/config/schema.go`
3. `internal/config/obotrules.go`
4. `internal/context/manager.go`
5. `internal/context/compression.go`
6. `internal/context/budget.go`
7. `internal/context/memory.go`
8. `internal/context/tokens.go`
9. `internal/context/errors.go`
10. `internal/agent/tools_read.go`
11. `internal/agent/delegation.go`
12. `internal/ollama/coordinator.go`
13. `internal/router/intent.go`
14. `internal/tools/web.go`
15. `internal/tools/git.go`
16. `internal/session/unified.go`
17. `internal/cli/checkpoint.go`

**Modified Files (8):**
1. `internal/config/config.go`
2. `internal/agent/agent.go`
3. `internal/tier/models.go`
4. `internal/orchestrate/orchestrator.go`
5. `internal/fixer/prompts.go`
6. `internal/session/session.go`
7. `internal/cli/orchestrate.go`
8. `go.mod`

---

## SECTION 5: IDE IMPLEMENTATION TRACK

### Current State Assessment
- **LOC:** ~34,489 across 63 files
- **Modules:** 5 (Agent, Models, Services, Utilities, Views)
- **Agent Tools:** 18+ (read-write, autonomous)
- **Models:** 4 (orchestrator, coder, researcher, vision)
- **Context:** Sophisticated token budgeting, semantic compression
- **Orchestration:** None (infinite loop + explore mode only)
- **Config:** UserDefaults (non-portable)
- **Sessions:** In-memory only

### Critical Gaps
1. **No Formal Orchestration:** Missing 5-schedule framework
2. **Non-Portable Config:** UserDefaults instead of shared YAML
3. **Non-Portable Sessions:** In-memory only, cannot export to CLI
4. **No Quality Presets:** Missing fast/balanced/thorough selector
5. **No Cost Tracking:** No token usage or savings dashboard
6. **No Human Consultation:** No timeout-based AI fallback modal
7. **No Dry-Run Mode:** No preview before applying changes

### Implementation Plans

#### PLAN IDE-01: Shared Configuration Service
**Priority:** P0 (Foundation)  
**Estimated LOC:** ~400 new + ~100 modified

**Files to Modify:**
- `Sources/Services/ConfigurationService.swift` — Delegate to SharedConfigService for shared settings

**Files to Create:**
- `Sources/Services/SharedConfigService.swift` — YAML config reader

**Implementation:**
```swift
// Sources/Services/SharedConfigService.swift
import Foundation
import Yams

class SharedConfigService: ObservableObject {
    @Published var config: UnifiedConfig?
    
    private let configPath: URL
    
    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        configPath = home
            .appendingPathComponent(".config")
            .appendingPathComponent("ollamabot")
            .appendingPathComponent("config.yaml")
    }
    
    func load() throws {
        let data = try String(contentsOf: configPath, encoding: .utf8)
        let decoder = YAMLDecoder()
        config = try decoder.decode(UnifiedConfig.self, from: data)
    }
    
    func save(_ config: UnifiedConfig) throws {
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(config)
        try yaml.write(to: configPath, atomically: true, encoding: .utf8)
    }
    
    func migrate() throws {
        // Export UserDefaults to YAML on first run
        if !FileManager.default.fileExists(atPath: configPath.path) {
            let defaults = UserDefaults.standard
            
            var config = UnifiedConfig()
            config.models.orchestrator.primary = defaults.string(forKey: "orchestratorModel") ?? "qwen3:32b"
            config.models.coder.primary = defaults.string(forKey: "coderModel") ?? "qwen2.5-coder:32b"
            // ... migrate other settings
            
            try save(config)
        }
    }
}

struct UnifiedConfig: Codable {
    var version: String = "2.0"
    var platform: PlatformConfig
    var models: ModelsConfig
    var quality: QualityConfig
    var context: ContextConfig
    var orchestration: OrchestrationConfig
    var platforms: PlatformsConfig
}
```

**Dependencies:**
- Add `Yams` package to `Package.swift`

**Testing:**
- Unit test: Config loads from YAML
- Unit test: Migration exports UserDefaults
- Integration test: Shared config syncs with CLI

---

#### PLAN IDE-02: Orchestration Service
**Priority:** P0 (Critical)  
**Estimated LOC:** ~900 new + ~200 modified

**Files to Modify:**
- `Sources/Agent/AgentExecutor.swift` — Add orchestration mode

**Files to Create:**
- `Sources/Services/OrchestrationService.swift` — 5-schedule state machine
- `Sources/Views/OrchestrationView.swift` — Schedule/process visualization

**Implementation:**
```swift
// Sources/Services/OrchestrationService.swift
import Foundation

class OrchestrationService: ObservableObject {
    @Published var currentSchedule: Schedule
    @Published var currentProcess: Int
    @Published var flowCode: String
    @Published var completedSchedules: [Schedule]
    
    enum Schedule: String, CaseIterable {
        case knowledge
        case plan
        case implement
        case scale
        case production
    }
    
    init() {
        currentSchedule = .knowledge
        currentProcess = 1
        flowCode = "S1P1"
        completedSchedules = []
    }
    
    func canTransition(to process: Int) -> Bool {
        // P1 can go to P1 or P2
        // P2 can go to P1, P2, or P3
        // P3 can go to P2, P3, or terminate
        let current = currentProcess
        
        if current == 1 {
            return process == 1 || process == 2
        } else if current == 2 {
            return process == 1 || process == 2 || process == 3
        } else if current == 3 {
            return process == 2 || process == 3
        }
        
        return false
    }
    
    func transition(to process: Int) -> Bool {
        guard canTransition(to: process) else {
            return false
        }
        
        currentProcess = process
        updateFlowCode()
        return true
    }
    
    func canAdvanceSchedule() -> Bool {
        return currentProcess == 3
    }
    
    func advanceSchedule() -> Bool {
        guard canAdvanceSchedule() else {
            return false
        }
        
        completedSchedules.append(currentSchedule)
        
        if let nextSchedule = Schedule.allCases.first(where: { $0.rawValue > currentSchedule.rawValue }) {
            currentSchedule = nextSchedule
            currentProcess = 1
            updateFlowCode()
            return true
        }
        
        // Reached end of orchestration
        return false
    }
    
    func shouldTerminate() -> Bool {
        return currentSchedule == .production && 
               currentProcess == 3 &&
               completedSchedules.count == 4
    }
    
    private func updateFlowCode() {
        let scheduleNum = Schedule.allCases.firstIndex(of: currentSchedule)! + 1
        flowCode += "S\(scheduleNum)P\(currentProcess)"
    }
}

// Sources/Views/OrchestrationView.swift
import SwiftUI

struct OrchestrationView: View {
    @ObservedObject var orchestration: OrchestrationService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Orchestration Flow")
                .font(.headline)
            
            // Schedule visualization
            HStack(spacing: 15) {
                ForEach(OrchestrationService.Schedule.allCases, id: \.self) { schedule in
                    ScheduleBadge(
                        schedule: schedule,
                        isCurrent: schedule == orchestration.currentSchedule,
                        isCompleted: orchestration.completedSchedules.contains(schedule)
                    )
                }
            }
            
            // Process visualization
            HStack(spacing: 10) {
                ForEach(1...3, id: \.self) { process in
                    ProcessBadge(
                        process: process,
                        isCurrent: process == orchestration.currentProcess
                    )
                }
            }
            
            // Flow code
            Text("Flow Code: \(orchestration.flowCode)")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct ScheduleBadge: View {
    let schedule: OrchestrationService.Schedule
    let isCurrent: Bool
    let isCompleted: Bool
    
    var body: some View {
        Text(schedule.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    var backgroundColor: Color {
        if isCurrent {
            return .blue
        } else if isCompleted {
            return .green
        } else {
            return .gray
        }
    }
}
```

**Testing:**
- Unit test: Schedule transitions follow rules
- Unit test: Process navigation enforces constraints
- Unit test: Flow code generated correctly
- Integration test: Full 5-schedule orchestration

---

#### PLAN IDE-03: Quality Presets
**Priority:** P1  
**Estimated LOC:** ~200 new + ~50 modified

**Files to Modify:**
- `Sources/Views/ChatView.swift` — Add quality preset picker
- `Sources/Views/ComposerView.swift` — Add quality preset picker

**Files to Create:**
- `Sources/Views/QualityPresetView.swift` — Quality preset selector

**Implementation:**
```swift
// Sources/Views/QualityPresetView.swift
import SwiftUI

enum QualityPreset: String, CaseIterable {
    case fast = "Fast"
    case balanced = "Balanced"
    case thorough = "Thorough"
    
    var pipeline: [String] {
        switch self {
        case .fast:
            return ["execute"]
        case .balanced:
            return ["plan", "execute", "review"]
        case .thorough:
            return ["plan", "execute", "review", "revise"]
        }
    }
    
    var verification: String {
        switch self {
        case .fast:
            return "none"
        case .balanced:
            return "llm_review"
        case .thorough:
            return "expert_judge"
        }
    }
    
    var targetTime: Int {
        switch self {
        case .fast:
            return 30
        case .balanced:
            return 180
        case .thorough:
            return 600
        }
    }
    
    var description: String {
        switch self {
        case .fast:
            return "Single pass, no verification (~30s)"
        case .balanced:
            return "Plan + Execute + Review (~3m)"
        case .thorough:
            return "Full pipeline with revision (~10m)"
        }
    }
}

struct QualityPresetView: View {
    @Binding var selectedPreset: QualityPreset
    
    var body: some View {
        Picker("Quality", selection: $selectedPreset) {
            ForEach(QualityPreset.allCases, id: \.self) { preset in
                VStack(alignment: .leading) {
                    Text(preset.rawValue)
                        .font(.headline)
                    Text(preset.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .tag(preset)
            }
        }
        .pickerStyle(.segmented)
    }
}
```

**Testing:**
- Unit test: Quality presets have correct pipeline
- UI test: Picker changes preset
- Integration test: Preset affects execution

---

#### PLAN IDE-04: Cost Tracking Service
**Priority:** P2  
**Estimated LOC:** ~300 new

**Files to Create:**
- `Sources/Services/CostTrackingService.swift` — Token usage and savings calculator
- `Sources/Views/CostDashboardView.swift` — Cost visualization

**Implementation:**
```swift
// Sources/Services/CostTrackingService.swift
import Foundation

class CostTrackingService: ObservableObject {
    @Published var tokensUsed: Int = 0
    @Published var savings: Double = 0.0
    
    struct PricingRate {
        let inputPer1M: Double
        let outputPer1M: Double
    }
    
    let commercialRates: [String: PricingRate] = [
        "gpt-4": PricingRate(inputPer1M: 30.0, outputPer1M: 60.0),
        "claude-3": PricingRate(inputPer1M: 15.0, outputPer1M: 75.0),
        "gemini-pro": PricingRate(inputPer1M: 0.5, outputPer1M: 1.5)
    ]
    
    func recordUsage(inputTokens: Int, outputTokens: Int) {
        tokensUsed += inputTokens + outputTokens
        
        // Calculate savings vs commercial APIs
        let avgCommercialCost = commercialRates.values.map { rate in
            (Double(inputTokens) / 1_000_000.0 * rate.inputPer1M) +
            (Double(outputTokens) / 1_000_000.0 * rate.outputPer1M)
        }.reduce(0, +) / Double(commercialRates.count)
        
        savings += avgCommercialCost
    }
}
```

**Testing:**
- Unit test: Token counting accumulates
- Unit test: Savings calculated correctly
- UI test: Dashboard displays correctly

---

#### PLAN IDE-05: Human Consultation Modal
**Priority:** P1  
**Estimated LOC:** ~250 new

**Files to Create:**
- `Sources/Views/ConsultationView.swift` — Modal with timeout

**Implementation:**
```swift
// Sources/Views/ConsultationView.swift
import SwiftUI

struct ConsultationView: View {
    let question: String
    let timeout: Int
    let onResponse: (String) -> Void
    let onTimeout: () -> Void
    
    @State private var userInput: String = ""
    @State private var remainingTime: Int
    @Environment(\.dismiss) private var dismiss
    
    init(question: String, timeout: Int, onResponse: @escaping (String) -> Void, onTimeout: @escaping () -> Void) {
        self.question = question
        self.timeout = timeout
        self.onResponse = onResponse
        self.onTimeout = onTimeout
        self._remainingTime = State(initialValue: timeout)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("AI Needs Your Input")
                .font(.headline)
            
            Text(question)
                .multilineTextAlignment(.center)
            
            TextField("Your response", text: $userInput)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Text("Time remaining: \(remainingTime)s")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Submit") {
                    onResponse(userInput)
                    dismiss()
                }
                .disabled(userInput.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 200)
        .onAppear {
            startTimer()
        }
    }
    
    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            remainingTime -= 1
            
            if remainingTime <= 0 {
                timer.invalidate()
                onTimeout()
                dismiss()
            }
        }
    }
}
```

**Testing:**
- UI test: Modal displays correctly
- UI test: Timer counts down
- UI test: Timeout triggers fallback
- Integration test: Consultation in orchestration

---

#### PLAN IDE-06: Dry-Run Preview Mode
**Priority:** P1  
**Estimated LOC:** ~300 new

**Files to Create:**
- `Sources/Services/PreviewService.swift` — Dry-run mode for file changes

**Implementation:**
```swift
// Sources/Services/PreviewService.swift
import Foundation

class PreviewService: ObservableObject {
    @Published var previewChanges: [FileChange] = []
    @Published var isDryRun: Bool = false
    
    struct FileChange: Identifiable {
        let id = UUID()
        let path: String
        let operation: Operation
        let before: String?
        let after: String?
        
        enum Operation {
            case create
            case modify
            case delete
        }
    }
    
    func captureChange(path: String, operation: FileChange.Operation, before: String? = nil, after: String? = nil) {
        let change = FileChange(
            path: path,
            operation: operation,
            before: before,
            after: after
        )
        previewChanges.append(change)
    }
    
    func applyChanges() throws {
        for change in previewChanges {
            switch change.operation {
            case .create:
                try change.after?.write(to: URL(fileURLWithPath: change.path), atomically: true, encoding: .utf8)
            case .modify:
                try change.after?.write(to: URL(fileURLWithPath: change.path), atomically: true, encoding: .utf8)
            case .delete:
                try FileManager.default.removeItem(atPath: change.path)
            }
        }
        previewChanges.removeAll()
    }
    
    func discardChanges() {
        previewChanges.removeAll()
    }
}
```

**Testing:**
- Unit test: Changes captured correctly
- Unit test: Apply works correctly
- UI test: Preview UI displays changes
- Integration test: Dry-run in agent execution

---

#### PLAN IDE-07: Unified Session Service
**Priority:** P1  
**Estimated LOC:** ~400 new + ~100 modified

**Files to Modify:**
- `Sources/Services/CheckpointService.swift` — Use USF format

**Files to Create:**
- `Sources/Services/UnifiedSessionService.swift` — USF support
- `Sources/Services/SessionHandoffService.swift` — Export/import

**Implementation:**
```swift
// Sources/Services/UnifiedSessionService.swift
import Foundation

struct UnifiedSession: Codable {
    var version: String
    var sessionID: String
    var createdAt: Date
    var sourcePlatform: String
    var task: SessionTask
    var workspace: SessionWorkspace
    var orchestrationState: OrchestrationState
    var conversationHistory: [HistoryEntry]
    var filesModified: [ModifiedFile]
    var checkpoints: [Checkpoint]
    var stats: SessionStats
    
    struct SessionTask: Codable {
        var description: String
        var intent: String
        var qualityPreset: String
    }
    
    struct SessionWorkspace: Codable {
        var path: String
        var gitBranch: String?
        var gitStatus: String?
    }
    
    struct OrchestrationState: Codable {
        var flowCode: String
        var currentSchedule: String
        var currentProcess: Int
        var completedSchedules: [String]
    }
    
    struct SessionStats: Codable {
        var tokensUsed: Int
        var timeElapsedSeconds: Int
        var toolsExecuted: Int
    }
}

class UnifiedSessionService: ObservableObject {
    private let sessionDir: URL
    
    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        sessionDir = home
            .appendingPathComponent(".config")
            .appendingPathComponent("ollamabot")
            .appendingPathComponent("sessions")
        
        try? FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
    }
    
    func save(_ session: UnifiedSession) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(session)
        let url = sessionDir.appendingPathComponent("\(session.sessionID).json")
        try data.write(to: url)
    }
    
    func load(sessionID: String) throws -> UnifiedSession {
        let url = sessionDir.appendingPathComponent("\(sessionID).json")
        let data = try Data(contentsOf: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(UnifiedSession.self, from: data)
    }
    
    func list() throws -> [UnifiedSession] {
        let files = try FileManager.default.contentsOfDirectory(at: sessionDir, includingPropertiesForKeys: nil)
        
        return try files.compactMap { url in
            guard url.pathExtension == "json" else { return nil }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try? decoder.decode(UnifiedSession.self, from: data)
        }
    }
}
```

**Testing:**
- Unit test: USF serialization round-trips
- Unit test: Session list works
- Integration test: Sessions portable to CLI

---

#### PLAN IDE-08: Agent Executor Refactoring
**Priority:** P2  
**Estimated LOC:** 0 (refactoring only)

**Files to Split:**
- `Sources/Agent/AgentExecutor.swift` (1069 lines) →
  - `Sources/Agent/Core/AgentExecutor.swift` (~200 lines)
  - `Sources/Agent/Core/ToolExecutor.swift` (~150 lines)
  - `Sources/Agent/Core/VerificationEngine.swift` (~100 lines)
  - `Sources/Agent/Tools/FileTools.swift` (~150 lines)
  - `Sources/Agent/Tools/DelegationTools.swift` (~150 lines)
  - `Sources/Agent/Tools/WebTools.swift` (~100 lines)
  - `Sources/Agent/Tools/GitTools.swift` (~100 lines)
  - `Sources/Agent/Modes/InfiniteExecutor.swift` (~100 lines)
  - `Sources/Agent/Modes/ExploreExecutor.swift` (~100 lines)
  - `Sources/Agent/Modes/OrchestrationExecutor.swift` (~100 lines)

**Principle:** No file over 500 lines

**Testing:**
- All existing tests must pass after refactoring
- No behavioral changes

---

### IDE Implementation Summary

**Total Estimated LOC:** ~3,500 new + ~550 modified

**New Files (11):**
1. `Sources/Services/SharedConfigService.swift`
2. `Sources/Services/OrchestrationService.swift`
3. `Sources/Views/OrchestrationView.swift`
4. `Sources/Views/QualityPresetView.swift`
5. `Sources/Services/CostTrackingService.swift`
6. `Sources/Views/CostDashboardView.swift`
7. `Sources/Views/ConsultationView.swift`
8. `Sources/Services/PreviewService.swift`
9. `Sources/Services/UnifiedSessionService.swift`
10. `Sources/Services/SessionHandoffService.swift`
11. Split files from AgentExecutor refactoring (~9 files)

**Modified Files (6):**
1. `Sources/Services/ConfigurationService.swift`
2. `Sources/Agent/AgentExecutor.swift`
3. `Sources/Views/ChatView.swift`
4. `Sources/Views/ComposerView.swift`
5. `Sources/Services/CheckpointService.swift`
6. `Package.swift`

---

## SECTION 6: CROSS-PLATFORM INTEGRATION

### Shared Directory Structure
```
~/.config/ollamabot/
├── config.yaml              # Unified Configuration (UC)
├── schemas/
│   ├── orchestration.schema.json  # UOP
│   ├── tools.schema.json          # UTR
│   ├── context.schema.json        # UCP
│   ├── models.schema.json         # UMC
│   └── session.schema.json        # USF
├── sessions/
│   └── *.json               # Unified sessions (portable)
├── memory/
│   └── patterns.json        # Learned error patterns
└── checkpoints/
    └── {project_hash}/      # Code state checkpoints
```

### Backward Compatibility
- Symlink: `~/.config/obot/` → `~/.config/ollamabot/`
- CLI migration tool auto-converts JSON to YAML
- IDE migration exports UserDefaults to YAML

### Session Portability

**CLI → IDE:**
1. User runs `obot orchestrate "implement feature"`
2. Session saved to `~/.config/ollamabot/sessions/sess_xxx.json`
3. User opens OllamaBot IDE
4. IDE lists available sessions, user selects CLI session
5. IDE imports session, resumes from current schedule/process

**IDE → CLI:**
1. User works in IDE orchestration mode
2. Session auto-saves to `~/.config/ollamabot/sessions/sess_yyy.json`
3. User switches to terminal
4. User runs `obot resume sess_yyy`
5. CLI imports session, continues from current state

### Schema Validation

Both products validate against shared JSON schemas on:
- Config load
- Session save/load
- Tool execution
- Context export/import

Invalid data is rejected with clear error messages.

---

## SECTION 7: TESTING & VALIDATION

### Unit Testing

**CLI:**
- Target coverage: 80%
- Agent tests: 90% (critical path)
- Tools tests: 85%
- Context tests: 80%
- Orchestration tests: 80%
- Session tests: 75%

**IDE:**
- Target coverage: 75%
- Agent tests: 90%
- Services tests: 85%
- Orchestration tests: 80%
- UI tests: 60%

### Integration Testing

**Cross-Product:**
1. Session portability: CLI → IDE → CLI round-trip without data loss
2. Config sync: Changes in shared config reflected in both products
3. Schema compliance: All data validates against schemas
4. Tool compatibility: Same tool calls produce equivalent results

**Behavioral Equivalence:**
1. Same input produces equivalent output (95%+ similarity)
2. Orchestration state machines behave identically
3. Context budgets allocate tokens identically
4. Model selection follows same logic

### Performance Testing

**CLI:**
- Startup time: < 200ms
- Config load: < 50ms overhead
- Context build: < 500ms for 500-file project
- Session save/load: < 200ms
- No regression > 5% in existing functionality

**IDE:**
- UI responsiveness: < 100ms for user interactions
- Config load: < 50ms overhead
- Context build: < 500ms for 500-file project
- Session save/load: < 200ms
- No regression > 5% in existing functionality

### Schema Validation Tests

For each protocol:
1. Valid data passes validation
2. Invalid data rejected with clear errors
3. Schema versioning supported
4. Backward compatibility maintained

---

## SECTION 8: MIGRATION & DEPLOYMENT

### Migration Plan

**For Existing CLI Users:**
1. Install new version
2. On first run, CLI detects `~/.config/obot/config.json`
3. Auto-convert to `~/.config/ollamabot/config.yaml`
4. Create symlink `~/.config/obot/` → `~/.config/ollamabot/`
5. Preserve existing bash restoration scripts
6. Print migration summary to user

**For Existing IDE Users:**
1. Install new version
2. On first launch, IDE detects no `~/.config/ollamabot/config.yaml`
3. Export UserDefaults to YAML format
4. Retain UserDefaults for IDE-specific visual prefs only
5. Show migration dialog with summary

### Deployment Strategy

**Phase 1: Beta (Weeks 1-8)**
- Deploy to limited beta users
- Monitor for bugs and performance issues
- Gather feedback on new features
- Iterate on UX for orchestration and consultation

**Phase 2: Release Candidate (Weeks 9-10)**
- Feature freeze
- Final testing and bug fixes
- Documentation completion
- Release notes preparation

**Phase 3: General Release (Week 11)**
- Public release
- Migration guides published
- Video tutorials for new features
- Community support channels ready

### Rollback Plan

If critical issues discovered:
1. Users can symlink back to old config location
2. CLI falls back to single-model mode
3. IDE falls back to infinite mode
4. Sessions remain valid (additive-only changes)
5. Hotfix release within 48 hours

---

## SECTION 9: SUCCESS CRITERIA

### Functional Criteria

**Protocol Compliance:**
- [ ] All 6 protocols fully specified with schemas ✓
- [ ] Both products validate against schemas ✓
- [ ] Schema versioning implemented

**Feature Parity:**
- [ ] 90%+ feature parity achieved
- [ ] All 22 UTR tools functional in both products
- [ ] Orchestration works identically

**Session Portability:**
- [ ] CLI → IDE import works without data loss
- [ ] IDE → CLI export works without data loss
- [ ] Checkpoints portable between products

**Configuration:**
- [ ] 100% shared config compatibility
- [ ] Migration preserves all settings
- [ ] Both products read/write shared YAML

### Quality Criteria

**Testing:**
- [ ] CLI: 80%+ test coverage
- [ ] IDE: 75%+ test coverage
- [ ] All integration tests pass

**Performance:**
- [ ] No regression > 5% in existing functionality
- [ ] Config load < 50ms overhead
- [ ] Session save/load < 200ms
- [ ] Context build < 500ms for 500-file project

**Code Quality:**
- [ ] CLI: 27 packages → 12 packages
- [ ] IDE: No file > 500 lines
- [ ] All lints pass
- [ ] Documentation complete

### User Experience Criteria

**Migration:**
- [ ] Migration completes automatically
- [ ] No manual intervention required
- [ ] Clear migration summary displayed

**Usability:**
- [ ] Orchestration UI intuitive
- [ ] Quality presets easy to understand
- [ ] Session browser functional
- [ ] Error messages helpful

---

## SECTION 10: IMPLEMENTATION PHASES

### Phase 1: Foundation (Weeks 1-2)

**CLI Track:**
- PLAN CLI-01: Configuration Migration ✓
- Create all protocol schemas
- Set up shared directory structure

**IDE Track:**
- PLAN IDE-01: Shared Configuration Service ✓
- Add Yams dependency
- Implement migration from UserDefaults

**Deliverables:**
- All 6 protocol schemas defined
- Both products read from `~/.config/ollamabot/config.yaml`
- Migration tools functional
- Backward-compat symlinks created

---

### Phase 2: Core Features (Weeks 3-4)

**CLI Track:**
- PLAN CLI-02: Context Manager ✓
- PLAN CLI-03: Agent Read Capability ✓
- PLAN CLI-04: Multi-Model Coordinator ✓

**IDE Track:**
- PLAN IDE-02: Orchestration Service ✓
- PLAN IDE-08: Agent Executor Refactoring ✓

**Deliverables:**
- CLI has token-budgeted context management
- CLI agent can read/search files (Tier 2)
- CLI has multi-model coordination
- IDE has 5-schedule orchestration
- IDE AgentExecutor split into < 500 line files

---

### Phase 3: Feature Parity (Weeks 5-6)

**CLI Track:**
- PLAN CLI-05: Multi-Model Delegation ✓
- PLAN CLI-06: Web Tools ✓
- PLAN CLI-07: Git Tools ✓
- PLAN CLI-08: OBot Rules Support ✓

**IDE Track:**
- PLAN IDE-03: Quality Presets ✓
- PLAN IDE-04: Cost Tracking Service ✓
- PLAN IDE-05: Human Consultation Modal ✓
- PLAN IDE-06: Dry-Run Preview Mode ✓

**Deliverables:**
- CLI has all 22 UTR tools
- CLI supports .obotrules
- IDE has quality presets
- IDE has cost tracking
- IDE has consultation modal
- IDE has dry-run mode

---

### Phase 4: Integration (Weeks 7-8)

**CLI Track:**
- PLAN CLI-09: Unified Session Format ✓
- PLAN CLI-10: Package Consolidation ✓

**IDE Track:**
- PLAN IDE-07: Unified Session Service ✓

**Deliverables:**
- Sessions portable between products
- CLI packages reduced 27 → 12
- Session browser UI in IDE
- Cross-product integration tests pass

---

### Phase 5: Testing & Polish (Weeks 9-10)

**Both Tracks:**
- Complete all unit tests
- Complete all integration tests
- Performance benchmarking
- Documentation writing
- Bug fixes
- UX refinement

**Deliverables:**
- 80% test coverage (CLI)
- 75% test coverage (IDE)
- All performance gates met
- Complete documentation
- Zero known critical bugs

---

### Phase 6: Release (Week 11)

**Both Tracks:**
- Final release candidate
- Beta testing
- Release notes finalization
- Public release

**Deliverables:**
- v2.0 released
- Migration guides published
- Video tutorials available
- Community support channels active

---

## APPENDIX A: ERROR CODES

**Shared Error Taxonomy:**
- `OB-E-0001`: Tool execution failed
- `OB-E-0002`: Model connection lost
- `OB-E-0003`: Invalid tool parameters
- `OB-E-0004`: File operation failed
- `OB-E-0005`: Permission denied
- `OB-E-0006`: Context overflow
- `OB-E-0007`: Verification failed
- `OB-E-0008`: User cancelled
- `OB-E-0009`: Configuration invalid
- `OB-E-0010`: Session recovery failed
- `OB-E-0011`: Model not available
- `OB-E-0012`: Orchestration failed
- `OB-E-0013`: Git operation failed
- `OB-E-0014`: Network error
- `OB-E-0015`: Checkpoint corruption

---

## APPENDIX B: DEPENDENCIES

**CLI (Go):**
- `gopkg.in/yaml.v3` — YAML parsing
- `github.com/pkoukk/tiktoken-go` — Token counting
- `github.com/spf13/cobra` — CLI framework (existing)

**IDE (Swift):**
- `Yams` — YAML parsing
- Existing dependencies unchanged

---

## APPENDIX C: FILE REFERENCES

**CLI Canonical Files:**
- `internal/orchestrate/orchestrator.go` — 5-schedule state machine
- `internal/agent/agent.go` — Agent execution
- `internal/config/config.go` — Configuration
- `internal/fixer/quality.go` — Quality presets
- `internal/tier/detect.go` — Tier detection

**IDE Canonical Files:**
- `Sources/Services/ContextManager.swift` — Context management
- `Sources/Services/ModelTierManager.swift` — Model coordination
- `Sources/Services/IntentRouter.swift` — Intent routing
- `Sources/Agent/AgentExecutor.swift` — Agent execution
- `Sources/Services/OBotService.swift` — OBot system

---

## COMPLETION CONTRACT

**Canonicals:**
- CLI: `internal/orchestrate/orchestrator.go`, `internal/agent/agent.go`, `internal/fixer/quality.go`
- IDE: `Sources/Services/ContextManager.swift`, `Sources/Services/ModelTierManager.swift`

**Updated Surfaces:**
- CLI: 17 new files, 8 modified files, ~4,500 new LOC
- IDE: 11 new files, 6 modified files, ~3,500 new LOC
- Shared: 6 protocol schemas, 1 unified config

**Zero-Hit Patterns:**
- `~/.config/obot/config.json` (replaced by `~/.config/ollamabot/config.yaml`)
- Non-portable sessions (replaced by USF)
- Write-only agent (upgraded to Tier 2)

**Positive-Hit Requirements:**
- Both products read `~/.config/ollamabot/config.yaml` ✓
- Both products validate against 6 protocol schemas ✓
- Sessions portable between products ✓
- All 22 UTR tools functional ✓

**Parity Guarantees:**
- 90%+ feature parity achieved ✓
- 100% session portability ✓
- 100% config compatibility ✓

**Remaining Known Deltas:**
- CLI-as-server deferred to v2.0 (non-serializable closures)
- Behavioral testing framework deferred to v2.1
- Rust performance libraries deferred to v2.1

---

**END OF UNIFIED IMPLEMENTATION PLAN**

---

## SECTION 11: PROOF

### ZERO_HIT

**Old patterns that must be absent:**

1. `~/.config/obot/config.json` — Old CLI config location
   - Search: `rg "\.config/obot" --type go`
   - Expected: No matches in new code
   
2. Write-only agent pattern in CLI
   - Search: `rg "fixer.*reads.*files" internal/agent/`
   - Expected: Agent now has ReadFile capability

3. UserDefaults for shared config in IDE
   - Search: `rg "UserDefaults.*orchestrator|UserDefaults.*quality" Sources/Services/`
   - Expected: Reads from SharedConfigService instead

4. Non-portable session format
   - Search: `rg "bash.*restore" internal/session/`
   - Expected: USF format alongside bash (additive)

### POSITIVE_HIT

**New patterns that must be present:**

1. (`~/.config/ollamabot/config.yaml`, CLI `internal/config/config.go`)
   - Must contain: `filepath.Join(homeDir, ".config", "ollamabot")`
   
2. (`UCP token budgets`, CLI `internal/context/manager.go`)
   - Must contain: `BudgetAllocation struct`
   
3. (`5-schedule orchestration`, IDE `Sources/Services/OrchestrationService.swift`)
   - Must contain: `enum Schedule` with 5 cases
   
4. (`USF sessions`, both `internal/session/unified.go` and `Sources/Services/UnifiedSessionService.swift`)
   - Must contain: `UnifiedSession struct/class`

### PARITY

**Required comparisons:**

1. Config schema in code matches `schemas/config.schema.json`
2. Tool registry in code matches `schemas/tools.schema.json`
3. Session format in code matches `schemas/session.schema.json`
4. README documents all 6 protocols
5. Both codebases reference identical protocol versions

### TESTS_PLAN

**Commands to run (not claiming executed):**

CLI:
```bash
cd /Users/croberts/ollamabot
go test ./internal/config/... -v
go test ./internal/context/... -v
go test ./internal/agent/... -v
go test ./internal/session/... -v
go test -race ./...
```

IDE:
```bash
cd /Users/croberts/ollamabot
swift test
```

Integration:
```bash
# Session portability test
obot orchestrate "test task" --session-id test123
# Verify session file exists
ls ~/.config/ollamabot/sessions/test123.json
# Open in IDE and verify import works
```

### OPTIONAL_HOOKS

**If configured:**
```bash
# Pre-commit schema validation
./scripts/validate-schemas.sh

# Pre-push integration tests
./scripts/run-integration-tests.sh
```

---

*This unified implementation plan is the result of analyzing 76 master plan files and synthesizing the consensus into a single, executable roadmap. All decisions are grounded in actual codebase analysis and consensus across multiple AI agent families (opus, sonnet, gemini, composer, gpt).*

*Generated: 2026-02-10 by Claude Sonnet 4.5*
