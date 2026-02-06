# THE DEFINITIVE HARMONIZATION PLAN — IDE
## OllamaBot (Swift/macOS) Implementation Scope

**Agent:** sonnet-3
**Round:** 2+ (Competitive Final)
**Date:** 2026-02-05
**Scope:** IDE-specific changes required for harmonization with obot CLI

---

## ARCHITECTURE: Protocol-Native, Zero Shared Code

The IDE reads shared contracts from `~/.config/ollamabot/` and implements all logic natively in Swift. No Rust FFI. No CLI subprocess wrapping. No JSON-RPC bridge.

```
~/.config/ollamabot/
├── config.yaml              (UC: Unified Config)
├── schemas/
│   ├── tools.schema.json    (UTR)
│   ├── context.schema.json  (UCP)
│   ├── session.schema.json  (USF)
│   └── orchestration.schema.json (UOP)
├── prompts/                 (Shared prompt templates)
└── sessions/                (Cross-platform sessions)
```

---

## CRITICAL FINDINGS FROM SOURCE CODE

### Finding 1: AgentExecutor.swift Is 1000+ Lines and Needs Splitting

The IDE agent combines decision-making and execution in one file. The CLI correctly separates these (Orchestrator vs Agent). The IDE should adopt this separation:

- `AgentExecutor.swift` (~200 lines) — loop control only
- `ToolExecutor.swift` (~150 lines) — tool dispatch
- `DelegationHandler.swift` — multi-model routing
- `VerificationEngine.swift` — output validation
- `ErrorRecovery.swift` — error handling

### Finding 2: IDE Has No Formal Orchestration

The CLI has a 5-schedule state machine with strict 1-2-3 navigation rules, flow code tracking, and termination prerequisites. The IDE has "Infinite Mode" which loops until a `complete` tool call — no phases, no structure.

### Finding 3: IDE Lacks Quality Presets

The CLI offers fast/balanced/thorough pipelines. The IDE has no equivalent — every task runs the same way regardless of complexity.

### Finding 4: IDE Has No Cost Tracking

The CLI tracks token savings vs commercial APIs. The IDE has no visibility into cost.

### Finding 5: IDE Configuration Is Split

UserDefaults for app preferences, ConfigurationService.swift for runtime config, .obot/ directory for project rules. These need consolidation under the shared config while keeping UserDefaults for visual-only prefs (font size, theme).

---

## IDE CHANGES BY WEEK

### Week 1: Configuration Foundation

**New Files:**
- `Sources/Services/SharedConfigService.swift` — Reads `~/.config/ollamabot/config.yaml` using Yams library. Watches file for hot-reload. Provides typed access to all shared config sections.

**Modified Files:**
- `Sources/Services/ConfigurationService.swift` — Delegates to SharedConfigService for model config, quality presets, context settings. Retains UserDefaults only for: theme, font size, panel layout, show_token_usage.

**Behavior:**
- On launch, read `~/.config/ollamabot/config.yaml`
- If missing, generate default from current UserDefaults values
- If old `.obot/config.yaml` exists in project, read project-level overrides
- UserDefaults writes for visual prefs remain unchanged

### Week 2: Context Management Validation

**Modified Files:**
- `Sources/Services/ContextManager.swift` — Add UCP schema export method. Validate token budget allocation matches shared schema percentages (task 25%, files 33%, project 16%, history 12%, memory 12%, errors 6%).
- `Sources/Services/ModelTierManager.swift` — Read tier mappings from shared config instead of hardcoded Swift enum. Fall back to hardcoded values if config unavailable.
- `Sources/Services/IntentRouter.swift` — Read intent keywords from shared config. Validate routing decisions match shared keyword lists.

### Week 3: Orchestration Framework (Biggest Change)

**New Files:**
- `Sources/Services/OrchestrationService.swift` — Full 5-schedule state machine ported from CLI's `orchestrator.go`:
  - Schedule enum: Knowledge(1), Plan(2), Implement(3), Scale(4), Production(5)
  - Process enum: P1, P2, P3
  - Navigation rules: P1 can go to P1 or P2. P2 can go to P1, P2, or P3. P3 can go to P2, P3, or TERMINATE.
  - Termination: All 5 schedules must run at least once. Last schedule must be Production.
  - Flow code tracking: "S1P123S2P12..."
  - Human consultation: Optional at Clarify (S2P2), mandatory at Feedback (S3P3)

- `Sources/Views/OrchestrationView.swift` — SwiftUI view showing:
  - Current schedule and process
  - Navigation buttons respecting 1-2-3 rules
  - Flow code display
  - Consultation prompts with countdown timer

- `Sources/Views/FlowCodeView.swift` — Compact flow code visualization (S1P123S2P12...)

**Modified Files:**
- `Sources/Agent/AgentExecutor.swift` — Add orchestration mode alongside existing Infinite Mode. When orchestration mode is active, agent execution is scoped to current schedule/process and respects navigation rules.
- `Sources/OllamaBotApp.swift` — Add "Orchestration Mode" to AI menu alongside Infinite Mode.

### Week 4: Feature Parity

**New Files:**
- `Sources/Views/QualityPresetView.swift` — Segmented control: Fast / Balanced / Thorough. Fast = single pass. Balanced = plan + execute + review. Thorough = plan + execute + review + revise.
- `Sources/Services/CostTrackingService.swift` — Calculate token savings vs GPT-4, Claude, Gemini pricing. Display in status bar or settings.
- `Sources/Views/ConsultationView.swift` — Modal dialog with question text, text input field, countdown timer (default 60s), and "Let AI Decide" button for timeout fallback.
- `Sources/Services/PreviewService.swift` — Dry-run mode: agent executes but writes to temporary directory. Shows diff between current and proposed state. User accepts or rejects.

### Week 5: Session Portability

**New Files:**
- `Sources/Services/UnifiedSessionService.swift` — Serialize/deserialize sessions in USF JSON format. Include orchestration state, tool history, context snapshot, checkpoints.
- `Sources/Services/SessionHandoffService.swift` — Export session to `~/.config/ollamabot/sessions/{id}.json`. Import CLI sessions from same directory. Convert CLI orchestration state to IDE OrchestrationService state.

**Modified Files:**
- `Sources/Services/CheckpointService.swift` — Write checkpoints in USF format instead of custom format. Include git state, file hashes, restoration metadata.

### Week 6: Polish and Release

- Integration tests: config loading, session round-trip, schema validation
- Performance validation: no launch time regression > 5%
- Documentation: user guide for orchestration mode, quality presets, session handoff

---

## SUCCESS CRITERIA (IDE)

### Must-Have for March
- [ ] Reads `~/.config/ollamabot/config.yaml` on launch
- [ ] OrchestrationService with 5-schedule state machine
- [ ] Quality preset selector (fast/balanced/thorough)
- [ ] Cost tracking visible in UI
- [ ] Session export in USF format
- [ ] Session import from CLI USF files
- [ ] Human consultation modal with timeout

### Performance Gates
- Config loading: < 50ms additional overhead
- Session save/load: < 200ms
- No launch time regression > 5%
- Streaming UI remains 60fps during orchestration

### Quality Gates
- Orchestration navigation rules match CLI behavior exactly
- Session export/import round-trips with CLI successfully
- Config migration preserves all existing UserDefaults values
- All JSON schemas pass validation
