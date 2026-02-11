package session

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/croberts/obot/internal/orchestrate"
)

func TestSessionManager(t *testing.T) {
	// Setup temporary base directory
	tmpDir, err := os.MkdirTemp("", "session-mgr-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	mgr := NewManager(tmpDir)

	// Test Start
	prompt := "Test prompt"
	sid, err := mgr.Start(prompt)
	if err != nil {
		t.Fatalf("Start failed: %v", err)
	}
	if sid == "" {
		t.Fatal("Expected non-empty session ID")
	}

	// Verify session directory structure
	sessionDir := filepath.Join(tmpDir, sid)
	dirs := []string{"states", "checkpoints", "notes", "metrics", "logs"}
	for _, d := range dirs {
		if _, err := os.Stat(filepath.Join(sessionDir, d)); os.IsNotExist(err) {
			t.Errorf("Expected directory %s to exist", d)
		}
	}

	// Verify initial save
	if _, err := os.Stat(filepath.Join(sessionDir, "meta.json")); os.IsNotExist(err) {
		t.Error("Expected meta.json to exist")
	}

	// Test AddState
	session := mgr.GetCurrentSession()
	stateID := session.AddState(orchestrate.ScheduleKnowledge, orchestrate.Process1, []string{"action1"})
	if stateID == "" {
		t.Fatal("Expected non-empty state ID")
	}

	// Test Checkpoint
	err = mgr.Checkpoint()
	if err != nil {
		t.Fatalf("Checkpoint failed: %v", err)
	}

	// Verify state file
	statePath := filepath.Join(sessionDir, "states", stateID+".state")
	if _, err := os.Stat(statePath); os.IsNotExist(err) {
		t.Errorf("Expected state file %s to exist", statePath)
	}

	// Test Load
	mgr2 := NewManager(tmpDir)
	err = mgr2.Load(sid)
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	s2 := mgr2.GetCurrentSession()
	if s2.ID != sid {
		t.Errorf("Expected session ID %s, got %s", sid, s2.ID)
	}
	if s2.GetPrompt() != prompt {
		t.Errorf("Expected prompt '%s', got '%s'", prompt, s2.GetPrompt())
	}
	if len(s2.states) != 1 {
		t.Errorf("Expected 1 state, got %d", len(s2.states))
	}
}
