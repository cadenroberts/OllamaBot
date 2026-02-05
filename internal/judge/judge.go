// Package judge implements LLM-as-judge analysis for obot orchestration.
package judge

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"
)

// Judge coordinates expert analysis and synthesis for prompt evaluation.
type Judge struct {
	mu sync.Mutex

	// Expert reports
	reports map[ExpertType]*ExpertReport

	// Retries configuration
	maxRetries int

	// Model coordinator (would be injected)
	// modelCoord *model.Coordinator
}

// ExpertType identifies an expert model
type ExpertType string

const (
	ExpertCoder      ExpertType = "coder"
	ExpertResearcher ExpertType = "researcher"
	ExpertVision     ExpertType = "vision"
)

// ExpertReport contains an expert's analysis
type ExpertReport struct {
	Expert          ExpertType
	PromptAdherence float64 // 0-100
	ProjectQuality  float64 // 0-100
	ActionsTaken    int
	ErrorsMade      int
	Observations    []string
	Recommendations []string
	Timestamp       time.Time
	Failed          bool
	FailureReason   string
}

// TLDR contains the final synthesized analysis
type TLDR struct {
	PromptGoal           string
	ImplementationSummary string
	ExpertConsensus      ExpertConsensus
	Discoveries          []string
	Learnings            []string
	Issues               []Issue
	QualityAssessment    QualityLevel
	Justification        string
	Recommendations      []string
}

// ExpertConsensus contains aggregated expert scores
type ExpertConsensus struct {
	PromptAdherenceAvg float64
	ProjectQualityAvg  float64
	PromptAdherence    map[ExpertType]float64
	ProjectQuality     map[ExpertType]float64
}

// Issue represents an issue encountered during execution
type Issue struct {
	Description string
	Resolution  string
}

// QualityLevel represents the overall quality assessment
type QualityLevel string

const (
	QualityAcceptable       QualityLevel = "ACCEPTABLE"
	QualityNeedsImprovement QualityLevel = "NEEDS_IMPROVEMENT"
	QualityExceptional      QualityLevel = "EXCEPTIONAL"
)

// NewJudge creates a new judge
func NewJudge() *Judge {
	return &Judge{
		reports:    make(map[ExpertType]*ExpertReport),
		maxRetries: 1,
	}
}

// RequestExpertAnalysis requests analysis from a specific expert
func (j *Judge) RequestExpertAnalysis(ctx context.Context, expert ExpertType, input *ExpertInput) (*ExpertReport, error) {
	j.mu.Lock()
	defer j.mu.Unlock()

	// In a real implementation, this would call the appropriate model
	// with a structured prompt for analysis

	report := &ExpertReport{
		Expert:    expert,
		Timestamp: time.Now(),
	}

	// Generate expert-specific analysis
	switch expert {
	case ExpertCoder:
		report = j.generateCoderAnalysis(input)
	case ExpertResearcher:
		report = j.generateResearcherAnalysis(input)
	case ExpertVision:
		report = j.generateVisionAnalysis(input)
	}

	j.reports[expert] = report
	return report, nil
}

// ExpertInput contains input for expert analysis
type ExpertInput struct {
	OriginalPrompt string
	FlowCode       string
	Actions        []string
	Errors         []string
	FileChanges    map[string]int // filename -> lines changed
	TestResults    *TestResults
	LintResults    *LintResults
}

// TestResults contains test execution results
type TestResults struct {
	Passed int
	Failed int
	Total  int
}

// LintResults contains lint check results
type LintResults struct {
	Errors   int
	Warnings int
}

// generateCoderAnalysis generates the coder expert analysis
func (j *Judge) generateCoderAnalysis(input *ExpertInput) *ExpertReport {
	report := &ExpertReport{
		Expert:    ExpertCoder,
		Timestamp: time.Now(),
	}

	// Calculate prompt adherence based on actions
	if len(input.Actions) > 0 {
		report.PromptAdherence = 85.0 // Would be calculated based on actual analysis
	}

	// Calculate project quality based on tests and lint
	if input.TestResults != nil && input.TestResults.Total > 0 {
		testPassRate := float64(input.TestResults.Passed) / float64(input.TestResults.Total) * 100
		report.ProjectQuality = testPassRate
	} else {
		report.ProjectQuality = 80.0 // Default
	}

	report.ActionsTaken = len(input.Actions)
	report.ErrorsMade = len(input.Errors)

	report.Observations = []string{
		"Code follows consistent patterns",
		"Error handling implemented throughout",
		"Test coverage appears adequate",
	}

	report.Recommendations = []string{
		"Consider adding more edge case tests",
		"Documentation could be expanded",
	}

	return report
}

