# obot CLI Master Plan (sonnet-3)
## Protocol-Native Harmonization — CLI Scope

**Agent:** sonnet-3 | **Product:** obot CLI (Go)
**Grounded in:** Actual source code analysis of 61 Go files
**Timeline:** 6 weeks to March 2026 release

---

## CLI Current State (Verified)

### Existing Strengths
- **5-Schedule Orchestration** framework (Knowledge, Plan, Implement, Scale, Production)
- **3-Process Navigation** with strict 1↔2↔3 rules
- **Flow code tracking** (S1P123S2P12...)
- **RAM-based tier detection** (5 tiers: 8GB through 64GB+)
- **Quality presets** (fast/balanced/thorough via --quality flag)
- **Session persistence** with bash-only restore scripts
- **Human consultation** with configurable timeouts and fallbacks
- **Cost/savings tracking** (tokens per model, vs-GPT4 comparison)

### Verified Gaps (What CLI Lacks)

**Critical finding from reading `internal/agent/agent.go`:**
The CLI agent is a **write-only executor** with exactly 12 actions:
```
CreateFile, DeleteFile, EditFile, RenameFile, MoveFile, CopyFile,
CreateDir, DeleteDir, RenameDir, MoveDir, CopyDir, RunCommand
```
It has **zero read operations**. The fixer engine reads files and feeds content as context. The agent cannot autonomously read, search, or browse.

**Additional gaps:**
- No multi-model delegation (single model per session)
- No token-budget context management (basic prompt building only)
- No intent routing (no keyword-based model selection)
- No web search tools
- No git integration tools
- Configuration at `~/.config/obot/config.json` (JSON, not shared YAML)
- No `.obotrules` or mention system support

---

## CLI Implementation Plan

### Week 1: Shared Configuration

**Goal:** Migrate from JSON config to shared YAML at `~/.config/ollamabot/config.yaml`.

**Modified Files:**
- `internal/config/config.go` — Replace JSON parsing with YAML (gopkg.in/yaml.v3)
  - Change `getConfigDir()` to return `~/.config/ollamabot/`
  - Read unified config schema with model registry, quality presets, orchestration settings
  - Preserve all existing config fields during migration

**New Files:**
- `internal/config/migrate.go` — Automatic migration
  - Detect old `~/.config/obot/config.json`
  - Convert JSON fields to YAML equivalents
  - Create symlink: `~/.config/obot/` → `~/.config/ollamabot/`
  - Run once on first launch, idempotent thereafter

- `internal/config/schema.go` — Schema validation
  - Validate config.yaml against JSON Schema
  - Report clear errors for invalid configuration
  - Use `github.com/xeipuuv/gojsonschema`

**Validation:**
- `obot fix` works identically before and after migration
- Old config.json settings preserved in new config.yaml
- Symlink allows old paths to continue working

### Week 2: Context Management (Highest Leverage Change)

**Goal:** Port IDE's sophisticated context management to Go.

**New Files:**
- `internal/context/manager.go` — Token-budget-aware context builder
  - Budget allocation: task 25%, files 33%, project 16%, history 12%, memory 12%, errors 6%
  - Dynamic reallocation when categories underuse their budget
  - Token counting via `github.com/pkoukk/tiktoken-go` (pure Go, zero FFI)

- `internal/context/compression.go` — Semantic truncation
  - Preserve: import statements, export statements, type/class/interface definitions, function signatures, error comments, TODO/FIXME markers
  - Truncate: function bodies, test fixtures, comments, whitespace
  - Compression ratio target: 0.3 (30% of original)

- `internal/router/intent.go` — Keyword-based intent classification
  - Coding: implement, fix, refactor, debug, optimize, test, code
  - Research: what, why, how, explain, compare, research, find
  - Writing: write, document, create, draft, generate
  - Vision: image, screenshot, analyze, describe, visual, diagram
  - Route to appropriate model role based on detected intent

**Modified Files:**
- `internal/tier/models.go` — Read tier-to-model mappings from shared config instead of hardcoded switch statement
- `internal/fixer/prompts.go` — Use ContextManager for prompt building instead of inline string concatenation

**Validation:**
- Context build time <500ms for 500-file project
- Token counts accurate within 5% of tiktoken reference
- Intent routing selects correct model for test prompts

### Week 3: Multi-Model & Autonomous Tools (Biggest Feature Port)

**Goal:** Add multi-model delegation and read/search capabilities to CLI agent.

**New Files:**
- `internal/agent/delegation.go` — Multi-model delegation
  - `delegate.coder`: Route task to coder model (qwen2.5-coder)
  - `delegate.researcher`: Route task to researcher model (command-r)
  - `delegate.vision`: Route task to vision model (qwen3-vl) with image path
  - Each delegation: create new Ollama chat, inject task context, return result
  - Fallback chain: if preferred model unavailable, try tier-appropriate alternative

**Modified Files:**
- `internal/agent/agent.go` — Add Tier 2 autonomous tools
  - `ReadFile(path string) string` — Read and return file contents
  - `SearchFiles(query string, dir string) []Match` — Grep-style search across project
  - `ListDirectory(path string) []Entry` — Directory listing with file types
  - Keep existing 12 Tier 1 executor tools unchanged

