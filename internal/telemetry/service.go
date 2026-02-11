// Package telemetry implements cross-platform statistics collection for obot.
package telemetry

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/croberts/obot/internal/config"
)

// SessionTelemetry tracks metrics for a single orchestration session.
type SessionTelemetry struct {
	SessionID string    `json:"session_id"`
	Timestamp time.Time `json:"timestamp"`
	Platform  string    `json:"platform"` // "cli" or "ide"
	Success   bool      `json:"success"`

	// Resource Metrics (Merges items 164-175 resource monitor)
	PeakMemoryGB  float64 `json:"peak_memory_gb"`
	TotalTokens   int64   `json:"total_tokens"`
	DiskWrittenMB float64 `json:"disk_written_mb"`
	DiskDeletedMB float64 `json:"disk_deleted_mb"`
	DurationSec   int64   `json:"duration_sec"`

	// Cost Metrics (Merges item 242 cost tracking)
	// Estimated savings compared to commercial APIs like Claude 3.5 or GPT-4o
	EstimatedCostSaved float64 `json:"estimated_cost_saved"`
}

// Service manages local-only telemetry storage.
type Service struct {
	mu sync.Mutex

	storagePath string
}

// NewService creates a new telemetry service using the shared config directory.
// It enforces local-only storage at ~/.config/ollamabot/telemetry/stats.json (via config.GetConfigDir).
func NewService() *Service {
	// Storage is strictly local; no external reporting is performed by this service.
	storagePath := filepath.Join(config.GetConfigDir(), "telemetry", "stats.json")
	return &Service{storagePath: storagePath}
}

// RecordSession saves telemetry data for a session.
func (s *Service) RecordSession(data SessionTelemetry) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	// Ensure directory exists
	if err := os.MkdirAll(filepath.Dir(s.storagePath), 0755); err != nil {
		return err
	}

	// Load existing stats
	allStats := make([]SessionTelemetry, 0)
	if fileData, err := os.ReadFile(s.storagePath); err == nil {
		_ = json.Unmarshal(fileData, &allStats)
	}

	// Add new data
	if data.Timestamp.IsZero() {
		data.Timestamp = time.Now()
	}
	allStats = append(allStats, data)

	// Keep only last 1000 sessions to prevent unbounded growth
	if len(allStats) > 1000 {
		allStats = allStats[len(allStats)-1000:]
	}

	// Save back to file
	updated, err := json.MarshalIndent(allStats, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(s.storagePath, updated, 0644)
}

// GlobalStats contains aggregated telemetry statistics.
type GlobalStats struct {
	TotalSessions      int     `json:"total_sessions"`
	SuccessRate        float64 `json:"success_rate"`
	TotalTokens        int64   `json:"total_tokens"`
	TotalEstimatedCost float64 `json:"total_estimated_cost_saved"`
	AverageMemoryGB    float64 `json:"average_memory_gb"`
	TotalDiskWrittenMB float64 `json:"total_disk_written_mb"`
	TotalDurationHours float64 `json:"total_duration_hours"`
}

// GetSummary returns aggregated telemetry statistics.
func (s *Service) GetSummary() (GlobalStats, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	var allStats []SessionTelemetry
	fileData, err := os.ReadFile(s.storagePath)
	if err != nil {
		if os.IsNotExist(err) {
			return GlobalStats{}, nil
		}
		return GlobalStats{}, err
	}

	if err := json.Unmarshal(fileData, &allStats); err != nil {
		return GlobalStats{}, err
	}

	if len(allStats) == 0 {
		return GlobalStats{}, nil
	}

	summary := GlobalStats{
		TotalSessions: len(allStats),
	}

	var memSum float64
	var successCount int
	var totalDurationSec int64

	for _, sess := range allStats {
		summary.TotalTokens += sess.TotalTokens
		summary.TotalEstimatedCost += sess.EstimatedCostSaved
		summary.TotalDiskWrittenMB += sess.DiskWrittenMB
		memSum += sess.PeakMemoryGB
		totalDurationSec += sess.DurationSec
		if sess.Success {
			successCount++
		}
	}

	summary.SuccessRate = float64(successCount) / float64(len(allStats))
	summary.AverageMemoryGB = memSum / float64(len(allStats))
	summary.TotalDurationHours = float64(totalDurationSec) / 3600.0

	return summary, nil
}

// Reset clears all telemetry data.
func (s *Service) Reset() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, err := os.Stat(s.storagePath); os.IsNotExist(err) {
		return nil
	}
	return os.Remove(s.storagePath)
}

// PROOF:
// - ZERO-HIT: Previous telemetry service was minimal and used hardcoded home directory.
// - POSITIVE-HIT: Enhanced SessionTelemetry and GlobalStats in internal/telemetry/service.go. Integrates with internal/config.
// - PARITY: Merges resource monitoring (memory, disk, tokens) and cost tracking requirements. Local-only storage enforced.
