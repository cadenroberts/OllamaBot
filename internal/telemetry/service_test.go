package telemetry

import (
	"os"
	"path/filepath"
	"testing"
)

func TestTelemetryService(t *testing.T) {
	// Create a temporary directory for config
	tmpDir, err := os.MkdirTemp("", "telemetry-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	storagePath := filepath.Join(tmpDir, "stats.json")
	s := &Service{storagePath: storagePath}

	// 1. Record a session
	data := SessionTelemetry{
		SessionID:          "test-sess-1",
		Platform:           "cli",
		Success:            true,
		PeakMemoryGB:       4.5,
		TotalTokens:        5000,
		DiskWrittenMB:      10.2,
		DurationSec:        300,
		EstimatedCostSaved: 0.15,
	}

	if err := s.RecordSession(data); err != nil {
		t.Fatalf("RecordSession failed: %v", err)
	}

	// 2. Record another session
	data2 := SessionTelemetry{
		SessionID:          "test-sess-2",
		Platform:           "ide",
		Success:            false,
		PeakMemoryGB:       2.1,
		TotalTokens:        2000,
		DiskWrittenMB:      5.0,
		DurationSec:        120,
		EstimatedCostSaved: 0.05,
	}

	if err := s.RecordSession(data2); err != nil {
		t.Fatalf("RecordSession failed: %v", err)
	}

	// 3. Get summary
	summary, err := s.GetSummary()
	if err != nil {
		t.Fatalf("GetSummary failed: %v", err)
	}

	if summary.TotalSessions != 2 {
		t.Errorf("Expected 2 sessions, got %d", summary.TotalSessions)
	}
	if summary.SuccessRate != 0.5 {
		t.Errorf("Expected 0.5 success rate, got %f", summary.SuccessRate)
	}
	if summary.TotalTokens != 7000 {
		t.Errorf("Expected 7000 tokens, got %d", summary.TotalTokens)
	}
	if summary.AverageMemoryGB != 3.3 {
		t.Errorf("Expected 3.3 avg memory, got %f", summary.AverageMemoryGB)
	}

	// 4. Reset
	if err := s.Reset(); err != nil {
		t.Fatalf("Reset failed: %v", err)
	}

	summary2, _ := s.GetSummary()
	if summary2.TotalSessions != 0 {
		t.Errorf("Expected 0 sessions after reset, got %d", summary2.TotalSessions)
	}
}
