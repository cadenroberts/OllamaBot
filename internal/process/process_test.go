package process

import (
	"testing"
	"time"

	"github.com/croberts/obot/internal/orchestrate"
)

func TestNewBaseProcess(t *testing.T) {
	p := NewBaseProcess(orchestrate.ScheduleImplement, orchestrate.Process1, "Implement")
	if p == nil {
		t.Fatal("NewBaseProcess returned nil")
	}
	if p.ProcessID != orchestrate.Process1 {
		t.Errorf("ProcessID: got %v", p.ProcessID)
	}
	if p.ScheduleID != orchestrate.ScheduleImplement {
		t.Errorf("ScheduleID: got %v", p.ScheduleID)
	}
}

func TestBaseProcess_ID(t *testing.T) {
	p := NewBaseProcess(orchestrate.ScheduleKnowledge, orchestrate.Process2, "Crawl")
	if p.ID() != orchestrate.Process2 {
		t.Errorf("ID(): got %v", p.ID())
	}
}

func TestBaseProcess_Name(t *testing.T) {
	p := NewBaseProcess(orchestrate.ScheduleImplement, orchestrate.Process1, "Custom")
	if p.Name() != "Custom" {
		t.Errorf("Name(): got %q", p.Name())
	}
	p2 := NewBaseProcess(orchestrate.ScheduleImplement, orchestrate.Process1, "")
	if p2.Name() != "Implement" {
		t.Errorf("Name() with empty ProcessName: got %q", p2.Name())
	}
}

func TestBaseProcess_Schedule(t *testing.T) {
	p := NewBaseProcess(orchestrate.ScheduleScale, orchestrate.Process3, "Optimize")
	if p.Schedule() != orchestrate.ScheduleScale {
		t.Errorf("Schedule(): got %v", p.Schedule())
	}
}

func TestBaseProcess_RecordStartEnd(t *testing.T) {
	p := NewBaseProcess(orchestrate.ScheduleImplement, orchestrate.Process1, "Test")
	p.RecordStart()
	time.Sleep(2 * time.Millisecond)
	p.RecordEnd()
	d := p.Duration()
	if d <= 0 {
		t.Errorf("Duration should be positive, got %v", d)
	}
}

func TestBaseProcess_RecordTokens(t *testing.T) {
	p := NewBaseProcess(orchestrate.ScheduleImplement, orchestrate.Process1, "Test")
	p.RecordTokens(100)
	p.RecordTokens(50)
	if p.Tokens != 150 {
		t.Errorf("Tokens: got %d", p.Tokens)
	}
}

func TestBaseProcess_RecordAction(t *testing.T) {
	p := NewBaseProcess(orchestrate.ScheduleImplement, orchestrate.Process1, "Test")
	p.RecordAction()
	p.RecordAction()
	if p.Actions != 2 {
		t.Errorf("Actions: got %d", p.Actions)
	}
}

func TestBaseProcess_ValidateEntry(t *testing.T) {
	p := NewBaseProcess(orchestrate.ScheduleImplement, orchestrate.Process2, "Verify")
	err := p.ValidateEntry(orchestrate.Process1)
	if err != nil {
		t.Errorf("P1->P2 should be valid: %v", err)
	}
	// P1->P3 is invalid (must go through P2)
	p3 := NewBaseProcess(orchestrate.ScheduleImplement, orchestrate.Process3, "Feedback")
	err = p3.ValidateEntry(orchestrate.Process1)
	if err == nil {
		t.Error("P1->P3 should be invalid")
	}
}

func TestBaseProcess_RequiresHumanConsultation(t *testing.T) {
	p := NewBaseProcess(orchestrate.ScheduleImplement, orchestrate.Process1, "Test")
	_ = p.RequiresHumanConsultation()
	_ = p.GetConsultationType()
}

func TestInvalidNavigationError(t *testing.T) {
	e := &InvalidNavigationError{From: orchestrate.Process1, To: orchestrate.Process3, Schedule: orchestrate.ScheduleImplement, Message: "bad"}
	s := e.Error()
	if s != "bad" {
		t.Errorf("Error(): got %q", s)
	}
}
