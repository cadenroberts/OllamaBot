# OllamaBot IDE Master Harmonization Plan

**Agent:** sonnet-1
**Product:** OllamaBot IDE (Swift/macOS)
**Scope:** Complete harmonization strategy for the IDE side

---

## Executive Summary

OllamaBot (IDE) and obot (CLI) must function as complementary interfaces to a unified AI coding platform. This master plan covers the IDE-side harmonization: what must change in the Swift codebase, what must be adopted from the CLI, and what shared contracts the IDE must honor.

**Current State:**
- ~34,489 LOC Swift (macOS IDE)
- 63 Swift files across Agent, Models, Services, Utilities, Views
- Shared code with CLI: 0%

---

## Part 1: IDE Architecture (Current)

### Core Modules

- `Sources/OllamaBotApp.swift` -- App entry, state management
- `Sources/Agent/AgentExecutor.swift` -- Infinite Mode engine (1,069 lines, monolithic)
- `Sources/Agent/ExploreAgentExecutor.swift` -- Autonomous improvement mode
- `Sources/Agent/CycleAgentManager.swift` -- Multi-agent orchestration
- `Sources/Services/OllamaService.swift` -- Ollama API client with streaming
- `Sources/Services/ContextManager.swift` -- Token-budgeted context with semantic compression
- `Sources/Services/IntentRouter.swift` -- Keyword-based model routing
- `Sources/Services/OBotService.swift` -- .obotrules, bots, context snippets, templates
- `Sources/Services/MentionService.swift` -- @mention system (14+ types)
- `Sources/Services/CheckpointService.swift` -- Windsurf-style save/restore

### IDE Tool Set (18 tools)

```
Core:       think, complete, ask_user
Files:      read_file, write_file, edit_file, search_files, list_directory
System:     run_command, take_screenshot
Delegation: delegate_to_coder, delegate_to_researcher, delegate_to_vision
Web:        web_search, fetch_url
Git:        git_status, git_diff, git_commit
```

### IDE Strengths

1. Sophisticated ContextManager with token budget allocation (task 25%, files 33%, project 16%, history 12%, memory 12%, errors 6%)
2. Multi-model delegation (4 specialized models: Qwen3, Command-R, Qwen-Coder, Qwen-VL)
3. OBot ecosystem (.obotrules, bots, context snippets, templates)
4. @Mention system for context injection
5. Checkpoint system for code state management
6. Parallel tool execution with LRU caching
7. Streaming response visualization
8. Integrated terminal, editor, file explorer

---

## Part 2: IDE Shortcomings (What CLI Has That IDE Lacks)

| Feature | CLI Implementation | Priority |
|---------|-------------------|----------|
| Orchestration framework | 5 schedules x 3 processes with navigation rules | CRITICAL |
| Quality presets | fast/balanced/thorough pipeline | HIGH |
| Cost savings tracking | Token cost comparison vs Claude/GPT-4 | HIGH |
| Session persistence | Resume interrupted work from disk | HIGH |
| Human consultation with timeout | 60s timeout, AI fallback | MEDIUM |
| Flow code tracking | S1P123S2P12 format | MEDIUM |
| Line-range editing | -10 +25 syntax | MEDIUM |
| LLM-as-judge | Expert model review post-completion | MEDIUM |
| Dry-run mode | Preview without writing | LOW |
| Memory visualization | Live RAM usage graph | LOW |

---

## Part 3: IDE Changes Required for Harmonization

### 3.1 Shared Configuration System

**Current:** SwiftUI AppStorage + UserDefaults (not portable)
**Target:** Read/write `~/.ollamabot/config.yaml`

New file: `Sources/Services/SharedConfigService.swift`
- Read same YAML config that CLI reads
- Sync changes bidirectionally
- Honor CLI flags when launched from terminal

### 3.2 Orchestration Framework Port

**Current:** Simple agent executor loop until complete tool
**Target:** 5-schedule orchestration matching CLI behavior

