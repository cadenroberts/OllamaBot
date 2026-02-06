# Master Plan: Gemini-2 — obot CLI

**Agent:** gemini-2
**Product:** obot CLI (Go)
**Status:** COMPLETE
**Date:** 2026-02-05

## Architecture Role

obot CLI becomes the **Universal Engine** — exposing all business logic via a JSON-RPC server that the IDE consumes, while retaining its own CLI interface.

```
obot (Go) = The Engine
  pkg/core/         - Shared types and schemas
  pkg/tier/         - Hardware detection (6 tiers, 4 model roles)
  pkg/config/       - Unified YAML config (~/.obot/config.yaml)
  pkg/context/      - Token budgeting (ported from Swift ContextManager)
  pkg/orchestrator/ - 5-Schedule / 3-Process state machine
  pkg/tools/        - 22-tool registry
  pkg/ollama/       - Ollama client
  pkg/session/      - Unified session format (USF)
  pkg/rpc/          - JSON-RPC 2.0 server over Stdio
  cmd/obot/         - CLI entrypoint
  cmd/server/       - RPC server entrypoint
```

## 6 Unified Protocols

1. **UOP** - Unified Orchestration Protocol: 5 Schedules (Knowledge, Plan, Implement, Scale, Production), 3 Processes each, navigation rules (1-2-3)
2. **UTR** - Unified Tool Registry: 22 tools across 6 categories (Core, Files, System, Delegation, Web, Git)
3. **UCP** - Unified Context Protocol: Token-budgeted context with priority sections and compression
4. **UMC** - Unified Model Coordinator: 6 RAM tiers, 4 model roles (orchestrator, coder, researcher, vision)
5. **UC** - Unified Configuration: Single ~/.obot/config.yaml for both products
6. **USF** - Unified State Format: JSON session persistence at ~/.obot/sessions/{id}.json

## CLI-Specific Implementation Plans

### PLAN-SPECS
Define 6 Unified Protocol JSON Schemas and Go types.

- Create `pkg/core/types.go` with ScheduleID, ProcessID, ModelRole, TierID constants
- Create `pkg/core/schemas/` with orchestration.schema.json, tools.schema.json, context.schema.json, models.schema.json, config.schema.json, session.schema.json

### PLAN-CORE-REFACTOR
Restructure obot from internal/ to pkg/ for reusability.

Move to pkg/:
- actions, agent->engine, analyzer, config, consultation, context, fsutil, index, judge, model, monitor, oberror, obotgit->git, ollama, orchestrate->orchestrator, planner, resource, session, stats, summary, tier, version

Keep in internal/:
- cli/ (CLI commands), ui/ (terminal TUI), fixer/ (CLI fix engine), review/ (CLI review)

### PLAN-CONFIG
Unified configuration at ~/.obot/config.yaml.

```yaml
version: "1.0"
tier: auto
ollama_url: "http://localhost:11434"
temperature: 0.3
max_tokens: 4096
verbose: false
models:
  orchestrator: ""
  coder: ""
  researcher: ""
  vision: ""
quality: balanced
orchestration:
  allow_consultation: true
  ai_fallback_timeout: 60
  session_persistence: true
```

- Add `gopkg.in/yaml.v3` dependency
- Auto-migrate from legacy ~/.config/obot/config.json

### PLAN-CONTEXT-GO
Port Swift ContextManager (703 lines) to Go.

- `pkg/context/manager.go`: Manager struct with config, memory, projectCache, toolResults, errorPatterns
- `pkg/context/budget.go`: TokenBudget with per-section allocation and remaining calculation
- `pkg/context/compress.go`: EstimateTokens (len/4), CompressCode (keep first+last, elide middle), CompressContext (ratio truncation)
- `pkg/context/memory.go`: MemoryEntry with keyword-based retrieval, access counting, LRU pruning

### PLAN-TIER-GO
Merge Go 5-tier + Swift 6-tier into unified 6-tier system.

- 6 tiers: minimal(8GB), compact(16GB), balanced(24GB), performance(32GB), advanced(64GB), maximum(128GB)
- 4 model roles per tier: orchestrator, coder, researcher, vision
- Port all model variant tables from Swift ModelTierManager (lines 91-293)
- Port MemorySettings and PerformanceExpectations from Swift

### PLAN-TOOLS-GO
Implement 22-tool registry.

- `pkg/tools/registry.go`: Tool struct, Registry, Execute dispatcher
- `pkg/tools/core.go`: think, complete, ask_user
- `pkg/tools/files.go`: read_file, create_file, edit_file, delete_file, create_dir, delete_dir, rename, move, copy, search_files, list_directory
- `pkg/tools/system.go`: run_command, take_screenshot
- `pkg/tools/delegation.go`: delegate_to_coder, delegate_to_researcher, delegate_to_vision
- `pkg/tools/web.go`: web_search, fetch_url
- `pkg/tools/gittools.go`: git_status, git_diff, git_commit

### PLAN-ORCHESTRATOR-GO
Formalize 5-Schedule state machine as reusable library.

- `pkg/orchestrator/orchestrator.go`: callback-based Orchestrator (accepts ScheduleSelector + ProcessExecutor functions)
- `pkg/orchestrator/navigator.go`: IsValidNavigation, ValidOptionsFrom
- `pkg/orchestrator/flowcode.go`: AppendToFlowCode, ParseFlowCode
- `pkg/orchestrator/types.go`: State enum (begin, selecting, active, suspended, terminated), StateUpdate struct

### PLAN-RPC-SERVER
Build `obot server` command with JSON-RPC 2.0 over Stdio.

Request methods (Client->Server):
- initialize, session/start, session/execute, session/pause, session/resume
- tool/execute, tier/detect, config/get, config/set

Notification methods (Server->Client):
- orchestrator/state, agent/action, agent/output
- context/update, consultation/request, memory/update

Entrypoint: `cmd/server/main.go`

## Key Decisions

1. Rust rewrite rejected — too risky for March deadline
2. Go chosen as engine — refactor existing code, not rewrite
3. JSON-RPC over Stdio — proven pattern (LSP, DAP, MCP)
4. Dual-mode operation — Quick Mode (local) + Orchestrated Mode (RPC)
5. IDE's context management ported TO Go (not the other way)
6. CLI's orchestration framework becomes the standard for both products

## Model Contribution Summary

| Model | Primary Contribution | Adopted |
|-------|---------------------|---------|
| Sonnet | Rust core proposal, 90 optimizations, thoroughness | Analysis adopted, Rust rejected |
| Opus | 6 Unified Protocols, 22-tool registry | Fully adopted |
| GPT | Honest stub assessment, incremental approach | Assessment adopted, approach rejected |
| Gemini | Go Engine + JSON-RPC architecture | Fully adopted (core decision) |
| Composer | 10-area component gap analysis | Fully adopted (informed porting decisions) |
