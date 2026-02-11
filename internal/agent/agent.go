// Package agent implements the agent executor for obot orchestration.
package agent

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/croberts/obot/internal/model"
	"github.com/croberts/obot/internal/ollama"
	"github.com/croberts/obot/internal/orchestrate"
)

// Agent executes processes and performs file operations.
// The agent is an EXECUTOR ONLY - it cannot make orchestration decisions.
type Agent struct {
	mu sync.Mutex

	// Multi-model coordination
	models       *model.Coordinator
	currentModel orchestrate.ModelType

	// Context tracking
	currentSchedule orchestrate.ScheduleID
	currentProcess  orchestrate.ProcessID

	// Action tracking
	actions  []Action
	tracker  *ActionStats
	recorder *Recorder

	// Session context
	sessionCtx   context.Context
	sessionNotes []orchestrate.Note

	// Callbacks
	onAction   func(Action)
	onComplete func()

	// Execution state
	executing bool
	stopCh    chan struct{}

	// Plugins
	plugins []Plugin
}

// NewAgent creates a new agent with model coordination and tracking.
func NewAgent(models *model.Coordinator) *Agent {
	return &Agent{
		models:   models,
		actions:  make([]Action, 0),
		tracker:  &ActionStats{},
		recorder: NewRecorder(),
		stopCh:   make(chan struct{}),
		plugins:  make([]Plugin, 0),
	}
}

// RegisterPlugin registers a plugin with the agent.
func (a *Agent) RegisterPlugin(p Plugin) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.plugins = append(a.plugins, p)
}

// SetContext sets the current schedule and process context
func (a *Agent) SetContext(schedule orchestrate.ScheduleID, process orchestrate.ProcessID) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.currentSchedule = schedule
	a.currentProcess = process
}

// SetActionCallback sets the callback for when an action is performed
func (a *Agent) SetActionCallback(callback func(Action)) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.onAction = callback
}

// SetCompleteCallback sets the callback for when execution is complete
func (a *Agent) SetCompleteCallback(callback func()) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.onComplete = callback
}

// Execute selects the model and executes the process logic.
func (a *Agent) Execute(ctx context.Context, schedule orchestrate.ScheduleID, process orchestrate.ProcessID, prompt string) error {
	a.mu.Lock()
	a.sessionCtx = ctx
	a.executing = true
	a.currentSchedule = schedule
	a.currentProcess = process
	plugins := a.plugins
	a.mu.Unlock()

	// Call OnBeforeExecute hooks
	for _, p := range plugins {
		if err := p.OnBeforeExecute(ctx, schedule.String(), process.String()); err != nil {
			a.mu.Lock()
			a.executing = false
			a.mu.Unlock()
			return fmt.Errorf("plugin %s failed before execution: %w", p.Name(), err)
		}
	}

	var execErr error
	defer func() {
		a.mu.Lock()
		a.executing = false
		a.mu.Unlock()

		// Call OnAfterExecute hooks
		for _, p := range plugins {
			_ = p.OnAfterExecute(ctx, schedule.String(), process.String(), execErr)
		}
	}()

	// Select model based on schedule/process
	a.currentModel = a.selectModel(schedule, process)

	client := a.models.Get(a.currentModel)
	if client == nil {
		return fmt.Errorf("no client found for model type %v", a.currentModel)
	}

	return a.executeWithModel(ctx, client, prompt)
}

// selectModel determines which model to use.
func (a *Agent) selectModel(schedule orchestrate.ScheduleID, process orchestrate.ProcessID) orchestrate.ModelType {
	if schedule == orchestrate.ScheduleKnowledge {
		return orchestrate.ModelResearcher
	}
	// For Production Harmonize (P3), we use the Coder model, 
	// but vision capabilities may be used separately by the tools.
	return orchestrate.ModelCoder
}

// executeWithModel streams model response and executes actions.
func (a *Agent) executeWithModel(ctx context.Context, client *ollama.Client, prompt string) error {
	// Build full system prompt with allowed actions
	systemPrompt := a.agentSystemPrompt()

	// Stream and parse actions
	resp, _, err := client.Generate(ctx, systemPrompt+"\n\n"+prompt)
	if err != nil {
		return err
	}

	// Simple completion check for now
	if strings.Contains(resp, "COMPLETE") {
		a.mu.Lock()
		callback := a.onComplete
		a.mu.Unlock()
		if callback != nil {
			callback()
		}
	}

	return nil
}

// agentSystemPrompt returns the system prompt for the agent.
func (a *Agent) agentSystemPrompt() string {
	return `You are the OllamaBot Agent. Your mission is to execute the current process by performing file and system operations.

ALLOWED ACTIONS:
1. createFile(path, content)
2. deleteFile(path)
3. createDir(path)
4. deleteDir(path)
5. renameFile(oldPath, newPath)
6. moveFile(oldPath, newPath)
7. renameDir(oldPath, newPath)
8. moveDir(oldPath, newPath)
9. copyFile(srcPath, dstPath)
10. copyDir(srcPath, dstPath)
11. runCommand(command)
12. editFile(path, edits)
13. delegate(content)
14. COMPLETE

RULES:
- You CANNOT select schedules or navigate between processes.
- You CANNOT terminate the prompt or make orchestration decisions.
- You MUST signal completion with 'COMPLETE' when finished.
- You MUST follow the .obotrules and project conventions.`
}

