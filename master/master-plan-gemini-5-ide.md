# Master Plan: Agent gemini-5 (IDE)

**Agent:** gemini-5
**Product:** OllamaBot IDE (Swift/macOS)
**Date:** 2026-02-05
**Rounds Participated:** 0, 1, 2
**Status:** Master version

---

## Summary

Agent gemini-5 participated in all three rounds of the OllamaBot/obot harmonization analysis. This document captures the IDE-specific deliverables from the final Protocol-First consensus.

---

## Round 0: "One Brain, Two Interfaces"

- Identified configuration fragmentation: IDE uses `~/.config/ollamabot/tier.json` + UserDefaults while CLI uses `~/.config/obot/config.json`.
- Identified duplicated business logic: `ModelTierManager.swift` duplicates `obot/internal/tier`.
- Identified feature parity gaps: IDE has generic Agents but lacks CLI's Orchestration, Savings Tracking, and Memory Graph.
- Proposed `OBotCLIWrapper.swift` to interface with the `obot` binary for heavy workflows.
- Proposed `ConfigAdapter` to read `obot` config from IDE.

## Round 1: "Protocol-First Approach"

- Rejected Rust rewrite as too high-risk for March release.
- Defined three protocol pillars: UCS (config), UTS (tools), UCP (context).
- Proposed `CLIBridgeService.swift` for IDE to delegate orchestration to CLI.
- Proposed splitting `AgentExecutor.swift` (1069 lines) into `Core/`, `Tools/`, `Strategies/`.
- Proposed IDE reads shared `config.yaml` via Yams library.

## Round 2: Final Convergence

- Full convergence on Protocol-First Architecture across all 40 agents.
- 6 Master Protocols defined: UOP, UTR, UCP, UMC, UC, USF.
- 42 implementation tasks defined across 6 categories.

---

## IDE-Specific Implementation Items

### Configuration Migration
- Migrate from UserDefaults to shared `~/.config/ollamabot/config.yaml`.
- Use Yams library for YAML parsing.
- Maintain UserDefaults as UI-layer cache only.

### Architecture Refactor
- Split `AgentExecutor.swift` into 5 files: Core loop, Tool executor, Verification engine, Delegation handler, Error recovery.
- Modularize tools: `FileTools.swift`, `SystemTools.swift`, `AITools.swift`, `WebTools.swift`, `GitTools.swift`.
- Create `OrchestratorService.swift` implementing UOP state machine.
- Create `ProcessNavigator.swift` enforcing 1-2-3 navigation rules.

### New Features from CLI
- Quality presets UI (fast/balanced/thorough selector).
- Orchestration Mode UI (5-schedule visualization).
- Human consultation modal dialogs with timeout.
- Flow code tracking display (S1P123S2P12 format).
- Cost tracking integration (token cost vs commercial APIs).
- Session persistence and export/import via USF.
- Line range editing capabilities.
- Dry-run preview mode.

### CLI Bridge
- `CLIBridgeService.swift` spawns `obot` for heavy orchestration.
- WebSocket event handler for streaming results.
- Server/Local mode toggle.

### Tool Registry
- Load tool definitions from shared `tools.json`.
- Normalize tool names to UTR canonical IDs.
- Validate tool calls against UTR schema.

### Testing
- Unit test suite targeting 75% coverage.
- Integration tests with CLI via shared session format.

---

## Verified Source Files

- `~/obot/plans_0/plan-0-gemini-5.md`
- `~/obot/plans_1/plan-1-gemini-5.md`
- `~/obot/plans_2/plan-2-gemini-5.md`
