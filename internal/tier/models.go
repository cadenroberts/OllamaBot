package tier

// ModelTier represents a RAM-based tier for model selection
type ModelTier string

const (
	TierMinimal     ModelTier = "minimal"     // 8GB RAM
	TierCompact     ModelTier = "compact"     // 16GB RAM
	TierBalanced    ModelTier = "balanced"    // 24GB RAM
	TierPerformance ModelTier = "performance" // 32GB RAM
	TierAdvanced    ModelTier = "advanced"    // 64GB+ RAM
)

// ModelVariant represents a specific model configuration
type ModelVariant struct {
	Name          string  // Human-readable name
	OllamaTag     string  // Ollama model tag
	SizeGB        float64 // Model size on disk
	Parameters    string  // Parameter count (e.g., "14B")
	ContextWindow int     // Maximum context window
	Quality       int     // Quality rating 1-10
	Speed         int     // Speed rating 1-10
}

// CoderModels maps tiers to their optimal coder model
// These are the primary models obot uses for code fixes
var CoderModels = map[ModelTier]ModelVariant{
	TierMinimal: {
		Name:          "DeepSeek-Coder 1.3B",
		OllamaTag:     "deepseek-coder:1.3b",
		SizeGB:        1.0,
		Parameters:    "1.3B",
		ContextWindow: 2048,
		Quality:       5,
		Speed:         10,
	},
	TierCompact: {
		Name:          "DeepSeek-Coder 6.7B",
		OllamaTag:     "deepseek-coder:6.7b",
		SizeGB:        4.0,
		Parameters:    "6.7B",
		ContextWindow: 4096,
		Quality:       8,
		Speed:         8,
	},
	TierBalanced: {
		Name:          "Qwen2.5-Coder 14B",
		OllamaTag:     "qwen2.5-coder:14b",
		SizeGB:        9.0,
		Parameters:    "14B",
		ContextWindow: 8192,
		Quality:       8,
		Speed:         7,
	},
	TierPerformance: {
		Name:          "Qwen2.5-Coder 32B",
		OllamaTag:     "qwen2.5-coder:32b",
		SizeGB:        20.0,
		Parameters:    "32B",
		ContextWindow: 16384,
		Quality:       9,
		Speed:         5,
	},
	TierAdvanced: {
		Name:          "DeepSeek-Coder 33B",
		OllamaTag:     "deepseek-coder:33b",
		SizeGB:        20.0,
		Parameters:    "33B",
		ContextWindow: 32768,
		Quality:       10,
		Speed:         4,
	},
}

// TierInfo contains metadata about a tier
type TierInfo struct {
	Tier            ModelTier
	MinRAM          int    // Minimum RAM in GB
	Description     string // Human-readable description
	TokensPerSecond string // Expected performance range
}

// Tiers provides metadata for all available tiers
var Tiers = []TierInfo{
	{
		Tier:            TierMinimal,
		MinRAM:          8,
		Description:     "Emergency mode: 1.3B model with limited capability",
		TokensPerSecond: "40-60",
	},
	{
		Tier:            TierCompact,
		MinRAM:          16,
		Description:     "Good for simpler tasks with 6.7B model",
		TokensPerSecond: "25-40",
	},
	{
		Tier:            TierBalanced,
		MinRAM:          24,
		Description:     "Balanced quality and speed with 14B model",
		TokensPerSecond: "15-25",
	},
	{
		Tier:            TierPerformance,
		MinRAM:          32,
		Description:     "Recommended: excellent quality with 32B model",
		TokensPerSecond: "8-15",
	},
	{
		Tier:            TierAdvanced,
		MinRAM:          64,
		Description:     "Professional: state-of-the-art 33B model",
		TokensPerSecond: "5-10",
	},
}

// GetTierInfo returns info for a specific tier
func GetTierInfo(t ModelTier) TierInfo {
	for _, info := range Tiers {
		if info.Tier == t {
			return info
		}
	}
	// Default to minimal
	return Tiers[0]
}

// String returns the tier name
func (t ModelTier) String() string {
	return string(t)
}

// DisplayName returns a human-readable tier name
func (t ModelTier) DisplayName() string {
	switch t {
	case TierMinimal:
		return "Minimal (1.3B)"
	case TierCompact:
		return "Compact (7B)"
	case TierBalanced:
		return "Balanced (14B)"
	case TierPerformance:
		return "Performance (32B)"
	case TierAdvanced:
		return "Advanced (33B)"
	default:
		return string(t)
	}
}
