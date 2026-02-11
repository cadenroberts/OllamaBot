// Package session implements session persistence and state management.
package session

import (
	"errors"
)

// StateRelation defines the recurrence relationship between two session states.
// It contains pointers to the previous and next states, along with scripts
// to restore the file system state by moving in either direction.
type StateRelation struct {
	CurrentID       string `json:"current_id"`
	PrevID          string `json:"prev_id"`
	NextID          string `json:"next_id"`
	FilesHash       string `json:"files_hash"`
	Actions         []string `json:"actions"`
	RestoreFromPrev string `json:"restore_from_prev"` // Script to apply diff from prev to current
	RestoreFromNext string `json:"restore_from_next"` // Script to revert diff from next back to current
}

// Direction indicates whether a path step moves forward or backward in time.
type Direction string

const (
	DirectionForward Direction = "forward"
	DirectionReverse Direction = "reverse"
)

// PathStep represents a single transition in a state restoration path.
type PathStep struct {
	From      string    `json:"from"`
	To        string    `json:"to"`
	Direction Direction `json:"direction"`
	DiffFile  string    `json:"diff_file"`
}

// FindPath finds the shortest path of diffs to move from currentID to targetID.
// It uses a bidirectional BFS on the graph of state relations.
func FindPath(currentID, targetID string, relations []StateRelation) ([]PathStep, error) {
	if currentID == targetID {
		return []PathStep{}, nil
	}

	// Build adjacency list
	adj := make(map[string][]StateRelation)
	for _, rel := range relations {
		adj[rel.CurrentID] = append(adj[rel.CurrentID], rel)
	}

	// Standard BFS for simplicity (bidirectional can be added if needed for performance)
	type queueItem struct {
		id   string
		path []PathStep
	}

	queue := []queueItem{{id: currentID, path: []PathStep{}}}
	visited := map[string]bool{currentID: true}

	for len(queue) > 0 {
		item := queue[0]
		queue = queue[1:]

		if item.id == targetID {
			return item.path, nil
		}

		// Check forward transitions
		for _, rel := range relations {
			if rel.CurrentID == item.id && rel.NextID != "" && !visited[rel.NextID] {
				visited[rel.NextID] = true
				newPath := append([]PathStep(nil), item.path...)
				newPath = append(newPath, PathStep{
					From:      rel.CurrentID,
					To:        rel.NextID,
					Direction: DirectionForward,
					// Diff file would be stored in the relation or next state's metadata
				})
				queue = append(queue, queueItem{id: rel.NextID, path: newPath})
			}
			
			// Check backward transitions
			if rel.CurrentID == item.id && rel.PrevID != "" && !visited[rel.PrevID] {
				visited[rel.PrevID] = true
				newPath := append([]PathStep(nil), item.path...)
				newPath = append(newPath, PathStep{
					From:      rel.CurrentID,
					To:        rel.PrevID,
					Direction: DirectionReverse,
				})
				queue = append(queue, queueItem{id: rel.PrevID, path: newPath})
			}
		}
	}

	return nil, errors.New("no path found between states")
}
