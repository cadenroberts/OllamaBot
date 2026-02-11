package planner

import (
	"fmt"
)

// ChangeSequencer determines the optimal order for executing subtasks based on their dependencies.
type ChangeSequencer struct{}

// NewChangeSequencer creates a new sequencer.
func NewChangeSequencer() *ChangeSequencer {
	return &ChangeSequencer{}
}

// Sequence reorders the subtasks into an optimal execution sequence.
// It uses a topological sort to ensure that dependencies are met before a task is executed.
func (s *ChangeSequencer) Sequence(subtasks []Subtask) ([]Subtask, error) {
	if len(subtasks) == 0 {
		return subtasks, nil
	}

	// Create a map for quick lookup and a graph for dependencies
	taskMap := make(map[string]Subtask)
	adj := make(map[string][]string)
	inDegree := make(map[string]int)

	for _, st := range subtasks {
		taskMap[st.ID] = st
		if _, exists := inDegree[st.ID]; !exists {
			inDegree[st.ID] = 0
		}

		for _, dep := range st.DependsOn {
			// st depends on dep, so dep -> st in the graph
			adj[dep] = append(adj[dep], st.ID)
			inDegree[st.ID]++
		}
	}

	// Queue for tasks with no dependencies (in-degree 0)
	queue := make([]string, 0)
	for id, degree := range inDegree {
		if degree == 0 {
			queue = append(queue, id)
		}
	}

	// Resulting sequence
	result := make([]Subtask, 0, len(subtasks))
	visitedCount := 0

	for len(queue) > 0 {
		// Pop from queue
		u := queue[0]
		queue = queue[1:]

		if task, ok := taskMap[u]; ok {
			result = append(result, task)
			visitedCount++
		}

		// Decrease in-degree of all neighbors
		for _, v := range adj[u] {
			inDegree[v]--
			if inDegree[v] == 0 {
				queue = append(queue, v)
			}
		}
	}

	// Check for cycles
	if visitedCount != len(subtasks) {
		// Identify remaining tasks for error message
		remaining := []string{}
		for id, degree := range inDegree {
			if degree > 0 {
				remaining = append(remaining, id)
			}
		}
		return nil, fmt.Errorf("circular dependency detected in subtasks: %v", remaining)
	}

	return result, nil
}

// GroupByFile groups subtasks by the file they modify, preserving the sequential order.
func (s *ChangeSequencer) GroupByFile(subtasks []Subtask) map[string][]Subtask {
	groups := make(map[string][]Subtask)
	// Note: Subtask doesn't currently have a File field in decompose.go, 
	// but the plan items suggest multi-file changes.
	// We'll keep this as a stub for future integration if Subtask is extended.
	return groups
}
