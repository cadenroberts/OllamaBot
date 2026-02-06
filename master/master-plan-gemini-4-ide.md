# Master Plan: gemini-4 — OllamaBot IDE

**Agent:** gemini-4
**Product:** OllamaBot IDE (Swift/SwiftUI)
**Date:** 2026-02-05
**Status:** FLOW EXIT COMPLETE

---

## Architecture

The OllamaBot IDE becomes a thin UI client for the obot Go kernel, communicating via JSON-RPC 2.0 over Stdio. All business logic (orchestration, context management, model coordination, session persistence) lives in Go. The IDE focuses on visualization, user interaction, and native macOS integration.

## Protocol Alignment

| Protocol | Abbreviation | IDE Role |
|----------|-------------|----------|
| Unified Orchestration Protocol | UOP | Renders schedule/process state from Go kernel notifications |
| Unified Tool Registry | UTR | Displays tool execution status, delegates to Go kernel |
| Unified Context Protocol | UCP | Sends open file/buffer state to Go kernel via textDocument/didChange |
| Unified Model Coordinator | UMC | Reads model config from shared YAML, displays tier info |
| Unified Configuration | UC | Reads ~/.config/ollamabot/config.yaml, retains UserDefaults for UI prefs only |
| Unified State Format | USF | Imports/exports sessions in cross-product JSON format |

## JSON-RPC Client Specification

The IDE spawns `obot-server` as a subprocess and communicates via Stdio.

### Requests (IDE to Go)

- `initialize(root_path, capabilities)` — Handshake, workspace indexing, model detection.
- `session/start(mode, task)` — Begin an orchestration or infinite-mode session.
- `session/input(session_id, text)` — Send user input to active session.
- `session/stop(session_id)` — Terminate session.
- `shutdown()` — Clean exit.

### Notifications (Go to IDE)

- `$/state/update` — Full state dump (schedule, process, current step).
- `$/stream/chunk` — Token stream from LLM for real-time rendering.
- `$/tool/start` — Tool execution begun on a file.
- `$/tool/end` — Tool execution completed on a file.

### File Sync (IDE to Go)

- `textDocument/didChange` — Notify Go of unsaved buffer edits for accurate context.

## Migration: Swift Services to Remove

These Swift services are replaced by RPC calls to the Go kernel:

- `Sources/Services/OllamaService.swift` — Replaced by RPC streaming client.
- `Sources/Agent/AgentExecutor.swift` — Replaced by RPC state listener rendering $/state/update.
- `Sources/Services/ContextManager.swift` — Logic ported to Go pkg/context.
- `Sources/Services/ModelTierManager.swift` — Logic ported to Go, IDE reads shared config.

## Migration: New Swift Files

- `Sources/Services/OBotKernel.swift` — Manages obot-server subprocess lifecycle (start, stop, restart, crash recovery).
- `Sources/Services/RPCClient.swift` — JSON-RPC 2.0 message framing over Stdio.
- `Sources/Views/OrchestrationView.swift` — Renders 5-schedule x 3-process state and flow code.
- `Sources/Views/QualityPresetView.swift` — Fast/Balanced/Thorough selector.

## Implementation Phases (IDE-Specific)

### Phase 2: Swift Client (Week 2)

1. Create OBotKernel.swift to manage the Go subprocess.
2. Create RPCClient.swift for JSON-RPC message passing.
3. Connect AgentView to $/state/update notifications instead of local AgentExecutor.
4. Verify basic chat flow works end-to-end via RPC.

### Phase 3: Feature Porting (Weeks 3-4)

1. Add OrchestrationView for 5-schedule visualization.
2. Add QualityPresetView for fast/balanced/thorough selection.
3. Add session import/export using USF JSON format.
4. Read shared config.yaml for model and quality settings.

### Phase 4: Validation

1. Verify token streaming latency is acceptable over Stdio.
2. If latency exceeds 50ms per chunk, switch to Named Pipe data channel.
3. Cross-platform session replay: export from IDE, import in CLI, verify identical state.

## Risk: Latency

- Stdio RPC adds serialization overhead to token streaming.
- Mitigation: Named Pipe or localhost socket as fallback data channel for raw token streams.
- Stdio remains the control channel for RPC requests/responses regardless.

## Contribution Summary

- Round 0: Identified IDE as monolithic fat client. Proposed .obot standard and Action Schema unification.
- Round 1: Rejected Rust rewrite. Proposed Protocol Standardization and Native Porting.
- Round 2: Endorsed Go Kernel. Specified JSON-RPC protocol. Defined Swift migration kill list.
- No implementation code was produced. All output was analysis and planning.
