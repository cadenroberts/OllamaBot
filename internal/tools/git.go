package tools

import (
	"fmt"
	"os/exec"
	"strings"
)

// GitStatusResult holds structured git status output.
type GitStatusResult struct {
	Branch       string   `json:"branch"`
	Staged       []string `json:"staged"`
	Modified     []string `json:"modified"`
	Untracked    []string `json:"untracked"`
	Clean        bool     `json:"clean"`
	AheadBehind  string   `json:"ahead_behind,omitempty"`
}

// GitStatus runs git status and returns structured output.
func GitStatus(workDir string) (*GitStatusResult, error) {
	result := &GitStatusResult{}

	// Get branch name
	branch, err := gitExec(workDir, "rev-parse", "--abbrev-ref", "HEAD")
	if err != nil {
		return nil, fmt.Errorf("git branch: %w", err)
	}
	result.Branch = strings.TrimSpace(branch)

	// Get porcelain status
	status, err := gitExec(workDir, "status", "--porcelain")
	if err != nil {
		return nil, fmt.Errorf("git status: %w", err)
	}

	if strings.TrimSpace(status) == "" {
		result.Clean = true
		return result, nil
	}

	for _, line := range strings.Split(status, "\n") {
		if len(line) < 3 {
			continue
		}
		xy := line[:2]
		file := strings.TrimSpace(line[3:])

		switch {
		case xy[0] != ' ' && xy[0] != '?':
			result.Staged = append(result.Staged, file)
		case xy == "??":
			result.Untracked = append(result.Untracked, file)
		case xy[1] == 'M' || xy[1] == 'D':
			result.Modified = append(result.Modified, file)
		}
	}

	// Get ahead/behind
	ab, err := gitExec(workDir, "rev-list", "--left-right", "--count", "HEAD...@{upstream}")
	if err == nil {
		result.AheadBehind = strings.TrimSpace(ab)
	}

	return result, nil
}

// GitDiff runs git diff for a path (or all if empty) and returns the diff text.
func GitDiff(workDir string, path string) (string, error) {
	args := []string{"diff"}
	if path != "" {
		args = append(args, "--", path)
	}

	diff, err := gitExec(workDir, args...)
	if err != nil {
		return "", fmt.Errorf("git diff: %w", err)
	}

	return diff, nil
}

// GitDiffStaged returns the staged diff.
func GitDiffStaged(workDir string) (string, error) {
	diff, err := gitExec(workDir, "diff", "--cached")
	if err != nil {
		return "", fmt.Errorf("git diff staged: %w", err)
	}
	return diff, nil
}

// GitCommit stages all changes and commits with the given message.
func GitCommit(workDir string, message string) error {
	if message == "" {
		return fmt.Errorf("commit message is required")
	}

	// Stage all changes
	if _, err := gitExec(workDir, "add", "-A"); err != nil {
		return fmt.Errorf("git add: %w", err)
	}

	// Commit
	if _, err := gitExec(workDir, "commit", "-m", message); err != nil {
		return fmt.Errorf("git commit: %w", err)
	}

	return nil
}

// GitLog returns recent commit log.
func GitLog(workDir string, count int) (string, error) {
	if count <= 0 {
		count = 10
	}
	log, err := gitExec(workDir, "log", "--oneline", fmt.Sprintf("-%d", count))
	if err != nil {
		return "", fmt.Errorf("git log: %w", err)
	}
	return log, nil
}

// gitExec runs a git command and returns stdout.
func gitExec(workDir string, args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	if workDir != "" {
		cmd.Dir = workDir
	}

	out, err := cmd.Output()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			return "", fmt.Errorf("git %s: %s", strings.Join(args, " "), string(exitErr.Stderr))
		}
		return "", err
	}

	return string(out), nil
}
