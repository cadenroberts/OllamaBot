# OllamaBot IDE Master Plan (sonnet-3)
## Protocol-Native Harmonization — IDE Scope

**Agent:** sonnet-3 | **Product:** OllamaBot IDE (Swift/SwiftUI)
**Grounded in:** Actual source code analysis of 63 Swift files
**Timeline:** 6 weeks to March 2026 release

---

## IDE Current State (Verified)

### Existing Strengths
- **AgentExecutor** with 18 tools (read, write, edit, search, delegate, web, git)
- **Multi-model orchestration** (4 roles: orchestrator, coder, researcher, vision)
- **ContextManager** with token budgeting (task 25%, files 33%, project 16%, history 12%, memory 12%, errors 6%)
- **Semantic compression** preserving imports/signatures/error lines
- **Conversation memory** with relevance scoring and pruning
- **.obotrules** project-level configuration
- **Mention system** (@file, @bot, @context)
- **Checkpoint/autosave** with recovery on launch

### Verified Gaps (What IDE Lacks)
- No structured orchestration (5-schedule framework exists only in CLI)
- No quality presets (fast/balanced/thorough)
- No cost/savings tracking
- No dry-run/preview mode
- No session export to CLI-compatible format
- Configuration lives in UserDefaults, not shared YAML
- No flow code visualization

---

## IDE Implementation Plan

### Week 1: Shared Configuration Reader

**Goal:** IDE reads `~/.config/ollamabot/config.yaml` alongside UserDefaults.

**New Files:**
- `Sources/Services/SharedConfigService.swift` — YAML config reader using Yams library
  - Reads unified config at `~/.config/ollamabot/config.yaml`
  - Falls back to UserDefaults for IDE-specific visual prefs (theme, font size)
  - Exposes model registry, quality presets, orchestration settings
  - Hot-reload on file change via FSEvents

**Modified Files:**
- `Sources/Services/ConfigurationService.swift` — Delegate model/agent settings to SharedConfigService; retain UserDefaults only for UI preferences

**Validation:**
- Config loads in <50ms
- All model definitions resolve correctly
- IDE launches with or without shared config file present

### Week 2: Context & Model Alignment

**Goal:** Validate IDE context management against shared UCP schema; adopt shared tier mappings.

**Modified Files:**
- `Sources/Services/ContextManager.swift` — Add schema validation for token budget allocations; ensure compression strategies match UCP spec
- `Sources/Services/ModelTierManager.swift` — Read tier-to-model mappings from shared config instead of hardcoded values
- `Sources/Services/IntentRouter.swift` — Validate intent keywords against shared config's `selection.intent_routing.keywords`

**Validation:**
- Token budgets match UCP schema percentages
- Model selection uses shared tier definitions
- Intent routing keywords are consistent with CLI

### Week 3: Orchestration Framework (Biggest Feature Port)

**Goal:** Port the 5-schedule orchestration state machine from CLI to native Swift.

**New Files:**
- `Sources/Services/OrchestrationService.swift` — Native Swift state machine
  - 5 schedules: Knowledge, Plan, Implement, Scale, Production
  - 3 processes per schedule with 1↔2↔3 navigation rules
  - Termination conditions: all schedules run once, end with Production
  - Flow code generation and tracking (S1P123S2P12...)
  - Human consultation integration (Clarify: optional 60s, Feedback: mandatory 300s)

- `Sources/Views/OrchestrationView.swift` — Schedule/process visualization
  - Visual state machine showing current position
  - Schedule completion indicators
  - Process navigation controls

- `Sources/Views/FlowCodeView.swift` — Flow code display
  - Real-time flow code string (S1P123...)
  - Visual schedule/process history

**Modified Files:**
- `Sources/Agent/AgentExecutor.swift` — Add orchestration mode alongside existing infinite mode
  - New `executionMode` enum: `.infinite`, `.orchestrated`, `.explore`
  - Route to OrchestrationService when orchestrated mode selected

**Critical Note:** Port the state machine NATIVELY in Swift. Do NOT wrap the Go binary. The CLI orchestrator uses Go closure callbacks (`selectScheduleFn`, `selectProcessFn`, `executeProcessFn`) that are not serializable over RPC. A native port is simpler and more reliable.

**Validation:**
- Same prompt produces same schedule/process flow as CLI
- Navigation rules enforced (cannot skip from P1 to P3)
- Flow code format matches CLI output exactly

### Week 4: Feature Parity

**New Files:**
- `Sources/Views/QualityPresetView.swift` — Fast/Balanced/Thorough selector
  - Fast: single-pass execution
  - Balanced: plan + execute + review
  - Thorough: plan + execute + review + revise
  - Wired to agent max_iterations and review_enabled flags

- `Sources/Services/CostTrackingService.swift` — Token savings calculator
  - Track tokens per model per session
  - Calculate savings vs GPT-4/Claude pricing
  - Persist across sessions

- `Sources/Views/ConsultationView.swift` — Modal dialog with countdown timer
  - Configurable timeout (default 60s for clarify, 300s for feedback)
  - Fallback action on timeout (configurable per consultation type)
  - Maps to orchestration consultation points

- `Sources/Services/PreviewService.swift` — Dry-run mode
  - Execute agent plan without writing files
  - Show diff preview of all proposed changes
  - User confirms before applying

**Validation:**
- Quality presets produce measurably different behavior
- Cost tracking persists across app restarts
- Consultation timeouts fire correctly
- Dry-run produces identical plan to live execution

### Week 5: Session Portability

**New Files:**
- `Sources/Services/UnifiedSessionService.swift` — USF v2.0 support
  - Serialize session state to JSON matching USF schema
  - Include orchestration state, execution history, context snapshot, checkpoints

- `Sources/Services/SessionHandoffService.swift` — Export/import
  - Export: write session to `~/.config/ollamabot/sessions/{id}.json`
  - Import: read CLI-created session, resume in IDE
  - Validate against USF JSON schema before import

**Modified Files:**
- `Sources/Services/CheckpointService.swift` — Update serialization to USF format
  - Add flow_code, schedule_counts, navigation_history fields
  - Backward-compatible: read old format, write new format

**Validation:**
- Session created in CLI loads in IDE with full state
- Session created in IDE loads in CLI with full state
- Round-trip: IDE → export → CLI → export → IDE preserves all data

### Week 6: Polish & Release

- AgentExecutor.swift refactor: split 1069-line file into 5 files
  - `AgentExecutor.swift` (~200 lines) — Core loop
  - `ToolExecutor.swift` (~150 lines) — Tool dispatch
  - `VerificationEngine.swift` (~100 lines) — Output validation
  - `DelegationHandler.swift` — Multi-model routing
  - `ErrorRecovery.swift` — Retry and fallback logic
- Integration tests for schema compliance
- Performance validation (no regression >5%)
- Documentation and migration guide

---

## Success Criteria (IDE)

### Must-Have for March
- [ ] Reads shared `config.yaml`
- [ ] Orchestration mode with 5-schedule framework
- [ ] Quality presets (fast/balanced/thorough)
- [ ] Session export to USF format
- [ ] Session import from CLI-created USF
- [ ] Cost tracking visible in UI

### Performance Gates
- Config loading: <50ms additional overhead
- Session save/load: <200ms
- Context build: <500ms for 500-file project
- No regression >5% in any existing functionality

### Quality Gates
- All schemas validate against JSON Schema
- Session round-trip preserves all data
- Orchestration state machine matches CLI behavior
- AgentExecutor.swift split into files <500 lines each
