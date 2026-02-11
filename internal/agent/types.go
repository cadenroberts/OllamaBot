// Package agent implements the agent executor for obot orchestration.
// The agent is an EXECUTOR ONLY - it cannot make orchestration decisions.
package agent

import (
	"time"
)

// ActionType identifies the type of agent action
type ActionType string

const (
	// File operations
	ActionCreateFile ActionType = "create_file"
	ActionDeleteFile ActionType = "delete_file"
	ActionEditFile   ActionType = "edit_file"
	ActionRenameFile ActionType = "rename_file"
	ActionMoveFile   ActionType = "move_file"
	ActionCopyFile   ActionType = "copy_file"

	// Directory operations
	ActionCreateDir ActionType = "create_dir"
	ActionDeleteDir ActionType = "delete_dir"
	ActionRenameDir ActionType = "rename_dir"
	ActionMoveDir   ActionType = "move_dir"
	ActionCopyDir   ActionType = "copy_dir"

	// Command operations
	ActionRunCommand ActionType = "run_command"

	// Read/search operations (Tier 2)
	ActionReadFile    ActionType = "read_file"
	ActionSearchFiles ActionType = "search_files"
	ActionListDir     ActionType = "list_dir"

	// Delegation operations (Tier 2)
	ActionDelegate ActionType = "delegate"

	// Process completion
	ActionProcessCompleted ActionType = "process_completed"
)

// Action represents an agent action
type Action struct {
	ID        string
	Type      ActionType
	Timestamp time.Time

	// File/Directory operations
	Path       string
	NewPath    string
	Content    string

	// Edit operations
	LineRanges []LineRange
	Diff       *DiffSummary

	// Command operations
	Command    string
	ExitCode   int
	Output     string

	// Process completion
	ProcessName string
}

// LineRange represents a range of edited lines
type LineRange struct {
	Start int
	End   int
}

// DiffSummary contains formatted diff information
type DiffSummary struct {
	Additions  []DiffLine
	Deletions  []DiffLine
	Context    []DiffLine
	TotalAdded int
	TotalRemoved int
}

// DiffLine represents a single line in a diff
type DiffLine struct {
	LineNumber int
	Content    string
	Type       DiffLineType
}

// DiffLineType identifies the type of diff line
type DiffLineType string

const (
	DiffLineAdd     DiffLineType = "add"
	DiffLineDelete  DiffLineType = "delete"
	DiffLineContext DiffLineType = "context"
)

// ActionOutput returns the formatted output string for an action
func (a *Action) ActionOutput() string {
	switch a.Type {
	case ActionCreateFile:
		return "Agent • Created " + a.Path
	case ActionDeleteFile:
		return "Agent • Deleted " + a.Path
	case ActionEditFile:
		return "Agent • Edited " + a.Path + " at lines " + formatLineRanges(a.LineRanges)
	case ActionRenameFile:
		return "Agent • Renamed " + a.Path + " to " + a.NewPath
	case ActionMoveFile:
		return "Agent • Moved " + a.Path + " to " + a.NewPath
	case ActionCopyFile:
		return "Agent • Copied " + a.Path + " to " + a.NewPath
	case ActionCreateDir:
		return "Agent • Created " + a.Path
	case ActionDeleteDir:
		return "Agent • Deleted " + a.Path
	case ActionRenameDir:
		return "Agent • Renamed " + a.Path + " to " + a.NewPath
	case ActionMoveDir:
		return "Agent • Moved " + a.Path + " to " + a.NewPath
	case ActionCopyDir:
		return "Agent • Copied " + a.Path + " to " + a.NewPath
	case ActionRunCommand:
		return "Agent • Ran " + a.Command + " (exit " + formatExitCode(a.ExitCode) + ")"
	case ActionReadFile:
		return "Agent • Read " + a.Path
	case ActionSearchFiles:
		return "Agent • Searched: " + a.Content
	case ActionListDir:
		return "Agent • Listed " + a.Path
	case ActionDelegate:
		return "Agent • Delegated: " + a.Content
	case ActionProcessCompleted:
		return "Agent • " + a.ProcessName + " Completed"
	default:
		return "Agent • Unknown action"
	}
}

// formatLineRanges formats line ranges as "12-15, 40-45"
func formatLineRanges(ranges []LineRange) string {
	if len(ranges) == 0 {
		return ""
	}

	result := ""
	for i, r := range ranges {
		if i > 0 {
			result += ", "
		}
		if r.Start == r.End {
			result += formatInt(r.Start)
		} else {
			result += formatInt(r.Start) + "-" + formatInt(r.End)
		}
	}
	return result
}

// formatInt formats an integer as a string (simple implementation)
func formatInt(n int) string {
	if n == 0 {
		return "0"
	}

	negative := n < 0
	if negative {
		n = -n
	}

	digits := make([]byte, 0, 20)
	for n > 0 {
		digits = append([]byte{byte(n%10) + '0'}, digits...)
		n /= 10
	}

	if negative {
		return "-" + string(digits)
	}
	return string(digits)
}

// formatExitCode formats an exit code
func formatExitCode(code int) string {
	return formatInt(code)
}

// ActionStats tracks action statistics
type ActionStats struct {
	FilesCreated     int
	FilesDeleted     int
	FilesEdited      int
	FilesRenamed     int
	FilesMoved       int
	FilesCopied      int
	DirsCreated      int
	DirsDeleted      int
	DirsRenamed      int
	DirsMoved        int
	DirsCopied       int
	CommandsRan      int
	FilesRead        int
	FilesSearched    int
	DirsListed       int
	Delegations      int
	TotalActions     int
}

// IncrementByType increments the appropriate counter for an action type
func (s *ActionStats) IncrementByType(actionType ActionType) {
	s.TotalActions++
	switch actionType {
	case ActionCreateFile:
		s.FilesCreated++
	case ActionDeleteFile:
		s.FilesDeleted++
	case ActionEditFile:
		s.FilesEdited++
	case ActionRenameFile:
		s.FilesRenamed++
	case ActionMoveFile:
		s.FilesMoved++
	case ActionCopyFile:
		s.FilesCopied++
	case ActionCreateDir:
		s.DirsCreated++
	case ActionDeleteDir:
		s.DirsDeleted++
	case ActionRenameDir:
		s.DirsRenamed++
	case ActionMoveDir:
		s.DirsMoved++
	case ActionCopyDir:
		s.DirsCopied++
	case ActionRunCommand:
		s.CommandsRan++
	case ActionReadFile:
		s.FilesRead++
	case ActionSearchFiles:
		s.FilesSearched++
	case ActionListDir:
		s.DirsListed++
	case ActionDelegate:
		s.Delegations++
	}
}
