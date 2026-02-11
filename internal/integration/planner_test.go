package integration

import (
	"context"
	"testing"

	"github.com/croberts/obot/internal/planner"
)

func TestPlannerImprovesOrchestration(t *testing.T) {
	// Test that the PreOrchestrationPlanner produces a valid plan
	// with subtasks, sequence, and risk labels.
	p := planner.NewPreOrchestrationPlanner(nil, "")

	result, err := p.Plan(context.Background(), "Implement a new feature with tests and documentation")
	if err != nil {
		t.Fatalf("Plan() returned error: %v", err)
	}

	// Must produce at least one subtask
	if len(result.Subtasks) == 0 {
		t.Fatal("Expected at least one subtask from planner")
	}

	// Sequence must contain the same subtasks
	if len(result.Sequence) != len(result.Subtasks) {
		t.Errorf("Sequence length %d != Subtasks length %d", len(result.Sequence), len(result.Subtasks))
	}

	// Risks must be assigned for each sequenced subtask
	if len(result.Risks) != len(result.Sequence) {
		t.Errorf("Risks length %d != Sequence length %d", len(result.Risks), len(result.Sequence))
	}

	// Each subtask must have an ID and description
	for i, st := range result.Subtasks {
		if st.ID == "" {
			t.Errorf("Subtask %d has empty ID", i)
		}
		if st.Description == "" {
			t.Errorf("Subtask %d has empty description", i)
		}
	}

	// Risk labels must be valid values
	for i, risk := range result.Risks {
		switch risk {
		case planner.RiskSafe, planner.RiskModerate, planner.RiskHigh:
			// valid
		default:
			t.Errorf("Subtask %d has invalid risk level: %v", i, risk)
		}
	}
}
