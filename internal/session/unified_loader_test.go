package session

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestLoadAnySession(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "unified-loader-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	// Override config dir for testing
	oldHome := os.Getenv("HOME")
	testHome := tmpDir
	os.Setenv("HOME", testHome)
	defer os.Setenv("HOME", oldHome)

	t.Run("LoadUnifiedSessionFormat", func(t *testing.T) {
		// Create a UnifiedSession
		sess := NewUnifiedSession("Test task", "build", "fast")
		sess.AddStep("tool-1", "in", "out", true, 100, 500)
		
		if err := SaveUSF(sess); err != nil {
			t.Fatalf("Failed to save UnifiedSession: %v", err)
		}

		// Load via LoadAnySession
		loaded, err := LoadAnySession(sess.SessionID)
		if err != nil {
			t.Fatalf("LoadAnySession failed: %v", err)
		}

		if loaded.SessionID != sess.SessionID {
			t.Errorf("SessionID mismatch: got %s, want %s", loaded.SessionID, sess.SessionID)
		}
		if len(loaded.Steps) != 1 {
			t.Errorf("Steps count mismatch: got %d, want 1", len(loaded.Steps))
		}
	})

	t.Run("LoadLegacyUSFSessionFormat", func(t *testing.T) {
		// Create a legacy USFSession
		legacy := NewUSFSession("legacy-sess-1", "cli", "Legacy task")
		legacy.AddStep(1, 1, []string{"action1"})
		
		sessionsDir := filepath.Join(testHome, ".config", "ollamabot", "sessions")
		if err := legacy.Save(sessionsDir); err != nil {
			t.Fatalf("Failed to save USFSession: %v", err)
		}

		// Load via LoadAnySession (should auto-convert)
		loaded, err := LoadAnySession(legacy.SessionID)
		if err != nil {
			t.Fatalf("LoadAnySession failed for legacy format: %v", err)
		}

		if loaded.SessionID != legacy.SessionID {
			t.Errorf("SessionID mismatch: got %s, want %s", loaded.SessionID, legacy.SessionID)
		}
		if loaded.Task.Description != "Legacy task" {
			t.Errorf("Task description mismatch: got %s, want 'Legacy task'", loaded.Task.Description)
		}
		if len(loaded.Steps) != 1 {
			t.Errorf("Steps count mismatch: got %d, want 1", len(loaded.Steps))
		}
	})

	t.Run("SessionNotFound", func(t *testing.T) {
		_, err := LoadAnySession("nonexistent-session")
		if err == nil {
			t.Error("Expected error for nonexistent session, got nil")
		}
	})
}

func TestListAllSessions(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "list-all-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	// Override HOME to isolate test
	oldHome := os.Getenv("HOME")
	os.Setenv("HOME", tmpDir)
	defer os.Setenv("HOME", oldHome)

	// Create a UnifiedSession
	unified := NewUnifiedSession("Unified task", "build", "fast")
	if err := SaveUSF(unified); err != nil {
		t.Fatalf("Failed to save UnifiedSession: %v", err)
	}

	// Create a legacy USFSession
	legacy := NewUSFSession("legacy-sess-2", "cli", "Legacy task")
	sessionsDir := filepath.Join(tmpDir, ".config", "ollamabot", "sessions")
	if err := legacy.Save(sessionsDir); err != nil {
		t.Fatalf("Failed to save USFSession: %v", err)
	}

	// List all sessions
	sessions, err := ListAllSessions()
	if err != nil {
		t.Fatalf("ListAllSessions failed: %v", err)
	}

	if len(sessions) != 2 {
		t.Errorf("Expected 2 sessions, got %d", len(sessions))
	}

	// Check both sessions are present
	found := make(map[string]bool)
	for _, sid := range sessions {
		found[sid] = true
	}

	if !found[unified.SessionID] {
		t.Errorf("UnifiedSession not found in list")
	}
	if !found[legacy.SessionID] {
		t.Errorf("USFSession not found in list")
	}
}

func TestSaveAnySession(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "save-any-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	oldHome := os.Getenv("HOME")
	os.Setenv("HOME", tmpDir)
	defer os.Setenv("HOME", oldHome)

	// Create a UnifiedSession and save
	sess := NewUnifiedSession("Test save", "build", "fast")
	sess.AddStep("tool-1", "in", "out", true, 100, 500)
	
	if err := SaveAnySession(sess); err != nil {
		t.Fatalf("SaveAnySession failed: %v", err)
	}

	// Verify file exists in UnifiedSession format
	sessionsDir := filepath.Join(tmpDir, ".config", "ollamabot", "sessions")
	unifiedFile := filepath.Join(sessionsDir, sess.SessionID+".json")
	if _, err := os.Stat(unifiedFile); os.IsNotExist(err) {
		t.Errorf("UnifiedSession file not created: %s", unifiedFile)
	}

	// Reload and verify
	loaded, err := LoadUSF(sess.SessionID)
	if err != nil {
		t.Fatalf("Failed to reload saved session: %v", err)
	}
	if loaded.SessionID != sess.SessionID {
		t.Errorf("Reloaded session ID mismatch")
	}
}

