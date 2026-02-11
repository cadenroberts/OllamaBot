package delegation

import (
	"strings"
	"testing"

	"github.com/croberts/obot/internal/model"
	"github.com/croberts/obot/internal/orchestrate"
)

func TestNewHandler(t *testing.T) {
	coord := model.NewCoordinator(nil)
	h := NewHandler(coord)
	if h == nil {
		t.Fatal("NewHandler returned nil")
	}
}

func TestHandler_GetAvailableDelegates(t *testing.T) {
	coord := model.NewCoordinator(nil)
	h := NewHandler(coord)
	delegates := h.GetAvailableDelegates()
	if len(delegates) == 0 {
		t.Fatal("GetAvailableDelegates returned empty")
	}
	want := []orchestrate.ModelType{
		orchestrate.ModelCoder,
		orchestrate.ModelResearcher,
		orchestrate.ModelVision,
	}
	for _, d := range want {
		found := false
		for _, g := range delegates {
			if g == d {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("GetAvailableDelegates missing %v", d)
		}
	}
}

func TestHandler_ValidateTask(t *testing.T) {
	coord := model.NewCoordinator(nil)
	h := NewHandler(coord)

	if err := h.ValidateTask("short"); err == nil {
		t.Error("ValidateTask should reject task < 10 chars")
	}
	if err := h.ValidateTask("adequate task"); err != nil {
		t.Errorf("ValidateTask should accept valid task: %v", err)
	}
}

func TestHandler_FormatDelegationResult(t *testing.T) {
	coord := model.NewCoordinator(nil)
	h := NewHandler(coord)
	got := h.FormatDelegationResult(orchestrate.ModelCoder, "response text")
	if got == "" {
		t.Fatal("FormatDelegationResult returned empty")
	}
	if !strings.Contains(got, "response text") {
		t.Errorf("result should contain response, got %q", got)
	}
	if !strings.Contains(got, "coder") {
		t.Errorf("result should contain model type, got %q", got)
	}
}
