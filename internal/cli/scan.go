package cli

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/spf13/cobra"
)

var scanCmd = &cobra.Command{
	Use:   "scan",
	Short: "Run a health scan on the current project",
	Long:  `Performs a comprehensive health check of the OllamaBot environment, including configuration, model availability, and resource limits.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		printBanner()
		printInfo("Starting project health scan...")
		fmt.Println()

		// 1. Check Configuration
		fmt.Printf("%-30s", "Configuration:")
		if cfg != nil {
			printSuccess("Loaded")
		} else {
			printError("Not found")
		}

		// 2. Check Ollama Connection
		fmt.Printf("%-30s", "Ollama Connection:")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := client.CheckConnection(ctx); err != nil {
			printError(fmt.Sprintf("Failed (%v)", err))
		} else {
			printSuccess(fmt.Sprintf("Connected (%s)", client.BaseURL()))
		}

		// 3. Check Active Model
		model := tierManager.GetActiveModel()
		fmt.Printf("%-30s", "Active Model:")
		hasModel, err := client.HasModel(ctx, model)
		if err != nil {
			printWarning("Unknown")
		} else if !hasModel {
			printError(fmt.Sprintf("Not found (%s)", model))
		} else {
			printSuccess(fmt.Sprintf("Available (%s)", model))
		}

		// 4. Check System Resources
		fmt.Printf("%-30s", "System RAM:")
		printInfo(fmt.Sprintf("%d GB (Tier: %s)", tierManager.SystemInfo.RAMGB, tierManager.SelectedTier.DisplayName()))

		// 5. Check Context Window
		fmt.Printf("%-30s", "Context Window:")
		printInfo(fmt.Sprintf("%d tokens", tierManager.GetContextWindow()))

		// 6. Check for .obot directory
		fmt.Printf("%-30s", "Project Init:")
		if _, err := os.Stat(".obot"); err == nil {
			printSuccess("Initialized")
		} else {
			printWarning("Not initialized (run 'obot init')")
		}

		fmt.Println()
		printSuccess("Scan complete!")
		return nil
	},
}

func init() {
	rootCmd.AddCommand(scanCmd)
}
