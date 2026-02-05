// Package orchestrate implements the obot orchestration framework.
// This provides professional-grade agentic orchestration through 5 schedules,
// each containing 3 processes, with strict navigation rules.
package orchestrate

import (
	"time"
)

// ScheduleID identifies one of the 5 schedules
type ScheduleID int

const (
	// ScheduleKnowledge is the Knowledge schedule (Research, Crawl, Retrieve)
	ScheduleKnowledge ScheduleID = 1
	// SchedulePlan is the Plan schedule (Brainstorm, Clarify, Plan)
	SchedulePlan ScheduleID = 2
	// ScheduleImplement is the Implement schedule (Implement, Verify, Feedback)
	ScheduleImplement ScheduleID = 3
	// ScheduleScale is the Scale schedule (Scale, Benchmark, Optimize)
	ScheduleScale ScheduleID = 4
	// ScheduleProduction is the Production schedule (Analyze, Systemize, Harmonize)
	ScheduleProduction ScheduleID = 5
)

// ScheduleNames maps schedule IDs to display names
var ScheduleNames = map[ScheduleID]string{
	ScheduleKnowledge:  "Knowledge",
	SchedulePlan:       "Plan",
	ScheduleImplement:  "Implement",
	ScheduleScale:      "Scale",
	ScheduleProduction: "Production",
}

// ProcessID identifies a process within a schedule (1, 2, or 3)
type ProcessID int

const (
	// Process1 is the first process in a schedule
	Process1 ProcessID = 1
	// Process2 is the second process in a schedule
	Process2 ProcessID = 2
	// Process3 is the third process in a schedule
	Process3 ProcessID = 3
)

// ProcessNames maps schedule+process to display names
var ProcessNames = map[ScheduleID]map[ProcessID]string{
	ScheduleKnowledge: {
		Process1: "Research",
		Process2: "Crawl",
		Process3: "Retrieve",
	},
	SchedulePlan: {
		Process1: "Brainstorm",
		Process2: "Clarify",
		Process3: "Plan",
	},
	ScheduleImplement: {
		Process1: "Implement",
		Process2: "Verify",
		Process3: "Feedback",
	},
	ScheduleScale: {
		Process1: "Scale",
		Process2: "Benchmark",
		Process3: "Optimize",
	},
	ScheduleProduction: {
		Process1: "Analyze",
		Process2: "Systemize",
		Process3: "Harmonize",
	},
}

// OrchestratorState represents the current orchestrator state
type OrchestratorState string

const (
	// StateBegin is the initial state
	StateBegin OrchestratorState = "Begin"
	// StateSelecting indicates the orchestrator is selecting a schedule/process
	StateSelecting OrchestratorState = "Selecting"
	// StateActive indicates the orchestrator is active and agent is executing
	StateActive OrchestratorState = "Active"
	// StateSuspended indicates an error has occurred and requires attention
	StateSuspended OrchestratorState = "Suspended"
	// StatePromptTerminated indicates the prompt has completed
	StatePromptTerminated OrchestratorState = "Prompt Terminated"
)

// ModelType identifies model roles
type ModelType string

const (
	// ModelOrchestrator is the orchestrator/planner model
	ModelOrchestrator ModelType = "orchestrator"
	// ModelCoder is the coding model
	ModelCoder ModelType = "coder"
	// ModelResearcher is the RAG/research model
	ModelResearcher ModelType = "researcher"
	// ModelVision is the vision model
	ModelVision ModelType = "vision"
)

// ConsultationType for human consultation
type ConsultationType string

const (
	// ConsultationNone indicates no human consultation
	ConsultationNone ConsultationType = "none"
	// ConsultationOptional indicates optional consultation (Clarify)
	ConsultationOptional ConsultationType = "optional"
	// ConsultationMandatory indicates mandatory consultation (Feedback)
	ConsultationMandatory ConsultationType = "mandatory"
)

// Schedule represents a schedule instance
type Schedule struct {
	ID         ScheduleID
	Name       string
	Processes  [3]Process
	Model      ModelType
	StartTime  time.Time
	EndTime    time.Time
	Terminated bool
}

// Process represents a process instance
type Process struct {
	ID                        ProcessID
	Name                      string
	Schedule                  ScheduleID
	RequiresHumanConsultation bool
	ConsultationType          ConsultationType
	StartTime                 time.Time
	EndTime                   time.Time
	Completed                 bool
	Terminated                bool
}

// NavigationRule defines valid process transitions
type NavigationRule struct {
	From     ProcessID
	AllowedTo []ProcessID
	CanTerminate bool
}

// NavigationRules defines all valid transitions
var NavigationRules = map[ProcessID]NavigationRule{
	0: { // Initial state
		From:         0,
		AllowedTo:    []ProcessID{Process1},
		CanTerminate: false,
	},
	Process1: {
		From:         Process1,
		AllowedTo:    []ProcessID{Process1, Process2},
		CanTerminate: false,
	},
	Process2: {
		From:         Process2,
		AllowedTo:    []ProcessID{Process1, Process2, Process3},
		CanTerminate: false,
	},
	Process3: {
		From:         Process3,
		AllowedTo:    []ProcessID{Process2, Process3},
		CanTerminate: true,
	},
}

// IsValidNavigation checks if a navigation from one process to another is valid
func IsValidNavigation(from, to ProcessID) bool {
	rule, ok := NavigationRules[from]
	if !ok {
		return false
	}
	
	// Check termination (to == 0)
	if to == 0 {
		return rule.CanTerminate
	}
	
	// Check allowed destinations
	for _, allowed := range rule.AllowedTo {
		if allowed == to {
			return true
		}
	}
	
	return false
}

// GetScheduleModel returns the model type for a given schedule
func GetScheduleModel(scheduleID ScheduleID) ModelType {
	switch scheduleID {
	case ScheduleKnowledge:
		return ModelResearcher
	case ScheduleProduction:
		return ModelCoder // Vision model added as secondary during Harmonize
	default:
		return ModelCoder
	}
}

// GetProcessConsultationType returns the consultation type for a process
func GetProcessConsultationType(scheduleID ScheduleID, processID ProcessID) ConsultationType {
	// Clarify (Plan schedule, Process 2) - Optional
	if scheduleID == SchedulePlan && processID == Process2 {
		return ConsultationOptional
	}
	// Feedback (Implement schedule, Process 3) - Mandatory
	if scheduleID == ScheduleImplement && processID == Process3 {
		return ConsultationMandatory
	}
	return ConsultationNone
}
