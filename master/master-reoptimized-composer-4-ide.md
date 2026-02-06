# OllamaBot IDE Master Harmonization Plan (Round 2 - Re-Optimized)

**Agent:** Composer-4
**Round:** 2 (Re-Optimized Consolidation)
**Date:** 2026-02-05
**Target:** OllamaBot IDE (Swift/macOS)
**Sources:** 18 Round 1 consolidation plans from Sonnet-2, Opus-1, Composer-2/3/5, Gemini-1/4/5, GPT-1, Unified Implementation Strategy

---

## Executive Summary

Protocol-first harmonization strategy for the OllamaBot IDE. Shared YAML/JSON schemas ensure behavioral equivalence with obot CLI without forcing code sharing. The IDE maintains its native Swift implementation while reading shared contracts from `~/.config/ollamabot/`.

**Core Principle:** Establish behavioral equivalence through shared contracts, allowing the IDE to maintain its SwiftUI strengths while ensuring consistent user experience with the CLI.

---

## Part 1: IDE Architecture

```
OllamaBot IDE (Swift)
├── SwiftUI Interface (existing)
├── SharedConfigService (NEW - reads ~/.config/ollamabot/config.yaml)
├── ToolRegistryService (NEW - validates against UTR)
├── OrchestrationService (NEW - 5-schedule state machine)
├── Local Agent Engine (existing AgentExecutor)
├── ContextManager (existing - validates against UCP)
├── UnifiedSessionService (NEW - USF import/export)
├── QualityPresetService (NEW - fast/balanced/thorough)
├── CostTrackingService (NEW - savings dashboard)
├── ConsultationService (NEW - human consultation modal)
└── PreviewService (NEW - dry-run mode)
```

---

## Part 2: Unified Configuration (IDE Side)

**SharedConfigService.swift** reads `~/.config/ollamabot/config.yaml`:

```yaml
version: "2.0"
created_by: "obot" | "ollamabot"

models:
  tier_detection:
    auto: true
    thresholds:
      minimal: [0, 15]
      compact: [16, 23]
      balanced: [24, 31]
      performance: [32, 63]
      advanced: [64, 999]
  orchestrator:
    default: qwen3:32b
    tier_mapping:
      minimal: qwen3:8b
      balanced: qwen3:14b
      performance: qwen3:32b
  coder:
    default: qwen2.5-coder:32b
    tier_mapping:
      minimal: deepseek-coder:1.3b
      balanced: qwen2.5-coder:14b
      performance: qwen2.5-coder:32b
  researcher:
    default: command-r:35b
    tier_mapping:
      minimal: command-r:7b
      performance: command-r:35b
  vision:
    default: qwen3-vl:32b
    tier_mapping:
      minimal: llava:7b
      performance: qwen3-vl:32b

orchestration:
  default_mode: "orchestration"
  schedules:
    - id: knowledge
      processes: [research, crawl, retrieve]
      model: researcher
    - id: plan
      processes: [brainstorm, clarify, plan]
      model: coder
      consultation:
        clarify: {type: optional, timeout: 60}
    - id: implement
      processes: [implement, verify, feedback]
      model: coder
      consultation:
        feedback: {type: mandatory, timeout: 300}
    - id: scale
      processes: [scale, benchmark, optimize]
      model: coder
    - id: production
      processes: [analyze, systemize, harmonize]
      model: [coder, vision]

context:
  max_tokens: 32768
  budget_allocation:
    task: 0.25
    files: 0.33
    project: 0.16
    history: 0.12
    memory: 0.12
    errors: 0.06
    reserve: 0.06
  compression:
    enabled: true
    strategy: semantic_truncate
    preserve: [imports, exports, signatures, errors]

quality:
  fast:
    iterations: 1
    verification: none
  balanced:
    iterations: 2
    verification: llm_review
  thorough:
    iterations: 3
    verification: expert_judge

platforms:
  ide:
    theme: dark
    font_size: 14
    show_token_usage: true

ollama:
  url: http://localhost:11434
  timeout_seconds: 120
```

**Swift Interface:**

```swift
@Observable
final class SharedConfigService {
    private(set) var config: UnifiedConfig

    struct UnifiedConfig: Codable {
        var version: String
        var ai: AIConfig
        var orchestration: OrchestrationConfig
        var context: ContextConfig
        var quality: QualityConfig
        var platforms: PlatformConfig
    }

    func loadSharedConfig() throws -> UnifiedConfig
    func watchForChanges()
}
```

---

## Part 3: IDE Enhancements

### I-01: OrchestrationService.swift

Port CLI's 5-schedule x 3-process framework to native Swift. Works alongside existing Infinite Mode and Explore Mode.

