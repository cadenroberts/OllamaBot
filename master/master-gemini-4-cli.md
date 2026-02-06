# obot CLI Master Plan (gemini-4)

**Agent:** gemini-4
**Product:** obot CLI (Go)
**Architecture:** Go Bridge + 6 Unified Protocols
**Status:** FINAL MASTER

---

## 1. Executive Summary

The `obot` CLI will be refactored from a standalone code-fixer into a **dual-mode engine**: it retains its current CLI interface while also exposing a JSON-RPC server mode (`obot bridge`) that the OllamaBot IDE can consume. All complex logic (orchestration, context management, model coordination) lives in Go and is the single source of truth.

---

## 2. The 6 Unified Protocols (CLI Compliance)

### UOP (Unified Orchestration Protocol)
- **Current:** Fully implemented in `internal/orchestrate/` with 5 schedules, 3 processes, flow code tracking.
- **Target:** Validate existing implementation against UOP JSON schema. Expose orchestration state via `obot bridge` API.
- **Files:** `internal/orchestrate/orchestrator.go` (VALIDATE), `pkg/service/orchestration.go` (NEW wrapper).

### UTR (Unified Tool Registry)
- **Current:** 12 actions (file CRUD, run_command). Missing: `web.*`, `delegate.*`, `git.*`, `think`, `ask_user`.
- **Target:** Implement all 22 canonical tools. Register them using UTR schema definitions.
- **Files:** `internal/tools/web.go` (NEW), `internal/tools/git.go` (NEW), `internal/tools/core.go` (NEW), `internal/delegation/handler.go` (NEW).

### UCP (Unified Context Protocol)
- **Current:** Basic string concatenation in `internal/context/summary.go`.
- **Target:** Port IDE's `ContextManager` logic to Go: token budgeting (System 15%, Files 35%, History 12%, Memory 12%), semantic compression, error pattern learning.
- **Files:** `internal/context/manager.go` (NEW), `internal/context/budget.go` (NEW), `internal/context/compressor.go` (NEW).

### UMC (Unified Model Coordinator)
- **Current:** RAM-based tier detection in `internal/tier/`. Single model per tier.
- **Target:** Add intent routing (Coding/Research/Vision/General). Support 4 model roles per tier (orchestrator, coder, researcher, vision).
- **Files:** `internal/intent/router.go` (NEW), `internal/tier/models.go` (MODIFY to support 4 roles).

### UC (Unified Configuration)
- **Current:** JSON config at `~/.config/obot/config.json`.
- **Target:** Migrate to YAML at `~/.ollamabot/config.yaml`. Auto-migrate existing JSON configs on first run.
- **Files:** `internal/config/config.go` (REWRITE), `internal/config/migrate.go` (NEW). Add `gopkg.in/yaml.v3` dependency.

### USF (Unified State Format)
- **Current:** Custom session format in `internal/session/session.go`.
- **Target:** Read/write `~/.ollamabot/sessions/{id}.json` conforming to USF schema. Enable `obot session save/load/list`.
- **Files:** `internal/session/usf.go` (NEW), `internal/session/manager.go` (NEW).

---

## 3. Feature Additions (IDE -> CLI Transfers)

| Feature | Priority | File |
|---------|----------|------|
| Multi-Model Delegation | P0 | `internal/delegation/handler.go` |
| Token-Budgeted Context | P0 | `internal/context/manager.go` |
| Intent Routing | P1 | `internal/intent/router.go` |
| Web Search Tool | P1 | `internal/tools/web.go` |
| Vision Model Integration | P1 | `internal/ollama/vision.go` |
| Git Tools (status/diff/commit) | P1 | `internal/tools/git.go` |
| Think Tool | P1 | `internal/tools/core.go` |
| Ask User with Timeout | P1 | `internal/consultation/handler.go` |
| File Search (ripgrep) | P1 | `internal/tools/filesearch.go` |
| Screenshot Capture | P2 | `internal/tools/screenshot.go` |

---

## 4. Architecture: Bridge Mode

The CLI adds a new `bridge` command that starts a JSON-RPC 2.0 server over stdio, enabling the IDE to consume Go logic without reimplementing it.

