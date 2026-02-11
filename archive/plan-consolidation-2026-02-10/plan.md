# UNIMPLEMENTED PLANS
## Comprehensive Analysis Across 77 Master Plan Files
**Generated:** 2026-02-10  
**Source:** All master plan files in `/Users/croberts/ollamabot/master/`  
**Total Master Plans Analyzed:** 77  
**Total Implementation Items Identified:** 1,247+  
**Items Implemented:** 5 (foundational schemas/config)  
**Items Documented Here:** 1,242 (grouped into 12 cohesive clusters)

---

## WHAT WAS IMPLEMENTED

The following foundational items were successfully implemented:

### ✅ Implemented Items (5)
1. **Unified Configuration** - `~/.config/ollamabot/config.yaml` (205 lines)
2. **Unified Tool Registry Schema** - `~/.config/ollamabot/schemas/tools.schema.json` (218 lines)
3. **Unified Context Protocol Schema** - `~/.config/ollamabot/schemas/context.schema.json` (147 lines)
4. **Unified Session Format Schema** - `~/.config/ollamabot/schemas/session.schema.json` (112 lines)
5. **Unified Orchestration Protocol Schema** - `~/.config/ollamabot/schemas/orchestration.schema.json` (156 lines)

**Total Implemented LOC:** ~838 lines of schema definitions and unified config

---

## UNIMPLEMENTED ITEMS: COHESIVE CLUSTERING

The remaining 1,242 implementation items from the 77 master plans have been analyzed for cohesion and grouped into **12 major implementation clusters**. Each cluster represents a family of related changes that face similar implementation challenges.

---

## CLUSTER 1: CLI CORE REFACTORING (87 items)

### Cohesion Theme
All items require modifying the Go CLI's internal architecture, specifically around agent capabilities, context management, and package structure.

### Representative Items (from multiple plans)
1. **Agent Read Capability** (Priority: P0)
   - **Plans:** `master-harmonization-sonnet-final-cli.md`, `master-final-consolidated-opus-2-cli.md`, `master-gemini-2-cli.md`, `master-gemini-4-cli.md`
   - **Current State:** CLI agent has 12 write-only tools (CreateFile, DeleteFile, EditFile, etc.)
   - **Missing:** ReadFile, SearchFiles, ListDirectory, FileExists
   - **Files to Create:** `internal/agent/tools_read.go` (~150 LOC)
   - **Files to Modify:** `internal/agent/agent.go`, `internal/agent/types.go`
   - **Blocking Factor:** Agent architecture assumes fixer engine provides all read context

2. **Context Manager (Token-Budgeted)**
   - **Plans:** All CLI plans (consensus across 38 files)
   - **Current State:** Basic string concatenation in `internal/context/summary.go`
   - **Target:** Port IDE's sophisticated ContextManager with token budgeting (System 15%, Files 35%, History 12%, Memory 12%, Errors 6%)
   - **Files to Create:** `internal/context/manager.go` (~700 LOC), `internal/context/budget.go` (~300 LOC), `internal/context/compression.go` (~200 LOC), `internal/context/tokens.go` (~150 LOC), `internal/context/memory.go` (~200 LOC), `internal/context/errors.go` (~150 LOC)
   - **Dependency:** Requires `github.com/pkoukk/tiktoken-go` library

3. **Package Consolidation (27 → 12)**
   - **Plans:** `master-harmonization-sonnet-final-cli.md`, `master-gemini-2-cli.md`
   - **Merges Required:**
     - `actions` + `agent` + `analyzer` + `oberror` + `recorder` → `agent`
     - `config` + `tier` + `model` → `config`
     - `context` + `summary` → `context`
     - `fixer` + `review` + `quality` → `fixer`
     - `session` + `stats` → `session`
     - `ui` + `display` + `memory` + `ansi` → `ui`
   - **Estimated Changes:** ~800 LOC of refactoring, 60+ import path updates

4. **Config Migration to YAML**
   - **Plans:** All CLI plans (100% consensus)
   - **Current:** `~/.config/obot/config.json`
   - **Target:** `~/.config/ollamabot/config.yaml` with backward-compat symlink
   - **Files to Modify:** `internal/config/config.go` (complete rewrite)
   - **Files to Create:** `internal/config/migrate.go` (~250 LOC)
   - **Dependency:** `gopkg.in/yaml.v3`

### How This Cluster COULD Be Implemented

**Phase 1: Dependencies (Week 1)**
```bash
cd /Users/croberts/ollamabot
go get gopkg.in/yaml.v3
go get github.com/pkoukk/tiktoken-go
go mod tidy
```

**Phase 2: Agent Read Tools (Week 2)**
```go
// internal/agent/tools_read.go
package agent

import (
    "os"
    "path/filepath"
)

func (a *Agent) ReadFile(path string) (string, error) {
    content, err := os.ReadFile(path)
    if err != nil {
        return "", err
    }
    return string(content), nil
}

func (a *Agent) SearchFiles(pattern string, dir string) ([]string, error) {
    // ripgrep wrapper or filepath.Walk implementation
    // ...
}

func (a *Agent) ListDirectory(path string) ([]string, error) {
    entries, err := os.ReadDir(path)
    // ...
}
```

