# OllamaBot IDE Harmonization Master Plan
## Agent: opus-2 | Platform: IDE (Swift/SwiftUI)

**Date:** 2026-02-05
**Round:** Final Consolidation
**Scope:** All IDE-side changes required for OllamaBot/obot harmonization
**Target:** March 2026 Release

---

## Executive Summary

This plan specifies every IDE-side change needed to harmonize OllamaBot (Swift/macOS) with obot (Go CLI) under a protocol-first, zero-shared-code architecture. The IDE gains orchestration, quality presets, cost tracking, session portability, and shared configuration -- while preserving its existing strengths in multi-model delegation, context management, and rich UI.

---

## Architecture Decision

**Protocol-Native, Zero Shared Code.** Both products implement the same behavioral contracts (JSON schemas, YAML configuration) in their native languages. The IDE does NOT wrap or call the CLI binary. Instead, it ports the orchestration state machine to Swift natively and reads the same shared configuration files.

---

## Part 1: Shared Configuration Integration

### 1.1 SharedConfigService (NEW)

**File:** `Sources/Services/SharedConfigService.swift`
**Purpose:** Read the unified YAML configuration at `~/.config/ollamabot/config.yaml`
**Dependencies:** Yams (Swift YAML parser)

```swift
import Yams

@Observable
class SharedConfigService {
    var config: UnifiedConfig

    struct UnifiedConfig: Codable {
        var version: String
        var platform: PlatformConfig
        var models: ModelsConfig
        var quality: QualityConfig
        var context: ContextConfig
        var orchestration: OrchestrationConfig
        var platforms: PlatformsConfig
    }

    struct ModelsConfig: Codable {
        var orchestrator: ModelEntry
        var coder: ModelEntry
        var researcher: ModelEntry
        var vision: ModelEntry
    }

    struct ModelEntry: Codable {
        var primary: String
        var tierMapping: [String: String]
    }

    func load() throws {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ollamabot/config.yaml")
        let yaml = try String(contentsOf: configPath)
        config = try YAMLDecoder().decode(UnifiedConfig.self, from: yaml)
    }
}
```

### 1.2 ConfigurationService Updates

**File:** `Sources/Services/ConfigurationService.swift`
**Change:** Read shared config for model definitions, quality presets, context budgets. Retain UserDefaults ONLY for IDE-specific visual preferences (theme, font size, editor settings).

**Specific changes:**
- Add `SharedConfigService` dependency
- Replace hardcoded model names with `config.models.{role}.primary`
- Replace hardcoded tier detection with `config.models.{role}.tierMapping`
- Load quality preset definitions from `config.quality.presets`
- Load context budget allocation from `config.context.budgetAllocation`

---

## Part 2: Orchestration Service (NEW)

### 2.1 OrchestrationService

**File:** `Sources/Services/OrchestrationService.swift`
**Purpose:** Port obot's 5-schedule x 3-process orchestration framework to Swift

```swift
@Observable
class OrchestrationService {
    enum Schedule: Int, CaseIterable {
        case knowledge = 1    // Research, Crawl, Retrieve
        case plan = 2         // Brainstorm, Clarify, Plan
        case implement = 3    // Implement, Verify, Feedback
        case scale = 4        // Scale, Benchmark, Optimize
        case production = 5   // Analyze, Systemize, Harmonize
    }

    enum Process: Int, CaseIterable {
        case first = 1, second = 2, third = 3
    }

    var currentSchedule: Schedule?
    var currentProcess: Process?
    var flowCode: String = ""
    var completedSchedules: Set<Schedule> = []
    var consultations: [Consultation] = []

    // Navigation rules: strict 1<->2<->3
    func canNavigate(from: Process, to: Process) -> Bool {
        abs(from.rawValue - to.rawValue) <= 1
    }

    // Flow code generation: S1P123S2P12...
    func appendFlowCode(schedule: Schedule, process: Process) {
        flowCode += "S\(schedule.rawValue)P\(process.rawValue)"
    }

    // Termination: all 5 schedules visited, production last
    func canTerminate() -> Bool {
        completedSchedules.count == 5 &&
        currentSchedule == .production &&
        currentProcess == .third
    }
}
```

