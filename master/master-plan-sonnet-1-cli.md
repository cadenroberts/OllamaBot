# obot CLI Master Harmonization Plan

**Agent:** sonnet-1
**Product:** obot CLI (Go)
**Scope:** Complete harmonization strategy for the CLI side

---

## Executive Summary

obot (CLI) and OllamaBot (IDE) must function as complementary interfaces to a unified AI coding platform. This master plan covers the CLI-side harmonization: what must change in the Go codebase, what must be adopted from the IDE, and what shared contracts the CLI must honor.

**Current State:**
- ~27,114 LOC Go (CLI tool)
- 61 Go files across 27 internal packages
- Shared code with IDE: 0%

---

## Part 1: CLI Architecture (Current)

### Core Packages

- `cmd/obot/main.go` -- Entry point
- `internal/cli/` -- Command interface (root, fix, orchestrate, plan, review, session, stats, interactive, version, theme, fs)
- `internal/fixer/` -- Code fix engine (engine, prompts, extract, diff, quality, agent, agent_prompts)
- `internal/agent/` -- Action execution (agent, types, recorder)
- `internal/orchestrate/` -- 5-schedule framework (orchestrator, navigator, types, flowcode)
- `internal/ollama/` -- Model client (client, models, stream)
- `internal/ui/` -- Terminal display (app, display, memory, ansi)
- `internal/config/` -- JSON configuration
- `internal/context/` -- Lightweight summarization
- `internal/consultation/` -- Human-in-loop handler
- `internal/session/` -- Session persistence
- `internal/tier/` -- RAM-based model selection
- `internal/stats/` -- Savings tracking

### CLI Action Set (12 actions)

```
create_file, delete_file, edit_file, create_dir, delete_dir,
rename_file, rename_dir, move_file, move_dir, copy_file,
copy_dir, run_command
```

### CLI Strengths

1. Formal 5-schedule orchestration framework (Knowledge, Plan, Implement, Scale, Production)
2. Strict navigation rules (P1->{P1,P2}, P2->{P1,P2,P3}, P3->{P2,P3,terminate})
3. Human consultation with 60s timeout and AI fallback
4. Flow code tracking (S1P123S2P12)
5. Session persistence with bash-only restoration
6. Quality presets (fast/balanced/thorough)
7. Cost savings tracker vs commercial APIs
8. LLM-as-judge analysis
9. RAM-based model tier detection (5 tiers: 8GB to 64GB+)
10. Line-range editing (-10 +25)

---

## Part 2: CLI Shortcomings (What IDE Has That CLI Lacks)

| Feature | IDE Implementation | Priority |
|---------|-------------------|----------|
| Multi-model delegation | 4 specialist models (orchestrator, coder, researcher, vision) | CRITICAL |
| Context management | Token-budgeted with semantic compression, memory, error learning | CRITICAL |
| @Mention system | 14+ types (@file, @codebase, @web, @bot, etc.) | HIGH |
| Intent routing | Auto-select model based on task keywords | HIGH |
| Web search tools | DuckDuckGo search, URL fetch | HIGH |
| Git tools | git_status, git_diff, git_commit as agent tools | HIGH |
| Think tool | Explicit reasoning step for planning | MEDIUM |
| Checkpoint system | Save/restore code states | MEDIUM |
| .obotrules support | Project-wide AI rules | MEDIUM |
| Custom bots | YAML-based multi-step workflows | LOW |

---

## Part 3: CLI Changes Required for Harmonization

### 3.1 Shared Configuration System

**Current:** ~/.config/obot/config.json (JSON, CLI-only)
**Target:** Read/write ~/.ollamabot/config.yaml

New file: `internal/obotconfig/loader.go`
- Load shared config from ~/.ollamabot/config.yaml
- Load project config from .obot/config.yaml
- Merge with precedence: CLI flags > project > global
- Migration: First run auto-migrates existing JSON config

### 3.2 Multi-Model Delegation

**Current:** Single model per RAM tier
**Target:** Multi-model coordinator matching IDE 4-model orchestration

