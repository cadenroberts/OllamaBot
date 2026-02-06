# OllamaBot IDE Harmonization Master Plan

**Agent:** sonnet-3
**Product:** ollamabot IDE (Swift/SwiftUI)
**Date:** 2026-02-05
**Status:** Canonical Master — IDE Component

---

## Architecture Role

The IDE is the Rich Interface in the "One Brain, Two Interfaces" model. It provides native macOS visualization, editing, and interaction while consuming shared behavioral contracts defined by the 6 Unified Protocols.

```
┌──────────────────────────────────────────────┐
│              ollamabot IDE (Swift)            │
│                                              │
│  EXISTING:              NEW:                 │
│  - AgentExecutor        + OrchestrationService│
│  - 18 tools             + Quality presets     │
│  - Multi-model (4)      + Cost tracking       │
│  - ContextManager       + Dry-run mode        │
│  - UI framework         + Session export (USF)│
│  - Checkpoints          + Shared YAML config  │
│  - .obotrules           + Flow code display   │
│  - @mentions            + Consultation modal  │
└──────────────────┬───────────────────────────┘
                   │
                   ▼
        ~/.config/ollamabot/
        ├── config.yaml     (UC)
        ├── schemas/        (UOP, UTR, UCP, USF)
        ├── prompts/
        └── sessions/
```

---

## Critical Code Findings

### AgentExecutor.swift (1069 lines)
- Monolithic: handles tool selection, model delegation, verification, error handling, parallel execution
- Must be split into Core/, Tools/, Strategies/ (5 files, ~200 lines each)
- Supports 18 tools including read, search, delegate, web, git
- Has LRU cache for tool results (capacity 100)

### ContextManager.swift
- Sophisticated token budgeting: task 25%, files 33%, project 16%, history 12%, memory 12%, errors 6%
- Semantic compression preserving imports/exports/signatures
- Inter-agent context passing for orchestrator-to-specialist delegation
- Conversation memory with relevance scoring
- Error pattern learning
- This is the IDE's strongest component — CLI must port this logic

### ModelTierManager.swift
- 6 tiers: Minimal, Compact, Balanced, Performance, Advanced, Maximum
- RAM detection via ProcessInfo.processInfo.physicalMemory
- Multiple models per tier (orchestrator, coder, researcher, vision)
- Must migrate tier definitions to shared config.yaml

### IntentRouter.swift
- Keyword-based intent classification (coding, research, writing, vision)
- Auto-selects model role based on task content
- Must validate against shared intent keywords in config

### ConfigurationService.swift
- Currently uses UserDefaults (macOS system preferences)
- Must add YAML config reader for ~/.config/ollamabot/config.yaml
- Keep UserDefaults ONLY for IDE-specific visual prefs (font size, theme)

---

## IDE Enhancement Plan (6 Weeks)

### Week 1: Configuration Migration

**New Files:**
- `Sources/Services/SharedConfigService.swift` — YAML config reader using Yams library
  - Read ~/.config/ollamabot/config.yaml
  - Merge with UserDefaults for IDE-specific prefs
  - File watcher for live config reload

**Modified Files:**
- `Sources/Services/ConfigurationService.swift` — Delegate to SharedConfigService for shared settings, keep UserDefaults for theme/font/UI prefs only

**Deliverables:**
- [ ] IDE reads shared config.yaml
- [ ] IDE-specific prefs remain in UserDefaults
- [ ] Config changes detected and reloaded

### Week 2: Context Schema Compliance

**Modified Files:**
- `Sources/Services/ContextManager.swift` — Validate token budget allocations against UCP schema
- `Sources/Services/ModelTierManager.swift` — Read tier mappings from shared config instead of hardcoded values
- `Sources/Services/IntentRouter.swift` — Validate intent keywords against shared config

**Deliverables:**
- [ ] Context building follows UCP spec
- [ ] Model tiers read from shared config
- [ ] Intent routing uses shared keywords

### Week 3: Orchestration Framework

