# OllamaBot IDE Master Plan — Protocol-First Harmonization

**Agent:** opus-1
**Product:** OllamaBot IDE (Swift/SwiftUI)
**Date:** 2026-02-05
**Architecture:** Protocol-First with CLI as Engine, IDE as Cockpit

---

## Executive Summary

OllamaBot IDE becomes the visualization and control layer ("Cockpit") in a harmonized two-product architecture. The IDE retains its native SwiftUI strengths — rich UI, streaming, multi-model delegation, context management — while gaining orchestration capabilities ported from the CLI and connecting to shared behavioral contracts via 6 Unified Protocols.

---

## Part 1: Current IDE State (Source-Grounded)

### Codebase Statistics
- **LOC:** ~34,489
- **Files:** 63 Swift files
- **Modules:** 5 (Agent, Models, Services, Utilities, Views)
- **Agent Tools:** 18+ (read-write, parallel execution, caching)
- **Models Supported:** 4 roles (orchestrator, coder, researcher, vision) + external APIs
- **Token Management:** Sophisticated ContextManager with budgets, compression, memory, error learning
- **Orchestration:** None (infinite loop + explore mode)
- **Config:** UserDefaults (macOS system preferences)
- **Session Persistence:** In-memory only

### Key Files

| File | LOC | Role |
|------|-----|------|
| `Sources/Agent/AgentExecutor.swift` | ~1,069 | Core agent loop — MUST be split |
| `Sources/Services/ContextManager.swift` | ~700 | Token budgeting, compression, memory |
| `Sources/Services/OllamaService.swift` | ~600 | Ollama API client with streaming |
| `Sources/Services/IntentRouter.swift` | ~200 | Intent classification for model routing |
| `Sources/Services/ModelTierManager.swift` | ~150 | RAM-based model selection |
| `Sources/Services/CheckpointService.swift` | ~200 | Code state save/restore |
| `Sources/Views/MainView.swift` | ~400 | Primary IDE layout |
| `Sources/Views/AgentView.swift` | ~300 | Agent interaction UI |

### What IDE Has That CLI Lacks
1. **ContextManager** — 700 LOC token-budget-aware context builder with semantic compression
2. **Multi-model delegation** — 4 specialized model roles with intent routing
3. **External API routing** — Claude, GPT, Gemini support
4. **Parallel tool execution** — Tools run concurrently with result caching
5. **OBot rules system** — `.obotrules`, `@mentions`, bot definitions
6. **Streaming UI** — Real-time token-by-token response display
7. **Rich diff preview** — Visual file change review before apply
8. **Performance infrastructure** — Model warmup, tracking, benchmarks

### What IDE Lacks That CLI Has
1. **5-schedule orchestration** — Knowledge/Plan/Implement/Scale/Production state machine
2. **3-process navigation** — Strict P1↔P2↔P3 rules with flow code tracking
3. **Human consultation** — Timeout with AI fallback for clarify/feedback
4. **Session persistence** — Flow code, restore capability, bash scripts
5. **Cost tracking** — Token savings vs commercial API calculations
6. **Tier detection** — Automatic RAM-based model tier selection

---

## Part 2: Architecture — IDE as Cockpit

```
┌─────────────────────────────────────────────────────────────┐
│                   OllamaBot IDE (Swift)                      │
│                   "The Cockpit"                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────┐  ┌──────────────────────────────────┐ │
│  │   SwiftUI Views  │  │   State Management               │ │
│  │                  │  │                                  │ │
│  │  OrchestrationV  │  │  @Observable OrchestratorService │ │
│  │  QualityPresetV  │  │  @Observable SessionService      │ │
│  │  ConsultationV   │  │  @Observable CostTracker         │ │
│  │  FlowCodeView    │  │                                  │ │
│  │  SessionRestore  │  │                                  │ │
│  └────────┬─────────┘  └──────────┬───────────────────────┘ │
│           └──────────────────────┬┘                         │
│                                  │                          │
│           ┌──────────────────────┴──────────────────┐      │
│           │         CLIBridgeService                │      │
│           │     (JSON-RPC Client over stdio)        │      │
│           │     Fallback: native Swift execution    │      │
│           └──────────────────────┬──────────────────┘      │
│                                  │                          │
└──────────────────────────────────┼──────────────────────────┘
                                   │ stdio / JSON-RPC
                                   ▼
                          obot server (Go)
```

