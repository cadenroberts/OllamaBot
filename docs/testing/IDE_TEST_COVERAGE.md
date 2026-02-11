# IDE Test Coverage Targets

This document outlines the target test coverage percentages for the OllamaBot IDE components.

## Target Metrics

| Component | Target Coverage |
|-----------|-----------------|
| Agent Execution | 90% |
| Tools | 85% |
| Context | 80% |
| Orchestration | 80% |
| Sessions | 75% |
| UI | 60% |

## Implementation Status

Currently, the IDE codebase (Swift) has no formal test targets in `Package.swift`. 

### Required Actions

1. **Add Test Target to Package.swift**:
   - Create a `Tests` directory.
   - Add `.testTarget` to `Package.swift`.
   
2. **Implement Unit Tests**:
   - **Agent Execution**: Test `AgentExecutor.swift` and its components.
   - **Tools**: Test `AgentTools.swift` and `AdvancedTools.swift`.
   - **Context**: Test `ContextManager.swift` and `FileIndexer.swift`.
   - **Orchestration**: Test `OrchestrationService.swift`.
   - **Sessions**: Test `SessionStateService.swift` and `UnifiedSessionService.swift`.
   - **UI**: Test Views using XCTest or a similar framework.

3. **Continuous Integration**:
   - Configure CI to run `swift test --enable-code-coverage`.
   - Monitor coverage against these targets.

## Component Breakdown

### Agent Execution (Target: 90%)
Focus on:
- Tool selection logic.
- Prompt construction.
- LLM response parsing.
- Error recovery paths.

### Tools (Target: 85%)
Focus on:
- File system operations.
- Git integration.
- External tool execution (e.g., shell commands).

### Context (Target: 80%)
Focus on:
- Token budgeting.
- File indexing and search.
- Context window management.

### Orchestration (Target: 80%)
Focus on:
- Schedule and process transitions.
- Navigation rule enforcement.
- State machine consistency.

### Sessions (Target: 75%)
Focus on:
- State persistence and loading.
- Note management.
- Restore script generation parity with CLI.

### UI (Target: 60%)
Focus on:
- View model logic.
- State propagation to views.
- Critical user interactions.
