// Package orchestrate implements the core orchestration logic.
package orchestrate

import (
	"context"
	"fmt"
	"sync"
	"time"
)

// Orchestrator manages schedule and process selection with strict separation of concerns.
// The orchestrator is a TOOLER ONLY - it cannot perform agent actions.
type Orchestrator struct {
	mu    sync.Mutex
	state OrchestratorState

	// Current execution state
	currentSchedule *Schedule
	currentProcess  *Process

	// Tracking
	scheduleHistory   []ScheduleID
	processHistory    []ProcessExecution
	scheduleCounts    map[ScheduleID]int
	processCounts     map[ScheduleID]map[ProcessID]int
	lastProcessBySchedule map[ScheduleID]ProcessID

	// Flow code tracking
	flowCode *FlowCode

	// Session context
	prompt       string
	sessionNotes []Note

	// Statistics
	stats *OrchestratorStats

	// Callbacks
	onStateChange   func(OrchestratorState)
	onScheduleStart func(ScheduleID)
	onProcessStart  func(ScheduleID, ProcessID)
	onProcessEnd    func(ScheduleID, ProcessID)
	onScheduleEnd   func(ScheduleID)
	onError         func(error)
}

// ProcessExecution tracks a single process execution
type ProcessExecution struct {
	Schedule  ScheduleID
	Process   ProcessID
	StartTime time.Time
	EndTime   time.Time
	Tokens    int64
	Actions   int
}

// Note represents a session note
type Note struct {
	ID        string
	Timestamp time.Time
	Content   string
	Source    string // "user", "ai-substitute", "system"
	Reviewed  bool
}

// OrchestratorStats tracks orchestration statistics
type OrchestratorStats struct {
	TotalSchedulings    int
	TotalProcesses      int
	SchedulingsByID     map[ScheduleID]int
	ProcessesBySchedule map[ScheduleID]map[ProcessID]int
	TotalTokens         int64
	TotalActions        int
	StartTime           time.Time
	EndTime             time.Time
}

// NewOrchestrator creates a new orchestrator
func NewOrchestrator() *Orchestrator {
	return &Orchestrator{
		state:               StateBegin,
		scheduleCounts:      make(map[ScheduleID]int),
		processCounts:       make(map[ScheduleID]map[ProcessID]int),
		lastProcessBySchedule: make(map[ScheduleID]ProcessID),
		flowCode:            NewFlowCode(),
		sessionNotes:        make([]Note, 0),
		stats: &OrchestratorStats{
			SchedulingsByID:     make(map[ScheduleID]int),
			ProcessesBySchedule: make(map[ScheduleID]map[ProcessID]int),
			StartTime:           time.Now(),
		},
	}
}

// SetPrompt sets the initial prompt
func (o *Orchestrator) SetPrompt(prompt string) {
	o.mu.Lock()
	defer o.mu.Unlock()
	o.prompt = prompt
}

// GetPrompt returns the initial prompt
func (o *Orchestrator) GetPrompt() string {
	o.mu.Lock()
	defer o.mu.Unlock()
	return o.prompt
}

// State returns the current orchestrator state
func (o *Orchestrator) State() OrchestratorState {
	o.mu.Lock()
	defer o.mu.Unlock()
	return o.state
}

// SetState updates the orchestrator state
func (o *Orchestrator) SetState(state OrchestratorState) {
	o.mu.Lock()
	o.state = state
	callback := o.onStateChange
	o.mu.Unlock()

	if callback != nil {
		callback(state)
	}
}

// CurrentSchedule returns the current schedule
func (o *Orchestrator) CurrentSchedule() *Schedule {
	o.mu.Lock()
	defer o.mu.Unlock()
	return o.currentSchedule
}

// CurrentProcess returns the current process
func (o *Orchestrator) CurrentProcess() *Process {
	o.mu.Lock()
	defer o.mu.Unlock()
	return o.currentProcess
}