Enhanced: `internal/model/coordinator.go`
- DelegateToCoder(task, files) for coding tasks
- DelegateToResearcher(query) for research tasks
- DelegateToVision(task, imagePath) for vision tasks
- Route(intent) for auto-routing
- Fallback: If only one model available, use tier-based single model

### 3.3 Context Management Port

**Current:** Basic prompt string concatenation
**Target:** Token-budgeted context management matching IDE

New file: `internal/context/manager.go`
- Token budget allocation (task 25%, files 33%, project 16%, history 12%, memory 12%, errors 6%)
- Semantic compression for over-budget contexts
- Error pattern tracking with warnings
- Memory store for relevant past interactions

### 3.4 Tool Expansion

Add missing tools from IDE:
- Think (explicit reasoning step)
- AskUser (request user input)
- SearchFiles (search text across codebase)
- ListDirectory (list directory contents)
- WebSearch (DuckDuckGo search)
- FetchURL (fetch web page content)
- GitStatus, GitDiff, GitCommit, GitPush (as agent tools)

### 3.5 .obotrules Parser

New file: `internal/obotrules/parser.go`
- Parse .obotrules markdown format in project root
- Extract project description, code style, patterns
- Inject into system prompts

### 3.6 @Mention System for CLI

New file: `internal/mention/parser.go`
- @file:path -- Include file content
- @context:id -- Include context snippet from .obot/context/
- @codebase -- Include project structure summary
- @selection -- Include piped stdin content

CLI usage: obot fix main.go "@context:style-guide add documentation"

### 3.7 Intent Routing

New file: `internal/router/intent.go`
- Classify intent from message keywords (coding, research, writing, vision)
- Select appropriate model from coordinator
- Override with explicit --model flag

### 3.8 Package Consolidation

Reduce from 27 to 12 packages:
- actions -> merge into agent
- analyzer -> merge into fixer
- oberror -> use stdlib errors
- model -> merge into ollama
- resource -> merge into monitor
- stats -> merge into session
- summary -> merge into context
- tier -> merge into config

---

## Part 4: Shared Contracts CLI Must Honor

### 4.1 Unified Config at ~/.ollamabot/config.yaml
### 4.2 Shared Session Schema (JSON, cross-platform)
### 4.3 Shared Prompt Templates at ~/.ollamabot/prompts/
### 4.4 .obotrules parsing in project root

---

## Part 5: Implementation Phases (CLI Side)

### Phase 1: Foundation (Weeks 1-2)
- obotconfig/loader.go -- Read shared YAML config
- Config migration tool -- Migrate existing JSON
- obotrules/parser.go -- Parse .obotrules files
- Shared prompt loader -- Load YAML templates

### Phase 2: Core Enhancements (Weeks 3-5)
- context/manager.go -- Token-budgeted context
- model/coordinator.go -- Multi-model delegation
- router/intent.go -- Intent-based model routing
- agent/tools.go -- Add 10 missing tools

### Phase 3: Integration (Weeks 5-7)
- mention/parser.go -- @mention system
- session/shared.go -- Cross-platform session format
- Package consolidation (27 -> 12)
- Test suite (target: 75% coverage)

### Phase 4: Polish (Weeks 7-8)
- New commands: obot chat, obot explore, obot checkpoint
- Session import/export: obot session import ide-session.json
- Performance validation
- Migration documentation

---

## Part 6: Success Criteria (CLI)

- CLI reads ~/.ollamabot/config.yaml
- CLI reads shared prompt templates
- CLI parses .obotrules and injects into prompts
- CLI supports multi-model delegation (opt-in)
- CLI has token-budgeted context management
- CLI has intent-based model routing
- CLI has @mention syntax for context injection
- CLI sessions exportable to IDE format
- Packages reduced from 27 to 12
- All 22 unified tools available in agent
- 75% test coverage on agent and fixer
- No regression in CLI startup time (<50ms)
- No regression in single-file fix performance

---

END OF CLI MASTER PLAN