// generateResearcherAnalysis generates the researcher expert analysis
func (j *Judge) generateResearcherAnalysis(input *ExpertInput) *ExpertReport {
	report := &ExpertReport{
		Expert:    ExpertResearcher,
		Timestamp: time.Now(),
	}

	report.PromptAdherence = 90.0
	report.ProjectQuality = 85.0
	report.ActionsTaken = 0 // Researcher typically doesn't modify files

	report.Observations = []string{
		"Information gathered is relevant to the prompt",
		"Multiple sources were consulted",
		"Context was properly structured",
	}

	report.Recommendations = []string{
		"Consider broader documentation coverage",
	}

	return report
}

// generateVisionAnalysis generates the vision expert analysis
func (j *Judge) generateVisionAnalysis(input *ExpertInput) *ExpertReport {
	report := &ExpertReport{
		Expert:    ExpertVision,
		Timestamp: time.Now(),
	}

	report.PromptAdherence = 88.0
	report.ProjectQuality = 82.0
	report.ActionsTaken = 0 // Vision model analyzes but may not modify

	report.Observations = []string{
		"UI components are consistent",
		"Color scheme follows design system",
		"Layout is responsive",
	}

	report.Recommendations = []string{
		"Minor spacing adjustments recommended",
		"Accessibility review suggested",
	}

	return report
}

// SynthesizeTLDR synthesizes all expert reports into a final TLDR
func (j *Judge) SynthesizeTLDR(ctx context.Context, input *SynthesisInput) (*TLDR, error) {
	j.mu.Lock()
	defer j.mu.Unlock()

	// Calculate consensus scores
	consensus := ExpertConsensus{
		PromptAdherence: make(map[ExpertType]float64),
		ProjectQuality:  make(map[ExpertType]float64),
	}

	totalAdherence := 0.0
	totalQuality := 0.0
	count := 0

	for expertType, report := range j.reports {
		if report.Failed {
			continue
		}
		consensus.PromptAdherence[expertType] = report.PromptAdherence
		consensus.ProjectQuality[expertType] = report.ProjectQuality
		totalAdherence += report.PromptAdherence
		totalQuality += report.ProjectQuality
		count++
	}

	if count > 0 {
		consensus.PromptAdherenceAvg = totalAdherence / float64(count)
		consensus.ProjectQualityAvg = totalQuality / float64(count)
	}

	// Determine quality level
	qualityLevel := QualityAcceptable
	avgScore := (consensus.PromptAdherenceAvg + consensus.ProjectQualityAvg) / 2
	if avgScore >= 90 {
		qualityLevel = QualityExceptional
	} else if avgScore < 70 {
		qualityLevel = QualityNeedsImprovement
	}

	// Collect all observations and recommendations
	discoveries := make([]string, 0)
	learnings := make([]string, 0)
	recommendations := make([]string, 0)

	for _, report := range j.reports {
		if report.Failed {
			continue
		}
		// First observation could be a discovery
		if len(report.Observations) > 0 {
			discoveries = append(discoveries, report.Observations[0])
		}
		// Rest could be learnings
		for i := 1; i < len(report.Observations); i++ {
			learnings = append(learnings, report.Observations[i])
		}
		recommendations = append(recommendations, report.Recommendations...)
	}

	// Generate justification
	justification := j.generateJustification(consensus, qualityLevel)

	return &TLDR{
		PromptGoal:           input.OriginalPrompt,
		ImplementationSummary: input.ImplementationSummary,
		ExpertConsensus:      consensus,
		Discoveries:          discoveries,
		Learnings:            learnings,
		Issues:               input.Issues,
		QualityAssessment:    qualityLevel,
		Justification:        justification,
		Recommendations:      recommendations,
	}, nil
}

// SynthesisInput contains input for TLDR synthesis
type SynthesisInput struct {
	OriginalPrompt       string
	ImplementationSummary string
	Issues               []Issue
}

