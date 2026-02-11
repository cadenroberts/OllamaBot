# obot Orchestration Implementation Plan - Part 2

Continuation of `ORCHESTRATION_PLAN.md` covering sections 11-20.

---

## 11. Error Handling

### 11.1 Error Types

```go
// internal/error/types.go

package error

import (
    "fmt"
    "time"
    
    "github.com/croberts/obot/internal/orchestrate"
)

// ErrorCode identifies specific error types
type ErrorCode string

const (
    // Navigation errors (E001-E008)
    ErrNavigationP1ToP3     ErrorCode = "E001"
    ErrAgentTerminateSchedule ErrorCode = "E002"
    ErrAgentTerminatePrompt ErrorCode = "E003"
    ErrOrchestratorFileOp   ErrorCode = "E004"
    ErrOrchestratorGenCode  ErrorCode = "E005"
    ErrOrchestratorAsAgent  ErrorCode = "E006"
    ErrAgentAsOrchestrator  ErrorCode = "E007"
    ErrScheduleTermEarly    ErrorCode = "E008"
    ErrUndefinedAction      ErrorCode = "E009"
    
    // System errors (E010-E015)
    ErrOllamaNotRunning     ErrorCode = "E010"
    ErrModelNotAvailable    ErrorCode = "E011"
    ErrMemoryPressure       ErrorCode = "E012"
    ErrDiskExhausted        ErrorCode = "E013"
    ErrNetworkFailure       ErrorCode = "E014"
    ErrGitOperation         ErrorCode = "E015"
)

// ErrorSeverity indicates error severity
type ErrorSeverity string

const (
    SeverityCritical ErrorSeverity = "critical"
    SeveritySystem   ErrorSeverity = "system"
    SeverityWarning  ErrorSeverity = "warning"
)

// OrchestrationError represents an orchestration error
type OrchestrationError struct {
    Code        ErrorCode
    Severity    ErrorSeverity
    Component   string  // "orchestrator", "agent", "system"
    Message     string
    Rule        string  // Which rule was violated
    Timestamp   time.Time
    
    // State at error
    Schedule    orchestrate.ScheduleID
    Process     orchestrate.ProcessID
    LastAction  string
    FlowCode    string
    
    // Analysis
    Solutions   []string
    Recoverable bool
}

func (e *OrchestrationError) Error() string {
    return fmt.Sprintf("[%s] %s: %s", e.Code, e.Component, e.Message)
}

// NewNavigationError creates a navigation error
func NewNavigationError(from, to orchestrate.ProcessID, schedule orchestrate.ScheduleID) *OrchestrationError {
    return &OrchestrationError{
        Code:      ErrNavigationP1ToP3,
        Severity:  SeverityCritical,
        Component: "agent",
        Message:   fmt.Sprintf("Invalid navigation from P%d to P%d (only 1↔2↔3 allowed)", from, to),
        Rule:      "Process navigation must follow strict 1↔2↔3 adjacency",
        Timestamp: time.Now(),
        Schedule:  schedule,
        Recoverable: true,
    }
}

// NewOrchestratorViolationError creates an orchestrator violation error
func NewOrchestratorViolationError(action string) *OrchestrationError {
    return &OrchestrationError{
        Code:      ErrOrchestratorAsAgent,
        Severity:  SeverityCritical,
        Component: "orchestrator",
        Message:   fmt.Sprintf("Orchestrator attempted agent action: %s", action),
        Rule:      "Orchestrator is a TOOLER only - cannot perform agent actions",
        Timestamp: time.Now(),
        Recoverable: false,
    }
}

// NewAgentViolationError creates an agent violation error
func NewAgentViolationError(action string) *OrchestrationError {
    return &OrchestrationError{
        Code:      ErrAgentAsOrchestrator,
        Severity:  SeverityCritical,
        Component: "agent",
        Message:   fmt.Sprintf("Agent attempted orchestration: %s", action),
        Rule:      "Agent is an EXECUTOR only - cannot make orchestration decisions",
        Timestamp: time.Now(),
        Recoverable: false,
    }
}
```

### 11.2 Hardcoded Error Messages

```go
// internal/error/hardcoded.go

package error

// HardcodedMessages contains static error messages
var HardcodedMessages = map[ErrorCode]string{
    ErrOllamaNotRunning: "Ollama is not running. Start Ollama with: ollama serve",
    ErrDiskExhausted:    "Disk space exhausted. Free space required: %s",
}

// GetHardcodedMessage returns the hardcoded message for an error code
func GetHardcodedMessage(code ErrorCode, args ...interface{}) string {
    msg, ok := HardcodedMessages[code]
    if !ok {
        return ""
    }
    if len(args) > 0 {
        return fmt.Sprintf(msg, args...)
    }
    return msg
}

// IsHardcoded checks if an error has a hardcoded message
func IsHardcoded(code ErrorCode) bool {
    _, ok := HardcodedMessages[code]
    return ok
}
```

### 11.3 Suspension Handler

```go
// internal/error/suspension.go

package error

import (
    "context"
    "fmt"
    "io"
    
    "github.com/croberts/obot/internal/ollama"
    "github.com/croberts/obot/internal/session"
)

// SuspensionHandler manages error suspension
type SuspensionHandler struct {
    writer      io.Writer
    reader      io.Reader
    aiModel     *ollama.Client
    session     *session.Session
}

// SuspensionResult contains the result of suspension handling
type SuspensionResult struct {
    Action      SuspensionAction
    StateID     string
    Solutions   []string
}

// SuspensionAction is the user's chosen action
type SuspensionAction string

const (
    ActionRetry       SuspensionAction = "retry"
    ActionSkip        SuspensionAction = "skip"
    ActionAbort       SuspensionAction = "abort"
    ActionInvestigate SuspensionAction = "investigate"
)

// Handle displays suspension UI and waits for user action
func (h *SuspensionHandler) Handle(ctx context.Context, err *OrchestrationError) (*SuspensionResult, error) {
    // Freeze state
    stateID, freezeErr := h.session.FreezeState()
    if freezeErr != nil {
        // Log but continue
    }
    
    // Display suspension UI
    h.displaySuspension(err, stateID)
    
    // Perform analysis
    analysis, analysisErr := h.analyzeError(ctx, err)
    if analysisErr == nil {
        h.displayAnalysis(analysis)
    }
    
    // Display solutions
    h.displaySolutions(err.Solutions)
    
    // Wait for user action
    action, userErr := h.waitForAction()
    if userErr != nil {
        return nil, userErr
    }
    
    return &SuspensionResult{
        Action:    action,
        StateID:   stateID,
        Solutions: err.Solutions,
    }, nil
}

// displaySuspension renders the suspension UI
func (h *SuspensionHandler) displaySuspension(err *OrchestrationError, stateID string) {
    fmt.Fprintf(h.writer, "\n")
    fmt.Fprintf(h.writer, "┌─────────────────────────────────────────────────────────────────────┐\n")
    fmt.Fprintf(h.writer, "│ %s                                            │\n", BoldRed("Orchestrator • Suspended"))
    fmt.Fprintf(h.writer, "│                                                                     │\n")
    fmt.Fprintf(h.writer, "│ %s: %s - %s│\n", Red("ERROR"), err.Code, padRight(err.Message, 45))
    fmt.Fprintf(h.writer, "│                                                                     │\n")
    fmt.Fprintf(h.writer, "│ ═══════════════════════════════════════════════════════════════════ │\n")
    fmt.Fprintf(h.writer, "│ %s                                                        │\n", BoldWhite("FROZEN STATE"))
    fmt.Fprintf(h.writer, "│ ═══════════════════════════════════════════════════════════════════ │\n")
    fmt.Fprintf(h.writer, "│ Schedule: %s (S%d)│\n", 
        padRight(orchestrate.ScheduleNames[err.Schedule], 50), err.Schedule)
    fmt.Fprintf(h.writer, "│ Process: %s (P%d)│\n", 
        padRight(orchestrate.ProcessNames[err.Schedule][err.Process], 51), err.Process)
    fmt.Fprintf(h.writer, "│ Last Action: %s│\n", padRight(err.LastAction, 54))
    fmt.Fprintf(h.writer, "│ Flow Code: %s│\n", padRight(h.formatFlowCodeWithError(err.FlowCode), 56))
    fmt.Fprintf(h.writer, "│           └─────────────^ Error occurred here                       │\n")
    fmt.Fprintf(h.writer, "│                                                                     │\n")
}

// analyzeError performs LLM-as-judge analysis for non-hardcoded errors
func (h *SuspensionHandler) analyzeError(ctx context.Context, err *OrchestrationError) (*ErrorAnalysis, error) {
    if IsHardcoded(err.Code) {
        // Return pre-defined analysis for hardcoded errors
        return &ErrorAnalysis{
            Description:    GetHardcodedMessage(err.Code),
            Component:      err.Component,
            Rule:           err.Rule,
            Hardcoded:      true,
        }, nil
    }
    
    // LLM analysis for complex errors
    prompt := fmt.Sprintf(`Analyze this orchestration error:

Error Code: %s
Component: %s
Message: %s
Rule Violated: %s

Current State:
- Schedule: %s (S%d)
- Process: %s (P%d)
- Flow Code: %s

Provide:
1. What happened (specific description of the violation)
2. Root cause analysis
3. Potential contributing factors
4. 3 ranked solutions

