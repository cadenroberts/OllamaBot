# MASTER PLAN: OllamaBot IDE Harmonization (opus-1)

**Agent:** opus-1
**Product:** OllamaBot IDE (Swift/macOS)
**Date:** 2026-02-05
**Strategy:** Protocols over Code -- shared contracts, native Swift implementation

---

## 1. CURRENT STATE

OllamaBot IDE is a SwiftUI-based macOS application (~34,489 LOC) providing:
- Multi-model orchestration (4 specialist models: qwen3:32b orchestrator, qwen2.5-coder:32b coder, command-r:35b researcher, qwen3-vl:32b vision)
- Sophisticated ContextManager with token budgeting, semantic compression, conversation memory, error pattern learning
- 18-tool agent system with parallel execution and caching
- External API routing (Claude, GPT, Gemini)
- OBot rules system (.obotrules, mentions, custom bots)
- Checkpoint system, Composer, Command Palette
- Full streaming with cancellation support

### Key Files

| File | LOC | Purpose |
|------|-----|---------|
| `Sources/Services/OllamaService.swift` | ~1300 | Multi-model Ollama client, streaming, warmup, performance tracking |
| `Sources/Services/ContextManager.swift` | ~700 | Token budgeting, compression, memory, error learning |
| `Sources/Agent/AgentExecutor.swift` | ~1000 | Infinite Mode agent loop, 18 tools, delegation |
| `Sources/Services/MentionService.swift` | ~400 | 14+ mention types resolution |
| `Sources/Services/OBotService.swift` | ~350 | .obotrules, custom bots, YAML workflows |
| `Sources/Services/IntentRouter.swift` | ~300 | Keyword-based model routing |

### What IDE Has That CLI Lacks

1. Multi-model orchestration (4 models with intent routing)
2. @Mention system (14+ types)
3. Checkpoint system (Windsurf-style save/restore)
4. Composer (multi-file AI agent)
5. ContextManager (token budgets, compression, memory, error learning)
6. Vision model integration
7. Web search tools
8. Git integration tools (status, diff, commit)
9. Streaming with cancellation
10. External API routing (Claude/GPT/Gemini)

### What IDE Lacks That CLI Has

1. 5-schedule orchestration framework (Knowledge/Plan/Implement/Scale/Production)
2. 3-process navigation with strict 1-2-3 rules
3. Human consultation with 60s timeout and AI fallback
4. Flow code tracking (S1P123S2P12...)
5. Quality presets (fast/balanced/thorough)
6. Cost savings tracking vs commercial APIs
7. Line range editing (-start +end)
8. Diff/dry-run/print modes
9. RAM-based tier detection with fallback chains
10. Session persistence with bash restoration

---

## 2. IDE ENHANCEMENTS REQUIRED

### 2.1 Orchestration Framework (UOP) -- CRITICAL

Port the 5-schedule state machine from `obot/internal/orchestrate/orchestrator.go` to Swift:

**New file:** `Sources/Services/OrchestratorService.swift`

```swift
@Observable
class OrchestratorService {
    enum Schedule: Int, CaseIterable {
        case knowledge = 1, plan, implement, scale, production
    }
    
    enum Process: Int { case first = 1, second, third }
    
    var currentSchedule: Schedule?
    var currentProcess: Process?
    var flowCode: FlowCode
    var schedulesRun: Set<Schedule> = []
    
    func selectSchedule(_ schedule: Schedule) throws
    func selectProcess(_ process: Process) throws  // Validate 1-2-3 navigation
    func canTerminatePrompt() -> Bool  // All 5 schedules, Production last
}
```

Navigation rules to enforce:
- P1 can go to P1 or P2
- P2 can go to P1, P2, or P3
- P3 can go to P2 or P3 (terminate schedule from P3 only)
- Prompt termination requires all 5 schedules visited, Production last

**New file:** `Sources/Views/OrchestrationView.swift` -- Schedule/process visualization
**New file:** `Sources/Views/FlowCodeView.swift` -- Flow code display (S1P123...)

Integration point: `Sources/Agent/AgentExecutor.swift` gains orchestration mode alongside existing Infinite Mode.

### 2.2 Quality Presets -- HIGH

Port from CLI's `--quality` flag system.

**New file:** `Sources/Views/QualityPresetView.swift`

```swift
enum AgentQuality: String, CaseIterable {
    case fast      // Single pass, no review
    case balanced  // Plan + execute + verify
    case thorough  // Plan + execute + verify + revise
}
```

### 2.3 Human Consultation with Timeout -- HIGH

Port from CLI's `internal/consultation/handler.go`.

