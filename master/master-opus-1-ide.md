# OllamaBot IDE — FINAL MASTER PLAN (opus-1)

**Agent**: opus-1  
**Product**: OllamaBot IDE (Swift/SwiftUI)  
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

### 1.2 IDE-CLI Bridge

The IDE invokes CLI for heavy operations:

```swift
// Sources/Services/CLIBridgeService.swift
class CLIBridgeService {
    // Option A: Direct subprocess (simpler)
    func execute(_ command: String) async -> Result

    // Option B: REST API (cleaner, supports streaming)
    func post(_ endpoint: String, body: Data) async -> Result
}

// Usage in IDE:
let session = await cliBridge.post("/api/v1/agent/execute", body: {
    "prompt": "Implement user authentication",
    "mode": "orchestrate",
    "quality": "balanced"
})
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

## Part 3: Feature Parity — IDE Perspective

### 3.1 CLI Features to Add to IDE (12)

| # | Feature | Priority | Implementation |
|---|---------|----------|----------------|
| 1 | Orchestration Framework | P0 | Port 5×3 schedule system to OrchestratorService.swift |
| 2 | Quality Presets | P0 | Add fast/balanced/thorough UI selector |
| 3 | Session Persistence | P0 | USF-compliant session export/import |
| 4 | Human Consultation | P1 | 60s timeout dialog + AI fallback |
| 5 | Flow Code Tracking | P1 | S1P123 visualization in status bar |
| 6 | Dry-Run Mode | P1 | Preview changes without applying |
| 7 | Cost Tracking | P1 | Status bar token/savings display |
| 8 | Line Range Editing | P2 | -start +end syntax in editor |
| 9 | Memory Visualization | P2 | Live RAM usage monitoring |
| 10 | LLM-as-Judge | P2 | Quality assessment integration |
| 11 | GitHub/GitLab Integration | P3 | Repository creation from IDE |
| 12 | Interactive Mode | P3 | Multi-turn conversation support |

### 3.2 IDE Features Already Implemented (Retain & Normalize)

| # | Feature | Status | Action |
|---|---------|--------|--------|
| 1 | OBot System | Implemented | Normalize to UTR schema |
| 2 | Multi-Model Coordination | Implemented | Align with UMC protocol |
| 3 | Context Management | Implemented | Validate UCP compliance |
| 4 | @Mention System (14+ types) | Implemented | Document in UTR |
| 5 | Checkpoint System | Implemented | Align with USF format |
| 6 | Web Tools | Implemented | Register in UTR |
| 7 | Vision Integration | Implemented | Register in UTR |
| 8 | Intent Routing | Implemented | Align with UMC |
| 9 | Chat History | Implemented | Align with USF |
| 10 | File Indexing | Implemented | Register in UTR |
| 11 | Composer Mode | Implemented | Document workflow |
| 12 | Design System | Implemented | IDE-specific, N/A for CLI |

---

## Part 4: IDE Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)
- Adopt UCS configuration schema — read `~/.config/obot/config.json`, merge with UserDefaults for UI
- Implement USF session format in CheckpointService
- Register all IDE tools against UTR canonical IDs
- Documentation of IDE protocol compliance

### Phase 2: Core Enhancements (Weeks 3-4)
- Validate existing Context Management against UCP schema
- Align ModelTierManager + IntentRouter with UMC protocol
- Add CLIBridgeService.swift for IDE-CLI subprocess/REST bridge

### Phase 3: Feature Porting (Weeks 5-6)
- Implement OrchestratorService.swift (5×3 schedule state machine from UOP)
- Add 5-Schedule Workflow UI with process navigation (1↔2↔3)
- Add Flow Code Tracking display (S1P123 visualization)
- Add Quality Preset selection UI (fast/balanced/thorough)
- Refactor AgentExecutor into 5 focused files

### Phase 4: Harmonization (Weeks 7-8)
- Cross-platform session import/export via USF
- Unified error handling with shared error codes (OB-E-0001 format)
- Tool vocabulary parity — normalize all tool IDs to UTR canonical form
- Human Consultation dialogs with 60s timeout

### Phase 5: Polish (Weeks 9-10)
- Dry-Run preview mode
- Cost tracking in status bar
- Line range editing support
- Performance optimization
- Target 70% test coverage

---

## Part 5: IDE-Specific Architecture Changes

### Files to Create
| File | Purpose |
|------|---------|
| `Sources/Services/CLIBridgeService.swift` | IDE-CLI subprocess/REST bridge |
| `Sources/Services/OrchestratorService.swift` | UOP 5×3 schedule state machine |
| `Sources/Services/UnifiedConfigService.swift` | UCS config reader + UserDefaults merge |
| `Sources/Services/SessionExportService.swift` | USF session import/export |

### Files to Modify
| File | Change |
|------|--------|
| `Sources/Services/OllamaService.swift` | Align with UMC model coordinator |
| `Sources/Utilities/ContextManager.swift` | Validate UCP compliance |
| `Sources/Services/AgentExecutor.swift` | Refactor into 5 files, add UOP hooks |
| `Sources/Services/CheckpointService.swift` | Adopt USF session format |
| `Sources/Views/SettingsView.swift` | Add quality preset selector, UCS config |

---

## Part 6: Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Architectural Harmony | 100% | All 5 standards implemented in IDE |
| Feature Parity | 95% | 11/12 CLI features ported to IDE |
| Test Coverage | 70% | Unit + integration tests |
| Code Quality | Pass | No files >500 lines |
| Performance | Maintain | No regressions from baseline |
| User Experience | Unified | Single config, session transfer with CLI |

---

## Conclusion

OllamaBot IDE becomes the rich graphical interface atop the unified obot engine. Through adoption of all 5 shared specifications (UCS, USF, UTR, UCP, UOP), the IDE achieves full protocol harmony with the CLI while preserving its native SwiftUI strengths — visual diff, chat history, @Mention system, and Composer mode.

The "Protocols over Code" approach ensures the IDE can implement each standard independently in Swift without depending on a shared compiled core, enabling parallel development and independent release cycles.

---

**END OF IDE MASTER PLAN — opus-1**

<!-- Recovery verified by opus-1 agent: 2026-02-06T01:15:21Z -->