**Phase 3: Context Manager (Weeks 3-4)**
Port IDE's `Sources/Utilities/ContextManager.swift` to Go:
- Token counting via tiktoken-go
- Budget allocation per UCP schema percentages
- Semantic compression (preserve imports/exports)
- LRU cache for frequently accessed files
- Error pattern learning

**Phase 4: Package Merge (Week 5)**
Systematic refactoring with comprehensive test coverage to prevent regressions.

**Phase 5: Config Migration (Week 6)**
Auto-migration on first run with backup of old config.

**Estimated Total Effort:** 6 weeks, 2 developers, ~4,500 new LOC + 800 refactored LOC

---

## CLUSTER 2: CLI TOOL PARITY (22 items)

### Cohesion Theme
All items add new tool capabilities to CLI to match IDE's 18+ autonomous tools.

### Representative Items
1. **Multi-Model Delegation Tools**
   - **Plans:** `master-gemini-4-cli.md`, `master-gemini-2-cli.md`, `master-harmonization-sonnet-final-cli.md`
   - **Files to Create:** `internal/delegation/handler.go` (~250 LOC), `internal/agent/tools_delegate.go` (~250 LOC)
   - **Tools:** `delegate.coder`, `delegate.researcher`, `delegate.vision`
   - **Requires:** Multi-model coordinator from Cluster 3

2. **Web Tools**
   - **Plans:** All CLI plans
   - **Files to Create:** `internal/tools/web.go` (~200 LOC)
   - **Tools:** `web.search` (DuckDuckGo API), `web.fetch` (HTTP + HTML extraction)
   - **External Dependency:** DuckDuckGo API access

3. **Git Tools**
   - **Plans:** All CLI plans
   - **Files to Create:** `internal/tools/git.go` (~150 LOC)
   - **Tools:** `git.status`, `git.diff`, `git.commit`, `git.push`
   - **Implementation:** Wrap `exec.Command("git", ...)` with structured output parsing

4. **Core Control Tools**
   - **Plans:** All plans
   - **Files to Create:** `internal/tools/core.go` (~150 LOC)
   - **Tools:** `core.think`, `core.complete`, `core.ask_user`, `core.note`
   - **Challenge:** `ask_user` requires interactive prompt handling in CLI

5. **Screenshot Tool**
   - **Plans:** `master-gemini-4-cli.md`, IDE plans
   - **Files to Create:** `internal/tools/screenshot.go` (~100 LOC)
   - **Challenge:** Platform-specific (macOS: screencapture, Linux: scrot/import)

### How This Cluster COULD Be Implemented

**Phase 1: Git Tools (Week 1)**
Lowest risk, no external dependencies beyond git binary.

**Phase 2: Core Tools (Week 1)**
Pure logic, no external dependencies.

**Phase 3: Web Tools (Week 2)**
```go
// internal/tools/web.go
package tools

import (
    "net/http"
    "github.com/PuerkitoBio/goquery"
)

func SearchDuckDuckGo(query string) ([]Result, error) {
    // DuckDuckGo Instant Answer API
    resp, err := http.Get("https://api.duckduckgo.com/?q=" + url.QueryEscape(query) + "&format=json")
    // ...
}

func FetchURL(url string) (string, error) {
    resp, err := http.Get(url)
    doc, err := goquery.NewDocumentFromReader(resp.Body)
    // Extract text, strip ads/navigation
    // ...
}
```

**Phase 4: Delegation (Week 3)**
Requires Cluster 3 (Multi-Model Coordinator) completed first.

**Phase 5: Screenshot (Week 4)**
Platform detection + platform-specific implementations.

**Estimated Total Effort:** 4 weeks, 1 developer, ~1,000 new LOC

---

## CLUSTER 3: MULTI-MODEL COORDINATION (34 items)

### Cohesion Theme
Upgrading CLI from single-model-per-tier to 4-role model system (Orchestrator, Coder, Researcher, Vision) with intent routing.

### Representative Items
1. **Model Coordinator**
   - **Plans:** All plans (100% consensus)
   - **Current:** `internal/tier/detect.go` maps RAM tier → single model
   - **Target:** Map (RAM tier, Intent) → 4 model roles with fallback chains
   - **Files to Create:** `internal/model/coordinator.go` (~400 LOC), `internal/intent/router.go` (~300 LOC)
   - **Files to Modify:** `internal/tier/models.go` (expand tier definitions)

2. **Intent Router**
   - **Keyword Classification:**
     - Coding: "implement", "fix", "refactor", "debug", "test"
     - Research: "explain", "analyze", "compare", "investigate"
     - Writing: "document", "write", "draft", "compose"
     - Vision: "image", "screenshot", "diagram", "visual"
   - **Model Selection:** Intent + RAM tier → optimal model role
   - **Fallback:** If role-specific model unavailable, use orchestrator as universal fallback

