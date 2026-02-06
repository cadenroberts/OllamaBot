# OllamaBot IDE Master Consolidation Plan

**Agent:** Composer-5
**Round:** 1 (Consolidation)
**Generated:** 2026-02-05
**Scope:** OllamaBot IDE (Swift/macOS) harmonization strategy
**Source Plans:** Consolidated from all plans_0 analyses (sonnet-1, opus-1, opus-2, composer-1-5, gemini-1-5, systemization plans)

---

## Executive Summary

This consolidated plan synthesizes the best ideas from all Round 0 analyses to create a comprehensive harmonization strategy for ollamabot IDE and obot CLI. The plan establishes shared protocols, unified infrastructure, and feature parity while preserving each product's unique strengths.

**Key Insights from Consolidation:**
1. **Shared Contracts Over Shared Code** - Language-agnostic protocols enable harmony without forcing identical implementations
2. **Progressive Harmonization** - Phase-based approach allows incremental improvement without breaking changes
3. **Dual-Mode Support** - Both single-model (CLI) and multi-model (IDE) workflows must coexist
4. **Context Intelligence** - Sophisticated context management is critical for quality AI interactions
5. **Formal Orchestration** - Structured schedules/processes provide predictability and debuggability

---

## Part 1: Unified Core Architecture

### 1.1 Agent Execution Protocol (AEP) v1.0

**Goal:** Language-agnostic protocol for agent tool/action execution

**Core Principles:**
- Tool/action definitions via JSON Schema
- Execution results in standardized format
- Parallel execution support
- Caching semantics
- Delegation patterns

**Schema Location:** `ollamabot-common/schemas/agent-execution-protocol.json`

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Agent Execution Protocol",
  "type": "object",
  "properties": {
    "version": {"type": "string", "const": "1.0"},
    "tool": {
      "type": "object",
      "properties": {
        "id": {"type": "string"},
        "category": {"enum": ["file", "command", "delegation", "web", "git", "session"]},
        "parameters": {"type": "object"},
        "parallelizable": {"type": "boolean"},
        "cache_key": {"type": "string"},
        "delegation": {
          "type": "object",
          "properties": {
            "model": {"type": "string"},
            "intent": {"enum": ["coding", "research", "writing", "vision"]}
          }
        }
      },
      "required": ["id", "category"]
    },
    "result": {
      "type": "object",
      "properties": {
        "success": {"type": "boolean"},
        "output": {"type": "string"},
        "metadata": {"type": "object"},
        "cached": {"type": "boolean"}
      }
    }
  }
}
```

**Implementation:**
- Create `ollamabot-common` repository
- Swift: Use JSONDecoder with AEP schemas
- Go: Use encoding/json with schema validation
- Test harness for behavioral equivalence

### 1.2 Unified Configuration System

**Directory Structure:**
```
~/.obotconfig/
├── config.yaml              # Core configuration
│   ├── models:              # Model definitions
│   ├── preferences:         # User preferences
│   ├── api_keys:            # External API keys
│   └── paths:               # Custom paths
├── rules.yaml               # AI rules (.obotrules format)
├── prompts/                 # Prompt templates
│   ├── system/              # System prompts per role
│   ├── tools/               # Tool-specific prompts
│   └── workflows/           # Multi-step workflows
├── context/                 # Shared context snippets
├── sessions/                # Cross-compatible sessions
└── learned_patterns.json   # Error pattern learning DB
```

**Config Schema (YAML):**
```yaml
version: "1.0"

models:
  tiers:
    minimal: { model: "deepseek-coder:1.3b", ram_required: "8GB" }
    performance: { model: "qwen2.5-coder:32b", ram_required: "32GB" }

  orchestration:
    orchestrator: "qwen3:32b"
    researcher: "command-r:35b"
    coder: "qwen2.5-coder:32b"
    vision: "qwen3-vl:32b"

  default_mode: "single"  # or "orchestration"

preferences:
  quality_preset: "balanced"  # fast | balanced | thorough
  auto_save: true
  checkpoint_interval: 300  # seconds
  max_context_tokens: 32000

paths:
  ollama_url: "http://localhost:11434"
  config_dir: "~/.obotconfig"
  sessions_dir: "~/.obotconfig/sessions"
