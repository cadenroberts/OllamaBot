// Package agent implements the agent executor for obot orchestration.
package agent

import (
	"fmt"
	"strings"
	"sync"
	"time"
)

// Recorder records all agent actions with timestamps and diff information.
type Recorder struct {
	mu sync.Mutex

	actions       []Action
	edits         map[string][]Action // Actions by file path
	commands      []Action
	fileCreates   []Action
	fileDeletes   []Action
	dirOperations []Action
	delegations   []Action

	startTime time.Time
}

// NewRecorder creates a new recorder
func NewRecorder() *Recorder {
	return &Recorder{
		actions:       make([]Action, 0),
		edits:         make(map[string][]Action),
		commands:      make([]Action, 0),
		fileCreates:   make([]Action, 0),
		fileDeletes:   make([]Action, 0),
		dirOperations: make([]Action, 0),
		delegations:   make([]Action, 0),
		startTime:     time.Now(),
	}
}

// Record records an action
func (r *Recorder) Record(action Action) {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.actions = append(r.actions, action)

	switch action.Type {
	case ActionEditFile:
		r.edits[action.Path] = append(r.edits[action.Path], action)
	case ActionRunCommand:
		r.commands = append(r.commands, action)
	case ActionCreateFile:
		r.fileCreates = append(r.fileCreates, action)
	case ActionDeleteFile:
		r.fileDeletes = append(r.fileDeletes, action)
	case ActionCreateDir, ActionDeleteDir, ActionRenameDir, ActionMoveDir, ActionCopyDir:
		r.dirOperations = append(r.dirOperations, action)
	case ActionDelegate:
		r.delegations = append(r.delegations, action)
	}
}

// GetAllActions returns all recorded actions
func (r *Recorder) GetAllActions() []Action {
	r.mu.Lock()
	defer r.mu.Unlock()

	result := make([]Action, len(r.actions))
	copy(result, r.actions)
	return result
}

// GetEditsByFile returns edits grouped by file
func (r *Recorder) GetEditsByFile() map[string][]Action {
	r.mu.Lock()
	defer r.mu.Unlock()

	result := make(map[string][]Action)
	for path, edits := range r.edits {
		result[path] = make([]Action, len(edits))
		copy(result[path], edits)
	}
	return result
}

// GetCommands returns all command actions
func (r *Recorder) GetCommands() []Action {
	r.mu.Lock()
	defer r.mu.Unlock()

	result := make([]Action, len(r.commands))
	copy(result, r.commands)
	return result
}

// GetDuration returns the recording duration
func (r *Recorder) GetDuration() time.Duration {
	r.mu.Lock()
	defer r.mu.Unlock()
	return time.Since(r.startTime)
}

// GenerateActionLog generates a formatted action log
func (r *Recorder) GenerateActionLog() string {
	r.mu.Lock()
	defer r.mu.Unlock()

	var sb strings.Builder
	sb.WriteString("# Action Log\n")
	sb.WriteString("# Generated: " + time.Now().Format(time.RFC3339) + "\n")
	sb.WriteString("# Duration: " + time.Since(r.startTime).String() + "\n")
	sb.WriteString("#\n")
	sb.WriteString(fmt.Sprintf("# Total actions: %d\n\n", len(r.actions)))

	for _, action := range r.actions {
		sb.WriteString(fmt.Sprintf("[%s] %s\n",
			action.Timestamp.Format("15:04:05.000"),
			action.ActionOutput()))

		// Include diff for edits
		if action.Type == ActionEditFile && action.Diff != nil {
			sb.WriteString(formatDiffForLog(action.Diff))
		}
	}

	return sb.String()
}

// formatDiffForLog formats a diff summary for the action log
func formatDiffForLog(diff *DiffSummary) string {
	var sb strings.Builder

	for _, line := range diff.Deletions {
		sb.WriteString(fmt.Sprintf("  -  %4d │ %s\n", line.LineNumber, line.Content))
	}
	for _, line := range diff.Additions {
		sb.WriteString(fmt.Sprintf("  +  %4d │ %s\n", line.LineNumber, line.Content))
	}

	return sb.String()
}

// GenerateEditDetails generates detailed edit information for the summary
func (r *Recorder) GenerateEditDetails() []EditDetail {
	r.mu.Lock()
	defer r.mu.Unlock()

	details := make([]EditDetail, 0)

	for path, edits := range r.edits {
		// Merge all line ranges for this file
		allRanges := make([]LineRange, 0)
		var combinedDiff *DiffSummary

		for _, edit := range edits {
			allRanges = append(allRanges, edit.LineRanges...)
			if combinedDiff == nil {
				combinedDiff = &DiffSummary{
					Additions: make([]DiffLine, 0),
					Deletions: make([]DiffLine, 0),
				}
			}
			if edit.Diff != nil {
				combinedDiff.Additions = append(combinedDiff.Additions, edit.Diff.Additions...)
				combinedDiff.Deletions = append(combinedDiff.Deletions, edit.Diff.Deletions...)
				combinedDiff.TotalAdded += edit.Diff.TotalAdded
				combinedDiff.TotalRemoved += edit.Diff.TotalRemoved
			}
		}

		// Merge overlapping ranges
		mergedRanges := mergeLineRanges(allRanges)

		details = append(details, EditDetail{
			Path:       path,
			LineRanges: mergedRanges,
			Diff:       combinedDiff,
			EditCount:  len(edits),
		})
	}

	return details
}

// EditDetail contains detailed information about edits to a file
type EditDetail struct {
	Path       string
	LineRanges []LineRange
	Diff       *DiffSummary
	EditCount  int
}

// mergeLineRanges merges overlapping or adjacent line ranges
func mergeLineRanges(ranges []LineRange) []LineRange {
	if len(ranges) == 0 {
		return nil
	}

	// Sort by start line
	sorted := make([]LineRange, len(ranges))
	copy(sorted, ranges)
	for i := 0; i < len(sorted)-1; i++ {
		for j := i + 1; j < len(sorted); j++ {
			if sorted[j].Start < sorted[i].Start {
				sorted[i], sorted[j] = sorted[j], sorted[i]
			}
		}
	}

	// Merge
	merged := make([]LineRange, 0)
	current := sorted[0]

	for i := 1; i < len(sorted); i++ {
		r := sorted[i]
		if r.Start <= current.End+1 {
			// Overlapping or adjacent - merge
			if r.End > current.End {
				current.End = r.End
			}
		} else {
			// Gap - save current and start new
			merged = append(merged, current)
			current = r
		}
	}
	merged = append(merged, current)

	return merged
}

// GenerateDiff generates a unified diff string
func (r *Recorder) GenerateDiff(path string) string {
	r.mu.Lock()
	edits, ok := r.edits[path]
	r.mu.Unlock()

	if !ok || len(edits) == 0 {
		return ""
	}

	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("--- a/%s\n", path))
	sb.WriteString(fmt.Sprintf("+++ b/%s\n", path))

	for _, edit := range edits {
		if edit.Diff == nil {
			continue
		}

		// Simple unified diff format
		for _, line := range edit.Diff.Deletions {
			sb.WriteString(fmt.Sprintf("-%s\n", line.Content))
		}
		for _, line := range edit.Diff.Additions {
			sb.WriteString(fmt.Sprintf("+%s\n", line.Content))
		}
	}

	return sb.String()
}
