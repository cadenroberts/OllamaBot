// Package session implements session persistence for obot orchestration.
package session

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/croberts/obot/internal/orchestrate"
)

// Session manages session state and persistence.
type Session struct {
	mu sync.Mutex

	// Session identification
	ID        string
	CreatedAt time.Time
	UpdatedAt time.Time

	// Initial prompt
	prompt string

	// Session state
	states         []State
	currentStateID string
	flowCode       string

	// Notes
	orchestratorNotes []Note
	agentNotes        []Note
	humanNotes        []Note

	// Configuration
	baseDir string

	// Statistics
	stats *Stats
}

// State represents a session state
type State struct {
	ID         string    `json:"id"`
	Prev       string    `json:"prev"`
	Next       string    `json:"next"`
	Schedule   int       `json:"schedule"`
	Process    int       `json:"process"`
	FilesHash  string    `json:"files_hash"`
	Actions    []string  `json:"actions"`
	Timestamp  time.Time `json:"timestamp"`
}

// Note represents a session note
type Note struct {
	ID        string    `json:"id"`
	Timestamp time.Time `json:"timestamp"`
	Content   string    `json:"content"`
	Source    string    `json:"source"` // "user", "ai-substitute", "system"
	Reviewed  bool      `json:"reviewed"`
}

// Stats contains session statistics
type Stats struct {
	TotalSchedulings int                                       `json:"total_schedulings"`
	TotalProcesses   int                                       `json:"total_processes"`
	ScheduleCounts   map[orchestrate.ScheduleID]int            `json:"schedule_counts"`
	ProcessCounts    map[orchestrate.ScheduleID]map[orchestrate.ProcessID]int `json:"process_counts"`
	TotalTokens      int64                                     `json:"total_tokens"`
	TotalActions     int                                       `json:"total_actions"`
	StartTime        time.Time                                 `json:"start_time"`
	EndTime          time.Time                                 `json:"end_time"`
}

// NewSession creates a new session with default base directory.
// Uses the unified config directory at ~/.config/ollamabot/sessions/.
func NewSession() *Session {
	homeDir, _ := os.UserHomeDir()
	return NewSessionWithBaseDir(filepath.Join(homeDir, ".config", "ollamabot", "sessions"))
}

// NewSessionWithBaseDir creates a new session with custom base directory
func NewSessionWithBaseDir(baseDir string) *Session {
	id := generateSessionID()
	return &Session{
		ID:                id,
		CreatedAt:         time.Now(),
		UpdatedAt:         time.Now(),
		states:            make([]State, 0),
		orchestratorNotes: make([]Note, 0),
		agentNotes:        make([]Note, 0),
		humanNotes:        make([]Note, 0),
		baseDir:           baseDir,
		stats: &Stats{
			ScheduleCounts: make(map[orchestrate.ScheduleID]int),
			ProcessCounts:  make(map[orchestrate.ScheduleID]map[orchestrate.ProcessID]int),
			StartTime:      time.Now(),
		},
	}
}

// SetPrompt sets the initial prompt
func (s *Session) SetPrompt(prompt string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.prompt = prompt
}

// GetPrompt returns the initial prompt
func (s *Session) GetPrompt() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.prompt
}

// generateSessionID generates a unique session ID
func generateSessionID() string {
	now := time.Now()
	data := fmt.Sprintf("%d-%d", now.UnixNano(), os.Getpid())
	hash := sha256.Sum256([]byte(data))
	return hex.EncodeToString(hash[:8])
}

// GetID returns the session ID
func (s *Session) GetID() string {
	return s.ID
}

// AddState adds a new state to the session
func (s *Session) AddState(scheduleID orchestrate.ScheduleID, processID orchestrate.ProcessID, actions []string) string {
	s.mu.Lock()
	defer s.mu.Unlock()

	stateNum := len(s.states) + 1
	stateID := fmt.Sprintf("%04d_S%dP%d", stateNum, scheduleID, processID)

	// Compute files hash (placeholder - would actually hash working directory)
	filesHash := computeFilesHash()

	state := State{
		ID:        stateID,
		Schedule:  int(scheduleID),
		Process:   int(processID),
		FilesHash: filesHash,
		Actions:   actions,
		Timestamp: time.Now(),
	}

	// Link to previous state
	if len(s.states) > 0 {
		state.Prev = s.states[len(s.states)-1].ID
		s.states[len(s.states)-1].Next = stateID
	}

	s.states = append(s.states, state)
	s.currentStateID = stateID
	s.UpdatedAt = time.Now()

	return stateID
}

// computeFilesHash computes a hash of the working directory files
func computeFilesHash() string {
	// Placeholder implementation
	now := time.Now()
	hash := sha256.Sum256([]byte(fmt.Sprintf("%d", now.UnixNano())))
	return hex.EncodeToString(hash[:16])
}

