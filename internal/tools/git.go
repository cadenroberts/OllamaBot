package tools

import (
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

// GitStatusResult holds structured git status output.
type GitStatusResult struct {
	Branch      string   `json:"branch"`
	Staged      []string `json:"staged"`
	Modified    []string `json:"modified"`
	Untracked   []string `json:"untracked"`
	Clean       bool     `json:"clean"`
	AheadBehind string   `json:"ahead_behind,omitempty"`
}

// GitStatus runs git status and returns structured output.
func GitStatus(ctx context.Context, workDir string) (*GitStatusResult, error) {
	result := &GitStatusResult{}

	// Get branch name
	branch, err := gitExecWithContext(ctx, workDir, "rev-parse", "--abbrev-ref", "HEAD")
	if err != nil {
		return nil, fmt.Errorf("git branch: %w", err)
	}
	result.Branch = strings.TrimSpace(branch)

	// Get porcelain status
	status, err := gitExecWithContext(ctx, workDir, "status", "--porcelain")
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
	ab, err := gitExecWithContext(ctx, workDir, "rev-list", "--left-right", "--count", "HEAD...@{upstream}")
	if err == nil {
		result.AheadBehind = strings.TrimSpace(ab)
	}

	return result, nil
}

// GitDiff runs git diff for a path (or all if empty) and returns the diff text.
func GitDiff(ctx context.Context, workDir string, path string) (string, error) {
	args := []string{"diff"}
	if path != "" {
		args = append(args, "--", path)
	}

	diff, err := gitExecWithContext(ctx, workDir, args...)
	if err != nil {
		return "", fmt.Errorf("git diff: %w", err)
	}

	return diff, nil
}

// GitDiffStaged returns the staged diff.
func GitDiffStaged(ctx context.Context, workDir string) (string, error) {
	diff, err := gitExecWithContext(ctx, workDir, "diff", "--cached")
	if err != nil {
		return "", fmt.Errorf("git diff staged: %w", err)
	}
	return diff, nil
}

// GitCommit stages all changes and commits with the given message.
func GitCommit(ctx context.Context, workDir string, message string) error {
	if message == "" {
		return fmt.Errorf("commit message is required")
	}

	// Stage all changes
	if _, err := gitExecWithContext(ctx, workDir, "add", "-A"); err != nil {
		return fmt.Errorf("git add: %w", err)
	}

	// Commit
	if _, err := gitExecWithContext(ctx, workDir, "commit", "-m", message); err != nil {
		return fmt.Errorf("git commit: %w", err)
	}

	return nil
}

// GitPush pushes changes to the remote repository.
func GitPush(ctx context.Context, workDir string, remote string, branch string) error {
	args := []string{"push"}
	if remote != "" {
		args = append(args, remote)
	}
	if branch != "" {
		args = append(args, branch)
	}

	if _, err := gitExecWithContext(ctx, workDir, args...); err != nil {
		return fmt.Errorf("git push: %w", err)
	}

	return nil
}

// GitLog returns recent commit log.
func GitLog(ctx context.Context, workDir string, count int) (string, error) {
	if count <= 0 {
		count = 10
	}
	log, err := gitExecWithContext(ctx, workDir, "log", "--oneline", fmt.Sprintf("-%d", count))
	if err != nil {
		return "", fmt.Errorf("git log: %w", err)
	}
	return log, nil
}

// gitExecWithContext runs a git command with timeout and working directory.
func gitExecWithContext(ctx context.Context, workDir string, args ...string) (string, error) {
	// Default 30s timeout if not provided via ctx
	if ctx == nil {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
	}

	cmd := exec.CommandContext(ctx, "git", args...)
	if workDir != "" {
		cmd.Dir = workDir
	}

	out, err := cmd.CombinedOutput()
	if err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			return "", fmt.Errorf("git command timed out: %s", strings.Join(args, " "))
		}
		return "", fmt.Errorf("git %s failed: %w (output: %s)", strings.Join(args, " "), err, string(out))
	}

	return string(out), nil
}
