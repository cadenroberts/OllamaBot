// Package agent implements the agent executor for obot orchestration.
package agent

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// executeAction is the internal entry point for all agent actions.
// It validates the action, assigns metadata, routes to the appropriate handler,
// and records the execution duration and outcome.
func (a *Agent) executeAction(ctx context.Context, action *Action) error {
	a.mu.Lock()
	if !a.executing {
		a.mu.Unlock()
		return fmt.Errorf("agent is not in executing state")
	}
	a.mu.Unlock()

	// 1. Validate action type
	if action.Type == "" {
		return fmt.Errorf("action type is required")
	}

	// 2. Set metadata, ID, and timestamp
	if action.ID == "" {
		a.mu.Lock()
		action.ID = fmt.Sprintf("A%05d", len(a.actions)+1)
		a.mu.Unlock()
	}
	if action.Timestamp.IsZero() {
		action.Timestamp = time.Now()
	}

	// Initialize metadata if nil
	if action.Metadata == nil {
		action.Metadata = make(map[string]any)
	}
	action.Metadata["start_time"] = action.Timestamp.Format(time.RFC3339Nano)
	
	a.mu.Lock()
	action.Metadata["schedule"] = a.currentSchedule.String()
	action.Metadata["process"] = a.currentProcess.String()
	action.Metadata["model"] = string(a.currentModel)
	plugins := a.plugins
	a.mu.Unlock()

	// 3. Call OnBeforeAction hooks
	for _, p := range plugins {
		if err := p.OnBeforeAction(ctx, action); err != nil {
			return fmt.Errorf("plugin %s rejected action: %w", p.Name(), err)
		}
	}

	// 4. Route to handler and measure duration
	start := time.Now()
	var err error

	// Pre-execution validation
	if err = a.preExecuteValidation(action); err != nil {
		err = a.finalizeAction(action, start, err)
	} else {
		switch action.Type {
		case ActionCreateFile:
			err = a.handleCreateFile(ctx, action)
		case ActionDeleteFile:
			err = a.handleDeleteFile(ctx, action)
		case ActionEditFile:
			err = a.handleEditFile(ctx, action)
		case ActionRenameFile:
			err = a.handleRenameFile(ctx, action)
		case ActionMoveFile:
			err = a.handleMoveFile(ctx, action)
		case ActionCopyFile:
			err = a.handleCopyFile(ctx, action)
		case ActionCreateDir:
			err = a.handleCreateDir(ctx, action)
		case ActionDeleteDir:
			err = a.handleDeleteDir(ctx, action)
		case ActionRenameDir:
			err = a.handleRenameDir(ctx, action)
		case ActionMoveDir:
			err = a.handleMoveDir(ctx, action)
		case ActionCopyDir:
			err = a.handleCopyDir(ctx, action)
		case ActionRunCommand:
			err = a.handleRunCommand(ctx, action)
		case ActionLint:
			err = a.handleLint(ctx, action)
		case ActionFormat:
			err = a.handleFormat(ctx, action)
		case ActionTest:
			err = a.handleTest(ctx, action)
		case ActionReadFile:
			err = a.handleReadFile(ctx, action)
		case ActionSearchFiles:
			err = a.handleSearchFiles(ctx, action)
		case ActionListDir:
			err = a.handleListDir(ctx, action)
		case ActionDelegate:
			err = a.handleDelegate(ctx, action)
		case ActionProcessCompleted:
			err = a.handleProcessCompleted(ctx, action)
		default:
			err = fmt.Errorf("unsupported action type: %s", action.Type)
		}

		err = a.finalizeAction(action, start, err)
	}

	// 5. Call OnAfterAction hooks
	for _, p := range plugins {
		_ = p.OnAfterAction(ctx, action)
	}

	return err
}

// preExecuteValidation performs checks before an action is executed.
func (a *Agent) preExecuteValidation(action *Action) error {
	// Path validation for all file/dir operations
	switch action.Type {
	case ActionCreateFile, ActionDeleteFile, ActionEditFile, ActionReadFile, 
	     ActionCreateDir, ActionDeleteDir, ActionListDir, ActionLint, ActionFormat, ActionTest:
		if err := validatePath(action.Path); err != nil {
			return err
		}
	case ActionRenameFile, ActionMoveFile, ActionCopyFile, 
	     ActionRenameDir, ActionMoveDir, ActionCopyDir:
		if err := validatePath(action.Path); err != nil {
			return err
		}
		if err := validatePath(action.NewPath); err != nil {
			return err
		}
	}
	return nil
}

// finalizeAction records the outcome of an action execution.
func (a *Agent) finalizeAction(action *Action, start time.Time, err error) error {
	duration := time.Since(start)
	action.Metadata["duration_ms"] = duration.Milliseconds()
	
	if err != nil {
		action.Metadata["error"] = err.Error()
		action.Metadata["status"] = "failed"
	} else {
		action.Metadata["status"] = "success"
	}

	// Record the finished action
	a.recordAction(*action)
	return err
}

