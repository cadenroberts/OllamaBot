package planner

import (
	"testing"
)

func TestSequencingHandlesDependencies(t *testing.T) {
	s := NewChangeSequencer()

	tests := []struct {
		name     string
		subtasks []Subtask
		wantErr  bool
	}{
		{
			name: "Simple linear dependency",
			subtasks: []Subtask{
				{ID: "T1", Description: "Task 1", DependsOn: []string{}},
				{ID: "T2", Description: "Task 2", DependsOn: []string{"T1"}},
				{ID: "T3", Description: "Task 3", DependsOn: []string{"T2"}},
			},
			wantErr: false,
		},
		{
			name: "Complex dependencies",
			subtasks: []Subtask{
				{ID: "T1", Description: "Task 1", DependsOn: []string{}},
				{ID: "T2", Description: "Task 2", DependsOn: []string{"T1"}},
				{ID: "T3", Description: "Task 3", DependsOn: []string{"T1"}},
				{ID: "T4", Description: "Task 4", DependsOn: []string{"T2", "T3"}},
			},
			wantErr: false,
		},
		{
			name: "Circular dependency",
			subtasks: []Subtask{
				{ID: "T1", Description: "Task 1", DependsOn: []string{"T2"}},
				{ID: "T2", Description: "Task 2", DependsOn: []string{"T1"}},
			},
			wantErr: true,
		},
		{
			name: "No dependencies",
			subtasks: []Subtask{
				{ID: "T1", Description: "Task 1"},
				{ID: "T2", Description: "Task 2"},
			},
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := s.Sequence(tt.subtasks)
			if (err != nil) != tt.wantErr {
				t.Errorf("Sequence() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !tt.wantErr {
				if len(got) != len(tt.subtasks) {
					t.Errorf("Sequence() got %d tasks, want %d", len(got), len(tt.subtasks))
				}
				
				// Verify dependency order
				visited := make(map[string]bool)
				for _, st := range got {
					for _, dep := range st.DependsOn {
						if !visited[dep] {
							t.Errorf("Task %s executed before dependency %s", st.ID, dep)
						}
					}
					visited[st.ID] = true
				}
			}
		})
	}
}
