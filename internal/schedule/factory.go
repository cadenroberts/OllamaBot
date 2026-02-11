// Package schedule implements the schedule factory and individual schedule logic.
package schedule

import (
	"context"

	"github.com/croberts/obot/internal/orchestrate"
)

// LogicHandler defines the interface for schedule-specific logic.
type LogicHandler interface {
	ExecuteProcess(ctx context.Context, processID orchestrate.ProcessID, exec func(context.Context, string) error) error
}

// NewSchedule creates a new schedule instance with its 3 constituent processes.
// It sets the appropriate model type and consultation requirements based on the schedule and process IDs.
//
// PROOF:
// - ZERO-HIT: Previous implementations only covered Implement schedule.
// - POSITIVE-HIT: Schedule factory and all 5 schedules (15 processes) implemented in internal/schedule/.
func NewSchedule(id orchestrate.ScheduleID) *orchestrate.Schedule {
	name, ok := orchestrate.ScheduleNames[id]
	if !ok {
		name = "Unknown"
	}

	model := orchestrate.GetScheduleModel(id)

	schedule := &orchestrate.Schedule{
		ID:    id,
		Name:  name,
		Model: model,
	}

	// Each schedule has exactly 3 processes
	for i := 0; i < 3; i++ {
		processID := orchestrate.ProcessID(i + 1)
		
		var processName string
		if names, ok := orchestrate.ProcessNames[id]; ok {
			processName = names[processID]
		}
		if processName == "" {
			processName = "Process " + processID.String()
		}

		consultation := orchestrate.GetProcessConsultationType(id, processID)

		schedule.Processes[i] = orchestrate.Process{
			ID:                        processID,
			Name:                      processName,
			Schedule:                  id,
			RequiresHumanConsultation: consultation != orchestrate.ConsultationNone,
			ConsultationType:          consultation,
		}
	}

	return schedule
}

// GetLogicHandler returns the logic handler for a given schedule ID.
func GetLogicHandler(id orchestrate.ScheduleID) LogicHandler {
	switch id {
	case orchestrate.ScheduleKnowledge:
		return NewKnowledgeSchedule()
	case orchestrate.SchedulePlan:
		return NewPlanSchedule(nil) // Consultation handler can be injected
	case orchestrate.ScheduleImplement:
		return NewImplementSchedule(nil) // Consultation handler can be injected
	case orchestrate.ScheduleScale:
		return NewScaleSchedule()
	case orchestrate.ScheduleProduction:
		return NewProductionSchedule()
	default:
		return nil
	}
}
