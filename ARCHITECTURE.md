# Architecture

## Component Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          USER INTERFACES                                 │
│                                                                          │
│  ┌──────────────────────┐          ┌───────────────────────────────────┐ │
│  │   SwiftUI IDE         │          │   Go CLI (obot)                  │ │
│  │   Sources/Views/      │          │   cmd/obot/main.go               │ │
│  │   - AgentView         │          │   internal/cli/root.go           │ │
│  │   - ChatView          │          │   16 subcommands                 │ │
│  │   - EditorView        │          │                                   │ │
│  │   - OrchestrationView │          │                                   │ │
│  └──────────┬───────────┘          └────────────┬──────────────────────┘ │
│             │                                    │                        │
└─────────────┼────────────────────────────────────┼────────────────────────┘
              │                                    │
              ▼                                    ▼
┌──────────────────────────┐   ┌──────────────────────────────────────────┐
│  IDE Agent Layer          │   │  CLI Agent Layer                         │
│                            │   │                                          │
│  Agent/AgentExecutor       │   │  internal/agent     (actions, types)     │
│  Agent/ExploreAgentExecutor│   │  internal/fixer     (code fix engine)    │
│  Agent/CycleAgentManager   │   │  internal/planner   (pre-orchestration)  │
│  Agent/CoreToolExecutor    │   │  internal/tools     (git, web, core)     │
│  Agent/AdvancedToolExecutor│   │  internal/delegation(multi-model)        │
└──────────┬─────────────────┘   └───────────┬────────────────────────────┘
           │                                  │
           ▼                                  ▼
┌──────────────────────────┐   ┌──────────────────────────────────────────┐
│  IDE Orchestration        │   │  CLI Orchestration                       │
│                            │   │                                          │
│  Services/                 │   │  internal/orchestrate  (state machine)   │
│    OrchestrationService    │   │  internal/schedule     (5 schedule types)│
│    (UOP state machine,     │   │  internal/process      (P1/P2/P3)       │
│     UserDefaults persist)  │   │  internal/model        (4-client coord) │
│                            │   │  internal/consultation (human-in-loop)  │
└──────────┬─────────────────┘   └───────────┬────────────────────────────┘
           │                                  │
           ▼                                  ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                          LLM CLIENT LAYER                                │
│                                                                          │
│  IDE: Services/OllamaService.swift       CLI: internal/ollama/client.go  │
│    URLSession -> localhost:11434            net/http -> localhost:11434   │
│    /api/chat (streaming)                   /api/chat, /api/generate      │
│    /api/generate                           /api/tags, /api/embeddings    │
│    /api/tags                                                             │
│    + ExternalLLMService (opt-in)                                         │
│    + APIKeyStore (Keychain)                                              │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
              │                                    │
              ▼                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                        SHARED DATA LAYER                                 │
│                                                                          │
│  ~/.config/ollamabot/config.yaml   (Unified Configuration - UC)          │
│  ~/.config/ollamabot/sessions/     (Unified Session Format - USF)        │
│  ~/.config/ollamabot/telemetry/    (Local-only usage stats)              │
│  .obot/rules.obotrules             (Project-level AI rules)              │
│                                                                          │
│  IDE reader: Services/SharedConfigService.swift (hot-reload via          │
│              DispatchSource file watcher)                                 │
│  CLI reader: internal/config/unified.go (load on startup)                │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
              │
              ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                          OLLAMA RUNTIME                                   │
│                                                                          │
│  ollama serve (localhost:11434)                                           │
│  Models: qwen3:32b, qwen2.5-coder:32b, command-r:35b, qwen3-vl:32b     │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

## Execution Flow

### CLI: Root command dispatch

1. `cmd/obot/main.go` sets build-time version info via `version.Set()` and `cli.SetVersion()`.
2. `cli.Execute()` invokes `rootCmd.Execute()` (Cobra).
3. `rootCmd.PersistentPreRunE` (`internal/cli/root.go:71-140`):
   - Loads config via `config.Load()` (tries unified YAML, then legacy JSON).
   - Creates `tier.NewManager()` to determine model tier from system RAM.
   - Creates `ollama.NewClient()` with base URL from flag > config > default.
   - Applies temperature, max tokens, context window from flags/config.
4. `rootCmd.RunE` (`internal/cli/root.go:141-167`):
   - If args match a registered subcommand, dispatches to it.
   - If no args, prints help.
   - Otherwise, treats args as `runFix(cmd, args)`.

### CLI: Orchestration loop

