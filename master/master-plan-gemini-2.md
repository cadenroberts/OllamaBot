---
agent: gemini-2
round: 2
source: plans_2/consolidated-master-plan-gemini-2.md
recovered: 2026-02-06
status: FLOW_EXIT_COMPLETE
---

# Definitive Harmonization Blueprint (Round 2)
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
*   **Implementation**:
    *   **IDE**: Implement `OrchestrationService.swift` to visualize these 5 phases.
    *   **CLI**: Already exists (`internal/orchestrate`). Align phase names.

### 2.2. UTR (Unified Tool Registry)
*   **Standard**: The 22-Tool Set defined in `sonnet-2`.
*   **Key Additions**:
    *   **CLI**: Needs `delegate` (multi-model), `web_search`, `vision`.
    *   **IDE**: Needs `edit_smart` (range-based editing) for precision.
*   **Schema**:
    ```json
    { "tool": "edit_smart", "params": { "file": "path", "start_line": 10, "end_line": 20, "instruction": "Fix error" } }
    ```

### 2.3. UCP (Unified Context Protocol)
*   **Standard**: The "Token Budget" Algorithm.
*   **Algorithm**:
    *   **System**: 15%
    *   **Task/Plan**: 25%
    *   **Active Files**: 40% (LRU managed)
    *   **Project Context**: 15%
    *   **History**: 5%
*   **Implementation**:
    *   **CLI**: Port `ContextManager.swift` logic to `internal/context/budget.go`.

### 2.4. UMC (Unified Model Coordinator)
*   **Standard**: The 4-Role Model System.
    *   **Orchestrator**: High reasoning (e.g., Qwen 32B).
    *   **Coder**: High accuracy (e.g., Qwen-Coder 32B).
    *   **Researcher**: High context/retrieval (e.g., Command-R).
    *   **Vision**: Image understanding (e.g., Qwen-VL).
*   **Hardware Tiering**: Use `obot`'s RAM detection to downscale these roles (e.g., 16GB RAM = All roles map to Qwen-14B).

### 2.5. UC (Unified Configuration)
*   **Standard**: `~/.config/ollamabot/config.yaml`.
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

## 3. Implementation Plan (The "Explosion")

### Phase 1: Schemas & Config (Week 1)
1.  **Config Loader**: Implement `internal/config/loader.go` (CLI) and `ConfigurationService.swift` (IDE) to read `config.yaml`.
2.  **Schema Definitions**: Create JSON schemas for UOP, UTR, USF in `~/ollamabot/schemas/`.

### Phase 2: Logic Porting (Week 2)
1.  **Context to Go**: Port the Token Budget logic from Swift to Go.
2.  **Tiers to Swift**: Port the RAM detection logic from Go to Swift (system calls).

### Phase 3: Tool Parity (Week 3)
1.  **Web/Vision in CLI**: Add tool stubs and Ollama multimodal calls in `internal/tools`.
2.  **Range Editing in IDE**: Implement `SmartEditService.swift` using the CLI's diff/patch logic.

### Phase 4: UI/UX Harmonization (Week 4)
1.  **Orchestration View**: Build the 5-Phase visualizer in SwiftUI.
2.  **Quality Selector**: Add the Fast/Balanced/Thorough dropdown to the IDE.

## 4. Why This Wins
*   **Low Risk**: No FFI/Rust rewrite.
*   **High Value**: Brings the "Brain" of the IDE to the "Body" of the CLI.
*   **Clear Path**: 4 distinct phases with concrete deliverables.
