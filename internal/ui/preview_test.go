package ui

import (
	"strings"
	"testing"

	"github.com/croberts/obot/internal/agent"
)

func TestDiffPreviewDisplaysCorrectly(t *testing.T) {
	widget := NewDiffPreviewWidget(80)

	diff := &agent.DiffSummary{
		TotalAdded:   1,
		TotalRemoved: 1,
		Deletions: []agent.DiffLine{
			{LineNumber: 10, Content: "func old() {", Type: agent.DiffLineDelete},
		},
		Additions: []agent.DiffLine{
			{LineNumber: 10, Content: "func new() {", Type: agent.DiffLineAdd},
		},
	}

	rendered := widget.Render("test.go", diff)

	// Check if key elements are present
	if !strings.Contains(rendered, "PREVIEW") {
		t.Errorf("Rendered output missing 'PREVIEW'")
	}
	if !strings.Contains(rendered, "test.go") {
		t.Errorf("Rendered output missing filename 'test.go'")
	}
	if !strings.Contains(rendered, "+1") {
		t.Errorf("Rendered output missing addition count '+1'")
	}
	if !strings.Contains(rendered, "-1") {
		t.Errorf("Rendered output missing removal count '-1'")
	}
	if !strings.Contains(rendered, "old") {
		t.Errorf("Rendered output missing deleted content 'old'")
	}
	if !strings.Contains(rendered, "new") {
		t.Errorf("Rendered output missing added content 'new'")
	}

	// Verify syntax highlighting (basic check for TokyoBlueBold or ANSIReset)
	// "func" is a keyword in .go
	if !strings.Contains(rendered, TokyoBlueBold) {
		t.Errorf("Rendered output missing syntax highlighting for keywords")
	}
}

func TestRenderNilDiff(t *testing.T) {
	widget := NewDiffPreviewWidget(80)
	rendered := widget.Render("test.go", nil)
	if !strings.Contains(rendered, "No changes") {
		t.Errorf("Expected 'No changes' message for nil diff")
	}
}
