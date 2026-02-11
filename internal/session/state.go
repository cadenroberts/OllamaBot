package session

import (
	"fmt"
	"time"

	"github.com/croberts/obot/internal/orchestrate"
)

// FormatStateID creates a state ID in the format 0001-S1P1.
func FormatStateID(sequence int, schedule orchestrate.ScheduleID, process orchestrate.ProcessID) string {
	return fmt.Sprintf("%04d-S%dP%d", sequence, schedule, process)
}

// State represents a specific point in a session's execution.
type State struct {
	ID        string    `json:"id"`        // Format: 0001-S1P1
	Prev      string    `json:"prev"`      // ID of previous state
	Next      string    `json:"next"`      // ID of next state
	Schedule  orchestrate.ScheduleID `json:"schedule"`
	Process   orchestrate.ProcessID  `json:"process"`
	FilesHash string    `json:"files_hash"` // Hash of workspace at this state
	Actions   []string  `json:"actions"`    // Actions performed in this state
	Timestamp time.Time `json:"timestamp"`
}

// Note represents an observation, decision, or piece of feedback.
type Note struct {
	ID        string    `json:"id"`
	Timestamp time.Time `json:"timestamp"`
	Content   string    `json:"content"`
	Source    string    `json:"source"` // "orchestrator", "agent", "human", "system"
	Reviewed  bool      `json:"reviewed"`
}

// SessionStats tracks metrics across the entire session.
type SessionStats struct {
	Schedules    int                                       `json:"schedules"`
	Processes    int                                       `json:"processes"`
	Actions      int                                       `json:"actions"`
	Tokens       int64                                     `json:"tokens"`
	Resources    ResourceStats                             `json:"resources"`
	Timing       TimingStats                               `json:"timing"`
	Consultation ConsultationStats                         `json:"consultation"`
	
	// Breakdown by schedule/process
	ScheduleCounts map[orchestrate.ScheduleID]int            `json:"schedule_counts"`
	ProcessCounts  map[orchestrate.ScheduleID]map[orchestrate.ProcessID]int `json:"process_counts"`
}

// ResourceStats tracks physical resource usage.
type ResourceStats struct {
	PeakMemoryGB  float64 `json:"peak_memory_gb"`
	DiskWrittenMB float64 `json:"disk_written_mb"`
	DiskDeletedMB float64 `json:"disk_deleted_mb"`
}

// TimingStats tracks temporal metrics.
type TimingStats struct {
	StartTime    time.Time     `json:"start_time"`
	EndTime      time.Time     `json:"end_time"`
	TotalElapsed time.Duration `json:"total_elapsed"`
	AgentTime    time.Duration `json:"agent_time"`
	HumanWait    time.Duration `json:"human_wait"`
}

// ConsultationStats tracks human interaction metrics.
type ConsultationStats struct {
	Initial        int `json:"initial"`
	Clarifications int `json:"clarifications"`
	Feedback       int `json:"feedback"`
	Substituted    int `json:"substituted"` // AI-substituted human responses
}

// SuspendError represents a critical failure that requires suspension.
type SuspendError struct {
	Code        string    `json:"code"`
	Message     string    `json:"message"`
	Component   string    `json:"component"`
	Rule        string    `json:"rule"`
	State       State     `json:"state"`
	Timestamp   time.Time `json:"timestamp"`
	Solutions   []string  `json:"solutions"`
	Recoverable bool      `json:"recoverable"`
}

func (e *SuspendError) Error() string {
	return e.Message
}
