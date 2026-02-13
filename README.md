# OllamaBot 

![OllamaBot Banner](https://img.shields.io/badge/OllamaBot-Local_AI_IDE-7dcfff?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IiM3ZGNmZmYiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIj48cGF0aCBkPSJNMTggOGE2IDYgMCAwIDAtMTIgMGMwIDcgMTIgNyAxMiAwWiIvPjxjaXJjbGUgY3g9IjEyIiBjeT0iOCIgcj0iNiIvPjwvc3ZnPg==) <span style="float:right;"> [![macOS](https://img.shields.io/badge/macOS-14.0+-000000?style=flat-square&logo=apple&logoColor=white)](https://www.apple.com/macos/) [![Swift](https://img.shields.io/badge/Swift-5.9+-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org) [![Ollama](https://img.shields.io/badge/Ollama-Local_AI-white?style=flat-square)](https://ollama.ai)

A native macOS IDE and Go CLI for autonomous local AI coding, powered by Ollama. Both platforms coordinate four specialized language models (orchestrator, coder, researcher, vision) to fix code, run multi-schedule orchestration, and manage sessions entirely offline.

## What it does

- **Infinite Mode (IDE):** Autonomous agent loop that reads, writes, and delegates across four models until a task is complete.
- **Explore Mode (IDE):** Continuous autonomous improvement cycles (understand, expand, specify, standardize, document, reflect).
- **CLI code fix:** Single-command file fixing with three quality presets (fast, balanced, thorough).
- **CLI orchestration:** 5-schedule (Knowledge, Plan, Implement, Scale, Production) x 3-process autonomous pipeline with session persistence.
- **Unified configuration:** Both platforms share `~/.config/ollamabot/config.yaml` and the Unified Session Format (USF).
- **Offline operation:** All inference runs locally via Ollama on localhost. No API keys required for core functionality.

## Architecture

```
OllamaBot/
├── Sources/                  # Swift macOS IDE (77 files)
│   ├── OllamaBotApp.swift    # @main entry, AppState init
│   ├── Agent/                # AgentExecutor, tools, delegation, Explore Mode
│   ├── Models/               # ChatMessage, FileItem, OllamaModel
│   ├── Services/             # 32 services (OllamaService, OrchestrationService, etc.)
│   ├── Utilities/            # DesignSystem, SyntaxHighlighter, PerformanceCore
│   └── Views/                # 27 SwiftUI views
│
├── cmd/obot/main.go          # Go CLI entry point
├── internal/                  # 38 Go packages
│   ├── cli/                   # 16 subcommands (fix, orchestrate, plan, review, etc.)
│   ├── ollama/                # HTTP client for Ollama API (/api/chat, /api/generate, /api/tags)
│   ├── orchestrate/           # 5-schedule state machine, navigation rules
│   ├── agent/                 # Action execution, types, delegation
│   ├── fixer/                 # Code fix engine with quality presets
│   ├── session/               # USF persistence, cross-platform export/import
│   ├── config/                # Unified YAML config, legacy JSON migration
│   ├── judge/                 # LLM-as-Judge quality assessment (4-expert panel)
│   └── ...                    # +30 more packages
│
├── Installer/                 # macOS installer app (separate Package.swift)
├── website/                   # Marketing site (static HTML/CSS/JS)
├── Resources/                 # Info.plist, AppIcon.icns
├── scripts/                   # setup.sh, build-app.sh, generate-icon.sh
├── Package.swift              # Swift Package Manager manifest
├── go.mod                     # Go 1.24, 7 direct dependencies
└── Makefile                   # Go CLI build targets
```

### Data flow: CLI fix

```
cmd/obot/main.go
  -> cli.Execute() -> PersistentPreRunE: config.Load(), ollama.NewClient()
  -> runFix: analyzer.ReadFileContext() -> fixer.NewAgent(client)
  -> agent.Fix: ollama.Chat(prompt) -> parse -> patch.Apply() -> validate
```

### Data flow: CLI orchestration

```
orchestrate subcommand
  -> router.Classify(prompt) -> model.NewCoordinator(4 clients)
  -> planner.BuildPlan() -> runOrchestrationLoop:
     for schedule in [knowledge, plan, implement, scale, production]:
       for process in [p1, p2, p3]:
         agent.Execute(model, prompt, tools)
  -> judge.Analyze() -> summary.Generate() -> session.Save()
```

### Data flow: IDE agent

```
AgentView -> AgentExecutor.runAgentLoop()
  -> OllamaService.chatWithTools(model, messages, tools)
  -> parseToolCalls -> executeToolsParallel (read tools in parallel, write tools sequential)
  -> delegate_to_coder / researcher / vision -> OllamaService.generate()
  -> loop until complete
```

## Design tradeoffs

1. **Four separate models vs. one general model.** Increases VRAM pressure (~32GB for all four loaded) but allows each specialist to use role-specific system prompts and temperature settings. The orchestrator delegates rather than doing everything.

2. **Local-only by default.** No cloud fallback means inference is slower than API-based tools, but eliminates API costs, rate limits, and data egress. External LLM providers are supported as an opt-in via the IDE's `ExternalModelConfigurationService`.

3. **Cobra CLI + SwiftUI IDE as separate codebases.** Shared via config files and session format rather than FFI or RPC. Simpler to maintain but requires manual parity for new features. A JSON-RPC bridge is planned for v2.0.

4. **Session-based state, not git-based.** Orchestration state is tracked via USF JSON files with flow codes (e.g., `S1P123S2P12`), not git branches. Enables cross-platform session handoff but requires explicit checkpoint management.

5. **No sandbox for CLI agent commands.** The `run_command` tool in orchestration mode executes arbitrary shell commands. The IDE prompts for confirmation; the CLI does not. Documented as P0 risk in the audit.

## Evaluation

### Go CLI

```bash
make build            # Compile binary with version injection
go test ./internal/...  # Run all 38 packages (currently 38/38 pass)
go vet ./internal/...   # Static analysis
```

38 packages pass. Weighted average test coverage is ~30%. High-coverage packages (actions 100%, router 90%, process 85.7%) are pure logic. Low-coverage packages (ollama 5.4%, cli 7.9%) depend on external services.

### Swift IDE

```bash
swift build           # Compile from source
swift test            # Run Swift tests
```

## Demo

### Prerequisites

- macOS 14.0+ on Apple Silicon
- Go 1.24+
- Ollama installed and running (`ollama serve`)
- At least one model pulled (`ollama pull qwen3:32b`)

### CLI quick start

```bash
# Build
git clone https://github.com/cadenroberts/OllamaBot.git
cd OllamaBot
make build

# Verify
./bin/obot --version

# Fix a file
./bin/obot main.go "add error handling"

# Run tests
go test ./internal/...
```

### IDE quick start

```bash
swift build
swift run OllamaBot
# Or: open Package.swift in Xcode
```

### Smoke test (no Ollama required)

```bash
make build && ./bin/obot --version && go test ./internal/... && go vet ./internal/...
```

Expected: binary prints `obot version 1.0.0`, all 38 test packages pass, vet reports no issues.

## Repository layout

| Path | Description |
|------|-------------|
| `Sources/` | Swift macOS IDE (77 files across Agent, Models, Services, Utilities, Views) |
| `cmd/obot/` | Go CLI binary entry point |
| `internal/` | 38 Go packages (cli, ollama, orchestrate, agent, fixer, session, config, judge, etc.) |
| `Installer/` | macOS installer app |
| `website/` | Static marketing site |
| `Resources/` | App bundle metadata (Info.plist, icons) |
| `scripts/` | Build and setup scripts (setup.sh, build-app.sh, generate-icon.sh) |
| `docs/` | Protocol specs, migration guides, release notes, testing docs |
| `Package.swift` | Swift Package Manager manifest (SwiftTerm, Yams) |
| `go.mod` | Go module (cobra, color, tiktoken-go, goquery, yaml.v3, etc.) |
| `Makefile` | Go build targets (build, install, test, release, checksums) |

## Limitations

- **VRAM requirement:** Full 4-model orchestration requires ~32GB RAM. 16GB systems can run with reduced model selection.
- **macOS only (IDE):** The SwiftUI IDE is macOS 14.0+ and Apple Silicon only.
- **No CI:** There is no automated CI pipeline. Build and test verification is manual.
- **CLI agent is unsandboxed:** The `run_command` tool executes arbitrary shell commands without confirmation during orchestration.
- **LLM nondeterminism:** Fix and orchestration results vary between runs due to sampling (default temperature 0.3).
- **No structured logging:** The CLI uses `fmt.Printf` throughout. No log levels, no structured output.

## License

MIT License. See [LICENSE](LICENSE) for details.
