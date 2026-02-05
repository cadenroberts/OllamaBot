package cli

import (
	"fmt"
	"os"

	"github.com/fatih/color"
	"github.com/spf13/cobra"

	"github.com/croberts/obot/internal/config"
	"github.com/croberts/obot/internal/ollama"
	"github.com/croberts/obot/internal/tier"
)

var (
	// Version is set at build time
	version = "dev"

	// Global flags
	verbose     bool
	modelFlag   string
	ollamaURL   string
	interactive bool
	qualityPreset string
	dryRun          bool
	printFixed      bool
	showDiff        bool
	diffContext     int
	noSummary       bool
	memGraphEnabled bool
	temperatureFlag float64
	maxTokensFlag   int
	contextWindowFlag int

	// Global instances
	cfg         *config.Config
	tierManager *tier.Manager
	client      *ollama.Client

)

// SetVersion sets the version string
func SetVersion(v string) {
	version = v
}

// rootCmd represents the base command
var rootCmd = &cobra.Command{
	Use:   "obot [file] [-start +end] [instruction]",
	Short: "Local AI-powered code fixer",
	Long: `obot - Concentrate local AI power for quick code fixes

Uses your local GPU via Ollama to fix code issues without cloud APIs.
Auto-detects your system RAM to select the optimal model.

Examples:
  obot main.go                    # Fix entire file
  obot main.go -10 +25            # Fix lines 10-25
  obot main.go "fix null check"   # Fix with instruction
  obot main.go -i                 # Interactive mode
  obot --saved                    # View cost savings`,
	Version:               version,
	Args:                  cobra.ArbitraryArgs,
	DisableFlagsInUseLine: true,
	SilenceErrors:         true,
	SilenceUsage:          true,
	PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
		// Skip setup for version/help/completion commands
		if cmd.Name() == "help" || cmd.Name() == "completion" {
			return nil
		}
		if cmd.Flags().Changed("version") {
			return nil
		}
		if shouldSkipSetup(cmd) {
			return nil
		}

		// Load configuration
		var err error
		cfg, err = config.Load()
		if err != nil {
			// Config doesn't exist yet, use defaults
			cfg = config.Default()
		}

		// Initialize tier manager
		tierManager = tier.NewManager()

		// Apply CLI overrides
		if modelFlag != "" {
			tierManager.SetModelOverride(modelFlag)
		}

		// Determine Ollama URL
		url := ollama.DefaultBaseURL
		if ollamaURL != "" {
			url = ollamaURL
		} else if cfg.OllamaURL != "" {
			url = cfg.OllamaURL
		}

		// Create Ollama client
		client = ollama.NewClient(
			ollama.WithBaseURL(url),
			ollama.WithModel(tierManager.GetActiveModel()),
		)

		// Configure generation options
		contextWindow := tierManager.GetContextWindow()
		if cmd.Flags().Changed("context-window") && contextWindowFlag > 0 {
			contextWindow = contextWindowFlag
		}
		client.SetContextWindow(contextWindow)

		temperature := cfg.Temperature
		if cmd.Flags().Changed("temperature") {
			temperature = temperatureFlag
		}
		if temperature < 0 {
			temperature = 0.3
		}
		client.SetTemperature(temperature)

		maxTokens := cfg.MaxTokens
		if cmd.Flags().Changed("max-tokens") {
			maxTokens = maxTokensFlag
		}
		if maxTokens <= 0 {
			maxTokens = 4096
		}
		client.SetMaxTokens(maxTokens)

		return nil
	},
	RunE: func(cmd *cobra.Command, args []string) error {
		// If no args, show help
		if len(args) == 0 {
			return cmd.Help()
		}

		// Otherwise, run the fix command
		err := runFix(cmd, args)
		if err != nil {
			printError(err.Error())
			return err
		}
		return nil
	},
}

// Execute runs the root command
func Execute() error {
	return rootCmd.Execute()
}

func init() {
	// Global flags
	rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", true, "Show detailed output")
	rootCmd.PersistentFlags().StringVarP(&modelFlag, "model", "m", "", "Override model (e.g., qwen2.5-coder:14b)")
	rootCmd.PersistentFlags().StringVar(&ollamaURL, "ollama-url", "", "Ollama server URL")
	rootCmd.PersistentFlags().BoolVarP(&interactive, "interactive", "i", false, "Interactive mode")
	rootCmd.PersistentFlags().StringVar(&qualityPreset, "quality", "balanced", "Generation quality preset: fast|balanced|thorough")
	rootCmd.PersistentFlags().BoolVar(&memGraphEnabled, "mem-graph", true, "Show live memory usage graph")
	rootCmd.PersistentFlags().BoolVar(&noSummary, "no-summary", false, "Disable actions summary")

	rootCmd.Flags().BoolVar(&dryRun, "dry-run", false, "Do not write changes to disk")
	rootCmd.Flags().BoolVar(&printFixed, "print", false, "Print fixed code to stdout")
	rootCmd.Flags().BoolVar(&showDiff, "diff", false, "Show unified diff before applying changes")
	rootCmd.Flags().IntVar(&diffContext, "diff-context", 3, "Context lines for unified diff")
	rootCmd.Flags().Float64Var(&temperatureFlag, "temperature", -1, "Override model temperature")
	rootCmd.Flags().IntVar(&maxTokensFlag, "max-tokens", 0, "Override max tokens to generate")
	rootCmd.Flags().IntVar(&contextWindowFlag, "context-window", 0, "Override context window size")

	// Add subcommands
	rootCmd.AddCommand(statsCmd)
	rootCmd.AddCommand(configCmd)
	rootCmd.AddCommand(modelsCmd)
	rootCmd.AddCommand(planCmd)
	rootCmd.AddCommand(reviewCmd)
	rootCmd.AddCommand(versionCmd)
	rootCmd.AddCommand(fsCmd)

	// Custom version template
	rootCmd.SetVersionTemplate(fmt.Sprintf(`%s version {{.Version}}
`, cyan("obot")))
}

func shouldSkipSetup(cmd *cobra.Command) bool {
	for current := cmd; current != nil; current = current.Parent() {
		switch current.Name() {
		case "plan", "review", "version", "fs":
			return true
		}
	}
	return false
}

// printBanner prints the obot banner
func printBanner() {
	if !verbose {
		return
	}
	fmt.Println()
	fmt.Printf("  %s %s\n", cyan("obot"), magenta("v"+version))
	fmt.Printf("  %s\n", color.HiBlackString("Local AI code fixer"))
	fmt.Println()
}

// printError prints an error message
func printError(msg string) {
	fmt.Fprintf(os.Stderr, "%s %s\n", red("Error:"), msg)
}

// printSuccess prints a success message
func printSuccess(msg string) {
	fmt.Printf("%s %s\n", green("✓"), msg)
}

// printInfo prints an info message
func printInfo(msg string) {
	if verbose {
		fmt.Printf("%s %s\n", cyan("→"), msg)
	}
}

// printWarning prints a warning message
func printWarning(msg string) {
	fmt.Printf("%s %s\n", yellow("⚠"), msg)
}
