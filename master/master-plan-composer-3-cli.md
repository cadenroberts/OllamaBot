# obot CLI Definitive Master Plan

**Agent:** Composer-3 (Claude Opus)
**Round:** 2 (Final Consolidation from 73 plans across Rounds 0-1)
**Generated:** 2026-02-05
**Scope:** obot CLI harmonization strategy

---

## Executive Summary

This is the final consolidated master plan for the obot CLI (Go), synthesizing 73 plans from 5+ agent families across 2 rounds of iterative refinement. Every decision below represents cross-agent consensus.

**Critical Stats:**
- ollamabot IDE: ~34,489 LOC Swift (63 files, 5 modules)
- obot CLI: ~27,114 LOC Go (61 files, 27 packages)
- Shared code: 0% (CRITICAL)
- Divergences identified: 37
- Tools to unify: 25
- Implementation timeline: 8 weeks across 4 phases

**Architecture Decision (unanimous):** "One Brain, Two Interfaces"
- `obot` CLI = execution engine (orchestration, context, tools)
- `ollamabot` IDE = visualization & control layer (UI, UX, OS integration)
- Shared specifications (NOT shared code) ensure behavioral consistency

---

## Part 1: Architecture

### 1.1 Execution Model

```
USER
  |
  +-- ollamabot IDE (Swift/SwiftUI)
  |     |-- UI Layer (views, panels, themes)
  |     |-- State Management (@Observable)
  |     |-- OS Integration (macOS, Accessibility)
  |     |-- CLIBridge (calls obot binary OR native execution)
  |     |
  |     +-- Shared Config (~/.ollamabot/config.yaml)
  |
  +-- obot CLI (Go/Cobra)
        |-- Terminal Interface (TUI, ANSI, flags)
        |-- Execution Engine (orchestration, agent, tools)
        |-- Server Mode (--server --json for IDE consumption)
        |
        +-- Shared Config (~/.ollamabot/config.yaml)
```

**Implementation Modes:**
1. **Standalone CLI**: `obot fix main.go "add error handling"` -- runs independently
2. **Standalone IDE**: ollamabot runs its own Swift-native agent executors
3. **Hybrid**: IDE delegates heavy orchestration to CLI via `obot orchestrate --json`
4. **Server**: `obot --server --port 9111` exposes REST API for IDE

### 1.2 Agent Architecture Standard

CLI already implements the correct separation:
- `internal/orchestrate/` = DecisionEngine (Orchestrator)
- `internal/agent/` = ExecutionEngine (Agent)

---

## Part 2: Unified Configuration

### 2.1 Config Location & Structure

**Location:** `~/.ollamabot/` (consensus)

```yaml
# ~/.ollamabot/config.yaml
version: "2.0"

platform:
  os: macos
  arch: arm64
  ram_gb: 32
  detected_tier: performance

models:
  orchestrator:
    default: qwen3:32b
    alternatives: [qwen3:14b, qwen3:8b]
    keep_alive: 30m
  coder:
    default: qwen2.5-coder:32b
    tier_mapping:
      minimal: deepseek-coder:1.3b      # 8GB
      compact: deepseek-coder:6.7b      # 16GB
      balanced: qwen2.5-coder:14b       # 24GB
      performance: qwen2.5-coder:32b    # 32GB
      advanced: deepseek-coder:33b      # 64GB+
  researcher:
    default: command-r:35b
    fallback: qwen3:32b
  vision:
    default: qwen3-vl:32b
    fallback: llava:13b
  intent_routing:
    coding: [implement, fix, refactor, optimize, debug, test]
    research: [what is, explain, compare, analyze, research]
    writing: [write, document, summarize, describe]
    vision: [image, screenshot, visual, UI, diagram]

ollama:
  url: http://localhost:11434
  timeout_seconds: 120

agent:
  max_steps: 50
  allow_terminal: true
  allow_file_writes: true
  confirm_destructive: true
  parallel_tool_execution: true

quality:
  fast:
    iterations: 1
    verification: none
  balanced:
    iterations: 2
    verification: llm_review
  thorough:
    iterations: 3
    verification: expert_judge

context:
  max_tokens: 32768
  budget_allocation:
    task: 0.25
    files: 0.33
    project: 0.16
    history: 0.12
    memory: 0.12
    errors: 0.06
  compression_enabled: true
  memory_enabled: true
  error_learning_enabled: true

orchestration:
  default_schedules: [knowledge, plan, implement]
  human_consultation_timeout: 60
  enable_llm_judge: true
  session_persistence: true
  flow_code_tracking: true

ide:
  theme: dark
  editor_font_size: 14
  show_token_usage: true
  font_family: SF Mono
  tab_size: 2
  word_wrap: true

cli:
  verbose: true
  mem_graph: true
  color_output: true
  no_summary: false
```

### 2.2 CLI Config Implementation

