// Package session implements session persistence for obot orchestration.
package session

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/croberts/obot/internal/orchestrate"
)

// USFVersion is the current version of the Unified Session Format.
const USFVersion = "1.0"

// USFSession represents the Unified Session Format (USF) for session portability.
type USFSession struct {
	Version            string               `json:"version"`
	SessionID          string               `json:"session_id"`
	CreatedAt          time.Time            `json:"created_at"`
	UpdatedAt          time.Time            `json:"updated_at"`
	Platform           string               `json:"platform"` // "cli" or "ide"
	Task               USFTaskInfo          `json:"task"`
	Workspace          USFWorkspaceInfo     `json:"workspace"`
	OrchestrationState USFOrchestrationInfo `json:"orchestration_state"`
	History            []USFStepInfo        `json:"history"`
	FilesModified      []string             `json:"files_modified"`
	Checkpoints        []USFCheckpointInfo  `json:"checkpoints"`
	Stats              USFStatsInfo         `json:"stats"`
}

// USFTaskInfo describes the task and its status.
type USFTaskInfo struct {
	Prompt      string `json:"prompt"`
	Description string `json:"description"`
	Status      string `json:"status"` // "in_progress", "completed", "suspended", "failed"
}

// USFWorkspaceInfo describes the working environment.
type USFWorkspaceInfo struct {
	Path      string `json:"path"`
	GitBranch string `json:"git_branch,omitempty"`
	GitCommit string `json:"git_commit,omitempty"`
}

// USFOrchestrationInfo tracks the current orchestration state.
type USFOrchestrationInfo struct {
	FlowCode         string                 `json:"flow_code"`
	Schedule         orchestrate.ScheduleID `json:"schedule"`
	Process          orchestrate.ProcessID  `json:"process"`
	ScheduleProgress map[string]float64     `json:"schedule_progress"`
}

// USFStepInfo records a single orchestration step.
type USFStepInfo struct {
	Sequence  int                    `json:"sequence"`
	Timestamp time.Time              `json:"timestamp"`
	Schedule  orchestrate.ScheduleID `json:"schedule"`
	Process   orchestrate.ProcessID  `json:"process"`
	Actions   []string               `json:"actions"`
}

// USFCheckpointInfo represents a saved checkpoint.
type USFCheckpointInfo struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	Timestamp time.Time `json:"timestamp"`
	FilesHash string    `json:"files_hash"`
}

// USFStatsInfo tracks session metrics.
type USFStatsInfo struct {
	TotalSteps      int           `json:"total_steps"`
	TotalTokens     int64         `json:"total_tokens"`
	DurationSeconds int64         `json:"duration_seconds"`
	HumanWaitTime   time.Duration `json:"human_wait_time"`
}

// NewUSFSession creates a new USF session.
func NewUSFSession(sessionID, platform, prompt string) *USFSession {
	now := time.Now()
	wd, _ := os.Getwd()

	return &USFSession{
		Version:   USFVersion,
		SessionID: sessionID,
		CreatedAt: now,
		UpdatedAt: now,
		Platform:  platform,
		Task: USFTaskInfo{
			Prompt: prompt,
			Status: "in_progress",
		},
		Workspace: USFWorkspaceInfo{
			Path: wd,
		},
		History:       make([]USFStepInfo, 0),
		FilesModified: make([]string, 0),
		Checkpoints:   make([]USFCheckpointInfo, 0),
		OrchestrationState: USFOrchestrationInfo{
			ScheduleProgress: make(map[string]float64),
		},
	}
}

// SaveUSF writes the USF session to disk.
func (s *USFSession) Save(baseDir string) error {
	s.UpdatedAt = time.Now()
	
	dir := filepath.Join(baseDir, s.SessionID)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create session directory: %w", err)
	}

	data, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal USF session: %w", err)
	}

	path := filepath.Join(dir, "session.usf")
	return os.WriteFile(path, data, 0644)
}

// LoadUSFSession reads a USF session from disk.
func LoadUSFSession(baseDir, sessionID string) (*USFSession, error) {
	path := filepath.Join(baseDir, sessionID, "session.usf")
	if baseDir == "" {
		homeDir, _ := os.UserHomeDir()
		path = filepath.Join(homeDir, ".config", "ollamabot", "sessions", sessionID, "session.usf")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read USF session: %w", err)
	}

	var session USFSession
	if err := json.Unmarshal(data, &session); err != nil {
		return nil, fmt.Errorf("failed to unmarshal USF session: %w", err)
	}

	return &session, nil
}

