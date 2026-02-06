# Master Plan: sonnet-1 — CLI (obot)

**Agent:** sonnet-1  
**Scope:** obot CLI (Go)  
**Date:** 2026-02-05  
**Recovery:** 2026-02-06

---

## CLI Harmonization Requirements

### Protocol Compliance

The CLI must implement or validate against all 6 Unified Protocols:

1. **Agent Execution Protocol (AEP)** — Update agent step recording to use standardized types (thinking, tool, user_input, error, complete) with JSON Schema validation
2. **Orchestration Protocol (OP)** — Already implements 5-schedule framework; validate against shared schema, expose flow code in session format
3. **Context Management Protocol (CMP)** — Port IDE ContextManager.swift algorithms to internal/context/manager.go with token budgeting (task 25%, files 33%, project 16%, history 12%, memory 12%, errors 6%)
4. **Tool Registry Specification (TRS)** — Load 22 standardized tools from shared registry YAML; add 10 missing tools (delegation, web, git, think, screenshot)
5. **Configuration Schema (CS)** — Migrate from ~/.config/obot/config.json to unified ~/.ollamabot/config.yaml
6. **Session Format (SF)** — Save sessions in unified JSON format enabling IDE resume

---

### CLI-Specific Enhancements Required

#### From IDE (Features CLI Lacks)
- Multi-model coordinator (4 specialized models with delegation)
- Intent-based routing (auto-detect which model to use)
- Context manager with token budgeting, semantic compression, memory, error learning
- OBot integration (.obotrules loading, bot execution)
- @Mention resolution in prompts
- Web search and fetch tools
- Vision model integration
- Checkpoint creation and restore
- Infinite mode (autonomous execution like IDE)

#### CLI Architecture Changes
- Create internal/context/manager.go (port from Swift, ~400 lines)
- Create internal/model/delegation.go for multi-model delegation
- Create internal/model/intent.go for intent-based routing
- Create internal/tools/registry.go to load shared tool definitions
- Create internal/config/loader.go for unified YAML config
- Create internal/session/format.go for unified session persistence
- Create internal/server/server.go for HTTP API server mode
- Enhance internal/model/coordinator.go with 4-model support

---

### Current CLI State (Verified)

**Source files:** 61 Go files across internal/cli, internal/fixer, internal/agent, internal/orchestrate, internal/ollama, internal/ui, and 20+ other packages

**Existing strengths (carry forward):**
- 5-schedule orchestration framework (Knowledge, Plan, Implement, Scale, Production)
- 1-2-3 process navigation with strict rules
- Human consultation with AI fallback (60-second timeout)
- Flow code tracking (S1P123S2P12 format)
- Quality presets (fast/balanced/thorough)
- Session persistence with bash-only restoration
- Cost savings tracker vs commercial APIs
- Line-range editing (-start +end)
- Interactive multi-turn mode
- Diff modes (--diff, --dry-run, --print)
- RAM-based model tier detection (5 tiers)

**Existing gaps (must address):**
- Basic context management (simple text concatenation, no token budgeting)
- Single-model execution only (no multi-model delegation)
- No intent routing
- No OBot rules support
- No @mention system
- No web search or fetch tools
- No vision model support
- No checkpoint system
- Limited test coverage (2 test files)
- No integration tests
- No graceful shutdown
- Prompts scattered across files (no versioning)

---

### Implementation Priority

| Priority | Item | Effort |
|----------|------|--------|
| P0 | Context manager port from Swift | Large |
| P0 | Multi-model coordinator | Medium |
| P0 | Configuration loader (YAML) | Small |
| P0 | Tool registry loader | Small |
| P0 | HTTP server infrastructure | Medium |
| P1 | Intent-based routing | Small |
| P1 | OBot integration (.obotrules) | Medium |
| P1 | Web tools (search, fetch) | Small |
| P1 | AI delegation tools | Medium |
| P1 | Session format (unified) | Medium |
| P2 | Vision model support | Small |
| P2 | Git push tool | Small |

---

### Recovery Metadata

- Agent: sonnet-1
- This file: new creation per recovery mandate
- Content: verifiable CLI state and requirements derived from Round 0-1 analysis
- No patches to existing files
