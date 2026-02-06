# Master Plan: Agent gemini-5 (CLI)

**Agent:** gemini-5
**Product:** obot CLI (Go)
**Date:** 2026-02-05
**Rounds Participated:** 0, 1, 2
**Status:** Master version

---

## Summary

Agent gemini-5 participated in all three rounds of the OllamaBot/obot harmonization analysis. This document captures the CLI-specific deliverables from the final Protocol-First consensus.

---

## Round 0: "One Brain, Two Interfaces"

- Identified CLI as having stronger capabilities: Orchestration (5 schedules), Savings Tracking, Memory Graph.
- Proposed CLI as the canonical "Agent Runtime" that IDE delegates to.
- Proposed treating `obot/internal/tier` as the single source of truth for model tier logic.
- Proposed unified configuration at `~/.config/obot/`.

## Round 1: "Protocol-First Approach"

- Rejected Rust rewrite as too high-risk for March release.
- Defined three protocol pillars: UCS (config), UTS (tools), UCP (context).
- Proposed reducing 27 Go packages to 12 via merges.
- Proposed new `internal/intent` package (port of Swift IntentRouter).
- Proposed new `internal/tools` package (UTS Registry implementation).
- Proposed CLI adopt `IntentRouter` logic for intelligent model routing.

## Round 2: Final Convergence

- Full convergence on Protocol-First Architecture across all 40 agents.
- 6 Master Protocols defined: UOP, UTR, UCP, UMC, UC, USF.
- 42 implementation tasks defined across 6 categories.

---

## CLI-Specific Implementation Items

### Package Consolidation (27 to 12)
- Merge `internal/actions` + `internal/fixer` into `internal/agent`.
- Merge `internal/summary` + `internal/resource` into `internal/context`.
- Merge `internal/stats` into `internal/session`.
- Merge `internal/tier` into `internal/config`.
- Merge `internal/model` into `internal/ollama`.
- Keep: `agent`, `cli`, `config`, `consultation`, `context`, `fixer`, `git`, `judge`, `ollama`, `orchestrate`, `session`, `ui`.

### Configuration Migration
- Migrate from `~/.config/obot/config.json` to shared `~/.config/ollamabot/config.yaml`.
- Use `gopkg.in/yaml.v3` for YAML parsing.
- Maintain backward compatibility with JSON config during transition.

### Context Manager (Port from IDE)
- Create `internal/context/manager.go` with token budget allocation.
- Implement semantic compression above threshold.
- Implement inter-agent context passing.
- Implement error pattern tracking with warnings.
- Token budget: system 15%, files 35%, project 16%, history 12%, memory 12%, errors 6%.

### Intent-Based Routing
- Create `internal/intent/router.go` porting IDE's IntentRouter.
- Classify user input into: coding, research, writing, vision.
- Route to appropriate model based on intent + tier.

### Multi-Model Coordinator
- Enhance `internal/ollama/coordinator.go` for 4-model orchestration.
- Support orchestrator, coder, researcher, vision model roles.
- Implement model warmup management.

### New Tools (Missing from CLI)
- `web.search`: DuckDuckGo API integration.
- `web.fetch`: URL content extraction.
- `ai.delegate.coder`: Spawn sub-agent with coder model.
- `ai.delegate.researcher`: Spawn sub-agent with researcher model.
- `ai.delegate.vision`: Spawn sub-agent with vision model.
- `file.search`: Ripgrep integration for codebase search.
- `file.list`: Directory listing tool.
- `git.push`: Push commits to remote.

### Tool Registry
- Create `internal/tools/registry.go` loading shared `tools.json`.
- Normalize existing actions to UTR canonical IDs.
- Validate tool calls against UTR schema.

### Server Mode
- Implement `obot serve` command with JSON-RPC over stdio.
- Agent execute API endpoint.
- Orchestration API endpoints.
- Context and session API endpoints.
- WebSocket streaming for real-time updates.

### OBot Integration
- Parse `.obotrules` markdown format.
- Support `@file`, `@context`, `@bot` mention syntax.
- Inject project rules into system prompts.

### Session Management
- Implement USF-compliant session save/load.
- Enable cross-product session portability.
- Session export as bash restore script.

### Testing
- Unit test suite targeting 75% coverage.
- Integration tests with IDE via shared session format.
- CI/CD pipeline setup.

---

## Verified Source Files

- `~/obot/plans_0/plan-0-gemini-5.md`
- `~/obot/plans_1/plan-1-gemini-5.md`
- `~/obot/plans_2/plan-2-gemini-5.md`
