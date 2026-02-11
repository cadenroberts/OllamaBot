package agent

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/croberts/obot/internal/model"
)

func TestExecuteAction(t *testing.T) {
	// Setup
	tempDir, err := os.MkdirTemp("", "agent-test-*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tempDir)

	models := model.NewCoordinator(nil) // Dummy coordinator
	a := NewAgent(models)
	a.executing = true // Manual set for test
	
	ctx := context.Background()

	t.Run("CreateFile", func(t *testing.T) {
		path := filepath.Join(tempDir, "test.txt")
		action := Action{
			Type:    ActionCreateFile,
			Path:    path,
			Content: "hello world",
		}

		err := a.executeAction(ctx, &action)
		if err != nil {
			t.Fatalf("executeAction failed: %v", err)
		}

		// Verify file
		data, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		if string(data) != "hello world" {
			t.Errorf("expected 'hello world', got %q", string(data))
		}

		// Verify metadata
		lastAction := a.actions[len(a.actions)-1]
		if lastAction.Metadata["status"] != "success" {
			t.Errorf("expected success status, got %v", lastAction.Metadata["status"])
		}
		if _, ok := lastAction.Metadata["duration_ms"]; !ok {
			t.Error("duration_ms metadata missing")
		}
	})

	t.Run("DeleteFile", func(t *testing.T) {
		path := filepath.Join(tempDir, "delete-me.txt")
		os.WriteFile(path, []byte("data"), 0644)

		action := Action{
			Type: ActionDeleteFile,
			Path: path,
		}

		err := a.executeAction(ctx, &action)
		if err != nil {
			t.Fatalf("executeAction failed: %v", err)
		}

		if _, err := os.Stat(path); !os.IsNotExist(err) {
			t.Error("file still exists after delete")
		}
	})

	t.Run("InvalidAction", func(t *testing.T) {
		action := Action{
			Type: "invalid_type",
		}
		err := a.executeAction(ctx, &action)
		if err == nil {
			t.Error("expected error for invalid action type")
		}
	})
}
