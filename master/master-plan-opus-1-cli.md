> RECOVERY_STATUS: RECOVERED
> AGENT_ID: opus-1
> ROUND: 2
> RECOVERY_DATE: 2026-02-05

# obot CLI Master Plan (opus-1)

**Agent**: opus-1
**Product**: obot CLI (Go)
**Round**: 2 (Final Consolidation)
**Consensus Level**: 95%+ agreement across all agents

---

## Executive Summary

After two rounds of consolidation across 40+ agent submissions, unanimous consensus emerged: obot CLI becomes the canonical execution engine. It exposes a JSON-RPC server mode for the IDE while retaining its standalone CLI interface. All orchestration, context management, tool execution, and model coordination logic lives here.

**Architecture**: Go Core + JSON-RPC Server
**Key Decision**: REJECT Rust rewrite. The Go codebase absorbs IDE intelligence (context management, mentions, OBot rules) and exposes it via server mode.

---

## Part 1: CLI Architecture

### 1.1 Role in Unified Stack

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         obot Engine (Go)                                    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      cmd/server  (JSON-RPC)                         │   │
│  │  Initialize project | Session management | Streaming state updates  │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                   │                                         │
│  ┌──────────────┬────────────────┬──────────────┬──────────────────────┐   │
│  │pkg/orchestrator│pkg/context   │pkg/model     │pkg/tools             │   │
│  │               │               │              │                      │   │
│  │ 5-Schedule    │ Token Budget  │ 4-Model      │ 22 Unified Tools    │   │
│  │ 3-Process     │ Compression   │ Coordinator  │ File/Shell/Web/Git  │   │
│  │ Navigation    │ Memory/Learn  │ Tier Detect  │ Delegation          │   │
│  └──────────────┴────────────────┴──────────────┴──────────────────────┘   │
│                                   │                                         │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                      pkg/ollama (Ollama Client)                      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Dual Mode Operation

```bash
# Mode 1: Standalone CLI (existing)
obot main.go "fix the nil pointer dereference"
obot orchestrate
obot --saved

# Mode 2: JSON-RPC Server (new, for IDE)
obot server --stdio
```

---

## Part 2: Directory Structure (Target)

```
obot/
├── cmd/
│   ├── obot/           # CLI entrypoint (existing)
│   │   └── main.go
│   └── server/         # NEW: JSON-RPC server for IDE
│       └── main.go
├── pkg/                # NEW: Shared packages (extracted from internal/)
│   ├── orchestrator/   # 5-Schedule orchestration
│   │   ├── scheduler.go
│   │   ├── navigator.go
│   │   ├── types.go
│   │   └── state.go
│   ├── context/        # PORTED: From Swift ContextManager
│   │   ├── manager.go
│   │   ├── budget.go
│   │   ├── compression.go
│   │   ├── memory.go
│   │   └── mentions.go
│   ├── model/          # Multi-model coordination
│   │   ├── coordinator.go
│   │   ├── tier.go
│   │   └── delegation.go
│   ├── tools/          # 22 unified tools
│   │   ├── registry.go
│   │   ├── file.go
│   │   ├── shell.go
│   │   ├── web.go
│   │   ├── git.go
│   │   └── delegation.go
│   ├── session/        # Session persistence
│   │   ├── session.go
│   │   ├── storage.go
│   │   └── recovery.go
│   ├── obot/           # .obotrules + bots (PORTED from Swift)
│   │   ├── rules.go
│   │   ├── bots.go
│   │   ├── templates.go
│   │   └── snippets.go
│   ├── server/         # JSON-RPC protocol
│   │   ├── handler.go
│   │   ├── protocol.go
│   │   └── stream.go
│   └── ollama/         # Ollama client (existing, enhanced)
│       ├── client.go
│       ├── stream.go
│       └── models.go
├── internal/           # CLI-specific internals
│   └── cli/
│       └── ...
└── configs/
    └── schema/         # JSON schemas for protocols
        ├── action.json
        ├── context.json
        └── session.json
```

---

## Part 3: Components Ported FROM IDE

### 3.1 Context Manager (Swift -> Go)

**Source:** `ollamabot/Sources/Services/ContextManager.swift`
**Target:** `obot/pkg/context/manager.go`

Key types: Manager, Config, TokenBudget.
Methods: BuildContext, compressContent, isPreservableLine.
Token budget allocation: System 8%, Rules 10%, Task 25%, Files 33%, Structure 16%, History 12%, Memory 8%, Errors 4%.

