// Package patch implements a safe, atomic patch engine for obot.
package patch

import (
	"context"
	"crypto/sha1"
	"fmt"
	"os"
	"path/filepath"
	"sync"
)

// Patcher handles atomic application of file patches with rollback support.
type Patcher struct {
	mu sync.Mutex
	
	// workDir is the base directory for file operations
	workDir string
	
	// backupDir is where pre-patch versions of files are stored
	backupDir string
}

// NewPatcher creates a new patch engine.
func NewPatcher(workDir, backupDir string) *Patcher {
	if backupDir == "" {
		homeDir, _ := os.UserHomeDir()
		backupDir = filepath.Join(homeDir, ".config", "ollamabot", "backups")
	}
	return &Patcher{
		workDir:   workDir,
		backupDir: backupDir,
	}
}

// Patch represents a single file change operation.
type Patch struct {
	Path     string
	NewContent string
	Checksum   string // Expected checksum after apply
}

// ApplyOptions defines configuration for patch application.
type ApplyOptions struct {
	DryRun   bool
	NoBackup bool
	Force    bool
}

// Apply atomically applies a set of patches. 
// If any patch fails, it rolls back all changes in the transaction.
func (p *Patcher) Apply(ctx context.Context, patches []Patch, opts ApplyOptions) error {
	p.mu.Lock()
	defer p.mu.Unlock()

	if len(patches) == 0 {
		return nil
	}

	if opts.DryRun {
		_, err := p.DryRun(patches)
		return err
	}

	// 1. Pre-flight validation
	if errs := p.ValidatePatches(patches); len(errs) > 0 {
		return fmt.Errorf("pre-flight validation failed: %v", errs[0])
	}

	// 2. Create a timestamped backup of all files in the patch
	var txBackupDir string
	if !opts.NoBackup {
		filePaths := make([]string, len(patches))
		for i, patch := range patches {
			filePaths[i] = patch.Path
		}
		
		var err error
		txBackupDir, err = p.CreateBackup(filePaths)
		if err != nil {
			if !opts.Force {
				return fmt.Errorf("failed to create backup: %w (use --force to apply anyway)", err)
			}
			fmt.Fprintf(os.Stderr, "Warning: failed to create backup: %v. Proceeding due to --force.\n", err)
		}
	}

	// 2. Apply changes
	applied := make([]string, 0, len(patches))
	for _, patch := range patches {
		absPath := filepath.Join(p.workDir, patch.Path)
		
		// Ensure directory exists
		if err := os.MkdirAll(filepath.Dir(absPath), 0755); err != nil {
			if txBackupDir != "" {
				_ = p.RestoreBackup(filepath.Base(txBackupDir))
			}
			return fmt.Errorf("failed to ensure directory for %s: %w", patch.Path, err)
		}

		if err := os.WriteFile(absPath, []byte(patch.NewContent), 0644); err != nil {
			if txBackupDir != "" {
				_ = p.RestoreBackup(filepath.Base(txBackupDir))
			}
			return fmt.Errorf("failed to write patch to %s: %w", patch.Path, err)
		}
		applied = append(applied, patch.Path)
	}

	// 3. Validate checksums
	for _, patch := range patches {
		if patch.Checksum != "" {
			if err := p.VerifyChecksum(patch.Path, patch.Checksum); err != nil {
				if txBackupDir != "" {
					_ = p.RestoreBackup(filepath.Base(txBackupDir))
				}
				return fmt.Errorf("checksum verification failed: %w", err)
			}
		}
	}

	return nil
}

// Rollback rolls back a transaction using the backup directory.
func (p *Patcher) Rollback(backupDir string, patches []Patch) error {
	for _, patch := range patches {
		src := filepath.Join(backupDir, patch.Path)
		dst := filepath.Join(p.workDir, patch.Path)
		
		if _, err := os.Stat(src); os.IsNotExist(err) {
			continue
		}

		if err := copyFile(src, dst); err != nil {
			return err
		}
	}
	return nil
}

// VerifyChecksum verifies the SHA1 checksum of a file matches the expected value.
func (p *Patcher) VerifyChecksum(path, expected string) error {
	absPath := filepath.Join(p.workDir, path)
	data, err := os.ReadFile(absPath)
	if err != nil {
		return fmt.Errorf("failed to read file for checksum: %w", err)
	}
	actual := fmt.Sprintf("%x", sha1.Sum(data))
	if actual != expected {
		return fmt.Errorf("checksum mismatch for %s: expected %s, got %s", path, expected, actual)
	}
	return nil
}

// DetectConflict checks if a file has been modified since a known checksum.
// Returns true if the file's current checksum differs from the base checksum.
func (p *Patcher) DetectConflict(path, baseChecksum string) (bool, error) {
	absPath := filepath.Join(p.workDir, path)
	data, err := os.ReadFile(absPath)
	if err != nil {
		return false, fmt.Errorf("failed to read file for conflict detection: %w", err)
	}
	actual := fmt.Sprintf("%x", sha1.Sum(data))
	return actual != baseChecksum, nil
}

// DryRun simulates patch application without modifying files.
func (p *Patcher) DryRun(patches []Patch) ([]string, error) {
	results := make([]string, 0, len(patches))
	for _, patch := range patches {
		results = append(results, fmt.Sprintf("Will update %s (%d bytes)", patch.Path, len(patch.NewContent)))
	}
	return results, nil
}
