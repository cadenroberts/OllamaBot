package git

import (
	"fmt"
	"os/exec"
	"strings"
)

// Config defines the configuration for the git Manager.
type Config struct {
	GitHubEnabled bool
	GitLabEnabled bool
	CommitSigning bool
}

// Manager coordinates git operations for a session.
type Manager struct {
	workDir string
	github  *GitHubClient
	gitlab  *GitLabClient
	config  Config
}

// NewManager initializes a new git Manager.
func NewManager(workDir string, github *GitHubClient, gitlab *GitLabClient, config Config) *Manager {
	return &Manager{
		workDir: workDir,
		github:  github,
		gitlab:  gitlab,
		config:  config,
	}
}

// Init runs 'git init' in the working directory.
func (m *Manager) Init() error {
	_, err := m.run("init")
	return err
}

// CreateRepository creates the repository on enabled remotes and adds them.
func (m *Manager) CreateRepository(name string) error {
	if m.config.GitHubEnabled {
		if m.github == nil {
			return fmt.Errorf("github client is not initialized")
		}
		if err := m.github.CreateRepository(name); err != nil {
			return fmt.Errorf("failed to create github repository: %w", err)
		}
		if _, err := m.run("remote", "add", "github", fmt.Sprintf("https://github.com/%s.git", name)); err != nil {
			// If remote already exists, that's fine, but log or handle other errors
			if !strings.Contains(err.Error(), "already exists") {
				return fmt.Errorf("failed to add github remote: %w", err)
			}
		}
	}
	if m.config.GitLabEnabled {
		if m.gitlab == nil {
			return fmt.Errorf("gitlab client is not initialized")
		}
		if err := m.gitlab.CreateRepository(name); err != nil {
			return fmt.Errorf("failed to create gitlab repository: %w", err)
		}
		if _, err := m.run("remote", "add", "gitlab", fmt.Sprintf("https://gitlab.com/%s.git", name)); err != nil {
			if !strings.Contains(err.Error(), "already exists") {
				return fmt.Errorf("failed to add gitlab remote: %w", err)
			}
		}
	}
	return nil
}

// CommitSession adds all changes and commits with a detailed message.
func (m *Manager) CommitSession(id string, summary string, stats map[string]interface{}) error {
	if _, err := m.run("add", "."); err != nil {
		return err
	}

	msg := m.buildCommitMessage(id, summary, stats)
	args := []string{"commit", "-m", msg}
	if m.config.CommitSigning {
		args = append(args, "-S")
	}

	_, err := m.run(args...)
	return err
}

// buildCommitMessage constructs the structured commit message as per spec.
func (m *Manager) buildCommitMessage(id string, summary string, stats map[string]interface{}) string {
	// Default values if stats are missing
	code := stats["code"]
	schedules := stats["schedules"]
	processes := stats["processes"]
	
	// File/Dir stats
	createdFiles := stats["created_files"]
	createdDirs := stats["created_dirs"]
	editedFiles := stats["edited_files"]
	deletedFiles := stats["deleted_files"]
	deletedDirs := stats["deleted_dirs"]
	
	// Human prompt stats
	initial := stats["initial"]
	clarifications := stats["clarifications"]
	feedback := stats["feedback"]

	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("[obot] %s\n\n", summary))
	sb.WriteString(fmt.Sprintf("Session: %s\n", id))
	sb.WriteString(fmt.Sprintf("Flow: %v\n", code))
	sb.WriteString(fmt.Sprintf("Schedules: %v\n", schedules))
	sb.WriteString(fmt.Sprintf("Processes: %v\n\n", processes))

	sb.WriteString("Changes:\n")
	sb.WriteString(fmt.Sprintf("  Created: %v files, %v dirs\n", createdFiles, createdDirs))
	sb.WriteString(fmt.Sprintf("  Edited: %v files\n", editedFiles))
	sb.WriteString(fmt.Sprintf("  Deleted: %v files, %v dirs\n\n", deletedFiles, deletedDirs))

	sb.WriteString("Human Prompts:\n")
	sb.WriteString(fmt.Sprintf("  Initial: %v\n", initial))
	sb.WriteString(fmt.Sprintf("  Clarifications: %v\n", clarifications))
	sb.WriteString(fmt.Sprintf("  Feedback: %v\n\n", feedback))

	sb.WriteString("Signed-off-by: obot <obot@local>")
	return sb.String()
}

// summarizeChanges formats the change summary string for short display.
func (m *Manager) summarizeChanges(created, edited, deleted interface{}) string {
	return fmt.Sprintf("%v created, %v edited, %v deleted", created, edited, deleted)
}

// PushAll pushes the main branch to all configured remotes.
func (m *Manager) PushAll() error {
	remotes, err := m.getRemotes()
	if err != nil {
		return err
	}

	for _, remote := range remotes {
		// Log failure but continue
		m.run("push", "-u", remote, "main")
	}
	return nil
}

// run executes a git command in the workDir.
func (m *Manager) run(args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = m.workDir
	out, err := cmd.CombinedOutput()
	return string(out), err
}

// getRemotes parses the list of git remotes.
func (m *Manager) getRemotes() ([]string, error) {
	out, err := m.run("remote")
	if err != nil {
		return nil, err
	}

	lines := strings.Split(strings.TrimSpace(out), "\n")
	var remotes []string
	for _, line := range lines {
		if line != "" {
			remotes = append(remotes, line)
		}
	}
	return remotes, nil
}
