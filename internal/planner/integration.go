// Package planner implements pre-orchestration planning logic.
package planner

import (
	"context"
	"fmt"

	"github.com/croberts/obot/internal/ollama"
)

// PreOrchestrationPlanner integrates decomposition, sequencing, and risk analysis.
type PreOrchestrationPlanner struct {
	decomposer *TaskDecomposer
	sequencer  *ChangeSequencer
	labeler    *RiskLabeler
}

// NewPreOrchestrationPlanner creates a new integrated planner.
func NewPreOrchestrationPlanner(client *ollama.Client, model string) *PreOrchestrationPlanner {
	return &PreOrchestrationPlanner{
		decomposer: NewTaskDecomposer(client, model),
		sequencer:  NewChangeSequencer(),
		labeler:    NewRiskLabeler(),
	}
}

// SubtaskResult contains the full output of the pre-orchestration planning phase.
type SubtaskResult struct {
	Subtasks []Subtask   `json:"subtasks"`
	Sequence []Subtask   `json:"sequence"`
	Risks    []RiskLevel `json:"risks"`
}

// Plan prepares the orchestration by decomposing the prompt and sequencing tasks.
func (p *PreOrchestrationPlanner) Plan(ctx context.Context, prompt string) (*SubtaskResult, error) {
	// 1. Decompose the prompt into subtasks
	subtasks, err := p.decomposer.Decompose(ctx, prompt)
	if err != nil {
		return nil, fmt.Errorf("decomposition failed: %w", err)
	}

	// 2. Sequence the subtasks based on dependencies
	sequence, err := p.sequencer.Sequence(subtasks)
	if err != nil {
		// If sequencing fails (e.g., due to cycles), we fallback to the original decomposition
		// but log it or handle it as an error depending on desired strictness.
		// For now, we return the error to ensure safe execution.
		return nil, fmt.Errorf("sequencing failed: %w", err)
	}

	// 3. Label risks for each subtask in the sequence
	risks := make([]RiskLevel, len(sequence))
	for i, st := range sequence {
		// Create a temporary Task object for the labeler to use its analysis logic.
		// At this stage, we may not know the exact file yet, so the labeler will 
		// primarily rely on the subtask description/message.
		task := Task{
			ID:      st.ID,
			Message: st.Description,
		}
		risk, _ := p.labeler.Label(task)
		risks[i] = risk
	}

	return &SubtaskResult{
		Subtasks: subtasks,
		Sequence: sequence,
		Risks:    risks,
	}, nil
}
