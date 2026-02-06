# obot CLI — FINAL MASTER PLAN (opus-1)

**Agent**: opus-1  
**Product**: obot CLI (Go/Cobra)  
**Round**: 2 (Final Consolidation)  
**Source**: 17 Round 1 plans from 6+ agents  
**Consensus Level**: 95%+ agreement across all agents

---

## Executive Summary

After two rounds of consolidation across 40+ agent submissions totaling ~500KB of analysis, **unanimous consensus** has emerged on the harmonization strategy for OllamaBot IDE and obot CLI.

**The Verdict**: "CLI as Engine, IDE as GUI" - obot becomes the canonical execution engine while OllamaBot provides the graphical interface, both sharing protocols, specifications, and session formats.

---

## Part 1: Consensus Architecture

### 1.1 Unified Product Stack

```
┌─────────────────────────────────────────────────────────────┐
│                    USER INTERFACES                          │
│  ┌─────────────────────┐    ┌─────────────────────────────┐ │
│  │   OllamaBot IDE     │    │        obot CLI             │ │
│  │   (Swift/SwiftUI)   │    │        (Go/Cobra)           │ │
│  │   - Rich UI         │    │   - Terminal interface      │ │
│  │   - Visual diff     │    │   - Flags & pipes           │ │
│  │   - Chat history    │    │   - Scripts & automation    │ │
│  └──────────┬──────────┘    └──────────┬──────────────────┘ │
│             │                          │                    │
│             ▼                          ▼                    │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              OBOT ENGINE (Go)                          │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │ │
│  │  │Orchestr. │ │Context   │ │Session   │ │Model     │   │ │
│  │  │5×3 Sched │ │UCP       │ │USF       │ │Coord.    │   │ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘   │ │
│  │                                                        │ │
│  │  Server Mode: obot --server --port 9111                │ │
│  │  REST API:    /api/v1/agent/execute                    │ │
│  │               /api/v1/context/build                    │ │
│  │               /api/v1/session/{id}                     │ │
│  └────────────────────────────────────────────────────────┘ │
│                           │                                 │
│                           ▼                                 │
│  ┌────────────────────────────────────────────────────────┐ │
│  │            SHARED LAYER (~/.config/obot/)              │ │
│  │  config.json │ tools.json │ sessions/ │ prompts/       │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 CLI as Engine — Server Mode

The CLI exposes its engine via REST for IDE consumption:

```go
// internal/server/server.go
func StartServer(port int) {
    mux := http.NewServeMux()
    mux.HandleFunc("/api/v1/agent/execute", handleExecute)
    mux.HandleFunc("/api/v1/context/build", handleContextBuild)
    mux.HandleFunc("/api/v1/session/", handleSession)
    http.ListenAndServe(fmt.Sprintf(":%d", port), mux)
}

