package summary

import (
	"strings"
	"testing"

	"github.com/croberts/obot/internal/orchestrate"
)

func TestNewGenerator(t *testing.T) {
	g := NewGenerator()
	if g == nil {
		t.Fatal("NewGenerator() = nil")
	}
	out := g.Generate()
	if out == "" {
		t.Error("NewGenerator().Generate() returned empty")
	}
}

func TestGenerator_Generate(t *testing.T) {
	g := NewGenerator()
	g.SetFlowCode("K1")
	g.SetTLDR("Test summary")

	out := g.Generate()
	if out == "" {
		t.Fatal("Generate() returned empty string")
	}
	if !strings.Contains(out, "Prompt Summary") {
		t.Errorf("Generate() output missing 'Prompt Summary': %q", out[:100])
	}
	if !strings.Contains(out, "Orchestrator") {
		t.Errorf("Generate() output missing 'Orchestrator': %q", out[:100])
	}
	if !strings.Contains(out, "Test summary") {
		t.Errorf("Generate() output missing TLDR content: %q", out[:200])
	}
}

func TestGenerator_AddProcessTokens(t *testing.T) {
	g := NewGenerator()
	g.SetStats(&orchestrate.OrchestratorStats{TotalTokens: 1000})
	g.SetFlowCode("K1")

	g.AddProcessTokens(orchestrate.ScheduleKnowledge, orchestrate.Process1, 100)
	g.AddProcessTokens(orchestrate.ScheduleKnowledge, orchestrate.Process2, 200)

	out := g.Generate()
	if out == "" {
		t.Fatal("Generate() after AddProcessTokens returned empty")
	}
	if !strings.Contains(out, "100") {
		t.Error("Generate() output should contain token count 100")
	}
}
