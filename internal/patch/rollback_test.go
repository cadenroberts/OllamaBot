package patch

import (
	"context"
	"os"
	"path/filepath"
	"testing"
)

func TestRollbackRestoresOriginal(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "rollback-test-work-*")
	if err != nil {
		t.Fatalf("Failed to create work dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	backupDir, err := os.MkdirTemp("", "rollback-test-backup-*")
	if err != nil {
		t.Fatalf("Failed to create backup dir: %v", err)
	}
	defer os.RemoveAll(backupDir)

	patcher := NewPatcher(tmpDir, backupDir)

	// 1. Create initial file
	filePath := "rollback.txt"
	initialContent := "Initial content"
	if err := os.WriteFile(filepath.Join(tmpDir, filePath), []byte(initialContent), 0644); err != nil {
		t.Fatalf("Failed to write initial file: %v", err)
	}

	// 2. Apply a patch that will fail (simulated by invalid path)
	// On Unix, a path with a null byte is invalid.
	patches := []Patch{
		{
			Path:       filePath,
			NewContent: "Modified content",
		},
		{
			Path:       "invalid\x00path.txt",
			NewContent: "This will fail",
		},
	}

	err = patcher.Apply(context.Background(), patches, ApplyOptions{})
	if err == nil {
		t.Error("Expected Apply to fail, but it succeeded")
	}

	// 3. Verify original content was restored
	content, err := os.ReadFile(filepath.Join(tmpDir, filePath))
	if err != nil {
		t.Fatalf("Failed to read file after rollback: %v", err)
	}

	if string(content) != initialContent {
		t.Errorf("Content mismatch after rollback. Expected %q, got %q", initialContent, string(content))
	}
}
