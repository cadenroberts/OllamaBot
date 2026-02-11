# OllamaBot Protocol Implementation Guide

This guide is for developers implementing or extending the core protocols that power OllamaBot's cross-platform agentic orchestration.

## 1. Unified Orchestration Protocol (UOP)

The UOP defines the state machine and navigation rules for sessions.

### Key Components:
- **Schedules (1-5)**: Knowledge, Plan, Implement, Scale, Production.
- **Processes (1-3)**: The three steps within each schedule.
- **Flow Code**: A string representation of the session's path (e.g., `S1P1P2P3S2P1`).

### Implementation Requirements:
- **Navigation Validation**: You MUST enforce the 1↔2↔3 rule. Transitions like P1→P3 or P3→P1 are forbidden within a schedule.
- **State Persistence**: Every process transition must be recorded in the session's history.

## 2. Unified Tool Registry (UTR)

The UTR standardizes how tools are defined and invoked across CLI and IDE.

### Tool Schema:
Tools should be defined with:
- `id`: Unique identifier (e.g., `core.think`).
- `description`: Clear text for the LLM to understand when to use it.
- `parameters`: JSON Schema for input validation.

### Execution Safety:
- All tool executions must be wrapped in a timeout and resource monitor.
- Destructive actions (delete, overwrite) must create a backup if the safety flag is enabled.

## 3. Unified Context Protocol (UCP)

The UCP manages how information is fed into the LLM's context window.

### Budget Allocation:
Context should be distributed according to these targets:
- **System/Task**: 25%
- **Current Files**: 33%
- **Project Structure**: 16%
- **History/Memory**: 12%
- **Error Context**: 6%
- **Reserve**: 6%

### Compression:
Implement "Semantic Truncation" where imports and signatures are preserved even when the body of a file is truncated.

## 4. Unified Session Format (USF)

The USF is the JSON schema used for session portability.

### File Structure:
A USF session folder contains:
- `session.usf`: The master JSON file.
- `states/`: Individual `.state` files for each step.
- `notes/`: JSON arrays of orchestrator/agent/human notes.
- `actions/diffs/`: Unified diffs of all file changes.

### Portability Rules:
- When exporting, all relative paths must be resolved relative to the workspace root.
- All timestamps must be in ISO 8601 format.

## 5. Unified Model Coordination (UMC)

UMC handles the routing of tasks to specialized models.

### Expert Roles:
- `orchestrator`: Strategic planning and navigation.
- `coder`: Implementation and technical review.
- `researcher`: RAG and information retrieval.
- `vision`: UI/UX analysis.

### Fallback Logic:
If a specialized model is unavailable, the system must fall back to the `orchestrator` model as a universal baseline.

---

*For contribution guidelines, see [CONTRIBUTING.md](../CONTRIBUTING.md).*
