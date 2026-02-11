// Package process defines the process interface and base implementation for obot orchestration.
package process

import (
	"context"
	"fmt"
	"time"

	"github.com/croberts/obot/internal/orchestrate"
)

// Process defines the interface for an orchestratable process.
// Each process represents a single step within a schedule.
type Process interface {
	// ID returns the process ID (1, 2, or 3)
	ID() orchestrate.ProcessID

	// Name returns the display name of the process
	Name() string

	// Schedule returns the ID of the schedule this process belongs to
	Schedule() orchestrate.ScheduleID

	// Execute runs the process logic
	Execute(ctx context.Context, exec func(context.Context, string) error) error

	// RequiresHumanConsultation returns true if the process requires human input
	RequiresHumanConsultation() bool

	// ConsultationType returns the type of human consultation required
	ConsultationType() orchestrate.ConsultationType

	// ValidateEntry checks if the process can be started based on current state
	ValidateEntry(lastProcess orchestrate.ProcessID) error
}

// BaseProcess provides common functionality for all 15 processes.
// It implements the Process interface and can be embedded in specific process types.
type BaseProcess struct {
	ProcessID        orchestrate.ProcessID
	ProcessName      string
	ScheduleID       orchestrate.ScheduleID
	ConsultationType orchestrate.ConsultationType
	
	// Stats tracking
	StartTime time.Time
	EndTime   time.Time
	Tokens    int64
	Actions   int
}

// NewBaseProcess creates a new base process instance.
func NewBaseProcess(sID orchestrate.ScheduleID, pID orchestrate.ProcessID, name string) *BaseProcess {
	return &BaseProcess{
		ProcessID:        pID,
		ProcessName:      name,
		ScheduleID:       sID,
		ConsultationType: orchestrate.GetProcessConsultationType(sID, pID),
	}
}

// ID returns the process ID (1, 2, or 3)
func (p *BaseProcess) ID() orchestrate.ProcessID {
	return p.ProcessID
}

// Name returns the display name of the process
func (p *BaseProcess) Name() string {
	if p.ProcessName != "" {
		return p.ProcessName
	}
	return orchestrate.ProcessNames[p.ScheduleID][p.ProcessID]
}

// Schedule returns the ID of the schedule this process belongs to
func (p *BaseProcess) Schedule() orchestrate.ScheduleID {
	return p.ScheduleID
}

// RequiresHumanConsultation returns true if the process requires human input
func (p *BaseProcess) RequiresHumanConsultation() bool {
	return p.ConsultationType != orchestrate.ConsultationNone
}

// GetConsultationType returns the type of human consultation required
func (p *BaseProcess) GetConsultationType() orchestrate.ConsultationType {
	return p.ConsultationType
}

// InvalidNavigationError represents a process-level navigation violation.
type InvalidNavigationError struct {
	From     orchestrate.ProcessID
	To       orchestrate.ProcessID
	Schedule orchestrate.ScheduleID
	Message  string
}

func (e *InvalidNavigationError) Error() string {
	return e.Message
}

// ValidateEntry checks if the process can be started based on the last process.
// It enforces the strict 1↔2↔3 navigation rules.
func (p *BaseProcess) ValidateEntry(lastProcess orchestrate.ProcessID) error {
	if !orchestrate.IsValidNavigation(lastProcess, p.ProcessID) {
		return &InvalidNavigationError{
			From:     lastProcess,
			To:       p.ProcessID,
			Schedule: p.ScheduleID,
			Message:  fmt.Sprintf("Invalid transition from P%d to P%d in %s schedule", lastProcess, p.ProcessID, orchestrate.ScheduleNames[p.ScheduleID]),
		}
	}
	return nil
}

// RecordStart marks the beginning of process execution.
func (p *BaseProcess) RecordStart() {
	p.StartTime = time.Now()
}

// RecordEnd marks the end of process execution.
func (p *BaseProcess) RecordEnd() {
	p.EndTime = time.Now()
}

// Duration returns the time spent on this process.
func (p *BaseProcess) Duration() time.Duration {
	if p.EndTime.IsZero() {
		if p.StartTime.IsZero() {
			return 0
		}
		return time.Since(p.StartTime)
	}
	return p.EndTime.Sub(p.StartTime)
}

// RecordTokens adds to the token count for this process.
func (p *BaseProcess) RecordTokens(count int64) {
	p.Tokens += count
}

// RecordAction increments the action count for this process.
func (p *BaseProcess) RecordAction() {
	p.Actions++
}
