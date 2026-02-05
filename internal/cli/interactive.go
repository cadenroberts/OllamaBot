package cli

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/fatih/color"

	"github.com/croberts/obot/internal/analyzer"
	obotcontext "github.com/croberts/obot/internal/context"
	"github.com/croberts/obot/internal/fixer"
	"github.com/croberts/obot/internal/ollama"
	"github.com/croberts/obot/internal/stats"
)

// runInteractiveMode runs the interactive fixing session
func runInteractiveMode(filePath string, startLine, endLine int) error {
	printBanner()

	// Validate file exists
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		return fmt.Errorf("file not found: %s", filePath)
	}

	// Check Ollama connection
	printInfo("Checking Ollama connection...")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	if err := client.CheckConnection(ctx); err != nil {
		cancel()
		return fmt.Errorf("cannot connect to Ollama: %v\nIs Ollama running? Start with: ollama serve", err)
	}
	cancel()

	model := tierManager.GetActiveModel()
	printInfo(fmt.Sprintf("Using model: %s", cyan(model)))

	// Read file context
	fileCtx, err := analyzer.ReadFileContext(filePath, startLine, endLine)
	if err != nil {
		return fmt.Errorf("failed to read file: %v", err)
	}

	quality := fixer.ResolveQuality(qualityPreset)
	var repoSummaryText string
	if quality != fixer.QualityFast {
		summary, err := obotcontext.BuildSummary(filePath, "", obotcontext.DefaultOptions())
		if err == nil && summary != nil {
			repoSummaryText = summary.RenderText()
		}
	}
	agent := fixer.NewAgent(client)

	// Print file info
	fmt.Println()
	fmt.Printf("  %s %s\n", cyan("File:"), filePath)
	fmt.Printf("  %s %s\n", cyan("Language:"), fileCtx.Language.DisplayName())
	if startLine > 0 && endLine > 0 {
		fmt.Printf("  %s %d-%d\n", cyan("Lines:"), startLine, endLine)
	} else {
		fmt.Printf("  %s %d lines\n", cyan("Total:"), len(fileCtx.Lines))
	}
	fmt.Println()

	// Print instructions
	dimColor := color.New(color.FgHiBlack)
	dimColor.Println("  Interactive mode. Commands:")
	dimColor.Println("    <instruction>  - Describe what to fix")
	dimColor.Println("    :show          - Show current code")
	dimColor.Println("    :reload        - Reload file from disk")
	dimColor.Println("    :quit          - Exit interactive mode")
	fmt.Println()

	// Setup signal handling
	ctx, cancel = context.WithCancel(context.Background())
	defer cancel()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		fmt.Println("\n" + yellow("Goodbye!"))
		cancel()
		os.Exit(0)
	}()

	// Interactive loop
	reader := bufio.NewReader(os.Stdin)
	fixCount := 0

	for {
		// Prompt
		fmt.Print(magenta("obot> "))

		// Read input
		input, err := reader.ReadString('\n')
		if err != nil {
			break
		}

		input = strings.TrimSpace(input)
		if input == "" {
			continue
		}

		// Handle commands
		switch {
		case input == ":quit" || input == ":q" || input == ":exit":
			fmt.Println(green("Goodbye!"))
			return nil

		case input == ":show" || input == ":s":
			showCode(fileCtx)
			continue

		case input == ":reload" || input == ":r":
			newCtx, err := analyzer.ReadFileContext(filePath, startLine, endLine)
			if err != nil {
				printError(fmt.Sprintf("Failed to reload: %v", err))
				continue
			}
			fileCtx = newCtx
			printSuccess("File reloaded")
			continue

		case input == ":help" || input == ":h":
			dimColor.Println("  Commands:")
			dimColor.Println("    <instruction>  - Describe what to fix")
			dimColor.Println("    :show          - Show current code")
			dimColor.Println("    :reload        - Reload file from disk")
			dimColor.Println("    :quit          - Exit interactive mode")
			continue

		case strings.HasPrefix(input, ":"):
			printWarning(fmt.Sprintf("Unknown command: %s", input))
			continue
		}

		// Run fix with the instruction
		fmt.Println()
		printInfo("Thinking...")

		startTime := time.Now()

		var resultContent string
		var resultStats *ollama.InferenceStats
		if quality == fixer.QualityFast {
			result, err := client.GenerateStream(ctx, fixer.BuildPrompt(fileCtx, input), func(token string) {
				fmt.Print(token)
			})
			if err != nil {
				if ctx.Err() == context.Canceled {
					return nil
				}
				printError(fmt.Sprintf("Generation failed: %v", err))
				continue
			}
			resultContent = result.Content
			resultStats = result.Stats
		} else {
			agentResult, err := agent.Fix(ctx, fileCtx, input, fixer.AgentOptions{
				Quality:     quality,
				RepoSummary: repoSummaryText,
			}, func(token string) {
				fmt.Print(token)
			})
			if err != nil {
				if ctx.Err() == context.Canceled {
					return nil
				}
				printError(fmt.Sprintf("Generation failed: %v", err))
				continue
			}
			resultContent = agentResult.FixedCode
			if len(agentResult.Stats) > 0 {
				resultStats = fixer.AggregateStats(agentResult.Stats)
			}
		}

		fmt.Println()
		elapsed := time.Since(startTime)

		// Extract and apply fix
		fixedCode := fixer.ExtractCode(resultContent, fileCtx.Language)

		if fixedCode == "" {
			printWarning("No code changes detected")
			continue
		}

		qualityReport := fixer.QuickReview(fileCtx.GetTargetLines(), fixedCode, fileCtx.Language)
		if len(qualityReport.Warnings) > 0 {
			printWarning(fmt.Sprintf("Internal review: %s", qualityReport.Summary(2)))
		}

		// Ask for confirmation
		fmt.Println()
		fmt.Print(yellow("Apply this fix? [y/N] "))
		confirm, _ := reader.ReadString('\n')
		confirm = strings.TrimSpace(strings.ToLower(confirm))

		if confirm == "y" || confirm == "yes" {
			if err := fileCtx.ApplyFix(fixedCode); err != nil {
				printError(fmt.Sprintf("Failed to apply fix: %v", err))
				continue
			}

			fixCount++
			printSuccess(fmt.Sprintf("Fix applied (%d total)", fixCount))

			// Track stats
			if resultStats != nil {
				tracker := stats.GetTracker()
				tracker.RecordInference(
					resultStats.PromptTokens,
					resultStats.CompletionTokens,
					elapsed,
				)
				tracker.RecordFileFix()
				tracker.Save()
			}

			// Reload file context
			fileCtx, _ = analyzer.ReadFileContext(filePath, startLine, endLine)
		} else {
			printInfo("Fix discarded")
		}

		fmt.Println()
	}

	return nil
}

// showCode displays the current code with line numbers
func showCode(fc *analyzer.FileContext) {
	fmt.Println()
	fmt.Println(strings.Repeat("─", 50))

	lines := fc.Lines
	start := 0
	end := len(lines)

	if fc.StartLine > 0 {
		start = fc.StartLine - 1
	}
	if fc.EndLine > 0 && fc.EndLine < end {
		end = fc.EndLine
	}

	for i := start; i < end; i++ {
		lineNum := i + 1
		line := lines[i]

		// Highlight the line number
		numStr := fmt.Sprintf("%4d", lineNum)
		fmt.Printf("%s │ %s\n", color.HiBlackString(numStr), line)
	}

	fmt.Println(strings.Repeat("─", 50))
	fmt.Println()
}
