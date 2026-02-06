---
agent: gemini-2
round: 2
product: obot-cli
recovered: 2026-02-06
status: FLOW_EXIT_COMPLETE
---

# Definitive Harmonization Blueprint — CLI (Round 2)
## Agent: gemini-2 | Round: 2 | Date: 2026-02-05

## 1. Strategic Decision: Polyglot Alignment
After analyzing the "Rust Core" proposal (from `sonnet-2`) and the "Protocol" proposal (from `opus-1`), we choose **Polyglot Alignment**.
*   **Why not Rust?** Rewriting the core logic in Rust introduces FFI complexity (CGO + Swift C interop) and massive regression risk for a team of Go/Swift developers.
*   **The Path Forward**: We will maintain two native codebases (Go and Swift) but strictly align them via **Shared Schemas** and **Ported Logic**.

## 2. The Hexagon Protocol System (Final Spec)
The "Hexagon" structure from Round 1 is refined with specific details from all plans.

### 2.1. UOP (Unified Orchestration Protocol)
*   **Standard**: A 5-Phase State Machine.
    1.  **Knowledge**: Research & Context Gathering.
    2.  **Plan**: Strategy & Clarification.
    3.  **Implement**: Code Generation & Application.
    4.  **Verify**: Testing & Review.
    5.  **Refine**: Optimization & Formatting.
*   **CLI Status**: Already implemented in `internal/orchestrate/orchestrator.go`. Align phase names to match the unified spec. Current names (Knowledge/Plan/Implement/Scale/Production) need mapping to the harmonized names.

### 2.2. UTR (Unified Tool Registry)
*   **Standard**: The 22-Tool Set.
*   **CLI Current State**: 12 write-only executor actions (CreateFile, DeleteFile, EditFile, RenameFile, MoveFile, CopyFile, CreateDir, DeleteDir, RenameDir, MoveDir, CopyDir, RunCommand).
*   **CLI Needs (Tier 2 Migration)**:
    *   `read_file` — Agent cannot currently read files itself; fixer engine feeds content.
    *   `search_files` — No codebase search capability in agent.
    *   `delegate` — Multi-model delegation (coder/researcher/vision).
    *   `web_search` / `fetch_url` — Web research capability.
    *   `git_status` / `git_diff` / `git_commit` — Git integration.
    *   `think` / `complete` / `ask_user` — Core agent control tools.

### 2.3. UCP (Unified Context Protocol)
*   **Standard**: The "Token Budget" Algorithm.
*   **Algorithm**:
    *   **System**: 15%
    *   **Task/Plan**: 25%
    *   **Active Files**: 40% (LRU managed)
    *   **Project Context**: 15%
    *   **History**: 5%
*   **CLI Status**: Not implemented. Current context is simple text summary (`internal/context/summary.go`). Needs full port from IDE's `ContextManager.swift`.

### 2.4. UMC (Unified Model Coordinator)
*   **Standard**: The 4-Role Model System.
    *   **Orchestrator**: High reasoning (e.g., Qwen 32B).
    *   **Coder**: High accuracy (e.g., Qwen-Coder 32B).
    *   **Researcher**: High context/retrieval (e.g., Command-R).
    *   **Vision**: Image understanding (e.g., Qwen-VL).
*   **CLI Status**: Single-model tier system (`internal/tier/detect.go`). Needs upgrade to support 4-role model assignment with fallback chains.
*   **Hardware Tiering**: Use existing RAM detection to downscale roles (e.g., 16GB RAM = All roles map to Qwen-14B).

### 2.5. UC (Unified Configuration)
*   **Standard**: `~/.config/ollamabot/config.yaml`.
*   **CLI Migration**: Move from `~/.config/obot/config.json` to shared YAML. Create backward-compat symlink.
*   **Structure**:
    ```yaml
    quality: balanced # fast | balanced | thorough
    roles:
      coder: "qwen2.5-coder:32b"
    features:
      web_search: true
    ```

### 2.6. USF (Unified State Format)
*   **Standard**: `session.json`.
*   **Content**: Preserves the **Orchestration State** (Current Phase), **Context Stack** (Loaded Files), and **Chat History**.
*   **CLI Migration**: Update `internal/session/session.go` to read/write USF format instead of bash-only restore scripts.

## 3. CLI Implementation Plan

### Phase 1: Config & Schema (Week 1)
1.  **internal/config/loader.go**: Implement YAML config loader for `~/.config/ollamabot/config.yaml`.
2.  **Migration**: Auto-migrate existing `~/.config/obot/config.json` to new location/format on first run.
3.  **Symlink**: Create `~/.config/obot/` -> `~/.config/ollamabot/` for backward compatibility.

### Phase 2: Context & Models (Week 2)
1.  **internal/context/budget.go**: Port Token Budget algorithm from IDE's `ContextManager.swift`.
2.  **internal/context/memory.go**: Implement conversation memory with LRU pruning.
3.  **internal/model/coordinator.go**: Upgrade from single-model to 4-role model coordinator with fallback chains.

### Phase 3: Tool Parity (Week 3)
1.  **internal/agent/tools_read.go**: Add `read_file`, `search_files`, `list_directory` to agent.
2.  **internal/agent/tools_delegate.go**: Add `delegate_to_coder`, `delegate_to_researcher`, `delegate_to_vision`.
3.  **internal/agent/tools_web.go**: Add `web_search`, `fetch_url` stubs.
4.  **internal/agent/tools_git.go**: Add `git_status`, `git_diff`, `git_commit`.

### Phase 4: OBot & Session (Week 4)
1.  **internal/obotrules/parser.go**: Parse `.obotrules` files for project-level AI rules.
2.  **internal/mention/parser.go**: Parse `@file`, `@bot`, `@context` mentions.
3.  **internal/session/shared.go**: Implement USF session format (read/write `session.json`).

## 4. CLI File Changes

### New Files
*   `internal/config/loader.go` (~250 lines) — YAML config loader
*   `internal/context/budget.go` (~300 lines) — Token budgeting
*   `internal/context/memory.go` (~200 lines) — Conversation memory
*   `internal/agent/tools_read.go` (~150 lines) — Read/search tools
*   `internal/agent/tools_delegate.go` (~250 lines) — Multi-model delegation
*   `internal/agent/tools_web.go` (~100 lines) — Web tools
*   `internal/agent/tools_git.go` (~150 lines) — Git tools
*   `internal/obotrules/parser.go` (~300 lines) — .obotrules parser
*   `internal/mention/parser.go` (~200 lines) — @mention parser
*   `internal/session/shared.go` (~350 lines) — USF session format

### Modified Files
*   `internal/config/config.go` — Add shared config support, YAML migration
*   `internal/model/coordinator.go` — Upgrade to 4-role system
*   `internal/agent/agent.go` — Register Tier 2 tools, add delegation support
*   `internal/cli/root.go` — Add @mention syntax support
*   `internal/fixer/prompts.go` — Include .obotrules in prompt construction

### Package Consolidation (27 -> 12)
*   Merge `actions` into `agent`
*   Merge `analyzer` into `fixer`
*   Merge `model` into `ollama`
*   Merge `tier` into `config`

## 5. Why This Wins
*   **Low Risk**: No FFI/Rust rewrite. Native Go throughout.
*   **High Value**: Brings IDE's intelligence (context, multi-model, tools) to the CLI's structural backbone.
*   **Clear Path**: 4 distinct phases with concrete deliverables.
