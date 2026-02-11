// Package ui implements the terminal UI for obot orchestration.
package ui

import (
	"fmt"
	"io"
	"strings"
	"sync"
)

// ChatShortcut represents a keyboard shortcut in the chat UI.
type ChatShortcut string

const (
	ShortcutApply   ChatShortcut = "a"
	ShortcutDiscard ChatShortcut = "d"
	ShortcutUndo    ChatShortcut = "u"
	ShortcutHelp    ChatShortcut = "?"
	ShortcutCancel  ChatShortcut = "c"
	ShortcutClear   ChatShortcut = "l"
)

// ShortcutInfo provides metadata about a shortcut.
type ShortcutInfo struct {
	Key         ChatShortcut
	Label       string
	Description string
}

// shortcutsTable defines all available shortcuts and their metadata.
var shortcutsTable = []ShortcutInfo{
	{ShortcutApply, "Apply", "Commit the current changes and proceed"},
	{ShortcutDiscard, "Discard", "Reject the current changes and ignore"},
	{ShortcutUndo, "Undo", "Revert the last apply operation"},
	{ShortcutCancel, "Cancel", "Abort the current operation"},
	{ShortcutClear, "Clear", "Clear the action history"},
	{ShortcutHelp, "Help", "Show available keyboard shortcuts"},
}

// ChatHandler manages chat-specific keyboard shortcuts and interactions.
// It tracks action history and provides visual feedback for shortcut triggers.
type ChatHandler struct {
	mu sync.Mutex

	writer io.Writer
	width  int

	// Callbacks for shortcuts
	onApply   func()
	onDiscard func()
	onUndo    func()
	onCancel  func()
	onClear   func()

	// State
	lastAction string
	canUndo    bool
	history    []string
	showHelp   bool
}

// NewChatHandler creates a new chat handler.
func NewChatHandler(writer io.Writer, width int) *ChatHandler {
	return &ChatHandler{
		writer:  writer,
		width:   width,
		history: make([]string, 0),
	}
}

// SetCallbacks sets the core action callbacks.
func (c *ChatHandler) SetCallbacks(apply, discard, undo func()) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.onApply = apply
	c.onDiscard = discard
	c.onUndo = undo
}

// SetExtendedCallbacks sets additional shortcut callbacks for cancel and clear actions.
func (c *ChatHandler) SetExtendedCallbacks(cancel, clear func()) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.onCancel = cancel
	c.onClear = clear
}

// HandleKey processes a single key press if it matches a registered shortcut.
// Returns true if the key was handled as a shortcut.
func (c *ChatHandler) HandleKey(key string) bool {
	c.mu.Lock()
	defer c.mu.Unlock()

	k := ChatShortcut(strings.ToLower(key))
	switch k {
	case ShortcutApply:
		if c.onApply != nil {
			c.recordAction("Apply")
			c.canUndo = true
			c.onApply()
			c.notify("Apply confirmed")
			return true
		}
	case ShortcutDiscard:
		if c.onDiscard != nil {
			c.recordAction("Discard")
			c.canUndo = false
			c.onDiscard()
			c.notify("Discard confirmed")
			return true
		}
	case ShortcutUndo:
		if c.onUndo != nil && c.canUndo {
			c.recordAction("Undo")
			c.canUndo = false
			c.onUndo()
			c.notify("Undo performed")
			return true
		}
	case ShortcutCancel:
		if c.onCancel != nil {
			c.recordAction("Cancel")
			c.onCancel()
			c.notify("Operation cancelled")
			return true
		}
	case ShortcutClear:
		if c.onClear != nil {
			c.recordAction("Clear")
			c.onClear()
			c.history = make([]string, 0)
			c.notify("History cleared")
			return true
		}
	case ShortcutHelp:
		c.showHelp = !c.showHelp
		if c.showHelp {
			c.renderHelp()
		} else {
			c.notify("Help closed")
		}
		return true
	}

	return false
}

