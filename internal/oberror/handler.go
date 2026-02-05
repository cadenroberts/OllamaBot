// Package oberror implements error handling for obot orchestration.
package oberror

import (
	"context"
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/croberts/obot/internal/orchestrate"
)

// ErrorCode identifies specific error types
type ErrorCode string

const (
	// Navigation errors (E001-E009)
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
	ErrOllamaNotRunning  ErrorCode = "E010"
	ErrModelNotAvailable ErrorCode = "E011"
	ErrMemoryPressure    ErrorCode = "E012"
	ErrDiskExhausted     ErrorCode = "E013"
	ErrNetworkFailure    ErrorCode = "E014"
	ErrGitOperation      ErrorCode = "E015"
)

// Severity indicates error severity
type Severity string

const (
	SeverityCritical Severity = "critical"
	SeveritySystem   Severity = "system"
	SeverityWarning  Severity = "warning"
)

// OrchestrationError represents an orchestration error
type OrchestrationError struct {
	Code        ErrorCode
	Severity    Severity
	Component   string // "orchestrator", "agent", "system"
	Message     string
	Rule        string // Which rule was violated
	Timestamp   time.Time

	// State at error
	Schedule   orchestrate.ScheduleID
	Process    orchestrate.ProcessID
	LastAction string
	FlowCode   string

	// Analysis
	Solutions   []string
	Recoverable bool
}

func (e *OrchestrationError) Error() string {
	return fmt.Sprintf("[%s] %s: %s", e.Code, e.Component, e.Message)
}

// Handler manages error handling and suspension
type Handler struct {
	writer io.Writer
	reader io.Reader
}

// NewHandler creates a new error handler
func NewHandler(reader io.Reader, writer io.Writer) *Handler {
	return &Handler{
		reader: reader,
		writer: writer,
	}
}

// HardcodedMessages contains static error messages
var HardcodedMessages = map[ErrorCode]string{
	ErrOllamaNotRunning:  "Ollama is not running. Start Ollama with: ollama serve",
	ErrModelNotAvailable: "Required model '%s' not found. Pull with: ollama pull %s",
	ErrDiskExhausted:     "Disk space exhausted. Free space required: %s",
}

// IsHardcoded checks if an error has a hardcoded message
func IsHardcoded(code ErrorCode) bool {
	_, ok := HardcodedMessages[code]
	return ok
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

// SuspensionAction represents user-chosen action after suspension
type SuspensionAction string

const (
	ActionRetry       SuspensionAction = "retry"
	ActionSkip        SuspensionAction = "skip"
	ActionAbort       SuspensionAction = "abort"
	ActionInvestigate SuspensionAction = "investigate"
)

// SuspensionResult contains the result of suspension handling
type SuspensionResult struct {
	Action    SuspensionAction
	StateID   string
	Solutions []string
}

// HandleSuspension displays suspension UI and handles error
func (h *Handler) HandleSuspension(ctx context.Context, err *OrchestrationError) (*SuspensionResult, error) {
	// Display suspension UI
	h.displaySuspensionUI(err)

	// In a real implementation, this would wait for user input
	// For now, return a default action
	return &SuspensionResult{
		Action:    ActionRetry,
		Solutions: err.Solutions,
	}, nil
}

// displaySuspensionUI displays the suspension UI
func (h *Handler) displaySuspensionUI(err *OrchestrationError) {
	var sb strings.Builder

	sb.WriteString("\n")
	sb.WriteString("┌─────────────────────────────────────────────────────────────────────┐\n")
	sb.WriteString("│ Orchestrator • Suspended                                            │\n")
	sb.WriteString("│                                                                     │\n")
	sb.WriteString(fmt.Sprintf("│ ERROR: %s - %s\n", err.Code, truncate(err.Message, 50)))
	sb.WriteString("│                                                                     │\n")
	sb.WriteString("│ ═══════════════════════════════════════════════════════════════════ │\n")
	sb.WriteString("│ FROZEN STATE                                                        │\n")
	sb.WriteString("│ ═══════════════════════════════════════════════════════════════════ │\n")

	scheduleName := orchestrate.ScheduleNames[err.Schedule]
	processName := ""
	if processes, ok := orchestrate.ProcessNames[err.Schedule]; ok {
		processName = processes[err.Process]
	}

	sb.WriteString(fmt.Sprintf("│ Schedule: %s (S%d)\n", scheduleName, err.Schedule))
	sb.WriteString(fmt.Sprintf("│ Process: %s (P%d)\n", processName, err.Process))
	sb.WriteString(fmt.Sprintf("│ Last Action: %s\n", truncate(err.LastAction, 50)))
	sb.WriteString(fmt.Sprintf("│ Flow Code: %s\n", err.FlowCode))

	// Show error marker position
	if err.FlowCode != "" {
		sb.WriteString(fmt.Sprintf("│           %s^ Error occurred here\n", strings.Repeat(" ", len(err.FlowCode)-1)))
	}

	sb.WriteString("│                                                                     │\n")
	sb.WriteString("│ ═══════════════════════════════════════════════════════════════════ │\n")
	sb.WriteString("│ ERROR ANALYSIS                                                      │\n")
	sb.WriteString("│ ═══════════════════════════════════════════════════════════════════ │\n")

	// Hardcoded or LLM analysis
	if IsHardcoded(err.Code) {
		sb.WriteString(fmt.Sprintf("│ %s\n", GetHardcodedMessage(err.Code)))
	} else {
		sb.WriteString("│ LLM Analysis: (see detailed output)\n")
	}

	sb.WriteString("│                                                                     │\n")
	sb.WriteString(fmt.Sprintf("│ Component: %s\n", err.Component))
	sb.WriteString(fmt.Sprintf("│ Rule Violated: %s\n", truncate(err.Rule, 50)))
	sb.WriteString("│                                                                     │\n")

	// Proposed solutions
	sb.WriteString("│ ═══════════════════════════════════════════════════════════════════ │\n")
	sb.WriteString("│ PROPOSED SOLUTIONS                                                  │\n")
	sb.WriteString("│ ═══════════════════════════════════════════════════════════════════ │\n")

	for i, solution := range err.Solutions {
		sb.WriteString(fmt.Sprintf("│ %d. %s\n", i+1, truncate(solution, 60)))
	}

	sb.WriteString("│                                                                     │\n")
	sb.WriteString("│ ═══════════════════════════════════════════════════════════════════ │\n")
	sb.WriteString("│ SAFE CONTINUATION OPTIONS                                           │\n")
	sb.WriteString("│ ═══════════════════════════════════════════════════════════════════ │\n")
	sb.WriteString("│ [R] Retry last process                                              │\n")
	sb.WriteString("│ [S] Skip to next valid state                                        │\n")
	sb.WriteString("│ [A] Abort and save session                                          │\n")
	sb.WriteString("│ [I] Investigate (enter debug mode)                                  │\n")
	sb.WriteString("│                                                                     │\n")
	sb.WriteString("│ Select option: _                                                    │\n")
	sb.WriteString("└─────────────────────────────────────────────────────────────────────┘\n")

	fmt.Fprint(h.writer, sb.String())
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
		Process:   to,
		Solutions: []string{
			"Return to the previous process and navigate correctly",
			"Reset to schedule start",
			"Abort current schedule",
		},
		Recoverable: true,
	}
}