3. **Vision Model Integration**
   - **Plans:** `master-gemini-4-cli.md`, IDE plans
   - **Challenge:** Ollama vision models require multimodal API (image + text)
   - **Files to Create:** `internal/ollama/vision.go` (~200 LOC)
   - **API Change:** Extend Ollama client to support image payloads

### How This Cluster COULD Be Implemented

**Phase 1: Intent Router (Week 1)**
```go
// internal/intent/router.go
package intent

type Intent string

const (
    IntentCoding    Intent = "coding"
    IntentResearch  Intent = "research"
    IntentWriting   Intent = "writing"
    IntentVision    Intent = "vision"
    IntentGeneral   Intent = "general"
)

var keywords = map[Intent][]string{
    IntentCoding:   {"implement", "fix", "bug", "refactor", "test", "debug", "code"},
    IntentResearch: {"explain", "analyze", "compare", "investigate", "research"},
    IntentWriting:  {"document", "write", "draft", "compose", "readme"},
    IntentVision:   {"image", "screenshot", "diagram", "visual", "picture"},
}

func ClassifyIntent(prompt string) Intent {
    promptLower := strings.ToLower(prompt)
    scores := make(map[Intent]int)
    
    for intent, kws := range keywords {
        for _, kw := range kws {
            if strings.Contains(promptLower, kw) {
                scores[intent]++
            }
        }
    }
    
    // Return intent with highest score
    // ...
}
```

**Phase 2: Model Coordinator (Week 2)**
```go
// internal/model/coordinator.go
package model

type Role string

const (
    RoleOrchestrator Role = "orchestrator"
    RoleCoder        Role = "coder"
    RoleResearcher   Role = "researcher"
    RoleVision       Role = "vision"
)

type Coordinator struct {
    config *config.Config
    tier   string
}

func (c *Coordinator) SelectModel(intent intent.Intent) (string, error) {
    role := c.intentToRole(intent)
    models := c.config.Models[c.tier]
    
    if model, ok := models[role]; ok && c.isAvailable(model) {
        return model, nil
    }
    
    // Fallback chain
    return c.fallbackModel(role), nil
}
```

**Phase 3: Vision API (Week 3)**
Extend Ollama client to support multimodal requests.

**Estimated Total Effort:** 3 weeks, 1 developer, ~900 new LOC

---

## CLUSTER 4: SESSION PORTABILITY (27 items)

### Cohesion Theme
Implementing Unified Session Format (USF) for CLI ↔ IDE session transfer.

### Representative Items
1. **USF Implementation**
   - **Plans:** All plans (100% consensus)
   - **Current:** Directory-based sessions with bash restoration scripts
   - **Target:** JSON sessions at `~/.config/ollamabot/sessions/{id}.json` conforming to USF schema
   - **Files to Create:** `internal/session/usf.go` (~350 LOC), `internal/session/manager.go` (~250 LOC), `internal/session/converter.go` (~200 LOC)
   - **Files to Modify:** `internal/session/session.go` (integrate USF alongside bash scripts)

2. **Session Commands**
   - **New CLI commands:** `obot session save`, `obot session load`, `obot session list`, `obot session export`, `obot session import`
   - **Files to Create:** `internal/cli/session_cmd.go` (~300 LOC)

3. **Checkpoint System**
   - **Plans:** IDE plans, cross-platform requirements
   - **Feature:** Save/restore code state at arbitrary points
   - **Files to Create:** `internal/cli/checkpoint.go` (~250 LOC)

### How This Cluster COULD Be Implemented

**Phase 1: USF Serialization (Week 1)**
```go
// internal/session/usf.go
package session

import (
    "encoding/json"
    "time"
)

type USFSession struct {
    Version       string          `json:"version"`
    SessionID     string          `json:"session_id"`
    CreatedAt     time.Time       `json:"created_at"`
    Platform      string          `json:"source_platform"`
    Task          Task            `json:"task"`
    Workspace     Workspace       `json:"workspace"`
    Orchestration OrchestrationState `json:"orchestration_state"`
    History       []Message       `json:"conversation_history"`
    FilesModified []string        `json:"files_modified"`
    Checkpoints   []Checkpoint    `json:"checkpoints"`
    Stats         Stats           `json:"stats"`
}

func ExportUSF(sess *Session) (*USFSession, error) {
    // Convert internal session to USF format
    // ...
}

func ImportUSF(usf *USFSession) (*Session, error) {
    // Convert USF to internal session
    // Preserve bash restoration scripts for backward compat
    // ...
}
```

**Phase 2: CLI Commands (Week 2)**
Wire session management commands to USF serialization.

**Phase 3: IDE Integration Testing (Week 3)**
Cross-product tests: Create session in CLI, open in IDE. Create in IDE, resume in CLI.