// Invoked via: obot --server --port 9111
```

---

## Part 2: Unified Specifications (Consensus)

### 2.1 Five Core Standards

| Standard | Abbrev. | Purpose | File Location |
|----------|---------|---------|---------------|
| Unified Config Schema | UCS | Shared configuration | `~/.config/obot/config.json` |
| Unified Session Format | USF | Cross-platform sessions | `~/.config/obot/sessions/*.json` |
| Unified Tool Registry | UTR | Tool definitions | `~/.config/obot/tools.json` |
| Unified Context Protocol | UCP | Context management | Runtime format |
| Unified Orchestration Protocol | UOP | Workflow coordination | 5×3 schedule system |

### 2.2 UCS - Configuration (Consensus Schema)

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

### 2.3 UTR - Tool Registry (22 Tools)

```json
{
  "version": "1.0.0",
  "tools": [
    {"id": "file.read", "platforms": ["ide", "cli"]},
    {"id": "file.write", "platforms": ["ide", "cli"]},
    {"id": "file.edit", "platforms": ["ide", "cli"]},
    {"id": "file.search", "platforms": ["ide"], "todo": "cli"},
    {"id": "file.delete", "platforms": ["cli"], "todo": "ide"},
    {"id": "system.execute", "platforms": ["ide", "cli"]},
    {"id": "ai.delegate.coder", "platforms": ["ide"], "todo": "cli"},
    {"id": "ai.delegate.researcher", "platforms": ["ide"], "todo": "cli"},
    {"id": "ai.delegate.vision", "platforms": ["ide"]},
    {"id": "web.search", "platforms": ["ide"], "todo": "cli"},
    {"id": "web.fetch", "platforms": ["ide"], "todo": "cli"},
    {"id": "git.status", "platforms": ["ide", "cli"]},
    {"id": "git.diff", "platforms": ["ide", "cli"]},
    {"id": "git.commit", "platforms": ["ide", "cli"]},
    {"id": "git.push", "platforms": ["cli"], "todo": "ide"},
    {"id": "core.think", "platforms": ["ide", "cli"]},
    {"id": "core.complete", "platforms": ["ide", "cli"]},
    {"id": "core.ask", "platforms": ["ide", "cli"]},
    {"id": "core.note", "platforms": ["cli"], "todo": "ide"}
  ]
}
```

### 2.4 USF - Session Format

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

---

## Part 3: Feature Parity — CLI Perspective

### 3.1 IDE Features to Add to CLI (16)

| # | Feature | Priority | Implementation |
|---|---------|----------|----------------|
| 1 | OBot System | P0 | Parse .obotrules, .obot/ in internal/obot/ |
| 2 | Multi-Model Coordination | P0 | 4-model delegation in internal/model/ |
| 3 | Context Management (UCP) | P0 | Token budgets, compression in internal/context/manager.go |
| 4 | @Mention System | P1 | @file, @folder, @git parsing in internal/mention/ |
| 5 | Checkpoint System | P1 | Save/restore code states in internal/checkpoint/ |
| 6 | Web Tools | P1 | web_search, fetch_url in internal/tools/web.go |
| 7 | Vision Integration | P2 | Image analysis via multimodal models |
| 8 | Intent Routing | P2 | Auto model selection in internal/model/router.go |
| 9 | Chat History | P2 | Persistent conversations in internal/session/ |
| 10 | File Indexing | P3 | Background search in internal/index/ |
| 11 | Inline Completions | P3 | Tab completion for Cobra commands |
| 12 | Explorer Mode | P3 | Continuous autonomous improvement |
| 13 | Composer Mode | P3 | Multi-file agent orchestration |
| 14 | Design System | N/A | CLI has no GUI — skip |
| 15 | Process Monitoring | P3 | Resource tracking in internal/stats/ |
| 16 | Command Palette | N/A | CLI has no GUI — skip |

### 3.2 CLI Features Already Implemented (Retain & Normalize)

| # | Feature | Status | Action |
|---|---------|--------|--------|
| 1 | Orchestration Framework (5×3) | Implemented | Validate against UOP schema |
| 2 | Quality Pipeline (fast/balanced/thorough) | Implemented | Align with UCS presets |
| 3 | Session Persistence | Implemented | Migrate to USF format |
| 4 | Human Consultation (timeout) | Implemented | Retain, document in UTR |
| 5 | Flow Code Tracking (S1P123) | Implemented | Validate against UOP |
| 6 | Dry-Run Mode | Implemented | Retain |
| 7 | Cost Tracking | Implemented | Align with UCS metrics |
| 8 | LLM-as-Judge | Implemented | Register in UTR |
| 9 | Memory Visualization | Implemented | Retain |
| 10 | Diff Generation (go-difflib) | Implemented | Register in UTR |
| 11 | Tiered Model Selection | Implemented | Align with UMC protocol |

---

## Part 4: CLI Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)
- Migrate config from internal JSON to UCS schema at `~/.config/obot/config.json`
- Implement USF session format — replace directory-based sessions with JSON
- Register all CLI tools against UTR canonical IDs
- Define and validate UOP schema against existing orchestrator.go

### Phase 2: Core Enhancements (Weeks 3-4)
- Implement Enhanced Context Manager (port from Swift) — `internal/context/manager.go` (~700 LOC)
- Add Intent Routing System — `internal/model/router.go`
- Add Multi-Model Delegation — `internal/model/coordinator.go`
- Implement Server Mode — `internal/server/server.go` (`obot --server --port 9111`)

### Phase 3: Feature Porting (Weeks 5-6)
- Implement OBot System parser — `internal/obot/parser.go` (parse .obotrules, .obot/)
- Add @Mention System — `internal/mention/parser.go` (@file, @folder, @git)
- Add Checkpoint System — `internal/checkpoint/manager.go`
- Add Web Tools — `internal/tools/web.go` (web_search, fetch_url)
- Add Think Tool — `internal/tools/think.go`
- Add Ask_User with Timeout — `internal/tools/ask.go`

### Phase 4: Harmonization (Weeks 7-8)
- Cross-platform session import/export via USF
- Unified error handling with shared error codes (OB-E-0001 format)
- Tool vocabulary parity — normalize all tool IDs to UTR canonical form
- Quality Preset Enforcement aligned with UCS
- Human Consultation Framework with AI fallback

### Phase 5: Polish (Weeks 9-10)
- Vision model integration
- File search and indexing
- Performance optimization
- Reduce packages from 27 to 12
- Documentation and CLI help text updates

---

## Part 5: CLI-Specific Architecture Changes

### Files to Create
| File | Purpose | Est. LOC |
|------|---------|----------|
| `internal/context/manager.go` | UCP-compliant context manager (port from Swift) | ~700 |
| `internal/model/router.go` | Intent-based model routing (UMC) | ~300 |
| `internal/model/coordinator.go` | Multi-model delegation | ~400 |
| `internal/server/server.go` | REST API server mode | ~500 |
| `internal/obot/parser.go` | OBot system parser (.obotrules) | ~300 |
| `internal/mention/parser.go` | @Mention system | ~250 |
| `internal/checkpoint/manager.go` | Checkpoint save/restore | ~350 |
| `internal/tools/web.go` | Web search + fetch tools | ~200 |
| `internal/tools/think.go` | Think tool | ~50 |
| `internal/tools/ask.go` | Ask_user with timeout | ~150 |

### Files to Modify
| File | Change |
|------|--------|
| `internal/config/config.go` | Migrate to UCS schema, read `~/.config/obot/config.json` |
| `internal/orchestrate/orchestrator.go` | Validate against UOP schema, add hooks |
| `internal/session/session.go` | Adopt USF JSON format |
| `internal/ollama/client.go` | Align with UMC model coordinator |
| `internal/cli/root.go` | Add `--server` flag and server mode |
| `internal/analyzer/analyzer.go` | Register tools in UTR format |

### Package Consolidation Target
| Current (27 packages) | Target (12 packages) |
|----------------------|---------------------|
| analyzer, config, context, fixer, index, judge, oberror, ollama, orchestrate, planner, resource, session, stats, summary, ... | core, config, context, model, orchestrate, server, session, tools, obot, mention, checkpoint, cli |

---

## Part 6: Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Architectural Harmony | 100% | All 5 standards implemented in CLI |
| Feature Parity | 95% | 14/16 IDE features ported to CLI (excl. GUI-only) |
| Test Coverage | 80% | Unit + integration tests |
| Code Quality | Pass | No files >500 lines, packages reduced to 12 |
| Performance | Maintain | No regressions from baseline |
| Server Mode | Functional | IDE can invoke CLI via REST API |

---

## Conclusion

obot CLI becomes the canonical execution engine for the unified product ecosystem. Through adoption of all 5 shared specifications (UCS, USF, UTR, UCP, UOP) and the addition of a REST server mode, the CLI serves both terminal users directly and the IDE as a backend engine.

The "Protocols over Code" approach ensures the CLI can implement each standard independently in Go without depending on a shared compiled core with the IDE, enabling parallel development and independent release cycles.

The most critical path item is the Enhanced Context Manager port (internal/context/manager.go, ~700 LOC), which gates multiple downstream features. This should begin in Week 3 with extensive golden tests.

---

**END OF CLI MASTER PLAN — opus-1**