**New file:** `Sources/Services/ConsultationService.swift`
**New file:** `Sources/Views/ConsultationView.swift` -- Modal dialog with countdown timer

- 60-second timeout (configurable)
- 15-second countdown warning
- AI substitute on timeout (configurable)
- Optional vs mandatory consultation types per schedule/process

### 2.4 Cost Tracking -- MEDIUM

Port from CLI's savings calculator.

**New file:** `Sources/Services/CostTrackingService.swift`

Track tokens used, calculate equivalent cost at Claude/GPT-4o/Gemini rates, display cumulative savings.

### 2.5 Session Export/Import (USF) -- MEDIUM

**New file:** `Sources/Services/UnifiedSessionService.swift`

Implement the Unified Session Format (JSON schema) enabling:
- Export IDE sessions to CLI-compatible format
- Import CLI sessions for visualization
- Session handoff: start in CLI, continue in IDE (and vice versa)

### 2.6 Configuration Schema Compliance -- LOW

**Modified file:** `Sources/Services/ConfigurationService.swift`

Read shared `~/.ollamabot/config.yaml` (or `~/.config/ollamabot/config.yaml`). Keep UserDefaults only for IDE-specific visual preferences (font size, theme). All model, agent, context, quality settings come from shared config.

### 2.7 Dry-Run Preview Mode -- LOW

**New file:** `Sources/Services/PreviewService.swift`

Show proposed changes before applying. Match CLI's `--dry-run` and `--diff` modes.

### 2.8 Line Range Editing -- LOW

Modify `Sources/Agent/AgentTools.swift` to support line range targeting like CLI's `-start +end` syntax.

---

## 3. PROTOCOL COMPLIANCE

### 3.1 Unified Orchestration Protocol (UOP)

IDE validates its orchestration against the UOP JSON schema. Same 5-schedule definitions, same navigation rules, same termination prerequisites as CLI.

### 3.2 Unified Tool Registry (UTR)

IDE normalizes its 18 tools to the canonical 22-tool registry. Tool names, parameter schemas, and return formats match the shared JSON schema exactly.

### 3.3 Unified Context Protocol (UCP)

IDE's existing ContextManager already implements UCP. Validate that token budget allocations, compression strategies, and memory behavior match the schema. Export context snapshots in UCP format for session portability.

### 3.4 Unified Model Coordinator (UMC)

IDE adds RAM-tier awareness from CLI's `tier/detect.go`. Merge with existing IntentRouter so model selection uses both intent classification and hardware capability.

### 3.5 Unified Configuration (UC)

IDE reads `~/.ollamabot/config.yaml`. Model registry, quality presets, orchestration settings, context parameters all come from shared config. IDE-specific section for visual preferences.

### 3.6 Unified State Format (USF)

IDE sessions serialize to USF JSON format. CheckpointService updated to use USF. Sessions are portable to CLI.

---

## 4. IMPLEMENTATION ROADMAP

| Week | Deliverable | Files |
|------|-------------|-------|
| 1 | Shared config reader + schema validation | `SharedConfigService.swift`, `SchemaValidator.swift` |
| 2 | Orchestration state machine + UI | `OrchestratorService.swift`, `OrchestrationView.swift`, `FlowCodeView.swift` |
| 3 | Quality presets + human consultation | `QualityPresetView.swift`, `ConsultationService.swift`, `ConsultationView.swift` |
| 4 | Cost tracking + session export | `CostTrackingService.swift`, `UnifiedSessionService.swift` |
| 5 | Integration testing + protocol compliance | Golden tests, schema validation |
| 6 | Polish, documentation, release | Migration guide, user docs |

---

## 5. SUCCESS METRICS

| Metric | Target |
|--------|--------|
| Orchestration parity with CLI | 100% -- same 5-schedule behavior |
| Tool registry compliance | 100% -- all 22 tools normalized |
| Session portability | 100% -- IDE sessions loadable in CLI |
| Config portability | 100% -- shared config works |
| Quality presets | 3 presets matching CLI behavior |
| Performance regression | Less than 5% |

---

## 6. RISK MITIGATION

| Risk | Mitigation |
|------|------------|
| Orchestration state machine complexity | CLI's orchestrator.go is working reference; port logic, not code |
| SwiftUI state management for orchestration | Use @Observable pattern, same as existing services |
| Breaking existing Infinite Mode | Orchestration is additive -- toggle between modes |
| Config migration | Read YAML alongside UserDefaults during transition |

---

**Agent:** opus-1
**Scope:** IDE enhancements only
**Dependencies:** Shared protocol schemas (UOP, UTR, UCP, UMC, UC, USF)