Format your response as:
WHAT_HAPPENED: <description>
ROOT_CAUSE: <analysis>
FACTORS: <contributing factors>
SOLUTION_1: <highest priority solution>
SOLUTION_2: <second priority solution>
SOLUTION_3: <third priority solution>`,
        err.Code, err.Component, err.Message, err.Rule,
        orchestrate.ScheduleNames[err.Schedule], err.Schedule,
        orchestrate.ProcessNames[err.Schedule][err.Process], err.Process,
        err.FlowCode)
    
    response, _, analysisErr := h.aiModel.Chat(ctx, []ollama.Message{
        {Role: "system", Content: "You are an expert system analyzer. Provide factual, technical analysis only."},
        {Role: "user", Content: prompt},
    })
    if analysisErr != nil {
        return nil, analysisErr
    }
    
    return h.parseAnalysis(response), nil
}

// ErrorAnalysis contains the analysis result
type ErrorAnalysis struct {
    Description     string
    RootCause       string
    Factors         string
    Solutions       []string
    Component       string
    Rule            string
    Hardcoded       bool
}

func (h *SuspensionHandler) displayAnalysis(analysis *ErrorAnalysis) {
    fmt.Fprintf(h.writer, "│ ═══════════════════════════════════════════════════════════════════ │\n")
    fmt.Fprintf(h.writer, "│ %s                                                   │\n", BoldWhite("ERROR ANALYSIS"))
    fmt.Fprintf(h.writer, "│ ═══════════════════════════════════════════════════════════════════ │\n")
    fmt.Fprintf(h.writer, "│                                                                     │\n")
    fmt.Fprintf(h.writer, "│ What happened:                                                      │\n")
    h.wrapAndPrint(analysis.Description, 65)
    fmt.Fprintf(h.writer, "│                                                                     │\n")
    fmt.Fprintf(h.writer, "│ Which component violated:                                           │\n")
    fmt.Fprintf(h.writer, "│   %s│\n", padRight(analysis.Component, 65))
    fmt.Fprintf(h.writer, "│                                                                     │\n")
    fmt.Fprintf(h.writer, "│ Rule violated:                                                      │\n")
    h.wrapAndPrint(analysis.Rule, 65)
    fmt.Fprintf(h.writer, "│                                                                     │\n")
}

func (h *SuspensionHandler) displaySolutions(solutions []string) {
    fmt.Fprintf(h.writer, "│ ═══════════════════════════════════════════════════════════════════ │\n")
    fmt.Fprintf(h.writer, "│ %s                                                │\n", BoldWhite("PROPOSED SOLUTIONS"))
    fmt.Fprintf(h.writer, "│ ═══════════════════════════════════════════════════════════════════ │\n")
    for i, solution := range solutions {
        fmt.Fprintf(h.writer, "│ %d. %s│\n", i+1, padRight(solution, 64))
    }
    fmt.Fprintf(h.writer, "│                                                                     │\n")
    fmt.Fprintf(h.writer, "│ ═══════════════════════════════════════════════════════════════════ │\n")
    fmt.Fprintf(h.writer, "│ %s                                          │\n", BoldWhite("SAFE CONTINUATION OPTIONS"))
    fmt.Fprintf(h.writer, "│ ═══════════════════════════════════════════════════════════════════ │\n")
    fmt.Fprintf(h.writer, "│ [R] Retry last process                                              │\n")
    fmt.Fprintf(h.writer, "│ [S] Skip to next valid state                                        │\n")
    fmt.Fprintf(h.writer, "│ [A] Abort and save session                                          │\n")
    fmt.Fprintf(h.writer, "│ [I] Investigate (enter debug mode)                                  │\n")
    fmt.Fprintf(h.writer, "│                                                                     │\n")
    fmt.Fprintf(h.writer, "│ Select option: _                                                    │\n")
    fmt.Fprintf(h.writer, "└─────────────────────────────────────────────────────────────────────┘\n")
}

func (h *SuspensionHandler) waitForAction() (SuspensionAction, error) {
    buf := make([]byte, 16)
    n, err := h.reader.Read(buf)
    if err != nil {
        return "", err
    }
    
    input := strings.ToUpper(strings.TrimSpace(string(buf[:n])))
    
    switch input {
    case "R":
        return ActionRetry, nil
    case "S":
        return ActionSkip, nil
    case "A":
        return ActionAbort, nil
    case "I":
        return ActionInvestigate, nil
    default:
        return "", fmt.Errorf("invalid option: %s", input)
    }
}

func (h *SuspensionHandler) formatFlowCodeWithError(flowCode string) string {
    return flowCode + Red("X")
}

func (h *SuspensionHandler) wrapAndPrint(text string, width int) {
    words := strings.Fields(text)
    line := ""
    for _, word := range words {
        if len(line)+len(word)+1 > width {
            fmt.Fprintf(h.writer, "│   %s│\n", padRight(line, width))
            line = word
        } else {
            if line == "" {
                line = word
            } else {
                line += " " + word
            }
        }
    }
    if line != "" {
        fmt.Fprintf(h.writer, "│   %s│\n", padRight(line, width))
    }
}
```

---

## 12. Session Persistence

### 12.1 Session Manager

```go
// internal/session/manager.go

package session

import (
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"
    "time"
    
    "github.com/croberts/obot/internal/orchestrate"
)

// Manager handles session persistence
type Manager struct {
    baseDir     string
    currentID   string
    session     *Session
}

// NewManager creates a new session manager
func NewManager() (*Manager, error) {
    homeDir, err := os.UserHomeDir()
    if err != nil {
        return nil, err
    }
    
    baseDir := filepath.Join(homeDir, ".obot", "sessions")
    if err := os.MkdirAll(baseDir, 0755); err != nil {
        return nil, err
    }
    
    return &Manager{
        baseDir: baseDir,
    }, nil
}

// Create creates a new session
func (m *Manager) Create(prompt string) (*Session, error) {
    sessionID := generateSessionID()
    sessionDir := filepath.Join(m.baseDir, sessionID)
    
    // Create session directory structure
    dirs := []string{
        sessionDir,
        filepath.Join(sessionDir, "states"),
        filepath.Join(sessionDir, "checkpoints"),
        filepath.Join(sessionDir, "notes"),
        filepath.Join(sessionDir, "actions"),
        filepath.Join(sessionDir, "actions", "diffs"),
    }
    
    for _, dir := range dirs {
        if err := os.MkdirAll(dir, 0755); err != nil {
            return nil, err
        }
    }
    
    session := &Session{
        ID:            sessionID,
        CreatedAt:     time.Now(),
        UpdatedAt:     time.Now(),
        Prompt:        prompt,
        States:        make([]*State, 0),
        ScheduleRuns:  make(map[orchestrate.ScheduleID]int),
        Stats:         &SessionStats{
            SchedulingsByID:     make(map[orchestrate.ScheduleID]int),
            ProcessesBySchedule: make(map[orchestrate.ScheduleID]map[orchestrate.ProcessID]int),
            ActionsByType:       make(map[agent.ActionType]int),
            TokensBySchedule:    make(map[orchestrate.ScheduleID]int64),
            TokensByProcess:     make(map[string]int64),
        },
    }
    
    m.currentID = sessionID
    m.session = session
    
    // Save initial metadata
    if err := m.saveMetadata(); err != nil {
        return nil, err
    }
    
    return session, nil
}

// Save persists the current session state
func (m *Manager) Save() error {
    if m.session == nil {
        return fmt.Errorf("no active session")
    }
    
    m.session.UpdatedAt = time.Now()
    
    // Save metadata
    if err := m.saveMetadata(); err != nil {
        return err
    }
    
    // Save flow code
    if err := m.saveFlowCode(); err != nil {
        return err
    }
    
    // Save recurrence relations
    if err := m.saveRecurrence(); err != nil {
        return err
    }
    
    // Generate restore script
    if err := m.generateRestoreScript(); err != nil {
        return err
    }
    
    return nil
}

// saveMetadata saves session metadata
func (m *Manager) saveMetadata() error {
    metaPath := filepath.Join(m.baseDir, m.currentID, "meta.json")
    data, err := json.MarshalIndent(m.session, "", "  ")
    if err != nil {
        return err
    }
    return os.WriteFile(metaPath, data, 0644)
}

// saveFlowCode saves the flow code
func (m *Manager) saveFlowCode() error {
    flowPath := filepath.Join(m.baseDir, m.currentID, "flow.code")
    return os.WriteFile(flowPath, []byte(m.session.FlowCode), 0644)
}

// saveRecurrence saves recurrence relations
func (m *Manager) saveRecurrence() error {
    relations := &RecurrenceRelations{
        States: make([]StateRelation, len(m.session.States)),
    }
    
    for i, state := range m.session.States {
        relations.States[i] = StateRelation{
            ID:              state.ID,
            Prev:            state.PrevState,
            Next:            state.NextState,
            Schedule:        int(state.Schedule),
            Process:         int(state.Process),
            FilesHash:       state.FilesHash,
            Actions:         state.Actions,
            RestoreFromPrev: fmt.Sprintf("apply_diff %s", state.DiffFile),
            RestoreFromNext: fmt.Sprintf("reverse_diff %s", state.DiffFile),
        }
    }
    
    recurrencePath := filepath.Join(m.baseDir, m.currentID, "states", "recurrence.json")
    return relations.Save(recurrencePath)
}

// generateRestoreScript creates the bash restore script
func (m *Manager) generateRestoreScript() error {
    scriptPath := filepath.Join(m.baseDir, m.currentID, "restore.sh")
    
    script := fmt.Sprintf(`#!/bin/bash
