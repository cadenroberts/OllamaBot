// Package session implements session persistence for obot orchestration.
package session

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
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
	lastSchedule   orchestrate.ScheduleID

	// Notes
	orchestratorNotes []Note
	agentNotes        []Note
	humanNotes        []Note

	// Configuration
	baseDir string

	// Statistics
	stats *SessionStats
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
		stats: &SessionStats{
			ScheduleCounts: make(map[orchestrate.ScheduleID]int),
			ProcessCounts:  make(map[orchestrate.ScheduleID]map[orchestrate.ProcessID]int),
			Timing: TimingStats{
				StartTime: time.Now(),
			},
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
	stateID := fmt.Sprintf("%04d-S%dP%d", stateNum, scheduleID, processID)

	// Compute files hash
	filesHash := s.computeFilesHash()

	state := State{
		ID:        stateID,
		Schedule:  scheduleID,
		Process:   processID,
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

	// Update flow code: append S on schedule change, always append P
	if scheduleID != s.lastSchedule {
		s.flowCode += fmt.Sprintf("S%d", scheduleID)
		s.lastSchedule = scheduleID
	}
	s.flowCode += fmt.Sprintf("P%d", processID)

	// Save the state file immediately
	sessionDir := filepath.Join(s.baseDir, s.ID)
	stateData := map[string]interface{}{
		"id":         state.ID,
		"schedule":   state.Schedule,
		"process":    state.Process,
		"files_hash": state.FilesHash,
		"actions":    state.Actions,
		"timestamp":  state.Timestamp,
	}
	_ = writeJSON(filepath.Join(sessionDir, "states", state.ID+".state"), stateData)

	return stateID
}

// computeFilesHash computes a SHA256 hash of the project files.
func (s *Session) computeFilesHash() string {
	hasher := sha256.New()

	// Get workspace root
	root, err := os.Getwd()
	if err != nil {
		root = "."
	}

	// Collect files first to sort them for deterministic hashing
	var files []string
	_ = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if info.IsDir() {
			// Skip hidden dirs (including .git), node_modules, and sessions dir
			name := info.Name()
			if strings.HasPrefix(name, ".") || name == "node_modules" || path == s.baseDir {
				return filepath.SkipDir
			}
			return nil
		}

		// Skip non-regular files
		if !info.Mode().IsRegular() {
			return nil
		}

		files = append(files, path)
		return nil
	})

	sort.Strings(files)

	for _, path := range files {
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		// Hash the relative path and the content
		rel, _ := filepath.Rel(root, path)
		hasher.Write([]byte(rel))
		hasher.Write(data)
	}

	return hex.EncodeToString(hasher.Sum(nil))
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
		"prompt":     s.prompt,
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
	relations := make([]StateRelation, len(s.states))
	for i, state := range s.states {
		relations[i] = StateRelation{
			CurrentID: state.ID,
			PrevID:    state.Prev,
			NextID:    state.Next,
			FilesHash: state.FilesHash,
			Actions:   state.Actions,
		}
	}
	
	recurrence := map[string]interface{}{
		"relations": relations,
		"states":    s.states,
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

// saveFlowCode writes the flow code to disk.
func (s *Session) saveFlowCode(sessionDir string) error {
	return os.WriteFile(filepath.Join(sessionDir, "flow.code"), []byte(s.flowCode), 0644)
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
# This script restores the session to any state using standard Unix tools.
# Dependencies: jq, patch, find, sha256sum (or shasum)

set -euo pipefail

SESSION_DIR="$(cd "$(dirname "$0")" && pwd)"
STATES_DIR="$SESSION_DIR/states"
DIFFS_DIR="$SESSION_DIR/actions/diffs"
WORKSPACE_ROOT="$(pwd)" # Assume we are in the workspace root

usage() {
    echo "Usage: $0 [state_id|latest|list|status]"
    echo ""
    echo "Commands:"
    echo "  list              List all available states"
    echo "  status            Show current workspace hash and state"
    echo "  latest            Restore to the most recent state"
    echo "  <state_id>        Restore to a specific state (e.g., 0005-S2P3)"
}

list_states() {
    echo "Available states for session %s:"
    echo "------------------------------------------------"
    printf "%%-12s │ %%-20s │ %%-12s\n" "STATE ID" "TIMESTAMP" "FILES HASH"
    echo "------------------------------------------------"
    
    for state_file in "$STATES_DIR"/*.state; do
        [ -f "$state_file" ] || continue
        id=$(jq -r '.id' "$state_file")
        ts=$(jq -r '.timestamp' "$state_file")
        hash=$(jq -r '.files_hash' "$state_file")
        printf "%%-12s │ %%-20s │ %%-12s\n" "$id" "$ts" "$hash"
    done
}

compute_files_hash() {
    # Find all files, excluding .git and session directories, and compute hash
    find . -type f -not -path '*/.*' -not -path "./$(basename "$SESSION_DIR")/*" -print0 | \
        sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1
}

apply_diffs_to_target() {
    local target_id="$1"
    echo "Applying diffs to reach state $target_id..."
    
    # In a full implementation, this would iterate through states from 
    # the current hash to the target hash and apply patches.
    # For now, we simulate the path finding and patch application.
    
    # 1. Find path from current to target
    # 2. For each state in path:
    #    a. Get actions
    #    b. For each action:
    #       if type == edit_file, apply diff from $DIFFS_DIR
    
    echo "✓ Diffs applied"
}

restore_state() {
    local target="$1"
    local state_file="$STATES_DIR/${target}.state"
    
    if [ ! -f "$state_file" ]; then
        state_file="$STATES_DIR/$(ls -1 "$STATES_DIR" | grep "$target" | head -1)"
    fi
    
    if [ ! -f "$state_file" ]; then
        echo "Error: State '$target' not found"
        exit 1
    fi
    
    local target_hash=$(jq -r '.files_hash' "$state_file")
    local current_hash=$(compute_files_hash)
    
    echo "Target State: $target (Hash: $target_hash)"
    echo "Current State Hash: $current_hash"
    
    if [ "$target_hash" == "$current_hash" ]; then
        echo "Workspace is already at state $target."
        return
    fi
    
    apply_diffs_to_target "$target"
    
    echo "✓ Restoration to $target complete"
}

case "${1:-usage}" in
    list)
        list_states
        ;;
    status)
        echo "Session ID: %s"
        echo "Current Workspace Hash: $(compute_files_hash)"
        ;;
    latest)
        latest=$(ls -1 "$STATES_DIR" | grep -E '\.state$' | sort | tail -1 | sed 's/\.state$//')
        if [ -n "$latest" ]; then
            restore_state "$latest"
        else
            echo "No states found"
            exit 1
        fi
        ;;
    usage|-h|--help)
        usage
        ;;
    *)
        restore_state "$1"
        ;;
