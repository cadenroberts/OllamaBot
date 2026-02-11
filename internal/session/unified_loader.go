// Package session - unified backwards-compatible session loading
package session

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// LoadAnySession attempts to load a session in either format (UnifiedSession or legacy USFSession).
// It returns a UnifiedSession regardless of the source format.
// This function provides backwards compatibility during the migration period.
func LoadAnySession(sessionID string) (*UnifiedSession, error) {
	// Try UnifiedSession format first (preferred)
	unified, err := LoadUSF(sessionID)
	if err == nil {
		return unified, nil
	}

	// Try legacy USFSession format
	usfSession, err := LoadUSFSession("", sessionID)
	if err != nil {
		return nil, fmt.Errorf("session %s not found in either format: %w", sessionID, err)
	}

	// Convert USFSession to UnifiedSession
	return convertUSFToUnified(usfSession), nil
}

// ListAllSessions returns all session IDs from both formats (UnifiedSession and USFSession).
// Duplicates are removed (sessionID is unique across both formats).
func ListAllSessions() ([]string, error) {
	seen := make(map[string]bool)
	var result []string

	// List UnifiedSession format
	unified, err := ListUSFSessions()
	if err == nil {
		for _, sid := range unified {
			if !seen[sid] {
				result = append(result, sid)
				seen[sid] = true
			}
		}
	}

	// List legacy USFSession format
	legacy, err := ListUSFSessionIDs("")
	if err == nil {
		for _, sid := range legacy {
			if !seen[sid] {
				result = append(result, sid)
				seen[sid] = true
			}
		}
	}

	return result, nil
}

// SaveAnySession saves a UnifiedSession and auto-migrates legacy USFSession if present.
// After saving in UnifiedSession format, it removes the old USFSession directory if found.
func SaveAnySession(session *UnifiedSession) error {
	// Save in UnifiedSession format
	if err := SaveUSF(session); err != nil {
		return err
	}

	// Check if there's a legacy USFSession directory and clean it up
	homeDir, _ := os.UserHomeDir()
	legacyDir := filepath.Join(homeDir, ".config", "ollamabot", "sessions", session.SessionID)
	legacyFile := filepath.Join(legacyDir, "session.usf")
	
	if _, err := os.Stat(legacyFile); err == nil {
		// Legacy session exists - rename the directory to mark it as migrated
		backupDir := filepath.Join(homeDir, ".config", "ollamabot", "sessions", ".migrated_"+session.SessionID)
		_ = os.Rename(legacyDir, backupDir)
	}

	return nil
}

// convertUSFToUnified converts a legacy USFSession to the current UnifiedSession format.
func convertUSFToUnified(usf *USFSession) *UnifiedSession {
	unified := &UnifiedSession{
		Version:        "1.0",
		SessionID:      usf.SessionID,
		CreatedAt:      usf.CreatedAt,
		UpdatedAt:      usf.UpdatedAt,
		PlatformOrigin: usf.Platform,
		Task: USFTask{
			Description:   usf.Task.Prompt,
			Intent:        "",
			QualityPreset: "",
			Status:        usf.Task.Status,
		},
		Workspace: USFWorkspace{
			Path:      usf.Workspace.Path,
			GitBranch: usf.Workspace.GitBranch,
			GitCommit: usf.Workspace.GitCommit,
		},
		Orchestration: USFOrchestration{
			FlowCode:        usf.OrchestrationState.FlowCode,
			CurrentSchedule: int(usf.OrchestrationState.Schedule),
			CurrentProcess:  int(usf.OrchestrationState.Process),
		},
		Steps:       make([]USFStep, 0),
		Checkpoints: make([]USFCheckpoint, 0),
	}

	// Convert history to steps
	for _, hist := range usf.History {
		unified.Steps = append(unified.Steps, USFStep{
			StepNumber: hist.Sequence,
			ToolID:     fmt.Sprintf("S%dP%d", hist.Schedule, hist.Process),
			Success:    true,
			Timestamp:  hist.Timestamp,
		})
	}

	// Convert checkpoints
	for _, cp := range usf.Checkpoints {
		unified.Checkpoints = append(unified.Checkpoints, USFCheckpoint{
			ID:        cp.ID,
			Name:      cp.Name,
			GitCommit: "", // Not available in legacy format
			FlowCode:  usf.OrchestrationState.FlowCode,
			Timestamp: cp.Timestamp,
		})
	}

	// Convert stats
	unified.Stats = USFStats{
		TotalTokens:     int(usf.Stats.TotalTokens),
		DurationSeconds: usf.Stats.DurationSeconds,
		FilesModified:   len(usf.FilesModified),
	}

	return unified
}

