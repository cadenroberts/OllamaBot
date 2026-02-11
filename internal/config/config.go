package config

import (
	"encoding/json"
	"os"
	"path/filepath"
)

// Config holds obot configuration (wraps UnifiedConfig for backward compatibility)
type Config struct {
	Unified *UnifiedConfig

	// model legacy fields
	Tier           string `json:"tier"`
	Model          string `json:"model"`
	AutoDetectTier bool   `json:"auto_detect_tier"`

	// Ollama legacy fields
	OllamaURL string `json:"ollama_url"`

	// Behavior legacy fields
	Verbose     bool    `json:"verbose"`
	Temperature float64 `json:"temperature"`
	MaxTokens   int     `json:"max_tokens"`

	// Internal
	path string
}

// Default returns the default configuration
func Default() *Config {
	uc := DefaultUnifiedConfig()
	return &Config{
		Unified:        uc,
		Tier:           "balanced",
		Model:          uc.Models.Coder.Default,
		AutoDetectTier: uc.Models.TierDetection.Auto,
		OllamaURL:      uc.Ollama.URL,
		Verbose:        uc.Platforms.CLI.Verbose,
		Temperature:    0.3,
		MaxTokens:      uc.Context.MaxTokens,
	}
}

// getConfigDir returns the config directory path
func getConfigDir() string {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		homeDir = "."
	}
	return filepath.Join(homeDir, ".config", "obot")
}

// getConfigPath returns the config file path
func getConfigPath() string {
	return filepath.Join(getConfigDir(), "config.json")
}

// Path returns the config file path
func (c *Config) Path() string {
	if c.path != "" {
		return c.path
	}
	return getConfigPath()
}

// Load loads configuration from disk
func Load() (*Config, error) {
	// Try YAML first
	uc, err := LoadUnifiedConfig()
	if err == nil {
		cfg := Default()
		cfg.Unified = uc
		// Sync legacy fields
		cfg.Tier = "balanced"
		cfg.Model = uc.Models.Coder.Default
		cfg.AutoDetectTier = uc.Models.TierDetection.Auto
		cfg.OllamaURL = uc.Ollama.URL
		cfg.Verbose = uc.Platforms.CLI.Verbose
		cfg.MaxTokens = uc.Context.MaxTokens
		return cfg, nil
	}

	// Fallback to legacy JSON
	configPath := getConfigPath()
	data, err := os.ReadFile(configPath)
	if err != nil {
		if os.IsNotExist(err) {
			return Default(), nil
		}
		return nil, err
	}

	cfg := Default()
	if err := json.Unmarshal(data, cfg); err != nil {
		return nil, err
	}
	return cfg, nil
}

// Save saves configuration to disk
func (c *Config) Save() error {
	// Always save as unified YAML
	if c.Unified != nil {
		return SaveUnifiedConfig(c.Unified)
	}
	
	// Fallback if unified is missing (shouldn't happen with Default())
	uc := DefaultUnifiedConfig()
	uc.Ollama.URL = c.OllamaURL
	uc.Context.MaxTokens = c.MaxTokens
	return SaveUnifiedConfig(uc)
}

// EnsureConfigDir ensures the config directory exists
func EnsureConfigDir() error {
	return os.MkdirAll(getConfigDir(), 0755)
}

// GetConfigDir returns the config directory path (for external use)
func GetConfigDir() string {
	return getConfigDir()
}
