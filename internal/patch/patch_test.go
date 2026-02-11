package patch

import (
	"context"
	"os"
	"path/filepath"
	"testing"
)

func TestAtomicApplyWorks(t *testing.T) {
	// Setup workspace
	workDir, err := os.MkdirTemp("", "patch-test-work-*")
	if err != nil {
		t.Fatalf("Failed to create work dir: %v", err)
	}
	defer os.RemoveAll(workDir)

	backupDir, err := os.MkdirTemp("", "patch-test-backup-*")
	if err != nil {
		t.Fatalf("Failed to create backup dir: %v", err)
	}
	defer os.RemoveAll(backupDir)

	// Create initial file
	filePath := "hello.txt"
	initialContent := "Hello, World!\n"
	if err := os.WriteFile(filepath.Join(workDir, filePath), []byte(initialContent), 0644); err != nil {
		t.Fatalf("Failed to write initial file: %v", err)
	}

	p := NewPatcher(workDir, backupDir)
	ctx := context.Background()
	opts := ApplyOptions{}

	// 1. Successful apply
	patches := []Patch{
		{Path: filePath, NewContent: "Hello, OllamaBot!\n"},
	}

	if err := p.Apply(ctx, patches, opts); err != nil {
		t.Fatalf("Apply failed: %v", err)
	}

	// Verify content
	content, _ := os.ReadFile(filepath.Join(workDir, filePath))
	if string(content) != "Hello, OllamaBot!\n" {
		t.Errorf("Expected modified content, got %q", string(content))
	}

	// 2. Failed apply with rollback
	// We'll simulate failure by providing an invalid path for the second patch
	// but the first one should be rolled back.
	patches = []Patch{
		{Path: filePath, NewContent: "Should be rolled back\n"},
		{Path: "nonexistent/directory/file.txt", NewContent: "Fail\n"},
	}

	// Make the path invalid by creating a file where a directory should be
	os.WriteFile(filepath.Join(workDir, "nonexistent"), []byte("not a dir"), 0644)

	if err := p.Apply(ctx, patches, opts); err == nil {
		t.Error("Expected Apply to fail, but it succeeded")
	}

	// Verify rollback
	content, _ = os.ReadFile(filepath.Join(workDir, filePath))
	if string(content) != "Hello, OllamaBot!\n" {
		t.Errorf("Expected content after rollback to be 'Hello, OllamaBot!', got %q", string(content))
	}
}
