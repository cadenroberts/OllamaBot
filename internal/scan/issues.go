package scan

import (
	"sort"
)

// Severity levels
const (
	SeverityCritical = "critical"
	SeverityHigh     = "high"
	SeverityMedium   = "medium"
	SeverityLow      = "low"
)

// PrioritizedIssue adds ranking and cost estimation to a health issue.
type PrioritizedIssue struct {
	HealthIssue
	Rank         int     `json:"rank"`          // 1 is highest priority
	EstimatedCost float64 `json:"estimated_cost"` // Estimated tokens or time units
}

// IssuePrioritizer ranks issues based on severity and impact.
type IssuePrioritizer struct{}

// NewIssuePrioritizer creates a new issue prioritizer.
func NewIssuePrioritizer() *IssuePrioritizer {
	return &IssuePrioritizer{}
}

// Prioritize ranks a list of health issues.
func (p *IssuePrioritizer) Prioritize(issues []HealthIssue) []PrioritizedIssue {
	prioritized := make([]PrioritizedIssue, len(issues))

	for i, issue := range issues {
		prioritized[i] = PrioritizedIssue{
			HealthIssue: issue,
			EstimatedCost: p.estimateCost(issue),
		}
	}

	// Sort by severity and then by cost (lower cost first for same severity)
	sort.Slice(prioritized, func(i, j int) bool {
		si := p.severityValue(prioritized[i].Severity)
		sj := p.severityValue(prioritized[j].Severity)

		if si != sj {
			return si > sj // Higher value first (Critical > High > ...)
		}

		return prioritized[i].EstimatedCost < prioritized[j].EstimatedCost
	})

	// Assign ranks
	for i := range prioritized {
		prioritized[i].Rank = i + 1
	}

	return prioritized
}

// severityValue converts severity string to a numeric value for sorting.
func (p *IssuePrioritizer) severityValue(severity string) int {
	switch severity {
	case SeverityCritical:
		return 4
	case SeverityHigh:
		return 3
	case SeverityMedium:
		return 2
	case SeverityLow:
		return 1
	default:
		return 0
	}
}

// estimateCost provides a rough estimate of tokens/effort to fix the issue.
func (p *IssuePrioritizer) estimateCost(issue HealthIssue) float64 {
	switch issue.Type {
	case "security":
		return 1000.0 // Security fixes often require more context
	case "complexity":
		return 800.0
	case "test_gap":
		return 500.0
	case "todo":
		return 200.0
	default:
		return 300.0
	}
}