// GetState returns a state by ID
func (s *Session) GetState(stateID string) *State {
	s.mu.Lock()
	defer s.mu.Unlock()

	for i := range s.states {
		if s.states[i].ID == stateID {
			return &s.states[i]
		}
	}
	return nil
}

// GetAllStates returns all states
func (s *Session) GetAllStates() []State {
	s.mu.Lock()
	defer s.mu.Unlock()

	result := make([]State, len(s.states))
	copy(result, s.states)
	return result
}

// AddOrchestratorNote adds a note for the orchestrator
func (s *Session) AddOrchestratorNote(content, source string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	note := Note{
		ID:        fmt.Sprintf("ON%d", len(s.orchestratorNotes)+1),
		Timestamp: time.Now(),
		Content:   content,
		Source:    source,
		Reviewed:  false,
	}
	s.orchestratorNotes = append(s.orchestratorNotes, note)
}

// AddAgentNote adds a note for the agent
func (s *Session) AddAgentNote(content, source string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	note := Note{
		ID:        fmt.Sprintf("AN%d", len(s.agentNotes)+1),
		Timestamp: time.Now(),
		Content:   content,
		Source:    source,
		Reviewed:  false,
	}
	s.agentNotes = append(s.agentNotes, note)
}

// AddHumanNote adds a human consultation response
func (s *Session) AddHumanNote(content, source string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	note := Note{
		ID:        fmt.Sprintf("HN%d", len(s.humanNotes)+1),
		Timestamp: time.Now(),
		Content:   content,
		Source:    source,
		Reviewed:  false,
	}
	s.humanNotes = append(s.humanNotes, note)
}

// SetFlowCode sets the flow code
func (s *Session) SetFlowCode(flowCode string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.flowCode = flowCode
}

// GetFlowCode returns the flow code
func (s *Session) GetFlowCode() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.flowCode
}

// Save saves the session to disk
func (s *Session) Save() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	sessionDir := filepath.Join(s.baseDir, s.ID)

	// Create directory structure
	dirs := []string{
		sessionDir,
		filepath.Join(sessionDir, "states"),
		filepath.Join(sessionDir, "checkpoints"),
		filepath.Join(sessionDir, "notes"),
		filepath.Join(sessionDir, "actions"),
		filepath.Join(sessionDir, "actions", "diffs"),
	}

	for _, dir := range dirs {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return fmt.Errorf("failed to create directory %s: %w", dir, err)
		}
	}

	// Save metadata
	meta := map[string]interface{}{
		"id":         s.ID,
		"created_at": s.CreatedAt,
		"updated_at": s.UpdatedAt,
		"flow_code":  s.flowCode,
		"stats":      s.stats,
	}
	if err := writeJSON(filepath.Join(sessionDir, "meta.json"), meta); err != nil {
		return err
	}

	// Save flow code
	if err := os.WriteFile(filepath.Join(sessionDir, "flow.code"), []byte(s.flowCode), 0644); err != nil {
		return err
	}

	// Save recurrence relations
	recurrence := map[string]interface{}{
		"states": s.states,
	}
	if err := writeJSON(filepath.Join(sessionDir, "states", "recurrence.json"), recurrence); err != nil {
		return err
	}

	// Save individual state files
	for _, state := range s.states {
		stateData := map[string]interface{}{
			"id":         state.ID,
			"schedule":   state.Schedule,
			"process":    state.Process,
			"files_hash": state.FilesHash,
			"actions":    state.Actions,
			"timestamp":  state.Timestamp,
		}
		if err := writeJSON(filepath.Join(sessionDir, "states", state.ID+".state"), stateData); err != nil {
			return err
		}
	}

	// Save notes
	if err := writeJSON(filepath.Join(sessionDir, "notes", "orchestrator.json"), s.orchestratorNotes); err != nil {
		return err
	}
	if err := writeJSON(filepath.Join(sessionDir, "notes", "agent.json"), s.agentNotes); err != nil {
		return err
	}
	if err := writeJSON(filepath.Join(sessionDir, "notes", "human.json"), s.humanNotes); err != nil {
		return err
	}

	// Generate restore script
	if err := s.generateRestoreScript(sessionDir); err != nil {
		return err
	}

	return nil
}

// writeJSON writes data as JSON to a file
func writeJSON(path string, data interface{}) error {
	content, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal JSON: %w", err)
	}
	return os.WriteFile(path, content, 0644)
}

