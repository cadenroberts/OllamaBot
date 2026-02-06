# Master Plan: sonnet-1 — IDE (OllamaBot)

**Agent:** sonnet-1  
**Scope:** OllamaBot IDE (Swift/SwiftUI)  
**Date:** 2026-02-05  
**Recovery:** 2026-02-06

---

## IDE Harmonization Requirements

### Protocol Compliance

The IDE must implement or validate against all 6 Unified Protocols:

1. **Agent Execution Protocol (AEP)** — Standardize agent step types (thinking, tool, user_input, error, complete) with JSON Schema validation
2. **Orchestration Protocol (OP)** — Add 5-schedule structured mode (Knowledge, Plan, Implement, Scale, Production) with 1-2-3 process navigation alongside existing Infinite Mode
3. **Context Management Protocol (CMP)** — Current ContextManager.swift already implements token budgeting; validate compliance with shared spec (task 25%, files 33%, project 16%, history 12%, memory 12%, errors 6%)
4. **Tool Registry Specification (TRS)** — Load 22 standardized tools from shared registry YAML; normalize existing 18 tools to canonical IDs
5. **Configuration Schema (CS)** — Migrate from UserDefaults + tier.json to unified ~/.ollamabot/config.yaml
6. **Session Format (SF)** — Save sessions in unified JSON format enabling CLI resume

---

### IDE-Specific Enhancements Required

#### From CLI (Features IDE Lacks)
- Quality presets UI (fast/balanced/thorough selector)
- Cost savings tracker (token cost comparison vs commercial APIs)
- Structured orchestration mode (5 schedules, flow code tracking, human consultation with timeout)
- Line-range targeting for code fixes
- Dry-run preview mode
- Session export to CLI-compatible format

#### IDE Architecture Changes
- Split AgentExecutor.swift (1069 lines) into modular components
- Create OrchestrationService.swift for 5-schedule state machine
- Create SharedConfigService.swift to read unified YAML config
- Create ToolRegistryService.swift to load shared tool definitions
- Create CLIBridgeService.swift for optional CLI server communication
- Create UnifiedSessionService.swift for cross-product session persistence

---

### Current IDE State (Verified)

**Source files:** 63 Swift files across Sources/Agent, Sources/Services, Sources/Views, Sources/Models, Sources/Utilities

**Existing strengths (carry forward):**
- Multi-model orchestration (4 specialized models: Qwen3, Qwen2.5-Coder, Command-R, Qwen3-VL)
- Sophisticated ContextManager with token budgeting and semantic compression
- OBot system (.obotrules, custom bots, context snippets, templates)
- @Mention system (14+ mention types)
- Checkpoint system (Windsurf-style save/restore)
- Composer for multi-file changes
- 18 agent tools including delegation, web search, git

**Existing gaps (must address):**
- No testing infrastructure (zero unit tests)
- No CI/CD pipeline
- No quality presets
- No structured orchestration (5-schedule framework)
- No cost tracking
- No unified configuration (uses UserDefaults)
- No cross-product session format
- Monolithic services (700-1300 lines each)

---

### Implementation Priority

| Priority | Item | Effort |
|----------|------|--------|
| P0 | Configuration migration to YAML | Small |
| P0 | Tool registry loader | Small |
| P0 | CLI bridge service | Medium |
| P1 | Orchestration mode UI | Large |
| P1 | Quality presets UI | Small |
| P1 | Session persistence (unified format) | Medium |
| P1 | AgentExecutor split | Medium |
| P1 | Cost savings tracker | Small |

---

### Recovery Metadata

- Agent: sonnet-1
- This file: new creation per recovery mandate
- Content: verifiable IDE state and requirements derived from Round 0-1 analysis
- No patches to existing files
