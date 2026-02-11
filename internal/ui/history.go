package ui

import (
	"bufio"
	"os"
	"path/filepath"
	"sync"
)

// CommandHistory manages a list of previous commands for terminal navigation.
type CommandHistory struct {
	mu       sync.Mutex
	commands []string
	index    int
	path     string
	limit    int
}

// NewCommandHistory creates a new history manager with persistent storage.
func NewCommandHistory() *CommandHistory {
	h := &CommandHistory{
		commands: make([]string, 0),
		index:    -1,
		limit:    1000,
	}

	// Determine path for history file
	home, err := os.UserHomeDir()
	if err == nil {
		h.path = filepath.Join(home, ".config", "ollamabot", "history.txt")
		h.load()
	}

	return h
}

// Add appends a new command to the history.
func (h *CommandHistory) Add(cmd string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if cmd == "" {
		return
	}

	// Avoid adding sequential duplicates
	if len(h.commands) > 0 && h.commands[len(h.commands)-1] == cmd {
		h.index = len(h.commands)
		return
	}

	h.commands = append(h.commands, cmd)

	// Enforce limit
	if len(h.commands) > h.limit {
		h.commands = h.commands[len(h.commands)-h.limit:]
	}

	h.index = len(h.commands)
	h.save()
}

// NavigateUp returns the previous command from history relative to the current index.
func (h *CommandHistory) NavigateUp() (string, bool) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if len(h.commands) == 0 {
		return "", false
	}

	if h.index > 0 {
		h.index--
	} else {
		h.index = 0
	}

	return h.commands[h.index], true
}

// NavigateDown returns the next command from history relative to the current index.
func (h *CommandHistory) NavigateDown() (string, bool) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if len(h.commands) == 0 {
		return "", false
	}

	if h.index < len(h.commands)-1 {
		h.index++
		return h.commands[h.index], true
	}

	// Reached the end of history
	h.index = len(h.commands)
	return "", true
}

// Clear removes all history entries.
func (h *CommandHistory) Clear() {
	h.mu.Lock()
	defer h.mu.Unlock()

	h.commands = make([]string, 0)
	h.index = -1
	if h.path != "" {
		_ = os.Remove(h.path)
	}
}

// ResetIndex resets the navigation pointer to the end of history.
func (h *CommandHistory) ResetIndex() {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.index = len(h.commands)
}

// load reads history from the configuration file.
func (h *CommandHistory) load() {
	if h.path == "" {
		return
	}

	f, err := os.Open(h.path)
	if err != nil {
		return
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		cmd := scanner.Text()
		if cmd != "" {
			h.commands = append(h.commands, cmd)
		}
	}

	// Enforce limit on load
	if len(h.commands) > h.limit {
		h.commands = h.commands[len(h.commands)-h.limit:]
	}

	h.index = len(h.commands)
}

// save writes history to the configuration file.
func (h *CommandHistory) save() {
	if h.path == "" {
		return
	}

	// Ensure directory exists
	dir := filepath.Dir(h.path)
	_ = os.MkdirAll(dir, 0755)

	f, err := os.Create(h.path)
	if err != nil {
		return
	}
	defer f.Close()

	writer := bufio.NewWriter(f)
	for _, cmd := range h.commands {
		_, _ = writer.WriteString(cmd + "\n")
	}
	_ = writer.Flush()
}

// GetAll returns a copy of all history entries.
func (h *CommandHistory) GetAll() []string {
	h.mu.Lock()
	defer h.mu.Unlock()
	
	result := make([]string, len(h.commands))
	copy(result, h.commands)
	return result
}
