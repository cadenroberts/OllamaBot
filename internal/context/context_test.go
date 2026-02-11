package context

import (
	"testing"

	"github.com/croberts/obot/internal/config"
)

func TestNewManager(t *testing.T) {
	uc := config.DefaultUnifiedConfig()
	cfg := uc.Context

	m := NewManager(cfg)
	if m == nil {
		t.Fatal("NewManager returned nil")
	}
}

func TestManager_Build_empty(t *testing.T) {
	uc := config.DefaultUnifiedConfig()
	cfg := uc.Context
	m := NewManager(cfg)

	built, err := m.Build(BuildOptions{})
	if err != nil {
		t.Fatalf("Build failed: %v", err)
	}
	if built == nil {
		t.Fatal("Build returned nil")
	}
	if built.TokenBudget <= 0 {
		t.Errorf("TokenBudget should be positive, got %d", built.TokenBudget)
	}
}

func TestManager_Build_withTask(t *testing.T) {
	uc := config.DefaultUnifiedConfig()
	cfg := uc.Context
	m := NewManager(cfg)

	built, err := m.Build(BuildOptions{Task: "Fix the bug in main.go"})
	if err != nil {
		t.Fatalf("Build failed: %v", err)
	}
	if built == nil {
		t.Fatal("Build returned nil")
	}
	if built.UserPrompt == "" {
		t.Error("UserPrompt should contain task when Task is provided")
	}
	if built.TokensUsed <= 0 {
		t.Errorf("TokensUsed should be positive, got %d", built.TokensUsed)
	}
}