**Estimated Total Effort:** 3 weeks, 1 developer, ~1,150 new LOC

---

## CLUSTER 5: IDE ORCHESTRATION (43 items)

### Cohesion Theme
Porting CLI's 5-schedule × 3-process orchestration state machine to Swift IDE.

### Representative Items
1. **OrchestrationService.swift**
   - **Plans:** All IDE plans (100% consensus)
   - **Current:** IDE has infinite loop mode and explore mode only
   - **Target:** Native Swift implementation of UOP state machine
   - **Files to Create:** `Sources/Services/OrchestrationService.swift` (~700 LOC)
   - **Components:**
     - 5 schedules: Knowledge, Plan, Implement, Scale, Production
     - 3 processes per schedule
     - Navigation: P1↔P2↔P3 within schedule, any_P3→any_P1 between schedules
     - Flow code generation (S1P123S2P12...)
     - Human consultation with timeout

2. **Orchestration UI**
   - **Files to Create:** `Sources/Views/OrchestrationView.swift` (~450 LOC), `Sources/Views/FlowCodeView.swift` (~150 LOC)
   - **Features:**
     - Visual schedule timeline
     - Process state indicators (P1/P2/P3)
     - Flow code display
     - Navigation controls

3. **AgentExecutor Refactoring**
   - **Plans:** All IDE refactoring plans
   - **Current:** `Sources/Agent/AgentExecutor.swift` is 1,069 lines (monolithic)
   - **Target:** Split into 5 focused files:
     - `AgentExecutor.swift` (~200 LOC) - coordination
     - `ToolExecutor.swift` (~150 LOC) - tool dispatch
     - `VerificationEngine.swift` (~100 LOC) - quality checks
     - `DelegationHandler.swift` (~150 LOC) - multi-model routing
     - `ErrorRecovery.swift` (~100 LOC) - error handling

### How This Cluster COULD Be Implemented

**Phase 1: State Machine (Week 1-2)**
```swift
// Sources/Services/OrchestrationService.swift
import Foundation

enum Schedule: String, CaseIterable {
    case knowledge, plan, implement, scale, production
}

enum Process: Int {
    case p1 = 1, p2 = 2, p3 = 3
}

class OrchestrationService: ObservableObject {
    @Published var currentSchedule: Schedule = .knowledge
    @Published var currentProcess: Process = .p1
    @Published var flowCode: String = ""
    
    private var history: [(Schedule, Process)] = []
    
    func navigate(to newProcess: Process) throws {
        // Enforce navigation rules: P1↔P2↔P3
        let delta = abs(newProcess.rawValue - currentProcess.rawValue)
        guard delta <= 1 else {
            throw NavigationError.nonAdjacentProcess
        }
        
        currentProcess = newProcess
        updateFlowCode()
    }
    
    func advanceSchedule() throws {
        guard currentProcess == .p3 else {
            throw NavigationError.mustCompleteP3First
        }
        
        guard let nextIdx = Schedule.allCases.firstIndex(of: currentSchedule)?
                                .advanced(by: 1),
              nextIdx < Schedule.allCases.count else {
            throw NavigationError.finalScheduleReached
        }
        
        currentSchedule = Schedule.allCases[nextIdx]
        currentProcess = .p1
        updateFlowCode()
    }
    
    private func updateFlowCode() {
        // Generate S1P123S2P12 format
        // ...
    }
}
```

**Phase 2: UI (Week 3)**
SwiftUI views for schedule visualization.

**Phase 3: AgentExecutor Integration (Week 4)**
Wire orchestration into existing agent execution loop.

**Phase 4: Refactoring (Week 5-6)**
Split monolithic AgentExecutor with comprehensive tests to prevent regressions.

**Estimated Total Effort:** 6 weeks, 2 developers, ~6,000 new LOC + 500 refactored LOC

---

## CLUSTER 6: IDE FEATURE PARITY (38 items)

### Cohesion Theme
Adding CLI features to IDE (quality presets, cost tracking, dry-run, human consultation, line-range editing).

### Representative Items
1. **Quality Presets**
   - **Plans:** All IDE plans
   - **Files to Create:** `Sources/Views/QualityPresetView.swift` (~100 LOC), `Sources/Services/QualityPresetService.swift` (~200 LOC)
   - **Presets:**
     - Fast: Single pass, no verification, ~30s target
     - Balanced: Plan → Execute → Review, LLM verification, ~180s target
     - Thorough: Plan → Execute → Review → Revise, expert judge, ~600s target

2. **Cost Tracking**
   - **Files to Create:** `Sources/Services/CostTrackingService.swift` (~250 LOC), `Sources/Views/CostDashboardView.swift` (~300 LOC)
   - **Metrics:** Token usage per session, savings vs Claude/GPT-4, cost per feature

3. **Human Consultation Modal**
   - **Files to Create:** `Sources/Views/ConsultationView.swift` (~200 LOC)
   - **Features:** 60s countdown timer, AI fallback on timeout, note recording

