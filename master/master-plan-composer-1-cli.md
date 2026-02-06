# OllamaBot Master Harmonization Plan - CLI Component

**Agent**: composer-1  
**Round**: 2 (Final Re-Optimization)  
**Date**: 2026-02-05  
**Scope**: obot CLI (Go/Cobra)

---

## Executive Summary

This plan defines the CLI-side harmonization strategy for unifying obot CLI with OllamaBot IDE into a single product ecosystem. The CLI adopts the "Engine" role in the Engine-and-Cockpit architecture, serving as the canonical execution engine with a new server mode that the IDE consumes.

---

## Part 1: CLI Architecture Role

### 1.1 Engine Pattern

The CLI is the single source of truth for all execution logic. It operates in two modes: direct CLI usage and server mode for IDE consumption.

```
obot CLI (ENGINE)
├── CLI Mode (direct terminal usage)
│   ├── obot main.go "fix bugs"
│   ├── obot orchestrate "Build REST API"
│   ├── obot plan . "fix TODOs"
│   └── obot --saved / obot --stats
├── Server Mode (IDE consumption)
│   ├── obot --server --port 9111
│   ├── POST /api/v1/agent/execute
│   ├── POST /api/v1/orchestrate/start
│   ├── GET  /api/v1/session/{id}
│   ├── POST /api/v1/context/build
│   ├── POST /api/v1/tools/execute
│   └── WS   /api/v1/stream
└── Core Engine
    ├── Orchestrator (5 schedules, 3 processes)
    ├── Agent (tool execution, action recording)
    ├── Context Manager (token budgeting, compression)
    ├── Model Coordinator (tier detection, routing)
    ├── Session Manager (unified format)
    └── Quality Pipeline (fast/balanced/thorough)
```

### 1.2 Current CLI Packages (to be extended)

