package scan

import (
	"testing"
)

func TestSuggestionsAreValid(t *testing.T) {
	// 1. Create a dummy report with some issues
	issues := []HealthIssue{
		{
			Type:     "todo",
			Severity: "low",
			Message:  "Pending task found: TODO: implement this",
		},
		{
			Type:     "security",
			Severity: "high",
			Message:  "Potential sensitive data exposed: password",
		},
	}

	// 2. Generate suggestions
	suggester := NewFixSuggester()
	suggestions := suggester.Suggest(issues)

	// 3. Verify suggestions
	if len(suggestions) != 2 {
		t.Fatalf("Expected 2 suggestions, got %d", len(suggestions))
	}

	foundTodo := false
	foundSecurity := false

	for _, s := range suggestions {
		if s.Issue.Type == "todo" {
			foundTodo = true
			if s.Action != "implement" {
				t.Errorf("Expected action 'implement' for todo, got %q", s.Action)
			}
		}
		if s.Issue.Type == "security" {
			foundSecurity = true
			if s.Action != "refactor" {
				t.Errorf("Expected action 'refactor' for security, got %q", s.Action)
			}
		}
	}

	if !foundTodo {
		t.Error("Did not find suggestion for todo")
	}
	if !foundSecurity {
		t.Error("Did not find suggestion for security")
	}
}