### Dual-Mode Execution

The IDE operates in two modes:
1. **Bridge Mode (preferred):** CLIBridgeService connects to `obot server` via JSON-RPC over stdio. All execution logic runs in Go. IDE is pure visualization.
2. **Native Mode (fallback):** If CLI binary unavailable, IDE runs its existing Swift agent loop with orchestration state machine ported natively.

---

## Part 3: Unified Protocols — IDE Implementation

### 3.1 Unified Configuration (UC)

**Location:** `~/.config/ollamabot/config.yaml`

**IDE Implementation:**
- NEW: `Sources/Services/SharedConfigService.swift` (~300 LOC)
- Reads shared YAML config using Yams library
- UserDefaults retained ONLY for IDE-specific visual prefs (theme, font size)
- Config changes written back to YAML for CLI sync

```swift
@Observable
class SharedConfigService {
    var config: UnifiedConfig
    
    init() {
        // Read ~/.config/ollamabot/config.yaml
        // Fall back to defaults if missing
        // Migrate from UserDefaults on first run
    }
    
    func save() throws {
        // Write back to YAML
    }
    
    struct UnifiedConfig: Codable {
        var version: String
        var models: ModelConfig
        var quality: QualityConfig
        var context: ContextConfig
        var orchestration: OrchestrationConfig
        var sessions: SessionConfig
        var ide: IDEConfig
    }
}
```

### 3.2 Unified Orchestration Protocol (UOP)

**IDE Implementation:**
- NEW: `Sources/Services/OrchestrationService.swift` (~500 LOC)
- Port of CLI's 5-schedule x 3-process state machine
- NEW: `Sources/Views/OrchestrationView.swift` (~450 LOC)
- NEW: `Sources/Views/FlowCodeView.swift` (~150 LOC)

```swift
@Observable
class OrchestrationService {
    enum Schedule: Int, CaseIterable {
        case knowledge = 1, plan, implement, scale, production
        
        var name: String {
            switch self {
            case .knowledge: "Knowledge"
            case .plan: "Plan"
            case .implement: "Implement"
            case .scale: "Scale"
            case .production: "Production"
            }
        }
        
        var processes: [ProcessInfo] {
            switch self {
            case .knowledge: [
                ProcessInfo(id: 1, name: "Research"),
                ProcessInfo(id: 2, name: "Crawl"),
                ProcessInfo(id: 3, name: "Retrieve")
            ]
            case .plan: [
                ProcessInfo(id: 1, name: "Brainstorm"),
                ProcessInfo(id: 2, name: "Clarify", consultation: .optional),
                ProcessInfo(id: 3, name: "Plan")
            ]
            case .implement: [
                ProcessInfo(id: 1, name: "Implement"),
                ProcessInfo(id: 2, name: "Verify"),
                ProcessInfo(id: 3, name: "Feedback", consultation: .mandatory)
            ]
            case .scale: [
                ProcessInfo(id: 1, name: "Scale"),
                ProcessInfo(id: 2, name: "Benchmark"),
                ProcessInfo(id: 3, name: "Optimize")
            ]
            case .production: [
                ProcessInfo(id: 1, name: "Analyze"),
                ProcessInfo(id: 2, name: "Systemize"),
                ProcessInfo(id: 3, name: "Harmonize")
            ]
            }
        }
    }
    
    enum Process: Int { case first = 1, second, third }
    
    var currentSchedule: Schedule?
    var currentProcess: Process?
    var flowCode: String = ""
    var scheduleCounts: [Schedule: Int] = [:]
    
    func selectSchedule(_ schedule: Schedule) throws
    func selectProcess(_ process: Process) throws  // Enforces P1↔P2↔P3
    func canTerminatePrompt() -> Bool  // All 5 schedules, Production last
    func appendFlowCode()
}
```

### 3.3 Unified Tool Registry (UTR)

