# FINAL CONSOLIDATED MASTER PLAN: OllamaBot IDE Harmonization
## Agent: opus-2 | Round: 2+ | IDE-Specific View

**Agent:** Claude Opus (opus-2)
**Date:** 2026-02-05
**Scope:** ollamabot IDE (Swift/SwiftUI) harmonization with obot CLI
**Intelligence Source:** 230+ agent contributions across 21 rounds, direct source code analysis
**Status:** FLOW EXIT COMPLETE

---

## Executive Summary

Protocol-first harmonization strategy for the March 2026 release. Shared behavioral contracts (YAML/JSON schemas) between IDE and CLI -- no shared code, no Rust FFI, no CLI-as-server dependency. The IDE implements all protocols natively in Swift while reading the same shared configuration and schemas as the CLI.

**Key Decisions:**
1. Protocol-First Architecture -- shared YAML/JSON schemas, NOT shared code
2. Zero Rust for March -- pure Swift, no FFI complexity
3. CLI-as-Server is OPTIONAL -- IDE implements orchestration natively in Swift
4. XDG-Compliant Config -- `~/.config/ollamabot/config.yaml` with backward-compat symlink
5. 6-Week Realistic Timeline -- respects ~7 weeks remaining before March release
6. Tool Tier Migration -- IDE has 18+ read-write tools; CLI has 12 write-only; bridge incrementally

---

## IDE Current State

| Metric | Value |
|--------|-------|
| LOC | ~34,489 |
| Files | 63 |
| Modules | 5 |
| Agent Tools | 18+ (read-write, autonomous) |
| Models Supported | 4 (orchestrator, coder, researcher, vision) |
| Token Management | Sophisticated (ContextManager) |
| Orchestration | None (infinite loop + explore mode) |
| Config Format | UserDefaults |
| Session Persistence | In-memory only |

---

## IDE Architecture: What Changes

### Shared Contracts Layer

The IDE reads shared specifications from `~/.config/ollamabot/`:
```
~/.config/ollamabot/
+-- config.yaml              (UC: Unified Config)
+-- schemas/
|   +-- tools.schema.json    (UTR: Tool Registry)
|   +-- context.schema.json  (UCP: Context Protocol)
|   +-- session.schema.json  (USF: Session Format)
|   +-- orchestration.schema.json (UOP: Orchestration Protocol)
+-- prompts/                 (Shared prompt templates)
+-- sessions/                (Cross-platform sessions)
```

### Agent Architecture: DecisionEngine + ExecutionEngine

Split `AgentExecutor.swift` (1069 lines) into:
- `OrchestratorEngine.swift` -- owns decision logic (task analysis, model routing, tool selection, schedule navigation)
- `ExecutionAgent.swift` -- owns execution (tool dispatch, action recording, result reporting)

This aligns with CLI's existing `internal/orchestrate/` + `internal/agent/` separation.

---

## 6-Week IDE Implementation Plan

### Week 1: Configuration + Schemas (Foundation)

**IDE File Changes:**
- `Sources/Services/SharedConfigService.swift` -- NEW: YAML config reader (using Yams library)
- `Sources/Services/ConfigurationService.swift` -- Update to read shared config, keep UserDefaults for UI-only prefs (font, theme, window position)

**Config Schema (v2.0):**
```yaml
# ~/.config/ollamabot/config.yaml
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
  ide:
    streaming_ui: true
    visual_flow_tracking: true
    rich_diff_preview: true
```

### Week 2: Context Management + Model Coordination

**IDE File Changes:**
- `Sources/Services/ContextManager.swift` -- Validate output against UCP schema
- `Sources/Services/ModelTierManager.swift` -- Read tier mappings from shared config (not hardcoded)
- `Sources/Services/IntentRouter.swift` -- Validate intent keywords against shared config

### Week 3: Orchestration in IDE