New file: `Sources/Services/OrchestrationService.swift`
- Schedule enum: knowledge, plan, implement, scale, production
- Process enum: p1, p2, p3
- Navigation rules: P1->{P1,P2}, P2->{P1,P2,P3}, P3->{P2,P3,terminate}
- Flow code generation: S1P123S2P12...

### 3.3 Tool Registry Unification

**Current:** 18 hardcoded tools in AgentTools.swift
**Target:** Load from shared tool registry YAML

Add missing tools from CLI:
- file.delete (delete_file)
- file.create_dir (create_dir)
- file.delete_dir (delete_dir)
- file.rename (rename)
- file.move (move)
- file.copy (copy)
- git.push (git_push)
- core.note (note)

### 3.4 Quality Presets

New integration in agent settings:
- fast: Single pass, no plan or review
- balanced: Plan + execute + review
- thorough: Plan + execute + review + revise loop

### 3.5 Cost Tracking

New file: `Sources/Services/CostTrackingService.swift`
- Track total tokens used
- Calculate savings vs Claude Opus ($0.015/$0.075), Sonnet ($0.003/$0.015), GPT-4o ($0.005/$0.015)

### 3.6 Session Persistence

New file: `Sources/Services/SharedSessionService.swift`
- Save/load sessions to ~/.ollamabot/sessions/
- Cross-platform format compatible with CLI
- Export to CLI format for session handoff

### 3.7 Human Consultation Framework

New file: `Sources/Services/ConsultationService.swift`
- 60s timeout with countdown
- AI substitute fallback
- Optional vs mandatory consultation types

### 3.8 AgentExecutor Refactoring

Split 1,069-line monolithic file into:
- Agent/Core/AgentExecutor.swift (~200 lines, loop only)
- Agent/Core/ToolExecutor.swift (~150 lines, dispatch)
- Agent/Core/VerificationEngine.swift (~100 lines)
- Agent/Tools/FileTools.swift
- Agent/Tools/SystemTools.swift
- Agent/Tools/AITools.swift
- Agent/Tools/WebTools.swift
- Agent/Tools/GitTools.swift

---

## Part 4: Shared Contracts IDE Must Honor

### 4.1 Unified Config at ~/.ollamabot/config.yaml
### 4.2 Shared Session Schema (JSON, cross-platform)
### 4.3 Shared Prompt Templates at ~/.ollamabot/prompts/
### 4.4 .obotrules parsing in project root

---

## Part 5: Implementation Phases (IDE Side)

### Phase 1: Foundation (Weeks 1-2)
- SharedConfigService -- Read shared YAML config
- Shared prompt loader -- Load YAML templates
- Tool registry -- Load from shared tools.yaml

### Phase 2: Feature Parity (Weeks 3-5)
- OrchestrationService -- 5-schedule framework
- CostTrackingService -- Savings tracker
- Quality presets -- fast/balanced/thorough
- ConsultationService -- Timeout-based human-in-loop

### Phase 3: Architecture (Weeks 5-7)
- AgentExecutor split into focused modules
- SharedSessionService -- Cross-platform sessions
- Test suite (target: 75% coverage)

### Phase 4: Polish (Weeks 7-8)
- OrchestrationView -- Schedule/process UI
- Session handoff UI
- Migration tool for existing UserDefaults

---

## Part 6: Success Criteria (IDE)

- IDE reads ~/.ollamabot/config.yaml
- IDE reads shared prompt templates
- IDE implements 5-schedule orchestration with navigation rules
- IDE sessions exportable to CLI format
- IDE has quality presets (fast/balanced/thorough)
- IDE has cost tracking
- IDE has human consultation with timeout
- AgentExecutor split into <300 line files
- 75% test coverage on agent and services
- All 22 unified tools available
- No regression in startup time or streaming performance

---

END OF IDE MASTER PLAN
