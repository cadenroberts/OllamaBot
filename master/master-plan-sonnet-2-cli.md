# Master Plan: sonnet-2 — obot CLI

**Agent:** sonnet-2  
**Product:** obot CLI (Go)  
**Recovery Date:** 2026-02-06  

---

## Verified Artifacts Produced

| File | Bytes | Content |
|------|-------|---------|
| internal/harmony/config.go | 10,442 | Unified YAML config with XDG paths, legacy migration, backward-compat symlink |
| internal/harmony/models.go | 7,382 | 5 hardware tiers, 4 model roles, intent routing, tier-aware resolution |
| internal/harmony/tools.go | 11,682 | 22-tool registry with Tier1/Tier2 distinction, gap analysis, legacy mapping |
| internal/harmony/session.go | 7,335 | USF session persistence, cross-product JSON serialization |
| internal/harmony/orchestration.go | 4,034 | UOP types, navigation validation, termination prerequisites |

**Build:** `go build ./internal/harmony/...` PASS. `go vet ./internal/harmony/...` PASS. `go build ./...` PASS.

## Package: internal/harmony

### config.go

- `UnifiedConfig` struct — full UC v1.0 schema with nested sections: OllamaConfig, ModelConfig, GenerationConfig, QualityConfig (with presets map), AgentConfig, ContextConfig, SessionConfig, OrchestrationConfig, IDEConfig, CLIConfig.
- `DefaultUnifiedConfig()` — returns defaults matching UC v1.0 specification.
- `ConfigPaths()` — returns search order: project-local `.obot/config.yaml` > XDG `~/.config/ollamabot/config.yaml` > legacy `~/.config/obot/config.yaml` > fallback `~/.obot/config.yaml`.
- `LoadUnifiedConfig()` — tries each path, returns first valid config with source path.
- `SaveUnifiedConfig()` — writes YAML with header comment to specified path.
- `MigrateFromLegacy()` — reads `~/.config/obot/config.json`, maps fields to UnifiedConfig.
- `EnsureBackwardCompatSymlink()` — creates `~/.config/obot` -> `~/.config/ollamabot` symlink if legacy path does not exist as real directory.
- `LegacyConfigPath()` — returns `~/.config/obot/config.json`.
- `GlobalConfigPath()` — returns `~/.config/ollamabot/config.yaml`.

### models.go

- `ModelRole` type — RoleOrchestrator, RoleCoder, RoleResearcher, RoleVision.
- `TierID` type — TierMinimal, TierCompact, TierBalanced, TierPerformance, TierAdvanced.
- `TierSpec` struct — ID, MinRAMGB, MaxRAMGB, Orchestrator/Coder/Researcher/Vision ModelSpec, ContextWindow, Description.
- `UnifiedTiers` slice — 5 entries with concrete model tags per role per tier.
- `DetectTier()` — reads system RAM, returns TierID.
- `TierFromRAM(ramGB)` — pure function: >=64 advanced, >=32 performance, >=24 balanced, >=16 compact, else minimal.
- `GetModelForRole(tierID, role)` — returns Ollama model tag.
- `ResolveModels(cfg)` — applies config overrides on top of tier defaults, returns map[ModelRole]string.
- `IntentRoute(input, hasImage, hasCodeContext)` — priority: vision (if image) > coder (if code keywords + context) > researcher (if research keywords) > coder (if code keywords alone) > orchestrator (default).

### tools.go

- `ToolID` type — 22 string constants (core.think through git.commit).
- `ToolTier` type — `Tier1Executor` (file mutations + commands, what CLI has today) and `Tier2Autonomous` (read/search/delegate/web/git, what IDE has and CLI needs).
- `ImplementationStatus` type — StatusImplemented, StatusMissing, StatusPartial.
- `ToolDefinition` struct — ID, Name, Category, Priority, Tier, Description, HasSideEffects, CLIStatus, IDEStatus.
- `UnifiedToolRegistry` slice — 22 entries with accurate CLIStatus/IDEStatus reflecting actual source code analysis.
- `ToolGapAnalysis()` — returns (cliMissing, ideMissing) slices.
- `Tier1Tools()` / `Tier2Tools()` — filter by tier.
- `GetToolByID()` / `GetToolsByCategory()` / `GetToolsByPriority()` — lookup functions.
- `MapLegacyAction(legacyAction)` — maps old ActionType strings to canonical ToolID.

