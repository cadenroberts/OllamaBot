package integration

import (
	"bytes"
	"strings"
	"testing"

	"github.com/croberts/obot/internal/ui"
)

func TestApplyDiscardWorkflow(t *testing.T) {
	var stdout bytes.Buffer
	stdin := strings.NewReader("")
	
	app := ui.NewApp(stdin, &stdout, &stdout, nil, "1.0.0")

	// State trackers
	applied := false
	discarded := false
	undone := false

	// Set callbacks
	app.SetShortcutCallbacks(
		func() { applied = true },
		func() { discarded = true },
		func() { undone = true },
	)

	// Test Apply
	if !app.HandleShortcutKey("a") {
		t.Errorf("HandleShortcutKey('a') failed")
	}
	if !applied {
		t.Errorf("Apply callback not called")
	}
	if !strings.Contains(stdout.String(), "Apply") {
		t.Errorf("Output missing 'Apply' notification: %s", stdout.String())
	}
	stdout.Reset()

	// Test Undo after Apply
	if !app.HandleShortcutKey("u") {
		t.Errorf("HandleShortcutKey('u') failed")
	}
	if !undone {
		t.Errorf("Undo callback not called")
	}
	if !strings.Contains(stdout.String(), "Undo") {
		t.Errorf("Output missing 'Undo' notification")
	}
	stdout.Reset()

	// Test Discard
	if !app.HandleShortcutKey("d") {
		t.Errorf("HandleShortcutKey('d') failed")
	}
	if !discarded {
		t.Errorf("Discard callback not called")
	}
	if !strings.Contains(stdout.String(), "Discard") {
		t.Errorf("Output missing 'Discard' notification")
	}
	stdout.Reset()

	// Test Undo after Discard (should be disabled)
	undone = false
	if app.HandleShortcutKey("u") {
		t.Errorf("HandleShortcutKey('u') should have failed after discard")
	}
	if undone {
		t.Errorf("Undo callback should not have been called after discard")
	}
}
