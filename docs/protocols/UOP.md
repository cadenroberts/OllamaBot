# Unified Orchestration Protocol (UOP)

The Unified Orchestration Protocol defines the state machine, navigation rules, and communication patterns for agentic orchestration in OllamaBot.

## 1. State Machine

The orchestration flow is governed by 5 schedules, each containing 3 processes.

### 1.1 Schedules
1. **Knowledge**: Information gathering and analysis.
2. **Plan**: Strategy development and task breakdown.
3. **Implement**: Code generation and modification.
4. **Scale**: Performance optimization and refactoring.
5. **Production**: Security audit, documentation, and final polish.

### 1.2 Processes
Each schedule has three sequential processes (P1, P2, P3).
- **P1**: Initial divergent thinking or analysis.
- **P2**: Mid-point refinement or optional consultation.
- **P3**: Final synthesis or mandatory feedback.

## 2. Navigation Rules

Processes within a schedule follow strict adjacency rules (1↔2↔3).

- **Initial State (0)**: Must go to P1.
- **P1**: Can go to P1 (repeat) or P2.
- **P2**: Can go to P1, P2 (repeat), or P3.
- **P3**: Can go to P2, P3 (repeat), or terminate the schedule.

### 2.1 Schedule Termination
A schedule can only be terminated after P3 has completed.

### 2.2 Prompt Termination
The overall prompt is considered "Terminated" only when:
1. All 5 schedules have run at least once.
2. The "Production" schedule was the last one to terminate.
3. The orchestrator justifies that the goal has been fully met.

## 3. Communication

The Orchestrator (TOOLER) selects schedules and processes.
The Agent (EXECUTOR) performs actions within a process.
The Human (CONSULTANT) provides guidance during P2 (optional) or P3 (mandatory) of specific schedules.
