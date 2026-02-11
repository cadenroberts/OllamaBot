package judge

import (
	"testing"
)

func TestTLDR_ExpertConsensus_initialized(t *testing.T) {
	consensus := ExpertConsensus{
		PromptAdherenceAvg: 85.0,
		ProjectQualityAvg:  90.0,
		PromptAdherence: map[ExpertType]float64{
			ExpertCoder:      80.0,
			ExpertResearcher: 90.0,
			ExpertVision:     85.0,
		},
		ProjectQuality: map[ExpertType]float64{
			ExpertCoder:      88.0,
			ExpertResearcher: 92.0,
			ExpertVision:     90.0,
		},
	}

	tldr := TLDR{
		PromptGoal:            "test goal",
		ImplementationSummary: "summary",
		ExpertConsensus:       consensus,
		QualityAssessment:     QualityAcceptable,
	}

	if tldr.ExpertConsensus.PromptAdherence == nil {
		t.Fatal("ExpertConsensus.PromptAdherence map should be initialized")
	}
	if tldr.ExpertConsensus.ProjectQuality == nil {
		t.Fatal("ExpertConsensus.ProjectQuality map should be initialized")
	}
	if len(tldr.ExpertConsensus.PromptAdherence) != 3 {
		t.Errorf("PromptAdherence map len = %d, want 3", len(tldr.ExpertConsensus.PromptAdherence))
	}
	if tldr.ExpertConsensus.PromptAdherenceAvg != 85.0 {
		t.Errorf("PromptAdherenceAvg = %v, want 85.0", tldr.ExpertConsensus.PromptAdherenceAvg)
	}
}

func TestExpertReport_zeroValue(t *testing.T) {
	var r ExpertReport
	if r.Expert != "" {
		t.Errorf("zero ExpertReport.Expert = %q, want empty", r.Expert)
	}
	if r.Observations != nil {
		t.Error("zero ExpertReport.Observations should be nil")
	}
}

func TestQualityLevel_constants(t *testing.T) {
	if QualityAcceptable != "ACCEPTABLE" {
		t.Errorf("QualityAcceptable = %q, want ACCEPTABLE", QualityAcceptable)
	}
	if QualityNeedsImprovement != "NEEDS_IMPROVEMENT" {
		t.Errorf("QualityNeedsImprovement = %q, want NEEDS_IMPROVEMENT", QualityNeedsImprovement)
	}
	if QualityExceptional != "EXCEPTIONAL" {
		t.Errorf("QualityExceptional = %q, want EXCEPTIONAL", QualityExceptional)
	}
}

func TestExpertType_constants(t *testing.T) {
	if ExpertCoder != "coder" {
		t.Errorf("ExpertCoder = %q, want coder", ExpertCoder)
	}
	if ExpertResearcher != "researcher" {
		t.Errorf("ExpertResearcher = %q, want researcher", ExpertResearcher)
	}
	if ExpertVision != "vision" {
		t.Errorf("ExpertVision = %q, want vision", ExpertVision)
	}
}
