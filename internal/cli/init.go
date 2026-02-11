package cli

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/croberts/obot/internal/config"
)

var initCmd = &cobra.Command{
	Use:   "init",
	Short: "Scaffold a new OllamaBot project",
	Long:  `Initializes the current directory with OllamaBot configuration and rules templates.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		printInfo("Initializing OllamaBot project...")

		// 1. Ensure global config exists
		if err := config.EnsureConfigDir(); err != nil {
			return fmt.Errorf("failed to ensure config dir: %w", err)
		}

		// 2. Create .obot directory
		obotDir := ".obot"
		if err := os.MkdirAll(obotDir, 0755); err != nil {
			return fmt.Errorf("failed to create .obot directory: %w", err)
		}
		printSuccess("Created .obot/ directory")

		// 3. Create .obotrules template
		rulesPath := filepath.Join(obotDir, "rules.obotrules")
		if _, err := os.Stat(rulesPath); os.IsNotExist(err) {
			rulesTemplate := `## System Rules
- Adhere to the project's established coding style.
- Prefer explicit over implicit.
- Ensure all new code is accompanied by unit tests.

## File-Specific Rules
- **Sources/Agent/*.swift**: Use async/await for all asynchronous operations.
- **internal/agent/*.go**: Ensure all tools route through executeAction.

## Global Rules
- Language: English
- Tone: Professional, concise
`
			if err := os.WriteFile(rulesPath, []byte(rulesTemplate), 0644); err != nil {
				return fmt.Errorf("failed to create .obotrules: %w", err)
			}
			printSuccess("Created .obot/rules.obotrules template")
		} else {
			printInfo(".obot/rules.obotrules already exists, skipping")
		}

		// 4. Create cache and session paths
		cacheDir := filepath.Join(obotDir, "cache")
		if err := os.MkdirAll(cacheDir, 0755); err != nil {
			return fmt.Errorf("failed to create cache directory: %w", err)
		}
		printSuccess("Created .obot/cache/ directory")

		fmt.Println()
		printSuccess("OllamaBot initialized successfully!")
		printInfo("Edit .obot/rules.obotrules to customize agent behavior.")

		return nil
	},
}

func init() {
	rootCmd.AddCommand(initCmd)
}
