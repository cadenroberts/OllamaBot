package git

import (
	"os"
	"path/filepath"
	"testing"
)

func TestNewGitHubClient(t *testing.T) {
	// Create a temporary token file
	tmpDir, err := os.MkdirTemp("", "github-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	tokenPath := filepath.Join(tmpDir, "token")
	err = os.WriteFile(tokenPath, []byte("test-token"), 0644)
	if err != nil {
		t.Fatal(err)
	}

	client, err := NewGitHubClient(tokenPath)
	if err != nil {
		t.Fatalf("NewGitHubClient failed: %v", err)
	}

	if client.token != "test-token" {
		t.Errorf("Expected token 'test-token', got '%s'", client.token)
	}

	if client.baseURL != "https://api.github.com" {
		t.Errorf("Expected baseURL 'https://api.github.com', got '%s'", client.baseURL)
	}
}

func TestExpandPath(t *testing.T) {
	tests := []struct {
		path     string
		contains string
	}{
		{"/abs/path", "/abs/path"},
		{"rel/path", "rel/path"},
	}

	for _, tt := range tests {
		result := expandPath(tt.path)
		if result != tt.path {
			t.Errorf("expandPath(%s): expected %s, got %s", tt.path, tt.path, result)
		}
	}
	
	// Test tilde expansion if HOME is set
	if home, err := os.UserHomeDir(); err == nil {
		result := expandPath("~/test")
		expected := filepath.Join(home, "test")
		if result != expected {
			t.Errorf("expandPath(~): expected %s, got %s", expected, result)
		}
	}
}
