# OllamaBot + obot Final Master Harmonization Plan (IDE)

**Round:** 2 (Final Consolidation)  
**Date:** 2026-02-05  
**Consolidated from:** All Round 0 and Round 1 plans  
**Status:** MASTER PLAN - Ready for Implementation  
**Target:** OllamaBot IDE

---

## Executive Summary

After multiple rounds of consolidation across 8+ agent analyses, this final master plan establishes the definitive harmonization strategy for OllamaBot IDE and obot CLI. The solution centers on **6 Unified Protocols** (UOP, UTR, UCP, UMC, UC, USF) implemented through **shared contracts** (schemas, configs, formats) rather than shared code, enabling both products to operate as "two products of the same fruit" while preserving their unique strengths.

**Core Strategy:**
- **Protocols over Code:** Define shared schemas/contracts, implement independently
- **Feature Parity:** Transfer missing features through medium-appropriate implementations  
- **State Portability:** Enable seamless CLI ↔ IDE workflow switching
- **Behavioral Consistency:** Same inputs produce same outputs (95%+)

**Key Metrics:**
- **52 harmonization points** identified
- **27 feature gaps** to address
- **12-week implementation roadmap**
- **90%+ feature parity** target

---

## Part 1: The 6 Unified Protocols

### Protocol 1: Unified Orchestration Protocol (UOP)

**Purpose:** Standardize the 5-schedule orchestration framework across both products.

**Schema Location:** `~/.ollamabot/protocols/orchestration.yaml`

**Key Elements:**
- 5 schedules: Knowledge, Plan, Implement, Scale, Production
- 3 processes per schedule with strict 1↔2↔3 navigation
- Human consultation points (optional/mandatory)
- Flow code tracking (S1P123S2P12...)
- Termination prerequisites

**Implementation:**
- **CLI:** Already implements (validate against schema)
- **IDE:** Refactor `AgentExecutor.swift` to follow UOP state machine
- **Shared:** JSON Schema validation

**Benefits:**
- IDE gains structured orchestration
- CLI orchestration becomes portable
- Cross-product session resumption

---

### Protocol 2: Unified Tool Registry (UTR)

**Purpose:** Standardize tool definitions and capabilities.

**Schema Location:** `~/.ollamabot/protocols/tools.yaml`

**Master Tool Set (22 tools):**

**Core (3):** think, complete, consult.human  
**Files (9):** file.read, file.write, file.edit, file.delete, file.search, file.list, file.rename, file.move, file.copy  
**System (2):** run_command, take_screenshot  
**Delegation (3):** delegate.coder, delegate.researcher, delegate.vision  
**Web (2):** web.search, web.fetch  
**Git (3):** git.status, git.diff, git.commit

**Implementation:**
- **CLI:** Add missing tools (web.*, delegate.*, git.*)
- **IDE:** Normalize to canonical tool IDs
- **Both:** Generate Ollama tool definitions from UTR
- **Both:** Validate tool calls against schema

**Benefits:**
- Consistent tool behavior
- Schema validation prevents errors
- Easy to extend

---

### Protocol 3: Unified Context Protocol (UCP)

**Purpose:** Port IDE's sophisticated context management to CLI.

**Schema Location:** `~/.ollamabot/protocols/context.yaml`

**Key Features:**
- Token budget allocation (task 25%, files 33%, project 16%, history 12%, memory 12%, errors 6%)
- Smart truncation preserving imports/exports/signatures
- Conversation memory with relevance scoring
- Error pattern learning
- Inter-agent context passing

**Implementation:**
- **CLI:** Create `internal/context/manager.go` porting IDE logic
- **IDE:** Refactor to follow UCP spec
- **Shared:** Token counting (tiktoken or equivalent)
- **Shared:** Context templates in YAML

**Benefits:**
- CLI gains sophisticated context management
- Consistent context prioritization
- Shared error learning

---

### Protocol 4: Unified Model Coordinator (UMC)

**Purpose:** Harmonize model selection combining RAM tiers + intent routing.

**Schema Location:** `~/.ollamabot/config/models.yaml`

