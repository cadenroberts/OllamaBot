package agent

import (
	"context"
	"os"
)

// Tier 2 autonomous tools: read, search, list.
// These move the CLI agent from executor-only to autonomous.
// They route through executeAction for centralized tracking and validation.

// ReadFile reads and returns the content of a file.
func (a *Agent) ReadFile(ctx context.Context, path string) (string, error) {
	action := Action{
		Type: ActionReadFile,
		Path: path,
	}
	err := a.executeAction(ctx, &action)
	if err != nil {
		return "", err
	}
	return action.Content, nil
}

// SearchFiles searches for a pattern in files under the given directory scope.
func (a *Agent) SearchFiles(ctx context.Context, pattern string, scope string) (string, error) {
	if scope == "" {
		scope = "."
	}

	action := Action{
		Type:    ActionSearchFiles,
		Path:    scope,
		Content: pattern,
	}
	err := a.executeAction(ctx, &action)
	if err != nil {
		return "", err
	}
	return action.Output, nil
}

// ListDirectory lists the contents of a directory.
func (a *Agent) ListDirectory(ctx context.Context, path string) (string, error) {
	if path == "" {
		path = "."
	}

	action := Action{
		Type: ActionListDir,
		Path: path,
	}
	err := a.executeAction(ctx, &action)
	if err != nil {
		return "", err
	}
	return action.Output, nil
}

// FileExists checks if a file or directory exists.
func (a *Agent) FileExists(ctx context.Context, path string) (bool, error) {
	_, err := os.Stat(path)
	if err == nil {
		return true, nil
	}
	if os.IsNotExist(err) {
		return false, nil
	}
	return false, err
}

// End of tier 2 autonomous tools.
