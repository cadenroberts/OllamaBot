package ui

import (
	"testing"
)

func TestHistoryNavigationWorks(t *testing.T) {
	h := NewCommandHistory()
	h.Clear() // Start fresh

	// Add some commands
	h.Add("command 1")
	h.Add("command 2")
	h.Add("command 3")

	// Test navigating up
	cmd, ok := h.NavigateUp()
	if !ok || cmd != "command 3" {
		t.Errorf("Expected 'command 3', got '%s'", cmd)
	}

	cmd, ok = h.NavigateUp()
	if !ok || cmd != "command 2" {
		t.Errorf("Expected 'command 2', got '%s'", cmd)
	}

	cmd, ok = h.NavigateUp()
	if !ok || cmd != "command 1" {
		t.Errorf("Expected 'command 1', got '%s'", cmd)
	}

	// Should stay at first command
	cmd, ok = h.NavigateUp()
	if !ok || cmd != "command 1" {
		t.Errorf("Expected 'command 1' (clamped), got '%s'", cmd)
	}

	// Test navigating down
	cmd, ok = h.NavigateDown()
	if !ok || cmd != "command 2" {
		t.Errorf("Expected 'command 2', got '%s'", cmd)
	}

	cmd, ok = h.NavigateDown()
	if !ok || cmd != "command 3" {
		t.Errorf("Expected 'command 3', got '%s'", cmd)
	}

	// Should return empty and ok=true at the end
	cmd, ok = h.NavigateDown()
	if !ok || cmd != "" {
		t.Errorf("Expected empty string at end of history, got '%s'", cmd)
	}

	// Cleanup
	h.Clear()
}

func TestHistoryPersistence(t *testing.T) {
	h := NewCommandHistory()
	h.Clear()

	h.Add("persistent command")
	path := h.path

	// Create a new history object to load from disk
	h2 := NewCommandHistory()
	h2.path = path // Ensure same path
	h2.load()

	cmd, ok := h2.NavigateUp()
	if !ok || cmd != "persistent command" {
		t.Errorf("Expected 'persistent command' from disk, got '%s'", cmd)
	}

	h.Clear()
}
