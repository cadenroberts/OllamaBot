package telemetry

import (
	"testing"
	"time"
)

func TestMetricsTrackedProperly(t *testing.T) {
	m := &PerformanceMetrics{}

	// Test Latency
	m.RecordLatency(100 * time.Millisecond)
	if m.FirstTokenLatency != 100*time.Millisecond {
		t.Errorf("Expected 100ms, got %v", m.FirstTokenLatency)
	}
	m.RecordLatency(200 * time.Millisecond)
	// EMA: 100*0.7 + 200*0.3 = 70 + 60 = 130ms
	if m.FirstTokenLatency != 130*time.Millisecond {
		t.Errorf("Expected 130ms (EMA alpha=0.3), got %v", m.FirstTokenLatency)
	}

	// Test Patch Success Rate
	m.RecordPatch(true)
	m.RecordPatch(false)
	if m.PatchSuccessRate != 0.5 {
		t.Errorf("Expected 0.5, got %f", m.PatchSuccessRate)
	}
	m.RecordPatch(true)
	if m.PatchSuccessRate != 2.0/3.0 {
		t.Errorf("Expected 0.666..., got %f", m.PatchSuccessRate)
	}

	// Test User Acceptance Rate
	m.RecordAcceptance(true)
	m.RecordAcceptance(true)
	m.RecordAcceptance(false)
	if m.UserAcceptanceRate != 2.0/3.0 {
		t.Errorf("Expected 0.666..., got %f", m.UserAcceptanceRate)
	}

	// Test Median Time to Fix
	m.AddFixDuration(10 * time.Second)
	if m.MedianTimeToFix != 10*time.Second {
		t.Errorf("Expected 10s, got %v", m.MedianTimeToFix)
	}
	m.AddFixDuration(30 * time.Second)
	if m.MedianTimeToFix != 20*time.Second {
		t.Errorf("Expected 20s (median of 10, 30), got %v", m.MedianTimeToFix)
	}
	m.AddFixDuration(20 * time.Second)
	if m.MedianTimeToFix != 20*time.Second {
		t.Errorf("Expected 20s (median of 10, 20, 30), got %v", m.MedianTimeToFix)
	}
	m.AddFixDuration(5 * time.Second)
	if m.MedianTimeToFix != 15*time.Second {
		t.Errorf("Expected 15s (median of 5, 10, 20, 30), got %v", m.MedianTimeToFix)
	}
}
