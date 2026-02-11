# Repository Audit

## 1. Purpose

OllamaBot is a dual-platform local AI coding assistant:

- **Go CLI (`obot`):** A command-line tool that uses local Ollama models to fix code, run autonomous multi-schedule orchestration, manage sessions, and perform project health scans.
- **Swift macOS IDE:** A native SwiftUI application with code editor, terminal, chat, and autonomous agent modes (Infinite Mode, Explore Mode) that coordinates four specialized Ollama models.

Both platforms share configuration (`~/.config/ollamabot/config.yaml`) and session formats (USF).

## 2. Entry Points

| Platform | Entry | Build | Run |
|----------|-------|-------|-----|
| Go CLI | `cmd/obot/main.go` | `make build` | `./bin/obot [file] [instruction]` |
| Swift IDE | `Sources/OllamaBotApp.swift` | `swift build` | `swift run OllamaBot` or `.app` bundle |
| Installer | `Installer/Sources/InstallerApp.swift` | `swift build` (via `Installer/Package.swift`) | macOS installer UI |

### CLI Subcommands (16 registered)

| Command | File | Purpose |
|---------|------|---------|
| `obot [file]` (root) | `cli/root.go`, `cli/fix.go` | Fix code in file or line range |
| `orchestrate` | `cli/orchestrate.go` | 5-schedule autonomous orchestration |
| `plan` | `cli/plan.go` | Generate fix plan from context |
| `review` | `cli/review.go` | Static code review (TODO, long lines) |
| `interactive` | `cli/interactive.go` | Multi-turn chat session |
| `session` | `cli/session_cmd.go` | USF session management |
| `checkpoint` | `cli/checkpoint.go` | Save/restore workspace state |
| `scan` | `cli/scan.go` | Health check (Ollama, models, RAM) |
| `init` | `cli/init.go` | Scaffold `.obot/` project directory |
| `index build` | `cli/index.go` | Build code search index |
| `search` / `symbols` | `cli/search.go` | Search indexed files and symbols |
| `config` | `cli/config_migrate.go` | Config migration and display |
| `stats` | `cli/stats.go` | Cost savings and performance metrics |
| `models` | `cli/stats.go` | List available Ollama models |
| `fs` | `cli/fs.go` | Filesystem helpers (write, delete) |
| `version` | `cli/version.go` | Version and build info |

## 3. Dependency Surface

### Go (runtime, 7 direct)

| Dependency | Version | Purpose |
|-----------|---------|---------|
| `github.com/spf13/cobra` | v1.8.0 | CLI framework |
| `github.com/fatih/color` | v1.16.0 | Terminal coloring |
| `github.com/pkoukk/tiktoken-go` | v0.1.8 | Token counting |
| `github.com/pmezard/go-difflib` | v1.0.0 | Unified diff generation |
| `github.com/PuerkitoBio/goquery` | v1.11.0 | HTML parsing for web fetch |
| `golang.org/x/text` | v0.34.0 | Text casing (title case in judge) |
| `gopkg.in/yaml.v3` | v3.0.1 | YAML config parsing |

### Swift (runtime, 2 direct)

| Dependency | Version | Purpose |
|-----------|---------|---------|
| `SwiftTerm` | 1.2.0+ | Terminal emulation |
| `Yams` | 5.0.0+ | YAML parsing (shared config) |

## 4. Configuration Surface

### Files

| Path | Format | Read by |
|------|--------|---------|
| `~/.config/ollamabot/config.yaml` | YAML | CLI (`config.LoadUnifiedConfig`), IDE (`SharedConfigService`) |
| `~/.config/obot/config.json` | JSON | CLI legacy fallback (`config.Load`) |
| `.obot/rules.obotrules` | Markdown | CLI (`obotrules.Parse`), IDE (`OBotService`) |

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `OBOT_MEM_GRAPH` | Set to `"0"` to disable memory graph (`internal/monitor/memory.go:55`) |
| `UPDATE_GOLDEN` | Set to `"true"` to regenerate golden test files (`internal/test/golden.go:22`) |

### CLI Flags (global)

`--verbose`, `--model`, `--ollama-url`, `--interactive`, `--quality`, `--mem-graph`, `--no-summary`, `--dry-run`, `--no-backup`, `--force`, `--print`, `--diff`, `--diff-context`, `--from-scan`, `--scope`, `--temperature`, `--max-tokens`, `--context-window`

## 5. Data Flow

### CLI Fix Path

```
User -> cmd/obot/main.go -> cli.Execute() -> root.PersistentPreRunE:
  config.Load() -> tier.NewManager() -> ollama.NewClient()
-> root.RunE -> runFix(cmd, args):
  analyzer.ReadFileContext() -> fixer.NewAgent(client) -> agent.Fix():
    ollama.Chat(prompt) -> parse response -> patch.Apply() -> backup + validate
```

### CLI Orchestration Path

```
User -> orchestrate subcommand:
  router.Classify(prompt) -> model.NewCoordinator(4 clients)
  -> orchestrate.NewOrchestrator() -> planner.BuildPlan()
  -> runOrchestrationLoop:
    for each schedule in [knowledge, plan, implement, scale, production]:
      for each process in [p1, p2, p3]:
        agent.Execute(model, prompt, tools) -> actions -> session.AddState()
  -> judge.Analyze() -> summary.Generate() -> session.Save()
```

### IDE Agent Path

