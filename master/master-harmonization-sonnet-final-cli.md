# obot CLI — Master Harmonization Plan (sonnet-final)

**Product:** obot CLI (Go 1.21, macOS/Linux)
**Agent:** Claude Sonnet 4.5 (sonnet-final)
**Date:** 2026-02-05
**Source:** 168 agent plans across 3 consolidation rounds
**Status:** MASTER — ready for implementation plan generation

---

## 1. Codebase Snapshot

- Language: Go 1.21
- LOC: ~27,114 across 61 files, 27 internal packages
- Test coverage: ~15%
- Agent tools: 12 (WRITE-ONLY: CreateFile, DeleteFile, EditFile, RenameFile, MoveFile, CopyFile, CreateDir, DeleteDir, RenameDir, MoveDir, CopyDir, RunCommand)
- Models: 1 per RAM tier
- Context: Basic file concatenation, no token budgets
- Orchestration: 5-schedule x 3-process (PARTIALLY STUBBED — sleeps/logs, no real tool execution)
- Config: JSON at ~/.config/obot/config.json
- Sessions: Bash scripts, directory-based

## 2. Architecture

Protocol-first, zero shared code. Both products implement identical behavioral contracts in native languages. No Rust FFI. CLI-as-server deferred to v2.0 (orchestrator uses Go closure-injected callbacks not serializable as JSON-RPC).

## 3. Protocols to Implement

### 3.1 UOP — Unified Orchestration Protocol
Un-stub the existing 5-schedule framework. Wire executeProcessFn to real agent tool execution. Requires agent read capability first (currently write-only).

### 3.2 UTR — Unified Tool Registry
Agent is write-only (12 mutation tools). Must add Tier 2 autonomous tools: ReadFile, SearchFiles, ListDirectory, Think, Complete, AskUser, DelegateToCoder, DelegateToResearcher, DelegateToVision, WebSearch, FetchURL, GitStatus, GitDiff, GitCommit, Note.
Load from ~/.config/ollamabot/tools.yaml. New: internal/tools/registry.go.

### 3.3 UCP — Unified Context Protocol
Port IDE ContextManager to Go (~700 LOC). Token budget allocation (task 25%, files 33%, project 16%, history 12%, memory 12%, errors 6%). Semantic compression. Error pattern learning. UCP JSON export/import.
New: internal/context/manager.go, internal/context/protocol.go.

### 3.4 UMC — Unified Model Coordinator
Replace single-model-per-tier with multi-model coordination. Intent routing (coding/research/writing/vision keywords). RAM-tier fallback for single-model mode.
New: internal/ollama/coordinator.go.

### 3.5 UC — Unified Configuration
Migrate JSON to YAML. Primary: ~/.config/ollamabot/config.yaml. Symlink: ~/.config/obot/ -> ~/.config/ollamabot/. CLI flags override config. Dep: gopkg.in/yaml.v3.

### 3.6 USF — Unified State Format
Sessions as JSON at ~/.config/ollamabot/sessions/{id}.json. Include orchestration state, flow code, steps, stats. Retain bash restoration. Add session import/export commands.

## 4. CLI-Specific Work

### 4.1 Agent Read Capability (CRITICAL)
Agent is write-only. Must add ReadFile, SearchFiles (ripgrep wrapper), ListDirectory. Prerequisite for real orchestration execution.

### 4.2 Package Consolidation (27 -> 12)
Merge: actions+agent+analyzer+oberror+recorder -> agent; config+tier+model -> config; context+summary -> context; fixer+review+quality -> fixer; obotgit -> git; session+stats -> session; ui+display+memory+ansi -> ui.

### 4.3 .obotrules Support
Parse .obotrules markdown, inject into system prompts. New: internal/config/rules.go.

### 4.4 Web Tools
WebSearch (DuckDuckGo), FetchURL (HTTP + HTML extract). New: internal/tools/web.go.

### 4.5 Git Tools
GitStatus, GitDiff, GitCommit. New: internal/tools/git.go.

### 4.6 @Mention Support
Parse @file:path and @context:id syntax in CLI input. New: internal/tools/mention.go.

## 5. Testing

Target 75% overall. Agent 90%, tools 85%, context 80%, orchestration 80%, fixer 85%, sessions 75%. Go test -race. CI validates schema compliance.

## 6. Phases

- Weeks 1-2: Foundation (YAML config, shared directory, protocol schemas)
- Weeks 3-4: Core (agent read capability, un-stub orchestration, package consolidation, context manager)
- Weeks 5-6: Features (multi-model, intent routing, web/git tools, .obotrules, @mentions, USF sessions)
- Weeks 7-8: Integration (UCP export/import, session portability, cross-product tests)
- Weeks 9-10: Polish (LLM-as-judge, benchmarks, docs)

## 7. Files Summary

New (14): context/manager.go (~700 LOC), context/protocol.go, ollama/coordinator.go, tools/registry.go, tools/web.go, tools/git.go, tools/mention.go, config/rules.go, config/migration.go, session/shared.go, session/converter.go, configs/tools.yaml, configs/session.schema.json, configs/context.schema.json.
Modified (8): agent/agent.go, config/config.go, orchestrate/orchestrator.go, fixer/engine.go, fixer/prompts.go, cli/orchestrate.go, ollama/client.go, go.mod.
Est: ~4,500 new + ~800 modified LOC.

## 8. Success Criteria

- Reads ~/.config/ollamabot/config.yaml
- Backward-compat symlink from ~/.config/obot/
- Loads shared tools.yaml
- Agent can read/search/list files
- Orchestration executes real tools (not stubbed)
- Multi-model delegation working
- Intent routing functional
- Context manager with token budgets operational
- Sessions portable to IDE
- .obotrules parsed and injected
- Web and git tools functional
- Packages reduced 27 -> 12
- Test coverage above 75%
- All 6 protocol schemas validated
- Error codes match shared taxonomy

---
END OF CLI MASTER PLAN
