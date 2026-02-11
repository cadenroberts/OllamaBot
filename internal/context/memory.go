package context

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// MemoryEntry represents a single conversation memory entry.
type MemoryEntry struct {
	Role      string    `json:"role"`
	Content   string    `json:"content"`
	Timestamp time.Time `json:"timestamp"`
	Tokens    int       `json:"tokens"`
}

// Memory stores conversation history with token accounting.
type Memory struct {
	mu      sync.Mutex
	entries []MemoryEntry
	path    string
}

// NewMemory creates a new memory store.
func NewMemory(storePath string) *Memory {
	m := &Memory{
		entries: make([]MemoryEntry, 0),
		path:    storePath,
	}
	_ = m.load()
	return m
}

// Add appends a message to conversation memory.
func (m *Memory) Add(role, content string) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.entries = append(m.entries, MemoryEntry{
		Role:      role,
		Content:   content,
		Timestamp: time.Now(),
		Tokens:    CountTokens(content),
	})
}

// GetRecent returns the most recent entries that fit within maxTokens.
func (m *Memory) GetRecent(maxTokens int) []MemoryEntry {
	m.mu.Lock()
	defer m.mu.Unlock()

	result := make([]MemoryEntry, 0)
	usedTokens := 0

	// Walk backward from most recent
	for i := len(m.entries) - 1; i >= 0; i-- {
		entry := m.entries[i]
		if usedTokens+entry.Tokens > maxTokens {
			break
		}
		result = append([]MemoryEntry{entry}, result...)
		usedTokens += entry.Tokens
	}
	return result
}

// TotalTokens returns total tokens across all entries.
func (m *Memory) TotalTokens() int {
	m.mu.Lock()
	defer m.mu.Unlock()

	total := 0
	for _, e := range m.entries {
		total += e.Tokens
	}
	return total
}

// Clear removes all entries.
func (m *Memory) Clear() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.entries = make([]MemoryEntry, 0)
}

// Save persists memory to disk.
func (m *Memory) Save() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.path == "" {
		return nil
	}

	dir := filepath.Dir(m.path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}

	data, err := json.MarshalIndent(m.entries, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(m.path, data, 0644)
}

// load reads memory from disk.
func (m *Memory) load() error {
	if m.path == "" {
		return nil
	}

	data, err := os.ReadFile(m.path)
	if err != nil {
		return nil // not an error if file doesn't exist
	}

	return json.Unmarshal(data, &m.entries)
}
