# Master Plan: OllamaBot IDE Harmonization
## opus-2 | IDE-Specific Implementation

**Agent:** Claude Opus (opus-2)
**Date:** 2026-02-05
**Product:** OllamaBot IDE (Swift)
**Round:** 2 (plans_2)
**Status:** FLOW EXIT COMPLETE

---

## Architecture

Protocol-native, zero shared code. IDE implements behavioral contracts natively in Swift. Shared schemas at `~/.config/ollamabot/` define the behavioral contracts that both CLI and IDE conform to independently.

---

## 6 Core Protocols

| Protocol | Abbrev | Format | Location |
|----------|--------|--------|----------|
| Unified Configuration | UC | YAML | `~/.config/ollamabot/config.yaml` |
| Unified Tool Registry | UTR | JSON Schema | `~/.config/ollamabot/schemas/tools.schema.json` |
| Unified Context Protocol | UCP | JSON Schema | `~/.config/ollamabot/schemas/context.schema.json` |
| Unified Orchestration Protocol | UOP | JSON Schema | `~/.config/ollamabot/schemas/orchestration.schema.json` |
| Unified Session Format | USF | JSON Schema | `~/.config/ollamabot/schemas/session.schema.json` |
| Unified Model Coordinator | UMC | YAML (in config) | Part of `config.yaml` models section |

---

## IDE Current State

| Metric | Value |
|--------|-------|
| LOC | ~34,489 |
| Files | 63 |
| Modules | 5 |
| Agent Tools | 18+ (read-write) |
| Models Supported | 4 (orchestrator, coder, researcher, vision) |
| Token Management | Sophisticated (ContextManager) |
| Orchestration | None (infinite loop + explore mode) |
| Config Format | UserDefaults |
| Session Persistence | In-memory only |

---

## IDE Enhancements (10 Plans)

### I-01: Shared Config Service (YAML reader)
- **File:** `Sources/Services/SharedConfigService.swift` (NEW)
- **Dependency:** Yams library
- Read unified `~/.config/ollamabot/config.yaml`
- Retain UserDefaults for IDE-specific visual preferences only
- Watch config file for external changes

### I-02: OrchestrationService (5-schedule state machine)
- **File:** `Sources/Services/OrchestrationService.swift` (NEW)
- Port CLI's 5-schedule x 3-process state machine to Swift
- Schedules: Knowledge, Plan, Implement, Scale, Production
- Navigation: intra-schedule 1<->2<->3, inter-schedule any_P3_to_any_P1
- Termination requires 5_production_3

### I-03: Orchestration UI
- **File:** `Sources/Views/OrchestrationView.swift` (NEW)
- **File:** `Sources/Views/FlowCodeView.swift` (NEW)
- Schedule/process visualization with flow code display (S1P123S2P12...)
- Visual progress through schedules

### I-04: Quality Presets UI
- **File:** `Sources/Views/QualityPresetView.swift` (NEW)
- Fast/Balanced/Thorough selector
- Maps to config.yaml quality presets

### I-05: Cost Tracking Service
- **File:** `Sources/Services/CostTrackingService.swift` (NEW)
- Token usage and savings calculator
- Port from CLI's savings tracker

### I-06: Human Consultation Modal
- **File:** `Sources/Views/ConsultationView.swift` (NEW)
- Modal dialog with countdown timer
- AI fallback on timeout
- Consultation types: optional (60s) and mandatory (300s)

### I-07: Dry-Run Preview Mode
- **File:** `Sources/Services/PreviewService.swift` (NEW)
- Preview agent file changes before applying
- Diff display for proposed modifications

### I-08: Unified Session Service (USF)
- **File:** `Sources/Services/UnifiedSessionService.swift` (NEW)
- Read/write JSON session files
- Cross-platform compatible format

### I-09: Session Handoff (export/import)
- **File:** `Sources/Services/SessionHandoffService.swift` (NEW)
- Export IDE session to CLI-compatible format
- Import CLI session into IDE