- `internal/orchestrate/` - Already implements 5-schedule framework (keep as-is)
- `internal/fixer/` - Fix engine with quality pipeline (keep as-is)
- `internal/agent/` - Agent with tool execution (extend with new tools)
- `internal/tier/` - RAM-based tier detection (align with IDE's 6 tiers)
- `internal/config/` - Configuration (migrate to unified format)
- `internal/context/` - Context building (add token budgeting)
- `internal/session/` - Session management (adopt unified JSON format)
- `internal/ollama/` - Ollama client (keep as-is)
- `internal/cli/` - Cobra commands (add server mode)

---

## Part 2: Critical CLI Changes

### 2.1 New Packages Required

**internal/server/** (~500 lines)
- HTTP server with REST API endpoints
- WebSocket streaming for real-time events
- JSON request/response handling
- CORS support for IDE consumption

**internal/mention/parser.go** (~200 lines)
- Parse @mention syntax from instruction text
- Support: @file:path, @folder:path, @codebase, @context:id, @bot:id, @template:id, @git:diff|log|status

**internal/mention/resolver.go** (~300 lines)
- Resolve parsed mentions to content
- File content inclusion
- Folder structure listing
- Git information retrieval
- Integration with context builder

**internal/obotrules/loader.go** (~250 lines)
- Parse .obotrules file from project root
- YAML configuration loading
- Rule application to agent behavior

**internal/obotrules/parser.go** (~200 lines)
- Parse .obot/ directory structure
- Load bot definitions (YAML)
- Load context snippets
- Load templates

### 2.2 Modified Packages

**internal/tier/detect.go**
- Add Maximum tier (128GB+ RAM) to match IDE
- Unified 6-tier system: Minimal, Compact, Balanced, Performance, Advanced, Maximum
- Add multi-model support per tier (orchestrator, coder, researcher, vision)

**internal/config/config.go**
- Migrate from `~/.config/obot/config.json` to `~/.ollamabot/config.yaml`
- YAML format instead of JSON
- Shared schema with IDE
- Add .obotrules support

**internal/context/summary.go**
- Add token budgeting (ported from IDE ContextManager)
- Add semantic compression
- Add mention resolution integration
- Unified context protocol format

**internal/session/session.go**
- Adopt unified JSON session format
- Flow code tracking in sessions
- Recurrence relations for state restoration
- Checkpoint integration

**internal/cli/root.go**
- Add --server flag and server subcommand
- Add @mention syntax in instruction parsing
- Add .obotrules loading on startup

---

## Part 3: CLI Server Mode API

### 3.1 Endpoints

**POST /api/v1/agent/execute**
```json
{
  "task": "Fix the nil pointer dereference",
  "files": ["main.go"],
  "mode": "fix",
  "options": {
    "quality": "balanced",
    "working_directory": "/path/to/project",
    "dry_run": false
  }
}
```

**POST /api/v1/orchestrate/start**
```json
{
  "prompt": "Build a REST API for user management",
  "options": {
    "hub": "my-api",
    "memory_limit": "8GB",
    "token_limit": 0,
    "timeout": "2h"
  }
}
```

**GET /api/v1/orchestrate/status**
```json
{
  "state": "active",
  "schedule": "implement",
  "process": 2,
  "flow_code": "S1P123S2P12",
  "stats": {
    "total_schedulings": 3,
    "total_processes": 8,
    "total_tokens": 45000
  }
}
```

**POST /api/v1/context/build**
```json
{
  "target_path": "main.go",
  "instruction": "fix null checks",
  "mentions": ["@file:utils.go", "@codebase"],
  "max_tokens": 32768
}
```

**GET /api/v1/session/{id}**
Returns the unified session JSON format.

**POST /api/v1/tools/execute**
```json
{
  "tool": "file.read",
  "params": { "path": "main.go" }
}
```

**WS /api/v1/stream**
WebSocket endpoint for real-time streaming of agent actions, orchestration events, and model output.

---

## Part 4: Unified Configuration (CLI perspective)

The CLI reads the same config file as the IDE:

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

CLI-specific settings (verbose, mem_graph, color_output) are command-line flags only, not in the shared config.

---

## Part 5: CLI Feature Gaps to Close

These 16 features exist in IDE but are missing from CLI:

1. **.obotrules support** - Add internal/obotrules/ package
2. **@mention system** - Add internal/mention/ package
3. **Multi-model delegation** - Add delegate tools to agent
4. **Advanced context management** - Port token budgeting from IDE
5. **Checkpoint system** - Add checkpoint save/restore commands
6. **Vision model integration** - Add vision tool to agent
7. **Web search tools** - Add web_search and fetch_url tools
8. **Git integration tools** - Add git_status, git_diff, git_commit tools
9. **Intent routing** - Add auto-model selection based on task type
10. **File system services** - Add caching and async operations
11. **Bot execution** - Add bot runner from .obot/bots/
12. **Template engine** - Add template processing from .obot/templates/
13. **Context snippets** - Add @context mention resolution
14. **Inline completions** - N/A (IDE-only, medium advantage)
15. **Command palette** - N/A (IDE-only, medium advantage)
16. **Explorer mode** - Map to orchestration continuous mode

---

## Part 6: Unified Session Format (CLI perspective)

The CLI reads and writes sessions in the same JSON format as the IDE:

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

Session storage moves from `~/.obot/sessions/` to `~/.ollamabot/sessions/` for unified access.

---

## Part 7: Unified Tool Registry (CLI additions)

Tools the CLI must add to achieve parity:

| Tool ID | Description | Priority |
|---------|-------------|----------|
| ai.delegate.coder | Delegate coding task to specialist model | HIGH |
| ai.delegate.researcher | Delegate research task to specialist model | HIGH |
| ai.delegate.vision | Delegate vision task to specialist model | MEDIUM |
| web.search | Search web via DuckDuckGo | HIGH |
| web.fetch | Fetch web page content | HIGH |
| file.search | Search text across codebase | HIGH |
| file.list | List directory contents | HIGH |
| system.screenshot | Capture screen for vision | LOW (CLI-limited) |

---

## Part 8: Implementation Roadmap (CLI)

### Week 1-2: Foundation
1. Add --server mode to CLI (internal/server/)
2. Implement HTTP API endpoints
3. Implement WebSocket streaming
4. Migrate config to ~/.ollamabot/config.yaml

### Week 5: CLI Feature Parity
1. Add internal/obotrules/ (.obotrules parser)
2. Add internal/mention/ (@mention system)
3. Add delegate, web, and git tools to agent
4. Port token budgeting to context builder
5. Add checkpoint save/restore

### Week 6: Final Integration
1. Cross-product session compatibility
2. Unified tool vocabulary
3. Config migration script (old to new location)
4. Performance optimization
5. Documentation

---

## Part 9: Success Metrics (CLI)

- Server mode responds correctly to all API endpoints
- IDE can execute full orchestration workflow via CLI server
- Sessions are interoperable (start in IDE, resume in CLI)
- .obotrules and @mentions work in CLI instructions
- Configuration changes in ~/.ollamabot/config.yaml reflected in both products
- All 22 tools available in both products (where medium permits)
- No regression in CLI fix speed or quality

---

*End of CLI Master Plan*
