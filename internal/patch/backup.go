// Package patch implements a safe, atomic patch engine for obot.
package patch

import (
	"fmt"
	"os"
	"path/filepath"
	"time"
)

// CreateBackup creates a backup of the given file paths.
func (p *Patcher) CreateBackup(paths []string) (string, error) {
	timestamp := time.Now().Format("20060102_150405")
	txBackupDir := filepath.Join(p.backupDir, timestamp)

	if err := os.MkdirAll(txBackupDir, 0755); err != nil {
		return "", err
	}

	for _, path := range paths {
		src := filepath.Join(p.workDir, path)
		dst := filepath.Join(txBackupDir, path)
		
		if _, err := os.Stat(src); os.IsNotExist(err) {
			continue // New file, nothing to back up
		}

		if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
			return "", err
		}

		if err := copyFile(src, dst); err != nil {
			return "", err
		}
	}

	return txBackupDir, nil
}

// ListBackups returns a list of available backup timestamps.
func (p *Patcher) ListBackups() ([]string, error) {
	entries, err := os.ReadDir(p.backupDir)
	if err != nil {
		if os.IsNotExist(err) {
			return []string{}, nil
		}
		return nil, fmt.Errorf("failed to list backups: %w", err)
	}

	var backups []string
	for _, entry := range entries {
		if entry.IsDir() {
			backups = append(backups, entry.Name())
		}
	}
	return backups, nil
}

// RestoreBackup restores files from a specific backup timestamp.
func (p *Patcher) RestoreBackup(timestamp string) error {
	txBackupDir := filepath.Join(p.backupDir, timestamp)
	if _, err := os.Stat(txBackupDir); os.IsNotExist(err) {
		return fmt.Errorf("backup %s not found", timestamp)
	}

	return filepath.Walk(txBackupDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if info.IsDir() {
			return nil
		}

		relPath, err := filepath.Rel(txBackupDir, path)
		if err != nil {
			return err
		}

		targetPath := filepath.Join(p.workDir, relPath)
		
		if err := os.MkdirAll(filepath.Dir(targetPath), 0755); err != nil {
			return err
		}

		return copyFile(path, targetPath)
	})
}

func copyFile(src, dst string) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return os.WriteFile(dst, data, 0644)
}

// PruneBackups removes backups older than the specified duration.
func (p *Patcher) PruneBackups(olderThan time.Duration) (int, error) {
	entries, err := os.ReadDir(p.backupDir)
	if err != nil {
		if os.IsNotExist(err) {
			return 0, nil
		}
		return 0, err
	}

	count := 0
	now := time.Now()
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		info, err := entry.Info()
		if err != nil {
			continue
		}

		if now.Sub(info.ModTime()) > olderThan {
			if err := os.RemoveAll(filepath.Join(p.backupDir, entry.Name())); err == nil {
				count++
			}
		}
	}

	return count, nil
}
