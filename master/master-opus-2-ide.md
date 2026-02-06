# MASTER PLAN: OllamaBot IDE Harmonization
## Agent: opus-2 | Final Consolidation | March 2026 Release

---

## Executive Summary

This is the IDE-specific master plan for harmonizing OllamaBot (Swift/macOS IDE) with obot (Go CLI) into a unified product ecosystem. It covers all IDE enhancements, refactoring, and protocol adoption required for the March 2026 release.

**Architecture:** Protocol-First -- shared YAML/JSON behavioral contracts, zero shared code, independent Swift implementation.

---

## Part 1: IDE Current State

| Metric | Value |
|--------|-------|
| LOC | ~34,489 |
| Files | 63 |
| Modules | 5 (Agent, Models, Services, Utilities, Views) |
| Agent Tools | 18+ (read-write) |
| Models | 4 (orchestrator, coder, researcher, vision) |
| Token Management | Sophisticated (ContextManager) |
| Orchestration | None (infinite loop + explore mode) |
| Config | UserDefaults |
| Session Persistence | In-memory only |

**Key Strengths:**
- Multi-model delegation (4 specialized models)
- Token-budgeted context management with semantic compression
- Rich SwiftUI interface with streaming responses
- 18 agent tools including web search, git, vision
- Intent-based model routing

**Key Gaps:**
- No formal orchestration framework (CLI has 5-schedule x 3-process)
- No quality presets (fast/balanced/thorough)
- No cost/savings tracking
- No dry-run/preview mode
- No cross-platform session persistence
- Configuration not shared with CLI
- AgentExecutor.swift is 1,069 lines (needs splitting)

---

## Part 2: The 6 Protocols (IDE Perspective)

### UC -- Unified Configuration
- **IDE Action:** Read `~/.config/ollamabot/config.yaml` via new `SharedConfigService.swift`
- **Retain:** UserDefaults for IDE-only visual prefs (theme, font size, sidebar width)
- **Library:** Yams (Swift YAML parser)

### UTR -- Unified Tool Registry
- **IDE Action:** Validate existing 18 tools against `tools.schema.json`
- **Normalize:** Tool IDs to canonical format (e.g., `read_file` -> `file.read`)
- **Add missing:** `git.push`, `session.note`

### UCP -- Unified Context Protocol
- **IDE Action:** Validate ContextManager output against `context.schema.json`
- **Already implemented:** Token budgets, semantic compression, error learning
- **Export:** Add UCP JSON export for cross-platform context sharing

### UOP -- Unified Orchestration Protocol
- **IDE Action:** NEW `OrchestrationService.swift` implementing 5-schedule state machine
- **Port from:** CLI's `internal/orchestrate/orchestrator.go` (behavioral port, not code port)
- **Integration:** Add as third mode alongside Infinite Mode and Explore Mode

### USF -- Unified Session Format
- **IDE Action:** NEW `UnifiedSessionService.swift` for JSON session read/write
- **Enable:** Session export to CLI-compatible format, import from CLI sessions
- **Update:** CheckpointService to persist using USF format

### UMC -- Unified Model Coordinator
- **IDE Action:** Update `ModelTierManager.swift` to read tier mappings from shared config
- **Remove:** Hardcoded model names from `OllamaModel` enum
- **Add:** RAM-aware fallback chains from shared config

---

## Part 3: IDE Implementation Plans (I-01 through I-10)

### I-01: Shared Config Service (YAML Reader)
- **New file:** `Sources/Services/SharedConfigService.swift`
- **Purpose:** Read `~/.config/ollamabot/config.yaml` using Yams
- **Modify:** `Sources/Services/ConfigurationService.swift` to delegate shared settings
- **Priority:** P0 | **Effort:** Medium | **Week:** 1

### I-02: OrchestrationService (5-Schedule State Machine)
- **New file:** `Sources/Services/OrchestrationService.swift`
- **Purpose:** 5-schedule x 3-process state machine with navigation rules
- **Schedules:** Knowledge, Plan, Implement, Scale, Production
- **Navigation:** P1->{P1,P2}, P2->{P1,P2,P3}, P3->{P2,P3,terminate}
- **Flow code:** Generate S1P123S2P12... tracking strings
- **Priority:** P0 | **Effort:** Large | **Week:** 3

### I-03: Orchestration UI
- **New file:** `Sources/Views/OrchestrationView.swift`
- **New file:** `Sources/Views/FlowCodeView.swift`
- **Purpose:** Schedule/process visualization with flow code display
- **Modify:** `Sources/Agent/AgentExecutor.swift` to add orchestration mode
- **Priority:** P1 | **Effort:** Medium | **Week:** 3

### I-04: Quality Presets UI
- **New file:** `Sources/Views/QualityPresetView.swift`
- **Purpose:** Fast/Balanced/Thorough selector
- **Presets from config:** pipeline steps, verification level, target time
- **Priority:** P1 | **Effort:** Small | **Week:** 4

### I-05: Cost Tracking Service
- **New file:** `Sources/Services/CostTrackingService.swift`
- **Purpose:** Token usage calculator, savings vs commercial APIs
- **Pricing:** Claude Opus $0.015/$0.075, Sonnet $0.003/$0.015, GPT-4o $0.005/$0.015
- **Priority:** P2 | **Effort:** Small | **Week:** 4

### I-06: Human Consultation Modal
- **New file:** `Sources/Views/ConsultationView.swift`
- **Purpose:** Modal dialog with countdown timer and AI fallback
- **Timeouts:** Clarify=60s (optional), Feedback=300s (mandatory)
- **Priority:** P1 | **Effort:** Medium | **Week:** 4

