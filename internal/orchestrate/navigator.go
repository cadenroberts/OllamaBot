// Package orchestrate implements the obot orchestration framework.
package orchestrate

import (
	"fmt"
)

// Navigator enforces strict 1↔2↔3 process navigation rules.
type Navigator struct {
	currentSchedule ScheduleID
	currentProcess  ProcessID
	history         []ProcessID
}

// NewNavigator creates a new navigator
func NewNavigator() *Navigator {
	return &Navigator{
		history: make([]ProcessID, 0),
	}
}

// SetSchedule sets the current schedule
func (n *Navigator) SetSchedule(scheduleID ScheduleID) {
	n.currentSchedule = scheduleID
	n.currentProcess = 0 // Reset to initial state
	n.history = make([]ProcessID, 0)
}

// CurrentProcess returns the current process
func (n *Navigator) CurrentProcess() ProcessID {
	return n.currentProcess
}

// CanNavigateTo checks if navigation to the given process is valid
func (n *Navigator) CanNavigateTo(processID ProcessID) bool {
	return IsValidNavigation(n.currentProcess, processID)
}

// NavigateTo attempts to navigate to the given process
func (n *Navigator) NavigateTo(processID ProcessID) error {
	if !n.CanNavigateTo(processID) {
		return &NavigationValidationError{
			From:     n.currentProcess,
			To:       processID,
			Schedule: n.currentSchedule,
			Rule:     n.getRuleDescription(n.currentProcess),
		}
	}

	n.history = append(n.history, processID)
	n.currentProcess = processID
	return nil
}

// CanTerminateSchedule checks if the schedule can be terminated
func (n *Navigator) CanTerminateSchedule() bool {
	return n.currentProcess == Process3
}

// GetAllowedTransitions returns the list of valid next processes
func (n *Navigator) GetAllowedTransitions() []ProcessID {
	rule, ok := NavigationRules[n.currentProcess]
	if !ok {
		return nil
	}
	return rule.AllowedTo
}

// GetHistory returns the navigation history for this schedule
func (n *Navigator) GetHistory() []ProcessID {
	result := make([]ProcessID, len(n.history))
	copy(result, n.history)
	return result
}

// Reset resets the navigator to initial state
func (n *Navigator) Reset() {
	n.currentSchedule = 0
	n.currentProcess = 0
	n.history = make([]ProcessID, 0)
}

// getRuleDescription returns a human-readable description of the navigation rule
func (n *Navigator) getRuleDescription(from ProcessID) string {
	switch from {
	case 0:
		return "From initial state: Can only go to P1"
	case Process1:
		return "From P1: Can go to P1 (repeat) or P2"
	case Process2:
		return "From P2: Can go to P1, P2 (repeat), or P3"
	case Process3:
		return "From P3: Can go to P2, P3 (repeat), or terminate schedule"
	default:
		return "Unknown state"
	}
}

// ValidateNavigationSequence validates an entire sequence of process transitions
func ValidateNavigationSequence(sequence []ProcessID) error {
	if len(sequence) == 0 {
		return nil
	}

	// First process must be P1
	if sequence[0] != Process1 {
		return fmt.Errorf("invalid sequence: must start with P1, got P%d", sequence[0])
	}

	// Validate each transition
	from := ProcessID(0)
	for i, to := range sequence {
		if !IsValidNavigation(from, to) {
			return fmt.Errorf("invalid transition at position %d: P%d to P%d", i, from, to)
		}
		from = to
	}

	return nil
}

// BuildValidSequences returns all valid process sequences up to maxLength
// This is useful for testing and demonstrating the navigation rules
func BuildValidSequences(maxLength int) [][]ProcessID {
	if maxLength <= 0 {
		return nil
	}

	sequences := make([][]ProcessID, 0)

	var build func(current []ProcessID, lastProcess ProcessID)
	build = func(current []ProcessID, lastProcess ProcessID) {
		if len(current) >= maxLength {
			// Store a copy
			seq := make([]ProcessID, len(current))
			copy(seq, current)
			sequences = append(sequences, seq)
			return
		}

		rule, ok := NavigationRules[lastProcess]
		if !ok {
			return
		}

		for _, next := range rule.AllowedTo {
			newSeq := append(current, next)
			build(newSeq, next)
		}

		// Also try termination if allowed
		if rule.CanTerminate && len(current) > 0 {
			seq := make([]ProcessID, len(current))
			copy(seq, current)
			sequences = append(sequences, seq)
		}
	}

	build([]ProcessID{}, 0)
	return sequences
}

