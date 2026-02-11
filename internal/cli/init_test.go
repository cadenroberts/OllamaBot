package cli

import (
	"os"
	"path/filepath"
	"testing"
)

func TestInitCreatesProperStructure(t *testing.T) {
	// Create a temporary directory for testing
	tmpDir, err := os.MkdirTemp("", "init-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Change to the temp directory
	oldWd, _ := os.Getwd()
	os.Chdir(tmpDir)
	defer os.Chdir(oldWd)

	// Run the init command logic
	// (Normally we would use cobra to execute, but we'll call the RunE logic directly)
	err = initCmd.RunE(initCmd, []string{})
	if err != nil {
		t.Fatalf("Init command failed: %v", err)
	}

	// Verify .obot directory exists
	if _, err := os.Stat(".obot"); os.IsNotExist(err) {
		t.Error(".obot directory was not created")
	}

	// Verify rules.obotrules exists
	rulesPath := filepath.Join(".obot", "rules.obotrules")
	if _, err := os.Stat(rulesPath); os.IsNotExist(err) {
		t.Error("rules.obotrules was not created")
	}

	// Verify cache directory exists
	cacheDir := filepath.Join(".obot", "cache")
	if _, err := os.Stat(cacheDir); os.IsNotExist(err) {
		t.Error("cache directory was not created")
	}
}