// NewOrchestratorViolationError creates an orchestrator violation error
func NewOrchestratorViolationError(action string) *OrchestrationError {
	return &OrchestrationError{
		Code:       ErrOrchestratorAsAgent,
		Severity:   SeverityCritical,
		Component:  "orchestrator",
		Message:    fmt.Sprintf("Orchestrator attempted agent action: %s", action),
		Rule:       "Orchestrator is a TOOLER only - cannot perform agent actions",
		Timestamp:  time.Now(),
		LastAction: action,
		Solutions: []string{
			"Reset orchestrator state",
			"Reload orchestrator model",
			"Abort session",
		},
		Recoverable: false,
	}
}

// NewAgentViolationError creates an agent violation error
func NewAgentViolationError(action string) *OrchestrationError {
	return &OrchestrationError{
		Code:       ErrAgentAsOrchestrator,
		Severity:   SeverityCritical,
		Component:  "agent",
		Message:    fmt.Sprintf("Agent attempted orchestration: %s", action),
		Rule:       "Agent is an EXECUTOR only - cannot make orchestration decisions",
		Timestamp:  time.Now(),
		LastAction: action,
		Solutions: []string{
			"Reset agent state",
			"Reload agent model",
			"Abort current process",
		},
		Recoverable: false,
	}
}

// NewSystemError creates a system error
func NewSystemError(code ErrorCode, message string) *OrchestrationError {
	return &OrchestrationError{
		Code:        code,
		Severity:    SeveritySystem,
		Component:   "system",
		Message:     message,
		Timestamp:   time.Now(),
		Recoverable: true,
	}
}

// truncate truncates a string to maxLen
func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen-3] + "..."
}

// ErrorCodeDescriptions provides descriptions for error codes
var ErrorCodeDescriptions = map[ErrorCode]string{
	ErrNavigationP1ToP3:     "Invalid process navigation (P1 to P3 jump)",
	ErrAgentTerminateSchedule: "Agent attempted to terminate schedule",
	ErrAgentTerminatePrompt:   "Agent attempted to terminate prompt",
	ErrOrchestratorFileOp:     "Orchestrator performed file operation",
	ErrOrchestratorGenCode:    "Orchestrator generated code",
	ErrOrchestratorAsAgent:    "Orchestrator acted as agent",
	ErrAgentAsOrchestrator:    "Agent acted as orchestrator",
	ErrScheduleTermEarly:      "Schedule terminated before P3 completed",
	ErrUndefinedAction:        "Undefined action type executed",
	ErrOllamaNotRunning:       "Ollama is not running",
	ErrModelNotAvailable:      "Model not available",
	ErrMemoryPressure:         "Memory pressure critical",
	ErrDiskExhausted:          "Disk space exhausted",
	ErrNetworkFailure:         "Network failure",
	ErrGitOperation:           "Git operation failed",
}

// GetErrorDescription returns the description for an error code
func GetErrorDescription(code ErrorCode) string {
	if desc, ok := ErrorCodeDescriptions[code]; ok {
		return desc
	}
	return "Unknown error"
}