### I-07: Dry-Run Preview Mode
- **New file:** `Sources/Services/PreviewService.swift`
- **Purpose:** Execute agent without writing files, show diff preview
- **Priority:** P1 | **Effort:** Medium | **Week:** 4

### I-08: Unified Session Service (USF)
- **New file:** `Sources/Services/UnifiedSessionService.swift`
- **Purpose:** Read/write USF JSON sessions
- **Schema:** version, session_id, task, workspace, orchestration_state, history, checkpoints
- **Priority:** P1 | **Effort:** Large | **Week:** 5

### I-09: Session Handoff
- **New file:** `Sources/Services/SessionHandoffService.swift`
- **Purpose:** Export IDE session to CLI format, import CLI session into IDE
- **Modify:** `Sources/Services/CheckpointService.swift` for USF persistence
- **Priority:** P1 | **Effort:** Medium | **Week:** 5

### I-10: Model Tier Manager (Shared Config)
- **Modify:** `Sources/Services/ModelTierManager.swift`
- **Purpose:** Read tier mappings from shared YAML config instead of hardcoded values
- **Priority:** P1 | **Effort:** Small | **Week:** 2

---

## Part 4: IDE Refactoring Plans (R-01 through R-04)

### R-01: Split AgentExecutor
- **Current:** `Sources/Agent/AgentExecutor.swift` (1,069 lines)
- **Split into:**
  - `Sources/Agent/Core/AgentExecutor.swift` (~200 lines, loop only)
  - `Sources/Agent/Core/ToolExecutor.swift` (~150 lines)
  - `Sources/Agent/Core/VerificationEngine.swift` (~100 lines)
- **Priority:** P1 | **Effort:** Medium | **Week:** 3

### R-02: Tools Modularization
- **Split tool implementations into:**
  - `Sources/Agent/Tools/FileTools.swift`
  - `Sources/Agent/Tools/SystemTools.swift`
  - `Sources/Agent/Tools/AITools.swift`
  - `Sources/Agent/Tools/WebTools.swift`
  - `Sources/Agent/Tools/GitTools.swift`
- **Priority:** P2 | **Effort:** Medium | **Week:** 3

### R-03: Decision/Execution Separation
- **New file:** `Sources/Agent/Support/DelegationHandler.swift`
- **New file:** `Sources/Agent/Support/ErrorRecovery.swift`
- **Priority:** P2 | **Effort:** Small | **Week:** 3

### R-04: Mode Executors Refactor
- **Purpose:** Clean separation between Infinite, Explore, and Orchestration modes
- **Each mode gets its own executor that delegates to shared ToolExecutor
- **Priority:** P2 | **Effort:** Medium | **Week:** 3

---

## Part 5: Success Criteria (IDE)

### Must-Have for March
- [ ] Reads shared `config.yaml` from `~/.config/ollamabot/`
- [ ] Orchestration mode with 5-schedule framework
- [ ] Quality presets (fast/balanced/thorough)
- [ ] Session export/import in USF format
- [ ] AgentExecutor split into <500 line files
- [ ] Model tier mappings from shared config

### Performance Gates
- No UI regression (maintain 60fps)
- Config loading: <50ms additional overhead
- Session save/load: <200ms
- Orchestration state transitions: <10ms

### Quality Gates
- All schemas validate against JSON Schema
- Session round-trip (export -> import) preserves all data
- Orchestration state machine passes all CLI behavioral test cases

---

## Part 6: File Change Summary

### New Files (12)
| File | Purpose | Week |
|------|---------|------|
| `Sources/Services/SharedConfigService.swift` | YAML config reader | 1 |
| `Sources/Services/OrchestrationService.swift` | 5-schedule state machine | 3 |
| `Sources/Views/OrchestrationView.swift` | Schedule/process UI | 3 |
| `Sources/Views/FlowCodeView.swift` | Flow code display | 3 |
| `Sources/Views/QualityPresetView.swift` | Quality selector | 4 |
| `Sources/Services/CostTrackingService.swift` | Savings calculator | 4 |
| `Sources/Views/ConsultationView.swift` | Human consultation modal | 4 |
| `Sources/Services/PreviewService.swift` | Dry-run mode | 4 |
| `Sources/Services/UnifiedSessionService.swift` | USF read/write | 5 |
| `Sources/Services/SessionHandoffService.swift` | Cross-platform handoff | 5 |
| `Sources/Agent/Support/DelegationHandler.swift` | Delegation logic | 3 |
| `Sources/Agent/Support/ErrorRecovery.swift` | Error handling | 3 |

### Modified Files (6)
| File | Change | Week |
|------|--------|------|
| `Sources/Services/ConfigurationService.swift` | Delegate to SharedConfigService | 1 |
| `Sources/Services/ModelTierManager.swift` | Read from shared config | 2 |
| `Sources/Services/ContextManager.swift` | UCP schema validation | 2 |
| `Sources/Services/IntentRouter.swift` | Validate against shared config | 2 |
| `Sources/Agent/AgentExecutor.swift` | Split + add orchestration mode | 3 |
| `Sources/Services/CheckpointService.swift` | USF persistence | 5 |

### Split Files (1 -> 5+)
| Original | New Files | Week |
|----------|-----------|------|
| `AgentExecutor.swift` (1069 lines) | Core/AgentExecutor, Core/ToolExecutor, Core/VerificationEngine, Tools/*, Support/* | 3 |

---

*Agent: Claude Opus (opus-2) | IDE Master Plan | FLOW EXIT COMPLETE*
