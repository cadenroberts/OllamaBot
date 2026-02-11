// Package session implements session persistence for obot orchestration.
package session

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/croberts/obot/internal/orchestrate"
)

// Manager handles session management and persistence.
type Manager struct {
	mu sync.Mutex

	baseDir   string
	currentID string
	session   *Session
}

// NewManager creates a new session manager.
func NewManager(baseDir string) *Manager {
	if baseDir == "" {
		homeDir, _ := os.UserHomeDir()
		baseDir = filepath.Join(homeDir, ".config", "ollamabot", "sessions")
	}
	return &Manager{
		baseDir: baseDir,
	}
}

// Start initializes a new session.
func (m *Manager) Start(prompt string) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	session := NewSessionWithBaseDir(m.baseDir)
	session.SetPrompt(prompt)
	m.session = session
	m.currentID = session.GetID()

	// Create session directory structure
	sessionDir := filepath.Join(m.baseDir, m.currentID)
	dirs := []string{
		sessionDir,
		filepath.Join(sessionDir, "states"),
		filepath.Join(sessionDir, "checkpoints"),
		filepath.Join(sessionDir, "notes"),
		filepath.Join(sessionDir, "metrics"),
		filepath.Join(sessionDir, "logs"),
	}

	for _, dir := range dirs {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return "", fmt.Errorf("failed to create directory %s: %w", dir, err)
		}
	}

	if err := m.session.Save(); err != nil {
		return "", fmt.Errorf("failed to save initial session: %w", err)
	}

	return m.currentID, nil
}

// AddState creates and persists a new session state.
func (m *Manager) AddState(schedule orchestrate.ScheduleID, process orchestrate.ProcessID, actions []string) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.session == nil {
		return "", fmt.Errorf("no active session")
	}

	stateID := m.session.AddState(schedule, process, actions)
	return stateID, nil
}

// Checkpoint performs periodic state saving, including recurrence relations.
func (m *Manager) Checkpoint() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.session == nil {
		return fmt.Errorf("no active session to checkpoint")
	}

	if err := m.session.Save(); err != nil {
		return err
	}

	return m.saveRecurrenceLocked()
}

// saveRecurrence builds the state relation array and writes it to recurrence.json.
//
// PROOF:
// - ZERO-HIT: No exported saveRecurrence implementation.
// - POSITIVE-HIT: saveRecurrence method in internal/session/manager.go.
func (m *Manager) saveRecurrence() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.session == nil {
		return fmt.Errorf("no active session to save recurrence")
	}

	return m.saveRecurrenceLocked()
}

// saveRecurrenceLocked builds the state relation array and writes it to recurrence.json.
// It assumes the caller holds the manager lock.
func (m *Manager) saveRecurrenceLocked() error {
	states := m.session.GetAllStates()
	relations := make([]StateRelation, len(states))

	for i, state := range states {
		relations[i] = StateRelation{
			CurrentID: state.ID,
			PrevID:    state.Prev,
			NextID:    state.Next,
			FilesHash: state.FilesHash,
			Actions:   state.Actions,
		}
	}

	sessionDir := filepath.Join(m.baseDir, m.currentID)
	recurrencePath := filepath.Join(sessionDir, "states", "recurrence.json")
	
	return writeJSON(recurrencePath, map[string]interface{}{
		"relations": relations,
		"states":    states,
	})
}

// Load loads an existing session.
func (m *Manager) Load(sessionID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	session, err := Load(m.baseDir, sessionID)
	if err != nil {
		return err
	}

	m.session = session
	m.currentID = sessionID
	return nil
}

// GetCurrentSession returns the active session.
func (m *Manager) GetCurrentSession() *Session {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.session
}

// GetSessionID returns the current session ID.
func (m *Manager) GetSessionID() string {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.currentID
}

// GetBaseDir returns the sessions base directory.
func (m *Manager) GetBaseDir() string {
	return m.baseDir
}

// generateSessionID generates a unique session ID based on Unix nanosecond timestamp.
func (m *Manager) generateSessionID() string {
	return fmt.Sprintf("S%d", time.Now().UnixNano())
}
