package schedule

import (
	"context"
	"testing"

	"github.com/croberts/obot/internal/orchestrate"
)

func TestNewSchedule(t *testing.T) {
	for id := orchestrate.ScheduleKnowledge; id <= orchestrate.ScheduleProduction; id++ {
		sched := NewSchedule(id)
		if sched == nil {
			t.Fatalf("NewSchedule(%v) = nil", id)
		}
		if sched.ID != id {
			t.Errorf("NewSchedule(%v).ID = %v, want %v", id, sched.ID, id)
		}
		if sched.Name == "" {
			t.Errorf("NewSchedule(%v).Name is empty", id)
		}
		if len(sched.Processes) != 3 {
			t.Errorf("NewSchedule(%v).Processes has %d elements, want 3", id, len(sched.Processes))
		}
	}
}

func TestGetLogicHandler(t *testing.T) {
	tests := []struct {
		id    orchestrate.ScheduleID
		nonNil bool
	}{
		{orchestrate.ScheduleKnowledge, true},
		{orchestrate.SchedulePlan, true},
		{orchestrate.ScheduleImplement, true},
		{orchestrate.ScheduleScale, true},
		{orchestrate.ScheduleProduction, true},
		{orchestrate.ScheduleID(99), false},
	}

	for _, tt := range tests {
		h := GetLogicHandler(tt.id)
		if (h != nil) != tt.nonNil {
			t.Errorf("GetLogicHandler(%v) = %v, want non-nil=%v", tt.id, h != nil, tt.nonNil)
		}
	}
}

func TestLogicHandler_ExecuteProcess(t *testing.T) {
	idl := GetLogicHandler(orchestrate.ScheduleImplement)
	if idl == nil {
		t.Skip("Implement schedule handler not available")
	}
	err := idl.ExecuteProcess(context.Background(), orchestrate.Process1, func(ctx context.Context, s string) error {
		return nil
	})
	if err != nil {
		t.Errorf("ExecuteProcess(nop) = %v, want nil", err)
	}
}
