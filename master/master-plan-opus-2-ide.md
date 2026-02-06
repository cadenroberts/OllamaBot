# FINAL CONSOLIDATED MASTER PLAN: OllamaBot IDE Harmonization
## Agent: opus-2 | IDE Focus | March 2026 Release

**Agent:** Claude Opus (opus-2)
**Date:** 2026-02-05
**Scope:** OllamaBot IDE (Swift/macOS) enhancements for harmonization
**Status:** FLOW EXIT COMPLETE

---

## Executive Summary

This plan covers all IDE-side changes required to harmonize OllamaBot IDE with obot CLI under the Protocol-First Architecture. The IDE gains orchestration capabilities, quality presets, cost tracking, session portability, and shared configuration -- while preserving its existing multi-model delegation, rich UI, and context management strengths.

---

## Architecture: IDE as Cockpit

The IDE becomes the rich visualization and control layer that reads shared protocols and provides native macOS UX for all harmonized features.

```
~/.config/ollamabot/config.yaml  <-- Shared config (read by IDE)
~/.config/ollamabot/schemas/     <-- Protocol schemas (validated by IDE)
~/.config/ollamabot/sessions/    <-- Cross-platform sessions (read/write)

OllamaBot IDE (Swift)
├── EXISTING (preserved):
│   ├── AgentExecutor.swift      -- Infinite Mode engine (18 tools)
│   ├── ExploreAgentExecutor.swift -- Explore Mode
│   ├── CycleAgentManager.swift  -- Multi-agent orchestration
│   ├── ContextManager.swift     -- Token-budgeted context
│   ├── OllamaService.swift      -- Ollama API client
│   ├── IntentRouter.swift       -- Intent-based model routing
│   ├── OBotService.swift        -- .obotrules, bots, context, templates
│   └── MentionService.swift     -- @mention system
│
├── NEW (March harmonization):
│   ├── SharedConfigService.swift       -- YAML config reader (Yams)
│   ├── OrchestrationService.swift      -- 5-schedule x 3-process state machine
│   ├── OrchestrationView.swift         -- Schedule/process visualization
│   ├── FlowCodeView.swift              -- Flow code display (S1P123...)
│   ├── QualityPresetView.swift         -- Fast/Balanced/Thorough selector
│   ├── CostTrackingService.swift       -- Token usage and savings
│   ├── ConsultationView.swift          -- Human consultation modal
│   ├── PreviewService.swift            -- Dry-run mode
│   ├── UnifiedSessionService.swift     -- USF read/write
│   └── SessionHandoffService.swift     -- CLI/IDE session export/import
│
└── REFACTORED:
    ├── AgentExecutor.swift → split into OrchestratorEngine + ExecutionAgent
    ├── ConfigurationService.swift → reads shared YAML config
    └── ModelTierManager.swift → reads tier mappings from shared config
```

---

## IDE Enhancement Plan (10 items)

### I-01: Shared Config Service (YAML reader)
- **File:** `Sources/Services/SharedConfigService.swift` (NEW)
- **Purpose:** Read `~/.config/ollamabot/config.yaml` using Yams library
- **Integration:** ConfigurationService delegates shared settings to this service, retains UserDefaults for IDE-only visual prefs

### I-02: OrchestrationService (5-schedule state machine)
- **File:** `Sources/Services/OrchestrationService.swift` (NEW)
- **Purpose:** Port CLI's 5-schedule x 3-process orchestrator to Swift
- **Schedules:** Knowledge, Plan, Implement, Scale, Production
- **Navigation:** P1 -> {P1,P2}, P2 -> {P1,P2,P3}, P3 -> {P2,P3,terminate}
- **Termination:** All 5 schedules completed, Production was last

### I-03: Orchestration UI
- **Files:** `Sources/Views/OrchestrationView.swift`, `Sources/Views/FlowCodeView.swift` (NEW)
- **Purpose:** Visual schedule/process display with flow code tracking (S1P123S2P12...)

### I-04: Quality Presets UI
- **File:** `Sources/Views/QualityPresetView.swift` (NEW)
- **Purpose:** Fast/Balanced/Thorough selector matching CLI's --quality flag
- **Fast:** Single-pass execution, no review (~30s)
- **Balanced:** Plan + execute + review (~3min)
- **Thorough:** Plan + execute + review + revise (~10min)

### I-05: Cost Tracking Service
- **File:** `Sources/Services/CostTrackingService.swift` (NEW)
- **Purpose:** Calculate token usage and savings vs commercial APIs (Claude, GPT-4)

### I-06: Human Consultation Modal
- **File:** `Sources/Views/ConsultationView.swift` (NEW)
- **Purpose:** Modal dialog with countdown timer and AI fallback
- **Clarify:** Optional, 60s timeout, auto-assume best practice
- **Feedback:** Mandatory, 300s timeout, auto-assume approval

### I-07: Dry-Run Preview Mode
- **File:** `Sources/Services/PreviewService.swift` (NEW)
- **Purpose:** Preview agent file changes before applying (diff view)

### I-08: Unified Session Service (USF)
- **File:** `Sources/Services/UnifiedSessionService.swift` (NEW)
- **Purpose:** Read/write sessions in Unified Session Format (JSON)

### I-09: Session Handoff
- **File:** `Sources/Services/SessionHandoffService.swift` (NEW)
- **Purpose:** Export IDE session to CLI-compatible format, import CLI sessions into IDE

### I-10: Model Tier Manager (shared config)
- **File:** `Sources/Services/ModelTierManager.swift` (MODIFY)
- **Purpose:** Read tier mappings from shared config.yaml instead of hardcoded values

---

## IDE Refactoring (4 items)

### R-01: Split AgentExecutor
- **Current:** `AgentExecutor.swift` (1069 lines)
- **Target:** `OrchestratorEngine.swift` (decision logic) + `ExecutionAgent.swift` (tool execution)

### R-02: Tools Modularization
- **Current:** Tools inline in AgentExecutor
- **Target:** Separate tool files per category (file, system, web, git, delegation, core)

### R-03: Decision/Execution Engine Separation
- **Purpose:** OrchestratorEngine owns planning/routing, ExecutionAgent owns tool calls

### R-04: Mode Executors Refactor
- **Purpose:** Infinite Mode, Explore Mode, and Orchestration Mode share common ExecutionAgent

---

## Success Criteria

- [ ] Shared config.yaml read by IDE
- [ ] Orchestration mode with 5-schedule framework
- [ ] Quality presets (fast/balanced/thorough)
- [ ] Session format cross-compatible with CLI (USF)
- [ ] Cost tracking dashboard
- [ ] Human consultation with timeout
- [ ] Dry-run preview mode
- [ ] AgentExecutor split into <500-line files
- [ ] No performance regression >5%

---

*Agent: Claude Opus (opus-2) | IDE Master Plan | FLOW EXIT COMPLETE*
