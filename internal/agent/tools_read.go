package agent

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Tier 2 autonomous tools: read, search, list.
// These move the CLI agent from executor-only to autonomous.

// ReadFile reads and returns the content of a file.
func (a *Agent) ReadFile(ctx context.Context, path string) (string, error) {
	absPath, err := filepath.Abs(path)
	if err != nil {
		return "", fmt.Errorf("resolve path: %w", err)
	}

	data, err := os.ReadFile(absPath)
	if err != nil {
		return "", fmt.Errorf("read file: %w", err)
	}

	action := Action{
		Type: ActionReadFile,
		Path: absPath,
	}
	a.recordAction(action)

	return string(data), nil
}

// SearchFiles searches for a pattern in files under the given directory scope.
func (a *Agent) SearchFiles(ctx context.Context, pattern string, scope string) ([]SearchResult, error) {
	if scope == "" {
		scope = "."
	}

	absScope, err := filepath.Abs(scope)
	if err != nil {
		return nil, fmt.Errorf("resolve scope: %w", err)
	}

	results := make([]SearchResult, 0)
	lowerPattern := strings.ToLower(pattern)

	err = filepath.Walk(absScope, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil // skip errors
		}
		if info.IsDir() {
			base := filepath.Base(path)
			if base == ".git" || base == "node_modules" || base == "vendor" || base == ".obot" {
				return filepath.SkipDir
			}
			return nil
		}
		if info.Size() > 1024*1024 { // skip files > 1MB
			return nil
		}

		data, err := os.ReadFile(path)
		if err != nil {
			return nil
		}

		content := string(data)
		lines := strings.Split(content, "\n")
		for i, line := range lines {
			if strings.Contains(strings.ToLower(line), lowerPattern) {
				relPath, _ := filepath.Rel(absScope, path)
				results = append(results, SearchResult{
					File:       relPath,
					Line:       i + 1,
					Content:    strings.TrimSpace(line),
					MatchCount: strings.Count(strings.ToLower(line), lowerPattern),
				})
			}
		}
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("search files: %w", err)
	}

	action := Action{
		Type:    ActionSearchFiles,
		Content: fmt.Sprintf("pattern=%q scope=%s results=%d", pattern, scope, len(results)),
	}
	a.recordAction(action)

	return results, nil
}

// ListDirectory lists the contents of a directory.
func (a *Agent) ListDirectory(ctx context.Context, path string) ([]DirEntry, error) {
	if path == "" {
		path = "."
	}

	absPath, err := filepath.Abs(path)
	if err != nil {
		return nil, fmt.Errorf("resolve path: %w", err)
	}

	entries, err := os.ReadDir(absPath)
	if err != nil {
		return nil, fmt.Errorf("list directory: %w", err)
	}

	result := make([]DirEntry, 0, len(entries))
	for _, entry := range entries {
		name := entry.Name()
		if strings.HasPrefix(name, ".") {
			continue // skip hidden files
		}

		info, err := entry.Info()
		if err != nil {
			continue
		}

		result = append(result, DirEntry{
			Name:  name,
			IsDir: entry.IsDir(),
			Size:  info.Size(),
		})
	}

	action := Action{
		Type: ActionListDir,
		Path: absPath,
	}
	a.recordAction(action)

	return result, nil
}

// SearchResult represents a single search match.
type SearchResult struct {
	File       string `json:"file"`
	Line       int    `json:"line"`
	Content    string `json:"content"`
	MatchCount int    `json:"match_count"`
}

// DirEntry represents a directory listing entry.
type DirEntry struct {
	Name  string `json:"name"`
	IsDir bool   `json:"is_dir"`
	Size  int64  `json:"size"`
}
