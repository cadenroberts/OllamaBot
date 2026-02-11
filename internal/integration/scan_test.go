package integration

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/croberts/obot/internal/scan"
)

func TestScanFixWorkflow(t *testing.T) {
	// 1. Setup workspace with issues
	tmpDir, err := os.MkdirTemp("", "scan-workflow-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	os.WriteFile(filepath.Join(tmpDir, "todo.go"), []byte("package main\n// TODO: Fix this\n"), 0644)

	// 2. Run scan
	scanner := scan.NewHealthScanner(tmpDir)
	report, err := scanner.Scan()
	if err != nil {
		t.Fatalf("Scan failed: %v", err)
	}

	if len(report.Issues) == 0 {
		t.Fatal("Expected at least one issue, got none")
	}

	// 3. Prioritize
	prioritizer := scan.NewIssuePrioritizer()
	prioritized := prioritizer.Prioritize(report.Issues)

	if len(prioritized) != len(report.Issues) {
		t.Errorf("Expected %d prioritized issues, got %d", len(report.Issues), len(prioritized))
	}

	// 4. Generate suggestions
	suggester := scan.NewFixSuggester()
	suggestions := suggester.Suggest(report.Issues)

	if len(suggestions) == 0 {
		t.Error("Expected at least one suggestion, got none")
	}
}
