package session

import (
	"os"
	"path/filepath"
	"testing"
)

func TestNotesManager(t *testing.T) {
	// Setup temporary base directory
	tmpDir, err := os.MkdirTemp("", "notes-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	sessionID := "test-session"
	nm := NewNotesManager(tmpDir, sessionID)

	// Test Add
	note, err := nm.Add(DestinationOrchestrator, "Test note", "user")
	if err != nil {
		t.Fatalf("Add failed: %v", err)
	}
	if note.Content != "Test note" {
		t.Errorf("Expected content 'Test note', got '%s'", note.Content)
	}

	// Test GetNotes
	notes := nm.GetNotes(DestinationOrchestrator)
	if len(notes) != 1 {
		t.Errorf("Expected 1 note, got %d", len(notes))
	}

	// Test persistence
	nm2 := NewNotesManager(tmpDir, sessionID)
	err = nm2.Load()
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}
	notes2 := nm2.GetNotes(DestinationOrchestrator)
	if len(notes2) != 1 || notes2[0].Content != "Test note" {
		t.Errorf("Persistence failed: expected 1 note with 'Test note', got %v", notes2)
	}

	// Test MarkReviewed
	err = nm2.MarkReviewed(DestinationOrchestrator, []string{note.ID})
	if err != nil {
		t.Fatalf("MarkReviewed failed: %v", err)
	}

	unreviewed := nm2.GetUnreviewed(DestinationOrchestrator)
	if len(unreviewed) != 0 {
		t.Errorf("Expected 0 unreviewed notes, got %d", len(unreviewed))
	}
}

func TestNotesFilenames(t *testing.T) {
	tmpDir, _ := os.MkdirTemp("", "notes-filename-test")
	defer os.RemoveAll(tmpDir)
	
	sessionID := "test-session"
	nm := NewNotesManager(tmpDir, sessionID)
	nm.Add(DestinationAgent, "Agent note", "system")
	
	// Verify filename format <dest>.md
	expectedPath := filepath.Join(tmpDir, sessionID, "notes", "agent.md")
	if _, err := os.Stat(expectedPath); os.IsNotExist(err) {
		t.Errorf("Expected file %s to exist", expectedPath)
	}
}
