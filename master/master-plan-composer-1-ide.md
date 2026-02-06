# OllamaBot Master Harmonization Plan - IDE Component

**Agent**: composer-1  
**Round**: 2 (Final Re-Optimization)  
**Date**: 2026-02-05  
**Scope**: OllamaBot IDE (Swift/SwiftUI)

---

## Executive Summary

This plan defines the IDE-side harmonization strategy for unifying OllamaBot IDE with obot CLI into a single product ecosystem. The IDE adopts the "Cockpit" role in the Engine-and-Cockpit architecture, consuming the CLI as execution engine while providing rich visualization and native macOS integration.

---

## Part 1: IDE Architecture Role

### 1.1 Cockpit Pattern

The IDE serves as the visualization and control layer. All execution logic is delegated to the CLI engine via HTTP/WebSocket or shared Rust core bindings.

```
OllamaBot IDE (COCKPIT)
├── UI Layer (SwiftUI)
│   ├── Syntax highlighting, diff view, chat UI
│   ├── Command palette, file explorer
│   └── Orchestration visualizer, quality selector
├── Bridge Layer
│   ├── CLIServerService.swift (HTTP/WS to obot --server)
│   └── libobot FFI bindings (Rust core via C FFI)
└── Native Layer
    ├── macOS integration (notifications, menus, shortcuts)
    ├── Real-time streaming
    └── File watching, async I/O
```

### 1.2 Current IDE Services (to be refactored)

- `Sources/Services/OllamaService.swift` - Replace with libobot + CLI server
- `Sources/Services/ModelTierManager.swift` - Replace with libobot tier detection
- `Sources/Services/ContextManager.swift` - Replace with libobot context manager
- `Sources/Services/ConfigurationService.swift` - Replace with unified config
- `Sources/Agent/AgentExecutor.swift` - Integrate orchestration via CLI server
- `Sources/Agent/CycleAgentManager.swift` - Adopt 5-schedule framework
- `Sources/Agent/ExploreAgentExecutor.swift` - Map to orchestration schedules

---

## Part 2: Critical IDE Changes

### 2.1 New Services Required

**OrchestrationService.swift** (~600 lines)
- Port obot's 5-schedule, 3-process framework
- Schedules: Knowledge, Plan, Implement, Scale, Production
- Strict 1-2-3 navigation rules
- Flow code generation matching CLI output

**ConsultationService.swift** (~400 lines)
- Human consultation framework with timeout
- Optional consultations (Clarify in Plan schedule)
- Mandatory consultations (Feedback in Implement schedule)
- AI substitute on timeout (60s default)

**CLIServerService.swift** (~300 lines)
- HTTP client for obot --server mode
- WebSocket streaming for real-time events
- Session management via unified format
- Tool execution delegation

**JudgeService.swift** (~250 lines)
- LLM-as-judge quality assessment
- Post-completion analysis
- Quality scoring integration

### 2.2 New Views Required

**OrchestrationView.swift** (~400 lines)
- 5-phase schedule visualizer
- Process navigation display
- Flow code live tracking
- Schedule/process statistics

**ConsultationView.swift** (~200 lines)
- Consultation prompt with countdown timer
- Optional vs mandatory indicator
- Response input field
- AI substitute fallback display

**QualityPresetSelector** (component)
- Fast / Balanced / Thorough toggle
- Integration with ChatView and ComposerView

### 2.3 Modified Services

**OllamaService.swift**
- Add quality preset support (fast/balanced/thorough)
- Route through libobot for model coordination
- Streaming via CLI server WebSocket

**ModelTierManager.swift**
- Replace RAM detection with libobot `detect_tier()`
- Unified 6-tier system (Minimal through Maximum)
- Shared model mappings across CLI and IDE

**ContextManager.swift**
- Adopt libobot token budgeting
- Shared compression algorithms
- Unified context protocol format

**ConfigurationService.swift**
- Read from `~/.ollamabot/config.yaml` (unified location)
- Drop UserDefaults for AI/model settings
- Shared schema with CLI

---

## Part 3: Unified Configuration (IDE perspective)

The IDE reads the same config file as the CLI:

