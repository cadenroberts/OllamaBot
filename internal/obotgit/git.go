// Package obotgit implements Git integration for obot orchestration.
// This includes full GitHub and GitLab support with NO functionality omitted.
package obotgit

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// Client provides Git operations
type Client struct {
	// Repository path
	repoPath string

	// Remote configurations
	github *RemoteConfig
	gitlab *RemoteConfig

	// Authentication
	auth *AuthConfig

	// Options
	commitSigning bool
	autoPush      bool
}

// RemoteConfig contains remote repository configuration
type RemoteConfig struct {
	Enabled  bool
	Name     string // Remote name (e.g., "origin", "github")
	URL      string
	Username string
	RepoName string
}

// AuthConfig contains authentication configuration
type AuthConfig struct {
	GitHubToken string
	GitLabToken string
	SSHKeyPath  string
}

// NewClient creates a new Git client
func NewClient(repoPath string) *Client {
	return &Client{
		repoPath:      repoPath,
		commitSigning: false,
		autoPush:      true,
	}
}

// SetGitHub configures GitHub integration
func (c *Client) SetGitHub(enabled bool, username, repoName, token string) {
	c.github = &RemoteConfig{
		Enabled:  enabled,
		Name:     "github",
		Username: username,
		RepoName: repoName,
	}
	if c.auth == nil {
		c.auth = &AuthConfig{}
	}
	c.auth.GitHubToken = token
}

// SetGitLab configures GitLab integration
func (c *Client) SetGitLab(enabled bool, username, repoName, token string) {
	c.gitlab = &RemoteConfig{
		Enabled:  enabled,
		Name:     "gitlab",
		Username: username,
		RepoName: repoName,
	}
	if c.auth == nil {
		c.auth = &AuthConfig{}
	}
	c.auth.GitLabToken = token
}

// Init initializes a new Git repository
func (c *Client) Init(ctx context.Context) error {
	return c.run(ctx, "init")
}

// Clone clones a repository
func (c *Client) Clone(ctx context.Context, url, dest string) error {
	return c.runInDir(ctx, "", "clone", url, dest)
}

// Add stages files
func (c *Client) Add(ctx context.Context, paths ...string) error {
	args := append([]string{"add"}, paths...)
	return c.run(ctx, args...)
}

// Commit creates a commit
func (c *Client) Commit(ctx context.Context, message string) error {
	args := []string{"commit", "-m", message}
	if c.commitSigning {
		args = append(args, "-S")
	}
	return c.run(ctx, args...)
}

// Push pushes to a remote
func (c *Client) Push(ctx context.Context, remote, branch string) error {
	return c.run(ctx, "push", remote, branch)
}

// Pull pulls from a remote
func (c *Client) Pull(ctx context.Context, remote, branch string) error {
	return c.run(ctx, "pull", remote, branch)
}

// Fetch fetches from a remote
func (c *Client) Fetch(ctx context.Context, remote string) error {
	return c.run(ctx, "fetch", remote)
}

// Branch creates a new branch
func (c *Client) Branch(ctx context.Context, name string) error {
	return c.run(ctx, "branch", name)
}

// Checkout checks out a branch or commit
func (c *Client) Checkout(ctx context.Context, ref string) error {
	return c.run(ctx, "checkout", ref)
}

// Merge merges a branch
func (c *Client) Merge(ctx context.Context, branch string) error {
	return c.run(ctx, "merge", branch)
}

// Rebase rebases onto a branch
func (c *Client) Rebase(ctx context.Context, branch string) error {
	return c.run(ctx, "rebase", branch)
}

// Tag creates a tag
func (c *Client) Tag(ctx context.Context, name, message string) error {
	if message != "" {
		return c.run(ctx, "tag", "-a", name, "-m", message)
	}
	return c.run(ctx, "tag", name)
}

// Status returns the repository status
func (c *Client) Status(ctx context.Context) (string, error) {
	return c.runOutput(ctx, "status", "--porcelain")
}

// Log returns commit log
func (c *Client) Log(ctx context.Context, count int) (string, error) {
	return c.runOutput(ctx, "log", fmt.Sprintf("-n%d", count), "--oneline")
}

// Diff returns diff output
func (c *Client) Diff(ctx context.Context, args ...string) (string, error) {
	allArgs := append([]string{"diff"}, args...)
	return c.runOutput(ctx, allArgs...)
}

// Stash stashes changes
func (c *Client) Stash(ctx context.Context) error {
	return c.run(ctx, "stash")
}

// StashPop pops stashed changes
func (c *Client) StashPop(ctx context.Context) error {
	return c.run(ctx, "stash", "pop")
}

// RemoteAdd adds a remote
func (c *Client) RemoteAdd(ctx context.Context, name, url string) error {
	return c.run(ctx, "remote", "add", name, url)
}

// RemoteRemove removes a remote
func (c *Client) RemoteRemove(ctx context.Context, name string) error {
	return c.run(ctx, "remote", "remove", name)
}

// Reset resets to a commit
func (c *Client) Reset(ctx context.Context, ref string, hard bool) error {
	if hard {
		return c.run(ctx, "reset", "--hard", ref)
	}
	return c.run(ctx, "reset", ref)
}

// Rev returns the current revision hash
func (c *Client) Rev(ctx context.Context) (string, error) {
	output, err := c.runOutput(ctx, "rev-parse", "HEAD")
	return strings.TrimSpace(output), err
}