**IDE File Changes:**
- `Sources/Services/OrchestrationService.swift` -- NEW: 5-schedule x 3-process state machine (ported from CLI's Go orchestrator to native Swift)
- `Sources/Views/OrchestrationView.swift` -- NEW: Schedule/process visualization with flow code display
- `Sources/Views/FlowCodeView.swift` -- NEW: Flow code display (S1P123S2P12...)
- `Sources/Agent/AgentExecutor.swift` -- Add orchestration mode alongside existing infinite/explore modes

**Why native Swift, not CLI bridge:** The CLI orchestrator uses closure-injected Go callbacks that are not serializable to JSON-RPC. Porting the state machine to Swift is faster and more reliable than wrapping the CLI binary.

### Week 4: Feature Parity

**IDE File Changes:**
- `Sources/Views/QualityPresetView.swift` -- NEW: Fast/Balanced/Thorough selector
- `Sources/Services/CostTrackingService.swift` -- NEW: Token usage and savings calculator
- `Sources/Views/ConsultationView.swift` -- NEW: Modal dialog with countdown timer and AI fallback
- `Sources/Services/PreviewService.swift` -- NEW: Dry-run mode for agent file changes

### Week 5: Session Format + Integration

**IDE File Changes:**
- `Sources/Services/UnifiedSessionService.swift` -- NEW: USF support (read/write JSON)
- `Sources/Services/SessionHandoffService.swift` -- NEW: Export to CLI format, import from CLI
- `Sources/Services/CheckpointService.swift` -- Update to persist using USF format

**USF Schema:**
```json
{
  "version": "1.0",
  "session_id": "sess_20260205_153045",
  "created_at": "2026-02-05T15:30:45Z",
  "source_platform": "ide",
  "task": {
    "description": "Implement JWT authentication",
    "intent": "coding",
    "quality_preset": "balanced"
  },
  "workspace": {
    "path": "/Users/dev/project",
    "git_branch": "feature/auth"
  },
  "orchestration_state": {
    "flow_code": "S1P123S2P12",
    "current_schedule": "implement",
    "current_process": 2,
    "completed_schedules": ["knowledge", "plan"]
  },
  "conversation_history": [],
  "files_modified": [],
  "checkpoints": []
}
```

### Week 6: Polish + Documentation + Release

**Deliverables:**
1. User migration guide (how to update from old config)
2. Protocol specification documentation
3. Integration test suite (schema compliance + session portability)
4. Performance validation (no regression > 5%)
5. Release build and packaging

---

## IDE Refactoring Plans (R-01 through R-04)

- **R-01:** Split AgentExecutor (1069 lines) into OrchestratorEngine + ExecutionAgent
- **R-02:** Tools Modularization
- **R-03:** Decision/Execution Engine Separation
- **R-04:** Mode Executors Refactor

---

## IDE Enhancement Plans (I-01 through I-10)

- **I-01:** Shared Config Service (YAML reader)
- **I-02:** OrchestrationService (5-schedule state machine)
- **I-03:** Orchestration UI (schedule/process visualization)
- **I-04:** Quality Presets UI
- **I-05:** Cost Tracking Service
- **I-06:** Human Consultation Modal
- **I-07:** Dry-Run Preview Mode
- **I-08:** Unified Session Service (USF)
- **I-09:** Session Handoff (export/import)
- **I-10:** Model Tier Manager (shared config integration)

---

## Success Criteria (IDE)

### Must-Have for March Release
- [ ] Shared `config.yaml` read by IDE
- [ ] IDE has orchestration mode (5-schedule framework)
- [ ] IDE has quality presets (fast/balanced/thorough)
- [ ] Session format is cross-compatible (file-based USF)
- [ ] All 6 protocol schemas defined and validated
- [ ] AgentExecutor split into DecisionEngine + ExecutionEngine

### Performance Gates
- No regression > 5%
- Config loading: < 50ms additional overhead
- Session save/load: < 200ms
- Context build time: < 500ms for 500-file project

---

## Consensus

All agents agreed on:
1. Protocol-first over code-sharing
2. Feature parity goal
3. Phased, backward-compatible approach
4. Session portability
5. 5-schedule orchestration as canonical model
6. Shared YAML configuration

Resolved disagreements:
- CLI-as-Server: **Deferred to v2.0** (orchestrator uses closures, not serializable)
- Rust FFI: **Zero Rust** (bottleneck is inference, not counting)
- Config Location: **XDG-compliant** `~/.config/ollamabot/` with symlink
- Timeline: **6 weeks** (March deadline non-negotiable)

---

*Agent: Claude Opus (opus-2) | IDE Master Plan | FLOW EXIT COMPLETE*