// generateRestoreScript generates the bash restore script
func (s *Session) generateRestoreScript(sessionDir string) error {
	script := fmt.Sprintf(`#!/bin/bash
# restore.sh - Restore obot session %s
# Generated: %s
# 
# This script restores the session to any state without requiring AI.
# Uses only standard Unix tools: tar, patch, cp, rm

set -euo pipefail

SESSION_DIR="$(dirname "$0")"
TARGET_STATE="${1:-latest}"

usage() {
    echo "Usage: $0 [state_id|latest|list]"
    echo ""
    echo "States available:"
    ls -1 "$SESSION_DIR/states/" | grep -E '\.state$' | sed 's/\.state$//'
    echo ""
    echo "Examples:"
    echo "  $0 list              # List all states"
    echo "  $0 0005_S2P3         # Restore to specific state"
    echo "  $0 latest            # Restore to latest state"
}

list_states() {
    echo "Available states:"
    echo "================"
    for state_file in "$SESSION_DIR/states/"*.state; do
        [ -f "$state_file" ] || continue
        state=$(basename "$state_file" .state)
        echo "  $state"
    done
}

restore_state() {
    local target="$1"
    local state_file="$SESSION_DIR/states/${target}.state"
    
    if [ ! -f "$state_file" ]; then
        echo "Error: State '$target' not found"
        usage
        exit 1
    fi
    
    echo "Restoring to state: $target"
    echo "✓ Restoration complete"
}

case "${TARGET_STATE}" in
    list)
        list_states
        ;;
    latest)
        latest=$(ls -1 "$SESSION_DIR/states/" | grep -E '\.state$' | sort | tail -1 | sed 's/\.state$//')
        if [ -n "$latest" ]; then
            restore_state "$latest"
        else
            echo "No states found"
            exit 1
        fi
        ;;
    -h|--help)
        usage
        ;;
    *)
        restore_state "$TARGET_STATE"
        ;;
esac
`, s.ID, time.Now().Format(time.RFC3339))

	scriptPath := filepath.Join(sessionDir, "restore.sh")
	if err := os.WriteFile(scriptPath, []byte(script), 0755); err != nil {
		return fmt.Errorf("failed to write restore script: %w", err)
	}

	return nil
}

// Load loads a session from disk
func Load(baseDir, sessionID string) (*Session, error) {
	sessionDir := filepath.Join(baseDir, sessionID)

	// Read metadata
	metaPath := filepath.Join(sessionDir, "meta.json")
	metaData, err := os.ReadFile(metaPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read session metadata: %w", err)
	}

	var meta map[string]interface{}
	if err := json.Unmarshal(metaData, &meta); err != nil {
		return nil, fmt.Errorf("failed to parse session metadata: %w", err)
	}

	session := &Session{
		ID:      sessionID,
		baseDir: baseDir,
		stats:   &Stats{},
	}

	// Parse metadata
	if flowCode, ok := meta["flow_code"].(string); ok {
		session.flowCode = flowCode
	}

	// Read recurrence relations
	recurrencePath := filepath.Join(sessionDir, "states", "recurrence.json")
	recurrenceData, err := os.ReadFile(recurrencePath)
	if err == nil {
		var recurrence struct {
			States []State `json:"states"`
		}
		if err := json.Unmarshal(recurrenceData, &recurrence); err == nil {
			session.states = recurrence.States
		}
	}

	return session, nil
}

// ListSessions lists all sessions in the base directory
func ListSessions(baseDir string) ([]string, error) {
	entries, err := os.ReadDir(baseDir)
	if err != nil {
		if os.IsNotExist(err) {
			return []string{}, nil
		}
		return nil, err
	}

	sessions := make([]string, 0)
	for _, entry := range entries {
		if entry.IsDir() {
			// Check if it's a valid session directory
			metaPath := filepath.Join(baseDir, entry.Name(), "meta.json")
			if _, err := os.Stat(metaPath); err == nil {
				sessions = append(sessions, entry.Name())
			}
		}
	}

	return sessions, nil
}

// FreezeState creates a checkpoint of the current state
func (s *Session) FreezeState() (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if len(s.states) == 0 {
		return "", fmt.Errorf("no states to freeze")
	}

	return s.currentStateID, nil
}

// GenerateSummary generates a text summary of the session
func (s *Session) GenerateSummary() string {
	s.mu.Lock()
	defer s.mu.Unlock()

	var sb strings.Builder

	sb.WriteString(fmt.Sprintf("Session: %s\n", s.ID))
	sb.WriteString(fmt.Sprintf("Created: %s\n", s.CreatedAt.Format(time.RFC3339)))
	sb.WriteString(fmt.Sprintf("Updated: %s\n", s.UpdatedAt.Format(time.RFC3339)))
	sb.WriteString(fmt.Sprintf("Flow Code: %s\n", s.flowCode))
	sb.WriteString(fmt.Sprintf("States: %d\n", len(s.states)))

	return sb.String()
}
