package telemetry

import (
	"testing"
)

func TestCostSavingsCalculator(t *testing.T) {
	calc := NewCostSavingsCalculator()

	// Test with 1M input and 1M output tokens
	// GPT-4o: 2.50 + 10.00 = 12.50
	// Claude Sonnet: 3.00 + 15.00 = 18.00
	// Gemini Pro: 1.25 + 5.00 = 6.25
	// Avg: (12.50 + 18.00 + 6.25) / 3 = 36.75 / 3 = 12.25

	savings := calc.CalculateSavings(1_000_000, 1_000_000)
	expected := 12.25

	if savings != expected {
		t.Errorf("Expected savings %v, got %v", expected, savings)
	}

	breakdown := calc.GetBreakdown(1_000_000, 1_000_000)
	if breakdown["gpt-4o"] != 12.50 {
		t.Errorf("Expected GPT-4o savings 12.50, got %v", breakdown["gpt-4o"])
	}
	if breakdown["claude-sonnet"] != 18.00 {
		t.Errorf("Expected Claude Sonnet savings 18.00, got %v", breakdown["claude-sonnet"])
	}
	if breakdown["gemini-pro"] != 6.25 {
		t.Errorf("Expected Gemini Pro savings 6.25, got %v", breakdown["gemini-pro"])
	}
}

func TestSavingsCalculatedAccurately(t *testing.T) {
	calc := NewCostSavingsCalculator()

	// Test case: 500k input, 100k output
	// GPT-4o: 0.5 * 2.50 + 0.1 * 10.00 = 1.25 + 1.00 = 2.25
	// Claude Sonnet: 0.5 * 3.00 + 0.1 * 15.00 = 1.50 + 1.50 = 3.00
	// Gemini Pro: 0.5 * 1.25 + 0.1 * 5.00 = 0.625 + 0.50 = 1.125
	// Avg: (2.25 + 3.00 + 1.125) / 3 = 6.375 / 3 = 2.125

	savings := calc.CalculateSavings(500_000, 100_000)
	expected := 2.125
	if savings != expected {
		t.Errorf("Expected savings %v, got %v", expected, savings)
	}

	// Test small amount formatting
	formatted := FormatSavings(0.001234)
	if formatted != "$0.0012" {
		t.Errorf("Expected formatted savings $0.0012, got %s", formatted)
	}

	formattedLarge := FormatSavings(12.3456)
	if formattedLarge != "$12.35" {
		t.Errorf("Expected formatted savings $12.35, got %s", formattedLarge)
	}
}

func TestZeroTokens(t *testing.T) {
	calc := NewCostSavingsCalculator()
	savings := calc.CalculateSavings(0, 0)
	if savings != 0 {
		t.Errorf("Expected zero savings for zero tokens, got %v", savings)
	}
}