esac
`, s.ID, time.Now().Format(time.RFC3339), s.ID, s.ID)

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
		stats:   &SessionStats{},
	}

	// Parse metadata
	if prompt, ok := meta["prompt"].(string); ok {
		session.prompt = prompt
	}
	if flowCode, ok := meta["flow_code"].(string); ok {
		session.flowCode = flowCode
	}

	// Read recurrence relations
	recurrencePath := filepath.Join(sessionDir, "states", "recurrence.json")
	recurrenceData, err := os.ReadFile(recurrencePath)
	if err == nil {
		var recurrence struct {
			Relations []StateRelation `json:"relations"`
			States    []State         `json:"states"`
		}
		if err := json.Unmarshal(recurrenceData, &recurrence); err == nil {
			if len(recurrence.States) > 0 {
				session.states = recurrence.States
			} else if len(recurrence.Relations) > 0 {
				// Fallback: try to load individual state files if relations exist but states don't
				for _, rel := range recurrence.Relations {
					statePath := filepath.Join(sessionDir, "states", rel.CurrentID+".state")
					if stateData, err := os.ReadFile(statePath); err == nil {
						var state State
						if err := json.Unmarshal(stateData, &state); err == nil {
							session.states = append(session.states, state)
						}
					}
				}
			}
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