### 2.2 OrchestrationView (NEW)

**File:** `Sources/Views/OrchestrationView.swift`
**Purpose:** UI for schedule/process visualization with flow code display

Components:
- Schedule progress indicator (5 phases with completion state)
- Process navigator (P1/P2/P3 with navigation rules enforced)
- Flow code display bar (e.g., S1P123S2P12)
- Human consultation modal integration

### 2.3 FlowCodeView (NEW)

**File:** `Sources/Views/FlowCodeView.swift`
**Purpose:** Compact flow code display showing orchestration path

### 2.4 AgentExecutor Integration

**File:** `Sources/Agent/AgentExecutor.swift`
**Change:** Add orchestration mode alongside existing infinite and explore modes

```swift
enum AgentMode {
    case infinite      // Existing: loop until complete
    case explore       // Existing: 6-phase autonomous
    case orchestration // NEW: 5-schedule framework
}
```

When `mode == .orchestration`, the executor delegates to `OrchestrationService` for schedule/process navigation and uses the standard tool system for execution within each process.

---

## Part 3: Quality Presets (NEW)

### 3.1 QualityPresetService

**File:** `Sources/Services/QualityPresetService.swift`

```swift
enum QualityPreset: String, CaseIterable {
    case fast       // Single pass, no plan, no review
    case balanced   // Plan + execute + review
    case thorough   // Plan + execute + review + revise loop
}

@Observable
class QualityPresetService {
    var activePreset: QualityPreset = .balanced

    var pipeline: [ExecutionPhase] {
        switch activePreset {
        case .fast:     return [.execute]
        case .balanced: return [.plan, .execute, .review]
        case .thorough: return [.plan, .execute, .review, .revise]
        }
    }
}
```

### 3.2 QualityPresetView (NEW)

**File:** `Sources/Views/QualityPresetView.swift`
**Purpose:** Segmented control for Fast/Balanced/Thorough selection in the chat toolbar

---

## Part 4: Cost Tracking (NEW)

### 4.1 CostTrackingService

**File:** `Sources/Services/CostTrackingService.swift`
**Purpose:** Track token usage and calculate savings vs commercial APIs

```swift
@Observable
class CostTrackingService {
    struct CostComparison {
        var totalTokens: Int64
        var claudeOpusCost: Double
        var claudeSonnetCost: Double
        var gpt4oCost: Double
        var ollamaCost: Double  // $0 (local)
        var totalSaved: Double
    }

    var sessionTokens: Int64 = 0
    var lifetimeTokens: Int64 = 0

    func calculateSavings() -> CostComparison { ... }
}
```

---

## Part 5: Human Consultation (NEW)

### 5.1 ConsultationView

**File:** `Sources/Views/ConsultationView.swift`
**Purpose:** Modal dialog with countdown timer and AI fallback

Behavior:
- Appears during orchestration Clarify (optional, 60s) and Feedback (mandatory, 300s) processes
- Shows countdown timer
- On timeout: falls back to AI substitute response
- User can respond at any time to cancel timer

---

## Part 6: Session Portability (NEW)

### 6.1 UnifiedSessionService

**File:** `Sources/Services/UnifiedSessionService.swift`
**Purpose:** Read/write Unified Session Format (USF) JSON files

```swift
struct UnifiedSession: Codable {
    var version: String = "1.0"
    var sessionId: String
    var createdAt: Date
    var sourcePlatform: String
    var task: TaskState
    var orchestrationState: OrchestrationState?
    var conversationHistory: [Message]
    var filesModified: [String]
    var checkpoints: [Checkpoint]
    var stats: SessionStats
}
```

### 6.2 SessionHandoffService

**File:** `Sources/Services/SessionHandoffService.swift`
**Purpose:** Export IDE sessions to CLI-compatible USF, import CLI sessions into IDE

