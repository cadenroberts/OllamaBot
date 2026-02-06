---
agent: gemini-2
round: 2
product: ollamabot-ide
recovered: 2026-02-06
status: FLOW_EXIT_COMPLETE
---

# Definitive Harmonization Blueprint — IDE (Round 2)
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
*   **IDE Implementation**:
    *   Implement `OrchestrationService.swift` to visualize these 5 phases.
    *   Map existing IDE modes: Infinite Mode = Plan + Implement, Explore Mode = Production with reflection loops, Cycle Mode = full 5-schedule orchestration.

### 2.2. UTR (Unified Tool Registry)
*   **Standard**: The 22-Tool Set.
*   **IDE Additions**:
    *   `edit_smart` (range-based editing) for precision line-range edits.
    *   Dry-run and diff preview modes ported from CLI.
*   **IDE Already Has**: `read_file`, `write_file`, `edit_file`, `search_files`, `list_directory`, `run_command`, `ask_user`, `think`, `complete`, `delegate_to_coder`, `delegate_to_researcher`, `delegate_to_vision`, `take_screenshot`, `web_search`, `fetch_url`, `git_status`, `git_diff`, `git_commit`.

### 2.3. UCP (Unified Context Protocol)
*   **Standard**: The "Token Budget" Algorithm.
*   **Algorithm**:
    *   **System**: 15%
    *   **Task/Plan**: 25%
    *   **Active Files**: 40% (LRU managed)
    *   **Project Context**: 15%
    *   **History**: 5%
*   **IDE Status**: Already implemented in `ContextManager.swift`. Verify budget percentages match this spec.

### 2.4. UMC (Unified Model Coordinator)
*   **Standard**: The 4-Role Model System.
    *   **Orchestrator**: High reasoning (e.g., Qwen 32B).
    *   **Coder**: High accuracy (e.g., Qwen-Coder 32B).
    *   **Researcher**: High context/retrieval (e.g., Command-R).
    *   **Vision**: Image understanding (e.g., Qwen-VL).
*   **IDE Status**: Already implemented in `ModelTierManager.swift` and `IntentRouter.swift`. Sync tier thresholds with CLI RAM detection values.

### 2.5. UC (Unified Configuration)
*   **Standard**: `~/.config/ollamabot/config.yaml`.
*   **IDE Migration**: Read shared YAML config for model/quality/feature settings. Retain UserDefaults for IDE-specific visual preferences only (theme, font size, window state).
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
*   **IDE Implementation**: Update `CheckpointService.swift` and `SessionStateService.swift` to read/write USF format.

## 3. IDE Implementation Plan

### Phase 1: Config Migration (Week 1)
1.  **SharedConfigService.swift**: New service to read `~/.config/ollamabot/config.yaml`.
2.  **Migration**: On first launch, export current UserDefaults model/quality settings to shared YAML.

### Phase 2: Orchestration (Week 2)
1.  **OrchestrationService.swift**: Implement the 5-Phase state machine from CLI.
2.  **OrchestrationView.swift**: Build the 5-Phase visualizer in SwiftUI.
3.  **Flow Code Tracking**: Display flow code (S1P123S2P12...) in orchestration UI.

### Phase 3: Quality & Tools (Week 3)
1.  **QualityPresetPicker.swift**: Add Fast/Balanced/Thorough dropdown to ComposerView and ChatView.
2.  **SmartEditService.swift**: Implement range-based editing using CLI's diff/patch logic.
3.  **DryRunView.swift**: Preview changes before applying (diff viewer).

### Phase 4: Session Portability (Week 4)
1.  **SharedSessionService.swift**: Read/write USF session.json format.
2.  **Session Resume**: Enable resuming sessions started in CLI.
3.  **Cost Tracking**: Port CLI savings/stats tracking to IDE performance dashboard.

## 4. IDE File Changes

### New Files
*   `Sources/Services/SharedConfigService.swift` (~300 lines)
*   `Sources/Services/OrchestrationService.swift` (~700 lines)
*   `Sources/Services/SharedSessionService.swift` (~400 lines)
*   `Sources/Views/OrchestrationView.swift` (~450 lines)
*   `Sources/Views/QualityPresetPicker.swift` (~100 lines)

### Modified Files
*   `Sources/Services/OllamaService.swift` — Read quality presets from shared config
*   `Sources/Services/ConfigurationService.swift` — Delegate to SharedConfigService
*   `Sources/Agent/AgentExecutor.swift` — Integrate orchestration, add quality preset logic
*   `Sources/Views/ChatView.swift` — Add quality selector
*   `Sources/Views/ComposerView.swift` — Add quality selector

### Refactoring
*   Split `AgentExecutor.swift` (1069 lines) into 5 files:
    *   `AgentExecutor.swift` (~200 lines)
    *   `ToolExecutor.swift` (~150 lines)
    *   `VerificationEngine.swift` (~100 lines)
    *   `DelegationHandler.swift` (~150 lines)
    *   `ErrorRecovery.swift` (~100 lines)

## 5. Why This Wins
*   **Low Risk**: No FFI/Rust rewrite. Native Swift throughout.
*   **High Value**: Brings CLI's structured orchestration to the IDE's rich UI.
*   **Clear Path**: 4 distinct phases with concrete deliverables.
