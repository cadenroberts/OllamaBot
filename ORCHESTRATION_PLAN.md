# obot Orchestration Implementation Plan

This document contains the complete technical implementation plan for the obot orchestration framework. It expands upon the specification in `.cursor/commands/orchestrate.md` with concrete implementation details.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Data Structures](#2-data-structures)
3. [Orchestrator Implementation](#3-orchestrator-implementation)
4. [Schedule Implementation](#4-schedule-implementation)
5. [Process Implementation](#5-process-implementation)
6. [Agent Implementation](#6-agent-implementation)
7. [Model Coordination](#7-model-coordination)
8. [Display System](#8-display-system)
9. [Memory Visualization](#9-memory-visualization)
10. [Human Consultation](#10-human-consultation)
11. [Error Handling](#11-error-handling)
12. [Session Persistence](#12-session-persistence)
13. [Git Integration](#13-git-integration)
14. [Resource Management](#14-resource-management)
15. [Terminal UI](#15-terminal-ui)
16. [Prompt Summary](#16-prompt-summary)
17. [LLM-as-Judge](#17-llm-as-judge)
18. [Testing Strategy](#18-testing-strategy)
19. [Migration Path](#19-migration-path)
20. [Open Implementation Questions](#20-open-implementation-questions)

---

## 1. Architecture Overview

### 1.1 System Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              TERMINAL UI                                      │
│  ┌─────────────┐ ┌─────────────────────┐ ┌─────────────────────────────────┐ │
│  │ Status Panel│ │ Memory Visualization│ │ Output Area                     │ │
│  │ (4 lines)   │ │ (3 bars)            │ │ (scrollable)                    │ │
│  └─────────────┘ └─────────────────────┘ └─────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ Input Area + [Send] [Stop] + Note Destination Toggle                   │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                            ORCHESTRATOR                                       │
│                                                                              │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐          │
│  │ Schedule        │    │ Process         │    │ Termination     │          │
│  │ Selector        │───▶│ Navigator       │───▶│ Logic           │          │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘          │
│           │                     │                     │                      │
│           ▼                     ▼                     ▼                      │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │                     STATE MACHINE                                │        │
│  │  ┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐          │        │
│  │  │ BEGIN  │───▶│SCHEDULE│───▶│PROCESS │───▶│COMPLETE│          │        │
│  │  └────────┘    └────────┘    └────────┘    └────────┘          │        │
│  │       │             ▲            │             │                │        │
│  │       │             │            ▼             │                │        │
│  │       │             │       ┌────────┐        │                │        │
│  │       │             └───────│SUSPEND │◀───────┘                │        │
│  │       │                     └────────┘                          │        │
│  └───────│─────────────────────────────────────────────────────────┘        │
│          │                                                                   │
└──────────│───────────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                               AGENT                                           │
│                                                                              │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐          │
│  │ Action          │    │ Action          │    │ Action          │          │
│  │ Validator       │───▶│ Executor        │───▶│ Recorder        │          │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘          │
│           │                     │                     │                      │
│           ▼                     ▼                     ▼                      │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │                     MODEL COORDINATOR                            │        │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │        │
│  │  │Orchestr. │  │ Coder    │  │Researcher│  │ Vision   │        │        │
│  │  │ Model    │  │ Model    │  │ Model    │  │ Model    │        │        │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘        │        │
│  └─────────────────────────────────────────────────────────────────┘        │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                          PERSISTENCE LAYER                                    │
│                                                                              │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐          │
│  │ Session         │    │ Recurrence      │    │ Git             │          │
│  │ Manager         │◀──▶│ Relations       │◀──▶│ Integration     │          │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘          │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Component Dependencies

```go
// Dependency injection structure
type OrchestratorApp struct {
    // Core components
    orchestrator *Orchestrator
    agent        *Agent
    session      *Session
    
    // Model coordination
    models       *ModelCoordinator
    
    // UI components
    ui           *TerminalUI
    display      *StatusDisplay
    memoryViz    *MemoryVisualization
    
    // Persistence
    persistence  *SessionPersistence
    git          *GitIntegration
    
    // Resource management
    resources    *ResourceMonitor
    
    // Error handling
    errorHandler *ErrorHandler
}
```

### 1.3 Event Flow

```
User Input
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│ Input Handler                                            │
│  - Validate input                                        │
│  - Route to appropriate component                        │
│  - Add to session notes if during generation             │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│ Orchestrator Decision Loop                               │
│  while (!promptTerminated) {                             │
│      schedule := selectSchedule()                        │
│      while (!scheduleTerminated) {                       │
│          process := selectProcess(schedule)              │
│          agent.execute(process)                          │
│          waitForCompletion()                             │
│          terminateProcess(process)                       │
│          reviewNotes()                                   │
│      }                                                   │
│      terminateSchedule(schedule)                         │
│  }                                                       │
│  terminatePrompt()                                       │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│ Summary Generation                                       │
│  - Generate flow code                                    │
│  - Calculate statistics                                  │
│  - Run LLM-as-judge analysis                            │
│  - Output TLDR                                          │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│ Persistence                                              │
│  - Save final session state                             │
│  - Generate restore script                              │
│  - Push to git (if configured)                          │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Data Structures

### 2.1 Core Types

```go
// internal/orchestrate/types.go

package orchestrate

import (
    "time"
)

// ScheduleID identifies one of the 5 schedules
type ScheduleID int

const (
    ScheduleKnowledge   ScheduleID = 1
    SchedulePlan        ScheduleID = 2
    ScheduleImplement   ScheduleID = 3
    ScheduleScale       ScheduleID = 4
    ScheduleProduction  ScheduleID = 5
)

// ScheduleNames maps IDs to display names
var ScheduleNames = map[ScheduleID]string{
    ScheduleKnowledge:  "Knowledge",
    SchedulePlan:       "Plan",
    ScheduleImplement:  "Implement",
    ScheduleScale:      "Scale",
    ScheduleProduction: "Production",
}

// ProcessID identifies a process within a schedule (1, 2, or 3)
type ProcessID int

const (
    Process1 ProcessID = 1
    Process2 ProcessID = 2
    Process3 ProcessID = 3
)

// ProcessNames maps schedule+process to display names
var ProcessNames = map[ScheduleID]map[ProcessID]string{
    ScheduleKnowledge: {
        Process1: "Research",
        Process2: "Crawl",
        Process3: "Retrieve",
    },
    SchedulePlan: {
        Process1: "Brainstorm",
        Process2: "Clarify",
        Process3: "Plan",
    },
    ScheduleImplement: {
        Process1: "Implement",
        Process2: "Verify",
        Process3: "Feedback",
    },
    ScheduleScale: {
        Process1: "Scale",
        Process2: "Benchmark",
        Process3: "Optimize",
    },
    ScheduleProduction: {
        Process1: "Analyze",
        Process2: "Systemize",
        Process3: "Harmonize",
    },
}

// OrchestratorState represents the current orchestrator state
type OrchestratorState string

const (
    StateBegin            OrchestratorState = "Begin"
    StateSelecting        OrchestratorState = "Selecting"
    StateActive           OrchestratorState = "Active"
    StateSuspended        OrchestratorState = "Suspended"
    StatePromptTerminated OrchestratorState = "Prompt Terminated"
)

// Schedule represents a schedule instance
type Schedule struct {
    ID         ScheduleID
    Name       string
    Processes  [3]Process
    Model      ModelType
    StartTime  time.Time
    EndTime    time.Time
    Terminated bool
}

// Process represents a process instance
type Process struct {
    ID                       ProcessID
    Name                     string
    Schedule                 ScheduleID
    RequiresHumanConsultation bool
    ConsultationType         ConsultationType
    StartTime                time.Time
    EndTime                  time.Time
    Completed                bool
    Terminated               bool
}

// ConsultationType for human consultation
type ConsultationType string

const (
    ConsultationNone      ConsultationType = "none"
    ConsultationOptional  ConsultationType = "optional"  // Clarify
    ConsultationMandatory ConsultationType = "mandatory" // Feedback
)

// ModelType identifies model roles
type ModelType string

const (
    ModelOrchestrator ModelType = "orchestrator"
    ModelCoder        ModelType = "coder"
    ModelResearcher   ModelType = "researcher"
    ModelVision       ModelType = "vision"
)
```

### 2.2 Agent Action Types

```go
// internal/agent/actions.go

package agent

import (
    "time"
)

// ActionType enumerates all allowed agent actions
type ActionType string

const (
    ActionCreateFile   ActionType = "create_file"
    ActionDeleteFile   ActionType = "delete_file"
    ActionCreateDir    ActionType = "create_dir"
    ActionDeleteDir    ActionType = "delete_dir"
    ActionRenameFile   ActionType = "rename_file"
    ActionRenameDir    ActionType = "rename_dir"
    ActionMoveFile     ActionType = "move_file"
    ActionMoveDir      ActionType = "move_dir"
    ActionCopyFile     ActionType = "copy_file"
    ActionCopyDir      ActionType = "copy_dir"
    ActionRunCommand   ActionType = "run_command"
    ActionEditFile     ActionType = "edit_file"
    ActionComplete     ActionType = "complete"  // Process completion signal
)

// AllowedActions is the set of valid actions
var AllowedActions = map[ActionType]bool{
    ActionCreateFile: true,
    ActionDeleteFile: true,
    ActionCreateDir:  true,
    ActionDeleteDir:  true,
    ActionRenameFile: true,
    ActionRenameDir:  true,
    ActionMoveFile:   true,
    ActionMoveDir:    true,
    ActionCopyFile:   true,
    ActionCopyDir:    true,
    ActionRunCommand: true,
    ActionEditFile:   true,
    ActionComplete:   true,
}

// Action represents a single agent action
type Action struct {
    ID          string
    Type        ActionType
    Timestamp   time.Time
    
    // File/directory operations
    Path        string
    NewPath     string  // For rename/move/copy
    
    // Edit operations
    LineRanges  []LineRange
    DiffSummary string
    
    // Command operations
    Command     string
    ExitCode    int
    Stdout      string
    Stderr      string
    
    // Metadata
    Schedule    ScheduleID
    Process     ProcessID
    Duration    time.Duration
}

// LineRange represents a range of edited lines
type LineRange struct {
    Start int
    End   int
}

// ActionResult is returned after action execution
type ActionResult struct {
    Action  *Action
    Success bool
    Error   error
}
```

### 2.3 Session State

```go
// internal/session/state.go

package session

import (
    "time"
    "github.com/croberts/obot/internal/orchestrate"
    "github.com/croberts/obot/internal/agent"
)

// Session represents a complete orchestration session
type Session struct {
    ID            string
    CreatedAt     time.Time
    UpdatedAt     time.Time
    
    // Initial prompt
    Prompt        string
    
    // Current state
    CurrentState  *State
    States        []*State
    
    // Flow tracking
    FlowCode      string
    ScheduleRuns  map[orchestrate.ScheduleID]int
    
    // Notes
    OrchestratorNotes []Note
    AgentNotes        []Note
    HumanNotes        []Note
    
    // Statistics
    Stats         *SessionStats
    
    // Git configuration
    GitHubRepo    string
    GitLabRepo    string
    
    // Status
    Completed     bool
    Suspended     bool
    SuspendError  *SuspendError
}

// State represents a single state in the session
type State struct {
    ID            string  // Format: "0001_S1P1"
    Sequence      int
    Schedule      orchestrate.ScheduleID
    Process       orchestrate.ProcessID
    
    // Recurrence relations
    PrevState     string
    NextState     string
    
    // File system state
    FilesHash     string
    
    // Actions taken in this state
    Actions       []string  // Action IDs
    
    // Diff from previous state
    DiffFile      string
    
    // Timestamps
    StartTime     time.Time
    EndTime       time.Time
}

// Note represents a session note
type Note struct {
    ID        string
    Timestamp time.Time
    Content   string
    Source    NoteSource
    Reviewed  bool
}

// NoteSource identifies note origin
type NoteSource string

const (
    NoteSourceUser        NoteSource = "user"
    NoteSourceAISubstitute NoteSource = "ai_substitute"
    NoteSourceSystem      NoteSource = "system"
)

// SessionStats tracks session statistics
type SessionStats struct {
    // Schedule counts
    TotalSchedulings    int
    SchedulingsByID     map[orchestrate.ScheduleID]int
    
    // Process counts
    TotalProcesses      int
    ProcessesBySchedule map[orchestrate.ScheduleID]map[orchestrate.ProcessID]int
    
    // Action counts
    TotalActions        int
    ActionsByType       map[agent.ActionType]int
    FilesCreated        int
    FilesDeleted        int
    FilesEdited         int
    DirsCreated         int
    DirsDeleted         int
    CommandsRan         int
    
    // Token counts
    TotalTokens         int64
    InferenceTokens     int64
    InputTokens         int64
    OutputTokens        int64
    ContextTokens       int64
    TokensBySchedule    map[orchestrate.ScheduleID]int64
    TokensByProcess     map[string]int64  // "S1P1" -> count
    
    // Resource usage
    PeakMemory          int64
    AverageMemory       int64
    DiskWritten         int64
    DiskDeleted         int64
    
    // Timing
    TotalDuration       time.Duration
    AgentDuration       time.Duration
    HumanDuration       time.Duration
    OrchestratorDuration time.Duration
    
    // Consultation
    ClarifyCount        int
    FeedbackCount       int
    AISubstituteCount   int
}

// SuspendError contains suspension details
type SuspendError struct {
    Code        string
    Message     string
    Component   string  // "orchestrator", "agent", "system"
    Rule        string  // Which rule was violated
    State       *State
    Timestamp   time.Time
    Solutions   []string
    Recoverable bool
}
```

### 2.4 Recurrence Relations

```go
// internal/session/recurrence.go

package session

import (
    "encoding/json"
    "os"
)

// RecurrenceRelations defines state-to-state relationships
type RecurrenceRelations struct {
    States []StateRelation `json:"states"`
}

// StateRelation defines a single state's relations
type StateRelation struct {
    ID              string   `json:"id"`
    Prev            string   `json:"prev"`
    Next            string   `json:"next"`
    Schedule        int      `json:"schedule"`
    Process         int      `json:"process"`
    FilesHash       string   `json:"files_hash"`
    Actions         []string `json:"actions"`
    RestoreFromPrev string   `json:"restore_from_prev"`
    RestoreFromNext string   `json:"restore_from_next"`
}

// Save writes recurrence relations to file
func (r *RecurrenceRelations) Save(path string) error {
    data, err := json.MarshalIndent(r, "", "  ")
    if err != nil {
        return err
    }
    return os.WriteFile(path, data, 0644)
}

// Load reads recurrence relations from file
func LoadRecurrenceRelations(path string) (*RecurrenceRelations, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }
    var r RecurrenceRelations
    if err := json.Unmarshal(data, &r); err != nil {
        return nil, err
    }
    return &r, nil
}

// FindPath finds the path between two states
func (r *RecurrenceRelations) FindPath(from, to string) ([]PathStep, error) {
    // BFS implementation
    visited := make(map[string]bool)
    queue := []pathNode{{id: from, path: nil}}
    
    for len(queue) > 0 {
        current := queue[0]
        queue = queue[1:]
        
        if current.id == to {
            return current.path, nil
        }
        
        if visited[current.id] {
            continue
        }
        visited[current.id] = true
        
        state := r.findState(current.id)
        if state == nil {
            continue
        }
        
        // Try forward
        if state.Next != "" && !visited[state.Next] {
            newPath := append(append([]PathStep{}, current.path...), 
                PathStep{Direction: "forward", DiffFile: state.RestoreFromPrev})
            queue = append(queue, pathNode{id: state.Next, path: newPath})
        }
        
        // Try backward
        if state.Prev != "" && !visited[state.Prev] {
            newPath := append(append([]PathStep{}, current.path...), 
                PathStep{Direction: "reverse", DiffFile: state.RestoreFromNext})
            queue = append(queue, pathNode{id: state.Prev, path: newPath})
        }
    }
    
    return nil, fmt.Errorf("no path found from %s to %s", from, to)
}

type pathNode struct {
    id   string
    path []PathStep
}

// PathStep represents one step in restoration path
type PathStep struct {
    Direction string `json:"direction"` // "forward" or "reverse"
    DiffFile  string `json:"diff_file"`
}

func (r *RecurrenceRelations) findState(id string) *StateRelation {
    for i := range r.States {
        if r.States[i].ID == id {
            return &r.States[i]
        }
    }
    return nil
}
```

---

## 3. Orchestrator Implementation

### 3.1 Core Orchestrator

```go
// internal/orchestrate/orchestrator.go

package orchestrate

import (
    "context"
    "fmt"
    "sync"
    
    "github.com/croberts/obot/internal/ollama"
)

// Orchestrator manages schedule and process selection
type Orchestrator struct {
    mu             sync.Mutex
    state          OrchestratorState
    model          *ollama.Client
    
    // Current execution state
    currentSchedule *Schedule
    currentProcess  *Process
    
    // Tracking
    scheduleHistory []ScheduleID
    processHistory  []ProcessExecution
    scheduleCounts  map[ScheduleID]int
    
    // Session notes
    notes          []Note
    
    // Callbacks
    onStateChange  func(OrchestratorState)
    onSchedule     func(ScheduleID)
    onProcess      func(ScheduleID, ProcessID)
    onError        func(error)
}

// ProcessExecution tracks a single process execution
type ProcessExecution struct {
    Schedule  ScheduleID
    Process   ProcessID
    StartTime time.Time
    EndTime   time.Time
    Tokens    int64
}

// NewOrchestrator creates a new orchestrator
func NewOrchestrator(model *ollama.Client) *Orchestrator {
    return &Orchestrator{
        state:          StateBegin,
        model:          model,
        scheduleCounts: make(map[ScheduleID]int),
    }
}

// Run starts the orchestration loop
func (o *Orchestrator) Run(ctx context.Context, prompt string) error {
    o.setState(StateBegin)
    
    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        default:
        }
        
        // Check if we can terminate the prompt
        if o.canTerminatePrompt() {
            decision, err := o.decidePromptTermination(ctx)
            if err != nil {
                return o.handleError(err)
            }
            if decision.ShouldTerminate {
                o.setState(StatePromptTerminated)
                return nil
            }
        }
        
        // Select schedule
        o.setState(StateSelecting)
        scheduleID, err := o.selectSchedule(ctx)
        if err != nil {
            return o.handleError(err)
        }
        
        schedule := o.initializeSchedule(scheduleID)
        o.currentSchedule = schedule
        o.scheduleHistory = append(o.scheduleHistory, scheduleID)
        o.scheduleCounts[scheduleID]++
        
        if o.onSchedule != nil {
            o.onSchedule(scheduleID)
        }
        
        // Run schedule until termination
        if err := o.runSchedule(ctx, schedule); err != nil {
            return o.handleError(err)
        }
    }
}

// selectSchedule asks the orchestrator model to select a schedule
func (o *Orchestrator) selectSchedule(ctx context.Context) (ScheduleID, error) {
    prompt := o.buildScheduleSelectionPrompt()
    
    response, _, err := o.model.Chat(ctx, []ollama.Message{
        {Role: "system", Content: scheduleSelectionSystemPrompt},
        {Role: "user", Content: prompt},
    })
    if err != nil {
        return 0, fmt.Errorf("schedule selection failed: %w", err)
    }
    
    scheduleID, err := o.parseScheduleSelection(response)
    if err != nil {
        return 0, fmt.Errorf("invalid schedule selection: %w", err)
    }
    
    return scheduleID, nil
}

// runSchedule runs a schedule until termination
func (o *Orchestrator) runSchedule(ctx context.Context, schedule *Schedule) error {
    o.setState(StateActive)
    
    lastProcess := ProcessID(0)
    
    for {
        // Select next process
        processID, err := o.selectProcess(ctx, schedule.ID, lastProcess)
        if err != nil {
            return err
        }
        
        // Check for schedule termination
        if processID == 0 {
            schedule.Terminated = true
            schedule.EndTime = time.Now()
            return nil
        }
        
        // Validate navigation
        if !o.isValidNavigation(lastProcess, processID) {
            return &NavigationError{
                From: lastProcess,
                To:   processID,
            }
        }
        
        process := &schedule.Processes[processID-1]
        o.currentProcess = process
        
        if o.onProcess != nil {
            o.onProcess(schedule.ID, processID)
        }
        
        // Execute process (via agent)
        if err := o.executeProcess(ctx, schedule, process); err != nil {
            return err
        }
        
        // Process completed, now terminate it
        process.Terminated = true
        process.EndTime = time.Now()
        
        // Review notes after each process termination
        o.reviewNotes(ctx)
        
        lastProcess = processID
    }
}

// isValidNavigation checks if navigation from->to is allowed
func (o *Orchestrator) isValidNavigation(from, to ProcessID) bool {
    if from == 0 {
        // Initial state, can only go to P1
        return to == Process1
    }
    
    switch from {
    case Process1:
        // From P1: can go to P1 or P2
        return to == Process1 || to == Process2
    case Process2:
        // From P2: can go to P1, P2, or P3
        return to == Process1 || to == Process2 || to == Process3
    case Process3:
        // From P3: can go to P2, P3, or terminate (0)
        return to == Process2 || to == Process3 || to == 0
    }
    
    return false
}

// canTerminatePrompt checks if prompt termination is allowed
func (o *Orchestrator) canTerminatePrompt() bool {
    // All 5 schedules must have run at least once
    for id := ScheduleKnowledge; id <= ScheduleProduction; id++ {
        if o.scheduleCounts[id] < 1 {
            return false
        }
    }
    
    // Last terminated schedule must be Production
    if len(o.scheduleHistory) == 0 {
        return false
    }
    lastSchedule := o.scheduleHistory[len(o.scheduleHistory)-1]
    return lastSchedule == ScheduleProduction
}

// Navigation rules prompts
const scheduleSelectionSystemPrompt = `You are the obot orchestrator. Your ONLY job is to select the next schedule for the agent to execute.

You are a TOOLER, not an agent. You CANNOT:
- Create, edit, or delete files
- Run commands
- Generate code
- Make implementation decisions

You CAN ONLY:
- Select one of the 5 schedules: Knowledge, Plan, Implement, Scale, Production
- Decide when to terminate the prompt (only when ALL schedules have run and Production was last)

Respond with ONLY the schedule name, nothing else.`

func (o *Orchestrator) setState(state OrchestratorState) {
    o.mu.Lock()
    o.state = state
    o.mu.Unlock()
    
    if o.onStateChange != nil {
        o.onStateChange(state)
    }
}
```

### 3.2 Navigation Logic

```go
// internal/orchestrate/navigator.go

package orchestrate

import (
    "context"
    "fmt"
    "strings"
)

// Navigator handles process navigation within schedules
type Navigator struct {
    orchestrator *Orchestrator
}

// NavigationError represents an invalid navigation attempt
type NavigationError struct {
    From ProcessID
    To   ProcessID
}

func (e *NavigationError) Error() string {
    return fmt.Sprintf("invalid navigation from P%d to P%d (only 1↔2↔3 allowed)", e.From, e.To)
}

// selectProcess asks the orchestrator model to select the next process
func (o *Orchestrator) selectProcess(ctx context.Context, scheduleID ScheduleID, lastProcess ProcessID) (ProcessID, error) {
    // Build valid options based on current state
    var validOptions []string
    var canTerminate bool
    
    switch lastProcess {
    case 0:
        validOptions = []string{ProcessNames[scheduleID][Process1]}
    case Process1:
        validOptions = []string{
            ProcessNames[scheduleID][Process1],
            ProcessNames[scheduleID][Process2],
        }
    case Process2:
        validOptions = []string{
            ProcessNames[scheduleID][Process1],
            ProcessNames[scheduleID][Process2],
            ProcessNames[scheduleID][Process3],
        }
    case Process3:
        validOptions = []string{
            ProcessNames[scheduleID][Process2],
            ProcessNames[scheduleID][Process3],
        }
        canTerminate = true
    }
    
    prompt := o.buildProcessSelectionPrompt(scheduleID, lastProcess, validOptions, canTerminate)
    
    response, _, err := o.model.Chat(ctx, []ollama.Message{
        {Role: "system", Content: processSelectionSystemPrompt},
        {Role: "user", Content: prompt},
    })
    if err != nil {
        return 0, fmt.Errorf("process selection failed: %w", err)
    }
    
    return o.parseProcessSelection(response, scheduleID, validOptions, canTerminate)
}

const processSelectionSystemPrompt = `You are the obot orchestrator selecting the next process.

NAVIGATION RULES (STRICTLY ENFORCED):
- From initial state: can only select Process 1
- From Process 1: can select Process 1 (repeat) or Process 2
- From Process 2: can select Process 1, Process 2 (repeat), or Process 3
- From Process 3: can select Process 2, Process 3 (repeat), or TERMINATE schedule

Respond with ONLY the process name or "TERMINATE", nothing else.`

func (o *Orchestrator) buildProcessSelectionPrompt(scheduleID ScheduleID, lastProcess ProcessID, validOptions []string, canTerminate bool) string {
    var sb strings.Builder
    
    sb.WriteString(fmt.Sprintf("Schedule: %s\n", ScheduleNames[scheduleID]))
    sb.WriteString(fmt.Sprintf("Last Process: %s\n", ProcessNames[scheduleID][lastProcess]))
    sb.WriteString("\nValid options:\n")
    for _, opt := range validOptions {
        sb.WriteString(fmt.Sprintf("- %s\n", opt))
    }
    if canTerminate {
        sb.WriteString("- TERMINATE (end this schedule)\n")
    }
    
    sb.WriteString("\nWhat process should the agent do now?")
    
    return sb.String()
}

func (o *Orchestrator) parseProcessSelection(response string, scheduleID ScheduleID, validOptions []string, canTerminate bool) (ProcessID, error) {
    response = strings.TrimSpace(strings.ToLower(response))
    
    if canTerminate && (response == "terminate" || strings.Contains(response, "terminate")) {
        return 0, nil // 0 indicates schedule termination
    }
    
    // Match against process names
    for processID := Process1; processID <= Process3; processID++ {
        name := strings.ToLower(ProcessNames[scheduleID][processID])
        if strings.Contains(response, name) {
            // Verify it's a valid option
            for _, opt := range validOptions {
                if strings.ToLower(opt) == name {
                    return processID, nil
                }
            }
            return 0, fmt.Errorf("process %s is not a valid option", name)
        }
    }
    
    return 0, fmt.Errorf("could not parse process selection: %s", response)
}
```

---

## 4. Schedule Implementation

### 4.1 Schedule Factory

```go
// internal/schedule/factory.go

package schedule

import (
    "github.com/croberts/obot/internal/orchestrate"
)

// NewSchedule creates a schedule instance
func NewSchedule(id orchestrate.ScheduleID) *orchestrate.Schedule {
    schedule := &orchestrate.Schedule{
        ID:   id,
        Name: orchestrate.ScheduleNames[id],
    }
    
    // Initialize processes
    for i := orchestrate.Process1; i <= orchestrate.Process3; i++ {
        schedule.Processes[i-1] = orchestrate.Process{
            ID:       i,
            Name:     orchestrate.ProcessNames[id][i],
            Schedule: id,
        }
    }
    
    // Set model type
    switch id {
    case orchestrate.ScheduleKnowledge:
        schedule.Model = orchestrate.ModelResearcher
    case orchestrate.ScheduleProduction:
        schedule.Model = orchestrate.ModelCoder // Plus vision for Harmonize
    default:
        schedule.Model = orchestrate.ModelCoder
    }
    
    // Set consultation requirements
    if id == orchestrate.SchedulePlan {
        schedule.Processes[1].RequiresHumanConsultation = true
        schedule.Processes[1].ConsultationType = orchestrate.ConsultationOptional
    }
    if id == orchestrate.ScheduleImplement {
        schedule.Processes[2].RequiresHumanConsultation = true
        schedule.Processes[2].ConsultationType = orchestrate.ConsultationMandatory
    }
    
    return schedule
}
```

### 4.2 Knowledge Schedule

```go
// internal/schedule/knowledge.go

package schedule

import (
    "context"
    
    "github.com/croberts/obot/internal/agent"
    "github.com/croberts/obot/internal/orchestrate"
)

// KnowledgeSchedule implements the Knowledge schedule
type KnowledgeSchedule struct {
    *orchestrate.Schedule
}

// Research implements the Research process
func (k *KnowledgeSchedule) Research(ctx context.Context, ag *agent.Agent) error {
    // Research process:
    // 1. Identify knowledge gaps from the prompt
    // 2. Formulate specific research questions
    // 3. Determine what information sources to consult
    // 4. Create a research plan
    
    prompt := buildResearchPrompt(ag.GetSessionContext())
    
    return ag.ExecuteWithModel(ctx, orchestrate.ModelResearcher, prompt, func(action agent.ActionType, data interface{}) error {
        // Research process should primarily produce notes and queries
        // Not file operations
        switch action {
        case agent.ActionComplete:
            return nil
        default:
            // Research shouldn't create/edit files
            return &orchestrate.ProcessViolation{
                Process:  "Research",
                Action:   string(action),
                Message:  "Research process should not perform file operations",
            }
        }
    })
}

// Crawl implements the Crawl process
func (k *KnowledgeSchedule) Crawl(ctx context.Context, ag *agent.Agent) error {
    // Crawl process:
    // 1. Navigate to identified information sources
    // 2. Extract raw content from documentation, code, web
    // 3. Validate source authenticity
    // 4. Store retrieved content for processing
    
    prompt := buildCrawlPrompt(ag.GetSessionContext(), ag.GetResearchNotes())
    
    return ag.ExecuteWithModel(ctx, orchestrate.ModelResearcher, prompt, nil)
}

// Retrieve implements the Retrieve process
func (k *KnowledgeSchedule) Retrieve(ctx context.Context, ag *agent.Agent) error {
    // Retrieve process:
    // 1. Extract relevant information from crawled content
    // 2. Validate accuracy and relevance
    // 3. Structure information for use in other schedules
    // 4. Store in session context
    
    prompt := buildRetrievePrompt(ag.GetSessionContext(), ag.GetCrawledContent())
    
    return ag.ExecuteWithModel(ctx, orchestrate.ModelResearcher, prompt, nil)
}
```

### 4.3 Plan Schedule

```go
// internal/schedule/plan.go

package schedule

import (
    "context"
    
    "github.com/croberts/obot/internal/agent"
    "github.com/croberts/obot/internal/orchestrate"
    "github.com/croberts/obot/internal/consultation"
)

// PlanSchedule implements the Plan schedule
type PlanSchedule struct {
    *orchestrate.Schedule
    consultation *consultation.Handler
}

// Brainstorm implements the Brainstorm process
func (p *PlanSchedule) Brainstorm(ctx context.Context, ag *agent.Agent) error {
    // Brainstorm process:
    // 1. Generate multiple potential approaches
    // 2. Consider trade-offs and constraints
    // 3. Identify risks and dependencies
    // 4. Produce a list of viable approaches
    
    prompt := buildBrainstormPrompt(ag.GetSessionContext())
    
    return ag.ExecuteWithModel(ctx, orchestrate.ModelCoder, prompt, nil)
}

// Clarify implements the Clarify process (with optional human consultation)
func (p *PlanSchedule) Clarify(ctx context.Context, ag *agent.Agent) error {
    // Clarify process:
    // 1. Identify ambiguities in requirements
    // 2. Formulate specific clarification questions
    // 3. IF ambiguities exist, request human consultation
    // 4. Integrate clarifications into understanding
    
    // Check for ambiguities
    ambiguities, err := ag.IdentifyAmbiguities(ctx)
    if err != nil {
        return err
    }
    
    if len(ambiguities) > 0 {
        // Request human consultation
        for _, ambiguity := range ambiguities {
            question := buildClarifyQuestion(ambiguity)
            response, err := p.consultation.Request(ctx, question, consultation.Options{
                Timeout:         60 * time.Second,
                CountdownStart:  15 * time.Second,
                AllowAISubstitute: true,
            })
            if err != nil {
                return err
            }
            
            ag.AddClarification(ambiguity.ID, response)
        }
    }
    
    return nil
}

// Plan implements the Plan process
func (p *PlanSchedule) Plan(ctx context.Context, ag *agent.Agent) error {
    // Plan process:
    // 1. Synthesize brainstorm ideas and clarifications
    // 2. Create concrete implementation steps
    // 3. Define dependencies and ordering
    // 4. Produce final plan document
    
    prompt := buildPlanPrompt(ag.GetSessionContext(), ag.GetBrainstormResults(), ag.GetClarifications())
    
    return ag.ExecuteWithModel(ctx, orchestrate.ModelCoder, prompt, nil)
}
```

### 4.4 Implement Schedule

```go
// internal/schedule/implement.go

package schedule

import (
    "context"
    
    "github.com/croberts/obot/internal/agent"
    "github.com/croberts/obot/internal/orchestrate"
    "github.com/croberts/obot/internal/consultation"
)

// ImplementSchedule implements the Implement schedule
type ImplementSchedule struct {
    *orchestrate.Schedule
    consultation *consultation.Handler
}

// Implement implements the Implement process
func (i *ImplementSchedule) Implement(ctx context.Context, ag *agent.Agent) error {
    // Implement process:
    // 1. Execute plan steps
    // 2. Create/edit files as needed
    // 3. Run necessary commands
    // 4. Track all changes
    
    plan := ag.GetCurrentPlan()
    
    for _, step := range plan.Steps {
        if err := ag.ExecuteStep(ctx, step); err != nil {
            return err
        }
    }
    
    return nil
}

// Verify implements the Verify process
func (i *ImplementSchedule) Verify(ctx context.Context, ag *agent.Agent) error {
    // Verify process:
    // 1. Run tests
    // 2. Run linters
    // 3. Check build
    // 4. Validate implementation correctness
    
    results := &VerifyResults{}
    
    // Run tests
    testResult, err := ag.RunCommand(ctx, "go test ./...")
    if err != nil {
        results.TestError = err
    }
    results.Tests = testResult
    
    // Run lint
    lintResult, err := ag.RunCommand(ctx, "golangci-lint run")
    if err != nil {
        results.LintError = err
    }
    results.Lint = lintResult
    
    // Run build
    buildResult, err := ag.RunCommand(ctx, "go build ./...")
    if err != nil {
        results.BuildError = err
    }
    results.Build = buildResult
    
    ag.SetVerifyResults(results)
    
    return nil
}

// Feedback implements the Feedback process (mandatory human consultation)
func (i *ImplementSchedule) Feedback(ctx context.Context, ag *agent.Agent) error {
    // Feedback process:
    // 1. Demonstrate changes to human
    // 2. Present structured questions
    // 3. Collect feedback
    // 4. Integrate feedback for next iteration
    
    // First, review any agent notes
    ag.ReviewNotes()
    
    // Build demonstration
    demonstration := buildDemonstration(ag.GetChanges(), ag.GetVerifyResults())
    
    // Present to human with structured questions
    questions := buildFeedbackQuestions(demonstration)
    
    for _, question := range questions {
        response, err := i.consultation.Request(ctx, question, consultation.Options{
            Timeout:          60 * time.Second,
            CountdownStart:   15 * time.Second,
            AllowAISubstitute: true,
            Mandatory:        true,  // Feedback is mandatory
        })
        if err != nil {
            return err
        }
        
        ag.AddFeedback(question.ID, response)
    }
    
    return nil
}
```

### 4.5 Scale Schedule

```go
// internal/schedule/scale.go

package schedule

import (
    "context"
    
    "github.com/croberts/obot/internal/agent"
    "github.com/croberts/obot/internal/orchestrate"
)

// ScaleSchedule implements the Scale schedule
type ScaleSchedule struct {
    *orchestrate.Schedule
}

// Scale implements the Scale process
func (s *ScaleSchedule) Scale(ctx context.Context, ag *agent.Agent) error {
    // Scale process:
    // 1. Identify scaling concerns
    // 2. Refactor for performance
    // 3. Optimize algorithms
    // 4. Consider resource usage
    
    prompt := buildScalePrompt(ag.GetSessionContext())
    
    return ag.ExecuteWithModel(ctx, orchestrate.ModelCoder, prompt, nil)
}

// Benchmark implements the Benchmark process
func (s *ScaleSchedule) Benchmark(ctx context.Context, ag *agent.Agent) error {
    // Benchmark process:
    // 1. Define performance metrics
    // 2. Run benchmarks
    // 3. Collect results
    // 4. Compare against baselines
    
    // Run Go benchmarks
    benchResult, err := ag.RunCommand(ctx, "go test -bench=. -benchmem ./...")
    if err != nil {
        // Log but continue
    }
    
    ag.SetBenchmarkResults(benchResult)
    
    return nil
}

// Optimize implements the Optimize process
func (s *ScaleSchedule) Optimize(ctx context.Context, ag *agent.Agent) error {
    // Optimize process:
    // 1. Analyze benchmark results
    // 2. Identify optimization opportunities
    // 3. Apply targeted optimizations
    // 4. Prepare for re-benchmark
    
    benchResults := ag.GetBenchmarkResults()
    prompt := buildOptimizePrompt(ag.GetSessionContext(), benchResults)
    
    return ag.ExecuteWithModel(ctx, orchestrate.ModelCoder, prompt, nil)
}
```

### 4.6 Production Schedule

```go
// internal/schedule/production.go

package schedule

import (
    "context"
    
    "github.com/croberts/obot/internal/agent"
    "github.com/croberts/obot/internal/orchestrate"
)

// ProductionSchedule implements the Production schedule
type ProductionSchedule struct {
    *orchestrate.Schedule
}

// Analyze implements the Analyze process
func (p *ProductionSchedule) Analyze(ctx context.Context, ag *agent.Agent) error {
    // Analyze process:
    // 1. Comprehensive code analysis
    // 2. Security review
    // 3. Dependency audit
    // 4. Identify production concerns
    
    prompt := buildAnalyzePrompt(ag.GetSessionContext())
    
    return ag.ExecuteWithModel(ctx, orchestrate.ModelCoder, prompt, nil)
}

// Systemize implements the Systemize process
func (p *ProductionSchedule) Systemize(ctx context.Context, ag *agent.Agent) error {
    // Systemize process:
    // 1. Ensure consistent patterns
    // 2. Verify documentation
    // 3. Check configuration management
    // 4. Standardize project structure
    
    prompt := buildSystemizePrompt(ag.GetSessionContext())
    
    return ag.ExecuteWithModel(ctx, orchestrate.ModelCoder, prompt, nil)
}

// Harmonize implements the Harmonize process (with vision model for UI)
func (p *ProductionSchedule) Harmonize(ctx context.Context, ag *agent.Agent) error {
    // Harmonize process:
    // 1. Final integration testing
    // 2. UI polish (via vision model)
    // 3. Production preparation
    // 4. Final validation
    
    // Check if project has UI components
    hasUI := ag.HasUIComponents()
    
    if hasUI {
        // Use vision model for UI analysis
        uiAnalysis, err := ag.ExecuteWithModel(ctx, orchestrate.ModelVision, buildUIAnalysisPrompt(ag.GetSessionContext()), nil)
        if err != nil {
            return err
        }
        
        // Apply UI fixes with coder model
        if uiAnalysis.HasIssues {
            if err := ag.ExecuteWithModel(ctx, orchestrate.ModelCoder, buildUIFixPrompt(uiAnalysis), nil); err != nil {
                return err
            }
        }
    }
    
    // Final validation with coder model
    return ag.ExecuteWithModel(ctx, orchestrate.ModelCoder, buildHarmonizePrompt(ag.GetSessionContext()), nil)
}
```

---

## 5. Process Implementation

### 5.1 Process Interface

```go
// internal/process/process.go

package process

import (
    "context"
    
    "github.com/croberts/obot/internal/agent"
    "github.com/croberts/obot/internal/orchestrate"
)

// Process defines the interface for all processes
type Process interface {
    // Identification
    ID() orchestrate.ProcessID
    Name() string
    Schedule() orchestrate.ScheduleID
    
    // Execution
    Execute(ctx context.Context, ag *agent.Agent) error
    
    // Consultation
    RequiresHumanConsultation() bool
    ConsultationType() orchestrate.ConsultationType
    
    // Validation
    ValidateEntry(lastProcess orchestrate.ProcessID) error
}

// BaseProcess provides common functionality
type BaseProcess struct {
    id           orchestrate.ProcessID
    name         string
    schedule     orchestrate.ScheduleID
    consultation orchestrate.ConsultationType
}

func (p *BaseProcess) ID() orchestrate.ProcessID {
    return p.id
}

func (p *BaseProcess) Name() string {
    return p.name
}

func (p *BaseProcess) Schedule() orchestrate.ScheduleID {
    return p.schedule
}

func (p *BaseProcess) RequiresHumanConsultation() bool {
    return p.consultation != orchestrate.ConsultationNone
}

func (p *BaseProcess) ConsultationType() orchestrate.ConsultationType {
    return p.consultation
}

func (p *BaseProcess) ValidateEntry(lastProcess orchestrate.ProcessID) error {
    // Validate 1↔2↔3 rule
    switch p.id {
    case orchestrate.Process1:
        if lastProcess != 0 && lastProcess != orchestrate.Process1 && lastProcess != orchestrate.Process2 {
            return &InvalidNavigationError{From: lastProcess, To: p.id}
        }
    case orchestrate.Process2:
        if lastProcess != orchestrate.Process1 && lastProcess != orchestrate.Process2 && lastProcess != orchestrate.Process3 {
            return &InvalidNavigationError{From: lastProcess, To: p.id}
        }
    case orchestrate.Process3:
        if lastProcess != orchestrate.Process2 && lastProcess != orchestrate.Process3 {
            return &InvalidNavigationError{From: lastProcess, To: p.id}
        }
    }
    return nil
}

// InvalidNavigationError indicates a navigation rule violation
type InvalidNavigationError struct {
    From orchestrate.ProcessID
    To   orchestrate.ProcessID
}

func (e *InvalidNavigationError) Error() string {
    return fmt.Sprintf("invalid navigation: P%d → P%d (only 1↔2↔3 allowed)", e.From, e.To)
}
```

---

## 6. Agent Implementation

### 6.1 Agent Core

```go
// internal/agent/agent.go

package agent

import (
    "context"
    "fmt"
    "sync"
    "time"
    
    "github.com/croberts/obot/internal/orchestrate"
    "github.com/croberts/obot/internal/ollama"
)

// Agent executes processes and performs actions
type Agent struct {
    mu            sync.Mutex
    models        *ModelCoordinator
    currentModel  orchestrate.ModelType
    
    // Action tracking
    actions       []*Action
    actionCounter int
    
    // Session context
    sessionCtx    *SessionContext
    
    // Notes
    notes         []Note
    
    // Callbacks
    onAction      func(*Action)
    onComplete    func(orchestrate.ProcessID)
}

// NewAgent creates a new agent
func NewAgent(models *ModelCoordinator) *Agent {
    return &Agent{
        models:   models,
        actions:  make([]*Action, 0, 64),
    }
}

// Execute runs the agent for a process
func (a *Agent) Execute(ctx context.Context, schedule orchestrate.ScheduleID, process orchestrate.ProcessID) error {
    // Determine which model to use
    modelType := a.selectModel(schedule, process)
    a.currentModel = modelType
    
    model := a.models.Get(modelType)
    if model == nil {
        return fmt.Errorf("model %s not available", modelType)
    }
    
    // Build process prompt
    prompt := a.buildProcessPrompt(schedule, process)
    
    // Execute with model
    return a.executeWithModel(ctx, model, prompt)
}

// selectModel determines the appropriate model for the schedule/process
func (a *Agent) selectModel(schedule orchestrate.ScheduleID, process orchestrate.ProcessID) orchestrate.ModelType {
    switch schedule {
    case orchestrate.ScheduleKnowledge:
        return orchestrate.ModelResearcher
    case orchestrate.ScheduleProduction:
        if process == orchestrate.Process3 {
            // Harmonize may use vision model
            return orchestrate.ModelCoder // Vision model called separately
        }
        return orchestrate.ModelCoder
    default:
        return orchestrate.ModelCoder
    }
}

// executeWithModel runs the agent with a specific model
func (a *Agent) executeWithModel(ctx context.Context, model *ollama.Client, prompt string) error {
    // Stream response and parse actions
    var response strings.Builder
    
    _, err := model.ChatStream(ctx, []ollama.Message{
        {Role: "system", Content: agentSystemPrompt},
        {Role: "user", Content: prompt},
    }, func(token string) {
        response.WriteString(token)
        
        // Check for complete action in response
        if action := a.parsePartialAction(response.String()); action != nil {
            if err := a.executeAction(ctx, action); err != nil {
                // Log error but continue
            }
        }
    })
    
    return err
}

const agentSystemPrompt = `You are the obot agent. You execute processes by performing allowed actions.

ALLOWED ACTIONS (use EXACTLY these formats):
- CREATE_FILE: path
- DELETE_FILE: path
- CREATE_DIR: path
- DELETE_DIR: path
- RENAME_FILE: old_path -> new_path
- RENAME_DIR: old_path -> new_path
- MOVE_FILE: old_path -> new_path
- MOVE_DIR: old_path -> new_path
- COPY_FILE: src_path -> dst_path
- COPY_DIR: src_path -> dst_path
- RUN_COMMAND: command
- EDIT_FILE: path
  <<<
  content to write or edit
  >>>
- COMPLETE: signal process completion

YOU CANNOT:
- Select schedules
- Navigate between processes
- Terminate schedules or the prompt
- Make orchestration decisions

Signal COMPLETE when you finish the process.`
```

### 6.2 Action Executor

```go
// internal/agent/executor.go

package agent

import (
    "context"
    "fmt"
    "os"
    "os/exec"
    "path/filepath"
    "time"
)

// executeAction performs a single action
func (a *Agent) executeAction(ctx context.Context, action *Action) error {
    // Validate action type
    if !AllowedActions[action.Type] {
        return &InvalidActionError{Type: action.Type}
    }
    
    // Set metadata
    action.ID = a.nextActionID()
    action.Timestamp = time.Now()
    
    var err error
    
    switch action.Type {
    case ActionCreateFile:
        err = a.createFile(action)
    case ActionDeleteFile:
        err = a.deleteFile(action)
    case ActionCreateDir:
        err = a.createDir(action)
    case ActionDeleteDir:
        err = a.deleteDir(action)
    case ActionRenameFile:
        err = a.renameFile(action)
    case ActionRenameDir:
        err = a.renameDir(action)
    case ActionMoveFile:
        err = a.moveFile(action)
    case ActionMoveDir:
        err = a.moveDir(action)
    case ActionCopyFile:
        err = a.copyFile(action)
    case ActionCopyDir:
        err = a.copyDir(action)
    case ActionRunCommand:
        err = a.runCommand(ctx, action)
    case ActionEditFile:
        err = a.editFile(action)
    case ActionComplete:
        // Signal completion to orchestrator
        if a.onComplete != nil {
            a.onComplete(a.sessionCtx.CurrentProcess)
        }
    default:
        err = &InvalidActionError{Type: action.Type}
    }
    
    action.Duration = time.Since(action.Timestamp)
    
    // Record action
    a.mu.Lock()
    a.actions = append(a.actions, action)
    a.mu.Unlock()
    
    // Notify callback
    if a.onAction != nil {
        a.onAction(action)
    }
    
    return err
}

func (a *Agent) createFile(action *Action) error {
    dir := filepath.Dir(action.Path)
    if err := os.MkdirAll(dir, 0755); err != nil {
        return err
    }
    
    f, err := os.Create(action.Path)
    if err != nil {
        return err
    }
    return f.Close()
}

func (a *Agent) deleteFile(action *Action) error {
    return os.Remove(action.Path)
}

func (a *Agent) createDir(action *Action) error {
    return os.MkdirAll(action.Path, 0755)
}

func (a *Agent) deleteDir(action *Action) error {
    return os.RemoveAll(action.Path)
}

func (a *Agent) renameFile(action *Action) error {
    return os.Rename(action.Path, action.NewPath)
}

func (a *Agent) renameDir(action *Action) error {
    return os.Rename(action.Path, action.NewPath)
}

func (a *Agent) moveFile(action *Action) error {
    // Ensure destination directory exists
    dir := filepath.Dir(action.NewPath)
    if err := os.MkdirAll(dir, 0755); err != nil {
        return err
    }
    return os.Rename(action.Path, action.NewPath)
}

func (a *Agent) moveDir(action *Action) error {
    dir := filepath.Dir(action.NewPath)
    if err := os.MkdirAll(dir, 0755); err != nil {
        return err
    }
    return os.Rename(action.Path, action.NewPath)
}

func (a *Agent) copyFile(action *Action) error {
    src, err := os.ReadFile(action.Path)
    if err != nil {
        return err
    }
    
    dir := filepath.Dir(action.NewPath)
    if err := os.MkdirAll(dir, 0755); err != nil {
        return err
    }
    
    return os.WriteFile(action.NewPath, src, 0644)
}

func (a *Agent) copyDir(action *Action) error {
    return filepath.Walk(action.Path, func(path string, info os.FileInfo, err error) error {
        if err != nil {
            return err
        }
        
        relPath, err := filepath.Rel(action.Path, path)
        if err != nil {
            return err
        }
        
        dstPath := filepath.Join(action.NewPath, relPath)
        
        if info.IsDir() {
            return os.MkdirAll(dstPath, info.Mode())
        }
        
        data, err := os.ReadFile(path)
        if err != nil {
            return err
        }
        
        return os.WriteFile(dstPath, data, info.Mode())
    })
}

func (a *Agent) runCommand(ctx context.Context, action *Action) error {
    cmd := exec.CommandContext(ctx, "sh", "-c", action.Command)
    
    output, err := cmd.CombinedOutput()
    action.Stdout = string(output)
    
    if exitErr, ok := err.(*exec.ExitError); ok {
        action.ExitCode = exitErr.ExitCode()
    } else if err != nil {
        return err
    } else {
        action.ExitCode = 0
    }
    
    return nil
}

func (a *Agent) editFile(action *Action) error {
    // Read original file
    original, err := os.ReadFile(action.Path)
    if err != nil && !os.IsNotExist(err) {
        return err
    }
    
    // Compute diff
    action.DiffSummary = a.computeDiff(string(original), action.Content)
    action.LineRanges = a.computeLineRanges(string(original), action.Content)
    
    // Write new content
    return os.WriteFile(action.Path, []byte(action.Content), 0644)
}

func (a *Agent) nextActionID() string {
    a.mu.Lock()
    defer a.mu.Unlock()
    a.actionCounter++
    return fmt.Sprintf("A%04d", a.actionCounter)
}

// InvalidActionError indicates an invalid action type
type InvalidActionError struct {
    Type ActionType
}

func (e *InvalidActionError) Error() string {
    return fmt.Sprintf("invalid action type: %s", e.Type)
}
```

### 6.3 Diff Generation

```go
// internal/agent/diff.go

package agent

import (
    "fmt"
    "strings"
    
    "github.com/pmezard/go-difflib/difflib"
)

// computeDiff generates an obot-styled diff summary
func (a *Agent) computeDiff(original, modified string) string {
    diff := difflib.UnifiedDiff{
        A:        difflib.SplitLines(original),
        B:        difflib.SplitLines(modified),
        FromFile: "original",
        ToFile:   "modified",
        Context:  3,
    }
    
    text, err := difflib.GetUnifiedDiffString(diff)
    if err != nil {
        return ""
    }
    
    // Convert to obot style with colors
    return a.formatDiffObot(text)
}

// formatDiffObot converts standard unified diff to obot-styled output
func (a *Agent) formatDiffObot(diffText string) string {
    lines := strings.Split(diffText, "\n")
    var result strings.Builder
    
    lineNum := 0
    
    for _, line := range lines {
        if len(line) == 0 {
            continue
        }
        
        // Skip headers
        if strings.HasPrefix(line, "---") || strings.HasPrefix(line, "+++") {
            continue
        }
        
        // Parse hunk headers to get line numbers
        if strings.HasPrefix(line, "@@") {
            // Extract line number from @@ -X,Y +Z,W @@
            // For simplicity, extract the '+' line number
            parts := strings.Split(line, "+")
            if len(parts) > 1 {
                fmt.Sscanf(parts[1], "%d", &lineNum)
            }
            continue
        }
        
        switch {
        case strings.HasPrefix(line, "+"):
            // Addition (green)
            result.WriteString(fmt.Sprintf("\033[32m+ %4d │ %s\033[0m\n", lineNum, line[1:]))
            lineNum++
        case strings.HasPrefix(line, "-"):
            // Deletion (red)
            result.WriteString(fmt.Sprintf("\033[31m- %4d │ %s\033[0m\n", lineNum, line[1:]))
            // Don't increment lineNum for deletions
        default:
            // Context (default color)
            result.WriteString(fmt.Sprintf("  %4d │ %s\n", lineNum, line[1:]))
            lineNum++
        }
    }
    
    return result.String()
}

// computeLineRanges calculates merged line ranges using max overlap algorithm
func (a *Agent) computeLineRanges(original, modified string) []LineRange {
    diff := difflib.UnifiedDiff{
        A:        difflib.SplitLines(original),
        B:        difflib.SplitLines(modified),
        FromFile: "original",
        ToFile:   "modified",
        Context:  0, // No context for range computation
    }
    
    text, err := difflib.GetUnifiedDiffString(diff)
    if err != nil {
        return nil
    }
    
    // Extract line numbers from hunks
    var ranges []LineRange
    lines := strings.Split(text, "\n")
    
    for _, line := range lines {
        if strings.HasPrefix(line, "@@") {
            var start, count int
            // Parse @@ -X,Y +Z,W @@ format
            fmt.Sscanf(line, "@@ -%d,%d +%d,%d @@", &start, &count, &start, &count)
            if count == 0 {
                count = 1
            }
            ranges = append(ranges, LineRange{
                Start: start,
                End:   start + count - 1,
            })
        }
    }
    
    // Merge overlapping ranges
    return mergeRanges(ranges)
}

// mergeRanges merges overlapping or adjacent line ranges
func mergeRanges(ranges []LineRange) []LineRange {
    if len(ranges) == 0 {
        return nil
    }
    
    // Sort by start
    sort.Slice(ranges, func(i, j int) bool {
        return ranges[i].Start < ranges[j].Start
    })
    
    merged := []LineRange{ranges[0]}
    
    for i := 1; i < len(ranges); i++ {
        last := &merged[len(merged)-1]
        current := ranges[i]
        
        // Check for overlap or adjacency
        if current.Start <= last.End+1 {
            // Merge
            if current.End > last.End {
                last.End = current.End
            }
        } else {
            // No overlap, add new range
            merged = append(merged, current)
        }
    }
    
    return merged
}

// FormatLineRanges formats line ranges for display
func FormatLineRanges(ranges []LineRange) string {
    parts := make([]string, len(ranges))
    for i, r := range ranges {
        if r.Start == r.End {
            parts[i] = fmt.Sprintf("%d", r.Start)
        } else {
            parts[i] = fmt.Sprintf("%d-%d", r.Start, r.End)
        }
    }
    return strings.Join(parts, ", ")
}
```

---

## 7. Model Coordination

### 7.1 Model Coordinator

```go
// internal/model/coordinator.go

package model

import (
    "github.com/croberts/obot/internal/ollama"
    "github.com/croberts/obot/internal/orchestrate"
)

// Coordinator manages model selection and coordination
type Coordinator struct {
    clients map[orchestrate.ModelType]*ollama.Client
    config  *Config
}

// Config holds model configuration
type Config struct {
    OrchestratorModel string `yaml:"orchestrator"`
    CoderModel        string `yaml:"coder"`
    ResearcherModel   string `yaml:"researcher"`
    VisionModel       string `yaml:"vision"`
    
    OllamaURL string `yaml:"ollama_url"`
}

// NewCoordinator creates a new model coordinator
func NewCoordinator(cfg *Config) (*Coordinator, error) {
    c := &Coordinator{
        clients: make(map[orchestrate.ModelType]*ollama.Client),
        config:  cfg,
    }
    
    // Initialize orchestrator model
    c.clients[orchestrate.ModelOrchestrator] = ollama.NewClient(
        ollama.WithBaseURL(cfg.OllamaURL),
        ollama.WithModel(cfg.OrchestratorModel),
    )
    
    // Initialize coder model
    c.clients[orchestrate.ModelCoder] = ollama.NewClient(
        ollama.WithBaseURL(cfg.OllamaURL),
        ollama.WithModel(cfg.CoderModel),
    )
    
    // Initialize researcher model
    c.clients[orchestrate.ModelResearcher] = ollama.NewClient(
        ollama.WithBaseURL(cfg.OllamaURL),
        ollama.WithModel(cfg.ResearcherModel),
    )
    
    // Initialize vision model
    c.clients[orchestrate.ModelVision] = ollama.NewClient(
        ollama.WithBaseURL(cfg.OllamaURL),
        ollama.WithModel(cfg.VisionModel),
    )
    
    return c, nil
}

// Get returns the client for a model type
func (c *Coordinator) Get(modelType orchestrate.ModelType) *ollama.Client {
    return c.clients[modelType]
}

// GetModelForSchedule returns the appropriate model for a schedule
func (c *Coordinator) GetModelForSchedule(schedule orchestrate.ScheduleID) *ollama.Client {
    switch schedule {
    case orchestrate.ScheduleKnowledge:
        return c.clients[orchestrate.ModelResearcher]
    default:
        return c.clients[orchestrate.ModelCoder]
    }
}

// GetOrchestratorModel returns the orchestrator model
func (c *Coordinator) GetOrchestratorModel() *ollama.Client {
    return c.clients[orchestrate.ModelOrchestrator]
}

// ValidateModels checks that all required models are available
func (c *Coordinator) ValidateModels(ctx context.Context) error {
    for modelType, client := range c.clients {
        available, err := client.IsModelAvailable(ctx)
        if err != nil {
            return fmt.Errorf("error checking model %s: %w", modelType, err)
        }
        if !available {
            return fmt.Errorf("model %s not available", modelType)
        }
    }
    return nil
}
```

---

## 8. Display System

### 8.1 Status Display

```go
// internal/ui/display.go

package ui

import (
    "fmt"
    "io"
    "sync"
    "time"
    
    "github.com/croberts/obot/internal/orchestrate"
)

// StatusDisplay manages the 4-line status panel
type StatusDisplay struct {
    mu          sync.Mutex
    writer      io.Writer
    
    // Current values
    orchestrator string
    schedule     string
    process      string
    agent        string
    
    // Animation
    dotPhase    int
    animating   map[string]bool
    stopAnim    chan struct{}
}

// NewStatusDisplay creates a new status display
func NewStatusDisplay(w io.Writer) *StatusDisplay {
    return &StatusDisplay{
        writer:    w,
        animating: make(map[string]bool),
        stopAnim:  make(chan struct{}),
    }
}

// Start begins the display and animations
func (d *StatusDisplay) Start() {
    // Initialize with animated dots
    d.orchestrator = "..."
    d.schedule = ".."
    d.process = "."
    d.agent = "..."
    
    d.animating["orchestrator"] = true
    d.animating["schedule"] = true
    d.animating["process"] = true
    d.animating["agent"] = true
    
    // Start animation goroutine
    go d.animationLoop()
    
    // Initial render
    d.render()
}

// Stop stops the display
func (d *StatusDisplay) Stop() {
    close(d.stopAnim)
}

// SetOrchestrator updates the orchestrator state
func (d *StatusDisplay) SetOrchestrator(state orchestrate.OrchestratorState) {
    d.mu.Lock()
    defer d.mu.Unlock()
    
    d.orchestrator = string(state)
    d.animating["orchestrator"] = false
    d.render()
}

// SetSchedule updates the schedule name
func (d *StatusDisplay) SetSchedule(name string) {
    d.mu.Lock()
    defer d.mu.Unlock()
    
    d.schedule = name
    d.animating["schedule"] = false
    d.render()
}

// SetProcess updates the process name
func (d *StatusDisplay) SetProcess(name string) {
    d.mu.Lock()
    defer d.mu.Unlock()
    
    d.process = name
    d.animating["process"] = false
    d.render()
}

// SetAgent updates the agent action
func (d *StatusDisplay) SetAgent(action string) {
    d.mu.Lock()
    defer d.mu.Unlock()
    
    d.agent = action
    d.animating["agent"] = false
    d.render()
}

// render outputs the current display state
func (d *StatusDisplay) render() {
    // Move cursor up 4 lines and clear
    fmt.Fprint(d.writer, "\033[4A\033[J")
    
    // Render each line with ANSI colors
    fmt.Fprintf(d.writer, "\033[1;34mOrchestrator\033[0m \033[34m•\033[0m %s\n", d.orchestrator)
    fmt.Fprintf(d.writer, "\033[34mSchedule\033[0m \033[34m•\033[0m %s\n", d.schedule)
    fmt.Fprintf(d.writer, "\033[34mProcess\033[0m \033[34m•\033[0m %s\n", d.process)
    fmt.Fprintf(d.writer, "\033[34mAgent\033[0m \033[34m•\033[0m %s\n", d.agent)
}

// animationLoop handles dot animations
func (d *StatusDisplay) animationLoop() {
    ticker := time.NewTicker(250 * time.Millisecond)
    defer ticker.Stop()
    
    dots := []string{".", "..", "..."}
    
    for {
        select {
        case <-d.stopAnim:
            return
        case <-ticker.C:
            d.mu.Lock()
            d.dotPhase = (d.dotPhase + 1) % 3
            
            needsRender := false
            
            if d.animating["orchestrator"] {
                d.orchestrator = dots[d.dotPhase]
                needsRender = true
            }
            if d.animating["schedule"] {
                d.schedule = dots[(d.dotPhase+1)%3]
                needsRender = true
            }
            if d.animating["process"] {
                d.process = dots[(d.dotPhase+2)%3]
                needsRender = true
            }
            if d.animating["agent"] {
                d.agent = dots[d.dotPhase]
                needsRender = true
            }
            
            if needsRender {
                d.render()
            }
            
            d.mu.Unlock()
        }
    }
}
```

### 8.2 ANSI Helpers

```go
// internal/ui/ansi.go

package ui

import (
    "fmt"
    "io"
)

// ANSI color codes
const (
    ANSIReset       = "\033[0m"
    ANSIBold        = "\033[1m"
    
    ANSIBlack       = "\033[30m"
    ANSIRed         = "\033[31m"
    ANSIGreen       = "\033[32m"
    ANSIYellow      = "\033[33m"
    ANSIBlue        = "\033[34m"
    ANSIMagenta     = "\033[35m"
    ANSICyan        = "\033[36m"
    ANSIWhite       = "\033[37m"
    
    ANSIBoldRed     = "\033[1;31m"
    ANSIBoldGreen   = "\033[1;32m"
    ANSIBoldYellow  = "\033[1;33m"
    ANSIBoldBlue    = "\033[1;34m"
    ANSIBoldWhite   = "\033[1;37m"
    
    ANSIClearLine   = "\033[2K"
    ANSICursorUp    = "\033[A"
    ANSICursorDown  = "\033[B"
    ANSIClearScreen = "\033[2J"
    ANSICursorHome  = "\033[H"
)

// Color wraps text with color codes
func Color(text, color string) string {
    return color + text + ANSIReset
}

// Blue returns blue colored text (obot theme)
func Blue(text string) string {
    return Color(text, ANSIBlue)
}

// BoldBlue returns bold blue colored text
func BoldBlue(text string) string {
    return Color(text, ANSIBoldBlue)
}

// Green returns green colored text (additions)
func Green(text string) string {
    return Color(text, ANSIGreen)
}

// Red returns red colored text (deletions/errors)
func Red(text string) string {
    return Color(text, ANSIRed)
}

// Yellow returns yellow colored text (warnings)
func Yellow(text string) string {
    return Color(text, ANSIYellow)
}

// White returns white colored text
func White(text string) string {
    return Color(text, ANSIWhite)
}

// BoldWhite returns bold white colored text
func BoldWhite(text string) string {
    return Color(text, ANSIBoldWhite)
}

// ClearLine clears the current line
func ClearLine(w io.Writer) {
    fmt.Fprint(w, ANSIClearLine+"\r")
}

// MoveCursorUp moves cursor up n lines
func MoveCursorUp(w io.Writer, n int) {
    fmt.Fprintf(w, "\033[%dA", n)
}

// MoveCursorDown moves cursor down n lines
func MoveCursorDown(w io.Writer, n int) {
    fmt.Fprintf(w, "\033[%dB", n)
}

// ClearToEnd clears from cursor to end of screen
func ClearToEnd(w io.Writer) {
    fmt.Fprint(w, "\033[J")
}
```

---

## 9. Memory Visualization

### 9.1 Memory Monitor

```go
// internal/ui/memory.go

package ui

import (
    "fmt"
    "io"
    "runtime"
    "sync"
    "time"
)

// MemoryVisualization displays memory usage
type MemoryVisualization struct {
    mu       sync.Mutex
    writer   io.Writer
    
    // Current values
    current  uint64
    peak     uint64
    predict  uint64
    total    uint64
    
    // Prediction info
    predictLabel string
    predictBasis string
    
    // Historical data for prediction
    history  []memSample
    
    // Control
    stopChan chan struct{}
    running  bool
}

type memSample struct {
    time    time.Time
    bytes   uint64
    process string
}

// NewMemoryVisualization creates a new memory visualization
func NewMemoryVisualization(w io.Writer) *MemoryVisualization {
    return &MemoryVisualization{
        writer:  w,
        history: make([]memSample, 0, 1000),
    }
}

// Start begins memory monitoring
func (m *MemoryVisualization) Start() {
    m.mu.Lock()
    if m.running {
        m.mu.Unlock()
        return
    }
    m.running = true
    m.stopChan = make(chan struct{})
    m.mu.Unlock()
    
    // Get total system memory
    m.total = getTotalMemory()
    
    go m.monitorLoop()
}

// Stop stops memory monitoring
func (m *MemoryVisualization) Stop() {
    m.mu.Lock()
    if !m.running {
        m.mu.Unlock()
        return
    }
    m.running = false
    close(m.stopChan)
    m.mu.Unlock()
}

// SetPrediction updates the prediction display
func (m *MemoryVisualization) SetPrediction(bytes uint64, label, basis string) {
    m.mu.Lock()
    defer m.mu.Unlock()
    
    m.predict = bytes
    m.predictLabel = label
    m.predictBasis = basis
    m.render()
}

// monitorLoop samples memory at regular intervals
func (m *MemoryVisualization) monitorLoop() {
    ticker := time.NewTicker(100 * time.Millisecond)
    defer ticker.Stop()
    
    for {
        select {
        case <-m.stopChan:
            return
        case <-ticker.C:
            m.sample()
        }
    }
}

// sample takes a memory sample
func (m *MemoryVisualization) sample() {
    var memStats runtime.MemStats
    runtime.ReadMemStats(&memStats)
    
    m.mu.Lock()
    defer m.mu.Unlock()
    
    m.current = memStats.HeapAlloc + memStats.StackInuse
    if m.current > m.peak {
        m.peak = m.current
    }
    
    m.history = append(m.history, memSample{
        time:  time.Now(),
        bytes: m.current,
    })
    
    // Trim old history (keep last 5 minutes)
    cutoff := time.Now().Add(-5 * time.Minute)
    for len(m.history) > 0 && m.history[0].time.Before(cutoff) {
        m.history = m.history[1:]
    }
    
    m.render()
}

// render outputs the memory visualization
func (m *MemoryVisualization) render() {
    // Move up and clear
    fmt.Fprint(m.writer, "\033[4A\033[J")
    
    // Header
    fmt.Fprintf(m.writer, "%s\n", BoldBlue("Memory"))
    
    // Current
    currentBar := m.renderBar(m.current, m.total, 40)
    fmt.Fprintf(m.writer, "├─ Current: %s %s / %s\n", 
        currentBar, formatBytes(m.current), formatBytes(m.total))
    
    // Peak
    peakBar := m.renderBar(m.peak, m.total, 40)
    fmt.Fprintf(m.writer, "├─ Peak:    %s %s\n", 
        peakBar, formatBytes(m.peak))
    
    // Predict
    predictBar := m.renderBar(m.predict, m.total, 40)
    predictLabel := "--"
    if m.predictLabel != "" {
        predictLabel = fmt.Sprintf("%s (%s)", formatBytes(m.predict), m.predictLabel)
    }
    fmt.Fprintf(m.writer, "└─ Predict: %s %s\n", 
        predictBar, predictLabel)
}

// renderBar creates an ASCII progress bar
func (m *MemoryVisualization) renderBar(value, total uint64, width int) string {
    if total == 0 {
        return strings.Repeat("░", width)
    }
    
    ratio := float64(value) / float64(total)
    if ratio > 1 {
        ratio = 1
    }
    
    filled := int(ratio * float64(width))
    empty := width - filled
    
    return strings.Repeat("█", filled) + strings.Repeat("░", empty)
}

// PredictForProcess estimates memory for a process
func (m *MemoryVisualization) PredictForProcess(scheduleID, processID int) uint64 {
    m.mu.Lock()
    defer m.mu.Unlock()
    
    // Look for historical data for this process
    var samples []uint64
    for _, s := range m.history {
        // Match process (simplified - would need more context in real impl)
        samples = append(samples, s.bytes)
    }
    
    if len(samples) == 0 {
        // Default prediction based on model type
        return m.defaultPrediction(scheduleID)
    }
    
    // Calculate average
    var sum uint64
    for _, s := range samples {
        sum += s
    }
    return sum / uint64(len(samples))
}

func (m *MemoryVisualization) defaultPrediction(scheduleID int) uint64 {
    // Base predictions per schedule type
    switch scheduleID {
    case 1: // Knowledge - RAG model
        return 2 * 1024 * 1024 * 1024 // 2GB
    case 5: // Production - Coder + Vision
        return 6 * 1024 * 1024 * 1024 // 6GB
    default: // Coder model
        return 4 * 1024 * 1024 * 1024 // 4GB
    }
}

func formatBytes(b uint64) string {
    const unit = 1024
    if b < unit {
        return fmt.Sprintf("%d B", b)
    }
    div, exp := uint64(unit), 0
    for n := b / unit; n >= unit; n /= unit {
        div *= unit
        exp++
    }
    return fmt.Sprintf("%.1f %cB", float64(b)/float64(div), "KMGTPE"[exp])
}

func getTotalMemory() uint64 {
    // Platform-specific implementation would go here
    // For now, return a reasonable default
    return 8 * 1024 * 1024 * 1024 // 8GB
}
```

---

## 10. Human Consultation

### 10.1 Consultation Handler

```go
// internal/consultation/handler.go

package consultation

import (
    "context"
    "fmt"
    "io"
    "sync"
    "time"
    
    "github.com/croberts/obot/internal/ollama"
)

// Handler manages human consultation
type Handler struct {
    mu          sync.Mutex
    reader      io.Reader
    writer      io.Writer
    aiModel     *ollama.Client
    
    // Configuration
    timeout     time.Duration
    countdown   time.Duration
    allowAISub  bool
}

// Options for consultation requests
type Options struct {
    Timeout           time.Duration
    CountdownStart    time.Duration
    AllowAISubstitute bool
    Mandatory         bool
}

// Response contains the consultation response
type Response struct {
    Content     string
    Source      ResponseSource
    Timestamp   time.Time
    Duration    time.Duration
}

// ResponseSource identifies response origin
type ResponseSource string

const (
    SourceHuman       ResponseSource = "human"
    SourceAISubstitute ResponseSource = "ai_substitute"
)

// NewHandler creates a new consultation handler
func NewHandler(reader io.Reader, writer io.Writer, aiModel *ollama.Client) *Handler {
    return &Handler{
        reader:    reader,
        writer:    writer,
        aiModel:   aiModel,
        timeout:   60 * time.Second,
        countdown: 15 * time.Second,
        allowAISub: true,
    }
}

// Request initiates a human consultation
func (h *Handler) Request(ctx context.Context, question string, opts Options) (*Response, error) {
    h.mu.Lock()
    defer h.mu.Unlock()
    
    start := time.Now()
    
    // Display consultation UI
    h.displayConsultation(question, opts)
    
    // Create channels for response and timeout
    responseChan := make(chan string, 1)
    
    // Start reading input
    go h.readInput(responseChan)
    
    // Create timeout timer
    timeout := opts.Timeout
    if timeout == 0 {
        timeout = h.timeout
    }
    timer := time.NewTimer(timeout)
    defer timer.Stop()
    
    // Countdown start time
    countdownStart := timeout - opts.CountdownStart
    if opts.CountdownStart == 0 {
        countdownStart = timeout - h.countdown
    }
    countdownTimer := time.NewTimer(countdownStart)
    defer countdownTimer.Stop()
    
    countdownActive := false
    
    for {
        select {
        case <-ctx.Done():
            return nil, ctx.Err()
            
        case response := <-responseChan:
            return &Response{
                Content:   response,
                Source:    SourceHuman,
                Timestamp: time.Now(),
                Duration:  time.Since(start),
            }, nil
            
        case <-countdownTimer.C:
            countdownActive = true
            go h.displayCountdown(opts.CountdownStart)
            
        case <-timer.C:
            if opts.AllowAISubstitute || h.allowAISub {
                // Generate AI substitute response
                aiResponse, err := h.generateAISubstitute(ctx, question)
                if err != nil {
                    return nil, fmt.Errorf("AI substitute failed: %w", err)
                }
                
                return &Response{
                    Content:   aiResponse,
                    Source:    SourceAISubstitute,
                    Timestamp: time.Now(),
                    Duration:  time.Since(start),
                }, nil
            }
            
            return nil, fmt.Errorf("consultation timeout")
        }
    }
}

// displayConsultation renders the consultation UI
func (h *Handler) displayConsultation(question string, opts Options) {
    fmt.Fprintf(h.writer, "\n")
    fmt.Fprintf(h.writer, "┌─────────────────────────────────────────────────────────────────────┐\n")
    fmt.Fprintf(h.writer, "│ %s                                        │\n", BoldBlue("HUMAN CONSULTATION REQUESTED"))
    fmt.Fprintf(h.writer, "│                                                                     │\n")
    fmt.Fprintf(h.writer, "│ %s                                                            │\n", question[:min(len(question), 60)])
    if len(question) > 60 {
        // Wrap question
        for i := 60; i < len(question); i += 60 {
            end := min(i+60, len(question))
            fmt.Fprintf(h.writer, "│ %s│\n", padRight(question[i:end], 67))
        }
    }
    fmt.Fprintf(h.writer, "│                                                                     │\n")
    fmt.Fprintf(h.writer, "│ ┌─────────────────────────────────────────────────────────────────┐ │\n")
    fmt.Fprintf(h.writer, "│ │ [Your response here...]                                         │ │\n")
    fmt.Fprintf(h.writer, "│ └─────────────────────────────────────────────────────────────────┘ │\n")
    fmt.Fprintf(h.writer, "│                                                                     │\n")
    fmt.Fprintf(h.writer, "│ Time remaining: %s  [Respond]                                    │\n", formatDuration(opts.Timeout))
    fmt.Fprintf(h.writer, "│                                                                     │\n")
    fmt.Fprintf(h.writer, "│ ⚠ After timeout, an AI model will respond on your behalf           │\n")
    fmt.Fprintf(h.writer, "└─────────────────────────────────────────────────────────────────────┘\n")
}

// displayCountdown shows the countdown warning
func (h *Handler) displayCountdown(duration time.Duration) {
    remaining := int(duration.Seconds())
    
    for remaining > 0 {
        fmt.Fprintf(h.writer, "\r⚠ %s: %d... ", Yellow("AI RESPONSE IN"), remaining)
        time.Sleep(time.Second)
        remaining--
    }
    
    fmt.Fprintf(h.writer, "\r⚠ %s              \n", Yellow("GENERATING AI RESPONSE"))
}

// generateAISubstitute creates an AI response
func (h *Handler) generateAISubstitute(ctx context.Context, question string) (string, error) {
    prompt := fmt.Sprintf(`You are acting as a human-in-the-loop for an AI coding agent.
The agent asked the following question and the human did not respond in time.
Please provide a reasonable, helpful response that a human user might give.

Question: %s

Respond concisely and helpfully. If the question is about implementation preferences,
choose the most standard/common approach. If it's about approval, approve if the
proposed approach seems reasonable.`, question)

    response, _, err := h.aiModel.Chat(ctx, []ollama.Message{
        {Role: "user", Content: prompt},
    })
    
    return response, err
}

func (h *Handler) readInput(ch chan<- string) {
    // Read line from stdin
    buf := make([]byte, 4096)
    n, err := h.reader.Read(buf)
    if err != nil {
        return
    }
    ch <- string(buf[:n])
}

func formatDuration(d time.Duration) string {
    m := int(d.Minutes())
    s := int(d.Seconds()) % 60
    return fmt.Sprintf("%02d:%02d", m, s)
}

func padRight(s string, length int) string {
    if len(s) >= length {
        return s[:length]
    }
    return s + strings.Repeat(" ", length-len(s))
}
```

---

This document continues with sections 11-20 covering:
- Error Handling (Section 11)
- Session Persistence (Section 12)
- Git Integration (Section 13)
- Resource Management (Section 14)
- Terminal UI (Section 15)
- Prompt Summary (Section 16)
- LLM-as-Judge (Section 17)
- Testing Strategy (Section 18)
- Migration Path (Section 19)
- Open Implementation Questions (Section 20)

Due to length constraints, I'll continue this document in a separate file: `ORCHESTRATION_PLAN_PART2.md`