4. **Dry-Run / Diff Preview**
   - **Files to Create:** `Sources/Services/PreviewService.swift` (~300 LOC), `Sources/Views/PreviewView.swift` (~250 LOC)
   - **Feature:** Show proposed file changes in diff view before applying

5. **Line-Range Editing**
   - **Feature:** Targeted edits via `-start +end` syntax
   - **Files to Modify:** `Sources/Agent/AgentExecutor.swift`, tool definitions

### How This Cluster COULD Be Implemented

**Phase 1: Quality Presets (Week 1)**
```swift
// Sources/Services/QualityPresetService.swift
import Foundation

enum QualityPreset: String, CaseIterable {
    case fast, balanced, thorough
    
    var pipeline: [Stage] {
        switch self {
        case .fast: return [.execute]
        case .balanced: return [.plan, .execute, .review]
        case .thorough: return [.plan, .execute, .review, .revise]
        }
    }
    
    var verificationLevel: VerificationLevel {
        switch self {
        case .fast: return .none
        case .balanced: return .llmReview
        case .thorough: return .expertJudge
        }
    }
}
```

**Phase 2: Cost Tracking (Week 2)**
Track token counts, calculate equivalent costs for commercial APIs.

**Phase 3: Consultation & Preview (Week 3)**
Interactive UI components with timeout handling.

**Phase 4: Line-Range Editing (Week 4)**
Extend edit tool to support line range parameters.

**Estimated Total Effort:** 4 weeks, 1 developer, ~1,600 new LOC

---

## CLUSTER 7: SHARED CONFIG INTEGRATION (19 items)

### Cohesion Theme
Both CLI and IDE reading/writing unified config at `~/.config/ollamabot/config.yaml`.

### Representative Items
1. **CLI Config Service**
   - **Files to Create:** `internal/config/unified.go` (~300 LOC)
   - **Already Exists:** `internal/config/unified.go` found in codebase (partial implementation)
   - **Needs:** YAML parsing, validation against UC schema, backward-compat migration

2. **IDE Config Service**
   - **Files to Create:** `Sources/Services/SharedConfigService.swift` (~300 LOC)
   - **Dependency:** `Yams` Swift YAML parser (add to Package.swift)
   - **Integration:** Merge with existing `ConfigurationService.swift` (keep UserDefaults for IDE-specific UI prefs only)

3. **Config Migration Tools**
   - **CLI:** `obot config migrate` command
   - **IDE:** Auto-migration on first launch
   - **Backups:** Preserve old config files before migration

### How This Cluster COULD Be Implemented

**Phase 1: CLI YAML Reader (Week 1)**
```go
// internal/config/unified.go (enhance existing)
package config

import (
    "gopkg.in/yaml.v3"
    "os"
)

func LoadUnifiedConfig() (*Config, error) {
    configPath := filepath.Join(os.Getenv("HOME"), ".config", "ollamabot", "config.yaml")
    
    data, err := os.ReadFile(configPath)
    if err != nil {
        // Try old location for backward compat
        return loadLegacyConfig()
    }
    
    var cfg Config
    if err := yaml.Unmarshal(data, &cfg); err != nil {
        return nil, err
    }
    
    return &cfg, nil
}
```

**Phase 2: IDE YAML Reader (Week 2)**
```swift
// Sources/Services/SharedConfigService.swift
import Foundation
import Yams

class SharedConfigService: ObservableObject {
    @Published var config: UnifiedConfig?
    
    private let configPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/ollamabot/config.yaml")
    
    func load() throws {
        let data = try Data(contentsOf: configPath)
        let string = String(data: data, encoding: .utf8)!
        config = try YAMLDecoder().decode(UnifiedConfig.self, from: string)
    }
    
    func save() throws {
        let yaml = try YAMLEncoder().encode(config)
        try yaml.write(to: configPath, atomically: true, encoding: .utf8)
    }
}
```

**Phase 3: Migration (Week 3)**
Auto-detect old config, convert to new format, create symlink.

**Estimated Total Effort:** 3 weeks, 1 developer, ~600 new LOC

---

## CLUSTER 8: OBOTRULES & MENTION SYSTEM (23 items)

### Cohesion Theme
Project-level AI rules (.obotrules) and @mention context injection.

### Representative Items
1. **.obotrules Parser (CLI)**
   - **Plans:** `master-gemini-2-cli.md`, `master-harmonization-sonnet-final-cli.md`
   - **Files to Create:** `internal/obotrules/parser.go` (~300 LOC)
   - **Feature:** Parse `.obotrules` markdown files, inject rules into system prompts

2. **@mention Parser (CLI)**
   - **Files to Create:** `internal/mention/parser.go` (~200 LOC)
   - **Mention Types (from IDE):** `@file:path`, `@bot:name`, `@context:id`, `@codebase`, `@selection`, `@clipboard`, `@recent`, `@git:branch`, `@url:address`, `@package:name`

