# FINAL CONSOLIDATED MASTER PLAN: obot CLI Harmonization
## Agent: opus-2 | CLI Focus | March 2026 Release

**Agent:** Claude Opus (opus-2)
**Date:** 2026-02-05
**Scope:** obot CLI (Go) enhancements for harmonization
**Status:** FLOW EXIT COMPLETE

---

## Executive Summary

This plan covers all CLI-side changes required to harmonize obot CLI with OllamaBot IDE under the Protocol-First Architecture. The CLI gains multi-model delegation, token-budgeted context management, read/search tools, web search, git tools, and shared YAML configuration -- while preserving its existing orchestration engine, session persistence, and cost tracking strengths.

---

## Architecture: CLI as Engine

The CLI is the canonical execution engine. Its orchestrator state machine, session persistence, and agent execution are the reference implementations that the IDE mirrors.

```
~/.config/ollamabot/config.yaml  <-- Shared config (read/write by CLI)
~/.config/obot/ -> symlink       <-- Backward compat for existing users
~/.config/ollamabot/schemas/     <-- Protocol schemas (validated by CLI)
~/.config/ollamabot/sessions/    <-- Cross-platform sessions (read/write)

obot CLI (Go)
├── EXISTING (preserved):
│   ├── internal/orchestrate/    -- 5-schedule x 3-process state machine
│   ├── internal/agent/          -- 12 executor actions (write-only)
│   ├── internal/fixer/          -- Code fix engine with prompt building
│   ├── internal/session/        -- Session persistence (bash scripts)
│   ├── internal/tier/           -- RAM-based tier detection
│   ├── internal/config/         -- Configuration (currently JSON)
│   ├── internal/ollama/         -- Ollama API client
│   └── internal/cli/            -- CLI commands and TUI
│
├── NEW (March harmonization):
│   ├── internal/config/config.go    -- YAML config (replace JSON)
│   ├── internal/config/migrate.go   -- Migration from old JSON config
│   ├── internal/context/manager.go  -- Token-budgeted context builder
│   ├── internal/context/compress.go -- Semantic truncation
│   ├── internal/router/intent.go    -- Intent-based model routing
│   ├── internal/model/coordinator.go -- 4-model coordinator
│   ├── internal/agent/delegation.go  -- delegate_to_coder/researcher/vision
│   ├── internal/agent/read.go        -- ReadFile, SearchFiles, ListFiles
│   ├── internal/tools/web.go         -- DuckDuckGo web search
│   ├── internal/tools/git.go         -- git status/diff/commit
│   ├── internal/session/unified.go   -- USF JSON serialization
│   └── internal/cli/checkpoint.go    -- Checkpoint commands
│
└── MODIFIED:
    ├── internal/config/config.go  -- JSON -> YAML, new path
    ├── internal/tier/models.go    -- Read from shared config
    └── internal/session/session.go -- USF format alongside bash scripts
```

---

## CLI Enhancement Plan (10 items)

### C-01: YAML Config Migration
- **Files:** `internal/config/config.go` (MODIFY), `internal/config/migrate.go` (NEW)
- **Purpose:** Replace JSON config with YAML at `~/.config/ollamabot/config.yaml`
- **Migration:** Detect old `~/.config/obot/config.json`, convert to YAML, create backward-compat symlink
- **Library:** `gopkg.in/yaml.v3`

### C-02: Context Manager (port from IDE)
- **File:** `internal/context/manager.go` (NEW)
- **Purpose:** Token-budget-aware context builder
- **Budget allocation:** system 7%, rules 4%, task 14%, files 42%, project 10%, history 14%, memory 5%, errors 4%
- **Library:** `github.com/pkoukk/tiktoken-go` for token counting

### C-03: Semantic Compression
- **File:** `internal/context/compression.go` (NEW)
- **Purpose:** Truncate context while preserving imports, function signatures, error sections
- **Strategy:** Priority-based section trimming when over token budget

### C-04: Intent Router
- **File:** `internal/router/intent.go` (NEW)
- **Purpose:** Keyword-based intent classification (coding/research/general/vision)
- **Integration:** Routes to appropriate model when multi-model is enabled

### C-05: Multi-Model Coordinator
- **File:** `internal/model/coordinator.go` (MODIFY)
- **Purpose:** Support 4 model roles (orchestrator, coder, researcher, vision)
- **Tier fallback:** Each role has tier_mapping in config for hardware-appropriate model selection