```

**Implementation:**
- YAML parser libraries: Swift (`Yams`), Go (`gopkg.in/yaml.v3`)
- Schema validation via JSON Schema
- Hot-reload support (file watchers)
- Migration tool for existing configs

### 1.3 Harmonized Tool/Action Vocabulary

**Unified Tool Registry (30 tools):**

**Core Execution:**
- `think` - Internal reasoning
- `complete` - Task completion signal
- `ask_user` - Human consultation

**File Operations:**
- `read_file` - Read file contents
- `write_file` - Write/create file
- `edit_file` - Edit file (search/replace)
- `edit_file_range` - Line-range editing (NEW)
- `delete_file` - Delete file
- `create_directory` - Create directory
- `delete_directory` - Delete directory
- `list_directory` - List directory contents
- `move_file` - Move/rename file
- `copy_file` - Copy file
- `search_files` - Search file contents
- `grep_files` - Pattern matching

**Command Execution:**
- `run_command` - Execute shell command
- `run_command_interactive` - Interactive command (NEW)

**Multi-Model Delegation:**
- `delegate_to_coder` - Delegate to coding model
- `delegate_to_researcher` - Delegate to research model
- `delegate_to_vision` - Delegate to vision model

**Web & External:**
- `web_search` - Web search
- `fetch_url` - Fetch URL content
- `take_screenshot` - Capture screenshot

**Git Operations:**
- `git_status` - Git status
- `git_diff` - Git diff
- `git_commit` - Git commit
- `git_log` - Git log (NEW)

**Session Management:**
- `checkpoint_save` - Save checkpoint
- `checkpoint_restore` - Restore checkpoint
- `checkpoint_list` - List checkpoints

**Tool-to-Action Mapping:**
- CLI actions map to unified tools via adapter layer
- IDE tools use unified tool registry
- Backward compatibility maintained

---

## Part 2: Context Management Harmonization

### 2.1 Unified Context Protocol (UCP)

**Token Budget Allocation:**
```
System/Task:     25% (orchestrator context)
Files:           33% (selected/open files)
Project:         16% (project structure)
History:         12% (conversation memory)
Memory:          12% (learned patterns)
Errors:           6% (error patterns)
Reserve:          6% (safety margin)
```

**Context Schema:**
```yaml
context:
  version: "1.0"
  token_budget: 32000
  allocation:
    system: 0.25
    files: 0.33
    project: 0.16
    history: 0.12
    memory: 0.12
    errors: 0.06
    reserve: 0.06

  files:
    - path: "src/main.go"
      priority: "high"
      lines: [10, 25]
      tokens: 450

  project:
    structure: "..."
    tokens: 1200

  history:
    messages: [...]
    tokens: 800

  learned_patterns:
    - pattern: "..."
      frequency: 5
```

**Implementation:**
- Port ContextManager logic to Go (`internal/context/manager.go`)
- Shared token counting (tiktoken or equivalent)
- Cross-product context sharing
- Error pattern learning database

### 2.2 Semantic Compression

**Algorithm:**
1. Identify low-priority context sections
2. Summarize using lightweight model or heuristics
3. Preserve high-priority sections verbatim
4. Maintain semantic relationships

**Shared Implementation:**
- Extract compression logic to language-agnostic algorithm
- Port to both Swift and Go
- Test with golden outputs

---

## Part 3: Model Coordination

### 3.1 Unified Model Management

**Hybrid Approach:**
- Support both single-model (CLI) and multi-model (IDE) workflows
- Intent-based routing for multi-model
- RAM-tier selection for single-model
- Seamless switching between modes

**Model Registry:**
```yaml
models:
  single_model:
    selection: "ram_tier"  # or "manual"
    tiers:
      - ram: "8GB"
        model: "deepseek-coder:1.3b"
      - ram: "32GB"
        model: "qwen2.5-coder:32b"

  orchestration:
    orchestrator: "qwen3:32b"
    researcher: "command-r:35b"
    coder: "qwen2.5-coder:32b"
    vision: "qwen3-vl:32b"

  intent_routing:
    coding: ["implement", "fix", "refactor", "optimize"]
    research: ["what is", "explain", "compare", "research"]
    writing: ["write", "document", "summarize"]
    vision: ["analyze", "describe", "extract"]