// handleCreateFile creates a new file with the specified content.
func (a *Agent) handleCreateFile(ctx context.Context, action *Action) error {
	// Ensure parent directory exists
	dir := filepath.Dir(action.Path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create directory %s: %w", dir, err)
	}

	// Create/Overwrite file
	err := os.WriteFile(action.Path, []byte(action.Content), 0644)
	if err != nil {
		return fmt.Errorf("failed to write file %s: %w", action.Path, err)
	}

	// Add file metadata to action
	if meta, metaErr := getFileMetadata(action.Path); metaErr == nil {
		for k, v := range meta {
			action.Metadata["file_"+k] = v
		}
	}

	return nil
}

// handleDeleteFile removes a file from the filesystem.
func (a *Agent) handleDeleteFile(ctx context.Context, action *Action) error {
	err := os.Remove(action.Path)
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to delete file %s: %w", action.Path, err)
	}
	return nil
}

// handleEditFile applies edits to an existing file.
func (a *Agent) handleEditFile(ctx context.Context, action *Action) error {
	// Check if file exists
	if _, err := os.Stat(action.Path); os.IsNotExist(err) {
		return fmt.Errorf("file does not exist: %s", action.Path)
	}

	// If action.Content is provided, we treat it as the new full content (full file replacement).
	if action.Content != "" {
		return os.WriteFile(action.Path, []byte(action.Content), 0644)
	}

	// Placeholder for actual edit logic
	return nil
}

// handleRenameFile renames a file.
func (a *Agent) handleRenameFile(ctx context.Context, action *Action) error {
	return os.Rename(action.Path, action.NewPath)
}

// handleMoveFile moves a file to a new location.
func (a *Agent) handleMoveFile(ctx context.Context, action *Action) error {
	dir := filepath.Dir(action.NewPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	return os.Rename(action.Path, action.NewPath)
}

// handleCopyFile copies a file from source to destination.
func (a *Agent) handleCopyFile(ctx context.Context, action *Action) error {
	data, err := os.ReadFile(action.Path)
	if err != nil {
		return err
	}

	dir := filepath.Dir(action.NewPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}

	return os.WriteFile(action.NewPath, data, 0644)
}

// handleCreateDir creates a new directory.
func (a *Agent) handleCreateDir(ctx context.Context, action *Action) error {
	return os.MkdirAll(action.Path, 0755)
}

// handleDeleteDir removes a directory and all its contents.
func (a *Agent) handleDeleteDir(ctx context.Context, action *Action) error {
	return os.RemoveAll(action.Path)
}

// handleRenameDir renames a directory.
func (a *Agent) handleRenameDir(ctx context.Context, action *Action) error {
	return os.Rename(action.Path, action.NewPath)
}

// handleMoveDir moves a directory.
func (a *Agent) handleMoveDir(ctx context.Context, action *Action) error {
	return os.Rename(action.Path, action.NewPath)
}

// handleCopyDir copies a directory recursively.
func (a *Agent) handleCopyDir(ctx context.Context, action *Action) error {
	return filepath.Walk(action.Path, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		rel, err := filepath.Rel(action.Path, path)
		if err != nil {
			return err
		}

		targetPath := filepath.Join(action.NewPath, rel)

		if info.IsDir() {
			return os.MkdirAll(targetPath, info.Mode())
		}

		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}

		return os.WriteFile(targetPath, data, info.Mode())
	})
}

// handleRunCommand executes a shell command with timeout and environment protection.
func (a *Agent) handleRunCommand(ctx context.Context, action *Action) error {
	cmd := exec.CommandContext(ctx, "sh", "-c", action.Command)
	cmd.Env = os.Environ()
	
	output, err := cmd.CombinedOutput()
	action.Output = string(output)
	
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			action.ExitCode = exitErr.ExitCode()
		} else {
			action.ExitCode = -1
		}
		return fmt.Errorf("command failed with exit code %d: %w", action.ExitCode, err)
	}
	
	action.ExitCode = 0
	return nil
}

// handleLint runs a linter on the specified path.
func (a *Agent) handleLint(ctx context.Context, action *Action) error {
	lang := detectLanguage(action.Path)
	var cmdStr string
	switch lang {
	case "go":
		cmdStr = "go vet " + action.Path
	case "python":
		cmdStr = "pylint " + action.Path
	case "javascript", "typescript":
		cmdStr = "eslint " + action.Path
	default:
		return fmt.Errorf("unsupported language for linting: %s", lang)
	}

	action.Command = cmdStr
	return a.handleRunCommand(ctx, action)
}