```go
// internal/config/shared.go
type SharedConfig struct {
    Version       string         `yaml:"version"`
    Platform      PlatformConfig `yaml:"platform"`
    Models        ModelsConfig   `yaml:"models"`
    Ollama        OllamaConfig   `yaml:"ollama"`
    Agent         AgentConfig    `yaml:"agent"`
    Quality       QualityConfig  `yaml:"quality"`
    Context       ContextConfig  `yaml:"context"`
    Orchestration OrchConfig     `yaml:"orchestration"`
    CLI           CLIConfig      `yaml:"cli"`
}

func LoadSharedConfig() (*SharedConfig, error) {
    path := filepath.Join(os.Getenv("HOME"), ".ollamabot", "config.yaml")
    data, err := os.ReadFile(path)
    if err != nil { return DefaultConfig(), nil }
    var cfg SharedConfig
    return &cfg, yaml.Unmarshal(data, &cfg)
}
```

---

## Part 3: Unified Tool Registry

### 3.1 Tool Inventory (25 tools)

| ID | Name | Platforms | Status |
|----|------|-----------|--------|
| **Core** |
| core.think | think | both | done |
| core.complete | complete | both | done |
| core.ask | ask_user | both | done |
| **File** |
| file.read | read_file | both | done |
| file.write | write_file | both | done |
| file.edit | edit_file | both | done |
| file.delete | delete_file | cli only | IDE: pending |
| file.search | search_files | ide only | CLI: pending |
| file.list | list_directory | both | done |
| file.move | move_file | cli only | IDE: pending |
| **System** |
| system.execute | run_command | both | done |
| system.screenshot | take_screenshot | ide only | -- |
| **Delegation** |
| ai.coder | delegate_to_coder | ide only | CLI: pending |
| ai.researcher | delegate_to_researcher | ide only | CLI: pending |
| ai.vision | delegate_to_vision | ide only | CLI: pending |
| **Web** |
| web.search | web_search | ide only | CLI: pending |
| web.fetch | fetch_url | ide only | CLI: pending |
| **Git** |
| git.status | git_status | both | done |
| git.diff | git_diff | both | done |
| git.commit | git_commit | both | done |
| git.push | git_push | cli only | IDE: pending |
| git.create_repo | git_create_repo | cli only | -- |
| **Session** |
| session.checkpoint_save | checkpoint_save | ide only | CLI: pending |
| session.checkpoint_restore | checkpoint_restore | ide only | CLI: pending |
| session.checkpoint_list | checkpoint_list | ide only | CLI: pending |

### 3.2 Tool Schema

```yaml
# ~/.ollamabot/tools.yaml
version: "1.0.0"
tools:
  - id: file.read
    aliases: [read_file, ReadFile]
    description: Read file contents
    platforms: [ide, cli]
    parallelizable: true
    cacheable: true
    parameters:
      - name: path
        type: string
        required: true
  - id: file.write
    aliases: [write_file, WriteFile, CreateFile]
    description: Create or overwrite file
    platforms: [ide, cli]
    parallelizable: false
    cacheable: false
    parameters:
      - name: path
        type: string
        required: true
      - name: content
        type: string
        required: true
```

---

## Part 4: Orchestration Framework

### 4.1 Master Protocol (5-Schedule Framework)

CLI already implements this as the canonical orchestration protocol:

```
Schedule 1: Knowledge
  P1: Research    -- gather information
  P2: Crawl       -- explore codebase/web
  P3: Retrieve    -- extract relevant data

Schedule 2: Plan
  P1: Brainstorm  -- generate approaches
  P2: Clarify*    -- resolve ambiguities (* human consultation optional)
  P3: Plan        -- create execution plan

Schedule 3: Implement
  P1: Implement   -- execute changes
  P2: Verify      -- test and validate
  P3: Feedback**  -- collect feedback (** human consultation mandatory)

Schedule 4: Scale
  P1: Scale       -- expand implementation
  P2: Benchmark   -- measure performance
  P3: Optimize    -- improve performance

Schedule 5: Production
  P1: Analyze     -- final analysis
  P2: Systemize   -- ensure consistency
  P3: Harmonize   -- polish and finalize
```

**Navigation Rules:**
- P1 -> {P1, P2}
- P2 -> {P1, P2, P3}
- P3 -> {P2, P3, terminate}

**Termination:**
- All 5 schedules must run at least once
- Production must be last terminated
- Flow code tracking: `S{n}P{n}` format (e.g., `S1P123S2P12`)

Already implemented in `internal/orchestrate/`.

---

## Part 5: Context Management Protocol

### 5.1 Token Budget Allocation

```
task:     25% -- task description, instructions
files:    33% -- file contents (selected, open, relevant)
project:  16% -- project structure, config files
history:  12% -- conversation history, recent steps
memory:   12% -- learned patterns, error warnings
errors:    6% -- error patterns, recurring issues
```

### 5.2 Unified Context Protocol (UCP)

```json
{
  "version": "1.0.0",
  "context_id": "uuid",
  "type": "orchestrator|delegation",
  "task": {
    "original": "Full task description",
    "compressed": "Abbreviated version",
    "intent": "coding|research|writing|vision"
  },
  "workspace": {
    "path": "/absolute/path",
    "language": "Go",
    "file_count": 61
  },
  "budget": {
    "total": 32768,
    "allocations": {
      "task": 8192,
      "files": 10813,
      "project": 5242,
      "history": 3932,
      "memory": 3932,
      "errors": 1966
    }
  }
}
```

