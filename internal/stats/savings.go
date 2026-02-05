package stats

// APICosts contains pricing for commercial AI APIs (per 1K tokens)
// Updated as of 2026
type APICosts struct {
	// Claude Opus 4.5 (premium tier)
	ClaudeOpusInput  float64
	ClaudeOpusOutput float64

	// Claude Sonnet 3.5
	ClaudeSonnetInput  float64
	ClaudeSonnetOutput float64

	// GPT-4o
	GPT4oInput  float64
	GPT4oOutput float64

	// GPT-4 Turbo
	GPT4TurboInput  float64
	GPT4TurboOutput float64
}

// CurrentPricing returns current API pricing (per 1K tokens)
func CurrentPricing() APICosts {
	return APICosts{
		// Claude Opus 4.5 - premium model
		ClaudeOpusInput:  0.015, // $0.015 per 1K input tokens
		ClaudeOpusOutput: 0.075, // $0.075 per 1K output tokens

		// Claude Sonnet 3.5
		ClaudeSonnetInput:  0.003, // $0.003 per 1K input tokens
		ClaudeSonnetOutput: 0.015, // $0.015 per 1K output tokens

		// GPT-4o
		GPT4oInput:  0.005, // $0.005 per 1K input tokens
		GPT4oOutput: 0.015, // $0.015 per 1K output tokens

		// GPT-4 Turbo
		GPT4TurboInput:  0.01, // $0.01 per 1K input tokens
		GPT4TurboOutput: 0.03, // $0.03 per 1K output tokens
	}
}

// CalculateCostSavings calculates savings for given token counts
func CalculateCostSavings(inputTokens, outputTokens int) CostSavings {
	pricing := CurrentPricing()

	inputK := float64(inputTokens) / 1000.0
	outputK := float64(outputTokens) / 1000.0

	return CostSavings{
		ClaudeOpus:   inputK*pricing.ClaudeOpusInput + outputK*pricing.ClaudeOpusOutput,
		ClaudeSonnet: inputK*pricing.ClaudeSonnetInput + outputK*pricing.ClaudeSonnetOutput,
		GPT4o:        inputK*pricing.GPT4oInput + outputK*pricing.GPT4oOutput,
		GPT4Turbo:    inputK*pricing.GPT4TurboInput + outputK*pricing.GPT4TurboOutput,
	}
}

// CostSavings contains calculated savings vs each provider
type CostSavings struct {
	ClaudeOpus   float64
	ClaudeSonnet float64
	GPT4o        float64
	GPT4Turbo    float64
}

// Total returns the total savings vs the most expensive option (Opus)
func (cs CostSavings) Total() float64 {
	return cs.ClaudeOpus
}

// Average returns the average savings across all providers
func (cs CostSavings) Average() float64 {
	return (cs.ClaudeOpus + cs.ClaudeSonnet + cs.GPT4o + cs.GPT4Turbo) / 4
}