func TestSaveAnySessionMigratesLegacy(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "migrate-on-save-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	oldHome := os.Getenv("HOME")
	os.Setenv("HOME", tmpDir)
	defer os.Setenv("HOME", oldHome)

	// Create a legacy USFSession
	legacy := NewUSFSession("legacy-sess-3", "cli", "Legacy task")
	sessionsDir := filepath.Join(tmpDir, ".config", "ollamabot", "sessions")
	if err := legacy.Save(sessionsDir); err != nil {
		t.Fatalf("Failed to save USFSession: %v", err)
	}

	// Load it (auto-converts to UnifiedSession)
	loaded, err := LoadAnySession(legacy.SessionID)
	if err != nil {
		t.Fatalf("Failed to load legacy session: %v", err)
	}

	// Save it (should migrate)
	if err := SaveAnySession(loaded); err != nil {
		t.Fatalf("SaveAnySession failed: %v", err)
	}

	// Verify legacy directory was renamed
	legacyDir := filepath.Join(sessionsDir, legacy.SessionID)
	if _, err := os.Stat(legacyDir); !os.IsNotExist(err) {
		// Check if it was renamed to .migrated_
		migratedDir := filepath.Join(sessionsDir, ".migrated_"+legacy.SessionID)
		if _, err := os.Stat(migratedDir); os.IsNotExist(err) {
			t.Errorf("Legacy directory was not migrated: %s", legacyDir)
		}
	}

	// Verify UnifiedSession file exists
	unifiedFile := filepath.Join(sessionsDir, legacy.SessionID+".json")
	if _, err := os.Stat(unifiedFile); os.IsNotExist(err) {
		t.Errorf("UnifiedSession file not created after migration: %s", unifiedFile)
	}
}

func TestConvertUSFToUnified(t *testing.T) {
	// Create a legacy USFSession with full data
	usf := &USFSession{
		Version:   "1.0",
		SessionID: "test-convert-1",
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
		Platform:  "cli",
		Task: USFTaskInfo{
			Prompt:      "Build a feature",
			Description: "Feature description",
			Status:      "in_progress",
		},
		Workspace: USFWorkspaceInfo{
			Path:      "/path/to/workspace",
			GitBranch: "main",
			GitCommit: "abc123",
		},
		OrchestrationState: USFOrchestrationInfo{
			FlowCode: "S1P1P2",
			Schedule: 1,
			Process:  2,
		},
		History: []USFStepInfo{
			{Sequence: 1, Timestamp: time.Now(), Schedule: 1, Process: 1},
			{Sequence: 2, Timestamp: time.Now(), Schedule: 1, Process: 2},
		},
		Checkpoints: []USFCheckpointInfo{
			{ID: "cp-1", Name: "checkpoint 1", Timestamp: time.Now()},
		},
		Stats: USFStatsInfo{
			TotalTokens:     1000,
			DurationSeconds: 120,
		},
	}

	// Convert
	unified := convertUSFToUnified(usf)

	// Verify conversion
	if unified.SessionID != usf.SessionID {
		t.Errorf("SessionID mismatch: got %s, want %s", unified.SessionID, usf.SessionID)
	}
	if unified.PlatformOrigin != usf.Platform {
		t.Errorf("Platform mismatch: got %s, want %s", unified.PlatformOrigin, usf.Platform)
	}
	if unified.Task.Description != usf.Task.Prompt {
		t.Errorf("Task description mismatch: got %s, want %s", unified.Task.Description, usf.Task.Prompt)
	}
	if unified.Orchestration.FlowCode != usf.OrchestrationState.FlowCode {
		t.Errorf("FlowCode mismatch: got %s, want %s", unified.Orchestration.FlowCode, usf.OrchestrationState.FlowCode)
	}
	if len(unified.Steps) != len(usf.History) {
		t.Errorf("Steps count mismatch: got %d, want %d", len(unified.Steps), len(usf.History))
	}
	if len(unified.Checkpoints) != len(usf.Checkpoints) {
		t.Errorf("Checkpoints count mismatch: got %d, want %d", len(unified.Checkpoints), len(usf.Checkpoints))
	}
	if unified.Stats.TotalTokens != int(usf.Stats.TotalTokens) {
		t.Errorf("TotalTokens mismatch: got %d, want %d", unified.Stats.TotalTokens, usf.Stats.TotalTokens)
	}
}

