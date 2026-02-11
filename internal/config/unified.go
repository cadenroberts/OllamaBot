// Package config implements unified YAML configuration for obot.
// Reads from ~/.config/ollamabot/config.yaml with backward-compat symlink from ~/.config/obot/.
package config

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// UnifiedConfig is the top-level shared configuration read by both CLI and IDE.
type UnifiedConfig struct {
	Version string `yaml:"version"`

	Models        ModelsConfig        `yaml:"models"`
	Orchestration OrchestrationConfig `yaml:"orchestration"`
	Context       ContextConfig       `yaml:"context"`
	Quality       QualityConfig       `yaml:"quality"`
	Platforms     PlatformsConfig     `yaml:"platforms"`
	Ollama        OllamaConfig        `yaml:"ollama"`
}

// ModelsConfig holds model tier and role mappings.
type ModelsConfig struct {
	TierDetection TierDetectionConfig        `yaml:"tier_detection"`
	Orchestrator  ModelRoleConfig             `yaml:"orchestrator"`
	Coder         ModelRoleConfig             `yaml:"coder"`
	Researcher    ModelRoleConfig             `yaml:"researcher"`
	Vision        ModelRoleConfig             `yaml:"vision"`
}

// TierDetectionConfig controls automatic tier detection.
type TierDetectionConfig struct {
	Auto       bool               `yaml:"auto"`
	Thresholds map[string][2]int  `yaml:"thresholds"`
}

// ModelRoleConfig defines a model role with tier mappings.
type ModelRoleConfig struct {
	Default     string            `yaml:"default"`
	TierMapping map[string]string `yaml:"tier_mapping"`
}

// OrchestrationConfig holds orchestration settings.
type OrchestrationConfig struct {
	DefaultMode string           `yaml:"default_mode"`
	Schedules   []ScheduleConfig `yaml:"schedules"`
}

// ScheduleConfig defines a single schedule.
type ScheduleConfig struct {
	ID           string                       `yaml:"id"`
	Processes    []string                     `yaml:"processes"`
	Model        string                       `yaml:"model"`
	Consultation map[string]ConsultationEntry `yaml:"consultation,omitempty"`
}

// ConsultationEntry defines consultation behavior for a process.
type ConsultationEntry struct {
	Type    string `yaml:"type"`
	Timeout int    `yaml:"timeout"`
}

// ContextConfig holds context management settings.
type ContextConfig struct {
	MaxTokens        int                `yaml:"max_tokens"`
	BudgetAllocation map[string]float64 `yaml:"budget_allocation"`
	Compression      CompressionConfig  `yaml:"compression"`
}

// CompressionConfig holds compression settings.
type CompressionConfig struct {
	Enabled  bool     `yaml:"enabled"`
	Strategy string   `yaml:"strategy"`
	Preserve []string `yaml:"preserve"`
}

// QualityConfig holds quality preset definitions.
type QualityConfig struct {
	Fast     QualityPreset `yaml:"fast"`
	Balanced QualityPreset `yaml:"balanced"`
	Thorough QualityPreset `yaml:"thorough"`
}

// QualityPreset defines a quality preset.
type QualityPreset struct {
	Iterations   int    `yaml:"iterations"`
	Verification string `yaml:"verification"`
}

// PlatformsConfig holds platform-specific settings.
type PlatformsConfig struct {
	CLI CLIPlatformConfig `yaml:"cli"`
	IDE IDEPlatformConfig `yaml:"ide"`
}

// CLIPlatformConfig holds CLI-specific settings.
type CLIPlatformConfig struct {
	Verbose     bool `yaml:"verbose"`
	MemGraph    bool `yaml:"mem_graph"`
	ColorOutput bool `yaml:"color_output"`
}

// IDEPlatformConfig holds IDE-specific settings.
type IDEPlatformConfig struct {
	Theme          string `yaml:"theme"`
	FontSize       int    `yaml:"font_size"`
	ShowTokenUsage bool   `yaml:"show_token_usage"`
}

// OllamaConfig holds Ollama connection settings.
type OllamaConfig struct {
	URL            string `yaml:"url"`
	TimeoutSeconds int    `yaml:"timeout_seconds"`
}

// UnifiedConfigDir returns the canonical config directory.
func UnifiedConfigDir() string {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		homeDir = "."
	}
	return filepath.Join(homeDir, ".config", "ollamabot")
}

// UnifiedConfigPath returns the canonical config file path.
func UnifiedConfigPath() string {
	return filepath.Join(UnifiedConfigDir(), "config.yaml")
}