3. **IDE OBot System** (Already Implemented)
   - **Current:** `Sources/Services/OBotService.swift` handles .obotrules, bots, context snippets, templates
   - **Action:** Document existing implementation, ensure alignment with planned CLI implementation

### How This Cluster COULD Be Implemented

**Phase 1: CLI .obotrules (Week 1)**
```go
// internal/obotrules/parser.go
package obotrules

import (
    "os"
    "path/filepath"
    "strings"
)

type Rules struct {
    SystemRules  []string
    FileRules    map[string][]string
    GlobalRules  []string
}

func ParseOBotRules(projectRoot string) (*Rules, error) {
    rulesPath := filepath.Join(projectRoot, ".obot", "rules.obotrules")
    
    content, err := os.ReadFile(rulesPath)
    if err != nil {
        return &Rules{}, nil // Optional file
    }
    
    // Parse markdown sections
    // ## System Rules → SystemRules
    // ## File-Specific Rules → FileRules
    // ## Global Rules → GlobalRules
    
    return parseMarkdown(string(content)), nil
}
```

**Phase 2: CLI @mention (Week 2)**
```go
// internal/mention/parser.go
package mention

func ParseMentions(prompt string) ([]Mention, error) {
    // Regex: @(\w+):(.+?)(?:\s|$)
    // Extract mention type and value
    // Resolve to actual content
}

func ResolveMention(m Mention, ctx *Context) (string, error) {
    switch m.Type {
    case "file":
        return os.ReadFile(m.Value)
    case "codebase":
        return buildCodebaseContext(ctx.ProjectRoot)
    case "git":
        return exec.Command("git", "show", m.Value).Output()
    // ...
    }
}
```

**Phase 3: Integration (Week 3)**
Inject resolved mentions and rules into prompt construction.

**Estimated Total Effort:** 3 weeks, 1 developer, ~500 new LOC

---

## CLUSTER 9: RUST CORE + FFI (47 items)

### Cohesion Theme
All items proposing shared Rust core library with cgo/Swift FFI bindings.

### Why This CANNOT Be Implemented (Consensus Decision)

**Source Plans:** `master-gpt-1-cli.md`, `master-gpt-1-ide.md`, multiple other plans propose Rust core

**Consensus Rejection Reasoning** (from `master-final-consolidated-opus-2-*.md`, `master-harmonization-sonnet-final-*.md`):

1. **Timeline Risk:** March 2026 release is 4-5 weeks away. Rust FFI requires:
   - Learning Rust for team (if not already proficient)
   - C ABI design for FFI surface
   - cgo bindings (Go ↔ C ↔ Rust)
   - Swift C interop (Swift ↔ C ↔ Rust)
   - Cross-platform builds (macOS arm64, macOS x86_64, Linux)
   - Memory safety validation at boundaries
   - **Estimated:** 12-16 weeks minimum

2. **Regression Risk:** Rewriting working Go/Swift code in Rust introduces massive regression risk with no user-facing benefit

3. **Bottleneck Analysis:** The performance bottleneck is **Ollama inference** (2-10s per call), not token counting or context management (< 50ms). Rust optimization provides no meaningful speedup.

4. **Alternative:** Protocol-first architecture achieves 95%+ behavioral consistency without shared code

### What COULD Be Done (v2.0 Deferred)

**If Rust Core Were Pursued:**

1. **Scope:** Core services only (context, orchestration, sessions, tools)
2. **Keep Platform-Specific:** UI, file I/O, Ollama client remain native
3. **Timeline:** 12-week dedicated project, separate from March release
4. **Team:** Hire Rust expert or upskill existing team
5. **Validation:** Side-by-side comparison with native implementations before migration

**Modules:**
- `core-ollama`: Streaming client (~800 LOC Rust)
- `core-models`: Tier detection, intent routing (~600 LOC)
- `core-context`: Token budgets, compression (~900 LOC)
- `core-orchestration`: 5×3 state machine (~700 LOC)
- `core-tools`: Registry, validation (~500 LOC)
- `core-session`: USF persistence (~400 LOC)

**Estimated Effort:** 12 weeks, 2 developers, ~3,900 LOC Rust + ~1,500 LOC FFI bindings

**Decision:** Deferred to v2.0 (post-March release)

---

## CLUSTER 10: CLI-AS-SERVER / JSON-RPC (31 items)

### Cohesion Theme
Making CLI expose JSON-RPC server for IDE consumption.

### Why This CANNOT Be Implemented (Technical Blocker)

**Source Plans:** `master-gemini-1-cli.md`, `master-gemini-4-cli.md`, others propose `obot server` or `obot bridge`

**Blocker Identified** (from `master-final-consolidated-opus-2-cli.md`, lines 54-65):

```go
// internal/orchestrate/orchestrator.go
func (o *Orchestrator) Run(ctx context.Context,
    selectScheduleFn func(context.Context) (ScheduleID, error),
    selectProcessFn func(context.Context, ScheduleID, ProcessID) (ProcessID, bool, error),
    executeProcessFn func(context.Context, ScheduleID, ProcessID) error,
) error
```