// SelectSchedule selects the next schedule to execute
// This is called by the orchestrator model to make scheduling decisions
func (o *Orchestrator) SelectSchedule(scheduleID ScheduleID) error {
	o.mu.Lock()
	defer o.mu.Unlock()

	if scheduleID < ScheduleKnowledge || scheduleID > ScheduleProduction {
		return fmt.Errorf("invalid schedule ID: %d", scheduleID)
	}

	// Initialize schedule
	schedule := &Schedule{
		ID:        scheduleID,
		Name:      ScheduleNames[scheduleID],
		Model:     GetScheduleModel(scheduleID),
		StartTime: time.Now(),
	}

	// Initialize processes
	for i := Process1; i <= Process3; i++ {
		schedule.Processes[i-1] = Process{
			ID:               i,
			Name:             ProcessNames[scheduleID][i],
			Schedule:         scheduleID,
			ConsultationType: GetProcessConsultationType(scheduleID, i),
		}
		if schedule.Processes[i-1].ConsultationType != ConsultationNone {
			schedule.Processes[i-1].RequiresHumanConsultation = true
		}
	}

	o.currentSchedule = schedule
	o.scheduleHistory = append(o.scheduleHistory, scheduleID)
	o.scheduleCounts[scheduleID]++
	o.stats.TotalSchedulings++
	o.stats.SchedulingsByID[scheduleID]++

	// Update flow code
	o.flowCode.AddSchedule(scheduleID)

	// Initialize process counts for this schedule if needed
	if o.processCounts[scheduleID] == nil {
		o.processCounts[scheduleID] = make(map[ProcessID]int)
	}
	if o.stats.ProcessesBySchedule[scheduleID] == nil {
		o.stats.ProcessesBySchedule[scheduleID] = make(map[ProcessID]int)
	}

	// Reset last process for this schedule
	o.lastProcessBySchedule[scheduleID] = 0

	if o.onScheduleStart != nil {
		go o.onScheduleStart(scheduleID)
	}

	return nil
}

// SelectProcess selects the next process to execute within the current schedule
// Enforces strict 1↔2↔3 navigation rules
func (o *Orchestrator) SelectProcess(processID ProcessID) error {
	o.mu.Lock()
	defer o.mu.Unlock()

	if o.currentSchedule == nil {
		return fmt.Errorf("no schedule selected")
	}

	if processID < Process1 || processID > Process3 {
		return fmt.Errorf("invalid process ID: %d", processID)
	}

	// Validate navigation
	lastProcess := o.lastProcessBySchedule[o.currentSchedule.ID]
	if !IsValidNavigation(lastProcess, processID) {
		return &NavigationError{
			From:     lastProcess,
			To:       processID,
			Schedule: o.currentSchedule.ID,
		}
	}

	// Set current process
	process := &o.currentSchedule.Processes[processID-1]
	process.StartTime = time.Now()
	o.currentProcess = process

	// Update tracking
	o.processCounts[o.currentSchedule.ID][processID]++
	o.stats.TotalProcesses++
	o.stats.ProcessesBySchedule[o.currentSchedule.ID][processID]++

	// Update flow code
	o.flowCode.AddProcess(processID)

	if o.onProcessStart != nil {
		go o.onProcessStart(o.currentSchedule.ID, processID)
	}

	return nil
}

// CompleteProcess marks the current process as completed
func (o *Orchestrator) CompleteProcess() error {
	o.mu.Lock()
	defer o.mu.Unlock()

	if o.currentProcess == nil {
		return fmt.Errorf("no process selected")
	}

	o.currentProcess.Completed = true
	o.currentProcess.EndTime = time.Now()

	// Record in history
	o.processHistory = append(o.processHistory, ProcessExecution{
		Schedule:  o.currentSchedule.ID,
		Process:   o.currentProcess.ID,
		StartTime: o.currentProcess.StartTime,
		EndTime:   o.currentProcess.EndTime,
	})

	return nil
}

// TerminateProcess terminates the current process
func (o *Orchestrator) TerminateProcess() error {
	o.mu.Lock()
	defer o.mu.Unlock()

	if o.currentProcess == nil {
		return fmt.Errorf("no process to terminate")
	}

	o.currentProcess.Terminated = true
	o.lastProcessBySchedule[o.currentSchedule.ID] = o.currentProcess.ID

	if o.onProcessEnd != nil {
		go o.onProcessEnd(o.currentSchedule.ID, o.currentProcess.ID)
	}

	return nil
}

