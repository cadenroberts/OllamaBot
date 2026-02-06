# OllamaBot IDE Master Plan (opus-1)

> Canonical master plan for OllamaBot IDE harmonization. Agent: opus-1, Round: 2.

---

## Architecture

OllamaBot IDE (Swift/SwiftUI) becomes a rich GUI client that delegates execution to the obot Go engine via JSON-RPC over stdin/stdout.

```
┌───────────────────────────────────────────────────────┐
│                  OllamaBot IDE (Swift)                 │
│                                                       │
│  EditorView  ChatView  AgentView  TerminalView        │
│       │          │         │           │              │
│       └──────────┴─────────┴───────────┘              │
│                      │                                │
│              OBotRPCClient.swift                       │
│              (JSON-RPC thin client)                    │
└──────────────────────┬────────────────────────────────┘
                       │ Process spawn
                       ▼
┌───────────────────────────────────────────────────────┐
│                  obot Engine (Go)                      │
│  Orchestrator │ Context │ Session │ Model │ Tools     │
└───────────────────────────────────────────────────────┘
```

---

## IDE Changes Required

### New Files

| File | Lines | Purpose |
|------|-------|---------|
| `Sources/Services/OBotRPCClient.swift` | ~300 | JSON-RPC client, spawns obot server subprocess |
| `Sources/Models/RPCTypes.swift` | ~200 | Shared protocol types (InitializeParams, StateUpdate, etc.) |
| `Sources/Services/OrchestrationService.swift` | ~600 | 5-schedule, 3-process state machine ported from CLI |
| `Sources/Views/OrchestrationView.swift` | ~400 | Schedule/process visualization UI |
| `Sources/Services/ConsultationService.swift` | ~400 | Human consultation with 60s timeout + AI fallback |
| `Sources/Views/ConsultationView.swift` | ~200 | Consultation modal UI |

### Modified Files

| File | Change |
|------|--------|
| `Sources/OllamaBotApp.swift` | Start obot server process on launch |
| `Sources/Services/OllamaService.swift` | Thin wrapper delegating to RPC client |
| `Sources/Agent/AgentExecutor.swift` | Use OBotRPCClient instead of direct Ollama calls |
| `Sources/Views/AgentView.swift` | Display orchestration state from RPC events |
| `Sources/Views/ChatView.swift` | Add quality preset selector (fast/balanced/thorough) |
| `Sources/Views/ComposerView.swift` | Add quality preset selector |
| `Sources/Services/ConfigurationService.swift` | Read unified YAML config from ~/.config/ollamabot/ |

### Files to Eventually Remove (post-migration)

| File | Reason |
|------|--------|
| `Sources/Services/ContextManager.swift` | Logic moves to Go engine |
| `Sources/Agent/AgentTools.swift` | Tool execution moves to Go engine |
| `Sources/Services/OBotService.swift` | Rules parsing moves to Go engine |

---

## Features to Add to IDE (from CLI)

| # | Feature | Priority | Description |
|---|---------|----------|-------------|
| 1 | Orchestration Framework | P0 | Port 5-schedule x 3-process system with navigation rules |
| 2 | Quality Presets | P0 | fast/balanced/thorough selector in chat and composer |
| 3 | Session Persistence | P0 | Save/restore sessions in unified format |
| 4 | Human Consultation | P1 | 60s timeout modal with AI substitute fallback |
| 5 | Flow Code Tracking | P1 | S1P123S2P12 visualization in agent view |
| 6 | Dry-Run Mode | P1 | Preview changes without applying |
| 7 | Cost Tracking | P1 | Token cost savings display in status bar |
| 8 | Line Range Editing | P2 | -start +end syntax support |
| 9 | Memory Visualization | P2 | Live RAM usage bars |
| 10 | LLM-as-Judge | P2 | Post-completion quality assessment |
| 11 | GitHub/GitLab Integration | P3 | Repository creation from IDE |
| 12 | Interactive Mode | P3 | Multi-turn conversation mode |

---

## Orchestration State Machine (ported from CLI)

### Schedules
1. Knowledge -- Research, Crawl, Retrieve
2. Plan -- Brainstorm, Clarify (optional consultation), Plan
3. Implement -- Implement, Verify, Feedback (mandatory consultation)
4. Scale -- Scale, Benchmark, Optimize
5. Production -- Analyze, Systemize, Harmonize

### Navigation Rules (strict)
- Entry: P1 only
- P1 -> P1 (repeat) or P2
- P2 -> P1, P2 (repeat), or P3
- P3 -> P2, P3 (repeat), or TERMINATE schedule

### Termination Prerequisites
- All 5 schedules must be visited at least once
- Production must be the final schedule
- Must be at P3 to terminate

### Flow Code Format
`S1P123S2P12S3P123S5P123` -- each S{n} is a schedule entry, each P{n} is a process visit.

---

## Unified Specifications (IDE must implement)

### UCS -- Unified Config Schema
Read from `~/.config/ollamabot/config.yaml`. Shared with CLI. Contains model definitions, tier settings, agent parameters, quality defaults.

### USF -- Unified Session Format
JSON sessions at `~/.config/ollamabot/sessions/*.json`. Fields: session_id, platform_origin, prompt, flow_code, orchestration state, actions, checkpoints, statistics.

### UTR -- Unified Tool Registry
22 tools across both platforms. IDE currently has 18, needs to add: file.delete, core.note. CLI needs to add: file.search, ai.delegate.*, web.*, core.think, core.ask.

### UCP -- Unified Context Protocol
Token-budgeted context building. Budget: System 8%, Rules 10%, Task 25%, Files 33%, Structure 16%, History 12%, Memory 8%, Errors 4%. Semantic compression when over budget.

### UOP -- Unified Orchestration Protocol
5-schedule x 3-process framework with strict navigation rules, flow code tracking, and human consultation points.

---

## IDE Implementation Roadmap

### Week 1-2: Foundation
- Create OBotRPCClient.swift
- Define RPCTypes.swift
- Wire process spawning into OllamaBotApp.swift
- Read unified config from ~/.config/ollamabot/

### Week 3-4: Orchestration
- Implement OrchestrationService.swift (state machine)
- Create OrchestrationView.swift (visualization)
- Integrate with AgentExecutor
- Add quality preset selector to ChatView/ComposerView

### Week 5-6: Feature Parity
- Implement ConsultationService.swift + ConsultationView.swift
- Add cost tracking to status bar
- Add flow code display to AgentView
- Add dry-run mode

### Week 7-8: Testing and Polish
- Unit tests for OrchestrationService
- Integration tests for RPC client
- Performance benchmarks (target <50ms RPC overhead)
- Migration guide for existing IDE users

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Swift LOC reduction | -50% (services moved to Go) |
| Protocol compliance | 100% (all 5 specs implemented) |
| Session portability | 100% (CLI sessions viewable in IDE) |
| Feature parity | 95% (26/28 features) |
| RPC latency | <50ms round-trip |
| Test coverage | 70%+ for new code |

---

**Agent:** opus-1 | **Round:** 2 | **Date:** 2026-02-05