1. `orchestrate` subcommand (`internal/cli/orchestrate.go:113-300`).
2. Classifies intent via `router.NewIntentRouter().Classify()`.
3. Creates 4-model coordinator: `model.NewCoordinator()`.
4. Creates orchestrator, session, resource monitor, agent.
5. Optionally runs `planner.BuildPlan()` for a pre-schedule plan.
6. Enters `runOrchestrationLoop()`:
   - `modelCoord.SelectNextSchedule()` picks next schedule.
   - Schedule factory creates schedule with 3 processes.
   - Each process executes via `agent.Execute()`.
   - Actions recorded in `session.AddState()`.
7. Post-loop: `judge.Analyze()` runs 4-expert quality assessment, `summary.Generate()` produces report, `session.Save()` persists.

### IDE: Agent loop

1. User triggers Infinite Mode via `AgentView`.
2. `AgentExecutor.runAgentLoop()` (`Sources/Agent/AgentExecutor.swift`).
3. Each iteration: `OllamaService.chatWithTools(model: .qwen3, messages, tools: AgentTools.all)`.
4. Response parsed for tool calls.
5. `executeToolsParallel()`: read-only tools (`read_file`, `list_directory`, `search_files`, `think`) run concurrently via `withTaskGroup`. Write tools run sequentially.
6. Delegation tools (`delegate_to_coder`, `delegate_to_researcher`, `delegate_to_vision`) call `OllamaService.generate()` with the specialist model.
7. Results fed back as tool results. Loop continues until `complete` tool is called or step limit reached.

## Contracts Between Components

### Ollama client contract

- **Input:** `ChatRequest` with `model`, `messages []Message`, optional `tools`, `stream: true`.
- **Output:** `AsyncThrowingStream<String, Error>` (IDE) or `ChatResponse` (CLI).
- **Invariant:** Client retries on connection failure up to the configured timeout. Client does not authenticate.

### Session persistence contract

- **Format:** USF (Unified Session Format) JSON.
- **Location:** `~/.config/ollamabot/sessions/{id}/`.
- **Invariant:** Sessions created in CLI can be loaded in IDE and vice versa. Flow codes encode the schedule/process path (e.g., `S1P123S2P12`).

### Configuration contract

- **Format:** YAML at `~/.config/ollamabot/config.yaml`.
- **Schema:** `version: "2.0"`, sections: `models`, `quality`, `context`, `orchestration`.
- **Invariant:** Both platforms read the same file. IDE watches for changes via `DispatchSource`. CLI reads once at startup.

### Navigation rules (orchestration)

- Process transitions within a schedule follow: P1 <-> P2 <-> P3.
- P1 cannot skip to P3. P3 cannot skip to P1.
- Schedule termination requires reaching P3.
- Prompt termination requires all 5 schedules run at least once, last schedule = Production.

## Failure Modes and Recovery

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Ollama not running | `client.CheckConnection()` returns error | CLI: `obot scan` reports status, user must start `ollama serve`. IDE: status bar shows "Disconnected". |
| Model not available | `client.HasModel()` returns false | CLI: error message with `ollama pull` command. IDE: model dropdown shows unavailable. |
| Agent stuck in loop | Step count exceeds configured limit | IDE: auto-stops and shows step summary. CLI: exits with error. |
| Power loss during orchestration | Process crash | IDE: `ResilienceService` auto-saves state every 30s. On relaunch, offers recovery via `RecoveryAlert`. CLI: `obot orchestrate --resume <id>` resumes from last checkpoint. |
| Patch apply failure | `patch.Apply()` returns error | Automatic rollback to backup file. Original file restored. |
| Navigation violation | `isValidNavigation()` returns false | `OrchestrationError` with code E001-E009. Orchestrator is suspended. User can Retry, Skip, or Abort. |

## Observability

| Signal | Implementation | Location |
|--------|---------------|----------|
| CLI output | `fmt.Printf` / `fmt.Fprintf(os.Stderr)` | `internal/cli/root.go` (`printInfo`, `printError`, `printWarning`) |
| Telemetry | Local JSON file | `~/.config/ollamabot/telemetry/stats.json` via `internal/telemetry/service.go` |
| Memory monitor | `runtime.ReadMemStats` at 100ms | `internal/monitor/memory.go` |
| Resource limits | Memory/disk/token tracking | `internal/resource/monitor.go` |
| Structured errors | `OrchestrationError` with codes E001-E015 | `internal/error/types.go` |
| IDE performance | `PerformanceTrackingService` | `Sources/Services/PerformanceTrackingService.swift` |
| IDE network | `NetworkMonitorService` via NWPathMonitor | `Sources/Services/NetworkMonitorService.swift` |