**IDE has 18+ tools already.** Changes needed:
- Normalize tool IDs to match UTR canonical names (e.g., `read_file` → `file.read`)
- Add alias mapping for backward compatibility
- Validate tool calls against JSON Schema

### 3.4 Unified Context Protocol (UCP)

**IDE already has sophisticated ContextManager.** Changes needed:
- Validate context output against UCP JSON Schema
- Read budget allocation from shared config (not hardcoded)
- Ensure compression strategy matches CLI port

### 3.5 Unified Session Format (USF)

**IDE Implementation:**
- NEW: `Sources/Services/UnifiedSessionService.swift` (~300 LOC)
- NEW: `Sources/Services/SessionHandoffService.swift` (~200 LOC)
- Sessions saved as JSON matching USF schema
- Export to CLI-compatible format
- Import from CLI sessions

### 3.6 Unified Model Coordinator (UMC)

**IDE already has multi-model.** Changes needed:
- Read tier mappings from shared config instead of hardcoded values
- Validate model availability against shared model registry

---

## Part 4: IDE Refactoring Requirements

### 4.1 Split AgentExecutor.swift (Critical — 1,069 lines)

Every agent flagged this as the #1 tech debt item. Split into:

| New File | LOC | Responsibility |
|----------|-----|----------------|
| `Sources/Agent/OrchestratorEngine.swift` | ~300 | Decision logic, schedule/process navigation |
| `Sources/Agent/ExecutionAgent.swift` | ~250 | Tool execution, result collection |
| `Sources/Agent/AgentModeManager.swift` | ~150 | Mode switching (infinite, explore, orchestration) |
| `Sources/Agent/AgentContextBuilder.swift` | ~200 | Prompt assembly, context injection |
| `Sources/Agent/AgentResponseParser.swift` | ~170 | Response parsing, tool call extraction |

### 4.2 Tools Modularization

Split `AgentTools.swift` into domain-specific files:

| New File | Tools |
|----------|-------|
| `Sources/Agent/Tools/FileTools.swift` | file.read, file.write, file.edit, file.delete |
| `Sources/Agent/Tools/DirectoryTools.swift` | dir.list, dir.create, file.search |
| `Sources/Agent/Tools/SystemTools.swift` | sys.exec |
| `Sources/Agent/Tools/GitTools.swift` | git.status, git.diff, git.commit |
| `Sources/Agent/Tools/WebTools.swift` | web.search, web.fetch |
| `Sources/Agent/Tools/DelegationTools.swift` | delegate.coder, delegate.researcher, delegate.vision |

---

## Part 5: New IDE Features

### 5.1 Quality Presets UI

NEW: `Sources/Views/QualityPresetPicker.swift` (~100 LOC)

```swift
struct QualityPresetPicker: View {
    @Binding var selectedPreset: QualityPreset
    
    enum QualityPreset: String, CaseIterable {
        case fast, balanced, thorough
        
        var pipeline: [String] {
            switch self {
            case .fast: ["execute"]
            case .balanced: ["plan", "execute", "review"]
            case .thorough: ["plan", "execute", "review", "revise"]
            }
        }
    }
    
    var body: some View {
        Picker("Quality", selection: $selectedPreset) {
            ForEach(QualityPreset.allCases, id: \.self) { preset in
                Text(preset.rawValue.capitalized).tag(preset)
            }
        }
        .pickerStyle(.segmented)
    }
}
```

### 5.2 Human Consultation Modal

NEW: `Sources/Views/ConsultationView.swift` (~200 LOC)

Modal dialog with countdown timer. When timer expires, AI substitutes its best-practice answer.

### 5.3 Cost Tracking Service

NEW: `Sources/Services/CostTrackingService.swift` (~250 LOC)

Tracks token usage per model, calculates savings vs commercial API pricing.

### 5.4 Dry-Run Preview Mode

NEW: `Sources/Services/PreviewService.swift` (~200 LOC)

Shows proposed file changes without applying them. User reviews diff and approves/rejects.

### 5.5 Session Persistence UI

NEW: `Sources/Views/SessionRestoreView.swift` (~200 LOC)

Lists saved sessions with flow code display, allows resume from any checkpoint.

