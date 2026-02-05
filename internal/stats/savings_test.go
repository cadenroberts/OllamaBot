package stats

import (
	"math"
	"testing"
)

func TestCalculateCostSavings(t *testing.T) {
	tests := []struct {
		name         string
		inputTokens  int
		outputTokens int
	}{
		{"small_request", 100, 200},
		{"medium_request", 1000, 2000},
		{"large_request", 10000, 20000},
		{"zero_tokens", 0, 0},
	}

	pricing := CurrentPricing()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			savings := CalculateCostSavings(tt.inputTokens, tt.outputTokens)

			// Calculate expected values
			inputK := float64(tt.inputTokens) / 1000.0
			outputK := float64(tt.outputTokens) / 1000.0

			expectedOpus := inputK*pricing.ClaudeOpusInput + outputK*pricing.ClaudeOpusOutput
			expectedSonnet := inputK*pricing.ClaudeSonnetInput + outputK*pricing.ClaudeSonnetOutput
			expectedGPT4o := inputK*pricing.GPT4oInput + outputK*pricing.GPT4oOutput

			// Check Claude Opus
			if math.Abs(savings.ClaudeOpus-expectedOpus) > 0.0001 {
				t.Errorf("ClaudeOpus = %v, want %v", savings.ClaudeOpus, expectedOpus)
			}

			// Check Claude Sonnet
			if math.Abs(savings.ClaudeSonnet-expectedSonnet) > 0.0001 {
				t.Errorf("ClaudeSonnet = %v, want %v", savings.ClaudeSonnet, expectedSonnet)
			}

			// Check GPT-4o
			if math.Abs(savings.GPT4o-expectedGPT4o) > 0.0001 {
				t.Errorf("GPT4o = %v, want %v", savings.GPT4o, expectedGPT4o)
			}
		})
	}
}

func TestCostSavingsTotal(t *testing.T) {
	savings := CalculateCostSavings(1000, 1000)

	// Total should be Claude Opus savings (highest)
	if savings.Total() != savings.ClaudeOpus {
		t.Errorf("Total() = %v, want %v (ClaudeOpus)", savings.Total(), savings.ClaudeOpus)
	}
}

func TestCostSavingsAverage(t *testing.T) {
	savings := CalculateCostSavings(1000, 1000)

	expected := (savings.ClaudeOpus + savings.ClaudeSonnet + savings.GPT4o + savings.GPT4Turbo) / 4
	if math.Abs(savings.Average()-expected) > 0.0001 {
		t.Errorf("Average() = %v, want %v", savings.Average(), expected)
	}
}

func TestCurrentPricing(t *testing.T) {
	pricing := CurrentPricing()

	// Verify pricing is set (non-zero)
	if pricing.ClaudeOpusInput == 0 {
		t.Error("ClaudeOpusInput should not be zero")
	}
	if pricing.ClaudeOpusOutput == 0 {
		t.Error("ClaudeOpusOutput should not be zero")
	}

	// Verify output is more expensive than input (typical for LLMs)
	if pricing.ClaudeOpusOutput <= pricing.ClaudeOpusInput {
		t.Error("Output tokens should be more expensive than input tokens")
	}

	// Verify Opus is more expensive than Sonnet
	if pricing.ClaudeSonnetInput >= pricing.ClaudeOpusInput {
		t.Error("Opus should be more expensive than Sonnet")
	}
}
