# FINAL MASTER PLAN - OllamaBot + obot Harmonization

**Agent**: Claude Opus 4.5  
**Round**: 2 (Final Consolidation)  
**Timestamp**: 2026-02-05  
**Status**: CONVERGENCE ACHIEVED

---

## Convergence Declaration

After analyzing **31+ plans** across Rounds 0-1 from **Opus, Sonnet, Gemini, and Composer** agents, I confirm that **consensus has been achieved** on all major architectural and implementation decisions.

**The definitive master plan is**: `consolidated-master-plan-sonnet-2.md` (41KB, 1397 lines)

This plan comprehensively synthesizes all agent contributions and should be adopted as the canonical implementation roadmap.

---

## Confirmed Consensus Points

### 1. Architecture: "CLI as Engine, IDE as GUI"
**Unanimous agreement across all agent families**
- CLI (`obot`) serves as the execution engine with `--json` mode for machine output
- IDE (`OllamaBot`) wraps CLI for orchestration while providing native GUI experiences
- Both read from shared config directory

### 2. Shared Configuration Standard (UCS v1.0)
**Location**: `~/.obot/config.yaml` (or `~/.ollamabot/`)
- Unified tier definitions with 4-model orchestration
- Cross-platform model routing and fallbacks
- Platform-specific sections (IDE/CLI) in single file

### 3. Universal Tool Specification (UTS v1.0)
**File**: `~/.obot/tools.json`
- 22 tools defined with standardized schemas
- Bidirectional alias mapping (snake_case ↔ CamelCase)
- Platform availability markers with porting priorities

### 4. Unified Context Protocol (UCP v1.0)
- Token budget allocation (25% task, 33% files, 16% project, 12% history, 12% memory, 6% errors)
- Semantic compression algorithms
- Inter-agent context passing
- Error pattern learning

### 5. Implementation Timeline
**Consensus**: 8-12 weeks across 4-6 phases
1. Foundation (Weeks 1-2): Shared specs and config
2. CLI Enhancements (Weeks 3-4): Multi-model, OBot system, context
3. IDE Enhancements (Weeks 5-6): Orchestration, quality presets, sessions
4. Harmonization (Weeks 7-8): CLI wrapper, cross-product features
5. Testing (Weeks 9-10): 75% coverage target

---

## Feature Gap Consensus

### CLI Needs (High Priority)
1. Multi-model delegation (port from IDE)
2. OBot system support (`.obotrules`)
3. Token-aware context management
4. Checkpoint system
5. Web search tools

### IDE Needs (High Priority)
1. 5×3 Orchestration framework (port from CLI)
2. Quality presets (fast/balanced/thorough)
3. Session persistence
4. Cost tracking
5. Flow code visualization

---

## Refactoring Consensus

### CLI Package Reduction
27 packages → 12 packages
- Consolidate: actions→agent, analyzer→fixer, model→ollama, tier→config

### IDE File Splitting
AgentExecutor.swift (1069 lines) → 5 files:
- AgentExecutor.swift (~200 lines)
- ToolExecutor.swift (~150 lines)
- VerificationEngine.swift (~100 lines)
- DelegationHandler.swift
- ErrorRecovery.swift

---

## Success Metrics Consensus

| Metric | Target |
|--------|--------|
| Shared config | 100% |
| Tool parity | 100% |
| Test coverage | 75% |
| Code duplication | -50% |
| Max file size | 500 lines |

---

## Recommendation

**ADOPT `consolidated-master-plan-sonnet-2.md` AS THE CANONICAL MASTER PLAN**

This plan:
- Synthesizes 31+ agent contributions
- Provides detailed implementation specs (UTS, UCP, UCS)
- Includes complete file structure changes
- Defines 12-week phased roadmap
- Establishes measurable success criteria

---

## Next Steps (Per Protocol)

1. **FLOW EXIT A**: Summary complete (above)
2. **FLOW EXIT B**: Master plan analysis (see `consolidated-master-plan-sonnet-2.md`)
3. **FLOW EXIT C**: Explode into implementation plans (pending user confirmation)
4. **FLOW EXIT D**: Generate 90+ individual implementation plans (await instruction)

---

**END OF FINAL MASTER PLAN**

**Agent Opus-1 confirms convergence. Awaiting instruction to proceed with implementation plan generation.**