// MigrateSession explicitly converts a legacy USFSession to UnifiedSession format.
// It loads the session, converts it, saves in the new format, and archives the old format.
// Returns the number of sessions migrated.
func MigrateAllSessions() (int, error) {
	// Get legacy sessions
	legacySessions, err := ListUSFSessionIDs("")
	if err != nil {
		return 0, fmt.Errorf("failed to list legacy sessions: %w", err)
	}

	migrated := 0
	for _, sessionID := range legacySessions {
		// Check if already exists in UnifiedSession format
		if _, err := LoadUSF(sessionID); err == nil {
			// Already migrated, just clean up legacy
			homeDir, _ := os.UserHomeDir()
			legacyDir := filepath.Join(homeDir, ".config", "ollamabot", "sessions", sessionID)
			backupDir := filepath.Join(homeDir, ".config", "ollamabot", "sessions", ".migrated_"+sessionID)
			_ = os.Rename(legacyDir, backupDir)
			migrated++
			continue
		}

		// Load legacy format
		usfSession, err := LoadUSFSession("", sessionID)
		if err != nil {
			continue // Skip if we can't load it
		}

		// Convert and save
		unified := convertUSFToUnified(usfSession)
		if err := SaveAnySession(unified); err != nil {
			continue // Skip if we can't save
		}

		migrated++
	}

	return migrated, nil
}

// GetSessionFormat returns which format a session is stored in: "unified", "legacy", or "not_found".
func GetSessionFormat(sessionID string) string {
	// Check UnifiedSession format
	if _, err := LoadUSF(sessionID); err == nil {
		return "unified"
	}

	// Check legacy USFSession format
	if _, err := LoadUSFSession("", sessionID); err == nil {
		return "legacy"
	}

	return "not_found"
}

// IsLegacySession checks if a session exists only in legacy USFSession format.
func IsLegacySession(sessionID string) bool {
	return GetSessionFormat(sessionID) == "legacy"
}

// SessionInfo holds metadata about a session in any format.
type SessionInfo struct {
	ID          string
	Format      string // "unified" or "legacy"
	Description string
	Platform    string
	CreatedAt   string
	UpdatedAt   string
	StepCount   int
}

// GetSessionInfo returns unified metadata about a session regardless of format.
func GetSessionInfo(sessionID string) (*SessionInfo, error) {
	// Try loading via unified loader (handles both formats)
	session, err := LoadAnySession(sessionID)
	if err != nil {
		return nil, err
	}

	format := "unified"
	if IsLegacySession(sessionID) {
		format = "legacy"
	}

	return &SessionInfo{
		ID:          session.SessionID,
		Format:      format,
		Description: session.Task.Description,
		Platform:    session.PlatformOrigin,
		CreatedAt:   session.CreatedAt.Format("2006-01-02 15:04:05"),
		UpdatedAt:   session.UpdatedAt.Format("2006-01-02 15:04:05"),
		StepCount:   len(session.Steps),
	}, nil
}

// detectAndParseSession attempts to parse a session file and detect its format.
func detectAndParseSession(path string) (*UnifiedSession, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	// Try UnifiedSession first
	var unified UnifiedSession
	if err := json.Unmarshal(data, &unified); err == nil {
		if unified.SessionID != "" {
			return &unified, nil
		}
	}

	// Try USFSession
	var usf USFSession
	if err := json.Unmarshal(data, &usf); err == nil {
		if usf.SessionID != "" {
			return convertUSFToUnified(&usf), nil
		}
	}

	return nil, fmt.Errorf("unable to parse session format")
}