**Strategy:**
1. Detect RAM tier (CLI's robust detection)
2. Classify intent (IDE's keyword-based routing)
3. Select model: `{role}.{tier}` (e.g., `coder.performance`)

**Model Roles:**
- **Orchestrator:** Planning, delegation (qwen3)
- **Coder:** Code generation, debugging (qwen2.5-coder)
- **Researcher:** RAG, documentation (command-r)
- **Vision:** Image analysis (qwen3-vl)

**Tier Mapping:**
- Minimal (8-15GB), Compact (16-23GB), Balanced (24-31GB), Performance (32-63GB), Advanced (64GB+)

**Implementation:**
- **CLI:** Add intent classification
- **IDE:** Add RAM-aware tier fallbacks
- **Both:** Use shared model registry
- **Both:** Support manual override

**Benefits:**
- CLI gains intelligent routing
- IDE gains RAM awareness
- Consistent model behavior

---

### Protocol 5: Unified Configuration (UC)

**Purpose:** Single source of truth for configuration.

**Location:** `~/.ollamabot/config.yaml`

**Structure:**
```yaml
version: "2.0"
ollama:
  url: http://localhost:11434
models:
  orchestrator: qwen3:32b
  coder: qwen2.5-coder:32b
generation:
  temperature: 0.3
  max_tokens: 4096
quality:
  default_preset: balanced
agent:
  max_steps: 50
context:
  max_tokens: 8192
ide: { ... }  # IDE-specific
cli: { ... }  # CLI-specific
```

**Implementation:**
- **CLI:** Migrate from JSON to YAML
- **IDE:** Read YAML, override with UserDefaults for UI
- **Both:** Validate against JSON Schema
- **Migration:** Tool to convert existing configs

**Benefits:**
- Single source of truth
- Settings sync across products
- Easier maintenance

---

### Protocol 6: Unified State Format (USF)

**Purpose:** Enable cross-product session portability.

**Schema Location:** `~/.ollamabot/protocols/state.yaml`

**Format:** JSON with schema validation

**Key Elements:**
- Session metadata (id, prompt, platform)
- Orchestration state (schedule, process, flow_code)
- Action history
- Token usage
- Memory entries
- Checkpoints

**Implementation:**
- **CLI:** Update session serialization to USF
- **IDE:** Update CheckpointService to USF
- **Both:** Validate against JSON Schema
- **Both:** Support import/export

**Benefits:**
- Sessions portable between CLI and IDE
- Unified checkpoint format
- Easier debugging

---

## Part 2: Feature Parity Implementation

### 2.1 CLI → IDE Transfers (Priority Order)

| Feature | Priority | Implementation |
|---------|----------|----------------|
| Orchestration Framework | P0 | Refactor AgentExecutor to UOP |
| Quality Presets | P1 | Add UI selector |
| Line Range Editing | P1 | Selection-based editing |
| Dry-Run Mode | P1 | Preview-only mode |
| Cost Tracking | P2 | Port stats system |
| Human Consultation | P2 | Modal dialogs with timeout |

### 2.2 IDE → CLI Transfers (Priority Order)

| Feature | Priority | Implementation |
|---------|----------|----------------|
| Multi-Model Delegation | P0 | Add delegate.* tools |
| Context Management | P0 | Port ContextManager to Go |
| Intent Routing | P1 | Port IntentRouter to Go |
| Web Search | P1 | Add web.search tool |
| Vision Support | P1 | Add vision model |

---

## Part 3: Implementation Roadmap

### Phase 1: Foundation (Weeks 1-4)
- Week 1: Define all 6 protocol schemas
- Week 2: Unified Configuration system
- Week 3: Unified Tool Registry
- Week 4: Unified Context Protocol

### Phase 2: Core Harmonization (Weeks 5-8)
- Week 5: Unified Orchestration Protocol
- Week 6: Unified Model Coordinator
- Week 7: Feature Parity - CLI → IDE
- Week 8: Feature Parity - IDE → CLI

### Phase 3: Advanced Features (Weeks 9-12)
- Week 9: Unified State Format
- Week 10: Testing & Quality
- Week 11: Documentation
- Week 12: Polish & Release

---

## Part 4: Success Metrics

**Technical:**
- 100% protocol compliance
- 90%+ feature parity
- 100% state portability
- 80%+ test coverage

**User Experience:**
- Seamless CLI ↔ IDE switching
- 95%+ behavioral consistency
- <30s feature discovery time

**Quality:**
- <5 critical bugs/month
- <5% performance regression
- 100% error handling coverage

---

## Conclusion

This final master plan synthesizes the best ideas from all previous rounds. The 6 Unified Protocols provide the foundation for harmonization while preserving each product's unique strengths. Implementation through shared contracts (not shared code) enables independent development while ensuring consistency.

**Expected Outcome:** Two harmonized products that feel like CLI and IDE versions of the same tool.

**Next Steps:** Begin Phase 1 implementation.