// recordAction records an action and triggers callbacks
func (a *Agent) recordAction(action Action) {
	a.mu.Lock()
	if action.ID == "" {
		action.ID = fmt.Sprintf("A%05d", len(a.actions)+1)
	}
	if action.Timestamp.IsZero() {
		action.Timestamp = time.Now()
	}
	a.actions = append(a.actions, action)
	a.tracker.IncrementByType(action.Type)
	a.recorder.Record(action)
	callback := a.onAction
	a.mu.Unlock()

	if callback != nil {
		callback(action)
	}
}

// CreateFile creates a file with the given content
func (a *Agent) CreateFile(ctx context.Context, path string, content string) error {
	action := Action{
		Type:    ActionCreateFile,
		Path:    path,
		Content: content,
	}
	return a.executeAction(ctx, &action)
}

// DeleteFile deletes a file
func (a *Agent) DeleteFile(ctx context.Context, path string) error {
	action := Action{
		Type: ActionDeleteFile,
		Path: path,
	}
	return a.executeAction(ctx, &action)
}

// EditFile edits a file with the given edits
func (a *Agent) EditFile(ctx context.Context, path string, edits []Edit) error {
	ranges := computeLineRanges(edits)
	diff := ComputeDiffFromEdits(edits)
	action := Action{
		Type:       ActionEditFile,
		Path:       path,
		LineRanges: ranges,
		Diff:       diff,
	}
	return a.executeAction(ctx, &action)
}

// RenameFile renames a file
func (a *Agent) RenameFile(ctx context.Context, oldPath, newPath string) error {
	action := Action{
		Type:    ActionRenameFile,
		Path:    oldPath,
		NewPath: newPath,
	}
	return a.executeAction(ctx, &action)
}

// MoveFile moves a file
func (a *Agent) MoveFile(ctx context.Context, oldPath, newPath string) error {
	action := Action{
		Type:    ActionMoveFile,
		Path:    oldPath,
		NewPath: newPath,
	}
	return a.executeAction(ctx, &action)
}

// CopyFile copies a file
func (a *Agent) CopyFile(ctx context.Context, srcPath, dstPath string) error {
	action := Action{
		Type:    ActionCopyFile,
		Path:    srcPath,
		NewPath: dstPath,
	}
	return a.executeAction(ctx, &action)
}

// CreateDir creates a directory
func (a *Agent) CreateDir(ctx context.Context, path string) error {
	action := Action{
		Type: ActionCreateDir,
		Path: path,
	}
	return a.executeAction(ctx, &action)
}

// DeleteDir deletes a directory
func (a *Agent) DeleteDir(ctx context.Context, path string) error {
	action := Action{
		Type: ActionDeleteDir,
		Path: path,
	}
	return a.executeAction(ctx, &action)
}

// RenameDir renames a directory
func (a *Agent) RenameDir(ctx context.Context, oldPath, newPath string) error {
	action := Action{
		Type:    ActionRenameDir,
		Path:    oldPath,
		NewPath: newPath,
	}
	return a.executeAction(ctx, &action)
}

// MoveDir moves a directory
func (a *Agent) MoveDir(ctx context.Context, oldPath, newPath string) error {
	action := Action{
		Type:    ActionMoveDir,
		Path:    oldPath,
		NewPath: newPath,
	}
	return a.executeAction(ctx, &action)
}

// CopyDir copies a directory
func (a *Agent) CopyDir(ctx context.Context, srcPath, dstPath string) error {
	action := Action{
		Type:    ActionCopyDir,
		Path:    srcPath,
		NewPath: dstPath,
	}
	return a.executeAction(ctx, &action)
}

// RunCommand runs a command
func (a *Agent) RunCommand(ctx context.Context, command string) (int, string, error) {
	action := Action{
		Type:    ActionRunCommand,
		Command: command,
	}
	err := a.executeAction(ctx, &action)
	return action.ExitCode, action.Output, err
}

// CompleteProcess marks the current process as completed
func (a *Agent) CompleteProcess(processName string) {
	action := Action{
		Type:        ActionProcessCompleted,
		ProcessName: processName,
	}
	_ = a.executeAction(context.Background(), &action)
}

// GetActions returns all recorded actions
func (a *Agent) GetActions() []Action {
	a.mu.Lock()
	defer a.mu.Unlock()
	result := make([]Action, len(a.actions))
	copy(result, a.actions)
	return result
}

// GetStats returns the action statistics
func (a *Agent) GetStats() *ActionStats {
	a.mu.Lock()
	defer a.mu.Unlock()
	stats := *a.tracker
	return &stats
}

// GetRecorder returns the recorder
func (a *Agent) GetRecorder() *Recorder {
	return a.recorder
}

// Stop stops the agent execution safely (idempotent via sync.Once pattern).
func (a *Agent) Stop() {
	a.mu.Lock()
	if a.executing {
		select {
		case <-a.stopCh:
			// Already closed
		default:
			close(a.stopCh)
		}
		a.executing = false
	}
	a.mu.Unlock()
}

// Reset resets the agent state
func (a *Agent) Reset() {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.actions = make([]Action, 0)
	a.tracker = &ActionStats{}
	a.recorder = NewRecorder()
	a.stopCh = make(chan struct{})
	a.executing = false
}
