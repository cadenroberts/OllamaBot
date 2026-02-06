# obot CLI Master Plan (opus-1)

> Canonical master plan for obot CLI harmonization. Agent: opus-1, Round: 2.

---

## Architecture

obot CLI (Go) becomes the canonical execution engine. It gains a server mode (JSON-RPC over stdin/stdout) so the IDE can delegate to it, while retaining its existing terminal interface.

```
┌───────────────────────────────────────────────────────┐
│                    obot (Go)                           │
│                                                       │
│  cmd/obot/       -- CLI entrypoint (existing)         │
│  cmd/server/     -- JSON-RPC server for IDE (NEW)     │
│                                                       │
│  pkg/orchestrator/  -- 5-schedule system (from internal)│
│  pkg/context/       -- Token-budgeted context (NEW)    │
│  pkg/model/         -- 4-model coordinator (NEW)       │
│  pkg/tools/         -- 22 unified tools (enhanced)     │
│  pkg/session/       -- Unified session format (NEW)    │
│  pkg/obot/          -- .obotrules + bots parser (NEW)  │
│  pkg/server/        -- JSON-RPC protocol (NEW)         │
│  pkg/ollama/        -- Ollama client (enhanced)        │
│                                                       │
│  internal/cli/      -- CLI-specific UI code            │
└───────────────────────────────────────────────────────┘
```

---

## CLI Changes Required

### New Files

| File | Lines | Purpose |
|------|-------|---------|
| `cmd/server/main.go` | ~150 | JSON-RPC server entrypoint |
| `pkg/context/manager.go` | ~400 | Token-budgeted context (ported from Swift ContextManager) |
| `pkg/context/budget.go` | ~150 | Token budget allocation |
| `pkg/context/compression.go` | ~200 | Semantic compression |
| `pkg/context/memory.go` | ~200 | Conversation memory with relevance scoring |
| `pkg/context/mentions.go` | ~300 | @mention parser and resolver |
| `pkg/model/coordinator.go` | ~300 | 4-model delegation (orchestrator, coder, researcher, vision) |
| `pkg/model/tier.go` | ~200 | Unified tier detection (6 tiers) |
| `pkg/model/delegation.go` | ~250 | Model delegation logic |
| `pkg/obot/rules.go` | ~250 | .obotrules parser |
| `pkg/obot/bots.go` | ~300 | YAML bot loader and executor |
| `pkg/obot/templates.go` | ~150 | Code template engine |
| `pkg/obot/snippets.go` | ~100 | Context snippet loader |
| `pkg/server/handler.go` | ~400 | JSON-RPC method handlers |
| `pkg/server/protocol.go` | ~200 | RPC types and serialization |
| `pkg/server/stream.go` | ~200 | Streaming state updates |
| `pkg/session/session.go` | ~300 | Unified session format |
| `pkg/session/storage.go` | ~200 | Session persistence |
| `pkg/session/recovery.go` | ~150 | Crash recovery |
| `pkg/tools/registry.go` | ~200 | Tool registry (22 tools) |

### Modified Files

| File | Change |
|------|--------|
| `internal/cli/root.go` | Add @mention syntax support, read .obotrules |
| `internal/orchestrate/orchestrator.go` | Extract to pkg/orchestrator/, add IDE streaming |
| `internal/config/config.go` | Read unified YAML config from ~/.config/ollamabot/ |
| `internal/context/summary.go` | Replace with pkg/context/ token-budgeted system |
| `internal/agent/agent.go` | Use pkg/tools/ registry, add missing tools |
| `internal/fixer/prompts.go` | Prepend .obotrules content to system prompts |
| `internal/tier/detect.go` | Align with pkg/model/tier.go (6 tiers) |

---

## Features to Add to CLI (from IDE)

| # | Feature | Priority | Description |
|---|---------|----------|-------------|
| 1 | OBot System | P0 | Parse .obotrules and .obot/ directory |
| 2 | Multi-Model Coordination | P0 | 4-model orchestration (orchestrator, coder, researcher, vision) |
| 3 | Context Management (UCP) | P0 | Token budgets, semantic compression, memory |
| 4 | @Mention System | P1 | @file:path, @folder:path, @codebase, @git:diff, @context:id, @bot:id |
| 5 | Checkpoint System | P1 | Save/restore code states |
| 6 | Web Tools | P1 | web_search, fetch_url |
| 7 | Vision Integration | P2 | Image analysis via vision model |
| 8 | Intent Routing | P2 | Auto model selection based on task type |
| 9 | Chat History | P2 | Persistent conversation history |
| 10 | File Indexing | P3 | Background file search index |
| 11 | Inline Completions | P3 | Tab completion for commands |
| 12 | Explorer Mode | P3 | Continuous autonomous improvement |
| 13 | Composer Mode | P3 | Multi-file agent changes |
| 14 | Process Monitoring | P3 | Resource tracking |

---

## Context Manager Port (Swift -> Go)

### Token Budget Allocation
| Section | Budget |
|---------|--------|
| System Prompt | 8% |
| Project Rules (.obotrules) | 10% |
| Task Description | 25% |
| Active Files | 33% |
| Project Structure | 16% |
| Conversation History | 12% |
| Memory (past interactions) | 8% |
| Error Patterns | 4% |

