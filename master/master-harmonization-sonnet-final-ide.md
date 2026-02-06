# OllamaBot IDE — Master Harmonization Plan (sonnet-final)

**Product:** OllamaBot IDE (Swift/SwiftUI, macOS)
**Agent:** Claude Sonnet 4.5 (sonnet-final)
**Date:** 2026-02-05
**Source:** 168 agent plans across 3 consolidation rounds
**Status:** MASTER — ready for implementation plan generation

---

## 1. Codebase Snapshot

- Language: Swift 5.9, SwiftUI
- LOC: ~34,489 across 63 files, 5 modules (Agent, Models, Services, Utilities, Views)
- Test coverage: 0%
- Agent tools: 18 (read/write/edit/search/list/run_command/screenshot/delegate x3/web x2/git x3/think/complete/ask_user)
- Models: 4 (orchestrator, coder, researcher, vision)
- Context: Sophisticated token budgets, semantic compression, error learning
- Orchestration: None (infinite loop + explore mode only)
- Config: UserDefaults (non-portable)
- Sessions: In-memory only

## 2. Architecture

Protocol-first, zero shared code. Both products implement identical behavioral contracts in native languages. No Rust FFI. No CLI-as-server for v1.0 (deferred to v2.0 due to non-serializable Go closure callbacks in CLI orchestrator).

## 3. Protocols to Implement

### 3.1 UOP — Unified Orchestration Protocol
Port CLI 5-schedule x 3-process state machine to Swift. Navigation: P1->{P1,P2}, P2->{P1,P2,P3}, P3->{P2,P3,terminate}. All 5 schedules must run; Production last. Flow code tracking.

New: Sources/Orchestration/OrchestratorEngine.swift, ProcessNavigator.swift, 5 schedule files, OrchestrationView.swift

### 3.2 UTR — Unified Tool Registry
Load tools from ~/.config/ollamabot/tools.yaml. Add file.delete, git.push, core.note.

### 3.3 UCP — Unified Context Protocol
Add exportUCP/importUCP to ContextManager.swift. Store learned patterns at ~/.config/ollamabot/memory/patterns.json.

### 3.4 UMC — Unified Model Coordinator
Add RAM-tier fallback, keep_alive config, read models from shared YAML.

### 3.5 UC — Unified Configuration
Migrate to ~/.config/ollamabot/config.yaml. Retain UserDefaults for IDE-only visual prefs. Backward-compat symlink from ~/.config/obot/.

### 3.6 USF — Unified State Format
Session persistence to ~/.config/ollamabot/sessions/{id}.json. Bash restore scripts. Session browser UI.

## 4. IDE-Specific Work

### 4.1 Split AgentExecutor.swift (1,069 -> 5+ files)
Core/AgentExecutor.swift (~200 lines), ToolExecutor.swift, VerificationEngine.swift. Tools/ split into 6 files by category. Modes/ for Infinite, Explore, Orchestration executors.

### 4.2 Quality Presets
fast (single pass), balanced (plan+execute+review), thorough (plan+execute+review+revise).

### 4.3 Cost Tracking
Token usage per session, savings vs commercial APIs in status bar.

### 4.4 Human Consultation Modal
60s timeout, AI-substitute fallback, note recording.

### 4.5 Line-Range Editing
Targeted AI modifications via UI selection.

### 4.6 Dry-Run / Diff Preview
Show proposed changes before applying.

## 5. Testing

Target 75% overall. Agent execution 90%, tools 85%, context 80%, orchestration 80%, sessions 75%, UI 60%. XCTest + integration tests. CI validates schema compliance.

## 6. Phases

- Weeks 1-2: Foundation (shared config, YAML parser, protocol specs)
- Weeks 3-4: Refactoring (split AgentExecutor, modularize tools, test infra)
- Weeks 5-6: Feature parity (orchestration, quality presets, sessions, cost tracking)
- Weeks 7-8: Integration (UCP export/import, session portability, cross-product tests)
- Weeks 9-10: Polish (consultation modal, dry-run, performance, docs)

## 7. Files Summary

New (16): OrchestratorEngine, ProcessNavigator, 5 schedules, OrchestrationView, ConsultationView, SharedConfigService, SessionPersistence, CostTrackingService, QualityPresetService, ToolExecutor, VerificationEngine.
Modified (8): AgentExecutor, ContextManager, ConfigurationService, OllamaService, ChatView, SettingsView, OllamaModel, Package.swift.
Est: ~6,000 new + ~500 modified LOC.

## 8. Success Criteria

- Reads ~/.config/ollamabot/config.yaml
- Loads shared tools.yaml
- UCP context export/import
- Sessions portable to CLI
- 5-schedule orchestration functional
- Quality presets working
- AgentExecutor under 300 lines
- No file over 500 lines
- Test coverage above 75%
- All 6 protocol schemas validated
- Error codes match shared taxonomy

---
END OF IDE MASTER PLAN
