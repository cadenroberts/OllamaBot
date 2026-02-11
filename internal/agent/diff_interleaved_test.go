package agent

import (
	"strings"
	"testing"
)

func TestRenderInterleaved(t *testing.T) {
	ds := &DiffSummary{
		Interleaved: []DiffLine{
			{LineNumber: 1, Content: "line 1", Type: DiffLineContext},
			{LineNumber: 2, Content: "line 2 deleted", Type: DiffLineDelete},
			{LineNumber: 2, Content: "line 2 added", Type: DiffLineAdd},
			{LineNumber: 3, Content: "line 3", Type: DiffLineContext},
		},
	}

	got := ds.RenderInterleaved()
	expected := "  line 1\n- line 2 deleted\n+ line 2 added\n  line 3\n"

	if got != expected {
		t.Errorf("Expected:\n%s\nGot:\n%s", expected, got)
	}
}

func TestComputeDiffInterleaved(t *testing.T) {
	oldContent := "line 1\nline 2\nline 3"
	newContent := "line 1\nline 2 modified\nline 3"
	
	summary := computeDiff(oldContent, newContent)
	
	foundModified := false
	for _, line := range summary.Interleaved {
		if strings.Contains(line.Content, "modified") && line.Type == DiffLineAdd {
			foundModified = true
		}
	}
	
	if !foundModified {
		t.Errorf("Interleaved diff missing modified line")
	}
}
