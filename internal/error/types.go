// Package errs defines the error codes and types for OllamaBot.
package errs

import (
	"fmt"
	"time"
)

// ErrorCode represents a unique identifier for a specific error condition.
type ErrorCode string

// ErrorSeverity defines the impact levels for orchestration errors as strings.
type ErrorSeverity string

const (
	SeverityCritical ErrorSeverity = "critical"
	SeveritySystem   ErrorSeverity = "system"
	SeverityWarning  ErrorSeverity = "warning"
)

// FrozenState captures the state of the orchestrator when an error occurs.
type FrozenState struct {
	Schedule   string
	Process    string
	LastAction string
	FlowCode   string
}

// OrchestrationError represents a structured error in the orchestration flow.
type OrchestrationError struct {
	Code        ErrorCode
	Severity    ErrorSeverity
	Component   string
	Message     string
	Rule        string
	Timestamp   time.Time
	State       FrozenState
	Solutions   []string
	Recoverable bool
}

func (e *OrchestrationError) Error() string {
	return fmt.Sprintf("[%s] %s: %s", e.Code, e.Severity, e.Message)
}

const (
	// --- Navigation Violations (E001-E009) ---

	// ErrInvalidTransition indicates a jump between non-adjacent processes (e.g., P1 to P3).
	ErrInvalidTransition ErrorCode = "E001"
	// ErrAgentTermination indicates an agent attempted to terminate the schedule improperly.
	ErrAgentTermination ErrorCode = "E002"
	// ErrOrchestratorBypass indicates the orchestrator attempted to bypass a required process.
	ErrOrchestratorBypass ErrorCode = "E003"
	// ErrCircularNavigation indicates a circular dependency or loop in process flow.
	ErrCircularNavigation ErrorCode = "E004"
	// ErrStateMismatch indicates a state inconsistency detected during navigation.
	ErrStateMismatch ErrorCode = "E005"
	// ErrIllegalBacktrack indicates an attempt to backtrack to a finalized process.
	ErrIllegalBacktrack ErrorCode = "E006"
	// ErrProcessSkip indicates skipping a mandatory validation or checkpoint.
	ErrProcessSkip ErrorCode = "E007"
	// ErrConcurrentNavigation indicates multiple agents attempting to navigate the same flow.
	ErrConcurrentNavigation ErrorCode = "E008"
	// ErrTargetNotFound indicates the navigation target process does not exist.
	ErrTargetNotFound ErrorCode = "E009"

	// --- System Errors (E010-E015) ---

	// ErrOllamaUnavailable indicates the Ollama service is not reachable.
	ErrOllamaUnavailable ErrorCode = "E010"
	// ErrModelNotFound indicates the specified LLM model is not available.
	ErrModelNotFound ErrorCode = "E011"
	// ErrResourceExhausted indicates system resources (memory/CPU) are critically low.
	ErrResourceExhausted ErrorCode = "E012"
	// ErrFileSystemAccess indicates a failure in reading or writing to the file system.
	ErrFileSystemAccess ErrorCode = "E013"
	// ErrNetworkTimeout indicates a network operation exceeded its deadline.
	ErrNetworkTimeout ErrorCode = "E014"
	// ErrGitConflict indicates a git operation failed due to unmanaged conflicts.
	ErrGitConflict ErrorCode = "E015"

	// --- Validation Errors (E016-E020) ---

	// ErrInvalidInput indicates the user input failed validation.
	ErrInvalidInput ErrorCode = "E016"
	// ErrMissingParameter indicates a required parameter was not provided.
	ErrMissingParameter ErrorCode = "E017"
	// ErrOutOfRange indicates a numerical value is outside the allowed range.
	ErrOutOfRange ErrorCode = "E018"
	// ErrFormatMismatch indicates the input format does not match expectation.
	ErrFormatMismatch ErrorCode = "E019"
	// ErrIncompatibleVersion indicates a version mismatch between components.
	ErrIncompatibleVersion ErrorCode = "E020"

	// --- Authentication & Permission Errors (E021-E025) ---

	// ErrUnauthorized indicates the user or agent is not authorized for the action.
	ErrUnauthorized ErrorCode = "E021"
	// ErrTokenExpired indicates an API token or session has expired.
	ErrTokenExpired ErrorCode = "E022"
	// ErrInsufficientScope indicates the provided credentials lack necessary scope.
	ErrInsufficientScope ErrorCode = "E023"
	// ErrForbiddenAction indicates the action is explicitly forbidden by policy.
	ErrForbiddenAction ErrorCode = "E024"
	// ErrKeyMissing indicates a required API key or secret is missing.
	ErrKeyMissing ErrorCode = "E025"
)

