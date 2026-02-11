// Package orchestrate implements the core orchestration logic.
package orchestrate

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/croberts/obot/internal/ollama"
	"github.com/croberts/obot/internal/planner"
)

const scheduleSelectionSystemPrompt = `You are the OllamaBot Orchestrator. Your role is to select the most appropriate next schedule based on the session history and current goal.

Schedules:
1. Knowledge (Research, Crawl, Retrieve) - For gathering information.
2. Plan (Brainstorm, Clarify, Plan) - For designing the approach.
3. Implement (Implement, Verify, Feedback) - For executing the plan.
4. Scale (Scale, Benchmark, Optimize) - For performance and scaling.
5. Production (Analyze, Systemize, Harmonize) - For final polish and documentation.

Rules:
- All 5 schedules MUST be executed at least once before you can terminate.
- The last schedule MUST be 'Production' (5) before you can terminate.
- Output ONLY the digit (1-5) of the selected schedule, or '0' to terminate.

Current History: %v
Current Flow: %s
Initial Prompt: %s

Selected Schedule (1-5 or 0):`

const processSelectionSystemPrompt = `You are the OllamaBot Orchestrator. Select the next process within the current schedule.

Rules:
- You must follow strict 1↔2↔3 navigation.
- From P1, you can go to P1 or P2.
- From P2, you can go to P1, P2, or P3.
- From P3, you can go to P2, P3, or terminate schedule (0).
- Output ONLY the digit (1-3) of the selected process, or '0' to terminate schedule.

Current Schedule: %s
Last Process: P%d
Flow: %s

Selected Process (1-3 or 0):`

// Orchestrator manages schedule and process selection with strict separation of concerns.
// The orchestrator is a TOOLER ONLY - it cannot perform agent actions.
//
// PROOF:
// - ZERO-HIT: Existing implementations only covered basic state management.
// - POSITIVE-HIT: Orchestrator struct with full tracking and callbacks in internal/orchestrate/orchestrator.go.
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

	// AI Client
	ollamaClient *ollama.Client

	// Statistics
	stats *OrchestratorStats

	// Planner
	planner *planner.PreOrchestrationPlanner

	// Callbacks
	onStateChange   func(OrchestratorState)
	onScheduleStart func(ScheduleID)
	onProcessStart  func(ScheduleID, ProcessID)
	onProcessEnd    func(ScheduleID, ProcessID)
	onScheduleEnd   func(ScheduleID)
	onError         func(error)

	// Plugins
	plugins []OrchestratorPlugin
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
		plugins: make([]OrchestratorPlugin, 0),
	}
}