// CanTerminateSchedule checks if the current schedule can be terminated
// Schedule can only be terminated after Process 3 has completed
func (o *Orchestrator) CanTerminateSchedule() bool {
	o.mu.Lock()
	defer o.mu.Unlock()

	if o.currentSchedule == nil {
		return false
	}

	lastProcess := o.lastProcessBySchedule[o.currentSchedule.ID]
	return lastProcess == Process3
}

// TerminateSchedule terminates the current schedule
func (o *Orchestrator) TerminateSchedule() error {
	o.mu.Lock()
	defer o.mu.Unlock()

	if o.currentSchedule == nil {
		return fmt.Errorf("no schedule to terminate")
	}

	lastProcess := o.lastProcessBySchedule[o.currentSchedule.ID]
	if lastProcess != Process3 {
		return fmt.Errorf("cannot terminate schedule: last process was P%d, must be P3", lastProcess)
	}

	o.currentSchedule.Terminated = true
	o.currentSchedule.EndTime = time.Now()

	if o.onScheduleEnd != nil {
		go o.onScheduleEnd(o.currentSchedule.ID)
	}

	o.currentSchedule = nil
	o.currentProcess = nil

	return nil
}

// CanTerminatePrompt checks if the prompt can be terminated
// Prerequisites: All 5 schedules run at least once, Production was last
func (o *Orchestrator) CanTerminatePrompt() bool {
	o.mu.Lock()
	defer o.mu.Unlock()

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

// TerminatePrompt terminates the prompt
func (o *Orchestrator) TerminatePrompt() error {
	if !o.CanTerminatePrompt() {
		return fmt.Errorf("cannot terminate prompt: prerequisites not met")
	}

	o.SetState(StatePromptTerminated)
	o.mu.Lock()
	o.stats.EndTime = time.Now()
	o.mu.Unlock()

	return nil
}

// MarkError marks an error in the flow code
func (o *Orchestrator) MarkError() {
	o.mu.Lock()
	defer o.mu.Unlock()
	o.flowCode.MarkError()
}

// GetFlowCode returns the current flow code
func (o *Orchestrator) GetFlowCode() string {
	o.mu.Lock()
	defer o.mu.Unlock()
	return o.flowCode.String()
}

// GetStats returns the orchestrator statistics
func (o *Orchestrator) GetStats() *OrchestratorStats {
	o.mu.Lock()
	defer o.mu.Unlock()

	// Return a copy
	stats := &OrchestratorStats{
		TotalSchedulings:    o.stats.TotalSchedulings,
		TotalProcesses:      o.stats.TotalProcesses,
		SchedulingsByID:     make(map[ScheduleID]int),
		ProcessesBySchedule: make(map[ScheduleID]map[ProcessID]int),
		TotalTokens:         o.stats.TotalTokens,
		TotalActions:        o.stats.TotalActions,
		StartTime:           o.stats.StartTime,
		EndTime:             o.stats.EndTime,
	}

	for k, v := range o.stats.SchedulingsByID {
		stats.SchedulingsByID[k] = v
	}
	for schedID, procMap := range o.stats.ProcessesBySchedule {
		stats.ProcessesBySchedule[schedID] = make(map[ProcessID]int)
		for procID, count := range procMap {
			stats.ProcessesBySchedule[schedID][procID] = count
		}
	}

	return stats
}

// AddNote adds a session note
func (o *Orchestrator) AddNote(content, source string) {
	o.mu.Lock()
	defer o.mu.Unlock()

	note := Note{
		ID:        fmt.Sprintf("N%d", len(o.sessionNotes)+1),
		Timestamp: time.Now(),
		Content:   content,
		Source:    source,
		Reviewed:  false,
	}
	o.sessionNotes = append(o.sessionNotes, note)
}

// GetUnreviewedNotes returns unreviewed notes
func (o *Orchestrator) GetUnreviewedNotes() []Note {
	o.mu.Lock()
	defer o.mu.Unlock()

	unreviewed := make([]Note, 0)
	for _, note := range o.sessionNotes {
		if !note.Reviewed {
			unreviewed = append(unreviewed, note)
		}
	}
	return unreviewed
}

// MarkNotesReviewed marks all notes as reviewed
func (o *Orchestrator) MarkNotesReviewed() {
	o.mu.Lock()
	defer o.mu.Unlock()

	for i := range o.sessionNotes {
		o.sessionNotes[i].Reviewed = true
	}
}

// RecordTokens records token usage
func (o *Orchestrator) RecordTokens(tokens int64) {
	o.mu.Lock()
	defer o.mu.Unlock()
	o.stats.TotalTokens += tokens
}

// RecordActions records action count
func (o *Orchestrator) RecordActions(count int) {
	o.mu.Lock()
	defer o.mu.Unlock()
	o.stats.TotalActions += count
}

// SetCallbacks sets the event callbacks
func (o *Orchestrator) SetCallbacks(
	onStateChange func(OrchestratorState),
	onScheduleStart func(ScheduleID),
	onProcessStart func(ScheduleID, ProcessID),
	onProcessEnd func(ScheduleID, ProcessID),
	onScheduleEnd func(ScheduleID),
	onError func(error),
) {
	o.mu.Lock()
	defer o.mu.Unlock()

	o.onStateChange = onStateChange
	o.onScheduleStart = onScheduleStart
	o.onProcessStart = onProcessStart
	o.onProcessEnd = onProcessEnd
	o.onScheduleEnd = onScheduleEnd
	o.onError = onError
}

// Run executes the main orchestration loop
func (o *Orchestrator) Run(ctx context.Context, selectScheduleFn func(context.Context) (ScheduleID, error), selectProcessFn func(context.Context, ScheduleID, ProcessID) (ProcessID, bool, error), executeProcessFn func(context.Context, ScheduleID, ProcessID) error) error {
	o.SetState(StateBegin)

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		// Check if we can terminate the prompt
		if o.CanTerminatePrompt() {
			// Let the orchestrator model decide
			o.SetState(StateSelecting)
		}

		// Select schedule
		o.SetState(StateSelecting)
		scheduleID, err := selectScheduleFn(ctx)
		if err != nil {
			o.MarkError()
			if o.onError != nil {
				o.onError(err)
			}
			return err
		}

		// Check for prompt termination signal (scheduleID == 0)
		if scheduleID == 0 {
			if o.CanTerminatePrompt() {
				return o.TerminatePrompt()
			}
			return fmt.Errorf("cannot terminate prompt: prerequisites not met")
		}

		if err := o.SelectSchedule(scheduleID); err != nil {
			o.MarkError()
			return err
		}

		// Run schedule until termination
		o.SetState(StateActive)
		lastProcess := ProcessID(0)

		for {
			// Select next process
			processID, terminate, err := selectProcessFn(ctx, scheduleID, lastProcess)
			if err != nil {
				o.MarkError()
				return err
			}

			if terminate {
				if err := o.TerminateSchedule(); err != nil {
					o.MarkError()
					return err
				}
				break
			}

			if err := o.SelectProcess(processID); err != nil {
				o.MarkError()
				return err
			}

			// Execute process
			if err := executeProcessFn(ctx, scheduleID, processID); err != nil {
				o.MarkError()
				return err
			}

			// Complete and terminate process
			if err := o.CompleteProcess(); err != nil {
				o.MarkError()
				return err
			}

			if err := o.TerminateProcess(); err != nil {
				o.MarkError()
				return err
			}

			// Review notes after each process termination
			o.MarkNotesReviewed()

			lastProcess = processID
		}
	}
}

// NavigationError represents an invalid navigation attempt
type NavigationError struct {
	From     ProcessID
	To       ProcessID
	Schedule ScheduleID
}

func (e *NavigationError) Error() string {
	return fmt.Sprintf("invalid navigation from P%d to P%d in schedule %s (only 1↔2↔3 allowed)",
		e.From, e.To, ScheduleNames[e.Schedule])
}
