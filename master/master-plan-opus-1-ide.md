# Ultimate Consolidated Harmonization Plan (Round 2) — IDE Focus

**Agent:** opus-1  
**Round:** 2 (Final Consolidation)  
**Date:** 2026-02-05  
**Sources:** 11 plans from Round 1 (sonnet-2, composer-1/2/3/4, gemini-1/4/5, opus-1, consolidated-opus-1, consolidated-composer-2)

---

## Executive Summary

This plan represents the **definitive consensus** from 11 comprehensive analyses. The core strategy is:

> **Protocol-First Harmonization** with **CLI as Execution Engine** and **IDE as Visualization Layer**, connected via shared schemas and JSON-RPC communication.

**Key Consensus Decisions:**
1. **REJECT** full Rust core rewrite (high-risk, FFI complexity)
2. **ADOPT** `obot server` mode as execution backend
3. **ADOPT** shared YAML/JSON protocols (not shared code)
4. **ADOPT** CLI's 5-schedule orchestration as master protocol
5. **ADOPT** IDE's context management logic (ported to specs)

---

## Part 1: Unified Architecture

### 1.1 The "Engine & Cockpit" Model

```
┌─────────────────────────────────────────────────────────────┐
│                   ollamabot IDE (Swift)                     │
│                   "The Cockpit"                             │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   SwiftUI   │  │   State     │  │  CLIBridgeService   │ │
│  │   Views     │  │   Management│  │  (JSON-RPC Client)  │ │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘ │
│         └────────────────┴───────────────────┬┘            │
│                                              │              │
│                     ┌────────────────────────┴─┐           │
│                     │    IPC Channel (stdio)   │           │
│                     └────────────────────────┬─┘           │
└─────────────────────────────────────────────┼──────────────┘
                                              │
┌─────────────────────────────────────────────┼──────────────┐
│                                              │              │
│                     ┌────────────────────────┴─┐           │
│                     │ obot server (JSON-RPC)   │           │
│                     └────────────────────────┬─┘           │
│                                              │              │
│  ┌─────────────┐  ┌─────────────┐  ┌────────┴────────────┐ │
│  │Orchestration│  │   Context   │  │   Agent Engine      │ │
│  │  (5x3)      │  │   Manager   │  │   (Tools, Models)   │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│                                                             │
│                    obot CLI (Go)                            │
│                    "The Engine"                             │
└─────────────────────────────────────────────────────────────┘
```