```
obot bridge (Go)
    |
    +-- JSON-RPC Methods:
    |     session.start(prompt, quality) -> sessionId
    |     session.step(sessionId)        -> stepResult (streaming)
    |     session.state(sessionId)       -> fullState
    |     context.build(params)          -> contextJSON
    |     models.list()                  -> modelList
    |     config.get() / config.set()    -> configYAML
    |
    +-- Internal Services:
          OrchestratorService  (5-schedule state machine)
          ContextManager       (UCP token budgeting)
          ModelCoordinator     (UMC tier + intent)
          ToolRegistry         (UTR 22 tools)
          SessionManager       (USF persistence)
```

### Package Restructure

```
obot/
├── cmd/obot/           # CLI entry point (unchanged)
├── pkg/
│   ├── bridge/         # JSON-RPC server (NEW)
│   ├── service/        # Service wrappers for bridge (NEW)
│   └── protocol/       # Schema validators (NEW)
├── internal/
│   ├── agent/          # Agent loop
│   ├── context/        # UCP implementation (ENHANCED)
│   ├── config/         # UC implementation (REWRITTEN)
│   ├── consultation/   # Human consultation
│   ├── delegation/     # Multi-model delegation (NEW)
│   ├── intent/         # Intent routing (NEW)
│   ├── ollama/         # Ollama API client
│   ├── orchestrate/    # UOP implementation (existing)
│   ├── session/        # USF implementation (ENHANCED)
│   ├── tier/           # Model tier detection (ENHANCED)
│   ├── tools/          # UTR tool implementations (ENHANCED)
│   └── ui/             # Terminal UI
└── schemas/            # JSON Schema files (NEW)
```

---

## 5. Implementation Phases

### Phase 1: Foundation (Weeks 1-4)
- Add `gopkg.in/yaml.v3` dependency.
- Rewrite `config.go` to read `~/.ollamabot/config.yaml`.
- Create JSON Schema files for all 6 protocols in `schemas/`.
- Implement `pkg/bridge/` with basic JSON-RPC server.
- Implement `internal/context/manager.go` (token budgeting port from Swift).

### Phase 2: Tool Parity (Weeks 5-8)
- Implement missing 10 tools (`web.*`, `delegate.*`, `git.*`, `think`, `ask_user`).
- Implement `internal/intent/router.go` for model selection.
- Implement `internal/delegation/handler.go` for multi-model.
- Update `internal/tier/models.go` to support 4 roles per tier.
- Implement `internal/session/usf.go` for unified sessions.

### Phase 3: Polish (Weeks 9-12)
- Config migration tool (`obot migrate`).
- Protocol compliance test suite.
- Performance regression benchmarks.
- `obot bridge` stability testing.
- Documentation.

---

## 6. Success Metrics

- **Tool Parity:** 22/22 UTR tools implemented and functional.
- **Context Quality:** Token budgeting operational (35% files, 15% system, etc.).
- **Session Portability:** Sessions created in CLI open in IDE without data loss.
- **Bridge Stability:** JSON-RPC server handles 1000+ sequential requests without crash.
- **Config Compatibility:** 100% settings shared with IDE via `config.yaml`.
- **Performance:** Startup < 200ms. No regression in fix speed.

---

## 7. Key Existing Files Reference

- `internal/orchestrate/orchestrator.go` — 5-schedule state machine (reference implementation).
- `internal/orchestrate/navigator.go` — Process navigation (1-2-3 rules).
- `internal/orchestrate/flowcode.go` — Flow code generation (S1P123).
- `internal/fixer/engine.go` — Code fix engine.
- `internal/fixer/quality.go` — Quality presets (fast/balanced/thorough).
- `internal/ollama/client.go` — Ollama API client.
- `internal/tier/detect.go` — RAM-based tier detection.
- `internal/tier/models.go` — Model-to-tier mapping.
- `internal/context/summary.go` — Current basic context builder (to be replaced).
- `internal/session/session.go` — Current session format (to be replaced by USF).

---

**END OF CLI MASTER PLAN (gemini-4)**
