package tier

import (
	"testing"
)

func TestDetectTierFromRAM(t *testing.T) {
	tests := []struct {
		name     string
		ramGB    int
		expected ModelTier
	}{
		{"minimal_8gb", 8, TierMinimal},
		{"compact_16gb", 16, TierCompact},
		{"compact_20gb", 20, TierCompact},
		{"balanced_24gb", 24, TierBalanced},
		{"balanced_28gb", 28, TierBalanced},
		{"performance_32gb", 32, TierPerformance},
		{"performance_48gb", 48, TierPerformance},
		{"advanced_64gb", 64, TierAdvanced},
		{"advanced_128gb", 128, TierAdvanced},
		{"minimal_4gb", 4, TierMinimal},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := detectTierFromRAM(tt.ramGB)
			if result != tt.expected {
				t.Errorf("detectTierFromRAM(%d) = %v, want %v", tt.ramGB, result, tt.expected)
			}
		})
	}
}

func TestGetModelForTier(t *testing.T) {
	tests := []struct {
		tier          ModelTier
		expectedModel string
	}{
		{TierMinimal, "deepseek-coder:1.3b"},
		{TierCompact, "deepseek-coder:6.7b"},
		{TierBalanced, "qwen2.5-coder:14b"},
		{TierPerformance, "qwen2.5-coder:32b"},
		{TierAdvanced, "deepseek-coder:33b"},
	}

	for _, tt := range tests {
		t.Run(string(tt.tier), func(t *testing.T) {
			model := GetModelForTier(tt.tier)
			if model.OllamaTag != tt.expectedModel {
				t.Errorf("GetModelForTier(%v) = %v, want %v", tt.tier, model.OllamaTag, tt.expectedModel)
			}
		})
	}
}

func TestTierDisplayName(t *testing.T) {
	tests := []struct {
		tier     ModelTier
		expected string
	}{
		{TierMinimal, "Minimal (1.3B)"},
		{TierCompact, "Compact (7B)"},
		{TierBalanced, "Balanced (14B)"},
		{TierPerformance, "Performance (32B)"},
		{TierAdvanced, "Advanced (33B)"},
	}

	for _, tt := range tests {
		t.Run(string(tt.tier), func(t *testing.T) {
			result := tt.tier.DisplayName()
			if result != tt.expected {
				t.Errorf("%v.DisplayName() = %v, want %v", tt.tier, result, tt.expected)
			}
		})
	}
}

func TestManagerGetActiveModel(t *testing.T) {
	manager := &Manager{
		SelectedModel: ModelVariant{OllamaTag: "qwen2.5-coder:32b"},
	}

	// Without override
	if got := manager.GetActiveModel(); got != "qwen2.5-coder:32b" {
		t.Errorf("GetActiveModel() = %v, want qwen2.5-coder:32b", got)
	}

	// With override
	manager.SetModelOverride("custom:model")
	if got := manager.GetActiveModel(); got != "custom:model" {
		t.Errorf("GetActiveModel() with override = %v, want custom:model", got)
	}
}
