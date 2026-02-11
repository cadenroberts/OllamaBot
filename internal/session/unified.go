package session

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/croberts/obot/internal/config"
)

// UnifiedSession is the cross-platform session format (USF v1.0).
// Both CLI and IDE read/write this format for session portability.
type UnifiedSession struct {
	Version        string            `json:"version"`
	SessionID      string            `json:"session_id"`
	CreatedAt      time.Time         `json:"created_at"`
	UpdatedAt      time.Time         `json:"updated_at"`
	PlatformOrigin string            `json:"platform_origin"` // "cli" or "ide"
	Task           USFTask           `json:"task"`
	Workspace      USFWorkspace      `json:"workspace"`
	Orchestration  USFOrchestration  `json:"orchestration"`
	Steps          []USFStep         `json:"steps"`
	Checkpoints    []USFCheckpoint   `json:"checkpoints"`
	Stats          USFStats          `json:"stats"`
}

// USFTask describes the task being worked on.
type USFTask struct {
	Description   string `json:"description"`
	Intent        string `json:"intent"`
	QualityPreset string `json:"quality_preset"`
	Status        string `json:"status"` // "in_progress", "completed", "failed"
}

// USFWorkspace describes the workspace context.
type USFWorkspace struct {
	Path      string `json:"path"`
	GitBranch string `json:"git_branch,omitempty"`
	GitCommit string `json:"git_commit,omitempty"`
}

// USFOrchestration tracks the orchestration state.
type USFOrchestration struct {
	FlowCode            string   `json:"flow_code"`
	CurrentSchedule     int      `json:"current_schedule"`
	CurrentProcess      int      `json:"current_process"`
	CompletedSchedules  []string `json:"completed_schedules"`
}

// USFStep records a single agent step.
type USFStep struct {
	StepNumber int       `json:"step_number"`
	ToolID     string    `json:"tool_id"`
	Input      string    `json:"input,omitempty"`
	Output     string    `json:"output,omitempty"`
	Success    bool      `json:"success"`
	Tokens     int       `json:"tokens,omitempty"`
	Duration   int64     `json:"duration_ms,omitempty"`
	Timestamp  time.Time `json:"timestamp"`
}

// USFCheckpoint represents a saved checkpoint.
type USFCheckpoint struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	GitCommit string    `json:"git_commit,omitempty"`
	FlowCode  string    `json:"flow_code"`
	Timestamp time.Time `json:"timestamp"`
}

// USFStats tracks session statistics.
type USFStats struct {
	TotalTokens       int     `json:"total_tokens"`
	FilesModified     int     `json:"files_modified"`
	FilesCreated      int     `json:"files_created"`
	CommandsRun       int     `json:"commands_run"`
	Delegations       int     `json:"delegations"`
	EstimatedCostSaved float64 `json:"estimated_cost_saved"`
	DurationSeconds   int64   `json:"duration_seconds"`
}

// NewUnifiedSession creates a new USF session for the CLI.
func NewUnifiedSession(task, intent, qualityPreset string) *UnifiedSession {
	now := time.Now()
	wd, _ := os.Getwd()

	return &UnifiedSession{
		Version:        "1.0",
		SessionID:      fmt.Sprintf("sess_%s", now.Format("20060102_150405")),
		CreatedAt:      now,
		UpdatedAt:      now,
		PlatformOrigin: "cli",
		Task: USFTask{
			Description:   task,
			Intent:        intent,
			QualityPreset: qualityPreset,
			Status:        "in_progress",
		},
		Workspace: USFWorkspace{
			Path: wd,
		},
		Steps:       make([]USFStep, 0),
		Checkpoints: make([]USFCheckpoint, 0),
	}
}

// AddStep records an agent step.
func (s *UnifiedSession) AddStep(toolID, input, output string, success bool, tokens int, duration int64) {
	s.Steps = append(s.Steps, USFStep{
		StepNumber: len(s.Steps) + 1,
		ToolID:     toolID,
		Input:      input,
		Output:     output,
		Success:    success,
		Tokens:     tokens,
		Duration:   duration,
		Timestamp:  time.Now(),
	})
	s.UpdatedAt = time.Now()
	s.Stats.TotalTokens += tokens
}

// AddCheckpoint saves a checkpoint.
func (s *UnifiedSession) AddCheckpoint(name, gitCommit string) {
	s.Checkpoints = append(s.Checkpoints, USFCheckpoint{
		ID:        fmt.Sprintf("cp-%d", len(s.Checkpoints)+1),
		Name:      name,
		GitCommit: gitCommit,
		FlowCode:  s.Orchestration.FlowCode,
		Timestamp: time.Now(),
	})
	s.UpdatedAt = time.Now()
}

// Complete marks the session as completed.
func (s *UnifiedSession) Complete() {
	s.Task.Status = "completed"
	s.UpdatedAt = time.Now()
	s.Stats.DurationSeconds = int64(time.Since(s.CreatedAt).Seconds())
}

// sessionsDir returns the sessions directory.
func sessionsDir() string {
	return filepath.Join(config.UnifiedConfigDir(), "sessions")
}

// SaveUSF writes the session to disk in USF format.
func SaveUSF(session *UnifiedSession) error {
	dir := sessionsDir()
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("create sessions dir: %w", err)
	}

	data, err := json.MarshalIndent(session, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal session: %w", err)
	}

	path := filepath.Join(dir, session.SessionID+".json")
	return os.WriteFile(path, data, 0644)
}

// LoadUSF reads a session from disk.
func LoadUSF(sessionID string) (*UnifiedSession, error) {
	path := filepath.Join(sessionsDir(), sessionID+".json")

	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read session: %w", err)
	}

	var session UnifiedSession
	if err := json.Unmarshal(data, &session); err != nil {
		return nil, fmt.Errorf("parse session: %w", err)
	}

	return &session, nil
}

// ListUSFSessions returns all USF session IDs.
func ListUSFSessions() ([]string, error) {
	dir := sessionsDir()
	entries, err := os.ReadDir(dir)
	if err != nil {
		if os.IsNotExist(err) {
			return []string{}, nil
		}
		return nil, err
	}

	sessions := make([]string, 0)
	for _, entry := range entries {
		if !entry.IsDir() && filepath.Ext(entry.Name()) == ".json" {
			sessions = append(sessions, entry.Name()[:len(entry.Name())-5])
		}
	}
	return sessions, nil
}

// ExportFromLegacy converts a legacy Session to a UnifiedSession.
func ExportFromLegacy(legacy *Session) *UnifiedSession {
	usf := &UnifiedSession{
		Version:        "1.0",
		SessionID:      legacy.ID,
		CreatedAt:      legacy.CreatedAt,
		UpdatedAt:      legacy.UpdatedAt,
		PlatformOrigin: "cli",
		Task: USFTask{
			Description: legacy.GetPrompt(),
			Status:      "completed",
		},
		Orchestration: USFOrchestration{
			FlowCode: legacy.GetFlowCode(),
		},
		Steps:       make([]USFStep, 0),
		Checkpoints: make([]USFCheckpoint, 0),
	}

	// Convert states to steps
	for i, state := range legacy.GetAllStates() {
		usf.Steps = append(usf.Steps, USFStep{
			StepNumber: i + 1,
			ToolID:     fmt.Sprintf("schedule.S%dP%d", state.Schedule, state.Process),
			Success:    true,
			Timestamp:  state.Timestamp,
		})
	}

	return usf
}