**Benefits:**
- Single source of truth for execution logic (Go)
- IDE focuses purely on UX (Swift's strength)
- Guaranteed behavioral consistency
- Reduced maintenance (no duplicate logic)
- CLI works standalone OR as IDE backend

### 1.2 Communication Protocol

**Mode:** JSON-RPC over stdio (simplest, fastest, no network)

**Server Command:**
```bash
obot server [--socket /tmp/obot.sock]
```

**Message Types:**
```json
{"jsonrpc": "2.0", "id": 1, "method": "startTask", "params": {"task": "...", "context": {}}}
{"jsonrpc": "2.0", "id": 1, "result": {"session_id": "...", "status": "running"}}
{"jsonrpc": "2.0", "method": "event", "params": {"type": "tool_call", "data": {}}}
```

---

## Part 2: The Five Unified Protocols

### 2.1 Unified Configuration Schema (UCS)

**Location:** `~/.config/ollamabot/config.yaml`

```yaml
version: "1.0"

models:
  tier: auto
  orchestrator: "qwen3:32b"
  coder: "qwen2.5-coder:32b"
  researcher: "command-r:35b"
  vision: "qwen3-vl:32b"

ollama:
  url: "http://localhost:11434"
  timeout_seconds: 300

generation:
  temperature: 0.3
  max_tokens: 4096
  context_window: 32768

quality:
  default: balanced
  presets:
    fast:
      steps: [execute]
      review: false
    balanced:
      steps: [plan, execute, review]
      review: true
    thorough:
      steps: [plan, execute, review, revise]
      review: true
      max_revisions: 3

orchestration:
  enabled: true
  flow_code_tracking: true
  human_consultation:
    clarify: optional
    feedback: mandatory

agent:
  max_steps: 50
  allow_terminal: true
  allow_file_writes: true
  confirm_destructive: true
  parallel_tools: true

context:
  max_tokens: 32000
  compression: true
  budget:
    task: 0.25
    file_content: 0.33
    project_structure: 0.16
    conversation: 0.12
    memory: 0.12
    errors: 0.06

sessions:
  auto_save: true
  save_interval_seconds: 30
  storage: "~/.config/ollamabot/sessions/"

ide:
  theme: dark
  font_size: 14
  show_token_usage: true

cli:
  verbose: true
  mem_graph: true
  colors: true
```

### 2.2 Unified Tool Specification (UTS)

**Location:** `~/.config/ollamabot/tools.yaml`

```yaml
version: "1.0"

tools:
  - id: think
    category: core
    platforms: [ide, cli]
    description: "Record internal reasoning steps"
    parameters: []

  - id: complete
    category: core
    platforms: [ide, cli]
    description: "Signal task completion with summary"
    parameters:
      - name: summary
        type: string
        required: true

  - id: ask_user
    category: core
    platforms: [ide, cli]
    description: "Request user input (with optional timeout)"
    parameters:
      - name: question
        type: string
        required: true
      - name: timeout_seconds
        type: integer
        default: 60

  - id: file.read
    aliases: [read_file, ReadFile]
    category: file
    platforms: [ide, cli]
    parameters:
      - name: path
        type: string
        required: true

  - id: file.write
    aliases: [write_file, WriteFile, create_file, CreateFile]
    category: file
    platforms: [ide, cli]
    parameters:
      - name: path
        type: string
        required: true
      - name: content
        type: string
        required: true

  - id: file.edit
    aliases: [edit_file, EditFile]
    category: file
    platforms: [ide, cli]
    parameters:
      - name: path
        type: string
        required: true
      - name: old_string
        type: string
        required: true
      - name: new_string
        type: string
        required: true

  - id: file.delete
    aliases: [delete_file, DeleteFile]
    category: file
    platforms: [ide, cli]
    parameters:
      - name: path
        type: string
        required: true

  - id: file.search
    aliases: [search_files, SearchFiles]
    category: file
    platforms: [ide, cli]
    parameters:
      - name: query
        type: string
        required: true
      - name: scope
        type: string
        default: "."

  - id: dir.list
    aliases: [list_directory, ListDirectory]
    category: file
    platforms: [ide, cli]
    parameters:
      - name: path
        type: string
        required: true

  - id: dir.create
    aliases: [create_dir, CreateDirectory]
    category: file
    platforms: [ide, cli]
    parameters:
      - name: path
        type: string
        required: true

  - id: sys.exec
    aliases: [run_command, RunCommand, ShellExec]
    category: system
    platforms: [ide, cli]
    parameters:
      - name: command
        type: string
        required: true
      - name: timeout_seconds
        type: integer
        default: 30

  - id: git.status
    aliases: [git_status, GitStatus]
    category: git
    platforms: [ide, cli]

  - id: git.diff
    aliases: [git_diff, GitDiff]
    category: git
    platforms: [ide, cli]
    parameters:
      - name: path
        type: string

  - id: git.commit
    aliases: [git_commit, GitCommit]
    category: git
    platforms: [ide, cli]
    parameters:
      - name: message
        type: string
        required: true

  - id: web.search
    aliases: [web_search]
    category: web
    platforms: [ide, cli]
    parameters:
      - name: query
        type: string
        required: true

  - id: web.fetch
    aliases: [fetch_url]
    category: web
    platforms: [ide, cli]
    parameters:
      - name: url
        type: string
        required: true

  - id: delegate.coder
    aliases: [delegate_to_coder]
    category: delegation
    platforms: [ide, cli]
    requires_model: coder
    parameters:
      - name: task
        type: string
        required: true
      - name: context
        type: string

  - id: delegate.researcher
    aliases: [delegate_to_researcher]
    category: delegation
    platforms: [ide, cli]
    requires_model: researcher
    parameters:
      - name: query
        type: string
        required: true

  - id: delegate.vision
    aliases: [delegate_to_vision]
    category: delegation
    platforms: [ide, cli]
    requires_model: vision
    parameters:
      - name: task
        type: string
        required: true
      - name: image_path
        type: string
        required: true
```

### 2.3 Unified Orchestration Protocol (UOP)

```yaml
version: "1.0"

schedules:
  - id: 1
    name: Knowledge
    processes:
      - {id: 1, name: Research}
      - {id: 2, name: Crawl}
      - {id: 3, name: Retrieve}
    model: researcher

  - id: 2
    name: Plan
    processes:
      - {id: 1, name: Brainstorm}
      - {id: 2, name: Clarify, consultation: {type: optional, timeout: 60}}
      - {id: 3, name: Plan}
    model: coder

  - id: 3
    name: Implement
    processes:
      - {id: 1, name: Implement}
      - {id: 2, name: Verify}
      - {id: 3, name: Feedback, consultation: {type: mandatory, timeout: 300}}
    model: coder

  - id: 4
    name: Scale
    processes:
      - {id: 1, name: Scale}
      - {id: 2, name: Benchmark}
      - {id: 3, name: Optimize}
    model: coder

  - id: 5
    name: Production
    processes:
      - {id: 1, name: Analyze}
      - {id: 2, name: Systemize}
      - {id: 3, name: Harmonize}
    model: [coder, vision]

navigation_rules:
  P1: [P1, P2]
  P2: [P1, P2, P3]
  P3: [P2, P3, terminate]

termination:
  requires:
    - all_schedules_run_once
    - last_schedule_is_production

flow_code:
  format: "S{schedule}P{process}"
  example: "S1P123S2P12S3P123S4P123S5P123"
```

### 2.4 Unified Context Protocol (UCP)

```json
{
  "$schema": "https://ollamabot.dev/schemas/context-v1.json",
  "version": "1.0",
  "task": {
    "description": "Build REST API for user management",
    "files": ["src/api.go", "src/types.go"],
    "mentions": ["@file:utils.go", "@context:api-docs"]
  },
  "budget": {
    "total": 32000,
    "allocation": {
      "task": 8000,
      "file_content": 10560,
      "project_structure": 5120,
      "conversation": 3840,
      "memory": 3840,
      "errors": 640
    },
    "used": 24500
  },
  "files": [
    {"path": "src/api.go", "summary": "Main API handlers with CRUD operations", "tokens": 1200, "compressed": false}
  ],
  "conversation": [
    {"role": "user", "content": "Add authentication middleware"},
    {"role": "assistant", "tool_calls": ["..."]}
  ],
  "memory": [
    {"id": "mem_001", "summary": "Fixed authentication bug in JWT validation", "relevance": 0.85, "timestamp": "2026-02-05T03:00:00Z"}
  ],
  "errors": {
    "patterns": [
      {"pattern": "undefined: jwt.Parse", "solution": "Import github.com/golang-jwt/jwt/v5", "occurrences": 2}
    ]
  }
}
```

### 2.5 Unified State Format (USF)

```json
{
  "$schema": "https://ollamabot.dev/schemas/session-v1.json",
  "version": "1.0",
  "session": {
    "id": "sess_abc123",
    "created": "2026-02-05T03:00:00Z",
    "modified": "2026-02-05T03:30:00Z",
    "platform": "cli",
    "prompt": "Build REST API for user management"
  },
  "orchestration": {
    "enabled": true,
    "flow_code": "S1P123S2P12S3P1",
    "current": {"schedule": 3, "process": 1},
    "history": [
      {"schedule": 1, "processes": [1, 2, 3]},
      {"schedule": 2, "processes": [1, 2]}
    ],
    "state": "active"
  },
  "context": {},
  "actions": [
    {"id": "A00001", "timestamp": "2026-02-05T03:05:00Z", "schedule": 3, "process": 1, "type": "file.write", "params": {"path": "src/auth.go", "content": "..."}, "result": {"success": true}}
  ],
  "checkpoints": [
    {"id": "cp_001", "timestamp": "2026-02-05T03:04:00Z", "description": "Before auth implementation", "auto": true, "files": [{"path": "src/api.go", "hash": "sha256:abc..."}], "git": {"branch": "feature/auth", "commit": "abc123", "dirty": true}}
  ],
  "consultation": {
    "responses": [
      {"schedule": 2, "process": 2, "question": "Which authentication method?", "response": "Use JWT", "source": "user", "timestamp": "2026-02-05T03:10:00Z"}
    ]
  },
  "stats": {
    "tokens": {"total": 45230, "by_model": {"orchestrator": 12000, "coder": 28000, "researcher": 5230}},
    "files": {"created": 3, "modified": 7, "deleted": 0},
    "commands": 12,
    "duration": "PT30M"
  }
}
```

---

## Part 3: Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)
- Define JSON Schemas for all 5 protocols
- Create schema validation libraries (Go + Swift)
- Implement YAML config loader in Go and Swift
- Migrate CLI from JSON to YAML
- Add config sync validation tests

### Phase 2: Core Integration (Weeks 3-4)
- Implement `obot server` command
- Implement JSON-RPC message handling and event streaming
- Create `CLIBridgeService.swift` (~400 lines)
- Wire orchestration UI to bridge with fallback to native execution

### Phase 3: Feature Parity (Weeks 5-6)
- Port IDE's ContextManager logic to Go
- Add `.obotrules` parser and `@mention` system to CLI
- Add orchestration mode UI, quality presets, flow code visualization to IDE
- Implement human consultation modal in IDE

### Phase 4: Polish (Weeks 7-8)
- Cross-platform compatibility and session portability tests
- Performance benchmarking
- Documentation and migration guides

---

## Part 4: IDE File Changes

### New Files

| File | Lines | Description |
|------|-------|-------------|
| `Sources/Services/CLIBridgeService.swift` | ~400 | JSON-RPC client |
| `Sources/Services/SharedConfigService.swift` | ~300 | YAML config |
| `Sources/Views/OrchestrationView.swift` | ~450 | Orchestration UI |
| `Sources/Views/QualityPresetPicker.swift` | ~100 | Quality selector |
| `Sources/Views/ConsultationView.swift` | ~200 | Human consultation |

### Modified Files

| File | Changes | Description |
|------|---------|-------------|
| `Sources/Services/OllamaService.swift` | +100 | Bridge integration |
| `Sources/Views/ChatView.swift` | +50 | Quality selector |
| `Sources/Agent/AgentExecutor.swift` | +150 | Orchestration mode |

---

## Part 5: Success Metrics

- **Protocol Compliance:** 100% messages validate against schemas
- **Feature Parity:** 90%+ core features in both products
- **Session Portability:** 100% sessions work cross-platform
- **Performance:** <5% overhead from bridge communication
- **Test Coverage:** >80% for new code

---

## Part 6: Risk Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| IPC latency | Low | Medium | Benchmark early, optimize hot paths |
| Schema drift | Medium | High | Automated validation, CI checks |
| User confusion | Medium | Medium | Clear migration guides, feature flags |
| Scope creep | High | Medium | Strict phase boundaries, weekly reviews |
| Performance regression | Low | High | Continuous benchmarking |

---

## Conclusion

Protocol-First with CLI-as-Engine provides simplicity, speed, consistency, maintainability, and flexibility. Two products that operate as CLI and IDE versions of the same tool — harmonized in behavior, consistent in experience, optimized for their respective mediums.

---

*End of Ultimate Consolidated Plan (Round 2) — IDE Focus — opus-1*
