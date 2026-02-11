package telemetry

import (
	"os"
	"path/filepath"
	"testing"
)

func TestStatsAccumulateCorrectly(t *testing.T) {
	// Create a temporary directory for config
	tmpDir, err := os.MkdirTemp("", "telemetry-accumulate-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	storagePath := filepath.Join(tmpDir, "stats.json")
	s := &Service{storagePath: storagePath}

	// Define test data
	sessions := []SessionTelemetry{
		{
			SessionID:          "s1",
			Success:            true,
			PeakMemoryGB:       1.0,
			TotalTokens:        1000,
			DiskWrittenMB:      10.0,
			DurationSec:        3600, // 1 hour
			EstimatedCostSaved: 0.50,
		},
		{
			SessionID:          "s2",
			Success:            false,
			PeakMemoryGB:       2.0,
			TotalTokens:        2000,
			DiskWrittenMB:      20.0,
			DurationSec:        1800, // 0.5 hours
			EstimatedCostSaved: 0.25,
		},
	}

	// Record sessions
	for _, sess := range sessions {
		if err := s.RecordSession(sess); err != nil {
			t.Fatalf("RecordSession failed: %v", err)
		}
	}

	// Get summary
	summary, err := s.GetSummary()
	if err != nil {
		t.Fatalf("GetSummary failed: %v", err)
	}

	// Validate accumulation
	if summary.TotalSessions != 2 {
		t.Errorf("TotalSessions: expected 2, got %d", summary.TotalSessions)
	}
	if summary.SuccessRate != 0.5 {
		t.Errorf("SuccessRate: expected 0.5, got %f", summary.SuccessRate)
	}
	if summary.TotalTokens != 3000 {
		t.Errorf("TotalTokens: expected 3000, got %d", summary.TotalTokens)
	}
	if summary.TotalEstimatedCost != 0.75 {
		t.Errorf("TotalEstimatedCost: expected 0.75, got %f", summary.TotalEstimatedCost)
	}
	if summary.AverageMemoryGB != 1.5 {
		t.Errorf("AverageMemoryGB: expected 1.5, got %f", summary.AverageMemoryGB)
	}
	if summary.TotalDiskWrittenMB != 30.0 {
		t.Errorf("TotalDiskWrittenMB: expected 30.0, got %f", summary.TotalDiskWrittenMB)
	}
	if summary.TotalDurationHours != 1.5 {
		t.Errorf("TotalDurationHours: expected 1.5, got %f", summary.TotalDurationHours)
	}
}
