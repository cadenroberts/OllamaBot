// Package test provides utilities for testing obot components.
package test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

// AssertGolden compares the actual output against the content of a golden file.
// If the file does not exist, it creates it with the actual output if the UPDATE_GOLDEN
// environment variable is set to "true".
func AssertGolden(t *testing.T, name string, actual []byte) {
	t.Helper()

	goldenPath := filepath.Join("testdata", name+".golden")
	
	// Check if we should update the golden file
	update := os.Getenv("UPDATE_GOLDEN") == "true"

	if update {
		err := os.MkdirAll(filepath.Dir(goldenPath), 0755)
		if err != nil {
			t.Fatalf("failed to create testdata directory: %v", err)
		}
		err = os.WriteFile(goldenPath, actual, 0644)
		if err != nil {
			t.Fatalf("failed to update golden file %s: %v", goldenPath, err)
		}
		t.Logf("Updated golden file: %s", goldenPath)
		return
	}

	expected, err := os.ReadFile(goldenPath)
	if err != nil {
		if os.IsNotExist(err) {
			t.Fatalf("golden file %s does not exist. Run with UPDATE_GOLDEN=true to create it.", goldenPath)
		}
		t.Fatalf("failed to read golden file %s: %v", goldenPath, err)
	}

	if !bytes.Equal(actual, expected) {
		t.Errorf("output does not match golden file %s\nActual:\n%s\nExpected:\n%s", 
			goldenPath, string(actual), string(expected))
	}
}

// AssertGoldenJSON is like AssertGolden but for JSON data, ensuring proper formatting.
func AssertGoldenJSON(t *testing.T, name string, actual interface{}) {
	t.Helper()

	actualJSON, err := json.MarshalIndent(actual, "", "  ")
	if err != nil {
		t.Fatalf("failed to marshal actual data to JSON: %v", err)
	}

	AssertGolden(t, name+".json", actualJSON)
}

// Snapshot represents a captured prompt and its output.
type Snapshot struct {
	ID        string `json:"id"`
	Prompt    string `json:"prompt"`
	Output    string `json:"output"`
	Timestamp int64  `json:"timestamp"`
	Model     string `json:"model"`
}

// SaveSnapshot saves a prompt/output pair to a snapshot file for later golden testing.
func SaveSnapshot(t *testing.T, name string, snapshot Snapshot) {
	t.Helper()
	AssertGoldenJSON(t, "snapshots/"+name, snapshot)
}

// LoadSnapshot loads a previously saved snapshot.
func LoadSnapshot(t *testing.T, name string) Snapshot {
	t.Helper()
	goldenPath := filepath.Join("testdata", "snapshots", name+".json.golden")
	
	data, err := os.ReadFile(goldenPath)
	if err != nil {
		t.Fatalf("failed to read snapshot file %s: %v", goldenPath, err)
	}

	var snapshot Snapshot
	if err := json.Unmarshal(data, &snapshot); err != nil {
		t.Fatalf("failed to unmarshal snapshot from %s: %v", goldenPath, err)
	}

	return snapshot
}

// Diff compares two strings and returns a human-readable diff (simplified).
func Diff(actual, expected string) string {
	if actual == expected {
		return ""
	}
	
	// Very simple "diff" showing where it first diverges
	minLen := len(actual)
	if len(expected) < minLen {
		minLen = len(expected)
	}
	
	for i := 0; i < minLen; i++ {
		if actual[i] != expected[i] {
			contextStart := i - 20
			if contextStart < 0 {
				contextStart = 0
			}
			contextEndActual := i + 20
			if contextEndActual > len(actual) {
				contextEndActual = len(actual)
			}
			contextEndExpected := i + 20
			if contextEndExpected > len(expected) {
				contextEndExpected = len(expected)
			}
			
			return fmt.Sprintf("Diverges at index %d:\nActual:   ...%s...\nExpected: ...%s...", 
				i, actual[contextStart:contextEndActual], expected[contextStart:contextEndExpected])
		}
	}
	
	return fmt.Sprintf("Length mismatch: Actual=%d, Expected=%d", len(actual), len(expected))
}
