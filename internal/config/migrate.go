package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// MigrateFromJSON detects old JSON config at ~/.config/obot/config.json,
// converts it to the unified YAML format, and creates a backward-compat symlink.
func MigrateFromJSON() (bool, error) {
	oldDir := getConfigDir()
	oldPath := filepath.Join(oldDir, "config.json")

	data, err := os.ReadFile(oldPath)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil // nothing to migrate
		}
		return false, fmt.Errorf("read old config: %w", err)
	}

	// Parse old JSON config
	var oldCfg Config
	if err := json.Unmarshal(data, &oldCfg); err != nil {
		return false, fmt.Errorf("parse old config: %w", err)
	}

	// Build unified config from old values
	unified := DefaultUnifiedConfig()
	if oldCfg.OllamaURL != "" {
		unified.Ollama.URL = oldCfg.OllamaURL
	}
	if oldCfg.MaxTokens > 0 {
		unified.Context.MaxTokens = oldCfg.MaxTokens
	}
	unified.Platforms.CLI.Verbose = oldCfg.Verbose

	// Save unified config
	if err := SaveUnifiedConfig(unified); err != nil {
		return false, fmt.Errorf("save unified config: %w", err)
	}

	// Create backward-compat symlink: ~/.config/obot -> ~/.config/ollamabot
	newDir := UnifiedConfigDir()
	if oldDir != newDir {
		// Rename old dir out of the way
		backupDir := oldDir + ".bak"
		if _, err := os.Stat(oldDir); err == nil {
			_ = os.Rename(oldDir, backupDir)
		}
		// Create symlink
		_ = os.Symlink(newDir, oldDir)
	}

	return true, nil
}

// EnsureUnifiedConfigDir creates the unified config directory and required subdirs.
func EnsureUnifiedConfigDir() error {
	dirs := []string{
		UnifiedConfigDir(),
		filepath.Join(UnifiedConfigDir(), "schemas"),
		filepath.Join(UnifiedConfigDir(), "sessions"),
		filepath.Join(UnifiedConfigDir(), "prompts"),
	}
	for _, dir := range dirs {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return fmt.Errorf("create dir %s: %w", dir, err)
		}
	}
	return nil
}

// EnsureBackwardCompatSymlink creates ~/.config/obot -> ~/.config/ollamabot if needed.
func EnsureBackwardCompatSymlink() error {
	oldDir := getConfigDir()
	newDir := UnifiedConfigDir()
	if oldDir == newDir {
		return nil
	}

	// Check if old dir is already a symlink pointing to new dir
	target, err := os.Readlink(oldDir)
	if err == nil && target == newDir {
		return nil // already correct
	}

	// If old dir exists and is a real directory, skip (don't clobber)
	info, err := os.Lstat(oldDir)
	if err == nil && info.IsDir() && info.Mode()&os.ModeSymlink == 0 {
		return nil // real directory exists, leave it alone
	}

	// Create symlink
	_ = os.Remove(oldDir) // remove stale symlink if any
	return os.Symlink(newDir, oldDir)
}
