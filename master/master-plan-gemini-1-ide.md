# Master Plan: Agent gemini-1 (IDE)

> RECOVERY HEADER
> Agent ID: gemini-1
> Source: ~/ollamabot/plans_3/plan-3-gemini-1.md
> Source Round: 3
> Recovery Date: 2026-02-06
> Scope: OllamaBot IDE (Swift/macOS)

---

# Final Consolidated Master Harmonization Plan (Round 3)

## 1. Executive Summary
This is the **Definitive Harmonization Roadmap**. It reconciles the "Protocol-Driven" approach (Gemini) with the "Go-Core" ambition (Sonnet/Composer). We reject the immediate "Rust Rewrite" as high-risk, choosing instead a **Hybrid Evolution**: immediately enforcing strict JSON protocols (Phase 1), then evolving the CLI into a "Headless Server" that the IDE can progressively adopt (Phase 2+).

**The "One Fruit" Vision:**
- **obot (CLI):** The rigorous, scriptable "Backbone" and "Server".
- **ollamabot (IDE):** The rich, interactive "Frontend" and "Client".
- **The Bond:** 5 Unified Protocols (UOP, UTR, UCP, UMC, USF).

## 2. The 5 Unified Protocols (The "Constitution")

We define 5 protocols that serve as the *Law* for both codebases.

### 2.1 Unified Orchestration Protocol (UOP)
*Definition:* The 5-Schedule Workflow (Knowledge → Plan → Implement → Scale → Production).
*Implementation:*
- **CLI:** Already native. Expose via `obot orchestrate --json`.
- **IDE:** Implement a State Machine in Swift that adheres to this lifecycle.
- **Goal:** IDE users get the rigor of the CLI workflow; CLI users get the visualization of the IDE.

### 2.2 Unified Tool Registry (UTR)
*Definition:* A superset of 22 canonical tools (e.g., `file.write`, `core.think`, `delegate.coder`).
*Implementation:*
- **Shared:** `tools.schema.json` defines the interface.
- **CLI:** Add `web.*`, `delegate.*` (via multi-model client).
- **IDE:** Rename legacy tools to match UTR IDs.

### 2.3 Unified Context Protocol (UCP)
*Definition:* A JSON standard for "Thought State" (Token Budgets, Semantic Compression).
*Implementation:*
- **Shared:** `context.schema.json`.
- **CLI:** Port IDE's `ContextManager` logic to Go.
- **IDE:** Export context snapshots in UCP format.

### 2.4 Unified Model Coordinator (UMC)
*Definition:* Logic for selecting models based on RAM (Tier) and Task (Intent).
*Implementation:*
- **Shared:** `models.yaml` config file.
- **Logic:** `Tier (RAM) -> Role (Intent) -> Model`.

### 2.5 Unified State Format (USF)
*Definition:* The "Session File" format.
*Implementation:*
- **Shared:** `session.schema.json`.
- **Capability:** `obot session save` -> `session.json` -> `OllamaBot Open`.

## 3. Architecture: The Hybrid Evolution

### Phase 1: Protocol Parity (Weeks 1-4)
*Goal: Separate but Equal.*
Both codebases remain independent but are refactored to speak the *exact same languages* (Protocols).
- **Action:** Create `ollamabot-spec` repo with JSON Schemas.
- **Action:** CI pipelines validate conformance.

### Phase 2: CLI as Server (Weeks 5-8)
*Goal: The Headless Backbone.*
The CLI implements a `server` mode (`obot server --port 9111`).
- **Action:** IDE *optionally* delegates heavy orchestration tasks to the CLI Server via JSON-RPC.
- **Benefit:** Swift code shrinks; Go code becomes the single source of truth for complex logic.

## 4. Implementation Roadmap (The Explosion)

### Step 1: The Specifications (Immediate)
Create the `ollamabot-spec` repo.
- `tools.schema.json`
- `context.schema.json`
- `session.schema.json`
- `config.schema.json`
- `orchestration.schema.json`

### Step 2: CLI Refactoring (Go)
1.  **Config:** Load `~/.ollamabot/config.yaml`.
2.  **Tools:** Implement `UniversalTool` interface.
3.  **Context:** Implement `ContextManager` (UCP).
4.  **Server:** Implement `obot server`.

### Step 3: IDE Refactoring (Swift)
1.  **Config:** Load `~/.ollamabot/config.yaml`.
2.  **Tools:** Map `AgentTools` to UTR.
3.  **Orchestration:** Implement UOP State Machine.
4.  **Client:** Implement `OBotClient` (RPC).

## 5. Risk Assessment
- **Risk:** FFI/RPC Latency. **Mitigation:** Keep the "inner loop" (typing, fast edits) native in Swift. Only offload "macro" tasks (Plan, Scale, Production) to Go.
- **Risk:** Schema Drift. **Mitigation:** "Golden File" tests in `ollamabot-spec` that break the build if either implementation diverges.

## 6. Success Metrics
1.  **Config Compatibility:** 100% shared `config.yaml`.
2.  **Session Portability:** 100% ability to open CLI sessions in IDE.
3.  **Tool Parity:** 22/22 tools supported in both (CLI via TUI/Headless).
4.  **Orchestration:** IDE fully supports the "Production" schedule.

This plan delivers the "One Fruit" vision: A unified, protocol-driven ecosystem with a clear evolutionary path toward a shared Go core.
