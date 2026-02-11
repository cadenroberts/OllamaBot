package config

import (
	"path/filepath"
	"strings"
	"testing"
)

func TestDefault(t *testing.T) {
	cfg := Default()
	if cfg == nil {
		t.Fatal("Default returned nil")
	}
	if cfg.Unified == nil {
		t.Fatal("Default config should have Unified set")
	}
	if cfg.Tier != "balanced" {
		t.Errorf("default Tier = %q, want balanced", cfg.Tier)
	}
	if cfg.Temperature != 0.3 {
		t.Errorf("default Temperature = %v, want 0.3", cfg.Temperature)
	}
	if cfg.OllamaURL == "" {
		t.Error("OllamaURL should not be empty")
	}
}

func TestConfig_Path(t *testing.T) {
	cfg := Default()
	p := cfg.Path()
	if p == "" {
		t.Fatal("Path returned empty")
	}
	if !strings.Contains(p, "config") {
		t.Errorf("Path should contain 'config', got %q", p)
	}
}

func TestGetConfigDir(t *testing.T) {
	dir := GetConfigDir()
	if dir == "" {
		t.Fatal("GetConfigDir returned empty")
	}
	// Legacy config dir is ~/.config/obot (kept for backward compat)
	if !strings.HasSuffix(dir, filepath.Join(".config", "obot")) {
		t.Errorf("GetConfigDir (legacy) should end with .config/obot, got %q", dir)
	}
}

func TestUnifiedConfigDir(t *testing.T) {
	dir := UnifiedConfigDir()
	if dir == "" {
		t.Fatal("UnifiedConfigDir returned empty")
	}
	if !strings.HasSuffix(dir, filepath.Join(".config", "ollamabot")) {
		t.Errorf("UnifiedConfigDir should end with .config/ollamabot, got %q", dir)
	}
}
