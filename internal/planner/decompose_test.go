package planner

import (
	"context"
	"testing"
)

func TestTaskDecomposition(t *testing.T) {
	// We'll test the stub implementation when client is nil
	d := NewTaskDecomposer(nil, "")
	
	ctx := context.Background()
	prompt := "Build a simple web server with a health check endpoint."
	
	subtasks, err := d.Decompose(ctx, prompt)
	if err != nil {
		t.Fatalf("Decompose failed: %v", err)
	}
	
	if len(subtasks) == 0 {
		t.Errorf("Expected at least one subtask, got 0")
	}
	
	found := false
	for _, st := range subtasks {
		if st.ID == "T1" {
			found = true
			expectedDesc := "Initial analysis of: " + prompt
			if st.Description != expectedDesc {
				t.Errorf("Expected description '%s', got '%s'", expectedDesc, st.Description)
			}
		}
	}
	
	if !found {
		t.Errorf("Expected to find subtask with ID 'T1'")
	}
}

func TestParseDecomposition(t *testing.T) {
	d := &TaskDecomposer{}
	
	resp := `ID: T1
DESCRIPTION: Create the main server structure
PRIORITY: 1
DEPENDS_ON: None

ID: T2
DESCRIPTION: Add health check handler
PRIORITY: 2
DEPENDS_ON: T1

ID: T3
DESCRIPTION: Write unit tests
PRIORITY: 3
DEPENDS_ON: T1, T2`

	subtasks := d.parseDecomposition(resp)
	
	if len(subtasks) != 3 {
		t.Fatalf("Expected 3 subtasks, got %d", len(subtasks))
	}
	
	t1 := subtasks[0]
	if t1.ID != "T1" || t1.Description != "Create the main server structure" || t1.Priority != 1 || len(t1.DependsOn) != 0 {
		t.Errorf("T1 mismatch: %+v", t1)
	}
	
	t2 := subtasks[1]
	if t2.ID != "T2" || t2.Description != "Add health check handler" || t2.Priority != 2 || len(t2.DependsOn) != 1 || t2.DependsOn[0] != "T1" {
		t.Errorf("T2 mismatch: %+v", t2)
	}
	
	t3 := subtasks[2]
	if t3.ID != "T3" || t3.Description != "Write unit tests" || t3.Priority != 3 || len(t3.DependsOn) != 2 || t3.DependsOn[0] != "T1" || t3.DependsOn[1] != "T2" {
		t.Errorf("T3 mismatch: %+v", t3)
	}
}
