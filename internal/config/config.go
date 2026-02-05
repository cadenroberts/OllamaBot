package config

import (
	"encoding/json"
	"os"
	"path/filepath"
)

// Config holds obot configuration
type Config struct {
	// Model configuration
	Tier           string `json:"tier"`
	Model          string `json:"model"`
	AutoDetectTier bool   `json:"auto_detect_tier"`

	// Ollama settings
	OllamaURL string `json:"ollama_url"`

	// Behavior settings
	Verbose     bool    `json:"verbose"`
	Temperature float64 `json:"temperature"`
	MaxTokens   int     `json:"max_tokens"`

	// Internal
	path string
}

// Default returns the default configuration
func Default() *Config {
	return &Config{
		Tier:           "auto",
		Model:          "",
		AutoDetectTier: true,
		OllamaURL:      "http://localhost:11434",
		Verbose:        true,
		Temperature:    0.3,
		MaxTokens:      4096,
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
	configPath := getConfigPath()

	data, err := os.ReadFile(configPath)
	if err != nil {
		if os.IsNotExist(err) {
			// Return default config if file doesn't exist
			cfg := Default()
			cfg.path = configPath
			return cfg, nil
		}
		return nil, err
	}

	cfg := Default()
	if err := json.Unmarshal(data, cfg); err != nil {
		return nil, err
	}

	cfg.path = configPath
	return cfg, nil
}

// Save saves configuration to disk
func (c *Config) Save() error {
	// Ensure directory exists
	configDir := getConfigDir()
	if err := os.MkdirAll(configDir, 0755); err != nil {
		return err
	}

	data, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(getConfigPath(), data, 0644)
}

// EnsureConfigDir ensures the config directory exists
func EnsureConfigDir() error {
	return os.MkdirAll(getConfigDir(), 0755)
}

// GetConfigDir returns the config directory path (for external use)
func GetConfigDir() string {
	return getConfigDir()
}