```yaml
# ~/.ollamabot/config.yaml
version: "2.0"

platform:
  os: macos
  arch: arm64
  ram_gb: 32
  detected_tier: performance

models:
  orchestrator: qwen3:32b
  coder: qwen2.5-coder:32b
  researcher: command-r:35b
  vision: qwen3-vl:32b

ollama:
  url: http://localhost:11434
  timeout_seconds: 120

agent:
  max_steps: 50
  allow_terminal: true
  allow_file_writes: true
  confirm_destructive: true

quality:
  fast:
    plan: false
    review: false
  balanced:
    plan: true
    review: true
    revise: false
  thorough:
    plan: true
    review: true
    revise: true

context:
  max_tokens: 32768
  budget_allocation:
    task: 25%
    files: 33%
    project: 16%
    history: 12%
    memory: 12%
    errors: 2%
  compression_enabled: true

orchestration:
  enabled: true
  schedules: [knowledge, plan, implement, scale, production]
  consultation_timeout: 60
```

IDE-specific settings (theme, font size, panel layout) remain in UserDefaults since they have no CLI equivalent.

---

## Part 4: IDE Feature Gaps to Close

These 12 features exist in CLI but are missing from IDE:

1. **Formal orchestration framework** - Add OrchestrationService.swift
2. **Human consultation system** - Add ConsultationService.swift + ConsultationView.swift
3. **Flow code tracking** - Add to OrchestrationService
4. **Quality presets (fast/balanced/thorough)** - Add QualityPresetSelector + OllamaService changes
5. **Line range editing** - Add to editor integration
6. **Diff preview modes (dry-run, diff, print)** - Add DiffPreviewView
7. **Cost savings tracking** - Add to PerformanceTrackingService
8. **Session persistence (unified format)** - Replace SessionStateService
9. **GitHub/GitLab integration** - Add to GitService
10. **Memory visualization** - Add MemoryMonitorService.swift
11. **LLM-as-judge analysis** - Add JudgeService.swift
12. **Interactive multi-turn** - Already exists as chat, ensure parity

---

## Part 5: Unified Session Format (IDE perspective)

The IDE reads and writes sessions in the same JSON format as the CLI:

```json
{
  "version": "1.0",
  "session": {
    "id": "uuid",
    "prompt": "Fix authentication bugs",
    "flow_code": "S2P1-S2P2-S2P3-S3P1-S3P2-S3P3",
    "orchestration": {
      "current_schedule": "implement",
      "current_process": 3,
      "state": "active"
    },
    "states": [
      {
        "id": "0001_S2P1",
        "schedule": 2,
        "process": 1,
        "timestamp": "2026-02-05T03:30:00Z",
        "files_hash": "abc123",
        "actions": ["A001", "A002"]
      }
    ],
    "recurrence": {
      "restore_path": ["0001_S2P1", "diff_001.patch"]
    },
    "checkpoints": [
      {
        "id": "checkpoint-001",
        "timestamp": "2026-02-05T03:30:00Z",
        "files": ["main.go", "auth.go"]
      }
    ],
    "stats": {
      "tokens_used": 45000,
      "files_created": 2,
      "files_edited": 5,
      "duration_seconds": 1200
    }
  }
}
```

Sessions started in the CLI can be viewed and resumed in the IDE, and vice versa.

---

## Part 6: Implementation Roadmap (IDE)

### Week 3: IDE to Rust Core
1. Replace ModelTierManager with libobot bindings
2. Replace ContextManager with libobot bindings
3. Replace config system with unified config reader
4. Add OrchestrationService.swift

### Week 4: IDE to CLI Server
1. Create CLIServerService.swift
2. Implement orchestration via CLI server
3. Implement tool execution via CLI server
4. Add quality pipeline UI (QualityPresetSelector)
5. Add ConsultationView.swift

### Week 5-6: Feature Parity and Polish
1. Add OrchestrationView.swift (5-phase visualizer)
2. Add JudgeService.swift (LLM-as-judge)
3. Add MemoryMonitorService.swift
4. Cross-product session compatibility testing
5. Performance optimization and documentation

---

## Part 7: Success Metrics (IDE)

- Orchestration UI shows same flow codes as CLI
- Quality presets produce comparable results to CLI
- Sessions are interoperable (start in CLI, resume in IDE)
- Configuration changes in ~/.ollamabot/config.yaml reflected in both products
- No regression in IDE performance or responsiveness

---

*End of IDE Master Plan*