# restore.sh - Restore obot session %s
# Generated: %s
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
        local id="${state%%.state}"
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
    find . -type f \( -name "*.go" -o -name "*.md" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" \) | \
        sort | \
        xargs cat 2>/dev/null | \
        sha256sum | \
        cut -d' ' -f1
}

apply_diffs_to_target() {
    local target="$1"
    local current_state=$(cat "$SESSION_DIR/.current_state" 2>/dev/null || echo "0000_init")
    
    # Get path from recurrence relations
    local path=$(find_path_jq "$current_state" "$target")
    
    while IFS=':' read -r direction diff_file; do
        if [ -z "$direction" ]; then
            continue
        fi
        
        echo "Applying: $direction $diff_file"
        
        if [ "$direction" = "forward" ]; then
            patch -p1 < "$SESSION_DIR/actions/diffs/$diff_file" || true
        else
            patch -R -p1 < "$SESSION_DIR/actions/diffs/$diff_file" || true
        fi
    done <<< "$path"
    
    echo "$target" > "$SESSION_DIR/.current_state"
}

find_path_jq() {
    local from="$1"
    local to="$2"
    
    # Simple BFS-like path finding using jq
    # In practice, this would be more sophisticated
    
    # For now, just apply all diffs sequentially if moving forward
    local from_seq=$(echo "$from" | sed 's/^0*//' | cut -d'_' -f1)
    local to_seq=$(echo "$to" | sed 's/^0*//' | cut -d'_' -f1)
    
    if [ -z "$from_seq" ]; then
        from_seq=0
    fi
    
    if [ "$to_seq" -gt "$from_seq" ]; then
        # Moving forward
        for ((i=from_seq+1; i<=to_seq; i++)); do
            local padded=$(printf "%%04d" $i)
            local diff_file=$(ls "$SESSION_DIR/actions/diffs/" | grep "^$padded" | head -1)
            if [ -n "$diff_file" ]; then
                echo "forward:$diff_file"
            fi
        done
    else
        # Moving backward
        for ((i=from_seq; i>to_seq; i--)); do
            local padded=$(printf "%%04d" $i)
            local diff_file=$(ls "$SESSION_DIR/actions/diffs/" | grep "^$padded" | head -1)
            if [ -n "$diff_file" ]; then
                echo "reverse:$diff_file"
            fi
        done
    fi
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
`, m.currentID, time.Now().Format(time.RFC3339))
    
    if err := os.WriteFile(scriptPath, []byte(script), 0755); err != nil {
        return err
    }
    
    return nil
}

// AddState adds a new state to the session
func (m *Manager) AddState(schedule orchestrate.ScheduleID, process orchestrate.ProcessID, actions []string, diffFile string) (*State, error) {
    seq := len(m.session.States) + 1
    stateID := fmt.Sprintf("%04d_S%dP%d", seq, schedule, process)
    
    var prevState string
    if seq > 1 {
        prevState = m.session.States[seq-2].ID
        m.session.States[seq-2].NextState = stateID
    }
    
    // Compute files hash
    filesHash, err := m.computeFilesHash()
    if err != nil {
        filesHash = "error"
    }
    
    state := &State{
        ID:        stateID,
        Sequence:  seq,
        Schedule:  schedule,
        Process:   process,
        PrevState: prevState,
        FilesHash: filesHash,
        Actions:   actions,
        DiffFile:  diffFile,
        StartTime: time.Now(),
    }
    
    m.session.States = append(m.session.States, state)
    
    // Update flow code
    if len(m.session.States) == 1 || m.session.States[len(m.session.States)-2].Schedule != schedule {
        m.session.FlowCode += fmt.Sprintf("S%d", schedule)
    }
    m.session.FlowCode += fmt.Sprintf("P%d", process)
    
    // Save state file
    statePath := filepath.Join(m.baseDir, m.currentID, "states", stateID+".state")
    stateData, _ := json.MarshalIndent(state, "", "  ")
    os.WriteFile(statePath, stateData, 0644)
    
    return state, nil
}

// FreezeState creates a checkpoint of the current state
func (m *Manager) FreezeState() (string, error) {
    if m.session == nil || len(m.session.States) == 0 {
        return "", fmt.Errorf("no states to freeze")
    }
    
    currentState := m.session.States[len(m.session.States)-1]
    
    // Mark error in flow code
    m.session.FlowCode += "X"
    
    // Save immediately
    m.Save()
    
    return currentState.ID, nil
}

func (m *Manager) computeFilesHash() (string, error) {
    // Compute SHA256 of tracked files
    // In practice, this would walk the project directory
    return fmt.Sprintf("%x", time.Now().UnixNano()), nil
}

func generateSessionID() string {
    return fmt.Sprintf("%d", time.Now().UnixNano())
}
```

### 12.2 Session Notes

```go
// internal/session/notes.go

package session

import (
    "encoding/json"
    "os"
    "path/filepath"
    "time"
)

// NoteDestination identifies where notes are stored
type NoteDestination string

const (
    DestinationOrchestrator NoteDestination = "orchestrator"
    DestinationAgent        NoteDestination = "agent"
    DestinationHuman        NoteDestination = "human"
)

// NotesManager handles session notes
type NotesManager struct {
    baseDir   string
    sessionID string
}

// NewNotesManager creates a new notes manager
func NewNotesManager(baseDir, sessionID string) *NotesManager {
    return &NotesManager{
        baseDir:   baseDir,
        sessionID: sessionID,
    }
}

// Add adds a note to the specified destination
func (n *NotesManager) Add(dest NoteDestination, content string, source NoteSource) (*Note, error) {
    note := &Note{
        ID:        generateNoteID(),
        Timestamp: time.Now(),
        Content:   content,
        Source:    source,
        Reviewed:  false,
    }
    
    // Load existing notes
    notes, err := n.Load(dest)
    if err != nil {
        notes = []Note{}
    }
    
    notes = append(notes, *note)
    
    // Save notes
    return note, n.save(dest, notes)
}

// Load loads notes from the specified destination
func (n *NotesManager) Load(dest NoteDestination) ([]Note, error) {
    notesPath := n.getNotesPath(dest)
    
    data, err := os.ReadFile(notesPath)
    if err != nil {
        if os.IsNotExist(err) {
            return []Note{}, nil
        }
        return nil, err
    }
    
    var notes []Note
    if err := json.Unmarshal(data, &notes); err != nil {
        return nil, err
    }
    
    return notes, nil
}

// GetUnreviewed returns unreviewed notes
func (n *NotesManager) GetUnreviewed(dest NoteDestination) ([]Note, error) {
    notes, err := n.Load(dest)
    if err != nil {
        return nil, err
    }
    
    unreviewed := make([]Note, 0)
    for _, note := range notes {
        if !note.Reviewed {
            unreviewed = append(unreviewed, note)
        }
    }
    
    return unreviewed, nil
}

// MarkReviewed marks notes as reviewed
func (n *NotesManager) MarkReviewed(dest NoteDestination, noteIDs []string) error {
    notes, err := n.Load(dest)
    if err != nil {
        return err
    }
    
    idSet := make(map[string]bool)
    for _, id := range noteIDs {
        idSet[id] = true
    }
    
    for i := range notes {
        if idSet[notes[i].ID] {
            notes[i].Reviewed = true
        }
    }
    
    return n.save(dest, notes)
}

func (n *NotesManager) save(dest NoteDestination, notes []Note) error {
    notesPath := n.getNotesPath(dest)
    data, err := json.MarshalIndent(notes, "", "  ")
    if err != nil {
        return err
    }
    return os.WriteFile(notesPath, data, 0644)
}

func (n *NotesManager) getNotesPath(dest NoteDestination) string {
    filename := ""
    switch dest {
    case DestinationOrchestrator:
        filename = "orchestrator.md"
    case DestinationAgent:
        filename = "agent.md"
    case DestinationHuman:
        filename = "human.md"
    }
    return filepath.Join(n.baseDir, n.sessionID, "notes", filename)
}

func generateNoteID() string {
    return fmt.Sprintf("N%d", time.Now().UnixNano())
}
```

---

## 13. Git Integration

### 13.1 Git Manager

```go
// internal/git/manager.go

package git

import (
    "context"
    "fmt"
    "os"
    "os/exec"
    "path/filepath"
    "strings"
    "time"
)

// Manager handles all git operations
type Manager struct {
    workDir      string
    github       *GitHubClient
    gitlab       *GitLabClient
    config       *Config
}

// Config holds git configuration
type Config struct {
    GitHub struct {
        Enabled   bool
        Username  string
        TokenPath string
    }
    GitLab struct {
        Enabled   bool
        Username  string
        TokenPath string
    }
    AutoPush      bool
    CommitSigning bool
}

// NewManager creates a new git manager
func NewManager(workDir string, config *Config) (*Manager, error) {
    m := &Manager{
        workDir: workDir,
        config:  config,
    }
    
    if config.GitHub.Enabled {
        github, err := NewGitHubClient(config.GitHub.TokenPath)
        if err != nil {
            return nil, fmt.Errorf("github init failed: %w", err)
        }
        m.github = github
    }
    
    if config.GitLab.Enabled {
        gitlab, err := NewGitLabClient(config.GitLab.TokenPath)
        if err != nil {
            return nil, fmt.Errorf("gitlab init failed: %w", err)
        }
        m.gitlab = gitlab
    }
    
    return m, nil
}

// Init initializes a git repository
func (m *Manager) Init(ctx context.Context) error {
    return m.run(ctx, "init")
}

// CreateRepository creates a repository on configured remotes
func (m *Manager) CreateRepository(ctx context.Context, name string, hub, lab bool) error {
    if hub && m.github != nil {
        if err := m.github.CreateRepository(ctx, name); err != nil {
            return fmt.Errorf("github create failed: %w", err)
        }
        
        // Add remote
        if err := m.run(ctx, "remote", "add", "github", 
            fmt.Sprintf("https://github.com/%s/%s.git", m.config.GitHub.Username, name)); err != nil {
            return err
        }
    }
    
    if lab && m.gitlab != nil {
        if err := m.gitlab.CreateRepository(ctx, name); err != nil {
            return fmt.Errorf("gitlab create failed: %w", err)
        }
        
        // Add remote
        if err := m.run(ctx, "remote", "add", "gitlab", 
            fmt.Sprintf("https://gitlab.com/%s/%s.git", m.config.GitLab.Username, name)); err != nil {
            return err
        }
    }
    
    return nil
}

// CommitSession creates a commit for the session
func (m *Manager) CommitSession(ctx context.Context, session *Session) error {
    // Stage all changes
    if err := m.run(ctx, "add", "."); err != nil {
        return err
    }
    
    // Build commit message
    message := m.buildCommitMessage(session)
    
    // Commit
    args := []string{"commit", "-m", message}
    if m.config.CommitSigning {
        args = append(args, "-S")
    }
    
    return m.run(ctx, args...)
}

// PushAll pushes to all configured remotes
func (m *Manager) PushAll(ctx context.Context) error {
    remotes, err := m.getRemotes(ctx)
    if err != nil {
        return err
    }
    
    for _, remote := range remotes {
        if err := m.run(ctx, "push", "-u", remote, "main"); err != nil {
            // Log but continue
            fmt.Printf("Warning: push to %s failed: %v\n", remote, err)
        }
    }
    
    return nil
}

// buildCommitMessage creates an obot-formatted commit message
func (m *Manager) buildCommitMessage(session *Session) string {
    var sb strings.Builder
    
    sb.WriteString(fmt.Sprintf("[obot] %s\n\n", m.summarizeChanges(session)))
    sb.WriteString(fmt.Sprintf("Session: %s\n", session.ID))
    sb.WriteString(fmt.Sprintf("Flow: %s\n", session.FlowCode))
    sb.WriteString(fmt.Sprintf("Schedules: %d\n", session.Stats.TotalSchedulings))
    sb.WriteString(fmt.Sprintf("Processes: %d\n", session.Stats.TotalProcesses))
    sb.WriteString("\nChanges:\n")
    
    if session.Stats.FilesCreated > 0 {
        sb.WriteString(fmt.Sprintf("  Created: %d files\n", session.Stats.FilesCreated))
    }
    if session.Stats.FilesEdited > 0 {
        sb.WriteString(fmt.Sprintf("  Edited: %d files\n", session.Stats.FilesEdited))
    }
    if session.Stats.FilesDeleted > 0 {
        sb.WriteString(fmt.Sprintf("  Deleted: %d files\n", session.Stats.FilesDeleted))
    }
    
    sb.WriteString("\nHuman Prompts:\n")
    sb.WriteString(fmt.Sprintf("  Initial: %s\n", truncate(session.Prompt, 60)))
    sb.WriteString(fmt.Sprintf("  Clarifications: %d\n", session.Stats.ClarifyCount))
    sb.WriteString(fmt.Sprintf("  Feedback: %d\n", session.Stats.FeedbackCount))
    
    sb.WriteString("\nSigned-off-by: obot <obot@local>")
    
    return sb.String()
}

func (m *Manager) summarizeChanges(session *Session) string {
    total := session.Stats.FilesCreated + session.Stats.FilesEdited + session.Stats.FilesDeleted
    if total == 0 {
        return "No file changes"
    }
    
    parts := make([]string, 0, 3)
    if session.Stats.FilesCreated > 0 {
        parts = append(parts, fmt.Sprintf("%d created", session.Stats.FilesCreated))
    }
    if session.Stats.FilesEdited > 0 {
        parts = append(parts, fmt.Sprintf("%d edited", session.Stats.FilesEdited))
    }
    if session.Stats.FilesDeleted > 0 {
        parts = append(parts, fmt.Sprintf("%d deleted", session.Stats.FilesDeleted))
    }
    
    return strings.Join(parts, ", ")
}

func (m *Manager) run(ctx context.Context, args ...string) error {
    cmd := exec.CommandContext(ctx, "git", args...)
    cmd.Dir = m.workDir
    cmd.Stdout = os.Stdout
    cmd.Stderr = os.Stderr
    return cmd.Run()
}

func (m *Manager) runOutput(ctx context.Context, args ...string) (string, error) {
    cmd := exec.CommandContext(ctx, "git", args...)
    cmd.Dir = m.workDir
    output, err := cmd.Output()
    return string(output), err
}

func (m *Manager) getRemotes(ctx context.Context) ([]string, error) {
    output, err := m.runOutput(ctx, "remote")
    if err != nil {
        return nil, err
    }
    
    lines := strings.Split(strings.TrimSpace(output), "\n")
    remotes := make([]string, 0, len(lines))
    for _, line := range lines {
        if line = strings.TrimSpace(line); line != "" {
            remotes = append(remotes, line)
        }
    }
    
    return remotes, nil
}

func truncate(s string, maxLen int) string {
    if len(s) <= maxLen {
        return s
    }
    return s[:maxLen-3] + "..."
}
```

### 13.2 GitHub Client

```go
// internal/git/github.go

package git

import (
    "bytes"
    "context"
    "encoding/json"
    "fmt"
    "io"
    "net/http"
    "os"
)

// GitHubClient handles GitHub API operations
type GitHubClient struct {
    token    string
    baseURL  string
    client   *http.Client
}

// NewGitHubClient creates a new GitHub client
func NewGitHubClient(tokenPath string) (*GitHubClient, error) {
    tokenPath = expandPath(tokenPath)
    
    token, err := os.ReadFile(tokenPath)
    if err != nil {
        return nil, fmt.Errorf("failed to read github token: %w", err)
    }
    
    return &GitHubClient{
        token:   strings.TrimSpace(string(token)),
        baseURL: "https://api.github.com",
        client:  &http.Client{},
    }, nil
}

// CreateRepository creates a new GitHub repository
func (g *GitHubClient) CreateRepository(ctx context.Context, name string) error {
    body := map[string]interface{}{
        "name":        name,
        "private":     false,
        "auto_init":   false,
        "description": "Created by obot orchestration",
    }
    
    jsonBody, err := json.Marshal(body)
    if err != nil {
        return err
    }
    
    req, err := http.NewRequestWithContext(ctx, "POST", g.baseURL+"/user/repos", bytes.NewReader(jsonBody))
    if err != nil {
        return err
    }
    
    req.Header.Set("Authorization", "token "+g.token)
    req.Header.Set("Accept", "application/vnd.github.v3+json")
    req.Header.Set("Content-Type", "application/json")
    
    resp, err := g.client.Do(req)
    if err != nil {
        return err
    }
    defer resp.Body.Close()
    
    if resp.StatusCode >= 400 {
        body, _ := io.ReadAll(resp.Body)
        return fmt.Errorf("github api error: %s - %s", resp.Status, string(body))
    }
    
    return nil
}

// All other GitHub operations would follow similar patterns:
// - CreatePullRequest
// - CreateIssue
// - ListBranches
// - CreateRelease
// - etc.

// Each method implements the full GitHub API endpoint
```

### 13.3 GitLab Client

```go
// internal/git/gitlab.go

package git

import (
    "bytes"
    "context"
    "encoding/json"
    "fmt"
    "io"
    "net/http"
    "os"
)

// GitLabClient handles GitLab API operations
type GitLabClient struct {
    token    string
    baseURL  string
    client   *http.Client
}

// NewGitLabClient creates a new GitLab client
func NewGitLabClient(tokenPath string) (*GitLabClient, error) {
    tokenPath = expandPath(tokenPath)
    
    token, err := os.ReadFile(tokenPath)
    if err != nil {
        return nil, fmt.Errorf("failed to read gitlab token: %w", err)
    }
    
    return &GitLabClient{
        token:   strings.TrimSpace(string(token)),
        baseURL: "https://gitlab.com/api/v4",
        client:  &http.Client{},
    }, nil
}

// CreateRepository creates a new GitLab project
func (g *GitLabClient) CreateRepository(ctx context.Context, name string) error {
    body := map[string]interface{}{
        "name":        name,
        "visibility":  "public",
        "description": "Created by obot orchestration",
    }
    
    jsonBody, err := json.Marshal(body)
    if err != nil {
        return err
    }
    
    req, err := http.NewRequestWithContext(ctx, "POST", g.baseURL+"/projects", bytes.NewReader(jsonBody))
    if err != nil {
        return err
    }
    
    req.Header.Set("PRIVATE-TOKEN", g.token)
    req.Header.Set("Content-Type", "application/json")
    
    resp, err := g.client.Do(req)
    if err != nil {
        return err
    }
    defer resp.Body.Close()
    
    if resp.StatusCode >= 400 {
        body, _ := io.ReadAll(resp.Body)
        return fmt.Errorf("gitlab api error: %s - %s", resp.Status, string(body))
    }
    
    return nil
}

// All other GitLab operations would follow similar patterns:
// - CreateMergeRequest
// - CreateIssue
// - ListBranches
// - CreateRelease
// - etc.
```

---

## 14. Resource Management

### 14.1 Resource Monitor

```go
// internal/resource/monitor.go

package resource

import (
    "context"
    "runtime"
    "sync"
    "time"
)

// Monitor tracks resource usage
type Monitor struct {
    mu          sync.RWMutex
    
    // Memory
    memCurrent  uint64
    memPeak     uint64
    memTotal    uint64
    
    // Disk
    diskWritten int64
    diskDeleted int64
    
    // Tokens
    tokensUsed  int64
    
    // Time
    startTime   time.Time
    
    // Limits (nil = unlimited)
    memLimit    *uint64
    diskLimit   *int64
    tokenLimit  *int64
    timeout     *time.Duration
    
    // Warnings
    warnings    []ResourceWarning
}

// ResourceWarning represents a resource warning
type ResourceWarning struct {
    Type      string
    Threshold float64
    Current   float64
    Timestamp time.Time
}

// NewMonitor creates a new resource monitor
func NewMonitor(config *Config) *Monitor {
    m := &Monitor{
        startTime: time.Now(),
        memTotal:  getSystemMemory(),
        warnings:  make([]ResourceWarning, 0),
    }
    
    if config != nil {
        if config.MemoryLimit > 0 {
            m.memLimit = &config.MemoryLimit
        }
        if config.DiskLimit > 0 {
            m.diskLimit = &config.DiskLimit
        }
        if config.TokenLimit > 0 {
            m.tokenLimit = &config.TokenLimit
        }
        if config.Timeout > 0 {
            m.timeout = &config.Timeout
        }
    }
    
    return m
}

// Config holds resource limits
type Config struct {
    MemoryLimit uint64        // 0 = unlimited
    DiskLimit   int64         // 0 = unlimited
    TokenLimit  int64         // 0 = unlimited
    Timeout     time.Duration // 0 = unlimited
    
    WarningThresholds struct {
        Memory float64 // e.g., 0.8 = 80%
        Disk   float64
    }
}

// Start begins resource monitoring
func (m *Monitor) Start(ctx context.Context) {
    go m.monitorLoop(ctx)
}

// monitorLoop samples resources periodically
func (m *Monitor) monitorLoop(ctx context.Context) {
    ticker := time.NewTicker(500 * time.Millisecond)
    defer ticker.Stop()
    
    for {
        select {
        case <-ctx.Done():
            return
        case <-ticker.C:
            m.sample()
        }
    }
}

// sample takes a resource sample
func (m *Monitor) sample() {
    var memStats runtime.MemStats
    runtime.ReadMemStats(&memStats)
    
    m.mu.Lock()
    defer m.mu.Unlock()
    
    m.memCurrent = memStats.HeapAlloc + memStats.StackInuse
    if m.memCurrent > m.memPeak {
        m.memPeak = m.memCurrent
    }
    
    // Check limits
    m.checkLimits()
}

// checkLimits checks if any limits are exceeded
func (m *Monitor) checkLimits() {
    // Memory warning
    if m.memTotal > 0 {
        ratio := float64(m.memCurrent) / float64(m.memTotal)
        if ratio > 0.8 {
            m.warnings = append(m.warnings, ResourceWarning{
                Type:      "memory",
                Threshold: 0.8,
                Current:   ratio,
                Timestamp: time.Now(),
            })
        }
    }
}

// RecordDiskWrite records bytes written
func (m *Monitor) RecordDiskWrite(bytes int64) {
    m.mu.Lock()
    m.diskWritten += bytes
    m.mu.Unlock()
}

// RecordDiskDelete records bytes deleted
func (m *Monitor) RecordDiskDelete(bytes int64) {
    m.mu.Lock()
    m.diskDeleted += bytes
    m.mu.Unlock()
}

// RecordTokens records tokens used
func (m *Monitor) RecordTokens(tokens int64) {
    m.mu.Lock()
    m.tokensUsed += tokens
    m.mu.Unlock()
}

// CheckMemoryLimit checks if memory limit is exceeded
func (m *Monitor) CheckMemoryLimit() error {
    m.mu.RLock()
    defer m.mu.RUnlock()
    
    if m.memLimit != nil && m.memCurrent > *m.memLimit {
        return &LimitExceededError{
            Resource: "memory",
            Limit:    *m.memLimit,
            Current:  m.memCurrent,
        }
    }
    return nil
}

// CheckTokenLimit checks if token limit is exceeded
func (m *Monitor) CheckTokenLimit() error {
    m.mu.RLock()
    defer m.mu.RUnlock()
    
    if m.tokenLimit != nil && m.tokensUsed > *m.tokenLimit {
        return &LimitExceededError{
            Resource: "tokens",
            Limit:    uint64(*m.tokenLimit),
            Current:  uint64(m.tokensUsed),
        }
    }
    return nil
}

// GetSummary returns a resource summary
func (m *Monitor) GetSummary() *ResourceSummary {
    m.mu.RLock()
    defer m.mu.RUnlock()
    
    return &ResourceSummary{
        Memory: MemorySummary{
            Peak:     m.memPeak,
            Current:  m.memCurrent,
            Total:    m.memTotal,
            Limit:    m.memLimit,
            Warnings: m.countWarnings("memory"),
        },
        Disk: DiskSummary{
            Written: m.diskWritten,
            Deleted: m.diskDeleted,
            Net:     m.diskWritten - m.diskDeleted,
            Limit:   m.diskLimit,
        },
        Tokens: TokenSummary{
            Used:  m.tokensUsed,
            Limit: m.tokenLimit,
        },
        Time: TimeSummary{
            Elapsed: time.Since(m.startTime),
            Timeout: m.timeout,
        },
    }
}

func (m *Monitor) countWarnings(resType string) int {
    count := 0
    for _, w := range m.warnings {
        if w.Type == resType {
            count++
        }
    }
    return count
}

// LimitExceededError indicates a resource limit was exceeded
type LimitExceededError struct {
    Resource string
    Limit    uint64
    Current  uint64
}

func (e *LimitExceededError) Error() string {
    return fmt.Sprintf("%s limit exceeded: %d > %d", e.Resource, e.Current, e.Limit)
}

// ResourceSummary contains a complete resource summary
type ResourceSummary struct {
    Memory MemorySummary
    Disk   DiskSummary
    Tokens TokenSummary
    Time   TimeSummary
}

type MemorySummary struct {
    Peak     uint64
    Current  uint64
    Total    uint64
    Limit    *uint64
    Warnings int
}

type DiskSummary struct {
    Written int64
    Deleted int64
    Net     int64
    Limit   *int64
}

type TokenSummary struct {
    Used  int64
    Limit *int64
}

type TimeSummary struct {
    Elapsed time.Duration
    Timeout *time.Duration
}

func getSystemMemory() uint64 {
    // Platform-specific implementation
    return 8 * 1024 * 1024 * 1024 // Default 8GB
}
```

---

## 15. Terminal UI

### 15.1 Application

```go
// internal/ui/app.go

package ui

import (
    "context"
    "fmt"
    "io"
    "os"
    "sync"
    
    "github.com/croberts/obot/internal/orchestrate"
    "github.com/croberts/obot/internal/session"
)

// App is the main terminal application
type App struct {
    mu           sync.Mutex
    stdin        io.Reader
    stdout       io.Writer
    stderr       io.Writer
    
    // Components
    display      *StatusDisplay
    memoryViz    *MemoryVisualization
    inputHandler *InputHandler
    
    // State
    running      bool
    hasPrompt    bool
    generating   bool
    
    // Note destination toggle
    noteDestination session.NoteDestination
    
    // Callbacks
    onPrompt     func(string)
    onNote       func(session.NoteDestination, string)
    onStop       func()
}

// NewApp creates a new terminal application
func NewApp() *App {
    return &App{
        stdin:           os.Stdin,
        stdout:          os.Stdout,
        stderr:          os.Stderr,
        noteDestination: session.DestinationOrchestrator,
    }
}

// Run starts the application
func (a *App) Run(ctx context.Context) error {
    a.mu.Lock()
    a.running = true
    a.mu.Unlock()
    
    // Initialize components
    a.display = NewStatusDisplay(a.stdout)
    a.memoryViz = NewMemoryVisualization(a.stdout)
    a.inputHandler = NewInputHandler(a.stdin)
    
    // Render initial UI
    a.renderUI()
    
    // Start components
    a.display.Start()
    a.memoryViz.Start()
    
    // Start input loop
    go a.inputLoop(ctx)
    
    // Wait for context cancellation
    <-ctx.Done()
    
    // Cleanup
    a.display.Stop()
    a.memoryViz.Stop()
    
    return nil
}

// renderUI renders the complete UI
func (a *App) renderUI() {
    // Clear screen
    fmt.Fprint(a.stdout, ANSIClearScreen+ANSICursorHome)
    
    // Header
    a.renderHeader()
    
    // Separator
    fmt.Fprintln(a.stdout, "├─────────────────────────────────────────────────────────────────────────────┤")
    
    // Status panel placeholder (4 lines)
    fmt.Fprintln(a.stdout, "│ Orchestrator • ...                                                          │")
    fmt.Fprintln(a.stdout, "│ Schedule • ..                                                               │")
    fmt.Fprintln(a.stdout, "│ Process • .                                                                 │")
    fmt.Fprintln(a.stdout, "│ Agent • ...                                                                 │")
    
    // Memory panel placeholder (4 lines)
    fmt.Fprintln(a.stdout, "├─────────────────────────────────────────────────────────────────────────────┤")
    fmt.Fprintln(a.stdout, "│ Memory                                                                      │")
    fmt.Fprintln(a.stdout, "│ ├─ Current: ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  0.0 GB / 8 GB          │")
    fmt.Fprintln(a.stdout, "│ ├─ Peak:    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  0.0 GB                  │")
    fmt.Fprintln(a.stdout, "│ └─ Predict: ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  -- GB                   │")
    
    // Output area placeholder
    fmt.Fprintln(a.stdout, "├─────────────────────────────────────────────────────────────────────────────┤")
    fmt.Fprintln(a.stdout, "│                                                                             │")
    fmt.Fprintln(a.stdout, "│  Output Area (scrollable)                                                   │")
    fmt.Fprintln(a.stdout, "│                                                                             │")
    
    // Input area
    fmt.Fprintln(a.stdout, "├─────────────────────────────────────────────────────────────────────────────┤")
    a.renderInputArea()
    
    fmt.Fprintln(a.stdout, "└─────────────────────────────────────────────────────────────────────────────┘")
}

// renderHeader renders the application header
func (a *App) renderHeader() {
    fmt.Fprintln(a.stdout, "┌─────────────────────────────────────────────────────────────────────────────┐")
    fmt.Fprintln(a.stdout, "│                                                                             │")
    
    // Logo area
    if !a.hasPrompt {
        // OllamaBot logo (no prompt yet)
        fmt.Fprintln(a.stdout, "│  ┌─────────┐                                                                │")
        fmt.Fprintf(a.stdout, "│  │ %s      │  %s                                   │\n", Blue("🦙"), BoldBlue("obot orchestrate"))
        fmt.Fprintln(a.stdout, "│  └─────────┘                                                                │")
    } else {
        // Toggle between orchestrator and coder
        icon := "🧠" // Brain for orchestrator
        if a.noteDestination == session.DestinationAgent {
            icon = "</>" // Coder
        }
        fmt.Fprintln(a.stdout, "│  ┌─────────┐                                                                │")
        fmt.Fprintf(a.stdout, "│  │ %s      │  %s                                   │\n", Blue(icon), BoldBlue("obot orchestrate"))
        fmt.Fprintln(a.stdout, "│  └─────────┘                                                                │")
    }
    
    fmt.Fprintln(a.stdout, "│                                                                             │")
}

// renderInputArea renders the input area
func (a *App) renderInputArea() {
    fmt.Fprintln(a.stdout, "│ ┌─────────────────────────────────────────────────────────────────────────┐ │")
    fmt.Fprintln(a.stdout, "│ │ Type your prompt here...                                                │ │")
    fmt.Fprintln(a.stdout, "│ └─────────────────────────────────────────────────────────────────────────┘ │")
    
    // Buttons
    if a.generating {
        fmt.Fprintln(a.stdout, "│                                                          [Send] "+Red("[Stop]")+"      │")
    } else {
        fmt.Fprintln(a.stdout, "│                                                          "+Green("[Send]")+" [Stop]      │")
    }
    
    // Note destination toggle
    fmt.Fprintln(a.stdout, "│                                                                             │")
    if a.noteDestination == session.DestinationOrchestrator {
        fmt.Fprintf(a.stdout, "│ [%s Orchestrator] [</> Coder]  ← Toggle for note destination               │\n", BoldBlue("🧠"))
    } else {
        fmt.Fprintf(a.stdout, "│ [🧠 Orchestrator] [%s Coder]  ← Toggle for note destination               │\n", BoldBlue("</>"))
    }
    fmt.Fprintln(a.stdout, "│                                                                             │")
}

// inputLoop handles user input
func (a *App) inputLoop(ctx context.Context) {
    for {
        select {
        case <-ctx.Done():
            return
        default:
        }
        
        input, err := a.inputHandler.ReadLine()
        if err != nil {
            continue
        }
        
        a.handleInput(input)
    }
}

// handleInput processes user input
func (a *App) handleInput(input string) {
    a.mu.Lock()
    defer a.mu.Unlock()
    
    // Check for special commands
    switch input {
    case "/toggle":
        a.toggleNoteDestination()
        return
    case "/stop":
        if a.generating && a.onStop != nil {
            a.onStop()
        }
        return
    }
    
    if !a.hasPrompt {
        // Initial prompt
        a.hasPrompt = true
        a.generating = true
        if a.onPrompt != nil {
            a.onPrompt(input)
        }
    } else {
        // Add as note
        if a.onNote != nil {
            a.onNote(a.noteDestination, input)
        }
    }
    
    // Re-render
    a.renderUI()
}

// toggleNoteDestination toggles between orchestrator and agent
func (a *App) toggleNoteDestination() {
    if a.noteDestination == session.DestinationOrchestrator {
        a.noteDestination = session.DestinationAgent
    } else {
        a.noteDestination = session.DestinationOrchestrator
    }
    a.renderUI()
}

// SetGenerating updates the generating state
func (a *App) SetGenerating(generating bool) {
    a.mu.Lock()
    a.generating = generating
    a.mu.Unlock()
    a.renderUI()
}

// UpdateDisplay updates the status display
func (a *App) UpdateDisplay(state orchestrate.OrchestratorState, schedule, process, agent string) {
    a.display.SetOrchestrator(state)
    a.display.SetSchedule(schedule)
    a.display.SetProcess(process)
    a.display.SetAgent(agent)
}

// UpdateMemory updates the memory visualization
func (a *App) UpdateMemory(current, peak, predict uint64, predictLabel string) {
    // Implementation updates memory bars
}

// WriteOutput writes to the output area
func (a *App) WriteOutput(text string) {
    // Implementation appends to scrollable output
    fmt.Fprintln(a.stdout, text)
}
```

---

## 16. Prompt Summary

### 16.1 Summary Generator

```go
// internal/summary/generator.go

package summary

import (
    "fmt"
    "strings"
    
    "github.com/croberts/obot/internal/orchestrate"
    "github.com/croberts/obot/internal/session"
    "github.com/croberts/obot/internal/ui"
)

// Generator creates prompt summaries
type Generator struct {
    session *session.Session
}

// NewGenerator creates a new summary generator
func NewGenerator(sess *session.Session) *Generator {
    return &Generator{session: sess}
}

// Generate creates the complete prompt summary
func (g *Generator) Generate() string {
    var sb strings.Builder
    
    // Header
    sb.WriteString("┌─────────────────────────────────────────────────────────────────────┐\n")
    sb.WriteString(fmt.Sprintf("│ %s                                       │\n", ui.BoldBlue("Orchestrator • Prompt Summary")))
    sb.WriteString("├─────────────────────────────────────────────────────────────────────┤\n")
    
    // Flow code
    sb.WriteString("│                                                                     │\n")
    sb.WriteString(fmt.Sprintf("│ %s                                  │\n", g.formatFlowCode()))
    sb.WriteString("│                                                                     │\n")
    
    // Schedule summary
    sb.WriteString("├─────────────────────────────────────────────────────────────────────┤\n")
    sb.WriteString(g.generateScheduleSummary())
    
    // Process summary
    sb.WriteString("├─────────────────────────────────────────────────────────────────────┤\n")
    sb.WriteString(g.generateProcessSummary())
    
    // Agent actions
    sb.WriteString("├─────────────────────────────────────────────────────────────────────┤\n")
    sb.WriteString(g.generateActionSummary())
    
    // Resources
    sb.WriteString("├─────────────────────────────────────────────────────────────────────┤\n")
    sb.WriteString(g.generateResourceSummary())
    
    // Tokens
    sb.WriteString("├─────────────────────────────────────────────────────────────────────┤\n")
    sb.WriteString(g.generateTokenSummary())
    
    // Generation flow
    sb.WriteString("├─────────────────────────────────────────────────────────────────────┤\n")
    sb.WriteString(g.generateGenerationFlow())
    
    // TLDR (placeholder for LLM-as-judge)
    sb.WriteString("├─────────────────────────────────────────────────────────────────────┤\n")
    sb.WriteString(fmt.Sprintf("│ %s                                                    │\n", ui.BoldBlue("OllamaBot • TLDR")))
    sb.WriteString("│                                                                     │\n")
    sb.WriteString("│ {LLM-as-Judge comprehensive analysis}                               │\n")
    sb.WriteString("│                                                                     │\n")
    
    sb.WriteString("└─────────────────────────────────────────────────────────────────────┘\n")
    
    return sb.String()
}

// formatFlowCode formats the flow code with colors
func (g *Generator) formatFlowCode() string {
    code := g.session.FlowCode
    var result strings.Builder
    
    for i := 0; i < len(code); i++ {
        c := code[i]
        switch c {
        case 'S':
            // Schedule code in white
            i++
            if i < len(code) {
                result.WriteString(ui.White(fmt.Sprintf("S%c", code[i])))
            }
        case 'P':
            // Process codes in blue
            for i+1 < len(code) && code[i+1] >= '0' && code[i+1] <= '9' {
                i++
                result.WriteString(ui.Blue(fmt.Sprintf("P%c", code[i])))
            }
        case 'X':
            // Error in red
            result.WriteString(ui.Red("X"))
        }
    }
    
    return result.String()
}

func (g *Generator) generateScheduleSummary() string {
    stats := g.session.Stats
    var sb strings.Builder
    
    sb.WriteString(fmt.Sprintf("│ Schedule • %d Total Schedulings                                      │\n", stats.TotalSchedulings))
    
    for id := orchestrate.ScheduleKnowledge; id <= orchestrate.ScheduleProduction; id++ {
        count := stats.SchedulingsByID[id]
        name := orchestrate.ScheduleNames[id]
        sb.WriteString(fmt.Sprintf("│   %s: %d scheduling(s)│\n", padRight(name, 12), count))
    }
    
    sb.WriteString("│                                                                     │\n")
    
    return sb.String()
}

func (g *Generator) generateProcessSummary() string {
    stats := g.session.Stats
    var sb strings.Builder
    
    sb.WriteString(fmt.Sprintf("│ Process • %d Total Processes                                        │\n", stats.TotalProcesses))
    sb.WriteString("│                                                                     │\n")
    
    for schedID := orchestrate.ScheduleKnowledge; schedID <= orchestrate.ScheduleProduction; schedID++ {
        schedName := orchestrate.ScheduleNames[schedID]
        schedProcesses := stats.ProcessesBySchedule[schedID]
        
        var total int
        for _, count := range schedProcesses {
            total += count
        }
        
        if total == 0 {
            continue
        }
        
        pct := float64(total) / float64(stats.TotalProcesses) * 100
        avg := float64(total) / float64(max(stats.SchedulingsByID[schedID], 1))
        
        sb.WriteString(fmt.Sprintf("│ %s • %d total (%.1f%% of all)│\n", schedName, total, pct))
        sb.WriteString(fmt.Sprintf("│   Averaging %.1f processes per scheduling│\n", avg))
        
        for procID := orchestrate.Process1; procID <= orchestrate.Process3; procID++ {
            procName := orchestrate.ProcessNames[schedID][procID]
            count := schedProcesses[procID]
            procPct := float64(count) / float64(total) * 100
            sb.WriteString(fmt.Sprintf("│   %s: %d (%.1f%% of %s)│\n", procName, count, procPct, schedName))
        }
        
        sb.WriteString("│                                                                     │\n")
    }
    
    return sb.String()
}

func (g *Generator) generateActionSummary() string {
    stats := g.session.Stats
    var sb strings.Builder
    
    sb.WriteString(fmt.Sprintf("│ Agent • Action Breakdown                                            │\n"))
    sb.WriteString("│                                                                     │\n")
    sb.WriteString(fmt.Sprintf("│ Created • %d files, %d directories                                   │\n", stats.FilesCreated, stats.DirsCreated))
    sb.WriteString(fmt.Sprintf("│ Deleted • %d files, %d directories                                   │\n", stats.FilesDeleted, stats.DirsDeleted))
    sb.WriteString(fmt.Sprintf("│ Ran • %d commands                                                    │\n", stats.CommandsRan))
    sb.WriteString(fmt.Sprintf("│ Edited • %d files                                                    │\n", stats.FilesEdited))
    sb.WriteString("│                                                                     │\n")
    
    return sb.String()
}

func (g *Generator) generateResourceSummary() string {
    // Implementation returns resource summary
    return "│ Resources • Summary                                                 │\n│ ...                                                                 │\n"
}

func (g *Generator) generateTokenSummary() string {
    stats := g.session.Stats
    var sb strings.Builder
    
    sb.WriteString(fmt.Sprintf("│ Tokens • %d total                                              │\n", stats.TotalTokens))
    sb.WriteString("│                                                                     │\n")
    sb.WriteString(fmt.Sprintf("│   Total Tokens: %d                                             │\n", stats.TotalTokens))
    sb.WriteString(fmt.Sprintf("│   Inference Tokens: %d (%.1f%%)                                 │\n", stats.InferenceTokens, pct(stats.InferenceTokens, stats.TotalTokens)))
    sb.WriteString(fmt.Sprintf("│   Input Tokens: %d (%.1f%%)                                     │\n", stats.InputTokens, pct(stats.InputTokens, stats.TotalTokens)))
    sb.WriteString(fmt.Sprintf("│   Output Tokens: %d (%.1f%%)                                    │\n", stats.OutputTokens, pct(stats.OutputTokens, stats.TotalTokens)))
    sb.WriteString(fmt.Sprintf("│   Context Retrieval: %d (%.1f%%)                                │\n", stats.ContextTokens, pct(stats.ContextTokens, stats.TotalTokens)))
    sb.WriteString("│                                                                     │\n")
    
    return sb.String()
}

func (g *Generator) generateGenerationFlow() string {
    var sb strings.Builder
    
    sb.WriteString("│ Generation Flow • Process-by-Process Token Recount                  │\n")
    sb.WriteString("│                                                                     │\n")
    sb.WriteString(fmt.Sprintf("│ %s                                  │\n", g.formatFlowCode()))
    sb.WriteString("│                                                                     │\n")
    
    // Detailed flow would go here
    
    return sb.String()
}

func pct(part, total int64) float64 {
    if total == 0 {
        return 0
    }
    return float64(part) / float64(total) * 100
}

func padRight(s string, n int) string {
    if len(s) >= n {
        return s[:n]
    }
    return s + strings.Repeat(" ", n-len(s))
}
```

---

## 17. LLM-as-Judge

### 17.1 Judge Coordinator

```go
// internal/judge/coordinator.go

package judge

import (
    "context"
    "fmt"
    "strings"
    
    "github.com/croberts/obot/internal/ollama"
    "github.com/croberts/obot/internal/session"
)

// Coordinator manages LLM-as-judge analysis
type Coordinator struct {
    orchestratorModel *ollama.Client
    coderModel        *ollama.Client
    researcherModel   *ollama.Client
    visionModel       *ollama.Client
}

// Analysis contains the complete judge analysis
type Analysis struct {
    Experts      map[string]*ExpertAnalysis
    Synthesis    *SynthesisAnalysis
    Failures     []string
}

// ExpertAnalysis contains one expert's analysis
type ExpertAnalysis struct {
    Expert           string
    PromptAdherence  int  // 0-100
    ProjectQuality   int  // 0-100
    ActionsCount     int
    ErrorsCount      int
    Observations     []string
    Recommendations  []string
}

// SynthesisAnalysis contains the orchestrator's synthesis
type SynthesisAnalysis struct {
    PromptGoal        string
    Implementation    string
    ExpertConsensus   map[string]int
    Discoveries       []string
    Issues            []IssueResolution
    QualityAssessment string  // "ACCEPTABLE", "NEEDS_IMPROVEMENT", "EXCEPTIONAL"
    Justification     string
    Recommendations   []string
}

type IssueResolution struct {
    Issue      string
    Resolution string
}

// NewCoordinator creates a new judge coordinator
func NewCoordinator(orchestrator, coder, researcher, vision *ollama.Client) *Coordinator {
    return &Coordinator{
        orchestratorModel: orchestrator,
        coderModel:        coder,
        researcherModel:   researcher,
        visionModel:       vision,
    }
}

// Analyze performs the complete LLM-as-judge analysis
func (c *Coordinator) Analyze(ctx context.Context, sess *session.Session) (*Analysis, error) {
    analysis := &Analysis{
        Experts:  make(map[string]*ExpertAnalysis),
        Failures: make([]string, 0),
    }
    
    // Get expert analyses
    experts := []struct {
        name  string
        model *ollama.Client
    }{
        {"Coder", c.coderModel},
        {"Researcher", c.researcherModel},
        {"Vision", c.visionModel},
    }
    
    for _, expert := range experts {
        expertAnalysis, err := c.getExpertAnalysis(ctx, expert.model, expert.name, sess)
        if err != nil {
            // Retry once
            expertAnalysis, err = c.getExpertAnalysis(ctx, expert.model, expert.name, sess)
            if err != nil {
                // Record failure, orchestrator will substitute
                analysis.Failures = append(analysis.Failures, expert.name)
                continue
            }
        }
        analysis.Experts[expert.name] = expertAnalysis
    }
    
    // Orchestrator synthesis
    synthesis, err := c.synthesize(ctx, analysis, sess)
    if err != nil {
        return nil, fmt.Errorf("synthesis failed: %w", err)
    }
    analysis.Synthesis = synthesis
    
    return analysis, nil
}

// getExpertAnalysis gets analysis from one expert
func (c *Coordinator) getExpertAnalysis(ctx context.Context, model *ollama.Client, expert string, sess *session.Session) (*ExpertAnalysis, error) {
    prompt := fmt.Sprintf(`You are the %s expert analyzing an obot orchestration session.

Session Summary:
- Prompt: %s
- Flow Code: %s
- Total Processes: %d
- Files Changed: %d

Analyze and provide:
1. PROMPT_ADHERENCE: Score 0-100 for how well the prompt was followed
2. PROJECT_QUALITY: Score 0-100 for deliverable quality in your domain
3. ACTIONS: Count of actions you performed
4. ERRORS: Count of errors you made
5. OBSERVATIONS: 3 key observations (one per line)
6. RECOMMENDATIONS: 2 recommendations (one per line)

Format:
PROMPT_ADHERENCE: <score>
PROJECT_QUALITY: <score>
ACTIONS: <count>
ERRORS: <count>
OBSERVATIONS:
- <observation 1>
- <observation 2>
- <observation 3>
RECOMMENDATIONS:
- <recommendation 1>
- <recommendation 2>`,
        expert, sess.Prompt, sess.FlowCode, sess.Stats.TotalProcesses,
        sess.Stats.FilesCreated+sess.Stats.FilesEdited+sess.Stats.FilesDeleted)
    
    response, _, err := model.Chat(ctx, []ollama.Message{
        {Role: "system", Content: "You are an expert system analyzer. Provide factual, metrics-based analysis only. No opinions or feelings."},
        {Role: "user", Content: prompt},
    })
    if err != nil {
        return nil, err
    }
    
    return c.parseExpertAnalysis(response, expert)
}

// synthesize creates the final orchestrator synthesis
func (c *Coordinator) synthesize(ctx context.Context, analysis *Analysis, sess *session.Session) (*SynthesisAnalysis, error) {
    // Build expert summaries
    var expertSummaries strings.Builder
    for name, expert := range analysis.Experts {
        expertSummaries.WriteString(fmt.Sprintf("\n%s Expert:\n", name))
        expertSummaries.WriteString(fmt.Sprintf("  Prompt Adherence: %d%%\n", expert.PromptAdherence))
        expertSummaries.WriteString(fmt.Sprintf("  Project Quality: %d%%\n", expert.ProjectQuality))
        expertSummaries.WriteString(fmt.Sprintf("  Observations: %s\n", strings.Join(expert.Observations, "; ")))
    }
    
    // Note failures
    for _, failure := range analysis.Failures {
        expertSummaries.WriteString(fmt.Sprintf("\n%s Expert: UNRESPONSIVE - substituting analysis\n", failure))
    }
    
    prompt := fmt.Sprintf(`You are the obot orchestrator creating the final TLDR synthesis.

Original Prompt: %s

Expert Analyses:
%s

Session Statistics:
- Flow Code: %s
- Total Processes: %d
- Files Created: %d
- Files Edited: %d
- Files Deleted: %d
- Tokens Used: %d

Create a synthesis with:
1. PROMPT_GOAL: Quote the original prompt
2. IMPLEMENTATION: Factual description of what was built/changed
3. EXPERT_CONSENSUS: Average scores
4. DISCOVERIES: 2-3 key discoveries/learnings
5. ISSUES: Any issues and their resolutions
6. QUALITY_ASSESSMENT: ACCEPTABLE, NEEDS_IMPROVEMENT, or EXCEPTIONAL
7. JUSTIFICATION: Concrete, metrics-based justification
8. RECOMMENDATIONS: 3 actionable recommendations

CRITICAL: Be factual and reproducible. No opinions, feelings, or vague statements.
Use phrases like "Based on X metric" and "The data shows" not "I think" or "It seems".`,
        sess.Prompt, expertSummaries.String(), sess.FlowCode,
        sess.Stats.TotalProcesses, sess.Stats.FilesCreated,
        sess.Stats.FilesEdited, sess.Stats.FilesDeleted, sess.Stats.TotalTokens)
    
    response, _, err := c.orchestratorModel.Chat(ctx, []ollama.Message{
        {Role: "system", Content: "You are producing standardized, reproducible output. Base all statements on concrete metrics. Prohibited: 'I think', 'It seems', 'Probably', 'In my opinion', 'I feel'."},
        {Role: "user", Content: prompt},
    })
    if err != nil {
        return nil, err
    }
    
    return c.parseSynthesis(response, sess.Prompt)
}

// RenderTLDR renders the final TLDR output
func (c *Coordinator) RenderTLDR(analysis *Analysis) string {
    var sb strings.Builder
    
    sb.WriteString("═══════════════════════════════════════════════════════════════════════\n")
    sb.WriteString("OLLAMABOT TLDR\n")
    sb.WriteString("═══════════════════════════════════════════════════════════════════════\n\n")
    
    sb.WriteString("PROMPT GOAL\n")
    sb.WriteString("───────────\n")
    sb.WriteString(analysis.Synthesis.PromptGoal + "\n\n")
    
    sb.WriteString("IMPLEMENTATION SUMMARY\n")
    sb.WriteString("──────────────────────\n")
    sb.WriteString(analysis.Synthesis.Implementation + "\n\n")
    
    sb.WriteString("EXPERT CONSENSUS\n")
    sb.WriteString("────────────────\n")
    for name, score := range analysis.Synthesis.ExpertConsensus {
        sb.WriteString(fmt.Sprintf("%s: %d%%\n", name, score))
    }
    sb.WriteString("\n")
    
    sb.WriteString("DISCOVERIES & LEARNINGS\n")
    sb.WriteString("───────────────────────\n")
    for _, discovery := range analysis.Synthesis.Discoveries {
        sb.WriteString(fmt.Sprintf("• %s\n", discovery))
    }
    sb.WriteString("\n")
    
    sb.WriteString("QUALITY ASSESSMENT\n")
    sb.WriteString("──────────────────\n")
    sb.WriteString(fmt.Sprintf("The orchestrator determines this implementation to be:\n%s\n\n", analysis.Synthesis.QualityAssessment))
    sb.WriteString("Justification:\n")
    sb.WriteString(analysis.Synthesis.Justification + "\n\n")
    
    sb.WriteString("ACTIONABLE RECOMMENDATIONS\n")
    sb.WriteString("──────────────────────────\n")
    for i, rec := range analysis.Synthesis.Recommendations {
        sb.WriteString(fmt.Sprintf("%d. %s\n", i+1, rec))
    }
    
    sb.WriteString("\n═══════════════════════════════════════════════════════════════════════\n")
    
    return sb.String()
}
```

---

## 18. Testing Strategy

### 18.1 Test Categories

1. **Unit Tests**: Individual component tests
2. **Integration Tests**: Component interaction tests
3. **Golden Tests**: Prompt and output snapshot tests
4. **Navigation Tests**: Schedule/process navigation rule tests
5. **Suspension Tests**: Error handling and recovery tests
6. **Session Tests**: Persistence and restoration tests

### 18.2 Navigation Rule Tests

```go
// internal/orchestrate/navigator_test.go

package orchestrate

import (
    "testing"
)

func TestNavigationRules(t *testing.T) {
    tests := []struct {
        name     string
        from     ProcessID
        to       ProcessID
        valid    bool
    }{
        // From initial state
        {"Initial to P1", 0, Process1, true},
        {"Initial to P2", 0, Process2, false},
        {"Initial to P3", 0, Process3, false},
        
        // From P1
        {"P1 to P1", Process1, Process1, true},
        {"P1 to P2", Process1, Process2, true},
        {"P1 to P3", Process1, Process3, false},  // FORBIDDEN
        
        // From P2
        {"P2 to P1", Process2, Process1, true},
        {"P2 to P2", Process2, Process2, true},
        {"P2 to P3", Process2, Process3, true},
        
        // From P3
        {"P3 to P1", Process3, Process1, false},  // FORBIDDEN
        {"P3 to P2", Process3, Process2, true},
        {"P3 to P3", Process3, Process3, true},
        {"P3 to terminate", Process3, 0, true},
    }
    
    o := NewOrchestrator(nil)
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            valid := o.isValidNavigation(tt.from, tt.to)
            if valid != tt.valid {
                t.Errorf("isValidNavigation(%d, %d) = %v, want %v", tt.from, tt.to, valid, tt.valid)
            }
        })
    }
}
```

---

## 19. Migration Path

### 19.1 Phase 1: Core Infrastructure

1. Create directory structure under `internal/orchestrate/`
2. Implement core types and interfaces
3. Implement orchestrator state machine
4. Implement navigation logic with validation

### 19.2 Phase 2: Schedule and Process Implementation

1. Implement schedule factory
2. Implement all 15 processes
3. Integrate model coordination
4. Add human consultation handling

### 19.3 Phase 3: UI and Display

1. Implement ANSI display system
2. Implement memory visualization
3. Implement terminal UI application
4. Add input handling

### 19.4 Phase 4: Persistence and Git

1. Implement session manager
2. Implement recurrence relations
3. Implement restore script generation
4. Implement GitHub/GitLab integration

### 19.5 Phase 5: Analysis and Summary

1. Implement resource monitoring
2. Implement prompt summary generation
3. Implement LLM-as-judge
4. Implement flow code generation

---

## 20. Open Implementation Questions

1. **Model Loading**: How should we handle model loading/unloading to manage memory?

2. **Checkpoint Granularity**: Should checkpoints be created after every process or only after schedule termination?

3. **Concurrent Operations**: Should we allow any concurrent operations (e.g., background indexing)?

4. **External Tool Integration**: How should we integrate external tools (linters, formatters, test runners)?

5. **Custom Schedule Definitions**: Should users be able to define custom schedules/processes?

6. **Distributed Execution**: Any considerations for future distributed execution across machines?

7. **Telemetry**: Should we add telemetry for usage analytics (opt-in)?

8. **Plugin System**: Any hooks for plugins/extensions?

These questions should be addressed as implementation progresses based on practical needs and user feedback.