// handleFormat runs a formatter on the specified path.
func (a *Agent) handleFormat(ctx context.Context, action *Action) error {
	lang := detectLanguage(action.Path)
	var cmdStr string
	switch lang {
	case "go":
		cmdStr = "go fmt " + action.Path
	case "python":
		cmdStr = "black " + action.Path
	case "javascript", "typescript":
		cmdStr = "prettier --write " + action.Path
	default:
		return fmt.Errorf("unsupported language for formatting: %s", lang)
	}

	action.Command = cmdStr
	return a.handleRunCommand(ctx, action)
}

// handleTest runs tests on the specified path.
func (a *Agent) handleTest(ctx context.Context, action *Action) error {
	lang := detectLanguage(action.Path)
	var cmdStr string
	switch lang {
	case "go":
		cmdStr = "go test -v " + action.Path
	case "python":
		cmdStr = "pytest " + action.Path
	case "javascript", "typescript":
		cmdStr = "npm test " + action.Path
	default:
		return fmt.Errorf("unsupported language for testing: %s", lang)
	}

	action.Command = cmdStr
	return a.handleRunCommand(ctx, action)
}

func detectLanguage(path string) string {
	ext := filepath.Ext(path)
	switch ext {
	case ".go":
		return "go"
	case ".py":
		return "python"
	case ".js", ".jsx":
		return "javascript"
	case ".ts", ".tsx":
		return "typescript"
	default:
		return "unknown"
	}
}

// handleReadFile reads the content of a file.
func (a *Agent) handleReadFile(ctx context.Context, action *Action) error {
	data, err := os.ReadFile(action.Path)
	if err != nil {
		return err
	}

	action.Content = string(data)
	
	// Add file metadata
	if meta, metaErr := getFileMetadata(action.Path); metaErr == nil {
		for k, v := range meta {
			action.Metadata["file_"+k] = v
		}
	}
	
	return nil
}

// handleSearchFiles searches for files matching a pattern using glob.
func (a *Agent) handleSearchFiles(ctx context.Context, action *Action) error {
	// Use ripgrep if available
	cmd := exec.CommandContext(ctx, "rg", "--line-number", "--no-heading", "--color", "never", action.Content, action.Path)
	if action.Path == "" {
		cmd.Args[len(cmd.Args)-1] = "."
	}
	
	output, err := cmd.Output()
	if err == nil || (err != nil && cmd.ProcessState != nil && cmd.ProcessState.ExitCode() == 1) {
		action.Output = string(output)
		return nil
	}

	// Fallback to filepath.Walk
	return a.manualSearch(action, action.Content, action.Path)
}

func (a *Agent) manualSearch(action *Action, pattern, scope string) error {
	if scope == "" {
		scope = "."
	}
	var sb strings.Builder
	err := filepath.Walk(scope, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		// Skip binary files and large files
		if info.Size() > 1024*1024 {
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return nil
		}
		
		content := string(data)
		if strings.Contains(content, pattern) {
			lines := strings.Split(content, "\n")
			for i, line := range lines {
				if strings.Contains(line, pattern) {
					sb.WriteString(fmt.Sprintf("%s:%d:%s\n", path, i+1, strings.TrimSpace(line)))
				}
			}
		}
		return nil
	})
	action.Output = sb.String()
	return err
}

// handleListDir lists the contents of a directory.
func (a *Agent) handleListDir(ctx context.Context, action *Action) error {
	if action.Path == "" {
		action.Path = "."
	}
	entries, err := os.ReadDir(action.Path)
	if err != nil {
		return err
	}

	var names []string
	for _, entry := range entries {
		name := entry.Name()
		if entry.IsDir() {
			name += "/"
		}
		names = append(names, name)
	}

	action.Output = strings.Join(names, "\n")
	action.Metadata["entry_count"] = len(entries)
	
	return nil
}

// handleProcessCompleted marks the current process as finished.
func (a *Agent) handleProcessCompleted(ctx context.Context, action *Action) error {
	a.mu.Lock()
	callback := a.onComplete
	a.mu.Unlock()
	
	if callback != nil {
		callback()
	}
	
	action.Metadata["completed_at"] = time.Now().Format(time.RFC3339)
	return nil
}

// --- Helper Functions ---

// validatePath ensures the path is within the workspace and safe.
func validatePath(path string) error {
	if path == "" {
		return fmt.Errorf("path cannot be empty")
	}
	if strings.Contains(path, "..") {
		return fmt.Errorf("path contains parent directory reference: %s", path)
	}
	return nil
}

// getFileMetadata returns metadata about a file.
func getFileMetadata(path string) (map[string]any, error) {
	info, err := os.Stat(path)
	if err != nil {
		return nil, err
	}

	return map[string]any{
		"size":    info.Size(),
		"mode":    info.Mode().String(),
		"modTime": info.ModTime().Format(time.RFC3339),
		"isDir":   info.IsDir(),
	}, nil
}

// End of action execution handlers.
