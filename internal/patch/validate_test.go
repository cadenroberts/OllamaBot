package patch

import (
	"crypto/sha1"
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

func TestValidationCatchesConflicts(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "patch-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	patcher := NewPatcher(tmpDir, "")

	// 1. Create a file
	filePath := "conflict.txt"
	absPath := filepath.Join(tmpDir, filePath)
	originalContent := "Original content"
	os.WriteFile(absPath, []byte(originalContent), 0644)

	baseChecksum := fmt.Sprintf("%x", sha1.Sum([]byte(originalContent)))

	// 2. Modify the file externally
	os.WriteFile(absPath, []byte("Modified content"), 0644)

	// 3. Try to detect conflict
	hasConflict, err := patcher.DetectConflict(filePath, baseChecksum)
	if err != nil {
		t.Fatalf("DetectConflict failed: %v", err)
	}

	if !hasConflict {
		t.Error("Expected conflict to be detected, but it wasn't")
	}

	// 4. Test with matching checksum (no conflict)
	newBaseChecksum := fmt.Sprintf("%x", sha1.Sum([]byte("Modified content")))
	hasConflict, err = patcher.DetectConflict(filePath, newBaseChecksum)
	if err != nil {
		t.Fatalf("DetectConflict failed: %v", err)
	}

	if hasConflict {
		t.Error("Expected no conflict, but one was detected")
	}
}

func TestVerifyChecksum(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "checksum-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	patcher := NewPatcher(tmpDir, "")

	filePath := "check.txt"
	absPath := filepath.Join(tmpDir, filePath)
	content := "Hello World"
	os.WriteFile(absPath, []byte(content), 0644)

	expectedChecksum := fmt.Sprintf("%x", sha1.Sum([]byte(content)))

	// 1. Valid checksum
	if err := patcher.VerifyChecksum(filePath, expectedChecksum); err != nil {
		t.Errorf("Expected checksum to verify, got error: %v", err)
	}

	// 2. Invalid checksum
	if err := patcher.VerifyChecksum(filePath, "wrong"); err == nil {
		t.Error("Expected checksum verification to fail, but it succeeded")
	}
}
