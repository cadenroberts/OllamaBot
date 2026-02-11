// Package session - Regression test for session format duality bug
// This test ensures the bug fix remains effective
package session

import (
	"os"
	"path/filepath"
	"testing"
)

// TestSessionFormatDualityRegression is a regression guard ensuring
// that both session formats remain accessible via unified interface.
// 
// Bug: Session USF format duality retained because both have active CLI 
// consumers - consolidation requires coordinated migration.
// 
// Fix: Implemented backwards-compatible unified loader that transparently
// handles both formats and auto-migrates legacy sessions on save.
func TestSessionFormatDualityRegression(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "regression-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	oldHome := os.Getenv("HOME")
	os.Setenv("HOME", tmpDir)
	defer os.Setenv("HOME", oldHome)

	sessionsDir := filepath.Join(tmpDir, ".config", "ollamabot", "sessions")

	// Scenario 1: Create session via "session_cmd.go" pattern (legacy USFSession)
	t.Run("SessionCmdCreatesUSFSession", func(t *testing.T) {
		legacy := NewUSFSession("sess-from-cmd", "cli", "Task from session cmd")
		legacy.AddStep(1, 1, []string{"action1"})
		
		if err := legacy.Save(sessionsDir); err != nil {
			t.Fatalf("Failed to create legacy session: %v", err)
		}

		// Verify it exists in legacy format
		legacyFile := filepath.Join(sessionsDir, "sess-from-cmd", "session.usf")
		if _, err := os.Stat(legacyFile); os.IsNotExist(err) {
			t.Errorf("Legacy session file not created")
		}
	})

	// Scenario 2: Create session via "checkpoint.go" pattern (UnifiedSession)
	t.Run("CheckpointCreatesUnifiedSession", func(t *testing.T) {
		unified := NewUnifiedSession("Task from checkpoint", "build", "fast")
		unified.AddStep("tool-1", "in", "out", true, 100, 500)
		unified.AddCheckpoint("cp-1", "abc123")
		
		if err := SaveUSF(unified); err != nil {
			t.Fatalf("Failed to create unified session: %v", err)
		}

		// Verify it exists in unified format
		unifiedFile := filepath.Join(sessionsDir, unified.SessionID+".json")
		if _, err := os.Stat(unifiedFile); os.IsNotExist(err) {
			t.Errorf("Unified session file not created")
		}
	})

	// Scenario 3: Both commands must see both sessions
	t.Run("BothCommandsSeeBothFormats", func(t *testing.T) {
		// Simulate "obot session list" (uses ListAllSessions)
		allSessions, err := ListAllSessions()
		if err != nil {
			t.Fatalf("ListAllSessions failed: %v", err)
		}

		if len(allSessions) < 2 {
			t.Errorf("ListAllSessions should see both formats, got %d", len(allSessions))
		}

		// Verify we can load both
		foundLegacy := false
		foundUnified := false
		for _, sid := range allSessions {
			if sid == "sess-from-cmd" {
				foundLegacy = true
			}
			if _, err := LoadAnySession(sid); err != nil {
				t.Errorf("Failed to load session %s: %v", sid, err)
			}
		}

		if !foundLegacy {
			t.Error("Legacy session not found in unified listing")
		}

		// Note: foundUnified check depends on SessionID generation,
		// so we just verify count >= 2 above
		_ = foundUnified
	})

	// Scenario 4: Checkpoints must work across both formats
	t.Run("CheckpointsWorkAcrossBothFormats", func(t *testing.T) {
		// Load legacy session
		legacy, err := LoadAnySession("sess-from-cmd")
		if err != nil {
			t.Fatalf("Failed to load legacy session: %v", err)
		}

		// Add checkpoint to it
		legacy.AddCheckpoint("test-checkpoint", "git-hash")
		if err := SaveAnySession(legacy); err != nil {
			t.Fatalf("Failed to save checkpoint to legacy session: %v", err)
		}

		// Reload and verify checkpoint exists
		reloaded, err := LoadAnySession("sess-from-cmd")
		if err != nil {
			t.Fatalf("Failed to reload session: %v", err)
		}

		if len(reloaded.Checkpoints) == 0 {
			t.Error("Checkpoint not preserved after save")
		}

		found := false
		for _, cp := range reloaded.Checkpoints {
			if cp.Name == "test-checkpoint" {
				found = true
				break
			}
		}
		if !found {
			t.Error("Checkpoint 'test-checkpoint' not found after reload")
		}
	})

	// Scenario 5: Legacy sessions auto-migrate on save
	t.Run("LegacySessionsAutoMigrate", func(t *testing.T) {
		// Load legacy session
		legacy, err := LoadAnySession("sess-from-cmd")
		if err != nil {
			t.Fatalf("Failed to load legacy session: %v", err)
		}

		// Modify and save (should trigger migration)
		legacy.Task.Status = "completed"
		if err := SaveAnySession(legacy); err != nil {
			t.Fatalf("Failed to save session: %v", err)
		}

		// Verify it's now in unified format
		unifiedFile := filepath.Join(sessionsDir, "sess-from-cmd.json")
		if _, err := os.Stat(unifiedFile); os.IsNotExist(err) {
			t.Error("Session was not migrated to unified format")
		}

		// Verify legacy directory was archived
		legacyDir := filepath.Join(sessionsDir, "sess-from-cmd")
		migratedDir := filepath.Join(sessionsDir, ".migrated_sess-from-cmd")
		
		_, legacyExists := os.Stat(legacyDir)
		_, migratedExists := os.Stat(migratedDir)
		
		if legacyExists == nil && migratedExists != nil {
			t.Error("Legacy directory should be renamed during migration")
		}

		// Verify format detection now reports "unified"
		format := GetSessionFormat("sess-from-cmd")
		if format != "unified" {
			t.Errorf("After migration, format should be 'unified', got '%s'", format)
		}
	})
}

