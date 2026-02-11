package patch

import (
	"context"
	"os"
	"path/filepath"
	"testing"
)

func TestBackupCreatedBeforeChanges(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "backup-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	backupDir, err := os.MkdirTemp("", "backup-store-*")
	if err != nil {
		t.Fatalf("Failed to create backup store: %v", err)
	}
	defer os.RemoveAll(backupDir)

	patcher := NewPatcher(tmpDir, backupDir)

	// 1. Create a file
	filePath := "test.txt"
	absPath := filepath.Join(tmpDir, filePath)
	originalContent := "Original content"
	os.WriteFile(absPath, []byte(originalContent), 0644)

	// 2. Apply a patch
	patches := []Patch{
		{
			Path:       filePath,
			NewContent: "New content",
		},
	}

	if err := patcher.Apply(context.Background(), patches, ApplyOptions{}); err != nil {
		t.Fatalf("Apply failed: %v", err)
	}

	// 3. Verify backup was created
	backups, err := patcher.ListBackups()
	if err != nil {
		t.Fatalf("ListBackups failed: %v", err)
	}

	if len(backups) != 1 {
		t.Fatalf("Expected 1 backup, got %d", len(backups))
	}

	// 4. Verify backup content matches original
	backupFilePath := filepath.Join(backupDir, backups[0], filePath)
	backupContent, err := os.ReadFile(backupFilePath)
	if err != nil {
		t.Fatalf("Failed to read backup file: %v", err)
	}

	if string(backupContent) != originalContent {
		t.Errorf("Backup content mismatch. Expected %q, got %q", originalContent, string(backupContent))
	}
}
