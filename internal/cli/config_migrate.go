package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/croberts/obot/internal/config"
)

var configMigrateCmd = &cobra.Command{
	Use:   "migrate",
	Short: "Migrate config from JSON to unified YAML",
	Long: `Migrate old ~/.config/obot/config.json to the unified YAML format
at ~/.config/ollamabot/config.yaml. Creates a backward-compat symlink.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		printInfo("Checking for old configuration...")

		migrated, err := config.MigrateFromJSON()
		if err != nil {
			return fmt.Errorf("migration failed: %w", err)
		}

		if !migrated {
			printInfo("No old configuration found. Nothing to migrate.")

			// Ensure the unified config dir exists with defaults
			if err := config.EnsureUnifiedConfigDir(); err != nil {
				return fmt.Errorf("create config dir: %w", err)
			}

			ucfg := config.DefaultUnifiedConfig()
			if err := config.SaveUnifiedConfig(ucfg); err != nil {
				return fmt.Errorf("save default config: %w", err)
			}

			printSuccess("Created default config at " + config.UnifiedConfigPath())
			return nil
		}

		// Ensure backward compat symlink
		if err := config.EnsureBackwardCompatSymlink(); err != nil {
			printWarning(fmt.Sprintf("Could not create backward-compat symlink: %v", err))
		}

		printSuccess("Configuration migrated to " + config.UnifiedConfigPath())
		printInfo("Backward-compat symlink created: ~/.config/obot -> ~/.config/ollamabot")
		return nil
	},
}

var configShowUnifiedCmd = &cobra.Command{
	Use:   "unified",
	Short: "Show unified configuration",
	RunE: func(cmd *cobra.Command, args []string) error {
		ucfg, err := config.LoadUnifiedConfig()
		if err != nil {
			return fmt.Errorf("load unified config: %w", err)
		}

		fmt.Printf("\n%s Unified Configuration (v%s)\n\n", cyan("⚙"), ucfg.Version)
		fmt.Printf("  %s Config: %s\n", cyan("📁"), config.UnifiedConfigPath())
		fmt.Println()

		// Models
		fmt.Printf("  %s Models\n", cyan("🤖"))
		fmt.Printf("    Orchestrator: %s\n", green(ucfg.Models.Orchestrator.Default))
		fmt.Printf("    Coder:        %s\n", green(ucfg.Models.Coder.Default))
		fmt.Printf("    Researcher:   %s\n", green(ucfg.Models.Researcher.Default))
		fmt.Printf("    Vision:       %s\n", green(ucfg.Models.Vision.Default))
		fmt.Println()

		// Context
		fmt.Printf("  %s Context\n", cyan("📊"))
		fmt.Printf("    Max Tokens:   %d\n", ucfg.Context.MaxTokens)
		fmt.Printf("    Compression:  %s (%v)\n", ucfg.Context.Compression.Strategy, ucfg.Context.Compression.Enabled)
		fmt.Println()

		// Quality
		fmt.Printf("  %s Quality Presets\n", cyan("⚡"))
		fmt.Printf("    Fast:     %d iterations, %s\n", ucfg.Quality.Fast.Iterations, ucfg.Quality.Fast.Verification)
		fmt.Printf("    Balanced: %d iterations, %s\n", ucfg.Quality.Balanced.Iterations, ucfg.Quality.Balanced.Verification)
		fmt.Printf("    Thorough: %d iterations, %s\n", ucfg.Quality.Thorough.Iterations, ucfg.Quality.Thorough.Verification)
		fmt.Println()

		// Orchestration
		fmt.Printf("  %s Orchestration\n", cyan("🔄"))
		fmt.Printf("    Mode: %s\n", ucfg.Orchestration.DefaultMode)
		fmt.Printf("    Schedules: %d\n", len(ucfg.Orchestration.Schedules))
		for _, s := range ucfg.Orchestration.Schedules {
			fmt.Printf("      %s: %v (model: %s)\n", s.ID, s.Processes, s.Model)
		}
		fmt.Println()

		// Ollama
		fmt.Printf("  %s Ollama\n", cyan("🦙"))
		fmt.Printf("    URL:     %s\n", ucfg.Ollama.URL)
		fmt.Printf("    Timeout: %ds\n", ucfg.Ollama.TimeoutSeconds)
		fmt.Println()

		return nil
	},
}
