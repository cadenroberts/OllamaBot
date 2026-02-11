package index

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

func TestIndexBuild(t *testing.T) {
	// Create a temporary directory for testing
	tmpDir, err := os.MkdirTemp("", "index-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Create some test files
	files := map[string]string{
		"file1.go": "package main\nfunc main() {}\n",
		"file2.md": "# Test Markdown\n",
		"subdir/file3.go": "package subdir\n",
	}

	for path, content := range files {
		fullPath := filepath.Join(tmpDir, path)
		if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
			t.Fatalf("Failed to create subdir: %v", err)
		}
		if err := os.WriteFile(fullPath, []byte(content), 0644); err != nil {
			t.Fatalf("Failed to write test file %s: %v", path, err)
		}
	}

	// Initialize index
	idx := NewIndex(tmpDir)

	// Build index
	if err := idx.Build(context.Background(), DefaultOptions()); err != nil {
		t.Fatalf("Index build failed: %v", err)
	}

	// Verify file counts
	stats := idx.GetStats()
	if stats.TotalFiles != 3 {
		t.Errorf("Expected 3 files, got %d", stats.TotalFiles)
	}

	// Verify language mapping (Analyzer.DetectLanguage returns lowercase)
	if stats.LanguageMap["go"] != 2 {
		t.Errorf("Expected 2 go files, got %d", stats.LanguageMap["go"])
	}
	if stats.LanguageMap["markdown"] != 1 {
		t.Errorf("Expected 1 markdown file, got %d", stats.LanguageMap["markdown"])
	}
}

func BenchmarkIndexBuild(b *testing.B) {
	// Create a larger test environment
	tmpDir, err := os.MkdirTemp("", "index-bench-*")
	if err != nil {
		b.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	for i := 0; i < 100; i++ {
		path := fmt.Sprintf("file%d.go", i)
		fullPath := filepath.Join(tmpDir, path)
		os.WriteFile(fullPath, []byte("package main\nfunc main() {}\n"), 0644)
	}

	idx := NewIndex(tmpDir)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = idx.Build(context.Background(), DefaultOptions())
	}
}

func TestSearchFindsMatches(t *testing.T) {
	// Create a temporary directory for testing
	tmpDir, err := os.MkdirTemp("", "search-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Create some test files with symbols
	files := map[string]string{
		"searchable.go": `package main
func FoundFunc() {}
type FoundStruct struct {}
func (s *FoundStruct) FoundMethod() {}
`,
		"other.py": `def python_func():
    pass
class PythonClass:
    pass
`,
	}

	for path, content := range files {
		fullPath := filepath.Join(tmpDir, path)
		if err := os.WriteFile(fullPath, []byte(content), 0644); err != nil {
			t.Fatalf("Failed to write test file %s: %v", path, err)
		}
	}

	// Initialize and build index
	idx := NewIndex(tmpDir)
	if err := idx.Build(context.Background(), DefaultOptions()); err != nil {
		t.Fatalf("Index build failed: %v", err)
	}

	// 1. Search for function
	results := idx.FindFunctions("FoundFunc")
	if len(results) != 1 {
		t.Errorf("Expected 1 match for FoundFunc, got %d", len(results))
	} else if results[0].Symbol.Name != "FoundFunc" {
		t.Errorf("Expected symbol name FoundFunc, got %s", results[0].Symbol.Name)
	}

	// 2. Search for method
	results = idx.FindMethods("FoundMethod")
	if len(results) != 1 {
		t.Errorf("Expected 1 match for FoundMethod, got %d", len(results))
	}

	// 3. Search for class/struct
	results = idx.FindClasses("FoundStruct")
	if len(results) != 1 {
		t.Errorf("Expected 1 match for FoundStruct, got %d", len(results))
	}

	// 4. Search for python symbol
	results = idx.SearchSymbols("python_func")
	if len(results) != 1 {
		t.Errorf("Expected 1 match for python_func, got %d", len(results))
	}

	// 5. Search for non-existent symbol
	results = idx.SearchSymbols("Missing")
	if len(results) != 0 {
		t.Errorf("Expected 0 matches for Missing, got %d", len(results))
	}
}

func TestSearchUses(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "search-uses-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	content := "usage of something unique"
	if err := os.WriteFile(filepath.Join(tmpDir, "usage.go"), []byte(content), 0644); err != nil {
		t.Fatalf("Failed to write test file: %v", err)
	}

	idx := NewIndex(tmpDir)
	if err := idx.Build(context.Background(), DefaultOptions()); err != nil {
		t.Fatalf("Index build failed: %v", err)
	}

	results := idx.SearchUses("something unique")
	if len(results) != 1 {
		t.Errorf("Expected 1 match, got %d", len(results))
	} else if results[0].File.RelPath != "usage.go" {
		t.Errorf("Expected usage.go, got %s", results[0].File.RelPath)
	}
}
