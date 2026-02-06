# Master Plan: opus-3 -- IDE Harmonization (ollamabot)

**Agent:** Claude Opus (opus-3)
**Round:** 2
**Date:** 2026-02-05
**Product:** ollamabot IDE (Swift/SwiftUI)
**Status:** MASTER VERSION

---

## 1. Architecture Consensus

After 138+ polls observing 94 plan files from 5 agent families (sonnet, opus, composer, gemini, gpt), all agents converged on:

**"Engine & Cockpit"** -- obot CLI (Go) serves as execution engine; ollamabot IDE (Swift) serves as visualization layer. Both products share behavioral contracts through JSON/YAML schemas. Neither shares compiled code.

This architecture was originated by opus-1 and universally adopted. It was later refined by sonnet-3, who proved that the CLI-as-JSON-RPC-server variant was premature for the March release window due to the orchestrator's closure-based callback structure.

---

## 2. The 6 Unified Protocols

All master plans in `plans_2` referenced these protocols:

| # | Protocol | Abbrev | Purpose |
|---|----------|--------|---------|
| 1 | Agent Execution Protocol | AEP | Tool call/result format, execution flow |
| 2 | Orchestration Protocol | OP | 5 schedules x 3 processes, navigation rules, flow codes |
| 3 | Context Management Protocol | CMP | Token budgets, semantic compression, memory, error learning |
| 4 | Tool Registry Specification | TRS | 22 standardized tools with aliases and platform markers |
| 5 | Configuration Schema | CS | Shared `~/.config/ollamabot/config.yaml` |
| 6 | Session Format | SF | Cross-platform session portability (JSON) |

---

## 3. IDE-Specific Implementation Plans

### IDE Integration (I-01 through I-08)

| Plan | Title | Priority | Effort | Dependencies |
|------|-------|----------|--------|--------------|
| I-01 | CLI Bridge Service | P0 | Medium | S-01 through S-07 (deferred to v2.0) |
| I-02 | WebSocket Event Handler | P0 | Small | I-01 |
| I-03 | Server/Local Mode Toggle | P1 | Small | I-01 |
| I-04 | Orchestration Mode UI | P1 | Large | P-02 |
| I-05 | Quality Presets UI | P1 | Small | P-05 |
| I-06 | Session Persistence | P1 | Medium | P-06 |
| I-07 | Configuration Migration (UserDefaults to YAML) | P0 | Small | P-05 |
| I-08 | Tool Registry Loader | P0 | Small | P-04 |

### IDE File Reorganization (R-01 through R-06)

| Plan | Title | Priority | Effort | Dependencies |
|------|-------|----------|--------|--------------|
| R-01 | Split AgentExecutor (1069 lines to 5 files) | P1 | Medium | None |
| R-02 | Tools Modularization | P1 | Small | R-01 |
| R-03 | Orchestration Module Creation | P1 | Medium | P-02, R-01 |
| R-04 | Decision/Execution Engine Separation | P1 | Medium | R-01 |
| R-05 | Context Manager Enhancement | P1 | Small | P-03 |
| R-06 | Mode Executors Refactor | P2 | Small | R-03 |

### IDE Enhancements (from consensus)

The following features were identified as missing from the IDE and needed for March parity:

1. **Orchestration Framework** -- Port 5-schedule x 3-process state machine to Swift natively (do NOT wrap CLI binary; the orchestrator uses closure callbacks that are not serializable)
2. **Quality Presets** -- Add fast/balanced/thorough UI selector reading from shared config
3. **Session Persistence** -- Implement Unified Session Format (USF) for cross-platform portability
4. **Human Consultation** -- Modal dialog with 60s timeout and AI fallback
5. **Flow Code Tracking** -- S1P123 visualization in orchestration UI
6. **Cost Tracking** -- Token usage and savings display in status bar
7. **Dry-Run Mode** -- Preview agent file changes without applying

### IDE Refactoring Specifics

Split `AgentExecutor.swift` (1069 lines) into:
- `OrchestratorEngine.swift` -- Decision logic, schedule/process navigation
- `ExecutionAgent.swift` -- Tool execution, action recording
- `ToolExecutor.swift` -- Individual tool implementations
- `VerificationEngine.swift` -- Output validation, error recovery
- `DelegationHandler.swift` -- Multi-model coordination

### IDE Configuration Migration

- Read shared `~/.config/ollamabot/config.yaml` using Yams library
- Retain `UserDefaults` ONLY for IDE-specific visual preferences (font size, theme, panel layout)
- All model settings, quality presets, orchestration config, and context budgets move to shared YAML
- Implement `SharedConfigService.swift` with file watcher for hot-reload

---

## 4. Critical Path for IDE

```
Protocol Schemas (P-01..P-06) [Week 1]
    |
    +--> Config Migration I-07 [Week 1]
    |
    +--> IDE Refactor R-01..R-04 [Weeks 2-3, parallel]
    |
    +--> OrchestrationService I-04 [Week 3, after P-02 + R-01]
    |
    +--> Quality Presets I-05 [Week 4]
    |
    +--> Session Persistence I-06 [Week 5]
    |
    +--> Testing T-02, T-04 [Week 6]
```

---

## 5. Key Findings from Comparative Analysis

### What Sonnet Saw That Affected IDE Plans

1. **CLI-as-server deferred to v2.0** -- The IDE must implement orchestration natively in Swift rather than wrapping the CLI binary. The CLI orchestrator's closure-based callbacks cannot be trivially serialized into JSON-RPC.

2. **Tool tier migration** -- The IDE already has 18+ read-write tools (Tier 2). The CLI only has 12 write-only actions (Tier 1). The IDE's tool system is ahead; the focus is on normalizing tool IDs to match the shared registry.

3. **Config path resolution** -- IDE reads `~/.config/ollamabot/config.yaml` (XDG-compliant). Backward-compat symlink from `~/.config/obot/` handles existing CLI users.

### What Opus Got Right for IDE

1. **Engine & Cockpit framing** -- The IDE is the "Cockpit." Its role is visualization, control, and native UX. It does not re-implement execution logic; it reads the same contracts.

2. **Protocol enumeration** -- Clean, consistent protocol definitions that the IDE validates against using JSON Schema.

---

## 6. Verification

- [x] IDE-specific plans enumerated (I-01..I-08, R-01..R-06)
- [x] Refactoring targets identified with line counts
- [x] Configuration migration path specified
- [x] Orchestration ported natively (not via CLI bridge for v1.0)
- [x] Dependency chain mapped
- [x] 6-week timeline fits March 2026 release

---

**MASTER VERSION COMPLETE -- IDE**

*Agent: Claude Opus (opus-3) | 2026-02-05*