func TestGetSessionFormat(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "format-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	oldHome := os.Getenv("HOME")
	os.Setenv("HOME", tmpDir)
	defer os.Setenv("HOME", oldHome)

	// Create a UnifiedSession
	unified := NewUnifiedSession("Unified task", "build", "fast")
	if err := SaveUSF(unified); err != nil {
		t.Fatalf("Failed to save UnifiedSession: %v", err)
	}

	// Create a legacy USFSession
	legacy := NewUSFSession("legacy-sess-4", "cli", "Legacy task")
	sessionsDir := filepath.Join(tmpDir, ".config", "ollamabot", "sessions")
	if err := legacy.Save(sessionsDir); err != nil {
		t.Fatalf("Failed to save USFSession: %v", err)
	}

	// Test format detection
	if format := GetSessionFormat(unified.SessionID); format != "unified" {
		t.Errorf("Expected 'unified' format, got '%s'", format)
	}

	if format := GetSessionFormat(legacy.SessionID); format != "legacy" {
		t.Errorf("Expected 'legacy' format, got '%s'", format)
	}

	if format := GetSessionFormat("nonexistent"); format != "not_found" {
		t.Errorf("Expected 'not_found' format, got '%s'", format)
	}
}

func TestGetSessionInfo(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "info-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	oldHome := os.Getenv("HOME")
	os.Setenv("HOME", tmpDir)
	defer os.Setenv("HOME", oldHome)

	// Create a session
	sess := NewUnifiedSession("Test task", "build", "fast")
	sess.AddStep("tool-1", "in", "out", true, 100, 500)
	if err := SaveUSF(sess); err != nil {
		t.Fatalf("Failed to save session: %v", err)
	}

	// Get session info
	info, err := GetSessionInfo(sess.SessionID)
	if err != nil {
		t.Fatalf("GetSessionInfo failed: %v", err)
	}

	if info.ID != sess.SessionID {
		t.Errorf("ID mismatch: got %s, want %s", info.ID, sess.SessionID)
	}
	if info.Description != "Test task" {
		t.Errorf("Description mismatch: got %s, want 'Test task'", info.Description)
	}
	if info.Platform != "cli" {
		t.Errorf("Platform mismatch: got %s, want 'cli'", info.Platform)
	}
	if info.StepCount != 1 {
		t.Errorf("StepCount mismatch: got %d, want 1", info.StepCount)
	}
	if info.Format != "unified" {
		t.Errorf("Format mismatch: got %s, want 'unified'", info.Format)
	}
}

func TestMigrateAllSessions(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "migrate-all-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	oldHome := os.Getenv("HOME")
	os.Setenv("HOME", tmpDir)
	defer os.Setenv("HOME", oldHome)

	sessionsDir := filepath.Join(tmpDir, ".config", "ollamabot", "sessions")

	// Create 3 legacy sessions
	legacyIDs := []string{"legacy-sess-a", "legacy-sess-b", "legacy-sess-c"}
	for _, id := range legacyIDs {
		legacy := NewUSFSession(id, "cli", "Legacy task")
		if err := legacy.Save(sessionsDir); err != nil {
			t.Fatalf("Failed to save USFSession %s: %v", id, err)
		}
	}

	// Migrate all
	count, err := MigrateAllSessions()
	if err != nil {
		t.Fatalf("MigrateAllSessions failed: %v", err)
	}

	if count != 3 {
		t.Errorf("Expected 3 migrations, got %d", count)
	}

	// Verify all are now in UnifiedSession format
	sessions, err := ListUSFSessions()
	if err != nil {
		t.Fatalf("ListUSFSessions failed: %v", err)
	}

	if len(sessions) < 3 {
		t.Errorf("Expected at least 3 sessions in unified format, got %d", len(sessions))
	}

	// Verify each legacy session was migrated
	for _, id := range legacyIDs {
		legacyDir := filepath.Join(sessionsDir, id)
		if _, err := os.Stat(legacyDir); !os.IsNotExist(err) {
			migratedDir := filepath.Join(sessionsDir, ".migrated_"+id)
			if _, err := os.Stat(migratedDir); os.IsNotExist(err) {
				t.Errorf("Legacy directory %s was not migrated", id)
			}
		}
	}
}