// DefaultUnifiedConfig returns the default unified configuration.
func DefaultUnifiedConfig() *UnifiedConfig {
	return &UnifiedConfig{
		Version: "2.0",
		Models: ModelsConfig{
			TierDetection: TierDetectionConfig{
				Auto: true,
				Thresholds: map[string][2]int{
					"minimal":     {0, 15},
					"compact":     {16, 23},
					"balanced":    {24, 31},
					"performance": {32, 63},
					"advanced":    {64, 999},
				},
			},
			Orchestrator: ModelRoleConfig{
				Default: "qwen3:32b",
				TierMapping: map[string]string{
					"minimal":     "qwen3:8b",
					"balanced":    "qwen3:14b",
					"performance": "qwen3:32b",
				},
			},
			Coder: ModelRoleConfig{
				Default: "qwen2.5-coder:32b",
				TierMapping: map[string]string{
					"minimal":     "deepseek-coder:1.3b",
					"compact":     "deepseek-coder:6.7b",
					"balanced":    "qwen2.5-coder:14b",
					"performance": "qwen2.5-coder:32b",
				},
			},
			Researcher: ModelRoleConfig{
				Default: "command-r:35b",
				TierMapping: map[string]string{
					"minimal":     "command-r:7b",
					"performance": "command-r:35b",
				},
			},
			Vision: ModelRoleConfig{
				Default: "qwen3-vl:32b",
				TierMapping: map[string]string{
					"minimal":     "llava:7b",
					"balanced":    "llava:13b",
					"performance": "qwen3-vl:32b",
				},
			},
		},
		Orchestration: OrchestrationConfig{
			DefaultMode: "orchestration",
			Schedules: []ScheduleConfig{
				{ID: "knowledge", Processes: []string{"research", "crawl", "retrieve"}, Model: "researcher"},
				{ID: "plan", Processes: []string{"brainstorm", "clarify", "plan"}, Model: "coder",
					Consultation: map[string]ConsultationEntry{"clarify": {Type: "optional", Timeout: 60}}},
				{ID: "implement", Processes: []string{"implement", "verify", "feedback"}, Model: "coder",
					Consultation: map[string]ConsultationEntry{"feedback": {Type: "mandatory", Timeout: 300}}},
				{ID: "scale", Processes: []string{"scale", "benchmark", "optimize"}, Model: "coder"},
				{ID: "production", Processes: []string{"analyze", "systemize", "harmonize"}, Model: "coder"},
			},
		},
		Context: ContextConfig{
			MaxTokens: 32768,
			BudgetAllocation: map[string]float64{
				"task":    0.25,
				"files":   0.33,
				"project": 0.16,
				"history": 0.12,
				"memory":  0.12,
				"errors":  0.06,
				"reserve": 0.06,
			},
			Compression: CompressionConfig{
				Enabled:  true,
				Strategy: "semantic_truncate",
				Preserve: []string{"imports", "exports", "signatures", "errors"},
			},
		},
		Quality: QualityConfig{
			Fast:     QualityPreset{Iterations: 1, Verification: "none"},
			Balanced: QualityPreset{Iterations: 2, Verification: "llm_review"},
			Thorough: QualityPreset{Iterations: 3, Verification: "expert_judge"},
		},
		Platforms: PlatformsConfig{
			CLI: CLIPlatformConfig{Verbose: true, MemGraph: true, ColorOutput: true},
			IDE: IDEPlatformConfig{Theme: "dark", FontSize: 14, ShowTokenUsage: true},
		},
		Ollama: OllamaConfig{
			URL:            "http://localhost:11434",
			TimeoutSeconds: 120,
		},
	}
}

// LoadUnifiedConfig loads the unified config from disk.
// Falls back to default if file does not exist.
func LoadUnifiedConfig() (*UnifiedConfig, error) {
	cfgPath := UnifiedConfigPath()

	data, err := os.ReadFile(cfgPath)
	if err != nil {
		if os.IsNotExist(err) {
			return DefaultUnifiedConfig(), nil
		}
		return nil, fmt.Errorf("read unified config: %w", err)
	}

	cfg := DefaultUnifiedConfig()
	if err := yaml.Unmarshal(data, cfg); err != nil {
		return nil, fmt.Errorf("parse unified config: %w", err)
	}

	return cfg, nil
}

// SaveUnifiedConfig writes the unified config to disk.
func SaveUnifiedConfig(cfg *UnifiedConfig) error {
	dir := UnifiedConfigDir()
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("create config dir: %w", err)
	}

	data, err := yaml.Marshal(cfg)
	if err != nil {
		return fmt.Errorf("marshal unified config: %w", err)
	}

	header := []byte("# obot + ollamabot unified configuration\n# https://github.com/croberts/ollamabot\n\n")
	return os.WriteFile(UnifiedConfigPath(), append(header, data...), 0644)
}

// ValidateUnifiedConfig checks required fields.
func ValidateUnifiedConfig(cfg *UnifiedConfig) error {
	if cfg.Version == "" {
		return fmt.Errorf("config version is required")
	}
	if cfg.Ollama.URL == "" {
		return fmt.Errorf("ollama url is required")
	}
	if cfg.Context.MaxTokens <= 0 {
		return fmt.Errorf("context.max_tokens must be positive")
	}
	return nil
}

// GetModelForRole returns the model name for a given role and tier.
func (cfg *UnifiedConfig) GetModelForRole(role, tier string) string {
	var rc ModelRoleConfig
	switch role {
	case "orchestrator":
		rc = cfg.Models.Orchestrator
	case "coder":
		rc = cfg.Models.Coder
	case "researcher":
		rc = cfg.Models.Researcher
	case "vision":
		rc = cfg.Models.Vision
	default:
		return cfg.Models.Coder.Default
	}

	if model, ok := rc.TierMapping[tier]; ok {
		return model
	}
	return rc.Default
}

// GetQualityPreset returns the quality preset by name.
func (cfg *UnifiedConfig) GetQualityPreset(name string) QualityPreset {
	switch name {
	case "fast":
		return cfg.Quality.Fast
	case "thorough":
		return cfg.Quality.Thorough
	default:
		return cfg.Quality.Balanced
	}
}