// Impact defines the severity of an error on the system as an integer.
type Impact int

const (
	ImpactNone Impact = iota
	ImpactLow
	ImpactMedium
	ImpactHigh
	ImpactCritical
	ImpactFatal
)

// String returns the string representation of the impact.
func (i Impact) String() string {
	switch i {
	case ImpactLow:
		return "LOW"
	case ImpactMedium:
		return "MEDIUM"
	case ImpactHigh:
		return "HIGH"
	case ImpactCritical:
		return "CRITICAL"
	case ImpactFatal:
		return "FATAL"
	default:
		return "NONE"
	}
}

// ErrorMetadata contains descriptive information about an error code.
type ErrorMetadata struct {
	Code        ErrorCode
	Description string
	Impact      Impact
	Recoverable bool
	ActionHint  string
}

// Registry maintains a map of error codes to their metadata.
var Registry = map[ErrorCode]ErrorMetadata{
	ErrInvalidTransition: {
		Code:        ErrInvalidTransition,
		Description: "Invalid process transition (e.g., P1 to P3).",
		Impact:      ImpactHigh,
		Recoverable: true,
		ActionHint:  "Ensure process navigation follows the strict 1-2-3 sequence.",
	},
	ErrAgentTermination: {
		Code:        ErrAgentTermination,
		Description: "Agent attempted to terminate schedule prematurely.",
		Impact:      ImpactCritical,
		Recoverable: false,
		ActionHint:  "Check agent prompts and termination conditions.",
	},
	ErrOrchestratorBypass: {
		Code:        ErrOrchestratorBypass,
		Description: "Orchestrator bypassed a mandatory process step.",
		Impact:      ImpactHigh,
		Recoverable: true,
		ActionHint:  "Verify orchestration logic and flow code generation.",
	},
	ErrCircularNavigation: {
		Code:        ErrCircularNavigation,
		Description: "Circular dependency detected in process flow.",
		Impact:      ImpactMedium,
		Recoverable: true,
		ActionHint:  "Analyze flow code for loops and simplify transitions.",
	},
	ErrStateMismatch: {
		Code:        ErrStateMismatch,
		Description: "Inconsistent state detected during navigation.",
		Impact:      ImpactHigh,
		Recoverable: true,
		ActionHint:  "Check for concurrent modifications to the session state.",
	},
	ErrIllegalBacktrack: {
		Code:        ErrIllegalBacktrack,
		Description: "Illegal attempt to backtrack to a finalized process.",
		Impact:      ImpactMedium,
		Recoverable: true,
		ActionHint:  "If backtracking is necessary, use the checkpoint restore functionality.",
	},
	ErrProcessSkip: {
		Code:        ErrProcessSkip,
		Description: "Mandatory process step was skipped.",
		Impact:      ImpactHigh,
		Recoverable: true,
		ActionHint:  "Ensure all required processes (P1, P2) are executed before P3.",
	},
	ErrConcurrentNavigation: {
		Code:        ErrConcurrentNavigation,
		Description: "Multiple agents attempting concurrent navigation.",
		Impact:      ImpactCritical,
		Recoverable: false,
		ActionHint:  "Implement locking or sequence the agent requests.",
	},
	ErrTargetNotFound: {
		Code:        ErrTargetNotFound,
		Description: "Navigation target process was not found.",
		Impact:      ImpactHigh,
		Recoverable: true,
		ActionHint:  "Check the flow code for valid process IDs.",
	},
	ErrOllamaUnavailable: {
		Code:        ErrOllamaUnavailable,
		Description: "Ollama service is not running or unreachable.",
		Impact:      ImpactFatal,
		Recoverable: true,
		ActionHint:  "Run 'ollama serve' and ensure the API is accessible at 127.0.0.1:11434.",
	},
	ErrModelNotFound: {
		Code:        ErrModelNotFound,
		Description: "The requested LLM model is not available in Ollama.",
		Impact:      ImpactFatal,
		Recoverable: true,
		ActionHint:  "Run 'ollama pull <model_name>' to download the required model.",
	},
	ErrResourceExhausted: {
		Code:        ErrResourceExhausted,
		Description: "Critical system resource exhaustion (Memory/CPU/Disk).",
		Impact:      ImpactCritical,
		Recoverable: true,
		ActionHint:  "Free up system resources or reduce the context window size.",
	},
	ErrFileSystemAccess: {
		Code:        ErrFileSystemAccess,
		Description: "Failed to access or modify files on disk.",
		Impact:      ImpactHigh,
		Recoverable: false,
		ActionHint:  "Check file permissions and disk space.",
	},
	ErrNetworkTimeout: {
		Code:        ErrNetworkTimeout,
		Description: "Network operation timed out.",
		Impact:      ImpactMedium,
		Recoverable: true,
		ActionHint:  "Check your internet connection or increase the timeout settings.",
	},
	ErrGitConflict: {
		Code:        ErrGitConflict,
		Description: "Git operation failed due to merge conflicts.",
		Impact:      ImpactHigh,
		Recoverable: true,
		ActionHint:  "Manually resolve the conflicts or use the 'fix' command.",
	},
	ErrInvalidInput: {
		Code:        ErrInvalidInput,
		Description: "Invalid user input or command parameters.",
		Impact:      ImpactLow,
		Recoverable: true,
		ActionHint:  "Check the command usage and try again.",
	},
	ErrMissingParameter: {
		Code:        ErrMissingParameter,
		Description: "A required parameter is missing from the request.",
		Impact:      ImpactLow,
		Recoverable: true,
		ActionHint:  "Provide all required parameters.",
	},
	ErrOutOfRange: {
		Code:        ErrOutOfRange,
		Description: "Value provided is outside the allowed boundaries.",
		Impact:      ImpactLow,
		Recoverable: true,
		ActionHint:  "Ensure values are within specified limits.",
	},
	ErrFormatMismatch: {
		Code:        ErrFormatMismatch,
		Description: "Input format does not match the expected pattern.",
		Impact:      ImpactLow,
		Recoverable: true,
		ActionHint:  "Check formatting (e.g., JSON structure, date formats).",
	},
	ErrIncompatibleVersion: {
		Code:        ErrIncompatibleVersion,
		Description: "Incompatible version detected between client and server.",
		Impact:      ImpactMedium,
		Recoverable: false,
		ActionHint:  "Update the OllamaBot CLI to the latest version.",
	},
	ErrUnauthorized: {
		Code:        ErrUnauthorized,
		Description: "User or agent is not authorized to perform this action.",
		Impact:      ImpactHigh,
		Recoverable: false,
		ActionHint:  "Check your credentials and permissions.",
	},
	ErrTokenExpired: {
		Code:        ErrTokenExpired,
		Description: "The authentication token or session has expired.",
		Impact:      ImpactMedium,
		Recoverable: true,
		ActionHint:  "Re-authenticate to obtain a new token.",
	},
	ErrInsufficientScope: {
		Code:        ErrInsufficientScope,
		Description: "The credentials provided lack the required scope/permissions.",
		Impact:      ImpactHigh,
		Recoverable: false,
		ActionHint:  "Request elevated permissions for the required resource.",
	},
	ErrForbiddenAction: {
		Code:        ErrForbiddenAction,
		Description: "This action is explicitly forbidden by security policy.",
		Impact:      ImpactCritical,
		Recoverable: false,
		ActionHint:  "Consult the security documentation for allowed operations.",
	},
	ErrKeyMissing: {
		Code:        ErrKeyMissing,
		Description: "A required API key or secret is missing from the environment.",
		Impact:      ImpactFatal,
		Recoverable: true,
		ActionHint:  "Set the required environment variables (e.g., OLLAMA_API_KEY).",
	},
}

