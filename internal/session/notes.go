// Package session implements session persistence for obot orchestration.
package session

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// NoteDestination identifies where a note should be routed.
type NoteDestination string

const (
	// DestinationOrchestrator for notes intended for the orchestrator
	DestinationOrchestrator NoteDestination = "orchestrator"
	// DestinationAgent for notes intended for the agent
	DestinationAgent NoteDestination = "agent"
	// DestinationHuman for notes from human consultation
	DestinationHuman NoteDestination = "human"
)

// NotesManager handles session notes persistence and management.
type NotesManager struct {
	mu        sync.Mutex
	baseDir   string
	sessionID string

	notes map[NoteDestination][]Note
}

// NewNotesManager creates a new notes manager for a specific session.
func NewNotesManager(baseDir, sessionID string) *NotesManager {
	return &NotesManager{
		baseDir:   baseDir,
		sessionID: sessionID,
		notes: map[NoteDestination][]Note{
			DestinationOrchestrator: make([]Note, 0),
			DestinationAgent:        make([]Note, 0),
			DestinationHuman:        make([]Note, 0),
		},
	}
}

// Add adds a new note to the specified destination and saves it.
func (nm *NotesManager) Add(destination NoteDestination, content, source string) (Note, error) {
	nm.mu.Lock()
	defer nm.mu.Unlock()

	// Load existing notes first to ensure we have the latest
	if err := nm.loadLocked(); err != nil && !os.IsNotExist(err) {
		return Note{}, err
	}

	note := Note{
		ID:        nm.generateNoteID(),
		Timestamp: time.Now(),
		Content:   content,
		Source:    source,
		Reviewed:  false,
	}

	nm.notes[destination] = append(nm.notes[destination], note)

	if err := nm.saveLocked(); err != nil {
		return note, err
	}

	return note, nil
}

// generateNoteID generates a unique note ID ("N" + Unix nanosecond timestamp).
func (nm *NotesManager) generateNoteID() string {
	return fmt.Sprintf("N%d", time.Now().UnixNano())
}

// GetNotes returns all notes for a specific destination.
func (nm *NotesManager) GetNotes(destination NoteDestination) []Note {
	nm.mu.Lock()
	defer nm.mu.Unlock()
	
	notes, ok := nm.notes[destination]
	if !ok {
		return nil
	}
	
	result := make([]Note, len(notes))
	copy(result, notes)
	return result
}

// GetAllUnreviewed returns all notes across all destinations where Reviewed is false.
func (nm *NotesManager) GetAllUnreviewed() []Note {
	nm.mu.Lock()
	defer nm.mu.Unlock()

	var unreviewed []Note
	for _, notes := range nm.notes {
		for _, n := range notes {
			if !n.Reviewed {
				unreviewed = append(unreviewed, n)
			}
		}
	}
	return unreviewed
}

// GetUnreviewed returns all notes with Reviewed=false for a destination.
func (nm *NotesManager) GetUnreviewed(destination NoteDestination) []Note {
	nm.mu.Lock()
	defer nm.mu.Unlock()

	notes, ok := nm.notes[destination]
	if !ok {
		return nil
	}

	var unreviewed []Note
	for _, n := range notes {
		if !n.Reviewed {
			unreviewed = append(unreviewed, n)
		}
	}
	return unreviewed
}

// MarkReviewed marks one or more notes as reviewed and saves.
func (nm *NotesManager) MarkReviewed(destination NoteDestination, noteIDs []string) error {
	nm.mu.Lock()
	defer nm.mu.Unlock()

	notes, ok := nm.notes[destination]
	if !ok {
		return nil
	}

	modified := false
	idMap := make(map[string]bool)
	for _, id := range noteIDs {
		idMap[id] = true
	}

	for i := range notes {
		if idMap[notes[i].ID] {
			notes[i].Reviewed = true
			modified = true
		}
	}

	if modified {
		return nm.saveLocked()
	}
	return nil
}

// Save saves all notes to disk.
func (nm *NotesManager) Save() error {
	nm.mu.Lock()
	defer nm.mu.Unlock()
	return nm.saveLocked()
}

func (nm *NotesManager) saveLocked() error {
	notesDir := filepath.Join(nm.baseDir, nm.sessionID, "notes")
	if err := os.MkdirAll(notesDir, 0755); err != nil {
		return fmt.Errorf("failed to create notes directory: %w", err)
	}

	for dest, notes := range nm.notes {
		// Use {destination}.md format as per implementation spec
		filename := fmt.Sprintf("%s.md", dest)
		if err := nm.writeJSON(filepath.Join(notesDir, filename), notes); err != nil {
			return err
		}
	}

	return nil
}

// Load loads notes from disk.
func (nm *NotesManager) Load() error {
	nm.mu.Lock()
	defer nm.mu.Unlock()
	return nm.loadLocked()
}

func (nm *NotesManager) loadLocked() error {
	notesDir := filepath.Join(nm.baseDir, nm.sessionID, "notes")

	for dest := range nm.notes {
		// Use {destination}.md format as per implementation spec
		filename := fmt.Sprintf("%s.md", dest)
		var notes []Note
		if err := nm.readJSON(filepath.Join(notesDir, filename), &notes); err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return err
		}
		nm.notes[dest] = notes
	}

	return nil
}

// writeJSON writes data as JSON to a file.
func (nm *NotesManager) writeJSON(path string, data interface{}) error {
	content, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal JSON: %w", err)
	}
	return os.WriteFile(path, content, 0644)
}

// readJSON reads data from a JSON file.
func (nm *NotesManager) readJSON(path string, data interface{}) error {
	content, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(content, data); err != nil {
		return fmt.Errorf("failed to unmarshal JSON from %s: %w", path, err)
	}
	return nil
}

// Clear clears all notes and saves.
func (nm *NotesManager) Clear() error {
	nm.mu.Lock()
	defer nm.mu.Unlock()
	
	for dest := range nm.notes {
		nm.notes[dest] = make([]Note, 0)
	}
	
	return nm.saveLocked()
}

// GetNoteCount returns the total number of notes.
func (nm *NotesManager) GetNoteCount() int {
	nm.mu.Lock()
	defer nm.mu.Unlock()
	
	count := 0
	for _, notes := range nm.notes {
		count += len(notes)
	}
	return count
}
