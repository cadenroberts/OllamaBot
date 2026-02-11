// Package schedule implements the schedule logic for obot orchestration.
package schedule

import (
	"context"
	"fmt"
	"strings"

	"github.com/croberts/obot/internal/consultation"
	"github.com/croberts/obot/internal/orchestrate"
)

// PlanSchedule implements the logic for the Plan schedule.
// Processes:
// 1. Brainstorm (generate approaches): Explore multiple implementation strategies.
// 2. Clarify (optional human consultation): Resolve ambiguities if they exist.
// 3. Plan (synthesize into concrete steps): Create a detailed step-by-step implementation plan.
type PlanSchedule struct {
	// Internal tracking of ideas and decisions to pass between processes
	Approaches  []string
	Ambiguities []string
	FinalSteps  []string

	ConsultHandler *consultation.Handler
}

// NewPlanSchedule creates a new Plan schedule logic handler.
func NewPlanSchedule(handler *consultation.Handler) *PlanSchedule {
	return &PlanSchedule{
		Approaches:     make([]string, 0),
		Ambiguities:    make([]string, 0),
		FinalSteps:     make([]string, 0),
		ConsultHandler: handler,
	}
}

// ExecuteProcess executes a process within the Plan schedule.
func (s *PlanSchedule) ExecuteProcess(ctx context.Context, processID orchestrate.ProcessID, exec func(context.Context, string) error) error {
	switch processID {
	case orchestrate.Process1:
		return s.Brainstorm(ctx, exec)
	case orchestrate.Process2:
		return s.Clarify(ctx, exec)
	case orchestrate.Process3:
		return s.Plan(ctx, exec)
	default:
		return fmt.Errorf("invalid process ID %d for Plan schedule", processID)
	}
}

// Brainstorm (P1) generates multiple implementation approaches.
func (s *PlanSchedule) Brainstorm(ctx context.Context, exec func(context.Context, string) error) error {
	var sb strings.Builder
	sb.WriteString("### PROCESS: BRAINSTORM (Plan P1)\n")
	sb.WriteString("You are the architect. Your mission is to GENERATE APPROACHES.\n\n")
	sb.WriteString("TASKS:\n")
	sb.WriteString("1. **Analyze Context**: Review findings from the Knowledge schedule.\n")
	sb.WriteString("2. **Divergent Thinking**: Generate at least 2-3 different ways to solve the problem.\n")
	sb.WriteString("3. **Evaluate Trade-offs**: For each approach, list pros, cons, and risks (performance, security, complexity).\n")
	sb.WriteString("4. **Identify Dependencies**: What new libraries or internal components will be needed?\n\n")
	sb.WriteString("GUIDELINES:\n")
	sb.WriteString("- Think outside the box, but respect existing architectural constraints.\n")
	sb.WriteString("- Look for reusable patterns or existing utilities that can be leveraged.\n")
	sb.WriteString("- Document assumptions clearly.\n\n")
	sb.WriteString("OUTPUT:\n")
	sb.WriteString("A list of potential approaches with trade-off analysis.")

	return exec(ctx, sb.String())
}

// Clarify (P2) resolves ambiguities via optional human consultation.
func (s *PlanSchedule) Clarify(ctx context.Context, exec func(context.Context, string) error) error {
	var sb strings.Builder
	sb.WriteString("### PROCESS: CLARIFY (Plan P2)\n")
	sb.WriteString("You are the communicator. Your mission is to RESOLVE AMBIGUITIES.\n\n")

	// If we have a consultation handler, use it
	if s.ConsultHandler != nil && len(s.Ambiguities) > 0 {
		req := consultation.FormatClarifyRequest("Decision point in planning", s.Ambiguities[0], s.Approaches)
		resp, err := s.ConsultHandler.Request(ctx, req)
		if err == nil {
			sb.WriteString(fmt.Sprintf("USER DECISION: %s\n\n", resp.Content))
		}
	}

	sb.WriteString("TASKS:\n")
	sb.WriteString("1. **Scan for Ambiguity**: Look at the approaches from Brainstorm. What is unclear?\n")
	sb.WriteString("2. **Human Consultation**: If multiple valid paths exist, use `core_ask_user` to get preference.\n")
	sb.WriteString("3. **Refine Scope**: Narrow down the chosen approach based on feedback.\n")
	sb.WriteString("4. **Lock Decisions**: Finalize the core strategy for the implementation.\n\n")
	sb.WriteString("GUIDELINES:\n")
	sb.WriteString("- Only ask the human if there's a genuine decision point or ambiguity.\n")
	sb.WriteString("- Provide clear, concise options (A, B, C) when asking the user.\n")
	sb.WriteString("- If no human response, the AI substitute will choose the most standard path.\n\n")
	sb.WriteString("OUTPUT:\n")
	sb.WriteString("A single, refined implementation strategy.")

	return exec(ctx, sb.String())
}

// Plan (P3) synthesizes decisions into concrete implementation steps.
func (s *PlanSchedule) Plan(ctx context.Context, exec func(context.Context, string) error) error {
	var sb strings.Builder
	sb.WriteString("### PROCESS: PLAN (Plan P3)\n")
	sb.WriteString("You are the lead planner. Your mission is to SYNTHESIZE INTO STEPS.\n\n")
	sb.WriteString("TASKS:\n")
	sb.WriteString("1. **Breakdown Tasks**: Divide the chosen strategy into small, atomic implementation steps.\n")
	sb.WriteString("2. **Sequence Work**: Determine the order of execution (types first, then logic, then UI, etc.).\n")
	sb.WriteString("3. **Define Success Criteria**: For each step, how will we know it's done correctly?\n")
	sb.WriteString("4. **Prepare Implement Prompt**: Write a high-level summary for the Implement schedule.\n\n")
	sb.WriteString("GUIDELINES:\n")
	sb.WriteString("- Steps should be small enough to fit in a single agent action if possible.\n")
	sb.WriteString("- Ensure the plan is complete—nothing should be left 'to be determined'.\n")
	sb.WriteString("- Consider testability at each step.\n\n")
	sb.WriteString("OUTPUT:\n")
	sb.WriteString("A detailed, sequenced implementation plan.")

	return exec(ctx, sb.String())
}

// AddApproach adds a potential approach to the schedule.
func (s *PlanSchedule) AddApproach(approach string) {
	s.Approaches = append(s.Approaches, approach)
}

// AddAmbiguity adds an ambiguity to be clarified.
func (s *PlanSchedule) AddAmbiguity(ambiguity string) {
	s.Ambiguities = append(s.Ambiguities, ambiguity)
}

// AddStep adds a finalized step to the plan.
func (s *PlanSchedule) AddStep(step string) {
	s.FinalSteps = append(s.FinalSteps, step)
}

// GetSummary returns a summary of the planning progress.
func (s *PlanSchedule) GetSummary() string {
	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("Approaches Considered: %d\n", len(s.Approaches)))
	sb.WriteString(fmt.Sprintf("Ambiguities Resolved: %d\n", len(s.Ambiguities)))
	sb.WriteString(fmt.Sprintf("Final Plan Steps: %d\n", len(s.FinalSteps)))
	return sb.String()
}
