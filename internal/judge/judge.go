// Package judge implements LLM-as-judge analysis for obot orchestration.
// This file defines the shared types used by the Coordinator in coordinator.go.
package judge

import (
	"time"
)

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
	PromptGoal            string
	ImplementationSummary string
	ExpertConsensus       ExpertConsensus
	Discoveries           []string
	Learnings             []string
	Issues                []Issue
	QualityAssessment     QualityLevel
	Justification         string
	Recommendations       []string
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

// SynthesisInput contains input for TLDR synthesis
type SynthesisInput struct {
	OriginalPrompt        string
	ImplementationSummary string
	Issues                []Issue
}
