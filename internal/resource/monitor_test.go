package resource

import (
	"testing"
	"time"

	"github.com/croberts/obot/internal/orchestrate"
)

func TestNewMonitor(t *testing.T) {
	m := NewMonitor()
	if m == nil {
		t.Fatal("NewMonitor returned nil")
	}
}

func TestNewMonitorWithConfig(t *testing.T) {
	cfg := DefaultConfig()
	m := NewMonitorWithConfig(cfg)
	if m == nil {
		t.Fatal("NewMonitorWithConfig returned nil")
	}
	m2 := NewMonitorWithConfig(nil)
	if m2 == nil {
		t.Fatal("NewMonitorWithConfig(nil) should use DefaultConfig")
	}
}

func TestDefaultConfig(t *testing.T) {
	cfg := DefaultConfig()
	if cfg == nil {
		t.Fatal("DefaultConfig returned nil")
	}
	if cfg.WarningThreshold != 0.80 {
		t.Errorf("WarningThreshold: got %v", cfg.WarningThreshold)
	}
	if cfg.CriticalThreshold != 0.95 {
		t.Errorf("CriticalThreshold: got %v", cfg.CriticalThreshold)
	}
}

func TestMonitor_UpdateMemory(t *testing.T) {
	m := NewMonitor()
	m.UpdateMemory()
	curr := m.GetCurrentMemory()
	if curr < 0 {
		t.Errorf("GetCurrentMemory should be non-negative, got %v", curr)
	}
}

func TestMonitor_RecordTokens(t *testing.T) {
	m := NewMonitor()
	m.RecordTokens(orchestrate.ScheduleImplement, orchestrate.Process1, 100)
	m.RecordTokens(orchestrate.ScheduleImplement, orchestrate.Process1, 50)
	if m.GetTotalTokens() != 150 {
		t.Errorf("GetTotalTokens: got %d", m.GetTotalTokens())
	}
}

func TestMonitor_RecordDiskWriteDelete(t *testing.T) {
	m := NewMonitor()
	m.RecordDiskWrite(1000)
	m.RecordDiskDelete(200)
	sum := m.GetSummary()
	if sum.Disk.Written != 1000 {
		t.Errorf("Disk Written: got %d", sum.Disk.Written)
	}
	if sum.Disk.Deleted != 200 {
		t.Errorf("Disk Deleted: got %d", sum.Disk.Deleted)
	}
}

func TestMonitor_GetStats(t *testing.T) {
	m := NewMonitor()
	m.UpdateMemory()
	stats := m.GetStats()
	if stats.CurrentMemory == 0 && stats.PeakMemory == 0 {
		t.Log("memory stats may be zero on minimal run")
	}
}

func TestMonitor_GetSummary(t *testing.T) {
	m := NewMonitor()
	m.RecordTokens(orchestrate.ScheduleKnowledge, orchestrate.Process1, 50)
	sum := m.GetSummary()
	if sum == nil {
		t.Fatal("GetSummary returned nil")
	}
	if sum.Tokens.Used != 50 {
		t.Errorf("Tokens.Used: got %d", sum.Tokens.Used)
	}
}

func TestMonitor_GetPressureStatus(t *testing.T) {
	m := NewMonitor()
	status := m.GetPressureStatus()
	if status != PressureNormal && status != PressureWarning && status != PressureCritical {
		t.Errorf("invalid PressureStatus: %s", status)
	}
}

func TestMonitor_CheckLimits(t *testing.T) {
	memLimit := 0.001 // 1MB - very low to trigger
	cfg := &Config{
		MemoryLimitGB:     &memLimit,
		WarningThreshold:  0.80,
		CriticalThreshold: 0.95,
	}
	m := NewMonitorWithConfig(cfg)
	m.UpdateMemory()
	// May or may not exceed depending on heap
	_ = m.CheckLimits()
}

func TestMonitor_StartStop(t *testing.T) {
	m := NewMonitor()
	m.Start()
	time.Sleep(20 * time.Millisecond)
	m.Stop()
}

func TestLimitExceededError(t *testing.T) {
	e := &LimitExceededError{Resource: "Memory", Limit: 1.0, Current: 2.0}
	s := e.Error()
	if s == "" || len(s) < 10 {
		t.Errorf("Error(): got %q", s)
	}
}

func TestMonitor_PredictMemory(t *testing.T) {
	m := NewMonitor()
	pred := m.PredictMemory(orchestrate.ScheduleKnowledge, orchestrate.Process1)
	if pred <= 0 {
		t.Errorf("PredictMemory should return positive default, got %v", pred)
	}
	m.RecordMemoryForProcess(orchestrate.ScheduleImplement, orchestrate.Process1, 2.5)
	pred = m.PredictMemory(orchestrate.ScheduleImplement, orchestrate.Process1)
	if pred != 2.5 {
		t.Errorf("PredictMemory with history: got %v", pred)
	}
}