```

**Implementation:**
- Port IntentRouter to CLI
- Add orchestration support to CLI
- Unified model warmup/switching logic

---

## Part 4: Feature Parity Roadmap

### 4.1 CLI Features to Add to IDE

1. **Line-Range Editing** (HIGH)
   - Add line selector to IDE editor
   - Right-click "Fix Selection"
   - Visual range indicator

2. **Quality Presets** (MEDIUM)
   - Add Fast/Balanced/Thorough selector to Infinite Mode
   - UI toggle in agent panel

3. **Dry-Run Mode** (HIGH)
   - Preview changes before applying
   - Diff view panel
   - Apply/reject buttons

4. **Cost Tracking** (LOW)
   - Add savings dashboard
   - Token usage statistics
   - Cost comparison vs commercial APIs

5. **Formal Orchestration** (CRITICAL)
   - Port 5-schedule x 3-process framework
   - Visual schedule/process indicator
   - Flow code tracking display

6. **Session Persistence** (MEDIUM)
   - Bash-only restoration support
   - Session export/import

### 4.2 IDE Features to Add to CLI

1. **Interactive Chat Mode** (HIGH)
   - `obot chat` command
   - Multi-turn conversation
   - Model selection (Ctrl+1-4)

2. **@Mention System** (HIGH)
   - `@file:path` syntax support
   - Context injection
   - Mention resolution

3. **Checkpoint System** (MEDIUM)
   - `obot checkpoint save/restore/list`
   - Code state management
   - Cross-session checkpoints

4. **Vision Support** (MEDIUM)
   - `obot analyze image.png`
   - Image analysis workflow
   - Vision model integration

5. **Web Search** (LOW)
   - `obot search "query"`
   - Web search integration
   - Result formatting

6. **Multi-Model Orchestration** (CRITICAL)
   - Port 4-model system to CLI
   - Intent-based routing
   - Model coordination

---

## Part 5: Shared Infrastructure

### 5.1 ollamabot-common Library

**Purpose:** Shared code/components for both products

**Components:**
1. **Schemas** - JSON schemas for AEP, config, sessions
2. **Token Counter** - Unified token counting (tiktoken)
3. **Context Builder** - Priority-based context construction
4. **Diff Engine** - Myers algorithm implementation
5. **Git Wrapper** - Safe git operations
6. **Language Detector** - File type detection
7. **Error Taxonomy** - Standardized error codes
8. **Cache Layer** - Response caching
9. **File Watcher** - Config hot-reload
10. **Telemetry** - Opt-in analytics

### 5.2 Cross-Product Testing

**Test Infrastructure:**
- Shared test fixtures
- Golden output comparison
- Protocol compliance tests
- Integration test suite
- Behavioral equivalence validation

---

## Part 6: Implementation Phases

### Phase 1: Foundation (Weeks 1-2)
- [ ] Create `ollamabot-common` repository
- [ ] Define JSON schemas (AEP, config, sessions)
- [ ] Implement shared YAML parser libraries
- [ ] Create unified tool vocabulary mapping
- [ ] Set up cross-product test infrastructure

### Phase 2: Configuration (Weeks 3-4)
- [ ] Implement `.obotconfig/` directory structure
- [ ] Port OBot system to CLI
- [ ] Enable hot-reload in CLI
- [ ] Create config migration tool
- [ ] Update both products to use shared config

### Phase 3: Agent Execution (Weeks 5-7)
- [ ] Implement AEP in both products
- [ ] Port parallel execution to CLI
- [ ] Port action recording to IDE
- [ ] Create unified state serialization
- [ ] Implement tool-to-action adapters

### Phase 4: Context Management (Weeks 8-9)
- [ ] Port ContextManager to Go
- [ ] Implement token budgeting in CLI
- [ ] Create context persistence layer
- [ ] Enable context sharing
- [ ] Implement semantic compression

### Phase 5: Model Coordination (Weeks 10-11)
- [ ] Create unified model configuration
- [ ] Port intent routing to CLI
- [ ] Add orchestration to CLI
- [ ] Create shared model tier definitions
- [ ] Enable model coordination

### Phase 6: Feature Parity (Weeks 12-16)
- [ ] Add CLI chat mode
- [ ] Add IDE line-range editing
- [ ] Port orchestration framework to IDE
- [ ] Port multi-model system to CLI
- [ ] Add checkpoint system to CLI
- [ ] Add @mention to CLI
- [ ] Add dry-run to IDE
- [ ] Add cost tracking to IDE

### Phase 7: Integration and Polish (Weeks 17-18)
- [ ] Create cross-product integration tests
- [ ] Implement session sharing
- [ ] Create unified telemetry
- [ ] Update documentation
- [ ] Performance optimization

---

## Part 7: Success Metrics

### Code Quality
- Shared code percentage: 0% to 30%+ (via common library)
- Architectural alignment: less than 10% to 80%+
- Test coverage: Current to 80%+

### Feature Parity
- CLI features in IDE: 0/6 to 6/6
- IDE features in CLI: 0/6 to 6/6
- Shared feature compatibility: 0% to 100%

### User Experience
- Configuration sync: 0% to 100%
- Session compatibility: 0% to 100%
- Cross-interface workflow: 0% to 100%

---

## Conclusion

This consolidated plan represents the synthesis of all Round 0 analyses, establishing a clear path forward for harmonizing ollamabot IDE and obot CLI into a unified platform. The key principle is shared contracts over shared code - establishing language-agnostic protocols that enable true interoperability while preserving each product's unique strengths.

**Critical Success Factors:**
1. Language-agnostic protocol definitions
2. Shared configuration system
3. Unified tool vocabulary
4. Cross-compatible session format
5. Consistent user experience
6. Progressive harmonization approach