// AddStep adds a history step to the USF session.
func (s *USFSession) AddStep(sched orchestrate.ScheduleID, proc orchestrate.ProcessID, actions []string) {
	s.History = append(s.History, USFStepInfo{
		Sequence:  len(s.History) + 1,
		Timestamp: time.Now(),
		Schedule:  sched,
		Process:   proc,
		Actions:   actions,
	})
	s.Stats.TotalSteps = len(s.History)
}

// ExportUSF converts an internal Session to a USFSession.
func ExportUSF(legacy *Session) *USFSession {
	usf := &USFSession{
		Version:   USFVersion,
		SessionID: legacy.ID,
		CreatedAt: legacy.CreatedAt,
		UpdatedAt: legacy.UpdatedAt,
		Platform:  "cli",
		Task: USFTaskInfo{
			Prompt: legacy.GetPrompt(),
			Status: "completed",
		},
		Workspace: USFWorkspaceInfo{
			Path: legacy.baseDir, // Approximating workspace path with baseDir
		},
		OrchestrationState: USFOrchestrationInfo{
			FlowCode: legacy.GetFlowCode(),
			ScheduleProgress: make(map[string]float64),
		},
		History:       make([]USFStepInfo, 0),
		FilesModified: make([]string, 0),
		Checkpoints:   make([]USFCheckpointInfo, 0),
	}

	// Convert legacy states to USF history steps
	for i, state := range legacy.GetAllStates() {
		usf.History = append(usf.History, USFStepInfo{
			Sequence:  i + 1,
			Timestamp: state.Timestamp,
			Schedule:  state.Schedule,
			Process:   state.Process,
			Actions:   state.Actions,
		})
	}

	// Update stats
	usf.Stats.TotalSteps = len(usf.History)
	if legacy.stats != nil {
		usf.Stats.TotalTokens = legacy.stats.Tokens
		usf.Stats.DurationSeconds = int64(legacy.stats.Timing.TotalElapsed.Seconds())
		usf.Stats.HumanWaitTime = legacy.stats.Timing.HumanWait
	}

	return usf
}

// ListUSFSessionIDs lists all sessions that have a session.usf file.
func ListUSFSessionIDs(baseDir string) ([]string, error) {
	if baseDir == "" {
		homeDir, _ := os.UserHomeDir()
		baseDir = filepath.Join(homeDir, ".config", "ollamabot", "sessions")
	}

	entries, err := os.ReadDir(baseDir)
	if err != nil {
		if os.IsNotExist(err) {
			return []string{}, nil
		}
		return nil, err
	}

	var sessions []string
	for _, entry := range entries {
		if entry.IsDir() {
			path := filepath.Join(baseDir, entry.Name(), "session.usf")
			if _, err := os.Stat(path); err == nil {
				sessions = append(sessions, entry.Name())
			}
		}
	}
	return sessions, nil
}

// ImportUSF converts a USFSession back to an internal Session.
func ImportUSF(usf *USFSession, baseDir string) *Session {
	s := &Session{
		ID:        usf.SessionID,
		CreatedAt: usf.CreatedAt,
		UpdatedAt: usf.UpdatedAt,
		prompt:    usf.Task.Prompt,
		baseDir:   baseDir,
		flowCode:  usf.OrchestrationState.FlowCode,
		states:    make([]State, 0),
		stats: &SessionStats{
			ScheduleCounts: make(map[orchestrate.ScheduleID]int),
			ProcessCounts:  make(map[orchestrate.ScheduleID]map[orchestrate.ProcessID]int),
			Timing: TimingStats{
				TotalElapsed: time.Duration(usf.Stats.DurationSeconds) * time.Second,
				HumanWait:    usf.Stats.HumanWaitTime,
			},
			Tokens: usf.Stats.TotalTokens,
		},
	}

	// Convert USF history steps back to legacy states
	for _, step := range usf.History {
		state := State{
			ID:        fmt.Sprintf("%04d-S%dP%d", step.Sequence, step.Schedule, step.Process),
			Schedule:  step.Schedule,
			Process:   step.Process,
			Actions:   step.Actions,
			Timestamp: step.Timestamp,
		}
		s.states = append(s.states, state)
		
		// Update counts
		s.stats.ScheduleCounts[step.Schedule]++
		if s.stats.ProcessCounts[step.Schedule] == nil {
			s.stats.ProcessCounts[step.Schedule] = make(map[orchestrate.ProcessID]int)
		}
		s.stats.ProcessCounts[step.Schedule][step.Process]++
		
		s.currentStateID = state.ID
	}

	// Link states
	for i := 0; i < len(s.states); i++ {
		if i > 0 {
			s.states[i].Prev = s.states[i-1].ID
		}
		if i < len(s.states)-1 {
			s.states[i].Next = s.states[i+1].ID
		}
	}

	return s
}
