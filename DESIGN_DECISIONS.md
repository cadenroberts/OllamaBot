# Design Decisions

## ADR-001: Four Specialized Models Instead of One General Model

**Context:** The system needs to handle diverse tasks: planning, code generation, research, and image analysis. A single large model can do all of these, but with varying quality.

**Decision:** Use four separate 32B-parameter models, each with a role-specific system prompt and temperature:
- Qwen3 32B as Orchestrator (planning, delegation).
- Qwen2.5-Coder 32B as Coder (code generation, debugging).
- Command-R 35B as Researcher (RAG, documentation).
- Qwen3-VL 32B as Vision (image analysis).

The Orchestrator delegates via `delegate_to_coder`, `delegate_to_researcher`, `delegate_to_vision` tool calls. See `Sources/Agent/AgentExecutor.swift` (IDE) and `internal/agent/types.go` (CLI) for delegation types.

**Consequences:**
- Requires ~32GB VRAM to keep all models loaded. Systems with 16GB must use reduced configurations.
- Each specialist produces higher-quality output in its domain than a generalist would.
- The Orchestrator must correctly classify tasks for delegation. Misrouting degrades results.
- Model loading/unloading between delegations adds latency (~30s per cold model swap).

---

## ADR-002: Separate Swift IDE and Go CLI Codebases

**Context:** The project needs both a native macOS IDE and a cross-platform CLI. Options considered: (a) shared Rust core with FFI bindings, (b) CLI-as-server with JSON-RPC, (c) separate codebases with shared configuration and session formats.

**Decision:** Option (c) — separate codebases. The Swift IDE uses SwiftUI and native frameworks. The Go CLI uses Cobra. They share data via:
- Unified Configuration at `~/.config/ollamabot/config.yaml` (`internal/config/unified.go`, `Sources/Services/SharedConfigService.swift`).
- Unified Session Format (USF) for cross-platform session export/import (`internal/session/usf.go`, `Sources/Services/UnifiedSessionService.swift`).

**Consequences:**
- Feature parity requires manual effort. New CLI features must be independently implemented in Swift.
- No shared runtime means no shared bugs, but also no shared optimizations.
- The shared YAML config acts as the contract. Schema changes must be coordinated across both codebases.
- A JSON-RPC bridge (option b) is planned for v2.0 to enable tighter integration. See `IMPLEMENTATION_PLAN.md` section 19.2.

---

## ADR-003: 5-Schedule x 3-Process Orchestration Model

**Context:** Autonomous code generation needs structure to avoid unbounded agent loops. The system needs to progress through distinct phases (research, planning, implementation, scaling, production hardening).

**Decision:** Implement the Unified Orchestration Protocol (UOP) with 5 named schedules (Knowledge, Plan, Implement, Scale, Production), each containing 3 sequential processes. Navigation within a schedule is constrained: P1 <-> P2 <-> P3 (no skipping). See `internal/orchestrate/types.go` for `ScheduleID` and `ProcessID` types, `internal/orchestrate/orchestrator.go` for the state machine.

**Consequences:**
- The navigation constraint (P1 cannot jump to P3) forces the agent through intermediate steps, reducing hallucinated shortcuts.
- Termination requires all 5 schedules to have run at least once and the final schedule to be Production. This prevents premature completion.
- The structure adds overhead for simple tasks that do not need 5 schedules. The CLI `--quality fast` preset bypasses orchestration entirely.
- Flow codes (e.g., `S1P123S2P12`) provide a compact audit trail for debugging orchestration behavior.

---

## ADR-004: Local-Only Telemetry and Session Storage

**Context:** The system tracks usage metrics (tokens processed, time spent, patch success rates) and session state. These could be stored remotely for analytics or locally for privacy.

**Decision:** All data is stored locally:
- Telemetry: `~/.config/ollamabot/telemetry/stats.json` (`internal/telemetry/service.go`).
- Sessions: `~/.config/ollamabot/sessions/` (`internal/session/manager.go`).
- IDE API keys: macOS Keychain via `SecItemAdd`/`SecItemCopyMatching` (`Sources/Services/APIKeyStore.swift`).

No data is sent to external servers. The `OBOT_MEM_GRAPH` environment variable can disable even the in-process memory graph.