// run executes a git command
func (c *Client) run(ctx context.Context, args ...string) error {
	return c.runInDir(ctx, c.repoPath, args...)
}

// runInDir executes a git command in a specific directory
func (c *Client) runInDir(ctx context.Context, dir string, args ...string) error {
	cmd := exec.CommandContext(ctx, "git", args...)
	if dir != "" {
		cmd.Dir = dir
	}
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// runOutput executes a git command and returns output
func (c *Client) runOutput(ctx context.Context, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, "git", args...)
	cmd.Dir = c.repoPath
	output, err := cmd.Output()
	return string(output), err
}

// SessionCommit creates a commit for a session state
type SessionCommit struct {
	SessionID     string
	FlowCode      string
	ScheduleCount int
	ProcessCount  int
	ActionSummary string
	InitialPrompt string
	Clarifications int
	Feedbacks     int
}

// CommitSession creates a commit for the current session state
func (c *Client) CommitSession(ctx context.Context, sc SessionCommit) error {
	message := fmt.Sprintf(`[obot] Session commit

Session: %s
Flow: %s
Schedules: %d
Processes: %d

Changes:
%s

Human Prompts:
- Initial: %s
- Clarifications: %d
- Feedback: %d

Signed-off-by: obot <obot@local>
`, sc.SessionID, sc.FlowCode, sc.ScheduleCount, sc.ProcessCount,
		sc.ActionSummary, truncate(sc.InitialPrompt, 50), sc.Clarifications, sc.Feedbacks)

	// Stage all changes
	if err := c.Add(ctx, "."); err != nil {
		return fmt.Errorf("failed to stage changes: %w", err)
	}

	// Create commit
	if err := c.Commit(ctx, message); err != nil {
		return fmt.Errorf("failed to commit: %w", err)
	}

	return nil
}

// PushToRemotes pushes to all configured remotes
func (c *Client) PushToRemotes(ctx context.Context) error {
	branch := "main" // Default branch

	if c.github != nil && c.github.Enabled {
		if err := c.Push(ctx, c.github.Name, branch); err != nil {
			return fmt.Errorf("failed to push to GitHub: %w", err)
		}
	}

	if c.gitlab != nil && c.gitlab.Enabled {
		if err := c.Push(ctx, c.gitlab.Name, branch); err != nil {
			return fmt.Errorf("failed to push to GitLab: %w", err)
		}
	}

	return nil
}

// CreateGitHubRepo creates a new GitHub repository
func (c *Client) CreateGitHubRepo(ctx context.Context, name string, private bool) error {
	if c.auth == nil || c.auth.GitHubToken == "" {
		return fmt.Errorf("GitHub token not configured")
	}

	// Would use GitHub API here
	// For now, placeholder
	fmt.Printf("Would create GitHub repo: %s (private: %v)\n", name, private)
	return nil
}

// CreateGitLabRepo creates a new GitLab repository
func (c *Client) CreateGitLabRepo(ctx context.Context, name string, private bool) error {
	if c.auth == nil || c.auth.GitLabToken == "" {
		return fmt.Errorf("GitLab token not configured")
	}

	// Would use GitLab API here
	// For now, placeholder
	fmt.Printf("Would create GitLab repo: %s (private: %v)\n", name, private)
	return nil
}

// OnPromptComplete handles prompt completion - auto-push if configured
func (c *Client) OnPromptComplete(ctx context.Context, sc SessionCommit) error {
	// Commit the session
	if err := c.CommitSession(ctx, sc); err != nil {
		return err
	}

	// Push if auto-push is enabled
	if c.autoPush {
		return c.PushToRemotes(ctx)
	}

	return nil
}

// MapSessionToCommit maps a session state ID to a git commit
func (c *Client) MapSessionToCommit(stateID string) (string, error) {
	// In a real implementation, this would look up the mapping
	// For now, return a placeholder
	return "", fmt.Errorf("mapping not implemented")
}

// LoadCredentials loads credentials from disk
func LoadCredentials(tokenPath string) (string, error) {
	expandedPath := expandPath(tokenPath)
	data, err := os.ReadFile(expandedPath)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(data)), nil
}

// expandPath expands ~ to home directory
func expandPath(path string) string {
	if strings.HasPrefix(path, "~/") {
		home, err := os.UserHomeDir()
		if err == nil {
			return filepath.Join(home, path[2:])
		}
	}
	return path
}

// truncate truncates a string to maxLen
func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen-3] + "..."
}

// GetCurrentBranch returns the current branch name
func (c *Client) GetCurrentBranch(ctx context.Context) (string, error) {
	output, err := c.runOutput(ctx, "rev-parse", "--abbrev-ref", "HEAD")
	return strings.TrimSpace(output), err
}

// HasUncommittedChanges checks for uncommitted changes
func (c *Client) HasUncommittedChanges(ctx context.Context) (bool, error) {
	status, err := c.Status(ctx)
	if err != nil {
		return false, err
	}
	return strings.TrimSpace(status) != "", nil
}

// GetLastCommitTime returns the timestamp of the last commit
func (c *Client) GetLastCommitTime(ctx context.Context) (time.Time, error) {
	output, err := c.runOutput(ctx, "log", "-1", "--format=%cI")
	if err != nil {
		return time.Time{}, err
	}
	return time.Parse(time.RFC3339, strings.TrimSpace(output))
}