### I-10: Model Tier Manager (shared config)
- **File:** `Sources/Services/ModelTierManager.swift` (UPDATE)
- Read tier mappings from shared config instead of hardcoded values
- RAM-aware fallbacks ported from CLI's tier detection

---

## IDE Refactoring (4 Plans)

### R-01: Split AgentExecutor
- `AgentExecutor.swift` (1069 lines) splits into:
  - `AgentExecutor.swift` (~200 lines) -- coordination
  - `OrchestratorEngine.swift` -- decision logic
  - `ExecutionAgent.swift` -- tool execution

### R-02: Tools Modularization
- Extract tool implementations from AgentExecutor into dedicated files

### R-03: Decision/Execution Engine Separation
- OrchestratorEngine owns decision logic, delegates to ExecutionAgent

### R-04: Mode Executors Refactor
- Add orchestration mode alongside existing infinite/explore modes

---

## IDE File Changes by Week

### Week 1
- `Sources/Services/SharedConfigService.swift` -- NEW: YAML config reader
- `Sources/Services/ConfigurationService.swift` -- UPDATE: read shared config

### Week 2
- `Sources/Services/ContextManager.swift` -- UPDATE: validate against UCP schema
- `Sources/Services/ModelTierManager.swift` -- UPDATE: read from shared config
- `Sources/Services/IntentRouter.swift` -- UPDATE: validate against shared config

### Week 3
- `Sources/Services/OrchestrationService.swift` -- NEW: state machine
- `Sources/Views/OrchestrationView.swift` -- NEW: visualization
- `Sources/Views/FlowCodeView.swift` -- NEW: flow code display
- `Sources/Agent/AgentExecutor.swift` -- UPDATE: add orchestration mode

### Week 4
- `Sources/Views/QualityPresetView.swift` -- NEW
- `Sources/Services/CostTrackingService.swift` -- NEW
- `Sources/Views/ConsultationView.swift` -- NEW
- `Sources/Services/PreviewService.swift` -- NEW

### Week 5
- `Sources/Services/UnifiedSessionService.swift` -- NEW
- `Sources/Services/SessionHandoffService.swift` -- NEW
- `Sources/Services/CheckpointService.swift` -- UPDATE: persist using USF

### Week 6
- Integration testing and documentation

---

## Code-Grounded Insights (IDE-Specific)

1. **IDE has sophisticated ContextManager** with token budgeting, semantic compression, conversation memory, and error pattern learning. This is the canonical implementation; CLI needs to port from it.

2. **IDE supports 4 model roles** (orchestrator, coder, researcher, vision) with intent routing. CLI currently supports 1 model per tier.

3. **IDE has 18+ read-write tools** including file operations, web search, git, delegation, and screenshot. These are Tier 2 autonomous tools.

4. **IDE lacks orchestration.** The 5-schedule x 3-process framework from CLI must be ported to Swift natively.

5. **IDE uses UserDefaults for config.** Must add YAML reader for shared settings while retaining UserDefaults for UI-only preferences.

6. **AgentExecutor.swift is 1069 lines.** Requires splitting into OrchestratorEngine + ExecutionAgent for maintainability.

---

## Success Criteria (IDE)

- [ ] Shared `config.yaml` read via SharedConfigService
- [ ] Orchestration mode with 5-schedule framework
- [ ] Quality presets (fast/balanced/thorough)
- [ ] Cost tracking display
- [ ] Session export/import (USF format)
- [ ] AgentExecutor split into OrchestratorEngine + ExecutionAgent
- [ ] No regression > 5% in existing functionality

---

## Provenance

Distilled from `~/ollamabot/plans_2/FINAL-CONSOLIDATED-MASTER-opus-2.md`. That document synthesized 230+ agent contributions across 21 consolidation rounds with direct source code analysis.

---

*Agent: Claude Opus (opus-2) | IDE Master Plan*