```swift
@Observable
final class OrchestrationService {
    enum Schedule: Int, CaseIterable {
        case knowledge = 1, plan = 2, implement = 3, scale = 4, production = 5
    }
    enum Process: Int { case first = 1, second = 2, third = 3 }

    struct OrchestrationState {
        var currentSchedule: Schedule
        var currentProcess: Process
        var flowCode: String
        var history: [(Schedule, Process, Date)]
        var isActive: Bool
    }

    func startOrchestration(task: String) async
    func navigateToSchedule(_ schedule: Schedule) throws
    func advanceProcess() throws
    func canNavigateTo(_ schedule: Schedule) -> Bool
    func requestHumanConsultation(question: String, timeout: Int) async -> String?
}
```

**Mode Mapping:**
- Infinite Mode -> Plan(P2,P3) + Implement(P1,P2,P3)
- Explore Mode -> Production(P1,P2,P3) with reflection loop
- Full Orchestration -> All 5 schedules

### I-05: Quality Presets

Segmented control for fast/balanced/thorough in chat interface. Reads presets from shared config. Controls agent iteration count and verification mode.

### I-06: Human Consultation Modal

Modal dialog with countdown timer when agent requests user input. AI fallback on timeout. Works with both orchestration and agent modes.

### I-07: Dry-Run Preview Mode

Toggle that captures proposed changes as diffs before applying. Users approve/reject individual changes. Matches CLI's --dry-run and --diff modes.

### I-09: Cost Tracking Dashboard

Token usage tracking per model per session. Estimated savings vs commercial API pricing. Session and lifetime totals displayed in dashboard widget.

### I-10: Session Export/Import (USF)

Export IDE sessions in USF JSON format to `~/.config/ollamabot/sessions/`. Import CLI-created sessions. Full session handoff between platforms.

### I-11: Configuration Migration

Read shared YAML config for AI/orchestration settings. Keep UserDefaults only for IDE-specific visual prefs (font size, theme). Hot-reload on config file changes.

---

## Part 4: Unified Tool Registry (IDE Side)

IDE validates tool calls against shared registry at `~/.config/ollamabot/tools/registry.yaml`. 21 tools with alias mapping for backward compatibility:

| Tool ID | Category | IDE Status |
|---------|----------|------------|
| think | core | existing |
| complete | core | existing |
| ask_user | core | NEW |
| file.read | file | existing (read_file) |
| file.write | file | existing (write_file) |
| file.edit | file | existing (edit_file) |
| file.edit_range | file | NEW |
| file.delete | file | existing |
| file.search | file | existing (search_files) |
| file.list | file | existing |
| system.run | system | existing (run_command) |
| ai.delegate.coder | delegation | existing (delegate_to_coder) |
| ai.delegate.researcher | delegation | existing (delegate_to_researcher) |
| ai.delegate.vision | delegation | existing (delegate_to_vision) |
| web.search | web | existing (web_search) |
| web.fetch | web | NEW |
| git.status | git | existing |
| git.diff | git | existing |
| git.commit | git | existing |
| checkpoint.save | session | existing |
| checkpoint.restore | session | existing |

---

## Part 5: Context Protocol (IDE Side)

Existing ContextManager.swift validates output against UCP JSON schema. Token budgeting, semantic compression, memory, and error learning already implemented. Ensure exported context matches UCP format for cross-platform sharing.

---

## Part 6: Session Format (IDE Side)

UnifiedSessionService.swift reads/writes USF JSON:

```json
{
  "version": "1.0",
  "session_id": "uuid",
  "created_at": "ISO-8601",
  "platform_origin": "ide",
  "task": {"original": "...", "status": "in_progress"},
  "orchestration": {"current_schedule": 3, "flow_code": "S2P123S3P1"},
  "steps": [{"step_number": 1, "tool_id": "file.read", "success": true}],
  "checkpoints": [{"id": "cp-1", "git_commit": "abc123"}],
  "stats": {"total_tokens": 15000, "files_modified": 3}
}
```

---

## Part 7: Implementation Roadmap (IDE)

### Week 1: Foundation
- SharedConfigService.swift (YAML reader using Yams)
- Config migration from UserDefaults
- File watcher for hot-reload

### Week 3: Orchestration
- OrchestrationService.swift (5-schedule state machine)
- OrchestrationView.swift (schedule/process UI)
- FlowCodeView.swift (flow code display)

### Week 4: Feature Parity
- QualityPresetView.swift (fast/balanced/thorough)
- ConsultationView.swift (modal with timeout)
- PreviewService.swift (dry-run mode)
- CostDashboardView.swift (savings tracker)

### Week 5: Session Portability
- UnifiedSessionService.swift (USF support)
- SessionHandoffService.swift (export/import)

---

## Part 8: Success Metrics (IDE)

- Configuration reads from shared config.yaml
- Orchestration mode available (5-schedule framework)
- Quality presets functional (fast/balanced/thorough)
- Session export/import works with CLI sessions
- All tool calls validated against shared registry
- No performance regression > 5%

---

**This plan represents composer-4's final IDE-specific master output from the 3-round, 150+ plan consolidation process.**
