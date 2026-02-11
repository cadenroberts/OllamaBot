package ui

import (
	"bytes"
	"strings"
	"testing"
)

func TestNewMemoryVisualization(t *testing.T) {
	var buf bytes.Buffer
	m := NewMemoryVisualization(&buf, 80)
	if m == nil {
		t.Fatal("NewMemoryVisualization returned nil")
	}
	if m.width != 80 {
		t.Errorf("Expected width 80, got %d", m.width)
	}
	if m.totalGB != 8.0 {
		t.Errorf("Expected default totalGB 8.0, got %f", m.totalGB)
	}
}

func TestMemoryUpdateAndStats(t *testing.T) {
	var buf bytes.Buffer
	m := NewMemoryVisualization(&buf, 80)
	
	m.Update(2.0, 0)
	m.Update(4.0, 0)
	m.Update(3.0, 0)
	
	min, max, avg := m.GetHistoryStats()
	if min != 2.0 {
		t.Errorf("Expected min 2.0, got %f", min)
	}
	if max != 4.0 {
		t.Errorf("Expected max 4.0, got %f", max)
	}
	if avg != 3.0 {
		t.Errorf("Expected avg 3.0, got %f", avg)
	}
	
	if m.GetPeakGB() != 4.0 {
		t.Errorf("Expected peak 4.0, got %f", m.GetPeakGB())
	}
}

func TestPrediction(t *testing.T) {
	var buf bytes.Buffer
	m := NewMemoryVisualization(&buf, 80)
	
	m.SetPrediction(5.5, "Test", "Basis")
	gb, label, basis := m.GetPrediction()
	
	if gb != 5.5 {
		t.Errorf("Expected predictGB 5.5, got %f", gb)
	}
	if label != "Test" {
		t.Errorf("Expected label 'Test', got '%s'", label)
	}
	if basis != "Basis" {
		t.Errorf("Expected basis 'Basis', got '%s'", basis)
	}
}

func TestPressureStatus(t *testing.T) {
	var buf bytes.Buffer
	m := NewMemoryVisualization(&buf, 80)
	m.SetTotalMemory(10.0)
	
	m.Update(2.0, 0)
	status := m.GetPressureStatus()
	if !strings.Contains(status, "NORMAL") {
		t.Errorf("Expected NORMAL status for 20%% usage, got %s", status)
	}
	
	m.Update(8.5, 0)
	status = m.GetPressureStatus()
	if !strings.Contains(status, "WARNING") {
		t.Errorf("Expected WARNING status for 85%% usage, got %s", status)
	}
	
	m.Update(9.6, 0)
	status = m.GetPressureStatus()
	if !strings.Contains(status, "CRITICAL") {
		t.Errorf("Expected CRITICAL status for 96%% usage, got %s", status)
	}
}

func TestFormatBytes(t *testing.T) {
	tests := []struct {
		bytes    int64
		expected string
	}{
		{512, "512 B"},
		{1024, "1.0 KB"},
		{1024 * 1024, "1.0 MB"},
		{1024 * 1024 * 1024, "1.0 GB"},
	}
	
	for _, tt := range tests {
		result := formatBytes(tt.bytes)
		if result != tt.expected {
			t.Errorf("formatBytes(%d): expected %s, got %s", tt.bytes, tt.expected, result)
		}
	}
}

func TestGetTrend(t *testing.T) {
	var buf bytes.Buffer
	m := NewMemoryVisualization(&buf, 80)
	
	// Not enough samples
	if m.GetTrendGBps() != 0 {
		t.Errorf("Expected 0 trend for <5 samples")
	}
	
	for i := 1.0; i <= 6.0; i++ {
		m.Update(i, 0)
	}
	
	trend := m.GetTrendGBps()
	if trend <= 0 {
		t.Errorf("Expected positive trend, got %f", trend)
	}
}

func TestGetPercentile(t *testing.T) {
	var buf bytes.Buffer
	m := NewMemoryVisualization(&buf, 80)
	
	for i := 1.0; i <= 10.0; i++ {
		m.Update(i, 0)
	}
	
	p50 := m.GetPercentile(50)
	if p50 < 5.0 || p50 > 6.0 {
		t.Errorf("Expected p50 around 5.5, got %f", p50)
	}
}

func TestVolatility(t *testing.T) {
	var buf bytes.Buffer
	m := NewMemoryVisualization(&buf, 80)
	
	m.Update(10.0, 0)
	m.Update(10.0, 0)
	if m.GetVolatility() != 0 {
		t.Errorf("Expected 0 volatility for constant values")
	}
	
	m.Update(20.0, 0)
	if m.GetVolatility() <= 0 {
		t.Errorf("Expected positive volatility after change")
	}
}