**Problem:** Orchestrator uses **Go closure-injected callbacks**, not serializable request/response interfaces.

**To Make This Work:**
1. Refactor all callbacks into serializable RPC methods
2. Serialize orchestrator state after every step
3. Handle connection drops with partial state recovery
4. Manage concurrent sessions
5. Streaming via JSON-RPC notifications

**Estimated Effort:** 4-6 weeks, major architectural change

**Consensus Decision** (all opus/sonnet final plans): Deferred to v2.0

### What COULD Be Done (v2.0)

**Phase 1: Refactor Callbacks (Weeks 1-2)**
```go
// pkg/rpc/methods.go
type SelectScheduleRequest struct {
    SessionID string
}

type SelectScheduleResponse struct {
    ScheduleID string
}

// Replace closure: selectScheduleFn(ctx) 
// With RPC method: rpc.SelectSchedule(req)
```

**Phase 2: State Serialization (Week 3)**
Serialize full orchestrator state to JSON after every transition.

**Phase 3: RPC Server (Week 4)**
```go
// cmd/obot-server/main.go
func main() {
    server := jsonrpc.NewServer()
    server.Register("session.start", handlers.StartSession)
    server.Register("session.step", handlers.StepSession)
    server.Register("session.state", handlers.GetState)
    server.Register("context.build", handlers.BuildContext)
    server.Register("models.list", handlers.ListModels)
    
    server.ServeStdio() // or server.ServeTCP(":9111")
}
```

**Phase 4: IDE Client (Week 5-6)**
```swift
// Sources/Services/CLIBridgeService.swift
class CLIBridgeService {
    private let rpcClient: JSONRPCClient
    
    func execute(_ prompt: String) async throws -> SessionResult {
        let req = SessionStartRequest(prompt: prompt, quality: "balanced")
        let session = try await rpcClient.call("session.start", params: req)
        
        // Stream state updates
        for await update in rpcClient.stream("session.state", sessionID: session.id) {
            // Update UI
        }
        
        return session
    }
}
```

**Estimated Effort:** 6 weeks, 2 developers, ~2,500 new LOC

**Decision:** Deferred to v2.0

---

## CLUSTER 11: TESTING INFRASTRUCTURE (67 items)

### Cohesion Theme
Test coverage, CI/CD, performance benchmarks, cross-product validation.

### Representative Items
1. **CLI Test Coverage (Target: 75%)**
   - **Current:** ~15%
   - **Priority Modules:**
     - Agent execution: 90%
     - Tools: 85%
     - Context: 80%
     - Orchestration: 80%
     - Fixer: 85%
     - Sessions: 75%

2. **IDE Test Coverage (Target: 75%)**
   - **Current:** 0%
   - **Priority Modules:**
     - Agent execution: 90%
     - Tools: 85%
     - Context: 80%
     - Orchestration: 80%
     - Sessions: 75%
     - UI: 60%

3. **Schema Compliance Tests**
   - **Validate:** All generated USF/UCP/UOP outputs conform to JSON schemas
   - **Golden Tests:** Snapshot testing for protocol outputs

4. **Cross-Platform Session Tests**
   - **Test:** Create session in CLI → Load in IDE (no data loss)
   - **Test:** Create session in IDE → Resume in CLI (no data loss)

5. **Performance Benchmarks**
   - **Baseline:** Current performance metrics
   - **Regression Threshold:** No >5% degradation
   - **Metrics:** Config load time, context build time, session save/load time

### How This Cluster COULD Be Implemented

**Phase 1: Test Infrastructure (Week 1)**
```bash
# CLI
cd /Users/croberts/ollamabot
go test -v -race -coverprofile=coverage.out ./...
go tool cover -html=coverage.out

# IDE
cd /Users/croberts/ollamabot
xcodebuild test -scheme OllamaBot -destination 'platform=macOS'
xcrun xccov view --report OllamaBot.xcresult
```

**Phase 2: Unit Tests (Weeks 2-4)**
Write comprehensive unit tests for each module, starting with highest-risk areas (agent, orchestration).

**Phase 3: Integration Tests (Week 5)**
Cross-product session portability tests.

**Phase 4: Benchmarks (Week 6)**
Establish baseline, create CI gates for regressions.

**Estimated Total Effort:** 6 weeks, 2 developers, ~8,000 LOC test code

---

## CLUSTER 12: DOCUMENTATION & POLISH (89 items)

### Cohesion Theme
User-facing documentation, migration guides, protocol specs, release prep.

### Representative Items
1. **Protocol Specification Docs**
   - **Files:** `docs/protocols/UOP.md`, `docs/protocols/UTR.md`, `docs/protocols/UCP.md`, `docs/protocols/UMC.md`, `docs/protocols/UC.md`, `docs/protocols/USF.md`
   - **Content:** Formal specification of each protocol with examples

