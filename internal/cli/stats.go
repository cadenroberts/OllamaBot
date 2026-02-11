package cli

import (
	"fmt"
	"strings"
	"time"

	"github.com/fatih/color"
	"github.com/spf13/cobra"

	"github.com/croberts/obot/internal/stats"
	"github.com/croberts/obot/internal/telemetry"
)

// statsCmd shows cost savings statistics
var statsCmd = &cobra.Command{
	Use:     "stats",
	Aliases: []string{"saved", "savings"},
	Short:   "Show cost savings vs commercial APIs",
	Long: `Display your cost savings from using local AI instead of cloud APIs.

Shows tokens used, files fixed, and money saved vs:
  - Claude Opus 4.5
  - Claude Sonnet 3.5
  - GPT-4o`,
	RunE: runStats,
}

var statsResetFlag bool

var statsResetCmd = &cobra.Command{
	Use:   "reset",
	Short: "Reset all statistics and telemetry data",
	RunE: func(cmd *cobra.Command, args []string) error {
		return performStatsReset()
	},
}

func performStatsReset() error {
	tracker := stats.GetTracker()
	tracker.Reset()
	if err := tracker.Save(); err != nil {
		return fmt.Errorf("failed to reset stats: %w", err)
	}

	// Also reset telemetry
	telService := telemetry.NewService()
	if err := telService.Reset(); err != nil {
		return fmt.Errorf("failed to reset telemetry: %w", err)
	}

	fmt.Printf("%s All statistics and telemetry data have been reset.\n", green("✔"))
	return nil
}

func init() {
	statsCmd.AddCommand(statsResetCmd)
	statsCmd.Flags().BoolVar(&statsResetFlag, "reset", false, "Reset all statistics and telemetry data")
}

func runStats(cmd *cobra.Command, args []string) error {
	if statsResetFlag {
		return performStatsReset()
	}
	tracker := stats.GetTracker()
	summary := tracker.GetSummary()

	// Build the box
	width := 55
	borderColor := primaryColor
	titleColor := primaryBoldColor
	valueColor := color.New(color.FgGreen)
	labelColor := color.New(color.FgWhite)
	dimColor := color.New(color.FgHiBlack)

	// Top border
	borderColor.Println("╭" + strings.Repeat("─", width-2) + "╮")

	// Title
	title := "obot savings report"
	padding := (width - 2 - len(title)) / 2
	borderColor.Print("│")
	fmt.Print(strings.Repeat(" ", padding))
	titleColor.Print(title)
	fmt.Print(strings.Repeat(" ", width-2-padding-len(title)))
	borderColor.Println("│")

	// Separator
	borderColor.Println("├" + strings.Repeat("─", width-2) + "┤")

	// Usage stats
	printStatLine(borderColor, labelColor, valueColor, "Total tokens:", formatNumber(summary.TotalTokens), width)
	printStatLine(borderColor, labelColor, valueColor, "Files fixed:", formatNumber(summary.FilesFixes), width)
	printStatLine(borderColor, labelColor, valueColor, "Sessions:", formatNumber(summary.Sessions), width)

	// Time range
	if !summary.FirstUse.IsZero() {
		duration := time.Since(summary.FirstUse)
		daysUsed := int(duration.Hours() / 24)
		if daysUsed < 1 {
			daysUsed = 1
		}
		printStatLine(borderColor, labelColor, dimColor, "Days using obot:", fmt.Sprintf("%d", daysUsed), width)
	}

	// Empty line
	borderColor.Print("│")
	fmt.Print(strings.Repeat(" ", width-2))
	borderColor.Println("│")

	// Cost savings header
	borderColor.Print("│  ")
	primaryColor.Print("💰 Cost Savings vs Commercial APIs:")
	fmt.Print(strings.Repeat(" ", width-2-38))
	borderColor.Println("│")

	// Divider
	borderColor.Print("│  ")
	dimColor.Print(strings.Repeat("─", 37))
	fmt.Print(strings.Repeat(" ", width-2-39))
	borderColor.Println("│")

	// Savings by provider
	savingsColor := color.New(color.FgGreen, color.Bold)
	printSavingsLine(borderColor, labelColor, savingsColor, "Claude Opus 4.5:", summary.ClaudeOpusSavings, width)
	printSavingsLine(borderColor, labelColor, valueColor, "Claude Sonnet 3.5:", summary.ClaudeSonnetSavings, width)
	printSavingsLine(borderColor, labelColor, valueColor, "GPT-4o:", summary.GPT4oSavings, width)

	// Empty line
	borderColor.Print("│")
	fmt.Print(strings.Repeat(" ", width-2))
	borderColor.Println("│")

	// Projections
	if summary.MonthlyProjection > 0 {
		borderColor.Print("│  ")
		primaryColor.Print("📈 ")
		labelColor.Print("Monthly projection: ")
		savingsColor.Print(formatCurrency(summary.MonthlyProjection))
		dimColor.Print(" (Opus rate)")
		remaining := width - 2 - 4 - 20 - len(formatCurrency(summary.MonthlyProjection)) - 12
		if remaining > 0 {
			fmt.Print(strings.Repeat(" ", remaining))
		}
		borderColor.Println("│")
	}

	// Data privacy
	dataKB := float64(summary.TotalTokens*4) / 1024.0
	borderColor.Print("│  ")
	primaryColor.Print("🔒 ")
	labelColor.Print("Data kept local: ")
	valueColor.Print(fmt.Sprintf("%.1f KB", dataKB))
	remaining := width - 2 - 4 - 17 - len(fmt.Sprintf("%.1f KB", dataKB))
	if remaining > 0 {
		fmt.Print(strings.Repeat(" ", remaining))
	}
	borderColor.Println("│")

	// Bottom border
	borderColor.Println("╰" + strings.Repeat("─", width-2) + "╯")

	// Footer note
	fmt.Println()
	dimColor.Println("  Savings calculated based on token usage at current API prices.")
	dimColor.Println("  All inference runs locally - your code never leaves your machine.")

	return nil
}

