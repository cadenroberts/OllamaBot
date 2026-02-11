package scan

import (
	"testing"
)

func TestPrioritizationRanksCorrectly(t *testing.T) {
	prioritizer := NewIssuePrioritizer()

	issues := []HealthIssue{
		{Type: "todo", Severity: "low", Message: "Low priority"},
		{Type: "security", Severity: "high", Message: "High priority"},
		{Type: "complexity", Severity: "medium", Message: "Medium priority"},
	}

	prioritized := prioritizer.Prioritize(issues)

	if len(prioritized) != 3 {
		t.Fatalf("Expected 3 prioritized issues, got %d", len(prioritized))
	}

	// Rank 1 should be Security (High)
	if prioritized[0].HealthIssue.Type != "security" {
		t.Errorf("Expected Rank 1 to be security, got %s", prioritized[0].HealthIssue.Type)
	}

	// Rank 2 should be Complexity (Medium)
	if prioritized[1].HealthIssue.Type != "complexity" {
		t.Errorf("Expected Rank 2 to be complexity, got %s", prioritized[1].HealthIssue.Type)
	}

	// Rank 3 should be TODO (Low)
	if prioritized[2].HealthIssue.Type != "todo" {
		t.Errorf("Expected Rank 3 to be todo, got %s", prioritized[2].HealthIssue.Type)
	}

	// Verify ranks are assigned
	for i, p := range prioritized {
		if p.Rank != i+1 {
			t.Errorf("Expected Rank %d, got %d", i+1, p.Rank)
		}
	}
}