### 5.6 CLIBridgeService

NEW: `Sources/Services/CLIBridgeService.swift` (~400 LOC)

JSON-RPC client over stdio connecting to `obot server`. Handles:
- Process lifecycle (launch, monitor, terminate)
- Request/response with timeout
- Event streaming for real-time tool call updates
- Automatic fallback to native Swift execution

---

## Part 6: Implementation Timeline (IDE Track)

### Week 1: Configuration + Schemas
- `SharedConfigService.swift` — YAML config reader
- Update `ConfigurationService.swift` to delegate shared settings
- Config migration from UserDefaults

### Week 2: Context + Model Coordination
- Validate ContextManager output against UCP schema
- Read model tier mappings from shared config
- Validate intent routing against shared keywords

### Week 3: Orchestration Port
- `OrchestrationService.swift` — 5-schedule state machine
- `OrchestrationView.swift` — Schedule/process visualization
- `FlowCodeView.swift` — Flow code display
- Add orchestration mode to AgentExecutor

### Week 4: Feature Parity
- `QualityPresetPicker.swift`
- `CostTrackingService.swift`
- `ConsultationView.swift`
- `PreviewService.swift`

### Week 5: Session Format + Integration
- `UnifiedSessionService.swift` — USF support
- `SessionHandoffService.swift` — Export/import
- `SessionRestoreView.swift` — Resume UI
- Integration smoke tests

### Week 6: Refactoring + Polish
- Split AgentExecutor.swift into 5 files
- Tools modularization into 6 files
- `CLIBridgeService.swift` — Bridge to obot server
- Documentation, testing, release

---

## Part 7: File Change Manifest

### New Files (14)

| File | LOC | Week |
|------|-----|------|
| `Sources/Services/SharedConfigService.swift` | ~300 | 1 |
| `Sources/Services/OrchestrationService.swift` | ~500 | 3 |
| `Sources/Views/OrchestrationView.swift` | ~450 | 3 |
| `Sources/Views/FlowCodeView.swift` | ~150 | 3 |
| `Sources/Views/QualityPresetPicker.swift` | ~100 | 4 |
| `Sources/Services/CostTrackingService.swift` | ~250 | 4 |
| `Sources/Views/ConsultationView.swift` | ~200 | 4 |
| `Sources/Services/PreviewService.swift` | ~200 | 4 |
| `Sources/Services/UnifiedSessionService.swift` | ~300 | 5 |
| `Sources/Services/SessionHandoffService.swift` | ~200 | 5 |
| `Sources/Views/SessionRestoreView.swift` | ~200 | 5 |
| `Sources/Services/CLIBridgeService.swift` | ~400 | 6 |
| `Sources/Agent/OrchestratorEngine.swift` | ~300 | 6 |
| `Sources/Agent/ExecutionAgent.swift` | ~250 | 6 |

### Modified Files (4)

| File | Changes | Week |
|------|---------|------|
| `Sources/Services/ConfigurationService.swift` | Delegate to SharedConfig | 1 |
| `Sources/Services/ContextManager.swift` | Schema validation | 2 |
| `Sources/Services/ModelTierManager.swift` | Read shared config | 2 |
| `Sources/Agent/AgentExecutor.swift` | Add orchestration mode, then split | 3, 6 |

**Total: ~3,800 new LOC + ~400 modified LOC**

---

## Part 8: Success Criteria

### Must-Have for March
- [ ] Shared config.yaml read by IDE
- [ ] Orchestration mode (5-schedule framework) functional
- [ ] Quality presets UI operational
- [ ] Session export in USF format
- [ ] All protocol schemas validated
- [ ] AgentExecutor split into 5+ files

### Performance Gates
- Config loading: < 50ms additional overhead
- Session save/load: < 200ms
- No UI responsiveness regression
- Context build time: < 500ms for 500-file project

### Quality Gates
- All JSON schemas pass validation
- Session export/import round-trips with CLI
- Config migration preserves all existing UserDefaults settings
- Orchestration state machine matches CLI behavior

---

*Agent: opus-1 | IDE Master Plan | Protocol-First Harmonization*