// MinimumProcessesToTerminate returns the minimum number of processes required
// to reach a state where the schedule can be terminated (must reach P3)
func MinimumProcessesToTerminate() int {
	// From initial: P1 -> P2 -> P3 = 3 processes minimum
	return 3
}

// IsCompleteSequence checks if a sequence of processes reaches termination correctly.
func IsCompleteSequence(sequence []ProcessID) bool {
	if len(sequence) == 0 {
		return false
	}
	
	// Must end with a process that can terminate (P3)
	last := sequence[len(sequence)-1]
	rule, ok := NavigationRules[last]
	if !ok || !rule.CanTerminate {
		return false
	}
	
	// Sequence itself must be valid
	return ValidateNavigationSequence(sequence) == nil
}

// GetPathToTermination returns the shortest path of process IDs to reach termination from current.
func (n *Navigator) GetPathToTermination() []ProcessID {
	switch n.currentProcess {
	case 0:
		return []ProcessID{Process1, Process2, Process3}
	case Process1:
		return []ProcessID{Process2, Process3}
	case Process2:
		return []ProcessID{Process3}
	case Process3:
		return []ProcessID{}
	default:
		return nil
	}
}

// ExplainNavigationError returns a detailed explanation of why a transition is invalid.
func (n *Navigator) ExplainNavigationError(to ProcessID) string {
	if n.CanNavigateTo(to) {
		return "Transition is valid."
	}
	
	rule, ok := NavigationRules[n.currentProcess]
	if !ok {
		return "Unknown current state."
	}
	
	allowed := ""
	for i, a := range rule.AllowedTo {
		if i > 0 {
			allowed += ", "
		}
		allowed += fmt.Sprintf("P%d", a)
	}
	
	return fmt.Sprintf("Cannot go from P%d to P%d. Allowed next processes: %s.", 
		n.currentProcess, to, allowed)
}

// ValidateCrossScheduleTransition validates navigation between schedules.
// Rule: any P3 -> any P1.
func ValidateCrossScheduleTransition(fromSchedule, toSchedule ScheduleID, fromProcess, toProcess ProcessID) error {
	if fromProcess != Process3 {
		return fmt.Errorf("cannot leave schedule %s: must complete P3 first (current: P%d)", 
			ScheduleNames[fromSchedule], fromProcess)
	}
	
	if toProcess != Process1 {
		return fmt.Errorf("cannot enter schedule %s: must start at P1 (requested: P%d)", 
			ScheduleNames[toSchedule], toProcess)
	}
	
	return nil
}

// FormatNavigationDiagram returns an ASCII diagram showing allowed transitions
func FormatNavigationDiagram() string {
	return `
   1↔2↔3 Navigation Matrix:
   
   ┌─────────┬─────────┬─────────┬─────────┬─────────┐
   │  FROM   │   P1    │   P2    │   P3    │  TERM   │
   ├─────────┼─────────┼─────────┼─────────┼─────────┤
   │  START  │    ✓    │    X    │    X    │    X    │
   ├─────────┼─────────┼─────────┼─────────┼─────────┤
   │   P1    │    ↻    │    ✓    │    X    │    X    │
   ├─────────┼─────────┼─────────┼─────────┼─────────┤
   │   P2    │    ✓    │    ↻    │    ✓    │    X    │
   ├─────────┼─────────┼─────────┼─────────┼─────────┤
   │   P3    │    X    │    ✓    │    ↻    │    ✓    │
   └─────────┴─────────┴─────────┴─────────┴─────────┘
   
   Rules:
   1. Must start with P1.
   2. P1 can repeat or move to P2.
   3. P2 can return to P1, repeat, or move to P3.
   4. P3 can return to P2, repeat, or terminate.
   5. Termination only allowed from P3.
   6. P1↔P3 jumps are strictly forbidden (E001/E003).
`
}