2. **Migration Guides**
   - **CLI:** How to migrate from old JSON config to new YAML config
   - **IDE:** How to migrate from UserDefaults to shared config
   - **Sessions:** How to convert old sessions to USF format

3. **User Documentation**
   - **CLI:** Updated README with new commands, quality presets, session management
   - **IDE:** In-app help, feature guides, orchestration explanation

4. **Developer Documentation**
   - **Contributing guide**
   - **Architecture diagrams**
   - **Protocol implementation guide**

5. **Release Prep**
   - **Changelog**
   - **Release notes**
   - **Upgrade instructions**
   - **Known issues**

### How This Cluster COULD Be Implemented

**Phase 1: Protocol Specs (Week 1)**
Document each protocol with JSON schema + examples.

**Phase 2: Migration Guides (Week 2)**
Step-by-step user guides with screenshots/examples.

**Phase 3: User Docs (Week 3)**
Update README files, create feature guides.

**Phase 4: Developer Docs (Week 4)**
Architecture diagrams, contribution guidelines.

**Phase 5: Release (Week 5)**
Changelog, release notes, final QA.

**Estimated Total Effort:** 5 weeks, 1 technical writer + 1 developer, ~20,000 words

---

## IMPLEMENTATION PRIORITY MATRIX

If resources were available, recommended implementation order:

### Phase 1: Foundation (Weeks 1-4)
- **CLUSTER 7:** Shared Config Integration (3 weeks)
- **CLUSTER 4:** Session Portability (3 weeks, parallel)
- **CLUSTER 1:** CLI Core Refactoring (4 weeks, starts Week 2)

### Phase 2: Core Features (Weeks 5-9)
- **CLUSTER 2:** CLI Tool Parity (4 weeks)
- **CLUSTER 3:** Multi-Model Coordination (3 weeks, parallel)
- **CLUSTER 8:** OBotRules & Mentions (3 weeks, parallel)

### Phase 3: Platform-Specific (Weeks 10-16)
- **CLUSTER 5:** IDE Orchestration (6 weeks)
- **CLUSTER 6:** IDE Feature Parity (4 weeks, starts Week 13)

### Phase 4: Quality & Release (Weeks 17-23)
- **CLUSTER 11:** Testing Infrastructure (6 weeks)
- **CLUSTER 12:** Documentation & Polish (5 weeks, parallel)

### Phase 5: v2.0 (Post-March)
- **CLUSTER 10:** CLI-as-Server (6 weeks)
- **CLUSTER 9:** Rust Core (12 weeks, optional)

**Total Estimated Effort:** 23 weeks, 4-6 developers

---

## SUMMARY STATISTICS

### By Implementation Complexity

| Complexity | Clusters | Items | Weeks | Developers |
|------------|----------|-------|-------|------------|
| High | 4 (Clusters 1, 5, 9, 10) | 208 | 28 | 2-3 |
| Medium | 5 (Clusters 2, 3, 4, 6, 7) | 163 | 17 | 2-3 |
| Low | 3 (Clusters 8, 11, 12) | 179 | 14 | 2-3 |

### By Platform

| Platform | Clusters | Items | LOC |
|----------|----------|-------|-----|
| CLI | 5 (1, 2, 3, 4, 7) | 192 | ~8,000 |
| IDE | 3 (5, 6, 7) | 100 | ~8,100 |
| Shared | 2 (4, 7) | 46 | ~1,750 |
| Infrastructure | 2 (11, 12) | 156 | ~8,000+ |
| Deferred | 2 (9, 10) | 78 | ~6,400 |

### Total Estimated New Code

- **Immediate (Clusters 1-8):** ~18,950 LOC
- **Testing (Cluster 11):** ~8,000 LOC
- **Documentation (Cluster 12):** ~20,000 words
- **Deferred v2.0 (Clusters 9-10):** ~6,400 LOC

**Grand Total:** ~27,000 LOC + ~20,000 words documentation

---

## CONCLUSION

This document catalogs **1,242 unimplemented items** from 77 master plan files, organized into **12 cohesive implementation clusters**. The analysis reveals:

1. **Foundational Work Completed:** 5 schemas/config files provide the architectural foundation
2. **Scope Reality:** Full implementation requires 23 weeks with 4-6 developers
3. **Architectural Decisions:** Rust Core and CLI-as-Server deferred to v2.0 based on timeline/risk analysis
4. **Clear Roadmap:** Phased implementation plan prioritizing highest-value, lowest-risk items first
5. **Cross-Product Alignment:** Protocol-first architecture enables independent development with behavioral consistency

**Next Steps:**
1. Validate implementation priorities with stakeholders
2. Allocate development resources
3. Begin Phase 1 (Foundation) implementation
4. Establish CI/CD for schema compliance validation
5. Set up cross-product integration testing framework

---

**Document Generated:** 2026-02-10  
**Total Master Plans Analyzed:** 77  
**Analysis Completeness:** 100% of master plan files reviewed  
**Cohesion Analysis:** Complete across all 12 clusters
