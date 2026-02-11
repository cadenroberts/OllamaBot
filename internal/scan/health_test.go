package scan

import (
	"os"
	"path/filepath"
	"testing"
)

func TestScannerDetectsKnownIssues(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "scan-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Create files with known issues
	files := map[string]string{
		"todo.go": `package main
// TODO: Implement this
func main() {}
`,
		"security.go": `package main
var secret = "super-secret-token"
`,
		"complex.go": `package main
func complex() {
								if true {
									if true {
										if true {
											if true {
												if true {
													if true {
														println("Deeply nested")
													}
												}
											}
										}
									}
								}
}
`,
	}

	for path, content := range files {
		fullPath := filepath.Join(tmpDir, path)
		os.WriteFile(fullPath, []byte(content), 0644)
	}

	scanner := NewHealthScanner(tmpDir)
	report, err := scanner.Scan()
	if err != nil {
		t.Fatalf("Scan failed: %v", err)
	}

	// Verify detections
	hasTodo := false
	hasSecurity := false
	hasComplexity := false

	for _, issue := range report.Issues {
		switch issue.Type {
		case "todo":
			hasTodo = true
		case "security":
			hasSecurity = true
		case "complexity":
			hasComplexity = true
		}
	}

	if !hasTodo {
		t.Error("Failed to detect TODO issue")
	}
	if !hasSecurity {
		t.Error("Failed to detect security issue")
	}
	if !hasComplexity {
		t.Error("Failed to detect complexity issue")
	}

	if report.Score >= 100 {
		t.Errorf("Expected health score to be < 100, got %d", report.Score)
	}
}