### 5.3 CLI Implementation

**New:** `internal/context/manager.go`
- Port IDE's ContextManager token budget algorithm
- Implement semantic compression
- Add error pattern learning
- Shared learned_patterns.json at `~/.ollamabot/memory/learned_patterns.json`

---

## Part 6: OBot System Integration

### 6.1 Port to CLI

**New package:** `internal/obot/`

```
internal/obot/
+-- rules.go      -- .obotrules parser
+-- bots.go       -- .obot/bots/ YAML parser + executor
+-- context.go    -- .obot/context/ snippet loader
+-- templates.go  -- .obot/templates/ template engine
+-- scaffold.go   -- `obot init` scaffolding
```

**New CLI commands:**
- `obot init` -- scaffold .obot/ directory
- `obot bot <name>` -- execute a bot
- `obot bot list` -- list available bots

### 6.2 Shared OBot Directory

```
project/
+-- .obotrules              # AI rules (both products read this)
+-- .obot/
    +-- config.json         # OBot configuration
    +-- bots/               # YAML bot definitions
    +-- context/            # Reusable context snippets
    +-- templates/          # Code generation templates
    +-- history/            # Execution history
```

---

## Part 7: Session Management

### 7.1 Unified Session Format

```json
{
  "$schema": "https://ollamabot.dev/session.schema.json",
  "version": "2.0",
  "id": "abc123",
  "source": "cli|ide",
  "prompt": "Build a REST API",
  "created": "2026-02-05T03:00:00Z",
  "modified": "2026-02-05T03:30:00Z",
  "status": "active|completed|suspended",
  "orchestration": {
    "flow_code": "S1P123S2P12S3P1",
    "current_schedule": 3,
    "current_process": 1
  },
  "steps": [],
  "checkpoints": [],
  "stats": {
    "tokens_used": 45000,
    "files_created": 12,
    "files_modified": 8,
    "commands_run": 15,
    "cost_savings": { "claude_opus": 3.84, "gpt4o": 1.02 }
  }
}
```

### 7.2 CLI Session Commands

- `obot session list` -- list all sessions
- `obot session resume <id>` -- resume session
- `obot session export <id>` -- export session
- Bash-only restore scripts generated alongside JSON

---

## Part 8: CLI Feature Additions (10 items from IDE)

| Feature | Priority | Effort | Implementation |
|---------|----------|--------|----------------|
| Multi-Model Delegation | CRITICAL | 3 days | internal/delegation/ |
| OBot System | CRITICAL | 3 days | internal/obot/ |
| Context Management | CRITICAL | 3 days | internal/context/manager.go |
| Checkpoint System | HIGH | 2 days | internal/checkpoint/ |
| @Mention System | HIGH | 2 days | internal/mention/ |
| Web Search | MEDIUM | 1 day | internal/web/ |
| URL Fetching | MEDIUM | 1 day | internal/web/fetch.go |
| search_files Tool | MEDIUM | 1 day | internal/agent/tools.go |
| Vision Support | MEDIUM | 2 days | internal/vision/ |
| Chat Mode | LOW | 2 days | `obot chat` command |

---

## Part 9: Implementation Phases

### Phase 1: Configuration & Foundations (Week 1-2)
1. Migrate from `~/.config/obot/config.json` to `~/.ollamabot/config.yaml`
2. Implement SharedConfig YAML loader
3. Add config file watcher (hot-reload)
4. Implement tool registry from tools.yaml

### Phase 2: Core Feature Alignment (Week 3-4)
1. Port ContextManager to CLI (internal/context/manager.go)
2. Implement OBot system (internal/obot/)
3. Add multi-model delegation support
4. Implement checkpoint system

### Phase 3: Feature Parity (Week 5-6)
1. Add @mention system
2. Add web search/fetch
3. Implement unified session format
4. Add search_files tool
5. Create tool compatibility tests

### Phase 4: Polish & Testing (Week 7-8)
1. Behavioral equivalence test suite
2. Integration tests (CLI + IDE interaction)
3. Performance benchmarking
4. Documentation unification

---

## Part 10: Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Feature Parity | 90%+ | Feature matrix comparison |
| Config Sync | 100% | Both read same config.yaml |
| Session Compat | 100% | Sessions work in both products |
| Tool Parity | 22/25 | Tools implemented in both |
| Test Coverage | 50%+ | Shared test suite |
| User Experience | Consistent | User feedback |

---

## Part 11: Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Specification drift | Version all specs, automated compliance tests |
| Performance degradation | Benchmark before/after, profile critical paths |
| User disruption | Backward compat, migration tools, gradual rollout |
| Implementation complexity | Incremental phases, clear boundaries, regular reviews |
| March deadline pressure | Phase 1-2 are critical path, Phase 3-4 can be deferred |