// AppError is a custom error type that includes an ErrorCode and additional context.
type AppError struct {
	Code      ErrorCode
	Message   string
	Cause     error
	Context   map[string]interface{}
	Timestamp int64
}

// Error implements the error interface for AppError.
func (e *AppError) Error() string {
	if e.Cause != nil {
		return fmt.Sprintf("[%s] %s: %v", e.Code, e.Message, e.Cause)
	}
	return fmt.Sprintf("[%s] %s", e.Code, e.Message)
}

// Unwrap returns the underlying cause of the error.
func (e *AppError) Unwrap() error {
	return e.Cause
}

// NewAppError creates a new AppError with the given code and message.
func NewAppError(code ErrorCode, message string) *AppError {
	return &AppError{
		Code:    code,
		Message: message,
	}
}

// Wrap wraps an existing error into an AppError.
func Wrap(err error, code ErrorCode, message string) *AppError {
	return &AppError{
		Code:    code,
		Message: message,
		Cause:   err,
	}
}

// WithContext adds contextual information to the error.
func (e *AppError) WithContext(key string, value interface{}) *AppError {
	if e.Context == nil {
		e.Context = make(map[string]interface{})
	}
	e.Context[key] = value
	return e
}

// GetMetadata returns the metadata for the error.
func (e *AppError) GetMetadata() (ErrorMetadata, bool) {
	return GetMetadata(e.Code)
}