- `internal/model/coordinator.go` — Enhance for 4 model roles
  - Current: single model selection based on RAM tier
  - New: maintain model instances for orchestrator, coder, researcher, vision roles
  - Lazy initialization: only load models when first needed
  - RAM-aware: skip roles whose models exceed available memory

**Critical Note:** The CLI agent transitions from write-only executor to read-write autonomous system. This is the single most impactful architectural change. Tier 1 tools remain backward compatible; Tier 2 tools are additive.

**Validation:**
- `obot fix` still works with only Tier 1 tools (backward compat)
- Delegation to coder/researcher produces coherent results
- ReadFile/SearchFiles return correct content
- RAM detection prevents loading models that won't fit

### Week 4: Feature Parity

**New Files:**
- `internal/tools/web.go` — Web search integration
  - DuckDuckGo HTML search (no API key required)
  - Parse top 5 results: title, URL, snippet
  - Fetch URL content with HTML-to-text conversion
  - Rate limiting: 1 request per second

- `internal/tools/git.go` — Git integration tools
  - `git.status`: Run `git status --porcelain`, parse output
  - `git.diff`: Run `git diff`, return structured output
  - `git.commit`: Stage specified files, create commit with message
  - All operations validate working directory is a git repo

**Modified Files:**
- `internal/orchestrate/orchestrator.go` — Wire new tools into orchestration processes
  - Knowledge schedule: allow web.search, file.read
  - Plan schedule: allow think, consult.human
  - Implement schedule: allow all file tools + delegation
  - Scale schedule: allow run_command for benchmarks
  - Production schedule: allow git.commit for final commits

**Validation:**
- Web search returns relevant results for coding queries
- Git tools work correctly in both clean and dirty repos
- Orchestrator correctly restricts tools per schedule

### Week 5: Session Portability

**New Files:**
- `internal/session/unified.go` — USF v2.0 serialization
  - Serialize: session metadata, orchestration state, execution steps, context snapshot, checkpoints
  - Deserialize: validate against JSON schema, populate session state
  - Location: `~/.config/ollamabot/sessions/{id}.json`

- `internal/cli/checkpoint.go` — Checkpoint commands
  - `obot checkpoint save <name>` — Snapshot current state
  - `obot checkpoint restore <id>` — Restore to checkpoint
  - `obot checkpoint list` — List available checkpoints
  - `obot session export` — Export current session as USF JSON
  - `obot session import <path>` — Import IDE-created session

**Modified Files:**
- `internal/session/session.go` — Update serialization to USF format
  - Add flow_code, schedule_counts, navigation_history, model_usage fields
  - Backward-compatible: read old format, write new format

**Validation:**
- Session created in IDE loads in CLI with full orchestration state
- Checkpoint save/restore preserves all state correctly
- Export/import round-trip: CLI → IDE → CLI preserves all data

### Week 6: Polish & Release

- Package consolidation: 27 packages → 12 packages
  - Merge: actions→agent, analyzer→fixer, model→ollama, tier→config
  - Remove: unused utility packages
- Integration tests for schema compliance
- Performance validation (no regression >5%)
- Documentation: unified CLI reference with new commands
- Release build and packaging

---

## Success Criteria (CLI)

### Must-Have for March
- [ ] Reads shared `config.yaml` (YAML, not JSON)
- [ ] Token-budget context management
- [ ] Multi-model delegation (coder, researcher, vision)
- [ ] ReadFile + SearchFiles tools (Tier 2)
- [ ] Web search tool
- [ ] Git integration tools
- [ ] Session export to USF format
- [ ] Session import from IDE-created USF
- [ ] Checkpoint save/restore/list commands

### Performance Gates
- Config loading: <50ms additional overhead
- Context build: <500ms for 500-file project
- Token counting: <10ms per file
- Session save/load: <200ms
- No regression >5% in `obot fix` performance

### Quality Gates
- All schemas validate against JSON Schema
- Session round-trip preserves all data
- Backward compatibility: old config.json auto-migrated
- Tier 1 tools unchanged (12 executor actions)
- RAM detection prevents OOM from model loading

---

## Architectural Decisions (Code-Grounded)

### Why NOT CLI-as-Server
The orchestrator (`internal/orchestrate/orchestrator.go`) uses Go closure callbacks:
```go
func (o *Orchestrator) Run(ctx context.Context,
    selectScheduleFn func(context.Context) (ScheduleID, error),
    selectProcessFn  func(context.Context, ScheduleID, ProcessID) (ProcessID, bool, error),
    executeProcessFn func(context.Context, ScheduleID, ProcessID) error,
) error
```
These are not serializable over JSON-RPC. Wrapping this in a server requires refactoring every callback into request-response pairs — a multi-week rewrite during a March release window. Instead: share behavioral contracts, implement natively in each platform.

### Why NOT Rust FFI
Token counting currently uses `content.count / 4` heuristic in Swift. CLI does not count tokens at all. The bottleneck is Ollama inference (2-10s per call), not token counting (<10ms). Pure Go (`tiktoken-go`) and pure Swift equivalents ship in days with zero FFI complexity.

### Why Two Tool Tiers
CLI agent has 12 write-only actions. IDE agent has 18 read-write tools. Forcing "22 unified tools" on CLI means adding 10+ tools simultaneously — high risk. Instead: define Tier 1 (existing executor tools) and Tier 2 (new autonomous tools). Add Tier 2 incrementally. Ship what's ready for March, complete parity in v2.1.
