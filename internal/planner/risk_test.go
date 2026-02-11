package planner

import (
	"testing"
)

func TestRiskLabelingAccurate(t *testing.T) {
	rl := NewRiskLabeler()

	tests := []struct {
		name         string
		task         Task
		expectedRisk RiskLevel
	}{
		{
			name: "High risk - security keyword",
			task: Task{
				Message: "Update security protocols",
				File:    "internal/util/helpers.go",
			},
			expectedRisk: RiskHigh,
		},
		{
			name: "High risk - critical path",
			task: Task{
				Message: "Change some logic",
				File:    "internal/ollama/client.go",
			},
			expectedRisk: RiskHigh,
		},
		{
			name: "Moderate risk - API keyword",
			task: Task{
				Message: "Add new public api endpoint",
				File:    "internal/util/helpers.go",
			},
			expectedRisk: RiskModerate,
		},
		{
			name: "Moderate risk - impactful path",
			task: Task{
				Message: "Improve session management",
				File:    "internal/session/manager.go",
			},
			expectedRisk: RiskModerate,
		},
		{
			name: "Safe - documentation",
			task: Task{
				Message: "Update README.md",
				File:    "README.md",
			},
			expectedRisk: RiskSafe,
		},
		{
			name: "Safe - tests",
			task: Task{
				Message: "Add unit tests for utils",
				File:    "internal/util/util_test.go",
			},
			expectedRisk: RiskSafe,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			risk, _ := rl.Label(tt.task)
			if risk != tt.expectedRisk {
				t.Errorf("Label() risk = %v, want %v", risk, tt.expectedRisk)
			}
		})
	}
}
