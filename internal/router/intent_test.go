package router

import "testing"

func TestIntentRouter_Classify(t *testing.T) {
	r := NewIntentRouter()

	tests := []struct {
		task   string
		expect Intent
	}{
		{"fix this bug", IntentCoding},
		{"implement the feature", IntentCoding},
		{"debug the crash", IntentCoding},
		{"what is the best practice", IntentResearch},
		{"explain how does it work", IntentResearch},
		{"write a readme", IntentWriting},
		{"analyze image screenshot", IntentVision},
		{"hello world", IntentGeneral},
	}

	for _, tt := range tests {
		got := r.Classify(tt.task)
		if got != tt.expect {
			t.Errorf("Classify(%q) = %v, want %v", tt.task, got, tt.expect)
		}
	}
}

func TestIntentRouter_SelectModelRole(t *testing.T) {
	r := NewIntentRouter()

	if got := r.SelectModelRole(IntentCoding); got != "coder" {
		t.Errorf("SelectModelRole(IntentCoding) = %q, want coder", got)
	}
	if got := r.SelectModelRole(IntentResearch); got != "researcher" {
		t.Errorf("SelectModelRole(IntentResearch) = %q, want researcher", got)
	}
	if got := r.SelectModelRole(IntentVision); got != "vision" {
		t.Errorf("SelectModelRole(IntentVision) = %q, want vision", got)
	}
}
