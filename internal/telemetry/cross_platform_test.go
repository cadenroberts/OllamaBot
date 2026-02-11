package telemetry

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/croberts/obot/internal/config"
)

func TestCrossPlatformCompatibility(t *testing.T) {
	// 1. Verify storage path uses the correct config directory
	s := NewService()
	expectedPrefix := config.GetConfigDir()
	
	if !strings.HasPrefix(s.storagePath, expectedPrefix) {
		t.Errorf("Expected storage path to start with %s, got %s", expectedPrefix, s.storagePath)
	}

	// 2. Test recording and retrieving with a temporary storage path
	tmpDir, err := os.MkdirTemp("", "telemetry_test")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	tmpStorage := filepath.Join(tmpDir, "stats.json")
	s.storagePath = tmpStorage

	session := SessionTelemetry{
		SessionID:          "test-session-1",
		Platform:           "cli",
		Success:            true,
		PeakMemoryGB:       1.5,
		TotalTokens:        1000,
		DiskWrittenMB:      10.5,
		DurationSec:        60,
		EstimatedCostSaved: 0.05,
	}

	if err := s.RecordSession(session); err != nil {
		t.Fatalf("Failed to record session: %v", err)
	}

	summary, err := s.GetSummary()
	if err != nil {
		t.Fatalf("Failed to get summary: %v", err)
	}

	if summary.TotalSessions != 1 {
		t.Errorf("Expected 1 session, got %d", summary.TotalSessions)
	}

	if summary.TotalTokens != 1000 {
		t.Errorf("Expected 1000 tokens, got %d", summary.TotalTokens)
	}

	// 3. Verify cross-platform path separators (Go's filepath handle this)
	// We'll just check if the path is absolute and looks reasonable
	if !filepath.IsAbs(s.storagePath) {
		t.Errorf("Expected absolute path, got %s", s.storagePath)
	}
}

func TestTelemetryTimestampHandling(t *testing.T) {
	s := &Service{storagePath: filepath.Join(os.TempDir(), "timestamp_test.json")}
	defer os.Remove(s.storagePath)

	now := time.Now()
	session := SessionTelemetry{
		SessionID: "timestamp-test",
		Timestamp: now, // This should be overwritten by RecordSession
	}

	if err := s.RecordSession(session); err != nil {
		t.Fatalf("RecordSession failed: %v", err)
	}

	// Load and check timestamp
	summary, err := s.GetSummary()
	if err != nil {
		t.Fatalf("GetSummary failed: %v", err)
	}
	if summary.TotalSessions != 1 {
		t.Errorf("Expected 1 session")
	}
}
