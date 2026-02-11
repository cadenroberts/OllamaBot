package orchestrate

import (
	"testing"
	"time"
)

func TestScheduleID_String(t *testing.T) {
	tests := []struct {
		id   ScheduleID
		want string
	}{
		{ScheduleKnowledge, "Knowledge"},
		{SchedulePlan, "Plan"},
		{ScheduleImplement, "Implement"},
		{ScheduleScale, "Scale"},
		{ScheduleProduction, "Production"},
		{ScheduleID(99), "Unknown"},
	}
	for _, tt := range tests {
		t.Run(tt.want, func(t *testing.T) {
			if got := tt.id.String(); got != tt.want {
				t.Errorf("ScheduleID.String() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestProcessID_String(t *testing.T) {
	tests := []struct {
		id   ProcessID
		want string
	}{
		{Process1, "1"},
		{Process2, "2"},
		{Process3, "3"},
		{ProcessID(0), "0"},
	}
	for _, tt := range tests {
		t.Run(tt.want, func(t *testing.T) {
			if got := tt.id.String(); got != tt.want {
				t.Errorf("ProcessID.String() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestIsValidNavigation(t *testing.T) {
	tests := []struct {
		name string
		from ProcessID
		to   ProcessID
		want bool
	}{
		{"Initial to P1", 0, Process1, true},
		{"Initial to P2", 0, Process2, false},
		{"P1 to P1", Process1, Process1, true},
		{"P1 to P2", Process1, Process2, true},
		{"P1 to P3", Process1, Process3, false},
		{"P2 to P1", Process2, Process1, true},
		{"P2 to P2", Process2, Process2, true},
		{"P2 to P3", Process2, Process3, true},
		{"P3 to P2", Process3, Process2, true},
		{"P3 to P3", Process3, Process3, true},
		{"P3 to Terminate", Process3, 0, true},
		{"P1 to Terminate", Process1, 0, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := IsValidNavigation(tt.from, tt.to); got != tt.want {
				t.Errorf("IsValidNavigation(%v, %v) = %v, want %v", tt.from, tt.to, got, tt.want)
			}
		})
	}
}

func TestNavigationRules(t *testing.T) {
	TestIsValidNavigation(t)
}

func TestOrchestratorState_IsTerminal(t *testing.T) {
	if !StatePromptTerminated.IsTerminal() {
		t.Error("StatePromptTerminated should be terminal")
	}
	if StateActive.IsTerminal() {
		t.Error("StateActive should not be terminal")
	}
}

func TestDuration(t *testing.T) {
	start := time.Now().Add(-1 * time.Minute)
	end := time.Now()

	s := Schedule{StartTime: start, EndTime: end}
	if s.Duration() != end.Sub(start) {
		t.Errorf("Schedule.Duration() = %v, want %v", s.Duration(), end.Sub(start))
	}

	p := Process{StartTime: start, EndTime: end}
	if p.Duration() != end.Sub(start) {
		t.Errorf("Process.Duration() = %v, want %v", p.Duration(), end.Sub(start))
	}
}
