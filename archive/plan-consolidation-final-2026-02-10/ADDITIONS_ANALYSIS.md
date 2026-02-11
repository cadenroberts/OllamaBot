# Additional Items Analysis
**Generated:** 2026-02-10  
**Source:** UNIFIED_IMPLEMENTATION_PLAN.md + SCALING_PLAN.md  
**Comparison Against:** plan.md (consolidated)

---

## UNIFIED_IMPLEMENTATION_PLAN.md ANALYSIS

### Items Already in plan.md ✅
All major items from UNIFIED_IMPLEMENTATION_PLAN.md are already covered in the consolidated plan.md:
- **6 Unified Protocols** - Documented extensively (UOP, UTR, UCP, UMC, UC, USF)
- **CLI Implementation Track** - CLI-01 through CLI-10 all covered
- **IDE Implementation Track** - IDE-01 through IDE-08 all covered
- **Cross-Platform Integration** - Covered in session portability sections
- **Testing & Validation** - Covered in Section 11
- **Migration & Deployment** - Covered in Section 13 and Section 17

### Unique Items NOT in plan.md ⚠️

**NONE** - The UNIFIED_IMPLEMENTATION_PLAN.md is 100% redundant with plan.md. It was one of the source documents used to create the original unimplemented plans that were then consolidated.

**Recommendation:** Archive UNIFIED_IMPLEMENTATION_PLAN.md (redundant)

---

## SCALING_PLAN.md ANALYSIS

