// Package telemetry handles usage tracking and cost analysis.
package telemetry

import (
	"fmt"
	"math"
	"time"
)

// ModelPricing represents input/output costs per 1 million tokens in USD.
type ModelPricing struct {
	Input  float64
	Output float64
}

// CommercialPricing contains pricing for various commercial LLMs as of early 2026.
type CommercialPricing struct {
	GPT4o        ModelPricing
	GPT4oMini    ModelPricing
	GPT4Turbo    ModelPricing
	ClaudeOpus   ModelPricing
	ClaudeSonnet ModelPricing
	ClaudeHaiku  ModelPricing
	GeminiFlash  ModelPricing
	GeminiPro    ModelPricing
}

// GetCurrentPricing returns the current market-average commercial API pricing.
// These rates reflect the competitive landscape where token costs have stabilized.
func GetCurrentPricing() CommercialPricing {
	return CommercialPricing{
		GPT4o: ModelPricing{
			Input:  2.50,  // $2.50 per 1M tokens
			Output: 10.00, // $10.00 per 1M tokens
		},
		GPT4oMini: ModelPricing{
			Input:  0.15,
			Output: 0.60,
		},
		GPT4Turbo: ModelPricing{
			Input:  10.00,
			Output: 30.00,
		},
		ClaudeOpus: ModelPricing{
			Input:  15.00,
			Output: 75.00,
		},
		ClaudeSonnet: ModelPricing{
			Input:  3.00,  // $3.00 per 1M tokens
			Output: 15.00, // $15.00 per 1M tokens
		},
		ClaudeHaiku: ModelPricing{
			Input:  0.25,
			Output: 1.25,
		},
		GeminiFlash: ModelPricing{
			Input:  0.10, // $0.10 per 1M tokens
			Output: 0.40, // $0.40 per 1M tokens
		},
		GeminiPro: ModelPricing{
			Input:  1.25, // $1.25 per 1M tokens
			Output: 5.00, // $5.00 per 1M tokens
		},
	}
}

// CostSavingsCalculator compares local execution costs (effectively zero) vs commercial providers.
// It assumes Ollama runs on existing hardware with negligible marginal electricity cost.
type CostSavingsCalculator struct {
	pricing CommercialPricing
}

// NewCostSavingsCalculator creates a new calculator with default market pricing.
func NewCostSavingsCalculator() *CostSavingsCalculator {
	return &CostSavingsCalculator{
		pricing: GetCurrentPricing(),
	}
}

// CalculateSavings estimates total savings for the given token volume.
// It returns the average saving across major "Pro" grade providers (GPT-4o, Claude Sonnet, Gemini Pro).
func (c *CostSavingsCalculator) CalculateSavings(inputTokens, outputTokens int64) float64 {
	if inputTokens <= 0 && outputTokens <= 0 {
		return 0.0
	}

	inputM := float64(inputTokens) / 1_000_000.0
	outputM := float64(outputTokens) / 1_000_000.0

	gpt4Cost := (inputM * c.pricing.GPT4o.Input) + (outputM * c.pricing.GPT4o.Output)
	claudeCost := (inputM * c.pricing.ClaudeSonnet.Input) + (outputM * c.pricing.ClaudeSonnet.Output)
	geminiCost := (inputM * c.pricing.GeminiPro.Input) + (outputM * c.pricing.GeminiPro.Output)

	// Average across high-end "workhorse" models for the baseline estimate
	avgCost := (gpt4Cost + claudeCost + geminiCost) / 3.0

	return c.round(avgCost)
}

// Breakdown represents savings compared to each specific commercial model.
type Breakdown map[string]float64

// CostSavings contains calculated savings for major providers.
type CostSavings struct {
	ClaudeOpus   float64
	ClaudeSonnet float64
	GPT4o        float64
	GPT4Turbo    float64
}

// Total returns the total savings vs the most expensive option (Opus).
func (cs CostSavings) Total() float64 {
	return cs.ClaudeOpus
}

// Average returns the average savings across all providers.
func (cs CostSavings) Average() float64 {
	return (cs.ClaudeOpus + cs.ClaudeSonnet + cs.GPT4o + cs.GPT4Turbo) / 4
}

// GetBreakdown returns savings compared to each specific commercial model.
func (c *CostSavingsCalculator) GetBreakdown(inputTokens, outputTokens int64) Breakdown {
	inputM := float64(inputTokens) / 1_000_000.0
	outputM := float64(outputTokens) / 1_000_000.0

	return Breakdown{
		"gpt-4o":        c.round((inputM * c.pricing.GPT4o.Input) + (outputM * c.pricing.GPT4o.Output)),
		"gpt-4o-mini":   c.round((inputM * c.pricing.GPT4oMini.Input) + (outputM * c.pricing.GPT4oMini.Output)),
		"gpt-4-turbo":   c.round((inputM * c.pricing.GPT4Turbo.Input) + (outputM * c.pricing.GPT4Turbo.Output)),
		"claude-opus":   c.round((inputM * c.pricing.ClaudeOpus.Input) + (outputM * c.pricing.ClaudeOpus.Output)),
		"claude-sonnet": c.round((inputM * c.pricing.ClaudeSonnet.Input) + (outputM * c.pricing.ClaudeSonnet.Output)),
		"claude-haiku":  c.round((inputM * c.pricing.ClaudeHaiku.Input) + (outputM * c.pricing.ClaudeHaiku.Output)),
		"gemini-flash":  c.round((inputM * c.pricing.GeminiFlash.Input) + (outputM * c.pricing.GeminiFlash.Output)),
		"gemini-pro":    c.round((inputM * c.pricing.GeminiPro.Input) + (outputM * c.pricing.GeminiPro.Output)),
	}
}

// Projection represents estimated savings over different time horizons.
type Projection struct {
	Daily   float64
	Weekly  float64
	Monthly float64
	Yearly  float64
}

// ProjectSavings calculates future savings based on current usage over a specific period.
func (c *CostSavingsCalculator) ProjectSavings(inputTokens, outputTokens int64, period time.Duration) Projection {
	savings := c.CalculateSavings(inputTokens, outputTokens)
	if period <= 0 || savings <= 0 {
		return Projection{}
	}

	// Normalized to daily rate
	daily := savings / (period.Hours() / 24.0)

	return Projection{
		Daily:   c.round(daily),
		Weekly:  c.round(daily * 7),
		Monthly: c.round(daily * 30.44), // Average month length
		Yearly:  c.round(daily * 365.25), // Average year length
	}
}

// round clean values to 4 decimal places (for sub-penny precision).
func (c *CostSavingsCalculator) round(val float64) float64 {
	return math.Round(val*10000) / 10000
}

// FormatSavings returns a human-readable currency string.
func FormatSavings(amount float64) string {
	if amount < 0.01 && amount > 0 {
		return fmt.Sprintf("$%.4f", amount)
	}
	return fmt.Sprintf("$%.2f", amount)
}
