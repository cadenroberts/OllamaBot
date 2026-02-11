package stats

import (
	"github.com/croberts/obot/internal/telemetry"
)

// APICosts contains pricing for commercial AI APIs (per 1K tokens)
// Deprecated: Use telemetry.CommercialPricing instead.
type APICosts struct {
	ClaudeOpusInput    float64
	ClaudeOpusOutput   float64
	ClaudeSonnetInput  float64
	ClaudeSonnetOutput float64
	GPT4oInput         float64
	GPT4oOutput        float64
	GPT4TurboInput     float64
	GPT4TurboOutput    float64
}

// CurrentPricing returns current API pricing (per 1K tokens)
// It is derived from the telemetry package (single source of truth).
func CurrentPricing() APICosts {
	p := telemetry.GetCurrentPricing()
	return APICosts{
		ClaudeOpusInput:    p.ClaudeOpus.Input / 1000.0,
		ClaudeOpusOutput:   p.ClaudeOpus.Output / 1000.0,
		ClaudeSonnetInput:  p.ClaudeSonnet.Input / 1000.0,
		ClaudeSonnetOutput: p.ClaudeSonnet.Output / 1000.0,
		GPT4oInput:         p.GPT4o.Input / 1000.0,
		GPT4oOutput:        p.GPT4o.Output / 1000.0,
		GPT4TurboInput:     p.GPT4Turbo.Input / 1000.0,
		GPT4TurboOutput:    p.GPT4Turbo.Output / 1000.0,
	}
}

// CalculateCostSavings calculates savings for given token counts.
// It uses the unified CostSavingsCalculator from the telemetry package.
func CalculateCostSavings(inputTokens, outputTokens int) telemetry.CostSavings {
	calc := telemetry.NewCostSavingsCalculator()
	breakdown := calc.GetBreakdown(int64(inputTokens), int64(outputTokens))

	return telemetry.CostSavings{
		ClaudeOpus:   breakdown["claude-opus"],
		ClaudeSonnet: breakdown["claude-sonnet"],
		GPT4o:        breakdown["gpt-4o"],
		GPT4Turbo:    breakdown["gpt-4-turbo"],
	}
}