func printStatLine(border, label, value *color.Color, labelText string, valueText string, width int) {
	border.Print("│  ")
	label.Print(labelText)
	spacing := 25 - len(labelText)
	if spacing < 1 {
		spacing = 1
	}
	fmt.Print(strings.Repeat(" ", spacing))
	value.Print(valueText)
	remaining := width - 2 - 2 - len(labelText) - spacing - len(valueText)
	if remaining > 0 {
		fmt.Print(strings.Repeat(" ", remaining))
	}
	border.Println("│")
}

func printSavingsLine(border, label, value *color.Color, labelText string, amount float64, width int) {
	border.Print("│  ")
	label.Print(labelText)
	spacing := 20 - len(labelText)
	if spacing < 1 {
		spacing = 1
	}
	fmt.Print(strings.Repeat(" ", spacing))
	valueStr := formatCurrency(amount) + " saved"
	value.Print(valueStr)
	remaining := width - 2 - 2 - len(labelText) - spacing - len(valueStr)
	if remaining > 0 {
		fmt.Print(strings.Repeat(" ", remaining))
	}
	border.Println("│")
}

func formatNumber(n int) string {
	if n < 1000 {
		return fmt.Sprintf("%d", n)
	}
	if n < 1000000 {
		return fmt.Sprintf("%d,%03d", n/1000, n%1000)
	}
	return fmt.Sprintf("%d,%03d,%03d", n/1000000, (n/1000)%1000, n%1000)
}

func formatCurrency(amount float64) string {
	return fmt.Sprintf("$%.2f", amount)
}

func init() {
	statsCmd.AddCommand(statsResetCmd)
}

// configCmd shows current configuration
var configCmd = &cobra.Command{
	Use:   "config",
	Short: "Show current configuration",
	RunE: func(cmd *cobra.Command, args []string) error {
		printBanner()

		// Show system info
		fmt.Printf("%s System\n", cyan("⚙"))
		fmt.Printf("  RAM: %s\n", green(fmt.Sprintf("%dGB", tierManager.SystemInfo.RAMGB)))
		fmt.Printf("  OS:  %s/%s\n", tierManager.SystemInfo.OS, tierManager.SystemInfo.Arch)
		fmt.Printf("  CPUs: %d\n", tierManager.SystemInfo.NumCPU)
		fmt.Println()

		// Show model info
		fmt.Printf("%s Model Configuration\n", cyan("🤖"))
		fmt.Printf("  Tier: %s\n", yellow(tierManager.SelectedTier.DisplayName()))
		fmt.Printf("  Model: %s\n", green(tierManager.GetActiveModel()))
		fmt.Printf("  Context: %d tokens\n", tierManager.GetContextWindow())
		fmt.Println()

		// Show config file location
		configPath := cfg.Path()
		fmt.Printf("%s Config file: %s\n", cyan("📁"), configPath)

		return nil
	},
}

// modelsCmd lists available models
var modelsCmd = &cobra.Command{
	Use:   "models",
	Short: "List available Ollama models",
	RunE: func(cmd *cobra.Command, args []string) error {
		printInfo("Fetching models from Ollama...")

		models, err := client.ListModels(cmd.Context())
		if err != nil {
			return fmt.Errorf("failed to list models: %v", err)
		}

		fmt.Println()
		fmt.Printf("%s Available Models:\n", cyan("📦"))
		fmt.Println()

		for _, m := range models {
			// Highlight if it's a coder model
			name := m.Name
			if strings.Contains(name, "coder") || strings.Contains(name, "code") {
				name = green(name) + " " + yellow("(coder)")
			}

			sizeGB := float64(m.Size) / 1024 / 1024 / 1024
			fmt.Printf("  • %s (%.1f GB)\n", name, sizeGB)
		}

		fmt.Println()
		fmt.Printf("  Current: %s\n", cyan(tierManager.GetActiveModel()))

		return nil
	},
}