Features to port:
- Token budget allocation with percentage-based sections
- Semantic compression (preserve imports, signatures, error handling)
- Conversation memory with relevance scoring
- Error pattern learning with warning thresholds
- Inter-agent context passing for delegation
- Project semantic cache

### 3.2 OBot Rules System (Swift -> Go)

**Source:** `ollamabot/Sources/Services/OBotService.swift`
**Target:** `obot/pkg/obot/rules.go`

Key types: Rules, Bot, Step.
Functions: LoadRules (reads .obotrules), LoadBots (reads .obot/bots/*.yaml).

### 3.3 Mention Resolution (Swift -> Go)

**Source:** `ollamabot/Sources/Services/MentionService.swift`
**Target:** `obot/pkg/context/mentions.go`

Key types: MentionType, Mention, MentionResolver.
Supported types: file, bot, context, web, git, selection, folder, docs.

### 3.4 Multi-Model Coordination (Swift -> Go)

**Source:** `ollamabot/Sources/Services/ModelTierManager.swift`
**Target:** `obot/pkg/model/coordinator.go`

4-model coordination: orchestrator, coder, researcher, vision.
RAM-based tier detection with 6 tiers (minimal through maximum).
Intent-based routing for automatic model selection.

---

## Part 4: Orchestration System Enhancement

### 4.1 Existing 5-Schedule System

Already implemented in `internal/orchestrate/orchestrator.go`:
- Knowledge -> Plan -> Implement -> Scale -> Production
- 3 processes per schedule (P1, P2, P3)
- Navigation rules: P1->{P1,P2}, P2->{P1,P2,P3}, P3->{P2,P3}
- Termination: all 5 schedules visited, Production last, at P3

### 4.2 Enhancements Needed

- Add JSON-RPC state streaming (emit StateUpdate on every navigation)
- Add human consultation handler with configurable timeout (60s default)
- Add flow code tracking (S1P123S2P12 format)
- Add model delegation per schedule (researcher for Knowledge, coder for Implement)
- Add session persistence in USF format

---

## Part 5: IDE Features to Port INTO CLI (16)

| # | Feature | Priority | Implementation |
|---|---------|----------|----------------|
| 1 | OBot System | P0 | Parse .obotrules, .obot/bots/*.yaml |
| 2 | Multi-Model Coordination | P0 | 4-model orchestrator/coder/researcher/vision |
| 3 | Context Management (UCP) | P0 | Token budgets, compression, memory |
| 4 | @Mention System | P1 | @file, @folder, @git, @bot resolution |
| 5 | Checkpoint System | P1 | Save/restore code states |
| 6 | Web Tools | P1 | web_search, fetch_url tools |
| 7 | Vision Integration | P2 | Image analysis via vision model |
| 8 | Intent Routing | P2 | Auto model selection by task type |
| 9 | Chat History | P2 | Persistent conversation storage |
| 10 | File Indexing | P3 | Background codebase search index |
| 11 | Inline Completions | P3 | Tab completion suggestions |
| 12 | Explorer Mode | P3 | Continuous autonomous improvement |
| 13 | Composer Mode | P3 | Multi-file agent orchestration |
| 14 | Design System | - | N/A (CLI has no GUI) |
| 15 | Process Monitoring | P3 | Resource usage tracking |
| 16 | Command Palette | - | N/A (CLI has no GUI) |

---

## Part 6: Unified Specifications (CLI Must Conform)

### 6.1 Five Core Standards

| Standard | Abbrev. | CLI Role |
|----------|---------|----------|
| Unified Config Schema (UCS) | config.json | Read/write shared config |
| Unified Session Format (USF) | sessions/*.json | Persist and restore sessions |
| Unified Tool Registry (UTR) | tools.json | Load tool definitions |
| Unified Context Protocol (UCP) | Runtime | Build and manage context |
| Unified Orchestration Protocol (UOP) | Runtime | Execute 5x3 schedule system |

### 6.2 Unified Action Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "id": { "type": "string", "format": "uuid" },
    "type": {
      "enum": [
        "think", "complete", "ask_user",
        "read_file", "create_file", "edit_file", "delete_file",
        "create_dir", "delete_dir", "rename", "move", "copy",
        "search_files", "list_directory",
        "run_command", "take_screenshot",
        "delegate_to_coder", "delegate_to_researcher", "delegate_to_vision",
        "web_search", "fetch_url",
        "git_status", "git_diff", "git_commit"
      ]
    },
    "params": { "type": "object" },
    "result": { "type": "object" },
    "timestamp": { "type": "string", "format": "date-time" },
    "duration_ms": { "type": "integer" },
    "schedule": { "enum": ["knowledge", "plan", "implement", "scale", "production"] },
    "process": { "enum": [1, 2, 3] }
  },
  "required": ["id", "type", "params", "timestamp"]
}
```

### 6.3 Context Protocol

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "version": { "const": "2.0" },
    "budget": {
      "type": "object",
      "properties": {
        "total_tokens": { "type": "integer" },
        "allocated": {
          "type": "object",
          "properties": {
            "system": { "type": "number" },
            "rules": { "type": "number" },
            "task": { "type": "number" },
            "files": { "type": "number" },
            "structure": { "type": "number" },
            "history": { "type": "number" },
            "memory": { "type": "number" },
            "errors": { "type": "number" }
          }
        }
      }
    }
  }
}
```

### 6.4 Session Format (USF)

```json
{
  "version": "1.0.0",
  "session_id": "uuid",
  "platform_origin": "cli|ide",
  "prompt": { "original": "...", "working_directory": "/path" },
  "flow_code": "S1P123S2P12",
  "orchestration": {
    "current_schedule": "implement",
    "current_process": 2,
    "history": [...]
  },
  "actions": [...],
  "checkpoints": [...],
  "statistics": { "tokens_used": 45000, "savings": 0.45 }
}
```

### 6.5 Shared Config (UCS)

```json
{
  "version": "1.0.0",
  "ai": {
    "ollama_url": "http://localhost:11434",
    "models": {
      "orchestrator": "qwen3:32b",
      "coder": "qwen2.5-coder:32b",
      "researcher": "command-r:35b",
      "vision": "qwen3-vl:32b"
    },
    "temperature": { "coding": 0.3, "research": 0.7 },
    "maxTokens": 4096
  },
  "agent": {
    "quality": "balanced",
    "maxSteps": 50,
    "confirmDestructive": true
  },
  "tiers": {
    "auto_detect": true,
    "definitions": {
      "minimal": { "ram_gb": 8, "model": "deepseek-coder:1.3b" },
      "performance": { "ram_gb": 32, "model": "qwen2.5-coder:32b" }
    }
  }
}
```

---

## Part 7: Implementation Roadmap (CLI)

### Week 1-2: Refactoring
- Move `internal/` -> `pkg/` for shared packages
- Implement `pkg/context/manager.go` (port from Swift)
- Implement `pkg/obot/rules.go` (port from Swift)
- Add JSON-RPC scaffolding to `cmd/server/`

### Week 3-4: Server Mode
- Define all JSON schemas in `configs/schema/`
- Implement full `pkg/server/handler.go`
- Add streaming state updates via JSON-RPC notifications
- Implement multi-model coordinator
- Add web tools (search, fetch)

### Week 5-6: Feature Parity
- Add @mention resolution to context builder
- Add checkpoint system
- Add vision model integration
- Add intent routing
- Reduce packages from 27 to 12

### Week 7-8: Testing & Polish
- Cross-platform session tests
- Performance benchmarks
- Golden test suite for prompts/outputs
- Documentation and migration guide

---

## Part 8: Success Metrics (CLI)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Go LOC increase | +30% | Ported logic from Swift |
| Protocol compliance | 100% | Schema validation |
| Session portability | 100% | CLI<->IDE handoff |
| Tool parity | 22/22 | All unified tools |
| Server mode latency | <50ms | RPC round-trip |
| Test coverage | 75% | Unit + integration tests |
| Package count | 12 | Reduced from 27 |

---

## Part 9: Risk Mitigation (CLI)

| Risk | Impact | Mitigation |
|------|--------|------------|
| internal/ to pkg/ breakage | Medium | Incremental migration with aliases |
| Context port fidelity | Medium | Golden tests comparing Swift vs Go output |
| Server mode stability | High | Graceful shutdown, connection recovery |
| Model coordination complexity | Medium | Start with 2-model, scale to 4 |
| Breaking CLI users | High | Feature flags, backward compatibility |

---

## Conclusion

The obot CLI transforms from a standalone tool into the canonical execution engine for the entire OllamaBot ecosystem. It absorbs the IDE's intelligence (context management, mentions, OBot rules, multi-model coordination) while exposing everything via JSON-RPC for the IDE client. This provides:

1. Single source of truth for all AI/orchestration logic
2. Automatic feature parity - IDE features become CLI features and vice versa
3. Testable core - unit test Go packages independently
4. Session continuity - sessions created in CLI are resumable in IDE
5. Pragmatic migration - incremental porting, no rewrite

---

**Plan Author:** opus-1
**Plan Version:** 2.0.0
**Round:** 2