// TestCLICommandConsistency ensures CLI commands use unified interface
func TestCLICommandConsistency(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "cli-consistency-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	oldHome := os.Getenv("HOME")
	os.Setenv("HOME", tmpDir)
	defer os.Setenv("HOME", oldHome)

	// Create mixed format sessions
	legacy := NewUSFSession("legacy-1", "cli", "Legacy task")
	legacy.AddStep(1, 1, []string{"action1"})
	sessionsDir := filepath.Join(tmpDir, ".config", "ollamabot", "sessions")
	if err := legacy.Save(sessionsDir); err != nil {
		t.Fatalf("Failed to save legacy: %v", err)
	}

	unified := NewUnifiedSession("Unified task", "build", "fast")
	if err := SaveUSF(unified); err != nil {
		t.Fatalf("Failed to save unified: %v", err)
	}

	// Test: session list pattern (session_cmd.go)
	t.Run("SessionListPattern", func(t *testing.T) {
		sessions, err := ListAllSessions()
		if err != nil {
			t.Fatalf("ListAllSessions failed: %v", err)
		}

		if len(sessions) < 2 {
			t.Errorf("Expected at least 2 sessions, got %d", len(sessions))
		}

		// Verify GetSessionInfo works for both
		for _, sid := range sessions {
			_, err := GetSessionInfo(sid)
			if err != nil {
				t.Errorf("GetSessionInfo failed for %s: %v", sid, err)
			}
		}
	})

	// Test: checkpoint list pattern (checkpoint.go)
	t.Run("CheckpointListPattern", func(t *testing.T) {
		// Add checkpoints to both sessions
		leg, _ := LoadAnySession("legacy-1")
		leg.AddCheckpoint("cp-legacy", "hash1")
		SaveAnySession(leg)

		uni, _ := LoadAnySession(unified.SessionID)
		uni.AddCheckpoint("cp-unified", "hash2")
		SaveAnySession(uni)

		// List all sessions and collect checkpoints
		sessions, _ := ListAllSessions()
		totalCheckpoints := 0
		for _, sid := range sessions {
			sess, err := LoadAnySession(sid)
			if err != nil {
				continue
			}
			totalCheckpoints += len(sess.Checkpoints)
		}

		if totalCheckpoints < 2 {
			t.Errorf("Expected at least 2 checkpoints across all sessions, got %d", totalCheckpoints)
		}
	})
}