Session directory: `~/.config/ollamabot/sessions/{session_id}.json`

---

## Part 7: Dry-Run Preview Mode (NEW)

**File:** `Sources/Services/PreviewService.swift`
**Purpose:** Execute agent in dry-run mode where file writes are captured but not applied. Shows diff preview for all proposed changes before user confirms.

---

## Part 8: IDE Refactoring

### 8.1 Split AgentExecutor

**Current:** `Sources/Agent/AgentExecutor.swift` (1069 lines)
**Target:** Split into:
- `Sources/Agent/OrchestratorEngine.swift` -- Decision logic, model routing, schedule navigation
- `Sources/Agent/ExecutionAgent.swift` -- Tool execution, file operations, result reporting

### 8.2 Model Tier Manager Update

**File:** `Sources/Services/ModelTierManager.swift`
**Change:** Read tier mappings from shared `config.yaml` instead of hardcoded Swift enum

### 8.3 Context Manager Schema Compliance

**File:** `Sources/Services/ContextManager.swift`
**Change:** Validate output against UCP JSON schema. Add `exportUCP()` method.

---

## Part 9: New Files Summary

| File | Lines (est.) | Purpose |
|------|-------------|---------|
| `SharedConfigService.swift` | ~200 | YAML config reader |
| `OrchestrationService.swift` | ~400 | 5-schedule state machine |
| `OrchestrationView.swift` | ~300 | Schedule/process UI |
| `FlowCodeView.swift` | ~80 | Flow code display |
| `QualityPresetService.swift` | ~100 | Fast/Balanced/Thorough |
| `QualityPresetView.swift` | ~80 | Preset selector UI |
| `CostTrackingService.swift` | ~150 | Token savings calculator |
| `ConsultationView.swift` | ~200 | Human consultation modal |
| `UnifiedSessionService.swift` | ~250 | USF read/write |
| `SessionHandoffService.swift` | ~150 | Export/import sessions |
| `PreviewService.swift` | ~200 | Dry-run mode |
| `OrchestratorEngine.swift` | ~500 | Decision engine (split) |
| `ExecutionAgent.swift` | ~400 | Execution engine (split) |

**Total new code:** ~3,010 lines

## Part 10: Modified Files Summary

| File | Change |
|------|--------|
| `ConfigurationService.swift` | Read shared config, UserDefaults for UI only |
| `AgentExecutor.swift` | Add orchestration mode, delegate to split engines |
| `ContextManager.swift` | UCP schema validation, exportUCP() |
| `ModelTierManager.swift` | Read tiers from shared config |
| `IntentRouter.swift` | Read intent keywords from shared config |
| `ChatView.swift` | Add quality preset selector, orchestration toggle |

---

## Part 11: Success Criteria

- [ ] IDE reads `~/.config/ollamabot/config.yaml` for all shared settings
- [ ] Orchestration mode runs 5-schedule x 3-process framework with flow code
- [ ] Quality presets control execution pipeline
- [ ] Cost tracking displays savings vs Claude/GPT-4o
- [ ] Human consultation modal appears with countdown timer
- [ ] Sessions export to USF format readable by CLI
- [ ] CLI sessions import into IDE and resume
- [ ] Dry-run mode shows diff preview before applying changes
- [ ] No regression > 5% in existing IDE performance

---

## Part 12: Protocol Schemas (IDE Implements)

| Protocol | Schema | IDE Responsibility |
|----------|--------|-------------------|
| UC (Unified Config) | `config.yaml` | Read and apply |
| UTR (Tool Registry) | `tools.schema.json` | Validate tool calls |
| UCP (Context Protocol) | `context.schema.json` | Export context state |
| UOP (Orchestration Protocol) | `orchestration.schema.json` | Run state machine |
| USF (Session Format) | `session.schema.json` | Read/write sessions |
| UMC (Model Coordinator) | Part of config.yaml | Route model selection |

---

*Agent: opus-2 | Platform: IDE | Final Consolidation*