// HandleCommand processes a slash command from the TUI input. (Merges item 314 TUI internal cmds)
func (c *ChatHandler) HandleCommand(command string) bool {
	cmd := strings.ToLower(strings.TrimPrefix(command, "/"))
	parts := strings.Fields(cmd)
	if len(parts) == 0 {
		return false
	}

	switch parts[0] {
	case "apply":
		return c.HandleKey(string(ShortcutApply))
	case "discard":
		return c.HandleKey(string(ShortcutDiscard))
	case "undo":
		return c.HandleKey(string(ShortcutUndo))
	case "history":
		fmt.Fprintf(c.writer, "\n%s %s\n", FormatLabelBold("Action History:"), c.RenderHistory(10))
		return true
	case "exit", "quit":
		if c.onCancel != nil {
			c.onCancel()
		}
		return true
	case "help":
		c.renderHelp()
		return true
	}

	return false
}

// recordAction logs an action to history for status display and undo tracking.
func (c *ChatHandler) recordAction(action string) {
	c.lastAction = action
	c.history = append(c.history, action)
	if len(c.history) > 100 {
		c.history = c.history[1:]
	}
}

// notify displays a brief notification about the shortcut action in the terminal.
func (c *ChatHandler) notify(message string) {
	fmt.Fprintf(c.writer, "\r%s %s%s\n", FormatLabelBold("Shortcut:"), message, ClearToEnd)
}

// renderHelp displays a formatted table of available shortcuts.
func (c *ChatHandler) renderHelp() {
	fmt.Fprintf(c.writer, "\n%s\n", FormatLabelBold("Keyboard Shortcuts:"))
	for _, s := range shortcutsTable {
		status := ""
		if s.Key == ShortcutUndo && !c.canUndo {
			status = FormatValueMuted(" (unavailable)")
		}
		fmt.Fprintf(c.writer, "  %s %-10s %s%s\n",
			FormatLabelBold("["+string(s.Key)+"]"),
			s.Label,
			FormatValue(s.Description),
			status)
	}
	fmt.Fprintf(c.writer, "\n")
}

// RenderShortcuts returns a compact string representing the available shortcuts for the status bar.
func (c *ChatHandler) RenderShortcuts() string {
	c.mu.Lock()
	defer c.mu.Unlock()

	var sb strings.Builder
	sb.WriteString(FormatLabel("Shortcuts:"))
	sb.WriteString(" ")

	// Primary shortcuts for the status bar
	mainShortcuts := []struct {
		k ChatShortcut
		l string
	}{
		{ShortcutApply, "Apply"},
		{ShortcutDiscard, "Discard"},
		{ShortcutUndo, "Undo"},
	}

	for i, s := range mainShortcuts {
		if s.k == ShortcutUndo && !c.canUndo {
			sb.WriteString(FormatValueMuted("[" + string(s.k) + "] " + s.l))
		} else {
			sb.WriteString(FormatLabelBold("[" + string(s.k) + "]"))
			sb.WriteString(" " + s.l)
		}
		if i < len(mainShortcuts)-1 {
			sb.WriteString("  ")
		}
	}

	sb.WriteString(FormatValueMuted("  [?] Help"))
	return sb.String()
}

// RenderStatus returns a status line containing the last action and recent history.
func (c *ChatHandler) RenderStatus() string {
	c.mu.Lock()
	defer c.mu.Unlock()

	if len(c.history) == 0 {
		return FormatValueMuted("No recent activity")
	}

	last := c.history[len(c.history)-1]
	historyLimit := 3
	start := len(c.history) - historyLimit
	if start < 0 {
		start = 0
	}

	breadcrumbs := strings.Join(c.history[start:], " → ")
	return fmt.Sprintf("%s %s %s %s",
		FormatLabel("Last:"), FormatValue(last),
		FormatLabel("| History:"), FormatValueMuted(breadcrumbs))
}

// SetCanUndo updates the undo availability state.
func (c *ChatHandler) SetCanUndo(can bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.canUndo = can
}

// RenderHistory returns a formatted string of the action history.
func (c *ChatHandler) RenderHistory(limit int) string {
	c.mu.Lock()
	defer c.mu.Unlock()

	if len(c.history) == 0 {
		return FormatValueMuted("No history yet.")
	}

	start := len(c.history) - limit
	if start < 0 {
		start = 0
	}

	return FormatValue(strings.Join(c.history[start:], " → "))
}

// Reset clears the handler's internal state.
func (c *ChatHandler) Reset() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.history = make([]string, 0)
	c.canUndo = false
	c.lastAction = ""
	c.showHelp = false
}

// GetLastAction returns the name of the most recently performed action.
func (c *ChatHandler) GetLastAction() string {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.lastAction
}
