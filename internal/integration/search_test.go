package integration

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/croberts/obot/internal/index"
)

func TestSearchIntegration(t *testing.T) {
	// 1. Setup a mock project structure
	tmpDir, err := os.MkdirTemp("", "search-integration-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	files := map[string]string{
		"src/main.go": `package main
func MainFunc() {
	println("Hello")
}
`,
		"src/utils/helper.go": `package utils
type HelperStruct struct {}
func (h *HelperStruct) Help() {}
`,
		"docs/README.md": "# Project README\n",
	}

	for path, content := range files {
		fullPath := filepath.Join(tmpDir, path)
		if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
			t.Fatalf("Failed to create directory: %v", err)
		}
		if err := os.WriteFile(fullPath, []byte(content), 0644); err != nil {
			t.Fatalf("Failed to write file: %v", err)
		}
	}

	// 2. Build the index
	idx := index.NewIndex(tmpDir)
	if err := idx.Build(context.Background(), index.DefaultOptions()); err != nil {
		t.Fatalf("Failed to build index: %v", err)
	}

	// 3. Verify index statistics
	stats := idx.GetStats()
	if stats.TotalFiles != 3 {
		t.Errorf("Expected 3 files in index, got %d", stats.TotalFiles)
	}

	// 4. Test symbol search
	results := idx.SearchSymbols("MainFunc")
	if len(results) != 1 {
		t.Errorf("Expected 1 result for MainFunc, got %d", len(results))
	} else if results[0].File.RelPath != "src/main.go" {
		t.Errorf("Expected match in src/main.go, got %s", results[0].File.RelPath)
	}

	// 5. Test method search
	results = idx.FindMethods("Help")
	if len(results) != 1 {
		t.Errorf("Expected 1 result for Help method, got %d", len(results))
	}

	// 6. Test file search
	resultsFiles := idx.FindByName("README")
	if len(resultsFiles) != 1 {
		t.Errorf("Expected 1 result for README, got %d", len(resultsFiles))
	}
}