// GetImpact returns the impact of the error.
func (e *AppError) GetImpact() Impact {
	return GetImpact(e.Code)
}

// GetMetadata returns the metadata for a given error code.
func GetMetadata(code ErrorCode) (ErrorMetadata, bool) {
	meta, ok := Registry[code]
	return meta, ok
}

// IsRecoverable returns true if the error is marked as recoverable in the registry.
func IsRecoverable(code ErrorCode) bool {
	meta, ok := Registry[code]
	return ok && meta.Recoverable
}

// GetImpact returns the impact of a given error code.
func GetImpact(code ErrorCode) Impact {
	meta, ok := Registry[code]
	if !ok {
		return ImpactNone
	}
	return meta.Impact
}

// FormatError returns a formatted string for the error code.
func FormatError(code ErrorCode) string {
	meta, ok := Registry[code]
	if !ok {
		return fmt.Sprintf("Unknown Error (%s)", code)
	}
	return fmt.Sprintf("[%s] %s (Impact: %s)", code, meta.Description, meta.Impact)
}

// GetActionHint returns the suggested action for a given error code.
func GetActionHint(code ErrorCode) string {
	meta, ok := Registry[code]
	if !ok {
		return "No action hint available."
	}
	return meta.ActionHint
}

// NewNavigationError creates a new E001 navigation error.
func NewNavigationError(message string, state FrozenState) *OrchestrationError {
	return &OrchestrationError{
		Code:        ErrInvalidTransition,
		Severity:    SeverityWarning,
		Component:   "Orchestrator",
		Message:     message,
		Rule:        "P1↔P2↔P3 navigation rule",
		Timestamp:   time.Now(),
		State:       state,
		Solutions:   []string{"Follow 1-2-3 sequence", "Reset to P1"},
		Recoverable: true,
	}
}

// NewOrchestratorViolationError creates a new error when orchestrator performs agent actions.
func NewOrchestratorViolationError(message string, state FrozenState) *OrchestrationError {
	return &OrchestrationError{
		Code:        ErrForbiddenAction,
		Severity:    SeverityCritical,
		Component:   "Orchestrator",
		Message:     message,
		Rule:        "TOOLER violation: orchestrator cannot perform agent actions",
		Timestamp:   time.Now(),
		State:       state,
		Solutions:   []string{"Delegate to Agent", "Refactor orchestration logic"},
		Recoverable: false,
	}
}

// NewAgentViolationError creates a new error when agent performs orchestration tasks.
func NewAgentViolationError(message string, state FrozenState) *OrchestrationError {
	return &OrchestrationError{
		Code:        ErrForbiddenAction,
		Severity:    SeverityCritical,
		Component:   "Agent",
		Message:     message,
		Rule:        "EXECUTOR violation: agent cannot perform orchestration decisions",
		Timestamp:   time.Now(),
		State:       state,
		Solutions:   []string{"Limit agent scope", "Check system prompts"},
		Recoverable: false,
	}
}
