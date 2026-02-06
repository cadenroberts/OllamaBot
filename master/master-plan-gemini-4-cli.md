# Master Plan: gemini-4 — obot CLI

**Agent:** gemini-4
**Product:** obot CLI (Go)
**Date:** 2026-02-05
**Status:** FLOW EXIT COMPLETE

---

## Architecture

The obot CLI becomes the canonical execution engine for both products. It exposes a JSON-RPC 2.0 server mode (`obot-server`) over Stdio that the IDE consumes. All orchestration, context management, model coordination, tool execution, and session persistence live in Go.

## Protocol Alignment

| Protocol | Abbreviation | CLI Role |
|----------|-------------|----------|
| Unified Orchestration Protocol | UOP | Owns the 5-schedule x 3-process state machine |
| Unified Tool Registry | UTR | Implements all 22 tools natively |
| Unified Context Protocol | UCP | Owns token budgeting, compression, memory, error learning |
| Unified Model Coordinator | UMC | Owns RAM tier detection, intent routing, model selection |
| Unified Configuration | UC | Reads/writes ~/.config/ollamabot/config.yaml |
| Unified State Format | USF | Owns session persistence, checkpoint save/restore |

## JSON-RPC Server Specification

The CLI exposes `cmd/obot-server` which listens on Stdio using JSON-RPC 2.0.

### Methods (IDE to Go)

- `initialize(root_path, capabilities) -> ServerCaps` — Boot kernel, index workspace, detect models.
- `session/start(mode, task) -> session_id` — Create new orchestration or infinite session.
- `session/input(session_id, text)` — Receive user input for active session.
- `session/stop(session_id)` — Terminate session cleanly.
- `shutdown()` — Clean exit, persist state.

### Notifications (Go to IDE)

- `$/state/update` — Emit full state dump after every orchestration step.
- `$/stream/chunk` — Emit each token chunk from LLM inference.
- `$/tool/start` — Emit when beginning tool execution.
- `$/tool/end` — Emit when tool execution completes.

### File Sync (IDE to Go)

- `textDocument/didChange` — Accept unsaved buffer contents from IDE for accurate context building.

## Migration: New Go Packages

These packages are created to support the kernel architecture:

- `pkg/server/` — JSON-RPC 2.0 handler, Stdio framing, request dispatch.
- `pkg/rpc/` — JSON-RPC 2.0 message types, serialization, notification emitter.
- `pkg/context/` — Port of Swift ContextManager: token budgeting, semantic compression, conversation memory, error pattern learning.
- `pkg/bots/` — Port of Swift OBotService: YAML bot parser, bot step executor, template renderer.

## Migration: Existing Go Enhancements

- `internal/agent/agent.go` — Add ReadFile, SearchFiles, ListFiles methods (Tier 2 tools). Currently write-only with 12 actions.
- `internal/agent/delegation.go` — New: multi-model delegation (delegate_to_coder, delegate_to_researcher, delegate_to_vision).
- `internal/model/coordinator.go` — Enhance to support 4 model roles (orchestrator, coder, researcher, vision).
- `internal/config/config.go` — Replace JSON config with YAML. Change path to ~/.config/ollamabot/. Add backward-compat symlink from ~/.config/obot/.
- `internal/tools/web.go` — New: DuckDuckGo web search integration.
- `internal/tools/git.go` — New: git status, diff, commit tools.

## Tool Tier Migration

The CLI agent currently has 12 write-only executor actions. The target is 22 tools across two tiers:

**Tier 1 (Executor) — Existing:**
CreateFile, DeleteFile, EditFile, RenameFile, MoveFile, CopyFile, CreateDir, DeleteDir, RenameDir, MoveDir, CopyDir, RunCommand

**Tier 2 (Autonomous) — To Add:**
ReadFile, SearchFiles, ListDirectory, DelegateToCoder, DelegateToResearcher, DelegateToVision, WebSearch, FetchURL, GitStatus, GitDiff

## Implementation Phases (CLI-Specific)

### Phase 1: The Go Server (Week 1)

1. Refactor obot to expose pkg/core (separate business logic from CLI entrypoint).
2. Implement cmd/obot-server as the Stdio RPC entrypoint.
3. Implement initialize and session/start RPC methods.
4. Implement $/state/update and $/stream/chunk notification emitters.

### Phase 3: Feature Porting (Weeks 3-4)

1. Port ContextManager token budgeting logic from Swift to Go (pkg/context).
2. Implement YAML bot parser in Go (pkg/bots).
3. Add Tier 2 tools: ReadFile, SearchFiles, web search, git tools, multi-model delegation.
4. Add checkpoint system (save/restore/list).

### Phase 4: Validation

1. Verify all 22 tools execute correctly via both CLI direct invocation and RPC server mode.
2. Cross-platform session replay: record session via CLI, import in IDE, verify identical state.
3. Performance gate: no regression greater than 5% in CLI execution time.

## Key Constraint: Orchestrator Closures

The existing orchestrator (internal/orchestrate/orchestrator.go) uses Go closure callbacks:

```
func (o *Orchestrator) Run(ctx context.Context,
    selectScheduleFn func(...) ...,
    selectProcessFn func(...) ...,
    executeProcessFn func(...) ...,
) error
```

These closures are not serializable over RPC. For the March release, both products implement the orchestration state machine natively against the UOP schema. Refactoring the orchestrator into a serializable request-response pattern is deferred to v2.0.

## Risk: Latency

- Stdio adds serialization overhead to high-throughput token streaming.
- Mitigation: Named Pipe or localhost socket as dedicated data channel for $/stream/chunk.
- Stdio remains the control channel for all other RPC traffic.

## Contribution Summary

- Round 0: Identified CLI as clean layered executor vs IDE as monolithic fat client.
- Round 1: Rejected Rust rewrite. Proposed CLI-as-engine with protocol bridge.
- Round 2: Endorsed Go Kernel. Specified RPC server protocol. Defined new Go packages.
- No implementation code was produced. All output was analysis and planning.