### Items Already in plan.md ✅
- **Multi-Model Routing** - Covered (items #59-68)
- **Diff and Patch Strategy** - Covered (items #48-52, #244)
- **Context Strategy** - Covered (items #209-214)
- **Testing Strategy** - Covered (items #197-208)
- **Performance Targets** - Covered in performance testing section

### Unique Items NOT in plan.md ⚠️

The following items from SCALING_PLAN.md represent distinct features that are NOT covered in the consolidated plan:

#### 1. **Repository Index System** (SCALING §Core Modules)
**Lines:** 37-39  
**Feature:** Fast file index, language map, optional embeddings for semantic search

**Missing Components:**
- `internal/index/builder.go` - Build file index on demand
- `internal/index/search.go` - Fast file/symbol search
- `internal/index/embeddings.go` - Optional semantic embeddings
- `internal/index/language.go` - Language detection and stats

**Why Missing:** Orchestration plans assume agent uses tools (file.search, file.list) but don't specify a dedicated indexing subsystem.

**Should Add:** YES - This is a distinct feature for performance optimization

---

#### 2. **Planner Module** (SCALING §Core Modules)
**Lines:** 40  
**Feature:** Task decomposition, change planning, risk labeling BEFORE execution

**Missing Components:**
- `internal/planner/decompose.go` - Break complex tasks into subtasks
- `internal/planner/sequence.go` - Determine optimal execution order
- `internal/planner/risk.go` - Label changes by risk (safe/moderate/high)

**Why Missing:** Orchestration plans have "Plan" schedule (items #23-26) but not a separate planning module that runs before any schedule starts.

**Should Add:** YES - This is pre-orchestration planning logic

---

#### 3. **Patch Engine with Rollback** (SCALING §Diff and Patch Strategy)
**Lines:** 63-68  
**Feature:** Atomic patch application with backup and rollback

**Missing Components:**
- `internal/patch/apply.go` - Atomic patch application
- `internal/patch/backup.go` - Create backup before patching
- `internal/patch/rollback.go` - Rollback on failure
- `internal/patch/validate.go` - Pre-patch validation (checksum, conflicts)

**Why Missing:** Orchestration plans have diff generation (items #48-52) but not a dedicated patch engine with safety features.

**Current in plan.md:** Only diff generation, not patch application safety

**Should Add:** YES - This is a critical safety feature

---

#### 4. **Review Module** (SCALING §Core Modules)
**Lines:** 43  
**Feature:** Lint, test runner integration, static checks, diff summaries

**Missing Components:**
- `internal/review/lint.go` - Integrate with language linters
- `internal/review/test.go` - Run test suites automatically
- `internal/review/static.go` - Static analysis checks
- `internal/review/summary.go` - Generate human-readable summaries

**Why Missing:** Orchestration plans have Verify process (item #26) but it's part of the schedule, not a standalone review module.

**Current in plan.md:** Item #26 (Verify process) runs tests/lint/build, but no standalone review module

**Should Add:** MAYBE - This could be a refactoring of existing Verify logic into a reusable module

---

#### 5. **Interactive TUI Mode** (SCALING §Core Modules, §North Star Flows)
**Lines:** 14-17, 119-122  
**Feature:** Interactive terminal UI with chat loop, history, diff preview, quick apply

**Missing Components:**
- `internal/cli/interactive.go` - Interactive TUI mode
- `internal/ui/chat.go` - Chat loop with history
- `internal/ui/preview.go` - Diff preview before apply
- `internal/ui/history.go` - Command/edit history navigation

**Why Missing:** Orchestration plans focus on status display (items #69-73) for orchestration mode, not interactive chat mode.

**Current in plan.md:** Terminal UI (items #86-95) but not interactive chat-style TUI

**Should Add:** YES - This is a distinct UX mode (obot interactive vs obot orchestrate)

---

#### 6. **Project Health Scan** (SCALING §North Star Flows)
**Lines:** 17  
**Feature:** Scan repo for issues, generate prioritized fix list

**Missing Components:**
- `internal/scan/health.go` - Project health scanner
- `internal/scan/issues.go` - Issue detection and prioritization
- `internal/scan/suggest.go` - Fix suggestions

**Why Missing:** Orchestration plans focus on executing user prompts, not autonomous project scanning.

**Should Add:** YES - This is a distinct feature (obot scan command)

---

#### 7. **Plugin System** (SCALING §Roadmap Phase 4)
**Lines:** 125-127  
**Feature:** Plugin system for tools and custom workflows

**Missing Components:**
- `internal/plugin/loader.go` - Plugin discovery and loading
- `internal/plugin/interface.go` - Plugin API
- `internal/plugin/registry.go` - Plugin registry

**Why Missing:** Orchestration plans mention plugin hooks (item #265 "Open Questions") but don't specify implementation.

**Current in plan.md:** Item #265 asks "Plugin System - Hooks for plugins/extensions?"

**Should Add:** DEFERRED - Phase 4 feature, post-v1.0

---

#### 8. **Telemetry System** (SCALING §Core Modules)
**Lines:** 45  
**Feature:** Local stats, cost savings, performance metrics

**Missing Components:**
- `internal/telemetry/tracker.go` - Local-only telemetry
- `internal/telemetry/savings.go` - Cost savings calculator
- `internal/telemetry/performance.go` - Performance metrics

**Why Missing:** Orchestration plans have resource monitoring (items #164-175) and cost tracking for IDE (item #242), but not a unified telemetry system.

**Current in plan.md:** Item #242 (IDE cost tracking only), items #164-175 (resource monitoring)

**Should Add:** YES - Unify as cross-platform telemetry system

---

## RECOMMENDATION

### Items to ADD to plan.md:

1. **Repository Index System** (~500 LOC) - Performance optimization
2. **Pre-Orchestration Planner** (~400 LOC) - Task decomposition before scheduling
3. **Patch Engine with Safety** (~600 LOC) - Atomic patches with rollback
4. **Interactive TUI Mode** (~800 LOC) - Chat-style interface
5. **Project Health Scanner** (~400 LOC) - Autonomous issue detection
6. **Unified Telemetry System** (~300 LOC) - Cross-platform stats/savings

**Total:** ~3,000 LOC of new features

### Items to DEFER:

7. **Plugin System** - Phase 4, post-v1.0 (item #265 already notes this)

### Items to DELETE/ARCHIVE:

- **UNIFIED_IMPLEMENTATION_PLAN.md** - 100% redundant with plan.md, should be archived
- **SCALING_PLAN.md** - After extracting 6 unique items above, can be archived

---

## DETAILED ADDITIONS TO plan.md

### NEW SECTION 22: ADVANCED CLI FEATURES (SCALING PLAN)

#### 22.1 Repository Index System
**Status:** New feature  
**Source:** SCALING_PLAN.md lines 37-39  
**Estimated LOC:** ~500

**Items:**
278. **Index Builder** - Fast file index on demand, language detection, file statistics
279. **Symbol Search** - Search for functions, classes, types across project
280. **Semantic Search** - Optional embedding-based semantic search (requires local embedding model)
281. **Language Map** - Per-language file counts and statistics

**Files to Create:**
- `internal/index/builder.go` (~200 LOC)
- `internal/index/search.go` (~150 LOC)
- `internal/index/embeddings.go` (~100 LOC)
- `internal/index/language.go` (~50 LOC)

**Commands:**
- `obot index build` - Build/rebuild index
- `obot search "query"` - Search indexed files
- `obot search --symbols "FunctionName"` - Symbol search

---

#### 22.2 Pre-Orchestration Planner
**Status:** New feature  
**Source:** SCALING_PLAN.md line 40  
**Estimated LOC:** ~400

**Items:**
282. **Task Decomposer** - Break complex prompts into subtasks before orchestration starts
283. **Change Sequencer** - Determine optimal order for multi-file changes
284. **Risk Labeler** - Label changes as safe/moderate/high risk

**Files to Create:**
- `internal/planner/decompose.go` (~150 LOC)
- `internal/planner/sequence.go` (~150 LOC)
- `internal/planner/risk.go` (~100 LOC)

**Integration:**
- Runs BEFORE orchestration starts
- Outputs: subtasks, sequence, risk labels
- Feeds into Knowledge → Plan schedules

---

#### 22.3 Patch Engine with Safety
**Status:** Enhancement of existing diff system  
**Source:** SCALING_PLAN.md lines 63-68  
**Estimated LOC:** ~600

**Items:**
285. **Atomic Patch Apply** - Apply patches transactionally (all or nothing)
286. **Pre-Apply Backup** - Create backup before any patch
287. **Rollback on Failure** - Automatic rollback if patch fails
288. **Patch Validation** - Checksum verification, conflict detection
289. **Dry-Run Mode** - Show what would change without applying

**Files to Create:**
- `internal/patch/apply.go` (~200 LOC)
- `internal/patch/backup.go` (~150 LOC)
- `internal/patch/rollback.go` (~150 LOC)
- `internal/patch/validate.go` (~100 LOC)

**Flags:**
- `--dry-run` - Show changes without applying
- `--no-backup` - Skip backup creation (power user)
- `--force` - Apply even if validation warnings

---

#### 22.4 Interactive TUI Mode
**Status:** New UX mode  
**Source:** SCALING_PLAN.md lines 14-17, 119-122  
**Estimated LOC:** ~800

**Items:**
290. **Interactive Chat Mode** - Chat-style interface with history
291. **Diff Preview Widget** - Show diffs before applying
292. **Quick Apply/Discard** - Keyboard shortcuts for fast decisions
293. **Command History** - Navigate previous commands and edits
294. **Session Resume** - Resume from any point in history

**Files to Create:**
- `internal/cli/interactive.go` (~300 LOC)
- `internal/ui/chat.go` (~200 LOC)
- `internal/ui/preview.go` (~150 LOC)
- `internal/ui/history.go` (~150 LOC)

**Commands:**
- `obot interactive` or `obot -i` - Start interactive mode
- Within TUI: `/apply`, `/discard`, `/history`, `/undo`

---

#### 22.5 Project Health Scanner
**Status:** New feature  
**Source:** SCALING_PLAN.md line 17  
**Estimated LOC:** ~400

**Items:**
295. **Health Scanner** - Scan repo for issues (unused imports, TODO comments, test coverage gaps, security issues)
296. **Issue Prioritizer** - Rank issues by severity and fix cost
297. **Fix Suggester** - Generate fix suggestions for detected issues
298. **Report Generator** - HTML/markdown health report

**Files to Create:**
- `internal/scan/health.go` (~150 LOC)
- `internal/scan/issues.go` (~150 LOC)
- `internal/scan/suggest.go` (~100 LOC)

**Commands:**
- `obot scan` - Run health scan on current project
- `obot scan --report health.html` - Generate report
- `obot fix --from-scan` - Fix issues from scan

---

#### 22.6 Unified Telemetry System
**Status:** Merge of CLI resource monitoring + IDE cost tracking  
**Source:** SCALING_PLAN.md line 45, existing items #164-175, #242  
**Estimated LOC:** ~300

**Items:**
299. **Unified Telemetry Service** - Cross-platform stats collection
300. **Cost Savings Calculator** - Compare Ollama vs commercial API costs
301. **Performance Metrics** - Track latency, throughput, success rates
302. **Local-Only Storage** - All telemetry stored locally at `~/.config/ollamabot/telemetry/`

**Files to Create:**
- `internal/telemetry/service.go` (~150 LOC)
- `internal/telemetry/savings.go` (~100 LOC)
- `internal/telemetry/metrics.go` (~50 LOC)

**Integrate With:**
- Existing items #164-175 (Resource Monitor)
- Existing item #242 (IDE Cost Tracking)

**Commands:**
- `obot stats` - Show telemetry summary
- `obot stats --savings` - Show cost savings vs commercial APIs

---

### NEW SECTION 23: SCALING-SPECIFIC CLI COMMANDS

#### 23.1 Enhanced CLI Surface
**Status:** New commands  
**Source:** SCALING_PLAN.md lines 48-54

**Items:**
303. **Line Range Syntax** - `obot file.go [-start +end] [instruction]`
304. **Scoped Fix** - `obot fix [path] --scope repo|dir|file --plan --apply`
305. **Review Command** - `obot review [path] --diff --tests`
306. **Search Command** - `obot search "query" --files --symbols`
307. **Init Command** - `obot init` to scaffold config and cache paths

**Implementation:**
Already partially implemented, enhance with:
- `internal/cli/fix.go` - Add --scope flag
- `internal/cli/review.go` - New review command
- `internal/cli/search.go` - New search command (uses index from item #278)
- `internal/cli/init.go` - New init command

---

## DECISION MATRIX

| Item | Add to plan.md? | Reason | Priority |
|------|----------------|--------|----------|
| Repository Index | YES | Performance optimization, enables fast search | P1 |
| Pre-Orchestration Planner | YES | Improves orchestration quality | P1 |
| Patch Engine Safety | YES | Critical for production use | P0 |
| Interactive TUI | YES | Major UX differentiator | P2 |
| Project Health Scanner | YES | Unique feature vs competitors | P2 |
| Unified Telemetry | YES | Merge existing items #164-175 + #242 | P1 |
| Enhanced CLI Commands | YES | User-facing features | P1 |
| Plugin System | NO | Already noted as item #265 (deferred) | v2.0 |

---

## PROPOSED ADDITIONS TO plan.md

### Add to SECTION 22: ADVANCED CLI FEATURES (NEW)

**6 new subsections:**
1. Repository Index System (items #278-281)
2. Pre-Orchestration Planner (items #282-284)
3. Patch Engine with Safety (items #285-289)
4. Interactive TUI Mode (items #290-294)
5. Project Health Scanner (items #295-298)
6. Unified Telemetry System (items #299-302)

### Add to SECTION 23: ENHANCED CLI COMMANDS (NEW)

**1 subsection:**
1. Enhanced CLI Surface (items #303-307)

### Modify SECTION 9: RESOURCE MANAGEMENT

**Merge items #164-175 with new item #299-302 (Unified Telemetry)**

---

## ARCHIVE RECOMMENDATIONS

### Archive These Documents ✅

1. **UNIFIED_IMPLEMENTATION_PLAN.md** - 100% redundant with plan.md (was a source document)
2. **SCALING_PLAN.md** - After extracting 6 unique item clusters (13 items total), archive

### Keep These Documents ✅

1. **plan.md** - Master consolidated plan (after adding 13 new items)
2. **CLI_RULES.md** - CLI-specific rules and constraints
3. **README.md** - User-facing documentation

---

## UPDATED STATISTICS (After Additions)

### Before Additions
- Total items: 277
- Total estimated LOC: ~33,350
- Sections: 21

### After Additions
- Total items: 290 (+13)
- Total estimated LOC: ~36,350 (+3,000)
- Sections: 23 (+2)

### New Total Effort Estimate
- Implementation: 25 weeks (was 23)
- Developers: 4-6 (same)
- New LOC: ~36,350 (was ~33,350)

---

## IMPLEMENTATION PRIORITY UPDATE

### Phase 1: Foundation (Weeks 1-4) - NO CHANGE
Same as before

### Phase 2: Core Features (Weeks 5-9) - ADD 1 WEEK
- Add: **Patch Engine with Safety** (item #285-289, P0)
- Add: **Repository Index** (items #278-281, P1)

### Phase 3: Platform-Specific (Weeks 10-16) - NO CHANGE
Same as before

### Phase 3.5: CLI Advanced Features (Weeks 17-18) - NEW
- **Pre-Orchestration Planner** (items #282-284)
- **Interactive TUI Mode** (items #290-294)
- **Enhanced CLI Commands** (items #303-307)

### Phase 4: Quality & Release (Weeks 19-25) - ADJUSTED
- **Unified Telemetry** (items #299-302, merge with #164-175, #242)
- **Project Health Scanner** (items #295-298)
- Testing Infrastructure (existing)
- Documentation & Polish (existing)

---

## FINAL RECOMMENDATION

### Actions:

1. ✅ **ADD 13 items** (items #278-307) to plan.md from SCALING_PLAN.md
2. ✅ **CREATE 2 new sections** (Section 22, Section 23)
3. ✅ **UPDATE Phase 2** timeline (+1 week)
4. ✅ **ADD Phase 3.5** (Weeks 17-18)
5. ✅ **ADJUST Phase 4** timeline (Weeks 19-25)
6. ✅ **ARCHIVE UNIFIED_IMPLEMENTATION_PLAN.md** (100% redundant)
7. ✅ **ARCHIVE SCALING_PLAN.md** (after extraction)

### New Timeline:
- **v1.0 Release:** 25 weeks (was 23)
- **Additional LOC:** +3,000 (new total: ~36,350)

---

**Analysis Completed:** 2026-02-10  
**Documents Analyzed:** 2  
**Unique Items Found:** 13  
**Redundant Documents:** 1 (UNIFIED_IMPLEMENTATION_PLAN.md)