```
User -> AgentView -> AgentExecutor.runAgentLoop():
  OllamaService.chatWithTools(model, messages, tools)
  -> parseToolCalls -> executeToolsParallel():
    CoreToolExecutor / AdvancedToolExecutor
    delegate_to_coder / researcher / vision -> OllamaService.generate()
  -> feed results back -> loop until complete
```

## 6. Determinism Risks

| Risk | Location | Impact |
|------|----------|--------|
| LLM output nondeterminism | All code paths through `ollama.Chat`/`Generate` | Fix/orchestration results vary per run |
| Temperature > 0 | Default 0.3 (`config.go:42`) | Adds sampling randomness |
| Concurrent expert analysis | `judge/coordinator.go:271-284` | goroutine scheduling order affects `Failures` slice order |
| Session ID generation | `session/manager.go` | Uses `time.Now().UnixNano()`, unique but not reproducible |
| Web search results | `tools/web.go` | DuckDuckGo results vary over time |

## 7. Observability

| Aspect | Implementation |
|--------|---------------|
| Logging | `fmt.Printf`/`fmt.Fprintf(os.Stderr)` via `printInfo`, `printError`, `printWarning` in `cli/root.go` |
| Metrics | `internal/telemetry/service.go` — local JSON at `~/.config/ollamabot/telemetry/stats.json` |
| Memory | `internal/monitor/memory.go` — runtime.ReadMemStats at 100ms intervals |
| Resource | `internal/resource/monitor.go` — memory/disk/token limit tracking |
| Structured errors | `internal/error/types.go` — `OrchestrationError` with codes E001-E015 |

No structured logging framework. No distributed tracing. No external metrics export.

## 8. Test State

| Package | Coverage | Notes |
|---------|----------|-------|
| actions | 100.0% | |
| router | 90.0% | |
| process | 85.7% | |
| telemetry | 85.6% | |
| obotrules | 78.3% | |
| scan | 70.0% | |
| resource | 68.5% | |
| fsutil | 65.5% | |
| mention | 64.5% | |
| version | 64.3% | |
| review | 61.8% | |
| session | 56.6% | |
| summary | 55.0% | |
| consultation | 51.7% | |
| patch | 49.0% | |
| test | 49.1% | |
| index | 45.1% | |
| planner | 38.3% | |
| model | 37.2% | |
| monitor | 34.4% | |
| ui | 28.1% | |
| tier | 24.7% | |
| agent | 22.4% | |
| context | 21.7% | |
| tools | 18.3% | |
| analyzer | 14.2% | |
| schedule | 14.3% | |
| fixer | 13.1% | |
| error | 8.3% | |
| delegation | 8.0% | |
| cli | 7.9% | |
| config | 6.9% | |
| stats | 6.0% | |
| ollama | 5.4% | |
| orchestrate | 3.9% | |
| git | 3.3% | |
| judge | 0.0% | Types only; coordinator needs Ollama |

**38/38 packages pass.** Weighted average coverage: ~30%. High-coverage packages are pure-logic; low-coverage packages depend on Ollama or filesystem.

## 9. Reproducibility

| Aspect | Status |
|--------|--------|
| Go dependencies pinned | Yes (`go.sum` lockfile) |
| Swift dependencies pinned | Semver ranges (`from: "1.2.0"`, `from: "5.0.0"`), `Package.resolved` gitignored |
| Go version specified | `go 1.24.0` in `go.mod` |
| Build command | `make build` — deterministic binary with ldflags |
| External runtime dependency | Ollama must be running at `localhost:11434` with models pulled |
| CI | None present |

## 10. Security Surface

| Surface | Risk | Mitigation |
|---------|------|------------|
| Ollama API | Unauthenticated HTTP on localhost | Local-only by default |
| GitHub/GitLab tokens | Read from plaintext files on disk | User-specified path; not env vars |
| Web fetch | Arbitrary URL access via agent tools | User-initiated only |
| Shell command execution | `run_command` agent tool executes arbitrary commands | Confirmation prompts in IDE; no guard in CLI orchestrate |
| File write | `write_file` agent tool can overwrite any file | Path validation in patch engine |
| IDE API keys | Stored in macOS Keychain | `kSecAttrAccessibleAfterFirstUnlock` |
| Telemetry | Local-only at `~/.config/ollamabot/telemetry/` | No external reporting |

## 11. Ranked Improvements

### P0 (Critical)

1. **No CI pipeline.** Zero automated verification on push. Build, test, and vet can regress silently.
2. **CLI `run_command` has no sandbox.** During orchestration, the agent can execute arbitrary shell commands without confirmation.

### P1 (Important)

3. **Judge package has 0% test coverage.** The `Coordinator.Analyze` flow is entirely untested.
4. **Ollama client has 5.4% coverage.** Core HTTP client largely untested.
5. **CLI package has 7.9% coverage.** Command wiring and flag parsing minimally tested.
6. **No structured logging.** `fmt.Printf` throughout makes debugging production issues difficult.
7. **Swift `Package.resolved` is gitignored.** IDE builds are not reproducible across machines.

### P2 (Nice to have)

8. **Weighted test coverage is ~30%.** Acceptable for early-stage, but packages below 20% should be targeted.
9. **No integration tests against a real Ollama instance.** All LLM-dependent paths are tested only via mocks or not at all.
10. **Session ID uses `time.Now().UnixNano()`.** Collision-safe but not cryptographically random.
11. **No rate limiting on web fetch.** Agent could make rapid requests to external sites.
