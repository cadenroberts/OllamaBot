package ui

import (
	"bytes"
	"strings"
	"testing"
)

func TestChatInterfaceResponsive(t *testing.T) {
	var buf bytes.Buffer
	width := 80
	ch := NewChatHandler(&buf, width)

	// Test initial state
	shortcuts := ch.RenderShortcuts()
	if !strings.Contains(shortcuts, "[a]") || !strings.Contains(shortcuts, "Apply") {
		t.Errorf("Expected shortcuts to contain [a] Apply, got: %s", shortcuts)
	}

	// Test apply shortcut
	applied := false
	ch.SetCallbacks(func() { applied = true }, nil, nil)

	if !ch.HandleKey("a") {
		t.Errorf("HandleKey('a') should return true")
	}

	if !applied {
		t.Errorf("Apply callback was not called")
	}

	// Test undo state
	if !strings.Contains(ch.RenderShortcuts(), "Undo") {
		t.Errorf("Expected shortcuts to contain Undo after apply")
	}

	// Test discard shortcut
	discarded := false
	ch.SetCallbacks(nil, func() { discarded = true }, nil)

	if !ch.HandleKey("d") {
		t.Errorf("HandleKey('d') should return true")
	}

	if !discarded {
		t.Errorf("Discard callback was not called")
	}

	// Test case insensitivity
	applied = false
	ch.SetCallbacks(func() { applied = true }, nil, nil)
	if !ch.HandleKey("A") {
		t.Errorf("HandleKey('A') should be case-insensitive")
	}
	if !applied {
		t.Errorf("Apply callback was not called for 'A'")
	}
}

func TestChatCommandHandling(t *testing.T) {
	var buf bytes.Buffer
	width := 80
	ch := NewChatHandler(&buf, width)

	// Test /apply command
	applied := false
	ch.SetCallbacks(func() { applied = true }, nil, nil)
	if !ch.HandleCommand("/apply") {
		t.Errorf("HandleCommand('/apply') should return true")
	}
	if !applied {
		t.Errorf("Apply callback not called for /apply")
	}

	// Test /history command
	if !ch.HandleCommand("/history") {
		t.Errorf("HandleCommand('/history') should return true")
	}
	if !strings.Contains(buf.String(), "Action History") {
		t.Errorf("Output missing 'Action History', got: %s", buf.String())
	}
	buf.Reset()

	// Test /help command
	if !ch.HandleCommand("/help") {
		t.Errorf("HandleCommand('/help') should return true")
	}
	if !strings.Contains(buf.String(), "Keyboard Shortcuts") {
		t.Errorf("Output missing 'Keyboard Shortcuts', got: %s", buf.String())
	}
}

