package session

import (
	"os"
	"testing"
	"time"

	"github.com/croberts/obot/internal/config"
)

func TestUSFCrossPlatformCompatibility(t *testing.T) {
	// Setup temporary config directory for USF
	tmpDir, err := os.MkdirTemp("", "usf-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	// Mock config.UnifiedConfigDir()
	originalConfigDir := config.UnifiedConfigDir()
	defer os.Setenv("OBOT_CONFIG_DIR", originalConfigDir)
	os.Setenv("OBOT_CONFIG_DIR", tmpDir)

	t.Run("CLI_Create_IDE_Load", func(t *testing.T) {
		// 1. Create session in CLI (simulated)
		sess := NewUnifiedSession("Test task from CLI", "build", "fast")
		sess.AddStep("tool-1", "input-1", "output-1", true, 100, 500)
		sess.AddCheckpoint("cp-1", "git-123")
		sess.Orchestration.FlowCode = "S1P1"
		
		err := SaveUSF(sess)
		if err != nil {
			t.Fatalf("Failed to save USF session: %v", err)
		}

		// 2. Load in IDE (simulated)
		loaded, err := LoadUSF(sess.SessionID)
		if err != nil {
			t.Fatalf("Failed to load USF session: %v", err)
		}

		// Verify data integrity
		if loaded.SessionID != sess.SessionID {
			t.Errorf("SessionID mismatch: got %s, want %s", loaded.SessionID, sess.SessionID)
		}
		if loaded.Task.Description != sess.Task.Description {
			t.Errorf("Task description mismatch: got %s, want %s", loaded.Task.Description, sess.Task.Description)
		}
		if len(loaded.Steps) != 1 {
			t.Errorf("Steps count mismatch: got %d, want 1", len(loaded.Steps))
		}
		if loaded.Steps[0].ToolID != "tool-1" {
			t.Errorf("Step tool ID mismatch: got %s, want tool-1", loaded.Steps[0].ToolID)
		}
		if loaded.Orchestration.FlowCode != "S1P1" {
			t.Errorf("Flow code mismatch: got %s, want S1P1", loaded.Orchestration.FlowCode)
		}
	})

	t.Run("IDE_Create_CLI_Resume", func(t *testing.T) {
		// 1. Create session in IDE (simulated)
		now := time.Now()
		sess := &UnifiedSession{
			Version:        "1.0",
			SessionID:      "sess_ide_123",
			CreatedAt:      now,
			UpdatedAt:      now,
			PlatformOrigin: "ide",
			Task: USFTask{
				Description: "Test task from IDE",
				Status:      "in_progress",
			},
			Orchestration: USFOrchestration{
				FlowCode: "S2P1",
			},
			Steps: make([]USFStep, 0),
		}
		
		err := SaveUSF(sess)
		if err != nil {
			t.Fatalf("Failed to save IDE session: %v", err)
		}

		// 2. Resume in CLI (simulated)
		resumed, err := LoadUSF("sess_ide_123")
		if err != nil {
			t.Fatalf("Failed to resume IDE session in CLI: %v", err)
		}

		// Verify data integrity
		if resumed.PlatformOrigin != "ide" {
			t.Errorf("PlatformOrigin mismatch: got %s, want ide", resumed.PlatformOrigin)
		}
		if resumed.Orchestration.FlowCode != "S2P1" {
			t.Errorf("Flow code mismatch: got %s, want S2P1", resumed.Orchestration.FlowCode)
		}

		// 3. Update in CLI
		resumed.AddStep("tool-cli", "cli-in", "cli-out", true, 50, 200)
		resumed.Orchestration.FlowCode = "S2P1P2"
		err = SaveUSF(resumed)
		if err != nil {
			t.Fatalf("Failed to save updated session from CLI: %v", err)
		}

		// 4. Reload and verify
		final, _ := LoadUSF("sess_ide_123")
		if len(final.Steps) != 1 {
			t.Errorf("Steps count mismatch after CLI update: got %d, want 1", len(final.Steps))
		}
		if final.Orchestration.FlowCode != "S2P1P2" {
			t.Errorf("Flow code mismatch after CLI update: got %s, want S2P1P2", final.Orchestration.FlowCode)
		}
	})
}

func TestLegacyToUnifiedExport(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "legacy-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	// Create a legacy session
	legacy := NewSessionWithBaseDir(tmpDir)
	legacy.SetPrompt("Legacy prompt")
	legacy.AddState(1, 1, []string{"action1"})
	legacy.SetFlowCode("S1P1")

	// Export to USF
	unified := ExportFromLegacy(legacy)

	// Verify
	if unified.SessionID != legacy.ID {
		t.Errorf("Export: ID mismatch")
	}
	if unified.Task.Description != "Legacy prompt" {
		t.Errorf("Export: prompt mismatch")
	}
	if len(unified.Steps) != 1 {
		t.Errorf("Export: steps count mismatch")
	}
	if unified.Orchestration.FlowCode != "S1P1" {
		t.Errorf("Export: flow code mismatch")
	}
}