**Consequences:**
- Complete privacy. No usage data leaves the machine.
- No aggregate analytics across users. Cannot measure adoption, common failure modes, or usage patterns at scale.
- Session files accumulate on disk. No automatic cleanup or rotation is implemented.
- Cost savings calculations (`obot stats --saved`) use hardcoded API pricing that may become stale.

---

## ADR-005: Frame-Coalesced Streaming for IDE Rendering

**Context:** LLM streaming produces ~60 tokens/second. Naive implementation updates SwiftUI `@Observable` state on every token, causing 60 re-renders/second and choppy scrolling.

**Decision:** Buffer tokens and flush to the UI at 30fps (every 33ms) using `CACurrentMediaTime()`. See `Sources/Services/OllamaService.swift` for the streaming implementation. Additional optimizations:
- `Equatable` conformance on `MessageRow` to skip unnecessary diffs.
- Cached markdown parsing that only re-parses on content change.
- Server-side token buffering (~50 chars before yielding).

**Consequences:**
- Smooth scrolling during streaming. UI remains responsive.
- 33ms latency between token arrival and display. Imperceptible to users.
- Adds complexity to the streaming pipeline. Debug logging must account for the buffer.

---

## ADR-006: Cobra for CLI Framework

**Context:** The CLI needs subcommands (`fix`, `orchestrate`, `plan`, `review`, `session`, `checkpoint`, etc.), persistent flags, and help generation. Options considered: (a) stdlib `flag` package, (b) `urfave/cli`, (c) `spf13/cobra`.

**Decision:** Cobra (`github.com/spf13/cobra` v1.8.0). See `internal/cli/root.go` for the root command and `PersistentPreRunE` setup.

**Consequences:**
- Automatic help generation, shell completions, and flag parsing.
- `PersistentPreRunE` provides a single initialization point for config, Ollama client, and tier manager.
- Cobra is a well-maintained dependency with minimal API surface risk.
- The root command doubles as the `fix` command (when args are provided but do not match a subcommand). This is a Cobra-idiomatic pattern but can confuse users who mistype subcommand names.

---

## ADR-007: Unified YAML Configuration with Legacy JSON Migration

**Context:** The CLI originally used `~/.config/obot/config.json`. The IDE had separate `UserDefaults`. Sharing configuration required a common format.

**Decision:** Migrate to `~/.config/ollamabot/config.yaml` as the single source of truth for both platforms. The CLI provides `obot config migrate` to convert legacy JSON. A symlink from `~/.config/obot/` to `~/.config/ollamabot/` preserves backward compatibility. See `internal/config/unified.go` and `docs/protocols/UC.md`.

**Consequences:**
- Both platforms read the same config file. Changes in the IDE (via `SharedConfigService` file watcher) are visible to the CLI on next startup.
- YAML is more readable than JSON for human-edited configuration.
- The migration path is one-way (JSON to YAML). The legacy JSON loader remains as a fallback.
- IDE-specific UI preferences (editor font, sidebar width) remain in `UserDefaults` via `ConfigurationService.swift`. Only model/orchestration/quality settings are in the shared YAML.

---

## ADR-008: LLM-as-Judge Quality Assessment

**Context:** After orchestration completes, the system needs to assess output quality. Static analysis (linting, tests) catches syntactic issues but not semantic quality (did the agent actually fulfill the prompt?).

**Decision:** Implement a 4-expert LLM-as-Judge panel (`internal/judge/coordinator.go`). Three specialist models (Coder, Researcher, Vision) independently analyze the session. The Orchestrator model synthesizes their analyses into a TLDR with scores (PROMPT_ADHERENCE 0-100, PROJECT_QUALITY 0-100) and a quality assessment (ACCEPTABLE / NEEDS_IMPROVEMENT / EXCEPTIONAL).

**Consequences:**
- Catches semantic quality issues that static analysis misses.
- Requires 4 sequential LLM calls post-orchestration. Adds ~2-5 minutes to total runtime.
- The judge is itself an LLM and can hallucinate scores. No ground-truth validation exists.
- Expert analysis runs concurrently (goroutines in `Analyze()`) but synthesis is sequential.
- Currently 0% test coverage. The coordinator depends on Ollama for all functionality.
