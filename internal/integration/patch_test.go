package integration

import (
	"context"
	"crypto/sha1"
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/croberts/obot/internal/patch"
)

func TestFullPatchWorkflow(t *testing.T) {
	// 1. Setup workspace
	workDir, err := os.MkdirTemp("", "patch-workflow-work-*")
	if err != nil {
		t.Fatalf("Failed to create work dir: %v", err)
	}
	defer os.RemoveAll(workDir)

	backupDir, err := os.MkdirTemp("", "patch-workflow-backup-*")
	if err != nil {
		t.Fatalf("Failed to create backup dir: %v", err)
	}
	defer os.RemoveAll(backupDir)

	patcher := patch.NewPatcher(workDir, backupDir)

	// 2. Create initial state
	file1 := "file1.txt"
	content1 := "Content 1"
	os.WriteFile(filepath.Join(workDir, file1), []byte(content1), 0644)

	// 3. Apply a valid patch
	newContent1 := "Modified Content 1"
	checksum1 := fmt.Sprintf("%x", sha1.Sum([]byte(newContent1)))
	
	patches := []patch.Patch{
		{
			Path:       file1,
			NewContent: newContent1,
			Checksum:   checksum1,
		},
		{
			Path:       "file2.txt",
			NewContent: "New File 2",
		},
	}

	if err := patcher.Apply(context.Background(), patches, patch.ApplyOptions{}); err != nil {
		t.Fatalf("Valid patch application failed: %v", err)
	}

	// 4. Verify changes
	data, _ := os.ReadFile(filepath.Join(workDir, file1))
	if string(data) != newContent1 {
		t.Errorf("Expected modified content in file1, got %q", string(data))
	}

	data, _ = os.ReadFile(filepath.Join(workDir, "file2.txt"))
	if string(data) != "New File 2" {
		t.Errorf("Expected new file2, got %q", string(data))
	}

	// 5. Apply a patch that fails checksum verification
	patches = []patch.Patch{
		{
			Path:       file1,
			NewContent: "This should be rolled back",
			Checksum:   "wrong-checksum",
		},
	}

	if err := patcher.Apply(context.Background(), patches, patch.ApplyOptions{}); err == nil {
		t.Error("Expected patch with wrong checksum to fail, but it succeeded")
	}

	// 6. Verify rollback
	data, _ = os.ReadFile(filepath.Join(workDir, file1))
	if string(data) != newContent1 {
		t.Errorf("Expected original content after rollback, got %q", string(data))
	}
}