### session.go

- `UnifiedSession` struct — USF v1.0: ID, CreatedAt, UpdatedAt, Platform, Prompt, Orchestration (state, current schedule/process, flow code, schedule counts), States (linked list with prev/next, files hash, action IDs), Actions (tool ID, params, result, duration), Notes (content, source, reviewed), Stats, Checkpoints.
- `NewSession(prompt, platform)` — creates session with generated ID and initialized maps.
- `SessionDir(sessionID)` — returns `~/.obot/sessions/{id}`.
- `SaveSession(session)` — writes `session.json` + `flow.txt` to session dir.
- `LoadSession(sessionID)` — reads and unmarshals `session.json`.
- `ListSessions()` — scans `~/.obot/sessions/` directory.
- `AddAction(toolID, params, result, durationMS)` — appends action, increments stat counters.
- `AddNote(content, source)` — appends note.

### orchestration.go

- `ScheduleID` type — constants 1-5 (Knowledge, Plan, Implement, Scale, Production).
- `ProcessID` type — constants 1-3.
- `ScheduleName(id)` / `ProcessName(schedule, process)` — display name lookups.
- `PrimaryModel(schedule)` — Knowledge uses Researcher, all others use Coder.
- `ConsultType` type — ConsultNone, ConsultOptional (Plan/P2), ConsultMandatory (Implement/P3).
- `ConsultationRequired(schedule, process)` — returns consultation type.
- `IsValidNavigation(from, to)` — enforces 1-2-3 adjacency: from 0 only to P1; from P1 to P1/P2; from P2 to P1/P2/P3; from P3 to P2/P3/terminate(0).
- `CanTerminatePrompt(scheduleCounts, lastSchedule)` — all 5 schedules must have run at least once AND last schedule must be Production.
- `AllScheduleIDs()` / `AllProcessIDs()` — ordered slices.

## CLI-Specific Harmonization Items

### What the CLI gained via harmony package
- Multi-model awareness — 4 model roles instead of 1 coder model per tier.
- Intent routing — keyword-based model selection previously only in IDE.
- Unified config — YAML format replacing JSON, XDG-compliant path, migration from legacy.
- Session persistence in portable JSON — previously used bash restore scripts.
- Tool gap tracking — explicit acknowledgment of which Tier 2 tools need porting.

### What the CLI retains uniquely
- 5-schedule orchestration engine (internal/orchestrate/) — the canonical implementation.
- Flow code tracking (internal/orchestrate/flowcode.go).
- Quality presets (fast/balanced/thorough) via --quality flag.
- Cost savings tracking (internal/stats/).
- Memory visualization (internal/ui/memory.go).
- Human consultation with AI fallback (internal/consultation/handler.go).
- LLM-as-judge analysis (internal/judge/judge.go).

### CLI tool gap (Tier 2 migration needed)
The CLI agent (internal/agent/agent.go) is write-only with 12 mutation actions. The following Tier 2 tools are implemented in the IDE but missing from CLI:

| Tool | UTR ID | Status |
|------|--------|--------|
| think | core.think | Missing |
| ask_user | core.ask_user | Missing |
| read_file | file.read | Missing (fixer engine reads, not agent) |
| search_files | file.search | Missing |
| list_directory | file.list | Missing |
| delegate_to_coder | delegate.coder | Missing |
| delegate_to_researcher | delegate.researcher | Missing |
| delegate_to_vision | delegate.vision | Missing |
| web_search | web.search | Missing |
| fetch_url | web.fetch | Missing |
| git_status | git.status | Missing |
| git_diff | git.diff | Missing |
| git_commit | git.commit | Missing |
| take_screenshot | system.screenshot | Missing |

### CLI constraint acknowledged
The orchestrator's `Run()` method uses closure-injected callbacks (`selectScheduleFn`, `selectProcessFn`, `executeProcessFn`). These are not serializable for JSON-RPC. CLI-as-server requires refactoring callbacks into request-response pairs — deferred to post-March v2.0.

## Architectural Position

Protocols over code. The CLI implements the 6 Unified Protocols natively in Go via the internal/harmony package. No Rust FFI, no shared binaries. The harmony package coexists with existing internal packages (orchestrate, agent, config, tier) and provides the cross-product contract layer. Existing CLI functionality is not disrupted.

---

*sonnet-2 | CLI master plan | 5 Go artifacts verified on disk, build passing*