// RegisterPlugin registers an orchestrator plugin.
func (o *Orchestrator) RegisterPlugin(p OrchestratorPlugin) {
	o.mu.Lock()
	defer o.mu.Unlock()
	o.plugins = append(o.plugins, p)
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
	plugins := o.plugins
	o.mu.Unlock()

	if callback != nil {
		callback(state)
	}

	for _, p := range plugins {
		_ = p.OnStateChange(context.Background(), state)
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

// SetClient sets the Ollama client for the orchestrator
func (o *Orchestrator) SetClient(client *ollama.Client) {
	o.mu.Lock()
	defer o.mu.Unlock()
	o.ollamaClient = client
	o.planner = planner.NewPreOrchestrationPlanner(client, "")
}

// DefaultSelectSchedule selects the next schedule using the orchestrator model.
// It builds a prompt containing the session history and the initial prompt,
// then parses the model's response to determine the next schedule.
func (o *Orchestrator) DefaultSelectSchedule(ctx context.Context) (ScheduleID, error) {
	o.mu.Lock()
	client := o.ollamaClient
	prompt := o.prompt
	history := o.scheduleHistory
	counts := o.scheduleCounts
	o.mu.Unlock()

	if client == nil {
		return o.heuristicSelectSchedule(), nil
	}

	// Build history string
	historyStr := "None"
	if len(history) > 0 {
		var h []string
		for _, id := range history {
			h = append(h, ScheduleNames[id])
		}
		historyStr = strings.Join(h, " -> ")
	}

	// Build counts string
	var c []string
	for id := ScheduleKnowledge; id <= ScheduleProduction; id++ {
		c = append(c, fmt.Sprintf("%s: %d", ScheduleNames[id], counts[id]))
	}
	countsStr := strings.Join(c, ", ")

	systemPrompt := `You are the orchestrator for obot. Select the next schedule based on history and intent.
Valid schedules:
1: Knowledge (Research, Crawl, Retrieve) - For gathering information.
2: Plan (Brainstorm, Clarify, Plan) - For designing solutions.
3: Implement (Implement, Verify, Feedback) - For executing code.
4: Scale (Scale, Benchmark, Optimize) - For performance tuning.
5: Production (Analyze, Systemize, Harmonize) - For final polish and consistency.

Rules:
- You must run all 5 schedules at least once before terminating.
- The last schedule MUST be Production.
- Respond ONLY with the schedule number (1-5) or 0 to terminate prompt.`

	userPrompt := fmt.Sprintf(`Initial Prompt: %s
Schedule History: %s
Schedule Counts: %s

Next Schedule (1-5, or 0 to terminate):`, prompt, historyStr, countsStr)

	resp, _, err := client.Generate(ctx, systemPrompt+"\n\n"+userPrompt)
	if err != nil {
		return 0, fmt.Errorf("llm generation failed: %w", err)
	}

	// Parse response
	resp = strings.TrimSpace(resp)
	if resp == "0" {
		if o.CanTerminatePrompt() {
			return 0, nil
		}
		// Force Production if they try to terminate early
		return ScheduleProduction, nil
	}

	var selected ScheduleID
	_, err = fmt.Sscanf(resp, "%d", &selected)
	if err != nil || selected < ScheduleKnowledge || selected > ScheduleProduction {
		// Fallback to heuristic if parsing fails
		return o.heuristicSelectSchedule(), nil
	}

	return selected, nil
}

// DefaultSelectProcess selects the next process within a schedule using the model.
func (o *Orchestrator) DefaultSelectProcess(ctx context.Context, scheduleID ScheduleID, lastProcess ProcessID) (ProcessID, bool, error) {
	o.mu.Lock()
	client := o.ollamaClient
	counts := o.processCounts[scheduleID]
	o.mu.Unlock()

	if client == nil {
		p, t := o.heuristicSelectProcess(scheduleID, lastProcess)
		return p, t, nil
	}

	// Get valid options
	var options []string
	rule := NavigationRules[lastProcess]
	for _, next := range rule.AllowedTo {
		options = append(options, fmt.Sprintf("%d: %s", next, ProcessNames[scheduleID][next]))
	}
	if rule.CanTerminate {
		options = append(options, "0: Terminate schedule")
	}
	optionsStr := strings.Join(options, "\n")

	// Build counts string
	var c []string
	for pID := Process1; pID <= Process3; pID++ {
		c = append(c, fmt.Sprintf("P%d: %d", pID, counts[pID]))
	}
	countsStr := strings.Join(c, ", ")

	systemPrompt := fmt.Sprintf(`You are the orchestrator for obot. Select the next process for the %s schedule.
Valid options from current state (P%d):
%s

Rules:
- You must complete P3 to terminate the schedule.
- Respond ONLY with the process number (1-3) or 0 to terminate.`, ScheduleNames[scheduleID], lastProcess, optionsStr)

	userPrompt := fmt.Sprintf(`Schedule: %s
Last Process: P%d
Process Counts in this Schedule: %s

Next Process (1-3, or 0 to terminate):`, ScheduleNames[scheduleID], lastProcess, countsStr)

	resp, _, err := client.Generate(ctx, systemPrompt+"\n\n"+userPrompt)
	if err != nil {
		return 0, false, fmt.Errorf("llm generation failed: %w", err)
	}

	// Parse response
	resp = strings.TrimSpace(resp)
	if resp == "0" {
		if rule.CanTerminate {
			return 0, true, nil
		}
		// Fallback to P3 if they try to terminate early
		return Process3, false, nil
	}

	var selected ProcessID
	_, err = fmt.Sscanf(resp, "%d", &selected)
	if err != nil || !IsValidNavigation(lastProcess, selected) {
		p, t := o.heuristicSelectProcess(scheduleID, lastProcess)
		return p, t, nil
	}

	return selected, false, nil
}

// heuristicSelectProcess provides a simple fallback for process selection
func (o *Orchestrator) heuristicSelectProcess(scheduleID ScheduleID, lastProcess ProcessID) (ProcessID, bool) {
	o.mu.Lock()
	defer o.mu.Unlock()

	// Simple linear progression: P1 -> P2 -> P3 -> Terminate
	switch lastProcess {
	case 0:
		return Process1, false
	case Process1:
		return Process2, false
	case Process2:
		return Process3, false
	case Process3:
		return 0, true
	default:
		return Process1, false
	}
}

// heuristicSelectSchedule provides a simple fallback for schedule selection
func (o *Orchestrator) heuristicSelectSchedule() ScheduleID {
	o.mu.Lock()
	defer o.mu.Unlock()

	// Ensure all run at least once
	for id := ScheduleKnowledge; id <= ScheduleProduction; id++ {
		if o.scheduleCounts[id] == 0 {
			return id
		}
	}

	// Default to Production if we're done with first pass
	return ScheduleProduction
}

// SelectSchedule selects the next schedule to execute
// This is called by the orchestrator model to make scheduling decisions
func (o *Orchestrator) SelectSchedule(scheduleID ScheduleID) error {
	if err := o.ValidateScheduleSelection(scheduleID); err != nil {
		return err
	}

	o.mu.Lock()

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

	plugins := o.plugins
	onScheduleStart := o.onScheduleStart
	o.mu.Unlock()

	for _, p := range plugins {
		_ = p.OnScheduleStart(context.Background(), scheduleID)
	}

	if onScheduleStart != nil {
		go onScheduleStart(scheduleID)
	}

	return nil
}

// SelectProcess selects the next process to execute within the current schedule
// Enforces strict 1↔2↔3 navigation rules
func (o *Orchestrator) SelectProcess(processID ProcessID) error {
	o.mu.Lock()

	if o.currentSchedule == nil {
		o.mu.Unlock()
		return fmt.Errorf("no schedule selected")
	}

	if processID < Process1 || processID > Process3 {
		o.mu.Unlock()
		return fmt.Errorf("invalid process ID: %d", processID)
	}

	// Validate navigation
	lastProcess := o.lastProcessBySchedule[o.currentSchedule.ID]
	if !IsValidNavigation(lastProcess, processID) {
		scheduleID := o.currentSchedule.ID
		o.mu.Unlock()
		return &NavigationError{
			From:     lastProcess,
			To:       processID,
			Schedule: scheduleID,
		}
	}

	scheduleID := o.currentSchedule.ID

	// Set current process
	process := &o.currentSchedule.Processes[processID-1]
	process.StartTime = time.Now()
	o.currentProcess = process

	// Update tracking
	o.processCounts[scheduleID][processID]++
	o.stats.TotalProcesses++
	o.stats.ProcessesBySchedule[scheduleID][processID]++

	// Update flow code
	o.flowCode.AddProcess(processID)

	plugins := o.plugins
	onProcessStart := o.onProcessStart
	o.mu.Unlock()

	for _, p := range plugins {
		_ = p.OnProcessStart(context.Background(), scheduleID, processID)
	}

	if onProcessStart != nil {
		go onProcessStart(scheduleID, processID)
	}

	return nil
}

// selectScheduleLLM selects the next schedule using the LLM.
func (o *Orchestrator) selectScheduleLLM(ctx context.Context) (ScheduleID, error) {
	o.mu.Lock()
	history := o.scheduleHistory
	flow := o.flowCode.String()
	prompt := o.prompt
	client := o.ollamaClient
	o.mu.Unlock()

	if client == nil {
		return 0, fmt.Errorf("ollama client not initialized")
	}

	fullPrompt := fmt.Sprintf(scheduleSelectionSystemPrompt, history, flow, prompt)

	resp, _, err := client.Generate(ctx, fullPrompt)
	if err != nil {
		return 0, fmt.Errorf("failed to generate schedule selection: %w", err)
	}

	resp = strings.TrimSpace(resp)
	if resp == "0" || strings.ToUpper(resp) == "TERMINATE" {
		return 0, nil
	}

	var id int
	// Try to find the first digit in the response
	for _, c := range resp {
		if c >= '0' && c <= '5' {
			id = int(c - '0')
			break
		}
	}

	return ScheduleID(id), nil
}

// selectProcessLLM selects the next process using the LLM.
func (o *Orchestrator) selectProcessLLM(ctx context.Context, scheduleID ScheduleID, lastProcess ProcessID) (ProcessID, bool, error) {
	o.mu.Lock()
	flow := o.flowCode.String()
	client := o.ollamaClient
	o.mu.Unlock()

	if client == nil {
		return 0, false, fmt.Errorf("ollama client not initialized")
	}

	scheduleName := ScheduleNames[scheduleID]
	fullPrompt := fmt.Sprintf(processSelectionSystemPrompt, scheduleName, lastProcess, flow)

	resp, _, err := client.Generate(ctx, fullPrompt)
	if err != nil {
		return 0, false, fmt.Errorf("failed to generate process selection: %w", err)
	}

	resp = strings.TrimSpace(resp)
	if resp == "0" || strings.ToUpper(resp) == "TERMINATE" {
		return 0, true, nil
	}

	var id int
	for _, c := range resp {
		if c >= '1' && c <= '3' {
			id = int(c - '0')
			break
		}
	}

	if id == 0 {
		return 0, true, nil
	}

	return ProcessID(id), false, nil
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

	if o.currentProcess == nil {
		o.mu.Unlock()
		return fmt.Errorf("no process to terminate")
	}

	scheduleID := o.currentSchedule.ID
	processID := o.currentProcess.ID

	o.currentProcess.Terminated = true
	o.lastProcessBySchedule[scheduleID] = processID

	plugins := o.plugins
	onProcessEnd := o.onProcessEnd
	o.mu.Unlock()

	for _, p := range plugins {
		_ = p.OnProcessEnd(context.Background(), scheduleID, processID)
	}

	if onProcessEnd != nil {
		go onProcessEnd(scheduleID, processID)
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

	if o.currentSchedule == nil {
		o.mu.Unlock()
		return fmt.Errorf("no schedule to terminate")
	}

	scheduleID := o.currentSchedule.ID

	lastProcess := o.lastProcessBySchedule[scheduleID]
	if lastProcess != Process3 {
		o.mu.Unlock()
		return fmt.Errorf("cannot terminate schedule: last process was P%d, must be P3", lastProcess)
	}

	o.currentSchedule.Terminated = true
	o.currentSchedule.EndTime = time.Now()

	plugins := o.plugins
	onScheduleEnd := o.onScheduleEnd

	o.currentSchedule = nil
	o.currentProcess = nil
	o.mu.Unlock()

	for _, p := range plugins {
		_ = p.OnScheduleEnd(context.Background(), scheduleID)
	}

	if onScheduleEnd != nil {
		go onScheduleEnd(scheduleID)
	}

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

// GetTerminationContext returns all context needed for the LLM to decide on termination.
func (o *Orchestrator) GetTerminationContext() map[string]interface{} {
	o.mu.Lock()
	defer o.mu.Unlock()

	return map[string]interface{}{
		"history": map[string]interface{}{
			"schedules": o.scheduleHistory,
			"processes": o.processHistory,
			"counts":    o.scheduleCounts,
		},
		"stats": o.stats,
		"notes": o.sessionNotes,
		"flow":  o.flowCode.String(),
		"can_terminate": o.CanTerminatePrompt(),
	}
}

// GetScheduleSelectionContext returns context for the LLM to select the next schedule.
func (o *Orchestrator) GetScheduleSelectionContext() map[string]interface{} {
	o.mu.Lock()
	defer o.mu.Unlock()

	return map[string]interface{}{
		"prompt":    o.prompt,
		"history":   o.scheduleHistory,
		"counts":    o.scheduleCounts,
		"notes":     o.sessionNotes,
		"available": []ScheduleID{1, 2, 3, 4, 5},
	}
}

// ValidateScheduleSelection validates a schedule selection against history and rules.
func (o *Orchestrator) ValidateScheduleSelection(id ScheduleID) error {
	o.mu.Lock()
	defer o.mu.Unlock()

	if id < ScheduleKnowledge || id > ScheduleProduction {
		return fmt.Errorf("invalid schedule ID: %d", id)
	}

	// Example rule: Don't jump back too far if implementation is advanced?
	// For now, any schedule is valid as long as it's within range.
	
	return nil
}

// MarkError marks an error in the flow code
func (o *Orchestrator) MarkError() {
	o.mu.Lock()
	o.flowCode.MarkError()
	plugins := o.plugins
	onError := o.onError
	o.mu.Unlock()

	err := fmt.Errorf("orchestration error")
	for _, p := range plugins {
		p.OnError(context.Background(), err)
	}
	if onError != nil {
		onError(err)
	}
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

	// Run pre-orchestration planning
	if o.planner != nil && o.prompt != "" {
		plan, err := o.planner.Plan(ctx, o.prompt)
		if err == nil {
			// Feed subtasks into session notes for Knowledge/Plan schedules to use
			for i, st := range plan.Sequence {
				risk := plan.Risks[i]
				o.AddNote(fmt.Sprintf("Subtask [%s] (Risk: %s): %s", st.ID, risk, st.Description), "planner")
			}
		}
	}

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