### Compression Strategy
1. Check if content fits within token budget
2. If over budget: preserve imports, exports, function signatures, type definitions, error handling, TODO/FIXME markers
3. If still over: head + tail truncation with "[N lines omitted]" marker

### Memory System
- Store up to 50 memory entries
- Relevance scoring via keyword overlap with current task
- Prune by access count when over capacity

---

## @Mention System for CLI

### Supported Mentions

| Mention | Syntax | Resolution |
|---------|--------|------------|
| File | `@file:path/to/file.go` | Read file contents, wrap in code fence |
| Folder | `@folder:path/to/dir` | List directory contents |
| Codebase | `@codebase` | Project structure summary |
| Context | `@context:api-docs` | Read .obot/context/api-docs.md |
| Bot | `@bot:refactor` | Reference bot definition |
| Git | `@git:diff` | Run git diff, include output |
| Git | `@git:log` | Run git log --oneline -10 |
| Git | `@git:status` | Run git status |

### CLI Usage
```bash
obot fix main.go "@file:utils.go add error handling"
obot "@codebase @context:style-guide refactor authentication"
obot orchestrate "@git:diff review and fix all issues"
```

---

## .obotrules Support

### Parser Behavior
1. Look for `.obotrules` in CWD, then walk up to root
2. Parse markdown sections (split on `## ` headings)
3. Extract title + content for each section
4. Prepend to system prompt as structured context

### .obot/ Directory Support
```
project/
├── .obotrules              # Project-wide AI rules
├── .obot/
│   ├── config.yaml         # Project-specific config
│   ├── bots/               # Custom YAML bot definitions
│   │   ├── refactor.yaml
│   │   └── test-gen.yaml
│   ├── context/            # Reusable context snippets
│   │   └── api-docs.md
│   └── templates/          # Code generation templates
│       └── component.go.tmpl
```

---

## Server Mode (JSON-RPC)

### Startup
```bash
obot server --stdio           # JSON-RPC over stdin/stdout (for IDE)
obot server --port 9111       # JSON-RPC over TCP (for external tools)
```

### Methods
| Method | Direction | Purpose |
|--------|-----------|---------|
| `initialize` | Client -> Server | Handshake, capability exchange |
| `session/start` | Client -> Server | Create or resume session |
| `session/execute` | Client -> Server | Execute prompt in session |
| `session/stop` | Client -> Server | Stop current execution |
| `state/update` | Server -> Client | Real-time orchestration state |
| `action/result` | Server -> Client | Tool execution results |
| `consultation/request` | Server -> Client | Human input needed |
| `consultation/respond` | Client -> Server | Human input provided |

---

## Unified Specifications (CLI must implement)

### UCS -- Unified Config Schema
Write to `~/.config/ollamabot/config.yaml`. Shared with IDE. CLI flags override YAML values.

### USF -- Unified Session Format
JSON sessions at `~/.config/ollamabot/sessions/*.json`. Must include: session_id, platform_origin (cli), prompt, flow_code, orchestration state, actions, checkpoints, statistics.

### UTR -- Unified Tool Registry
22 tools. CLI currently has 12, needs to add: think, ask_user, search_files, list_directory, delegate_to_coder, delegate_to_researcher, delegate_to_vision, web_search, fetch_url, git_status.

### UCP -- Unified Context Protocol
Token-budgeted context building with the budget allocation defined above. Must match IDE behavior for identical inputs.

### UOP -- Unified Orchestration Protocol
CLI already has this (5-schedule x 3-process). Must expose state via JSON-RPC for IDE consumption.

---

## CLI Implementation Roadmap

### Week 1-2: Refactoring
- Extract internal/ packages to pkg/ for reuse
- Implement pkg/context/manager.go (port from Swift)
- Implement pkg/obot/rules.go (parse .obotrules)
- Add JSON-RPC scaffolding in cmd/server/

### Week 3-4: Feature Parity
- Implement pkg/model/coordinator.go (4-model delegation)
- Implement pkg/context/mentions.go (@mention system)
- Implement pkg/obot/bots.go (YAML bot loader)
- Add missing tools to pkg/tools/ (web_search, fetch_url, think, ask_user)

### Week 5-6: Server Mode
- Implement pkg/server/handler.go (all RPC methods)
- Implement streaming state updates
- Implement consultation protocol
- Integration test with IDE client

### Week 7-8: Testing and Polish
- Unit tests for all pkg/ packages (target 80% coverage)
- Integration tests for server mode
- Performance benchmarks
- Documentation and migration guide

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Go LOC increase | +30% (ported logic + server) |
| Protocol compliance | 100% (all 5 specs) |
| Session portability | 100% (IDE sessions resumable in CLI) |
| Tool count | 22 (up from 12) |
| .obotrules support | Full parity with IDE parser |
| Server mode latency | <50ms per RPC call |
| Test coverage | 80%+ for pkg/ |

---

**Agent:** opus-1 | **Round:** 2 | **Date:** 2026-02-05