### C-06: Multi-Model Delegation Tools
- **File:** `internal/agent/delegation.go` (NEW)
- **Purpose:** `delegate_to_coder`, `delegate_to_researcher`, `delegate_to_vision` tools
- **Behavior:** Build delegation-specific context, call specialist model, return result to orchestrator

### C-07: Read/Search/List Tools (Tier 2)
- **File:** `internal/agent/read.go` (NEW)
- **Purpose:** Add ReadFile, SearchFiles, ListFiles methods to agent
- **Impact:** CLI agent evolves from write-only (Tier 1) to read-write (Tier 2)

### C-08: Web Search Tool
- **File:** `internal/tools/web.go` (NEW)
- **Purpose:** DuckDuckGo search integration for research tasks
- **Output:** Structured search results with title, URL, snippet

### C-09: Git Tools
- **File:** `internal/tools/git.go` (NEW)
- **Purpose:** `git status`, `git diff`, `git commit` tools
- **Implementation:** Shell out to git binary, parse output

### C-10: Checkpoint System
- **File:** `internal/cli/checkpoint.go` (NEW)
- **Purpose:** `obot checkpoint save/restore/list` commands
- **Storage:** File snapshots in `~/.config/ollamabot/sessions/{session_id}/checkpoints/`

---

## Session Format Enhancement

### Unified Session Format (USF)
- **File:** `internal/session/unified.go` (NEW)
- **Purpose:** JSON-based session format compatible with IDE
- **Schema:**
```json
{
  "version": "1.0",
  "session_id": "sess_20260205_153045",
  "source_platform": "cli",
  "task": {
    "description": "...",
    "intent": "coding",
    "quality_preset": "balanced"
  },
  "orchestration_state": {
    "flow_code": "S1P123S2P12",
    "current_schedule": "implement",
    "current_process": 2
  },
  "conversation_history": [],
  "files_modified": [],
  "checkpoints": []
}
```
- **Backward compat:** Existing bash restoration scripts continue to work alongside USF

---

## Configuration Schema (v2.0)

```yaml
version: "2.0"

platform:
  os: darwin
  arch: arm64
  ram_gb: 32
  detected_tier: performance

models:
  orchestrator:
    primary: "qwen3:32b"
    tier_mapping:
      minimal: "qwen3:8b"
      balanced: "qwen3:14b"
      performance: "qwen3:32b"
  coder:
    primary: "qwen2.5-coder:32b"
    tier_mapping:
      minimal: "deepseek-coder:1.3b"
      compact: "deepseek-coder:6.7b"
      balanced: "qwen2.5-coder:14b"
      performance: "qwen2.5-coder:32b"
  researcher:
    primary: "command-r:35b"
    tier_mapping:
      minimal: "command-r:7b"
      performance: "command-r:35b"
  vision:
    primary: "qwen3-vl:32b"
    tier_mapping:
      minimal: "llava:7b"
      balanced: "llava:13b"
      performance: "qwen3-vl:32b"

quality:
  presets:
    fast:
      pipeline: ["execute"]
      verification: none
    balanced:
      pipeline: ["plan", "execute", "review"]
      verification: llm_review
    thorough:
      pipeline: ["plan", "execute", "review", "revise"]
      verification: expert_judge

context:
  token_limits:
    max_context: 32768
    reserve_response: 4096
  budget_allocation:
    system_prompt: 0.07
    project_rules: 0.04
    task_description: 0.14
    file_content: 0.42
    project_structure: 0.10
    conversation_history: 0.14
    memory_patterns: 0.05
    error_warnings: 0.04

orchestration:
  full_schedules: ["knowledge", "plan", "implement", "scale", "production"]
  consultation:
    clarify: {type: optional, timeout_seconds: 60}
    feedback: {type: mandatory, timeout_seconds: 300}
```

---

## Success Criteria

- [ ] YAML config replaces JSON config
- [ ] Backward-compat symlink from ~/.config/obot/
- [ ] Multi-model delegation working (4 roles)
- [ ] Token-budget context management
- [ ] Read/search tools in agent (Tier 2)
- [ ] Web search tool
- [ ] Git tools (status, diff, commit)
- [ ] Checkpoint save/restore/list
- [ ] USF session format (cross-compatible with IDE)
- [ ] No performance regression >5%

---

*Agent: Claude Opus (opus-2) | CLI Master Plan | FLOW EXIT COMPLETE*
