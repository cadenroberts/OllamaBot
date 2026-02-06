# obot FINAL MASTER PLAN — CLI

**Version:** 3.0 (The "Pragmatic Bridge" Consensus)
**Author:** Gemini-7 (Consolidating Sonnet-3, Composer-2, Gemini-6)
**Date:** 2026-02-05
**Scope:** obot CLI (Go)
**Philosophy:** Protocols for Standards, Go for Engine. No Rust Rewrite.

---

## 1. The Core Decision: Architecture

We analyzed three competing architectures:
1. **Rust Core (Sonnet):** Write a new shared library in Rust. (Rejected: Too high risk for March).
2. **Pure Protocols (Composer):** No shared code, just shared JSON schemas. (Rejected: Duplicates complex logic like Context Management).
3. **Go Bridge (Gemini):** Use the mature `obot` CLI as the shared engine via JSON-RPC. (Accepted: Best balance of code reuse and safety).

**Verdict:** We proceed with the **Go Bridge Architecture** reinforced by **Strict Protocols**.

---

## 2. System Architecture: The "One Brain"

### 2.1 The Engine (`obot`)
The `obot` CLI (Go) is refactored to expose its internals as a service.
- **Service Layer:** `pkg/service/` wraps Orchestrator, Context, and Tools.
- **Bridge Mode:** `obot bridge` starts a JSON-RPC 2.0 server over Stdio.

### 2.2 The Interface (`ollamabot`)
The IDE (Swift) becomes a lightweight UI layer.
- **Protocol:** Communicates exclusively via JSON-RPC.
- **State:** Mirrors the Engine's state (Session, Orchestration status).

### 2.3 The Protocols (The Contract)
We adopt the **6 Unified Protocols**:
1. **UOP (Orchestration):** 5 Schedules (Knowledge, Plan, Implement, Scale, Production).
2. **UTR (Tools):** 22 Standardized Tools (File, Git, Search, System).
3. **UCP (Context):** Token Budgeting & Semantic Compression (Ported from Swift to Go).
4. **UMC (Models):** Tier Detection & Intent Routing.
5. **UC (Config):** Shared YAML Configuration.
6. **USF (State):** Unified Session Format.

---

## 3. CLI-Specific Implementation

### 3.1 Package Refactoring
**Current:** All logic lives in `internal/` (unexportable).
**Target:** Extract reusable logic into `pkg/` (exportable for Bridge).

| Current Location | New Location | Purpose |
|---|---|---|
| `internal/orchestrate/` | `pkg/orchestrator/` | 5-Schedule state machine |
| `internal/context/` | `pkg/context/` | Token budgeting (ported from Swift) |
| `internal/fixer/` | `pkg/fixer/` | Code fix engine |
| `internal/agent/` | `pkg/agent/` | Tool execution |
| `internal/ollama/` | `pkg/ollama/` | Ollama API client |
| `internal/tier/` | `pkg/model/` | Tier detection + Intent routing |
| `internal/config/` | `pkg/config/` | Unified YAML config loader |
| `internal/session/` | `pkg/session/` | Unified session persistence |

### 3.2 Bridge Server (`cmd/bridge.go`)
- **Transport:** JSON-RPC 2.0 over Stdio (stdin/stdout).
- **Methods:**
  - `orchestrator.start_task` — Begin a new task.
  - `orchestrator.state` — Get current schedule/process.
  - `tool.execute` — Execute a tool and return result.
  - `context.build` — Build token-budgeted context.
  - `session.save` / `session.load` — Persist/restore sessions.
- **Notifications (server -> client):**
  - `agent.thought` — Internal reasoning block.
  - `tool.call` — Tool invocation with args.
  - `tool.result` — Tool execution result.
  - `orchestrator.state_change` — Schedule/process transition.
  - `stream.token` — Streaming LLM token.

### 3.3 New CLI Features (from IDE parity)
- **Token Budgeting:** Port `ContextManager` logic from Swift to `pkg/context/`.
- **Intent Routing:** Port `IntentRouter` logic from Swift to `pkg/model/`.
- **Web Search Tool:** Add DuckDuckGo search to `pkg/tools/`.
- **Multi-Model Delegation:** Add `delegate` tool to `pkg/tools/`.
- **Git Tools:** Add `git.status`, `git.diff`, `git.commit` to `pkg/tools/`.

### 3.4 The 22-Tool Standard

| Category | Tool ID | Status |
|---|---|---|
| **Core** | `think` | NEW |
| | `complete` | NEW |
| | `ask_user` | NEW |
| **Files** | `file.read` | EXISTS (rename) |
| | `file.write` | EXISTS (rename) |
| | `file.edit` | EXISTS (rename) |
| | `file.list` | NEW |
| | `file.delete` | EXISTS (rename) |
| | `file.move` | EXISTS (rename) |
| | `file.copy` | EXISTS (rename) |
| | `file.mkdir` | EXISTS (rename) |
| **Search** | `search.code` | NEW |
| | `search.web` | NEW |
| | `fetch.url` | NEW |
| **Git** | `git.status` | NEW |
| | `git.diff` | NEW |
| | `git.commit` | NEW |
| **System** | `sys.exec` | EXISTS (rename) |
| **Delegation** | `agent.delegate` | NEW |

---

## 4. Implementation Roadmap

### Phase 1: Foundation (Weeks 1-4)
- P1.01-06: Define JSON Schemas for all 6 Protocols.
- P1.07: Refactor `obot` to separate `cmd` from `pkg`.
- P1.08: Implement `obot bridge` command (JSON-RPC server).

### Phase 2: Migration (Weeks 5-8)
- P2.01: Port **Token Budgeting** (Swift) -> `pkg/context` (Go).
- P2.02: Port **Intent Router** (Swift) -> `pkg/model` (Go).
- P2.03: Implement **5-Schedule Orchestrator** in `pkg/orchestrator` (Go).

### Phase 3: Unification (Weeks 9-12)
- P3.01: Implement **22-Tool Registry** in `pkg/tools` (Go).
- P3.03: Unified Session persistence (JSON).
- P3.08: Add missing tools (Web Search, Git, Delegation).

---

## 5. Success Criteria
1. **Zero Logic Duplication:** Complex algorithms (Context, Orchestration) exist ONLY in Go.
2. **Bridge Stability:** `obot bridge` runs indefinitely without memory leaks.
3. **March Release:** Achievable because we are refactoring, not rewriting.
4. **Tool Parity:** All 22 tools implemented and callable via Bridge.
5. **Binary Size:** Go binary < 20MB (acceptable for bundling inside OllamaBot.app).