// generateJustification generates an unbiased justification
func (j *Judge) generateJustification(consensus ExpertConsensus, level QualityLevel) string {
	var sb strings.Builder

	sb.WriteString(fmt.Sprintf("Based on aggregated expert scores (Prompt Adherence: %.1f%%, Project Quality: %.1f%%), ", 
		consensus.PromptAdherenceAvg, consensus.ProjectQualityAvg))

	switch level {
	case QualityExceptional:
		sb.WriteString("the implementation exceeds standard requirements. All major objectives were met with high quality.")
	case QualityAcceptable:
		sb.WriteString("the implementation meets standard requirements. Core objectives were achieved satisfactorily.")
	case QualityNeedsImprovement:
		sb.WriteString("the implementation requires additional work. Some objectives were not fully achieved.")
	}

	return sb.String()
}

// FormatTLDR formats the TLDR for display
func FormatTLDR(tldr *TLDR) string {
	var sb strings.Builder

	sb.WriteString("═══════════════════════════════════════════════════════════════════════\n")
	sb.WriteString("OLLAMABOT TLDR\n")
	sb.WriteString("═══════════════════════════════════════════════════════════════════════\n\n")

	sb.WriteString("PROMPT GOAL\n")
	sb.WriteString("───────────\n")
	sb.WriteString(tldr.PromptGoal)
	sb.WriteString("\n\n")

	sb.WriteString("IMPLEMENTATION SUMMARY\n")
	sb.WriteString("──────────────────────\n")
	sb.WriteString(tldr.ImplementationSummary)
	sb.WriteString("\n\n")

	sb.WriteString("EXPERT CONSENSUS\n")
	sb.WriteString("────────────────\n")
	sb.WriteString(fmt.Sprintf("Prompt Adherence: %.1f%%", tldr.ExpertConsensus.PromptAdherenceAvg))
	for expert, score := range tldr.ExpertConsensus.PromptAdherence {
		sb.WriteString(fmt.Sprintf(" (%s: %.1f%%)", expert, score))
	}
	sb.WriteString("\n")
	sb.WriteString(fmt.Sprintf("Project Quality: %.1f%%", tldr.ExpertConsensus.ProjectQualityAvg))
	for expert, score := range tldr.ExpertConsensus.ProjectQuality {
		sb.WriteString(fmt.Sprintf(" (%s: %.1f%%)", expert, score))
	}
	sb.WriteString("\n\n")

	if len(tldr.Discoveries) > 0 {
		sb.WriteString("DISCOVERIES & LEARNINGS\n")
		sb.WriteString("───────────────────────\n")
		for _, d := range tldr.Discoveries {
			sb.WriteString("• " + d + "\n")
		}
		for _, l := range tldr.Learnings {
			sb.WriteString("• " + l + "\n")
		}
		sb.WriteString("\n")
	}

	if len(tldr.Issues) > 0 {
		sb.WriteString("ISSUES ENCOUNTERED\n")
		sb.WriteString("──────────────────\n")
		for _, issue := range tldr.Issues {
			sb.WriteString(fmt.Sprintf("• %s - Resolution: %s\n", issue.Description, issue.Resolution))
		}
		sb.WriteString("\n")
	}

	sb.WriteString("QUALITY ASSESSMENT\n")
	sb.WriteString("──────────────────\n")
	sb.WriteString(fmt.Sprintf("The orchestrator determines this implementation to be:\n%s\n\n", tldr.QualityAssessment))
	sb.WriteString("Justification:\n")
	sb.WriteString(tldr.Justification)
	sb.WriteString("\n\n")

	if len(tldr.Recommendations) > 0 {
		sb.WriteString("ACTIONABLE RECOMMENDATIONS\n")
		sb.WriteString("──────────────────────────\n")
		for i, rec := range tldr.Recommendations {
			sb.WriteString(fmt.Sprintf("%d. %s\n", i+1, rec))
		}
		sb.WriteString("\n")
	}

	sb.WriteString("═══════════════════════════════════════════════════════════════════════\n")

	return sb.String()
}

// HandleExpertFailure handles when an expert fails to respond
func (j *Judge) HandleExpertFailure(expert ExpertType, reason string) {
	j.mu.Lock()
	defer j.mu.Unlock()

	j.reports[expert] = &ExpertReport{
		Expert:        expert,
		Failed:        true,
		FailureReason: reason,
		Timestamp:     time.Now(),
	}
}

// GetFailedExperts returns the list of failed experts
func (j *Judge) GetFailedExperts() []ExpertType {
	j.mu.Lock()
	defer j.mu.Unlock()

	failed := make([]ExpertType, 0)
	for expertType, report := range j.reports {
		if report.Failed {
			failed = append(failed, expertType)
		}
	}
	return failed
}
