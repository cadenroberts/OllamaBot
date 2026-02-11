package scan

import (
	"fmt"
)

// FixSuggestion represents a proposed fix for a health issue.
type FixSuggestion struct {
	Issue      HealthIssue `json:"issue"`
	Suggestion string      `json:"suggestion"`
	Confidence float64     `json:"confidence"` // 0.0 - 1.0
	Action     string      `json:"action"`     // "delete", "replace", "refactor"
}

// FixSuggester generates suggestions for improving codebase health.
type FixSuggester struct{}

// NewFixSuggester creates a new fix suggester.
func NewFixSuggester() *FixSuggester {
	return &FixSuggester{}
}

// Suggest generates suggestions for a list of health issues.
func (s *FixSuggester) Suggest(issues []HealthIssue) []FixSuggestion {
	suggestions := make([]FixSuggestion, 0, len(issues))

	for _, issue := range issues {
		suggestion := s.generateSuggestion(issue)
		if suggestion != nil {
			suggestions = append(suggestions, *suggestion)
		}
	}

	return suggestions
}

// generateSuggestion creates a specific suggestion based on issue type.
func (s *FixSuggester) generateSuggestion(issue HealthIssue) *FixSuggestion {
	switch issue.Type {
	case "todo":
		return &FixSuggestion{
			Issue:      issue,
			Suggestion: "Implement the pending task described in the comment.",
			Confidence: 0.9,
			Action:     "implement",
		}
	case "security":
		return &FixSuggestion{
			Issue:      issue,
			Suggestion: "Move sensitive data to environment variables or a secure configuration file.",
			Confidence: 0.95,
			Action:     "refactor",
		}
	case "complexity":
		if issue.Line > 500 {
			return &FixSuggestion{
				Issue:      issue,
				Suggestion: fmt.Sprintf("Split the large file (%d lines) into smaller, more focused modules.", issue.Line),
				Confidence: 0.8,
				Action:     "refactor",
			}
		}
		return &FixSuggestion{
			Issue:      issue,
			Suggestion: "Reduce nesting depth by extracting logic into helper functions.",
			Confidence: 0.75,
			Action:     "refactor",
		}
	case "unused_import":
		return &FixSuggestion{
			Issue:      issue,
			Suggestion: "Remove the unused import to clean up the dependency graph.",
			Confidence: 1.0,
			Action:     "delete",
		}
	default:
		return nil
	}
}
