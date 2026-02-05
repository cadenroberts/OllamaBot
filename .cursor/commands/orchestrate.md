---
title: obot orchestrate
description: Professional IBM-grade agentic orchestration framework with 5 schedules, 15 processes, strict navigation rules, and LLM-as-judge quality enforcement
format: oos
version: 1
author: obot
schedules: 5
processes_per_schedule: 3
total_processes: 15
navigation_rule: 1↔2↔3
human_consultation:
  clarify: optional
  feedback: mandatory
timeout_seconds: 60
countdown_seconds: 15
dot_interval_ms: 250
memory_update_ms: 100
---

# obot orchestrate

Execute the obot orchestration framework with professional, IBM-grade agentic behavior. This command launches a terminal-based orchestration application with structured schedule and process management.

## Command

```bash
obot orchestrate [options] ["initial prompt"]
```

## Description

The `obot orchestrate` command launches a full-featured terminal application that manages agentic code generation through a rigorous, structured framework. The system operates through 5 schedules, each containing 3 processes, with strict navigation rules enforced by a central orchestrator.

This is NOT vibe-coded AI. This is deterministic, auditable, production-grade orchestration.

---

# ORCHESTRATION SPECIFICATION

## Table of Contents

1. [Core Architecture](#core-architecture)
2. [Schedules and Processes](#schedules-and-processes)
3. [Navigation Rules](#navigation-rules)
4. [Agent Actions](#agent-actions)
5. [Display System](#display-system)
6. [Memory Visualization](#memory-visualization)
7. [Human Consultation](#human-consultation)
8. [Model Coordination](#model-coordination)
9. [Error Handling and Suspension](#error-handling-and-suspension)
10. [Prompt Summary](#prompt-summary)
11. [LLM-as-Judge Analysis](#llm-as-judge-analysis)
12. [Session Persistence](#session-persistence)
13. [Git Integration](#git-integration)
14. [Resource Management](#resource-management)
15. [Terminal UI Application](#terminal-ui-application)
16. [Configuration](#configuration)
17. [Implementation Modules](#implementation-modules)

---

## 1. Core Architecture

### 1.1 Component Hierarchy

```
┌─────────────────────────────────────────────────────────────────────┐
│                           ORCHESTRATOR                               │
│  Role: Schedule selection, process navigation, prompt termination    │
│  Model: Best available planner/writer (Qwen3 on Mac)                │
│  Behavior: TOOLER ONLY - no agentic actions                         │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                            SCHEDULES                                 │
│  5 Action Sets: Knowledge, Plan, Implement, Scale, Production       │
│  Each contains 3 processes with 1↔2↔3 navigation                    │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                             AGENT                                    │
│  Role: Execute processes, perform file operations, run commands     │
│  Models: Coder (Plan/Implement/Scale), RAG (Knowledge), Vision (Prod)│
│  Behavior: EXECUTOR ONLY - no orchestration decisions               │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Separation of Concerns

**CRITICAL INVARIANT**: The orchestrator and agent have strictly separated responsibilities.

| Component    | CAN DO                                      | CANNOT DO                                  |
|--------------|---------------------------------------------|-------------------------------------------|
| Orchestrator | Select schedules                            | Create/edit/delete files                  |
| Orchestrator | Navigate between processes                  | Run CLI commands                          |
| Orchestrator | Terminate schedules                         | Generate code                             |
| Orchestrator | Terminate prompt                            | Act as agent                              |
| Orchestrator | Review session notes                        | Make implementation decisions             |
| Agent        | Create/edit/delete files                    | Select schedules                          |
| Agent        | Run CLI commands                            | Navigate between processes                |
| Agent        | Generate code                               | Terminate schedules or prompt             |
| Agent        | Request human consultation                  | Make orchestration decisions              |

**VIOLATION OF THIS INVARIANT = IMMEDIATE SUSPENSION**

### 1.3 Decision Flow

```
ORCHESTRATOR asks: "What schedule should the agent do now?"
    ├─→ Selects Schedule (1-5)
    │       └─→ Prints: "Schedule • {ScheduleName}"
    │
    └─→ ORCHESTRATOR asks: "What process should the agent do now?"
            ├─→ Selects Process (based on navigation rules)
            │       └─→ Prints: "Process • {ProcessName}"
            │
            └─→ AGENT executes process
                    ├─→ Performs allowed actions
                    │       └─→ Prints: "Agent • {Action}"
                    │
                    └─→ Signals completion
                            └─→ Prints: "Agent • {ProcessName} Completed"
                                    │
                                    └─→ ORCHESTRATOR terminates process
                                            └─→ Prints: "Process • {ProcessName} Terminated"
```

---

## 2. Schedules and Processes

### 2.1 Schedule Definitions

| Schedule ID | Schedule Name | Process 1   | Process 2   | Process 3   |
|-------------|---------------|-------------|-------------|-------------|
| S1          | Knowledge     | Research    | Crawl       | Retrieve    |
| S2          | Plan          | Brainstorm  | Clarify     | Plan        |
| S3          | Implement     | Implement   | Verify      | Feedback    |
| S4          | Scale         | Scale       | Benchmark   | Optimize    |
| S5          | Production    | Analyze     | Systemize   | Harmonize   |

### 2.2 Schedule Purposes

#### S1 • Knowledge

**Purpose**: Information gathering and context building through research, web crawling, and retrieval.

**Model**: RAG model ONLY (no coding model during this schedule)

**Processes**:
- **Research (P1)**: Identify knowledge gaps, formulate research questions, determine information needs
- **Crawl (P2)**: Navigate documentation, codebases, web resources to gather raw information
- **Retrieve (P3)**: Extract, validate, and structure relevant information for use in other schedules

**Typical Flow**: Research → Crawl → Retrieve → (optionally back to Crawl for more data)

#### S2 • Plan

**Purpose**: Strategic planning and clarification of implementation approach.

**Model**: Coding model (primary agent representation)

**Processes**:
- **Brainstorm (P1)**: Generate potential approaches, consider alternatives, identify constraints
- **Clarify (P2)**: **HUMAN CONSULTATION ALLOWED** - Resolve ambiguities, confirm understanding with human
- **Plan (P3)**: Produce concrete implementation plan with steps, dependencies, and risk assessment

**Typical Flow**: Brainstorm → Clarify (if needed) → Plan

#### S3 • Implement

**Purpose**: Code generation, verification, and human feedback integration.

**Model**: Coding model (primary agent representation)

**Processes**:
- **Implement (P1)**: Generate code, create files, make edits according to plan
- **Verify (P2)**: Run tests, lint checks, validate implementation correctness
- **Feedback (P3)**: **HUMAN CONSULTATION MANDATORY** - Demonstrate changes, receive structured feedback

**Typical Flow**: Implement → Verify → Feedback → (back to Implement if changes needed)

#### S4 • Scale

**Purpose**: Performance optimization and benchmarking.

**Model**: Coding model (primary agent representation)

**Processes**:
- **Scale (P1)**: Identify scaling concerns, refactor for performance, optimize algorithms
- **Benchmark (P2)**: Measure performance metrics, compare against baselines
- **Optimize (P3)**: Apply targeted optimizations based on benchmark results

**Typical Flow**: Scale → Benchmark → Optimize → (back to Benchmark to verify improvements)

#### S5 • Production

**Purpose**: Final analysis, systematization, and harmonization for production readiness.

**Model**: Coding model + Vision model (for UI analysis)

**Processes**:
- **Analyze (P1)**: Comprehensive code analysis, security review, dependency audit
- **Systemize (P2)**: Ensure consistent patterns, documentation, configuration management
- **Harmonize (P3)**: Final integration testing, UI polish (via vision model), production preparation

**Special Rules**:
- Production is the ONLY schedule that can terminate the prompt
- Prompt termination requires ALL 5 schedules to have executed at least once
- Upon Production termination, orchestrator must justify why further schedules would not improve outcome

---

## 3. Navigation Rules

### 3.1 Process Navigation (Within a Schedule)

**STRICT RULE**: Processes follow 1↔2↔3 adjacency. No jumping allowed.

```
Process 1 ←→ Process 2 ←→ Process 3
    │            │            │
    ↓            ↓            ↓
 Can go to:   Can go to:   Can go to:
  - P1         - P1          - P2
  - P2         - P2          - P3
               - P3          - Terminate Schedule
```

#### From Process 1 Termination:
- **ALLOWED**: Go to Process 1 (repeat)
- **ALLOWED**: Go to Process 2
- **FORBIDDEN**: Go to Process 3
- **FORBIDDEN**: Terminate Schedule

#### From Process 2 Termination:
- **ALLOWED**: Go to Process 1
- **ALLOWED**: Go to Process 2 (repeat)
- **ALLOWED**: Go to Process 3
- **FORBIDDEN**: Terminate Schedule

#### From Process 3 Termination:
- **FORBIDDEN**: Go to Process 1
- **ALLOWED**: Go to Process 2
- **ALLOWED**: Go to Process 3 (repeat)
- **ALLOWED**: Terminate Schedule

### 3.2 Schedule Navigation

**After Schedule Termination**:
- Orchestrator may select ANY of the 5 schedules
- No forced ordering or frequency requirements
- Each schedule MUST execute at least once before prompt can terminate

### 3.3 Prompt Termination Rules

**Prerequisites for Prompt Termination**:
1. All 5 schedules have executed at least once
2. Production schedule is the most recently terminated schedule
3. Orchestrator can prove/justify that no further schedules would improve the outcome

**Orchestrator Decision Question**: "Should the agent execute {Schedule1}, {Schedule2}, ..., {Schedule5}, or terminate the prompt?"

**Justification Requirement**: The orchestrator MUST provide a short anecdote in the Generation Flow explaining:
- Why the current implementation satisfies the human prompt
- Why additional Plan schedules would not yield better understanding
- Why additional Implement schedules would not yield better code
- Why the agent cannot improve using ANY of the 5 schedules

---

## 4. Agent Actions

### 4.1 Allowed Action Types

The agent may ONLY perform the following actions. Any other action is a violation.

| Action Type | Output Format                                                      |
|-------------|-------------------------------------------------------------------|
| Create File | `Agent • Created {filename}`                                       |
| Delete File | `Agent • Deleted {filename}`                                       |
| Create Dir  | `Agent • Created {directory}`                                      |
| Delete Dir  | `Agent • Deleted {directory}`                                      |
| Rename File | `Agent • Renamed {filename} to {new_filename}`                     |
| Rename Dir  | `Agent • Renamed {directory} to {new_directory}`                   |
| Move File   | `Agent • Moved {filename} to {new_path}`                           |
| Move Dir    | `Agent • Moved {directory} to {new_path}`                          |
| Copy File   | `Agent • Copied {filename} to {new_path}`                          |
| Copy Dir    | `Agent • Copied {directory} to {new_path}`                         |
| Run Command | `Agent • Ran {cli_command} (exit {code})`                          |
| Edit File   | `Agent • Edited {filename} at lines {ranges}`                      |
|             | `{diff_summary}`                                                   |

### 4.2 Edit Action Detail

For file edits, the output includes:

1. **Line Ranges**: Computed using max overlap algorithm to produce minimal range representation
   - Example: Lines 12-15, 40-45 edited → `12-15, 40-45`
   - Example: Lines 12-13, 14-15, 16-17 edited → `12-17` (merged)

2. **Diff Summary**: obot-styled breakdown with cursor-style visualization
   ```
   +  12 │ func newFunction() {
   +  13 │     return nil
   +  14 │ }
   -  40 │ // old comment
   +  40 │ // new comment with more detail
   ```
   - Green (`+`) for additions
   - Red (`-`) for deletions
   - Line numbers aligned
   - Context lines shown in default color

### 4.3 Process Completion

When the agent finishes a process:
```
Agent • {ProcessName} Completed
```

The orchestrator then terminates the process:
```
Process • {ProcessName} Terminated
```

---

## 5. Display System

### 5.1 Stationary Display Panel

The display uses ANSI escape codes for in-place updates. The panel structure:

```
┌─────────────────────────────────────────────────────────────────────┐
│ Orchestrator • {state}                                              │
│ Schedule • {schedule_name}                                          │
│ Process • {process_name}                                            │
│ Agent • {current_action}                                            │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.2 State Values

| Component    | Possible States                                                    |
|--------------|--------------------------------------------------------------------|
| Orchestrator | `Begin`, `Selecting`, `Active`, `Suspended`, `Prompt Terminated`   |
| Schedule     | `Knowledge`, `Plan`, `Implement`, `Scale`, `Production`, `{name} Terminated` |
| Process      | `Research`, `Crawl`, `Retrieve`, `Brainstorm`, `Clarify`, `Plan`,  |
|              | `Implement`, `Verify`, `Feedback`, `Scale`, `Benchmark`, `Optimize`,|
|              | `Analyze`, `Systemize`, `Harmonize`, `{name} Terminated`           |
| Agent        | Any action output, `{ProcessName} Completed`, or animated dots     |

### 5.3 Initial State Animation

Before the first message is available for each level, display animated dots:
- `.` → `..` → `...` → `.` (cycling)
- Animation interval: 250ms

```
Orchestrator • ...
Schedule • ..
Process • .
Agent • ...
```

### 5.4 ANSI Color Scheme

Using obot's blue accent theme:

| Element              | Color                        | ANSI Code           |
|---------------------|------------------------------|---------------------|
| Orchestrator label  | Blue (bold)                  | `\033[1;34m`        |
| Schedule label      | Blue                         | `\033[34m`          |
| Process label       | Blue                         | `\033[34m`          |
| Agent label         | Blue                         | `\033[34m`          |
| State/Name values   | White (default)              | `\033[0m`           |
| Bullet separator    | Blue                         | `\033[34m`          |
| Diff additions      | Green                        | `\033[32m`          |
| Diff deletions      | Red                          | `\033[31m`          |
| Errors              | Red (bold)                   | `\033[1;31m`        |
| Warnings            | Yellow                       | `\033[33m`          |
| Success             | Green                        | `\033[32m`          |
| Flow code S1-S5     | White                        | `\033[37m`          |
| Flow code P123      | Blue                         | `\033[34m`          |

---

## 6. Memory Visualization

### 6.1 Live Memory Monitor

Display real-time memory usage with predictive measurement for upcoming processes/schedules.

```
┌─────────────────────────────────────────────────────────────────────┐
│ Memory                                                              │
│ ├─ Current: ████████████████░░░░░░░░░░░░░░░░░░░░░░░░  2.4 GB / 8 GB │
│ ├─ Peak:    ██████████████████████░░░░░░░░░░░░░░░░░░  3.1 GB        │
│ └─ Predict: ████████████████████████████░░░░░░░░░░░░  4.2 GB (P2)   │
└─────────────────────────────────────────────────────────────────────┘
```

### 6.2 Predictive Measurement

When the orchestrator selects a process or schedule, display an opaque prediction of expected memory usage:

**Prediction Sources**:
- Historical averages from previous process executions
- Model size estimates based on which model will be used
- Context window size estimates
- File operation estimates

**Prediction Display**:
```
Predict: ████████████████████████████░░░░░░░░░░░░░░░░  4.2 GB (Crawl)
         └─ Based on: RAG model load + web context retrieval
```

### 6.3 Memory Metrics

| Metric         | Description                                          |
|----------------|------------------------------------------------------|
| Current        | Real-time heap + system memory usage                 |
| Peak           | Maximum memory observed during session               |
| Predict        | Estimated memory for next process/schedule           |
| Available      | System available memory                              |
| Pressure       | Memory pressure indicator (normal/warning/critical)  |

### 6.4 Update Frequency

- Current/Peak: Update every 100ms during agent execution
- Predict: Update on each process/schedule selection
- Pressure: Update every 500ms with exponential smoothing

---

## 7. Human Consultation

### 7.1 Allowed Consultation Points

| Schedule  | Process   | Consultation Type |
|-----------|-----------|-------------------|
| Plan      | Clarify   | Optional (on ambiguity) |
| Implement | Feedback  | Mandatory         |

### 7.2 Consultation Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│ HUMAN CONSULTATION REQUESTED                                        │
│                                                                     │
│ Process: Clarify                                                    │
│ Question: {structured_question}                                     │
│                                                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ [Your response here...]                                         │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│ Time remaining: 01:00  [Respond]                                    │
│                                                                     │
│ ⚠ After timeout, an AI model will respond on your behalf           │
└─────────────────────────────────────────────────────────────────────┘
```

### 7.3 Timeout Behavior

1. **Initial Period**: 60 seconds for human response
2. **Warning Countdown**: At 15 seconds remaining, display visual countdown
3. **Countdown Display**:
   ```
   ⚠ AI RESPONSE IN: 15... 14... 13... 12... 11... 10... 9... 8... 7... 6... 5... 4... 3... 2... 1...
   ```
4. **AI Substitute**: Invoke appropriate model to generate response as human-in-loop
5. **Record**: Store AI-generated response with `[AI-SUBSTITUTE]` marker in session notes

### 7.4 Clarify Process Behavior

**Trigger**: Agent detects ambiguity in requirements or implementation approach

**Question Format**: Must be structured to eliminate varied interpretability
```
CLARIFY REQUEST
───────────────
Context: {what the agent is trying to understand}
Ambiguity: {specific point of confusion}
Options:
  A) {option_a_description}
  B) {option_b_description}
  C) {option_c_description}
  D) Other (please specify)

Which option best matches your intent?
```

### 7.5 Feedback Process Behavior

**Mandatory**: Always executed when Process 3 of Implement schedule is reached

**Demonstration Format**:
```
FEEDBACK DEMONSTRATION
──────────────────────
Changes Made:
  1. {change_1_description}
     File: {filename}
     Lines: {range}
     
  2. {change_2_description}
     File: {filename}
     Lines: {range}

Verification Results:
  ✓ Tests: {pass_count}/{total_count} passed
  ✓ Lint: {warning_count} warnings, {error_count} errors
  ✓ Build: {status}

Questions for Review:
  Q1: Does {specific_change} meet your expectations?
      [Yes] [No, because: ___]
  
  Q2: Should {other_aspect} be modified?
      [Keep as-is] [Modify to: ___]
```

**Structured Questioning**: Questions must be binary or multiple-choice to eliminate interpretation variance

---

## 8. Model Coordination

### 8.1 Model Assignments

| Role         | Model Type                | Used In                           |
|--------------|---------------------------|-----------------------------------|
| Orchestrator | Planner/Writer (Qwen3)    | All schedule/process decisions    |
| Coder        | Coding model              | Plan, Implement, Scale schedules  |
| Researcher   | RAG model                 | Knowledge schedule ONLY           |
| Vision       | Vision model              | Production schedule (with Coder)  |

### 8.2 Model Selection Logic

```go
func selectModel(schedule Schedule, process Process) Model {
    switch schedule {
    case Knowledge:
        return RAGModel  // ONLY RAG during Knowledge
    case Production:
        if process == Harmonize && hasUIComponents() {
            return []Model{CoderModel, VisionModel}  // Both for UI polish
        }
        return CoderModel
    default:
        return CoderModel  // Plan, Implement, Scale
    }
}
```

### 8.3 Orchestrator Model Constraints

The orchestrator model:
- MUST be the best available planner/writer model
- MUST NOT generate code
- MUST NOT perform file operations
- MUST ONLY make scheduling decisions
- MUST review session notes after each process termination

### 8.4 Model Handoff Protocol

```
1. Orchestrator selects schedule → logs decision
2. Orchestrator selects process → logs decision
3. Orchestrator hands control to appropriate model(s)
4. Agent model(s) execute process
5. Agent signals completion
6. Control returns to orchestrator
7. Orchestrator reviews session notes (if any)
8. Orchestrator decides next action
```

---

## 9. Error Handling and Suspension

### 9.1 Suspension Trigger Conditions

| Condition                                    | Error Code | Severity  |
|---------------------------------------------|------------|-----------|
| Agent attempts P1→P3 jump                   | E001       | Critical  |
| Agent attempts schedule termination         | E002       | Critical  |
| Agent attempts prompt termination           | E003       | Critical  |
| Orchestrator performs file operations       | E004       | Critical  |
| Orchestrator generates code                 | E005       | Critical  |
| Orchestrator acts as agent                  | E006       | Critical  |
| Agent acts as orchestrator                  | E007       | Critical  |
| Schedule terminates before P3 completes     | E008       | Critical  |
| Undefined action type executed              | E009       | Critical  |
| Ollama not running                          | E010       | System    |
| Model not available                         | E011       | System    |
| Memory pressure critical                    | E012       | System    |
| Disk space exhausted                        | E013       | System    |
| Network failure (during Knowledge)          | E014       | System    |
| Git operation failure                       | E015       | System    |

### 9.2 Suspension Output

```
┌─────────────────────────────────────────────────────────────────────┐
│ Orchestrator • Suspended                                            │
│                                                                     │
│ ERROR: {error_code} - {error_description}                           │
│                                                                     │
│ ═══════════════════════════════════════════════════════════════════ │
│ FROZEN STATE                                                        │
│ ═══════════════════════════════════════════════════════════════════ │
│ Schedule: {schedule_name} (S{n})                                    │
│ Process: {process_name} (P{n})                                      │
│ Last Action: {last_action}                                          │
│ Flow Code: S1P123S2P12X                                             │
│           └─────────────^ Error occurred here                       │
│                                                                     │
│ ═══════════════════════════════════════════════════════════════════ │
│ ERROR ANALYSIS                                                      │
│ ═══════════════════════════════════════════════════════════════════ │
│ {Detailed error narrative from orchestrator LLM-as-judge}           │
│                                                                     │
│ What happened:                                                      │
│   {description of the violation}                                    │
│                                                                     │
│ Which component violated:                                           │
│   {Orchestrator | Agent | System}                                   │
│                                                                     │
│ Rule violated:                                                      │
│   {specific rule from this specification}                           │
│                                                                     │
│ ═══════════════════════════════════════════════════════════════════ │
│ PROPOSED SOLUTIONS                                                  │
│ ═══════════════════════════════════════════════════════════════════ │
│ 1. {solution_1}                                                     │
│ 2. {solution_2}                                                     │
│ 3. {solution_3}                                                     │
│                                                                     │
│ ═══════════════════════════════════════════════════════════════════ │
│ SAFE CONTINUATION OPTIONS                                           │
│ ═══════════════════════════════════════════════════════════════════ │
│ [R] Retry last process                                              │
│ [S] Skip to next valid state                                        │
│ [A] Abort and save session                                          │
│ [I] Investigate (enter debug mode)                                  │
│                                                                     │
│ Select option: _                                                    │
└─────────────────────────────────────────────────────────────────────┘
```

### 9.3 Hardcoded Error Messages

| Error Code | Hardcoded Message                                                  |
|------------|-------------------------------------------------------------------|
| E010       | "Ollama is not running. Start Ollama with: ollama serve"          |
| E011       | "Required model '{model}' not found. Pull with: ollama pull {model}" |
| E013       | "Disk space exhausted. Free space required: {bytes}"              |

### 9.4 LLM-Analyzed Errors

For non-hardcoded errors, the orchestrator performs LLM-as-judge analysis:

1. **Context Gathering**: Collect recent actions, memory state, system state
2. **Analysis Prompt**: 
   ```
   Analyze the following error condition and provide:
   1. Root cause analysis
   2. Potential contributing factors
   3. Recommended solutions ranked by likelihood of success
   4. Safe continuation options that preserve session integrity
   ```
3. **Validation**: Ensure proposed solutions are actually possible given current state

---

## 10. Prompt Summary

### 10.1 Summary Trigger

Displayed after:
```
Orchestrator • Prompt Terminated
Schedule • Production Terminated
Process • Harmonize Terminated
Agent • Harmonize Completed
```

### 10.2 Summary Format

```
┌─────────────────────────────────────────────────────────────────────┐
│ Orchestrator • Prompt Summary                                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│ S1P1212323S2P123S4P123S3P123S5P123                                  │
│ ▲  ▲▲▲▲▲▲▲▲                                                         │
│ │  └──┴──┴──── Process codes (blue)                                 │
│ └───────────── Schedule codes (white)                               │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│ Schedule • 8 Total Schedulings                                      │
│   Knowledge: 1 scheduling                                           │
│   Plan: 2 schedulings                                               │
│   Implement: 2 schedulings                                          │
│   Scale: 1 scheduling                                               │
│   Production: 2 schedulings                                         │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│ Process • 47 Total Processes                                        │
│                                                                     │
│ Knowledge • 8 total (17.0% of all)                                  │
│   Averaging 2.67 processes per scheduling                           │
│   Research: 3 (37.5% of Knowledge)                                  │
│   Crawl: 3 (37.5% of Knowledge)                                     │
│   Retrieve: 2 (25.0% of Knowledge)                                  │
│                                                                     │
│ Plan • 12 total (25.5% of all)                                      │
│   Averaging 6.0 processes per scheduling                            │
│   Brainstorm: 4 (33.3% of Plan)                                     │
│   Clarify: 5 (41.7% of Plan)                                        │
│   Plan: 3 (25.0% of Plan)                                           │
│                                                                     │
│ Implement • 15 total (31.9% of all)                                 │
│   Averaging 7.5 processes per scheduling                            │
│   Implement: 6 (40.0% of Implement)                                 │
│   Verify: 5 (33.3% of Implement)                                    │
│   Feedback: 4 (26.7% of Implement)                                  │
│                                                                     │
│ Scale • 5 total (10.6% of all)                                      │
│   Averaging 5.0 processes per scheduling                            │
│   Scale: 2 (40.0% of Scale)                                         │
│   Benchmark: 2 (40.0% of Scale)                                     │
│   Optimize: 1 (20.0% of Scale)                                      │
│                                                                     │
│ Production • 7 total (14.9% of all)                                 │
│   Averaging 3.5 processes per scheduling                            │
│   Analyze: 3 (42.9% of Production)                                  │
│   Systemize: 2 (28.6% of Production)                                │
│   Harmonize: 2 (28.6% of Production)                                │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│ Agent • Action Breakdown                                            │
│                                                                     │
│ Created • 12 files, 3 directories                                   │
│ Deleted • 2 files, 0 directories                                    │
│ Renamed • 1 file, 0 directories                                     │
│ Moved • 0 files, 0 directories                                      │
│ Copied • 0 files, 0 directories                                     │
│ Ran • 24 commands                                                   │
│ Edited • 18 files                                                   │
│                                                                     │
│ Edit Details:                                                       │
│   main.go at 12-45, 78-92                                           │
│   +  12 │ func newHandler() http.Handler {                          │
│   +  13 │     return &handler{}                                     │
│   -  78 │ // TODO: implement                                        │
│   +  78 │ func (h *handler) ServeHTTP(w, r) {                       │
│   ...                                                               │
│                                                                     │
│   utils.go at 5-10                                                  │
│   +   5 │ package utils                                             │
│   +   6 │                                                           │
│   +   7 │ import "strings"                                          │
│   ...                                                               │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│ Resources • Summary                                                 │
│                                                                     │
│ Memory:                                                             │
│   Peak Usage: 4.2 GB                                                │
│   Average Usage: 2.8 GB                                             │
│   Pressure Events: 0 warning, 0 critical                            │
│                                                                     │
│ Disk:                                                               │
│   Files Written: 847 KB                                             │
│   Files Deleted: 12 KB                                              │
│   Net Change: +835 KB                                               │
│                                                                     │
│ Time:                                                               │
│   Total Duration: 12m 34s                                           │
│   Agent Active: 8m 12s (65.3%)                                      │
│   Human Wait: 2m 45s (21.9%)                                        │
│   Orchestrator: 1m 37s (12.8%)                                      │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│ Tokens • 127,432 total                                              │
│                                                                     │
│   Total Tokens: 127,432                                             │
│   Inference Tokens: 89,201 (70.0%)                                  │
│   Input Tokens: 31,847 (25.0%)                                      │
│   Output Tokens: 57,354 (45.0%)                                     │
│   Context Retrieval: 38,231 (30.0%)                                 │
│                                                                     │
│   By Schedule:                                                      │
│     Knowledge: 34,521 (27.1%)                                       │
│     Plan: 28,934 (22.7%)                                            │
│     Implement: 41,287 (32.4%)                                       │
│     Scale: 12,453 (9.8%)                                            │
│     Production: 10,237 (8.0%)                                       │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│ Generation Flow • Process-by-Process Token Recount                  │
│                                                                     │
│ S1P1212323S2P123S4P123S3P123S5P123                                  │
│                                                                     │
│ S1 (Knowledge):                                                     │
│   P1 Research    +2,341 tokens    2,341 / 127,432 (1.8%)            │
│   P2 Crawl       +5,672 tokens    8,013 / 127,432 (6.3%)            │
│   P1 Research    +1,893 tokens    9,906 / 127,432 (7.8%)            │
│   P2 Crawl       +4,521 tokens   14,427 / 127,432 (11.3%)           │
│   P3 Retrieve    +8,234 tokens   22,661 / 127,432 (17.8%)           │
│   P2 Crawl       +3,891 tokens   26,552 / 127,432 (20.8%)           │
│   P3 Retrieve    +7,969 tokens   34,521 / 127,432 (27.1%)           │
│                                                                     │
│ S2 (Plan):                                                          │
│   P1 Brainstorm  +4,234 tokens   38,755 / 127,432 (30.4%)           │
│   P2 Clarify     +3,891 tokens   42,646 / 127,432 (33.5%)           │
│   P3 Plan        +6,721 tokens   49,367 / 127,432 (38.7%)           │
│   ...                                                               │
│                                                                     │
│ ─────────────────────────────────────────────────────────────────── │
│ Production Termination Justification:                               │
│                                                                     │
│   The orchestrator determined prompt termination appropriate        │
│   because:                                                          │
│                                                                     │
│   1. All user requirements from the initial prompt have been        │
│      implemented and verified through 2 Implement schedule cycles   │
│                                                                     │
│   2. Human feedback in both Feedback processes confirmed            │
│      satisfaction with the implementation approach                  │
│                                                                     │
│   3. Additional Plan schedules would not yield new understanding    │
│      as no ambiguities remain after 5 Clarify processes             │
│                                                                     │
│   4. Additional Implement schedules would not improve code          │
│      quality as all tests pass and lint is clean                    │
│                                                                     │
│   5. Scale schedule optimizations achieved target benchmarks        │
│                                                                     │
│   6. Production Harmonize process confirmed UI consistency          │
│      via vision model analysis                                      │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│ OllamaBot • TLDR                                                    │
│                                                                     │
│ {LLM-as-Judge comprehensive analysis - see Section 11}              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 10.3 Flow Code Format

The flow code encodes the entire orchestration history:

- `S{n}` = Schedule number (1-5), printed in WHITE
- `P{n}` = Process number (1-3), printed in BLUE
- `X` = Error marker, printed in RED, always at end next to failed process

**Examples**:
- `S1P123` = Knowledge schedule, processes 1→2→3
- `S2P1212323` = Plan schedule, processes 1→2→1→2→3→2→3
- `S3P12X` = Implement schedule, error at process 2

### 10.4 Flow Code Parser Script

```bash
#!/bin/bash
# parse_flow_code.sh - Parse obot orchestration flow code

parse_flow() {
    local code="$1"
    local i=0
    local schedule=""
    local process=""
    local error=false
    
    while [ $i -lt ${#code} ]; do
        char="${code:$i:1}"
        case "$char" in
            S)
                i=$((i + 1))
                schedule="${code:$i:1}"
                echo "Schedule $schedule started"
                ;;
            P)
                # Continue reading all process numbers until S or X or end
                i=$((i + 1))
                while [[ "${code:$i:1}" =~ [0-9] ]]; do
                    process="${code:$i:1}"
                    echo "  Process $process executed"
                    i=$((i + 1))
                done
                i=$((i - 1))  # Back up one
                ;;
            X)
                echo "  ERROR at Process $process"
                error=true
                ;;
        esac
        i=$((i + 1))
    done
    
    $error && return 1 || return 0
}

parse_flow "$1"
```

---

## 11. LLM-as-Judge Analysis

### 11.1 Expert Models

| Expert       | Role                                    | Analysis Focus                            |
|--------------|-----------------------------------------|-------------------------------------------|
| Orchestrator | Final synthesis and narrative           | Overall prompt adherence, coordination    |
| Coder        | Code quality expert                     | Implementation quality, patterns, errors  |
| Researcher   | Information quality expert              | Knowledge retrieval accuracy, coverage    |
| Vision       | UI/UX expert                            | Visual consistency, accessibility         |

### 11.2 Expert Analysis Protocol

1. **Individual Expert Analysis**: Each expert model analyzes:
   - Prompt adherence for their domain
   - Project quality in their specialty
   - Personal performance review (actions taken, errors made)

2. **Expert Report Format**:
   ```
   ═══════════════════════════════════════════════════════════════════
   {EXPERT_NAME} ANALYSIS
   ═══════════════════════════════════════════════════════════════════
   
   PROMPT ADHERENCE
   ────────────────
   Score: {0-100}%
   {Specific assessment of how well the prompt was followed}
   
   PROJECT QUALITY
   ───────────────
   Score: {0-100}%
   {Assessment of deliverable quality in expert's domain}
   
   PERFORMANCE REVIEW
   ──────────────────
   Actions Taken: {count}
   Errors Made: {count}
   {Self-assessment of execution quality}
   
   KEY OBSERVATIONS
   ────────────────
   • {observation_1}
   • {observation_2}
   • {observation_3}
   
   RECOMMENDATIONS
   ───────────────
   • {recommendation_1}
   • {recommendation_2}
   ```

3. **Expert Failure Handling**:
   - If an expert fails to respond after 1 retry, the orchestrator:
     - Records the failure as a system-wide indicator
     - Performs additional analysis FOR that expert
     - Notes in TLDR: "Expert {name} unresponsive - orchestrator substituted analysis"

### 11.3 Orchestrator Synthesis

The orchestrator receives all expert reports and produces the final TLDR:

```
═══════════════════════════════════════════════════════════════════════
OLLAMABOT TLDR
═══════════════════════════════════════════════════════════════════════

PROMPT GOAL
───────────
{Original user prompt, quoted verbatim}

IMPLEMENTATION SUMMARY
──────────────────────
{Factual description of what was built/changed}

EXPERT CONSENSUS
────────────────
Prompt Adherence: {average}% (Coder: {x}%, Researcher: {y}%, Vision: {z}%)
Project Quality: {average}% (Coder: {x}%, Researcher: {y}%, Vision: {z}%)

DISCOVERIES & LEARNINGS
───────────────────────
• {discovery_1}
• {discovery_2}
• {learning_1}
• {learning_2}

ISSUES ENCOUNTERED
──────────────────
• {issue_1} - Resolution: {resolution}
• {issue_2} - Resolution: {resolution}

QUALITY ASSESSMENT
──────────────────
The orchestrator determines this implementation to be:
{ACCEPTABLE | NEEDS_IMPROVEMENT | EXCEPTIONAL}

Justification:
{Unbiased, reproducible assessment based on concrete metrics}

ACTIONABLE RECOMMENDATIONS
──────────────────────────
1. {recommendation_1}
2. {recommendation_2}
3. {recommendation_3}

═══════════════════════════════════════════════════════════════════════
```

### 11.4 No Vibe-Coding Enforcement

**CRITICAL**: The TLDR must be:
- **Standardized**: Same structure every time
- **Reproducible**: Same inputs → same outputs
- **Factual**: Based on concrete metrics, not feelings
- **Unbiased**: No favoritism toward any component

**Prohibited Phrases**:
- "I think..."
- "It seems like..."
- "Probably..."
- "In my opinion..."
- "I feel..."

**Required Basis**:
- Token counts
- Error counts
- Test results
- Lint results
- Benchmark measurements
- Human feedback responses

---

## 12. Session Persistence

### 12.1 Session State Structure

```
~/.obot/sessions/
├── {session_id}/
│   ├── meta.json              # Session metadata
│   ├── flow.code              # Raw flow code
│   ├── states/
│   │   ├── 0001_S1P1.state    # State after S1P1
│   │   ├── 0002_S1P2.state    # State after S1P2
│   │   ├── ...
│   │   └── recurrence.json    # Recurrence relations
│   ├── checkpoints/
│   │   ├── S1_complete.tar.gz
│   │   ├── S2_complete.tar.gz
│   │   └── ...
│   ├── notes/
│   │   ├── orchestrator.md    # Orchestrator notes
│   │   ├── agent.md           # Agent notes
│   │   └── human.md           # Human inputs
│   ├── actions/
│   │   ├── actions.log        # All agent actions
│   │   └── diffs/
│   │       ├── 0001.diff
│   │       ├── 0002.diff
│   │       └── ...
│   ├── restore.sh             # Bash script to restore session
│   └── summary.txt            # Final prompt summary
└── index.json                 # All sessions index
```

### 12.2 Recurrence Relations

Each state relates to adjacent states through recurrence relations:

```json
{
  "states": [
    {
      "id": "0001_S1P1",
      "prev": null,
      "next": "0002_S1P2",
      "schedule": 1,
      "process": 1,
      "files_hash": "abc123...",
      "actions": ["A001", "A002"],
      "restore_from_prev": "apply_diff 0001.diff",
      "restore_from_next": "reverse_diff 0002.diff"
    },
    {
      "id": "0002_S1P2",
      "prev": "0001_S1P1",
      "next": "0003_S1P3",
      "schedule": 1,
      "process": 2,
      "files_hash": "def456...",
      "actions": ["A003", "A004", "A005"],
      "restore_from_prev": "apply_diff 0002.diff",
      "restore_from_next": "reverse_diff 0003.diff"
    }
  ]
}
```

### 12.3 Restore Script Generation

Each session generates a `restore.sh` script:

```bash
#!/bin/bash
# restore.sh - Restore obot session {session_id}
# Generated: {timestamp}
# 
# This script restores the session to any state without requiring AI.
# Uses only standard Unix tools: tar, patch, cp, rm

set -euo pipefail

SESSION_DIR="$(dirname "$0")"
TARGET_STATE="${1:-latest}"

usage() {
    echo "Usage: $0 [state_id|latest|list]"
    echo ""
    echo "States available:"
    ls -1 "$SESSION_DIR/states/" | grep -E '\.state$' | sed 's/\.state$//'
    echo ""
    echo "Examples:"
    echo "  $0 list              # List all states"
    echo "  $0 0005_S2P3         # Restore to specific state"
    echo "  $0 latest            # Restore to latest state"
}

list_states() {
    echo "Available states:"
    echo "================"
    while IFS= read -r state; do
        local id="${state%.state}"
        local schedule=$(jq -r ".states[] | select(.id==\"$id\") | .schedule" "$SESSION_DIR/states/recurrence.json")
        local process=$(jq -r ".states[] | select(.id==\"$id\") | .process" "$SESSION_DIR/states/recurrence.json")
        echo "  $id (Schedule $schedule, Process $process)"
    done < <(ls -1 "$SESSION_DIR/states/" | grep -E '\.state$')
}

restore_state() {
    local target="$1"
    local state_file="$SESSION_DIR/states/${target}.state"
    
    if [ ! -f "$state_file" ]; then
        echo "Error: State '$target' not found"
        usage
        exit 1
    fi
    
    echo "Restoring to state: $target"
    
    # Read state metadata
    local files_hash=$(jq -r ".states[] | select(.id==\"$target\") | .files_hash" "$SESSION_DIR/states/recurrence.json")
    
    # Find closest checkpoint
    local schedule=$(jq -r ".states[] | select(.id==\"$target\") | .schedule" "$SESSION_DIR/states/recurrence.json")
    local checkpoint="$SESSION_DIR/checkpoints/S${schedule}_complete.tar.gz"
    
    if [ -f "$checkpoint" ]; then
        echo "Restoring from checkpoint: S${schedule}_complete"
        tar -xzf "$checkpoint" -C .
    fi
    
    # Apply diffs forward or backward to reach target
    apply_diffs_to_target "$target"
    
    # Verify restoration
    local current_hash=$(compute_files_hash)
    if [ "$current_hash" = "$files_hash" ]; then
        echo "✓ Restoration verified"
    else
        echo "⚠ Warning: Hash mismatch. Files may differ from original state."
    fi
}

compute_files_hash() {
    find . -type f -name "*.go" -o -name "*.md" -o -name "*.json" | \
        sort | \
        xargs cat 2>/dev/null | \
        sha256sum | \
        cut -d' ' -f1
}

apply_diffs_to_target() {
    local target="$1"
    # Implementation: walk recurrence relations and apply/reverse diffs
    # This is deterministic and requires no AI
    
    local current_state=$(cat "$SESSION_DIR/.current_state" 2>/dev/null || echo "0000_init")
    
    # Find path from current to target
    local path=$(find_path "$current_state" "$target")
    
    for step in $path; do
        local direction="${step%:*}"
        local diff_file="${step#*:}"
        
        if [ "$direction" = "forward" ]; then
            patch -p1 < "$SESSION_DIR/actions/diffs/$diff_file"
        else
            patch -R -p1 < "$SESSION_DIR/actions/diffs/$diff_file"
        fi
    done
    
    echo "$target" > "$SESSION_DIR/.current_state"
}

find_path() {
    # BFS through recurrence relations
    # Returns: forward:0001.diff forward:0002.diff OR reverse:0003.diff reverse:0002.diff
    local from="$1"
    local to="$2"
    
    # Implementation uses recurrence.json to find path
    jq -r --arg from "$from" --arg to "$to" '
        # Path finding algorithm implementation
        # Returns space-separated list of direction:diff pairs
    ' "$SESSION_DIR/states/recurrence.json"
}

case "${TARGET_STATE}" in
    list)
        list_states
        ;;
    latest)
        latest=$(ls -1 "$SESSION_DIR/states/" | grep -E '\.state$' | sort | tail -1 | sed 's/\.state$//')
        restore_state "$latest"
        ;;
    -h|--help)
        usage
        ;;
    *)
        restore_state "$TARGET_STATE"
        ;;
esac
```

### 12.4 Forward/Backward Versioning Compatibility

**Design Principles**:
1. **State files are version-tagged**: Include format version in header
2. **Recurrence relations are stable**: Mathematical structure doesn't change
3. **Diffs are universal**: Standard unified diff format
4. **Checksums enable verification**: Can detect corruption
5. **No AI required**: Pure bash/Unix tools for restoration

**Compatibility Matrix**:
| From Version | To Version | Supported | Method                    |
|--------------|------------|-----------|---------------------------|
| v1.x         | v1.x       | ✓         | Direct restore            |
| v1.x         | v2.x       | ✓         | Migration script          |
| v2.x         | v1.x       | ✓         | Reverse migration script  |
| Any          | Any        | ✓         | Diffs are format-agnostic |

---

## 13. Git Integration

### 13.1 Overview

Full GitHub and GitLab integration with NO functionality omitted.

### 13.2 Authentication

#### GitHub Authentication

```bash
# Option 1: OAuth Device Flow (preferred)
obot auth github

# Option 2: Personal Access Token
obot auth github --token

# Option 3: SSH Key
obot auth github --ssh
```

#### GitLab Authentication

```bash
# Option 1: OAuth
obot auth gitlab

# Option 2: Personal Access Token
obot auth gitlab --token

# Option 3: SSH Key
obot auth gitlab --ssh
```

### 13.3 Repository Creation Flags

```bash
# Create GitHub repository alongside obot project
obot orchestrate --hub "my-project" "Build a REST API"

# Create GitLab repository alongside obot project
obot orchestrate --lab "my-project" "Build a REST API"

# Create both
obot orchestrate --hub "my-project" --lab "my-project" "Build a REST API"
```

### 13.4 Git Operations

**All Git functionality is self-implemented. No omissions.**

| Category          | Operations                                                           |
|-------------------|----------------------------------------------------------------------|
| Repository        | init, clone, fork, create, delete, archive, unarchive, transfer      |
| Branches          | list, create, delete, rename, protect, default, merge, compare       |
| Commits           | list, show, cherry-pick, revert, compare, gpg-sign                   |
| Tags              | list, create, delete, verify                                         |
| Remotes           | list, add, remove, rename, set-url, fetch, pull, push                |
| Stash             | list, save, pop, apply, drop, clear                                  |
| Index             | add, remove, reset, diff, status                                     |
| Working Tree      | checkout, clean, restore                                             |
| Merge             | merge, rebase, abort, continue, squash                               |
| Diff              | diff, diff-cached, diff-tree                                         |
| Log               | log, shortlog, reflog                                                |
| Blame             | blame, annotate                                                      |
| Bisect            | start, good, bad, reset                                              |
| Submodules        | add, init, update, sync, deinit                                      |
| Worktrees         | add, list, remove, prune                                             |
| Hooks             | list, install, uninstall, run                                        |
| Config            | get, set, unset, list                                                |
| GitHub-Specific   | pull-requests, issues, actions, releases, gists, discussions, wiki   |
| GitLab-Specific   | merge-requests, issues, pipelines, releases, snippets, wiki, boards  |

### 13.5 Auto-Push on Prompt Completion

When a prompt finishes successfully:

```go
func onPromptComplete(session *Session) error {
    // 1. Stage all changes
    git.Add(".")
    
    // 2. Create commit with summary
    message := generateCommitMessage(session)
    git.Commit(message)
    
    // 3. Push to configured remotes
    if session.HasGitHub() {
        git.Push("github", "main")
    }
    if session.HasGitLab() {
        git.Push("gitlab", "main")
    }
    
    // 4. Create release if version bump detected
    if session.HasVersionBump() {
        createRelease(session)
    }
    
    return nil
}
```

### 13.6 Commit Message Format

```
[obot] {brief_summary}

Session: {session_id}
Flow: {flow_code}
Schedules: {schedule_count}
Processes: {process_count}

Changes:
{agent_action_summary}

Human Prompts:
- Initial: {initial_prompt}
- Clarifications: {clarification_count}
- Feedback: {feedback_count}

Signed-off-by: obot <obot@local>
```

### 13.7 Session-Git Mapping

Each session state maps to a git commit:

```
Session State          Git Commit
─────────────────────────────────────────
0001_S1P1         →    abc1234 "S1P1: Initial research"
0002_S1P2         →    def5678 "S1P2: Crawled documentation"
0003_S1P3         →    ghi9012 "S1P3: Retrieved API specs"
...
```

This enables:
- `git checkout abc1234` to restore session state 0001_S1P1
- `obot restore 0001_S1P1` to restore via obot
- Both methods produce identical results

---

## 14. Resource Management

### 14.1 Resource Limits Configuration

**Default: No limits (functionally infinite framework)**

```yaml
# ~/.obot/config.yaml
resources:
  memory:
    limit: null        # No limit by default
    warning: 80%       # Warn at 80% of system RAM
    critical: 95%      # Critical at 95% of system RAM
  
  disk:
    limit: null        # No limit by default
    warning: 90%       # Warn at 90% disk usage
  
  tokens:
    limit: null        # No limit by default
    per_schedule: null # No per-schedule limit
    per_process: null  # No per-process limit
  
  time:
    timeout: null      # No timeout by default
    per_schedule: null # No per-schedule timeout
    per_process: null  # No per-process timeout
```

### 14.2 Setting Limits

```bash
# Set memory limit
obot config set resources.memory.limit 8GB

# Set token limit
obot config set resources.tokens.limit 500000

# Set per-schedule timeout
obot config set resources.time.per_schedule 30m

# Set per-process timeout
obot config set resources.time.per_process 5m
```

### 14.3 Resource Summary (in Prompt Summary)

```
├─────────────────────────────────────────────────────────────────────┤
│ Resources • Summary                                                 │
│                                                                     │
│ Memory:                                                             │
│   Peak Usage: 4.2 GB                                                │
│   Average Usage: 2.8 GB                                             │
│   Limit: None (unlimited)                                           │
│   Pressure Events: 0 warning, 0 critical                            │
│   Predictions Accuracy: 87.3% (within 500MB)                        │
│                                                                     │
│ Disk:                                                               │
│   Files Written: 847 KB                                             │
│   Files Deleted: 12 KB                                              │
│   Net Change: +835 KB                                               │
│   Session Storage: 2.3 MB                                           │
│   Limit: None (unlimited)                                           │
│                                                                     │
│ Tokens:                                                             │
│   Total: 127,432                                                    │
│   Limit: None (unlimited)                                           │
│   Cost Estimate: $0.00 (local inference)                            │
│                                                                     │
│ Time:                                                               │
│   Total Duration: 12m 34s                                           │
│   Limit: None (unlimited)                                           │
│   Timeouts: 0                                                       │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
```

---

## 15. Terminal UI Application

### 15.1 Application Launch

```bash
obot orchestrate
```

Launches a full-featured terminal application.

### 15.2 UI Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  ┌─────────┐                                                                │
│  │ 🦙      │  obot orchestrate v{version}                                   │
│  └─────────┘                                                                │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│ Orchestrator • ...                                                          │
│ Schedule • ...                                                              │
│ Process • ...                                                               │
│ Agent • ...                                                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│ Memory                                                                      │
│ ├─ Current: ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  0.0 GB / 8 GB          │
│ ├─ Peak:    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  0.0 GB                  │
│ └─ Predict: ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  -- GB                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Output Area (scrollable)                                                   │
│                                                                             │
│                                                                             │
│                                                                             │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ Type your prompt here...                                                │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                                                          [Send] [Stop]      │
│                                                                             │
│ [🧠 Orchestrator] [</> Coder]  ← Toggle for note destination               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 15.3 UI Components

#### Logo Area
- **Initial State**: OllamaBot logo (🦙) indicating no prompt given
- **Active State**: Toggle between:
  - 🧠 Orchestrator brain icon (when sending notes to orchestrator)
  - </> Coder icon (when sending notes to agent)

#### Status Panel
- Fixed 4-line display with ANSI in-place updates
- Shows: Orchestrator state, Schedule name, Process name, Agent action
- Animated dots (250ms) when waiting for first message at each level

#### Memory Panel
- Real-time memory visualization
- Current/Peak/Predict bars
- Updates every 100ms

#### Output Area
- Scrollable area for agent output, diffs, and verbose information
- Supports ANSI colors for diff visualization

#### Input Area
- Multi-line text input
- [Send] button to submit
- [Stop] button to interrupt generation (appears after initial prompt)

#### Note Destination Toggle
- [🧠 Orchestrator] - Notes go to orchestrator's session notes
- [</> Coder] - Notes go to agent's session notes
- Orchestrator reviews its notes after each process termination
- Agent reviews its notes during human feedback processes

### 15.4 Interaction Flow

1. **Initial State**: Logo shown, waiting for prompt
2. **User types prompt**: Input area active
3. **User clicks Send**: 
   - Prompt submitted
   - [Send] changes to [Stop]
   - Logo toggles to Orchestrator icon
   - Status panel begins updating
4. **During generation**:
   - User can type and send notes (added to session)
   - User can toggle note destination
   - User can click [Stop] to interrupt
5. **Human consultation**:
   - Input area becomes consultation mode
   - Timer displayed
   - Previously added notes shown to agent/orchestrator
6. **Completion**:
   - Summary displayed
   - [Stop] changes back to [Send]
   - Ready for new prompt or session commands

### 15.5 Session Notes

**Anything typed and sent during a session is added to notes.**

```go
type SessionNotes struct {
    Orchestrator []Note  // Notes for orchestrator
    Agent        []Note  // Notes for agent
    Human        []Note  // Human consultation responses
}

type Note struct {
    Timestamp  time.Time
    Content    string
    Source     string  // "user", "ai-substitute"
    Reviewed   bool    // Has this note been reviewed?
}
```

**Note Review Rules**:
- Agent reviews agent notes during Feedback (P3 of Implement)
- Orchestrator reviews orchestrator notes after every process termination
- Human consultation answers stored in Human notes for reference

---

## 16. Configuration

### 16.1 Configuration File

```yaml
# ~/.obot/config.yaml

# Core settings
version: "1.0"
verbose: true

# Ollama settings
ollama:
  url: "http://localhost:11434"
  
# Model assignments
models:
  orchestrator: "qwen3:latest"      # Best planner/writer
  coder: "qwen2.5-coder:14b"        # Coding model
  researcher: "nomic-embed-text"    # RAG model
  vision: "llava:13b"               # Vision model

# Resource limits (default: no limits)
resources:
  memory:
    limit: null
    warning: 80%
    critical: 95%
  disk:
    limit: null
  tokens:
    limit: null
  time:
    timeout: null

# Git integration
git:
  github:
    enabled: false
    username: null
    token_path: "~/.obot/github_token"
  gitlab:
    enabled: false
    username: null
    token_path: "~/.obot/gitlab_token"
  auto_push: true
  commit_signing: false

# UI settings
ui:
  colors: true
  memory_graph: true
  animations: true
  dot_interval_ms: 250
  memory_update_ms: 100

# Human consultation
consultation:
  timeout_seconds: 60
  countdown_seconds: 15
  ai_substitute: true
```

### 16.2 Command-Line Options

```
obot orchestrate [options] ["initial prompt"]

Options:
  --config <path>        Use custom config file
  --verbose, -v          Enable verbose output (default: true)
  --quiet, -q            Disable verbose output
  
  --model <tag>          Override coder model
  --orchestrator <tag>   Override orchestrator model
  --researcher <tag>     Override researcher model
  --vision <tag>         Override vision model
  
  --memory-limit <size>  Set memory limit (e.g., 8GB)
  --token-limit <count>  Set token limit
  --timeout <duration>   Set overall timeout (e.g., 30m, 2h)
  
  --hub <name>           Create GitHub repository
  --lab <name>           Create GitLab repository
  
  --no-colors            Disable ANSI colors
  --no-memory-graph      Disable memory visualization
  --no-animations        Disable animations
  
  --session <id>         Resume existing session
  --list-sessions        List all sessions
  --restore <state>      Restore to specific state
  
  --dry-run              Simulate without executing
  --export <path>        Export session to path
```

---

## 17. Implementation Modules

### 17.1 Module Structure

```
internal/
├── orchestrate/
│   ├── orchestrator.go      # Core orchestrator logic
│   ├── scheduler.go         # Schedule management
│   ├── navigator.go         # Process navigation
│   ├── terminator.go        # Termination logic
│   └── state.go             # State management
│
├── schedule/
│   ├── knowledge.go         # Knowledge schedule
│   ├── plan.go              # Plan schedule
│   ├── implement.go         # Implement schedule
│   ├── scale.go             # Scale schedule
│   └── production.go        # Production schedule
│
├── process/
│   ├── process.go           # Process interface
│   ├── research.go          # Research process
│   ├── crawl.go             # Crawl process
│   ├── retrieve.go          # Retrieve process
│   ├── brainstorm.go        # Brainstorm process
│   ├── clarify.go           # Clarify process
│   ├── plan.go              # Plan process
│   ├── implement.go         # Implement process
│   ├── verify.go            # Verify process
│   ├── feedback.go          # Feedback process
│   ├── scale.go             # Scale process
│   ├── benchmark.go         # Benchmark process
│   ├── optimize.go          # Optimize process
│   ├── analyze.go           # Analyze process
│   ├── systemize.go         # Systemize process
│   └── harmonize.go         # Harmonize process
│
├── agent/
│   ├── agent.go             # Agent interface
│   ├── actions.go           # Action definitions
│   ├── executor.go          # Action executor
│   ├── recorder.go          # Action recording
│   └── diff.go              # Diff generation
│
├── model/
│   ├── coordinator.go       # Model coordination
│   ├── orchestrator.go      # Orchestrator model
│   ├── coder.go             # Coder model
│   ├── researcher.go        # Researcher model
│   └── vision.go            # Vision model
│
├── ui/
│   ├── app.go               # Terminal application
│   ├── display.go           # Status display
│   ├── memory.go            # Memory visualization
│   ├── input.go             # User input handling
│   ├── output.go            # Output rendering
│   ├── ansi.go              # ANSI code helpers
│   └── animations.go        # Dot animations
│
├── consultation/
│   ├── handler.go           # Consultation handler
│   ├── timeout.go           # Timeout management
│   ├── countdown.go         # Countdown display
│   └── substitute.go        # AI substitute
│
├── session/
│   ├── session.go           # Session management
│   ├── persistence.go       # State persistence
│   ├── recurrence.go        # Recurrence relations
│   ├── restore.go           # Restoration logic
│   └── notes.go             # Session notes
│
├── git/
│   ├── git.go               # Git operations
│   ├── github.go            # GitHub integration
│   ├── gitlab.go            # GitLab integration
│   ├── auth.go              # Authentication
│   ├── repository.go        # Repository operations
│   ├── branch.go            # Branch operations
│   ├── commit.go            # Commit operations
│   ├── remote.go            # Remote operations
│   ├── merge.go             # Merge operations
│   ├── pullrequest.go       # PR/MR operations
│   ├── issue.go             # Issue operations
│   ├── release.go           # Release operations
│   ├── actions.go           # CI/CD operations
│   └── hook.go              # Hook operations
│
├── resource/
│   ├── monitor.go           # Resource monitoring
│   ├── memory.go            # Memory management
│   ├── predictor.go         # Prediction engine
│   └── limits.go            # Limit enforcement
│
├── summary/
│   ├── generator.go         # Summary generation
│   ├── flowcode.go          # Flow code generation
│   ├── statistics.go        # Statistics calculation
│   └── tldr.go              # TLDR generation
│
├── judge/
│   ├── judge.go             # LLM-as-judge coordinator
│   ├── expert.go            # Expert analysis
│   ├── synthesis.go         # Synthesis logic
│   └── metrics.go           # Quality metrics
│
└── error/
    ├── handler.go           # Error handling
    ├── suspension.go        # Suspension logic
    ├── recovery.go          # Recovery logic
    └── hardcoded.go         # Hardcoded errors
```

### 17.2 Core Interfaces

```go
// Orchestrator interface
type Orchestrator interface {
    SelectSchedule() (Schedule, error)
    SelectProcess(Schedule) (Process, error)
    TerminateProcess(Process) error
    TerminateSchedule(Schedule) error
    TerminatePrompt() error
    ReviewNotes() error
}

// Agent interface
type Agent interface {
    Execute(Process) error
    CreateFile(path string) error
    DeleteFile(path string) error
    EditFile(path string, edits []Edit) error
    RunCommand(cmd string) (int, error)
    // ... all allowed actions
}

// Schedule interface
type Schedule interface {
    ID() int
    Name() string
    Processes() []Process
    GetModel() Model
}

// Process interface
type Process interface {
    ID() int
    Name() string
    Execute(Agent, context.Context) error
    RequiresHumanConsultation() bool
}

// Session interface
type Session interface {
    ID() string
    Save() error
    Restore(stateID string) error
    GenerateRestoreScript() error
    AddNote(destination NoteDestination, content string)
    GetNotes(destination NoteDestination) []Note
}
```

---

## Options

```
-h, --help              Show this help message
-v, --version           Show version information
```

## Examples

```bash
# Start interactive orchestration
obot orchestrate

# Start with initial prompt
obot orchestrate "Build a REST API for user management"

# Start with GitHub repository
obot orchestrate --hub "my-api" "Build a REST API"

# Resume a previous session
obot orchestrate --session abc123

# List all sessions
obot orchestrate --list-sessions

# Restore to specific state
obot orchestrate --restore 0005_S2P3

# Export session
obot orchestrate --export ./backup/
```

## See Also

- `obot fix` - Quick code fixes
- `obot plan` - Generate task plans
- `obot review` - Run code review
- `obot stats` - View usage statistics
- `obot config` - Manage configuration
