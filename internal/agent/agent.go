// Package agent implements the agent executor for obot orchestration.
package agent

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/croberts/obot/internal/ollama"
	"github.com/croberts/obot/internal/orchestrate"
)

// Agent executes processes and performs file operations.
// The agent is an EXECUTOR ONLY - it cannot make orchestration decisions.
type Agent struct {
	mu sync.Mutex

	// Ollama client
	client *ollama.Client

	// Action tracking
	actions   []Action
	stats     *ActionStats
	recorder  *Recorder

	// Current context
	currentSchedule orchestrate.ScheduleID
	currentProcess  orchestrate.ProcessID

	// Callbacks
	onAction func(Action)

	// Execution state
	executing bool
	stopCh    chan struct{}
}

// NewAgent creates a new agent with an Ollama client
func NewAgent(client *ollama.Client) *Agent {
	return &Agent{
		client:   client,
		actions:  make([]Action, 0),
		stats:    &ActionStats{},
		recorder: NewRecorder(),
		stopCh:   make(chan struct{}),
	}
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

// recordAction records an action and triggers callbacks
func (a *Agent) recordAction(action Action) {
	a.mu.Lock()
	action.ID = fmt.Sprintf("A%05d", len(a.actions)+1)
	action.Timestamp = time.Now()
	a.actions = append(a.actions, action)
	a.stats.IncrementByType(action.Type)
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

	// Actual file creation would happen here
	// For now, we just record the action
	a.recordAction(action)
	return nil
}

// DeleteFile deletes a file
func (a *Agent) DeleteFile(ctx context.Context, path string) error {
	action := Action{
		Type: ActionDeleteFile,
		Path: path,
	}

	a.recordAction(action)
	return nil
}

// EditFile edits a file with the given edits
func (a *Agent) EditFile(ctx context.Context, path string, edits []Edit) error {
	// Compute line ranges using max overlap algorithm
	ranges := computeLineRanges(edits)

	// Compute diff summary
	diff := computeDiff(edits)

	action := Action{
		Type:       ActionEditFile,
		Path:       path,
		LineRanges: ranges,
		Diff:       diff,
	}

	a.recordAction(action)
	return nil
}

// RenameFile renames a file
func (a *Agent) RenameFile(ctx context.Context, oldPath, newPath string) error {
	action := Action{
		Type:    ActionRenameFile,
		Path:    oldPath,
		NewPath: newPath,
	}

	a.recordAction(action)
	return nil
}

// MoveFile moves a file
func (a *Agent) MoveFile(ctx context.Context, oldPath, newPath string) error {
	action := Action{
		Type:    ActionMoveFile,
		Path:    oldPath,
		NewPath: newPath,
	}

	a.recordAction(action)
	return nil
}

// CopyFile copies a file
func (a *Agent) CopyFile(ctx context.Context, srcPath, dstPath string) error {
	action := Action{
		Type:    ActionCopyFile,
		Path:    srcPath,
		NewPath: dstPath,
	}

	a.recordAction(action)
	return nil
}

// CreateDir creates a directory
func (a *Agent) CreateDir(ctx context.Context, path string) error {
	action := Action{
		Type: ActionCreateDir,
		Path: path,
	}

	a.recordAction(action)
	return nil
}

// DeleteDir deletes a directory
func (a *Agent) DeleteDir(ctx context.Context, path string) error {
	action := Action{
		Type: ActionDeleteDir,
		Path: path,
	}

	a.recordAction(action)
	return nil
}

// RenameDir renames a directory
func (a *Agent) RenameDir(ctx context.Context, oldPath, newPath string) error {
	action := Action{
		Type:    ActionRenameDir,
		Path:    oldPath,
		NewPath: newPath,
	}

	a.recordAction(action)
	return nil
}

// MoveDir moves a directory
func (a *Agent) MoveDir(ctx context.Context, oldPath, newPath string) error {
	action := Action{
		Type:    ActionMoveDir,
		Path:    oldPath,
		NewPath: newPath,
	}

	a.recordAction(action)
	return nil
}

// CopyDir copies a directory
func (a *Agent) CopyDir(ctx context.Context, srcPath, dstPath string) error {
	action := Action{
		Type:    ActionCopyDir,
		Path:    srcPath,
		NewPath: dstPath,
	}

	a.recordAction(action)
	return nil
}

// RunCommand runs a command
func (a *Agent) RunCommand(ctx context.Context, command string) (int, string, error) {
	action := Action{
		Type:     ActionRunCommand,
		Command:  command,
		ExitCode: 0, // Would be set by actual execution
		Output:   "", // Would be set by actual execution
	}

	a.recordAction(action)
	return action.ExitCode, action.Output, nil
}

// CompleteProcess marks the current process as completed
func (a *Agent) CompleteProcess(processName string) {
	action := Action{
		Type:        ActionProcessCompleted,
		ProcessName: processName,
	}

	a.recordAction(action)
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

	// Return a copy
	stats := *a.stats
	return &stats
}

// GetRecorder returns the recorder
func (a *Agent) GetRecorder() *Recorder {
	return a.recorder
}

// Stop stops the agent execution
func (a *Agent) Stop() {
	a.mu.Lock()
	if a.executing {
		close(a.stopCh)
		a.executing = false
	}
	a.mu.Unlock()
}

// Reset resets the agent state
func (a *Agent) Reset() {
	a.mu.Lock()
	defer a.mu.Unlock()

	a.actions = make([]Action, 0)
	a.stats = &ActionStats{}
	a.recorder = NewRecorder()
	a.stopCh = make(chan struct{})
	a.executing = false
}

// Edit represents a file edit operation
type Edit struct {
	StartLine int
	EndLine   int
	OldContent string
	NewContent string
}

// computeLineRanges computes merged line ranges using max overlap algorithm
func computeLineRanges(edits []Edit) []LineRange {
	if len(edits) == 0 {
		return nil
	}

	// Sort edits by start line
	sorted := make([]Edit, len(edits))
	copy(sorted, edits)
	for i := 0; i < len(sorted)-1; i++ {
		for j := i + 1; j < len(sorted); j++ {
			if sorted[j].StartLine < sorted[i].StartLine {
				sorted[i], sorted[j] = sorted[j], sorted[i]
			}
		}
	}

	// Merge overlapping ranges
	ranges := make([]LineRange, 0)
	current := LineRange{Start: sorted[0].StartLine, End: sorted[0].EndLine}

	for i := 1; i < len(sorted); i++ {
		edit := sorted[i]
		if edit.StartLine <= current.End+1 {
			// Merge
			if edit.EndLine > current.End {
				current.End = edit.EndLine
			}
		} else {
			// New range
			ranges = append(ranges, current)
			current = LineRange{Start: edit.StartLine, End: edit.EndLine}
		}
	}
	ranges = append(ranges, current)

	return ranges
}

// computeDiff computes a diff summary from edits
func computeDiff(edits []Edit) *DiffSummary {
	summary := &DiffSummary{
		Additions: make([]DiffLine, 0),
		Deletions: make([]DiffLine, 0),
		Context:   make([]DiffLine, 0),
	}

	for _, edit := range edits {
		// Count deletions (old content lines)
		if edit.OldContent != "" {
			lines := splitLines(edit.OldContent)
			for i, line := range lines {
				summary.Deletions = append(summary.Deletions, DiffLine{
					LineNumber: edit.StartLine + i,
					Content:    line,
					Type:       DiffLineDelete,
				})
			}
			summary.TotalRemoved += len(lines)
		}

		// Count additions (new content lines)
		if edit.NewContent != "" {
			lines := splitLines(edit.NewContent)
			for i, line := range lines {
				summary.Additions = append(summary.Additions, DiffLine{
					LineNumber: edit.StartLine + i,
					Content:    line,
					Type:       DiffLineAdd,
				})
			}
			summary.TotalAdded += len(lines)
		}
	}

	return summary
}

// splitLines splits a string into lines
func splitLines(s string) []string {
	if s == "" {
		return nil
	}

	lines := make([]string, 0)
	start := 0
	for i := 0; i < len(s); i++ {
		if s[i] == '\n' {
			lines = append(lines, s[start:i])
			start = i + 1
		}
	}
	if start < len(s) {
		lines = append(lines, s[start:])
	}
	return lines
}