**New Files:**
- `Sources/Services/OrchestrationService.swift` (~600 lines) — 5-schedule state machine
  ```swift
  @Observable
  final class OrchestrationService {
      enum Schedule: Int, CaseIterable {
          case knowledge = 1, plan, implement, scale, production
      }
      enum Process: Int { case p1 = 1, p2, p3 }

      var currentSchedule: Schedule?
      var currentProcess: Process?
      var flowCode: String = ""

      func canNavigate(from: Process, to: Process) -> Bool
      func selectSchedule(_ id: Schedule) throws
      func selectProcess(_ id: Process) throws
      func canTerminateSchedule() -> Bool
      func generateFlowCode() -> String
  }
  ```
  Navigation rules: P1->{P1,P2}, P2->{P1,P2,P3}, P3->{P2,P3,terminate}
  Termination: all schedules run once, Production last

- `Sources/Views/OrchestrationView.swift` (~400 lines) — Schedule/process visualization
- `Sources/Views/FlowCodeView.swift` (~100 lines) — S1P123S2P12 display

**Modified Files:**
- `Sources/Agent/AgentExecutor.swift` — Add orchestration mode alongside infinite mode

**Deliverables:**
- [ ] 5-schedule orchestration working in IDE
- [ ] Process navigation enforces 1-2-3 rules
- [ ] Flow code tracked and displayed
- [ ] User can choose Infinite Mode or Orchestration Mode

### Week 4: Feature Parity

**New Files:**
- `Sources/Views/QualityPresetView.swift` — Fast/Balanced/Thorough selector
  ```swift
  enum QualityPreset: String, CaseIterable {
      case fast       // Single pass, no review
      case balanced   // Plan + execute + review
      case thorough   // Plan + execute + review + revise
  }
  ```
- `Sources/Services/CostTrackingService.swift` — Token savings calculator (port from CLI stats/savings.go)
- `Sources/Views/ConsultationView.swift` — Modal dialog with countdown timer
  - Optional consultation: 60s timeout, AI substitute on expiry
  - Mandatory consultation: blocks until response
- `Sources/Services/PreviewService.swift` — Dry-run mode showing proposed changes before applying

**Deliverables:**
- [ ] Quality presets selectable in Chat/Composer views
- [ ] Cost tracking displayed in status bar
- [ ] Human consultation with timeout working
- [ ] Dry-run preview mode functional

### Week 5: Session Portability

**New Files:**
- `Sources/Services/UnifiedSessionService.swift` — USF serialization/deserialization
  - Read/write ~/.config/ollamabot/sessions/{id}/session.json
  - Validate against USF JSON Schema
- `Sources/Services/SessionHandoffService.swift` — Export IDE session for CLI, import CLI session into IDE

**Modified Files:**
- `Sources/Services/CheckpointService.swift` — Update to use USF checkpoint format

**Deliverables:**
- [ ] Sessions saved in USF format
- [ ] CLI sessions visible in IDE "Recent Sessions"
- [ ] IDE sessions resumable in CLI
- [ ] Checkpoints use shared format

### Week 6: Refactoring + Polish

**Refactoring:**
- Split AgentExecutor.swift into:
  - `Sources/Agent/Core/AgentExecutor.swift` (~200 lines) — Main loop
  - `Sources/Agent/Core/ToolExecutor.swift` (~150 lines) — Tool dispatch
  - `Sources/Agent/Core/VerificationEngine.swift` (~100 lines) — Output verification
  - `Sources/Agent/Tools/FileTools.swift` — File operations
  - `Sources/Agent/Tools/AITools.swift` — Delegation tools
  - `Sources/Agent/Tools/WebTools.swift` — Web/git tools

**Documentation:**
- Protocol specification docs
- Migration guide for existing users

**Deliverables:**
- [ ] AgentExecutor split into focused modules
- [ ] All schemas validate
- [ ] Performance: no regression > 5%
- [ ] Documentation complete

---

## Success Criteria

### Must-Have for March
- [ ] Shared config.yaml read by IDE
- [ ] Orchestration mode (5-schedule framework)
- [ ] Quality presets (fast/balanced/thorough)
- [ ] Session format cross-compatible with CLI
- [ ] All protocol schemas validated

### Performance Gates
- Config loading: < 50ms overhead
- Session save/load: < 200ms
- Context build: < 500ms for 500-file project
- No UI lag from shared config loading

---

*IDE component of the sonnet-3 canonical master plan.*
