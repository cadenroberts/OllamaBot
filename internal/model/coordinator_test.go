package model

import (
	"testing"

	"github.com/croberts/obot/internal/orchestrate"
)

func TestNewCoordinator(t *testing.T) {
	c := NewCoordinator(nil)
	if c == nil {
		t.Fatal("NewCoordinator returned nil")
	}
}

func TestCoordinator_Get(t *testing.T) {
	c := NewCoordinator(nil)
	client := c.Get(orchestrate.ModelOrchestrator)
	if client == nil {
		t.Error("Get(orchestrator) returned nil")
	}
}

func TestCoordinator_GetOrchestratorModel(t *testing.T) {
	c := NewCoordinator(nil)
	client := c.GetOrchestratorModel()
	if client == nil {
		t.Error("GetOrchestratorModel returned nil")
	}
}

func TestCoordinator_GetModel(t *testing.T) {
	c := NewCoordinator(nil)
	cfg := c.GetModel(orchestrate.ModelCoder)
	if cfg == nil {
		t.Fatal("GetModel(coder) returned nil")
	}
	if cfg.Name == "" {
		t.Error("model config Name is empty")
	}
}

func TestCoordinator_SelectModelForSchedule(t *testing.T) {
	c := NewCoordinator(nil)
	models := c.SelectModelForSchedule(orchestrate.ScheduleKnowledge)
	if len(models) == 0 {
		t.Error("SelectModelForSchedule returned empty slice")
	}
	if models[0] != orchestrate.ModelResearcher {
		t.Errorf("Knowledge schedule should use researcher, got %s", models[0])
	}
}

func TestCoordinator_SelectModelForProcess(t *testing.T) {
	c := NewCoordinator(nil)
	mt := c.SelectModelForProcess(orchestrate.ScheduleProduction, orchestrate.Process3)
	if mt != orchestrate.ModelVision {
		t.Errorf("Production P3 should use vision, got %s", mt)
	}
	mt = c.SelectModelForProcess(orchestrate.ScheduleImplement, orchestrate.Process1)
	if mt != orchestrate.ModelCoder {
		t.Errorf("Implement P1 should use coder, got %s", mt)
	}
}

func TestCoordinator_RecordTokens(t *testing.T) {
	c := NewCoordinator(nil)
	c.RecordTokens(orchestrate.ModelCoder, 100)
	counts := c.GetTokenCounts()
	if counts[orchestrate.ModelCoder] != 100 {
		t.Errorf("expected 100 tokens, got %d", counts[orchestrate.ModelCoder])
	}
}

func TestCoordinator_SelectModelForIntent(t *testing.T) {
	c := NewCoordinator(nil)
	if c.SelectModelForIntent("coding") != orchestrate.ModelCoder {
		t.Error("coding intent should return ModelCoder")
	}
	if c.SelectModelForIntent("research") != orchestrate.ModelResearcher {
		t.Error("research intent should return ModelResearcher")
	}
}

func TestDefaultModels(t *testing.T) {
	models := DefaultModels()
	if len(models) == 0 {
		t.Fatal("DefaultModels returned empty map")
	}
	if models[orchestrate.ModelOrchestrator] == nil {
		t.Error("orchestrator model config missing")
	}
}

func TestGetRAMTier(t *testing.T) {
	if GetRAMTier(8) != RAMMinimal {
		t.Errorf("8GB should be minimal, got %s", GetRAMTier(8))
	}
	if GetRAMTier(20) != RAMCompact {
		t.Errorf("20GB should be compact, got %s", GetRAMTier(20))
	}
	if GetRAMTier(64) != RAMAdvanced {
		t.Errorf("64GB should be advanced, got %s", GetRAMTier(64))
	}
}

func TestMapIntent(t *testing.T) {
	if MapIntent("research the topic", 0) != IntentResearch {
		t.Error("research prompt should map to IntentResearch")
	}
	if MapIntent("optimize the code", 0) != IntentOptimization {
		t.Error("optimize prompt should map to IntentOptimization")
	}
}
