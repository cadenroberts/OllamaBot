package cli

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/fatih/color"
	"github.com/spf13/cobra"

	"github.com/croberts/obot/internal/analyzer"
	obotcontext "github.com/croberts/obot/internal/context"
	"github.com/croberts/obot/internal/fixer"
	"github.com/croberts/obot/internal/stats"
)

// runFix is the main fix command logic
func runFix(cmd *cobra.Command, args []string) error {
	printBanner()
	session := startSession()
	defer session.Close()

	// Parse arguments: file [-start] [+end] ["instruction"]
	filePath, startLine, endLine, instruction, err := parseFixArgs(args)
	if err != nil {
		return err
	}

	session.Add("Parsed fix arguments", map[string]string{
		"file":        filePath,
		"start_line":  fmt.Sprintf("%d", startLine),
		"end_line":    fmt.Sprintf("%d", endLine),
		"instruction": instruction,
	})

	// Check if interactive mode
	if interactive {
		session.Add("Interactive mode requested", map[string]string{
			"file": filePath,
		})
		return runInteractiveMode(filePath, startLine, endLine)
	}

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
	session.Add("Checked Ollama connection", map[string]string{
		"url": client.BaseURL(),
	})

	// Check if model is available
	model := tierManager.GetActiveModel()
	printInfo(fmt.Sprintf("Using model: %s", cyan(model)))
	session.Add("Selected model", map[string]string{
		"model":          model,
		"tier":           tierManager.SelectedTier.DisplayName(),
		"ram_gb":         fmt.Sprintf("%d", tierManager.SystemInfo.RAMGB),
		"context_window": fmt.Sprintf("%d", tierManager.GetContextWindow()),
	})

	ctx, cancel = context.WithTimeout(context.Background(), 5*time.Second)
	hasModel, err := client.HasModel(ctx, model)
	cancel()
	if err != nil {
		printWarning(fmt.Sprintf("Could not verify model: %v", err))
	} else if !hasModel {
		return fmt.Errorf("model %s not found\nInstall with: ollama pull %s", model, model)
	}
	session.Add("Verified model availability", map[string]string{
		"model":     model,
		"available": fmt.Sprintf("%t", hasModel),
	})

	// Read file context
	printInfo(fmt.Sprintf("Reading %s...", filePath))
	fileCtx, err := analyzer.ReadFileContext(filePath, startLine, endLine)
	if err != nil {
		return fmt.Errorf("failed to read file: %v", err)
	}
	session.Add("Read file context", map[string]string{
		"file":     filePath,
		"language": fileCtx.Language.DisplayName(),
		"lines":    fmt.Sprintf("%d", len(fileCtx.Lines)),
	})

	quality := fixer.ResolveQuality(qualityPreset)
	session.Add("Selected quality preset", map[string]string{
		"quality": string(quality),
	})

	var repoSummaryText string
	if quality != fixer.QualityFast {
		summary, err := obotcontext.BuildSummary(filePath, instruction, obotcontext.DefaultOptions())
		if err == nil && summary != nil {
			repoSummaryText = summary.RenderText()
			session.Add("Built repo context summary", map[string]string{
				"files":       fmt.Sprintf("%d", summary.TotalFiles),
				"languages":   fmt.Sprintf("%d", len(summary.Languages)),
				"plan_tasks":  fmt.Sprintf("%d", len(summary.PlanTasks)),
				"todo_files":  fmt.Sprintf("%d", len(summary.TodoFiles)),
				"siblings":    fmt.Sprintf("%d", len(summary.SiblingFiles)),
			})
		} else if err != nil {
			session.Add("Repo context summary failed", map[string]string{
				"error": err.Error(),
			})
		}
	}

	// Show what we're fixing
	if startLine > 0 && endLine > 0 {
		printInfo(fmt.Sprintf("Fixing lines %d-%d (%s)", startLine, endLine, fileCtx.Language))
	} else {
		printInfo(fmt.Sprintf("Fixing entire file (%d lines, %s)", len(fileCtx.Lines), fileCtx.Language))
	}

	// Setup signal handling for graceful cancellation
	ctx, cancel = context.WithCancel(context.Background())
	defer cancel()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		fmt.Println("\n" + yellow("Cancelled"))
		cancel()
	}()

	// Run inference with streaming
	fmt.Println()
	if verbose {
		fmt.Printf("%s %s\n", cyan("Model thinking..."), color.HiBlackString("(Ctrl+C to cancel)"))
		fmt.Println(strings.Repeat("─", 50))
	}

	session.StartMemoryGraph()
	agent := fixer.NewAgent(client)

	result, err := agent.Fix(ctx, fileCtx, instruction, fixer.AgentOptions{
		Quality:     quality,
		RepoSummary: repoSummaryText,
	}, func(token string) {
		if verbose {
			fmt.Print(token)
		}
	})

	session.StopMemoryGraph()

	if err != nil {
		if ctx.Err() == context.Canceled {
			return nil
		}
		return fmt.Errorf("generation failed: %v", err)
	}

	if verbose {
		fmt.Println()
		fmt.Println(strings.Repeat("─", 50))
	}

	if result.Plan != "" {
		session.Add("Generated plan", map[string]string{
			"steps": fmt.Sprintf("%d", countPlanSteps(result.Plan)),
		})
	}
	if result.ReviewNotes != "" {
		status := "issues"
		if result.ReviewOK {
			status = "ok"
		}
		session.Add("Reviewer verdict", map[string]string{
			"status":     status,
			"iterations": fmt.Sprintf("%d", result.Iterations),
		})
	}

	// Extract the fixed code from the response
	fixedCode := result.FixedCode

	qualityReport := fixer.QuickReview(fileCtx.GetTargetLines(), fixedCode, fileCtx.Language)
	session.Add("Internal quality review", mergeFacts(qualityReport.Metrics, map[string]string{
		"warnings": fmt.Sprintf("%d", len(qualityReport.Warnings)),
	}))
	if len(qualityReport.Warnings) > 0 {
		printWarning(fmt.Sprintf("Internal review flagged: %s", qualityReport.Summary(2)))
	}

	if fixedCode == "" {
		printWarning("No code changes detected in model response")
		return nil
	}

	originalCode := fileCtx.GetTargetLines()
	if showDiff {
		diff := fixer.UnifiedDiff(originalCode, fixedCode, fileCtx.FileName(), diffContext)
		if diff == "" {
			printInfo("No diff to display")
		} else {
			fmt.Println(diff)
		}
		session.Add("Rendered diff", map[string]string{
			"context": fmt.Sprintf("%d", diffContext),
		})
	}
	if printFixed {
		fmt.Println(fixedCode)
		session.Add("Printed fixed code", map[string]string{
			"lines": fmt.Sprintf("%d", countLines(fixedCode)),
		})
	}

	if dryRun {
		printInfo("Dry run enabled: no changes applied")
		session.Add("Dry run", map[string]string{
			"file": filePath,
		})
		recordStats(result, session, false)
		return nil
	}

	// Apply the fix
	printInfo("Applying fix...")
	if err := fileCtx.ApplyFix(fixedCode); err != nil {
		return fmt.Errorf("failed to apply fix: %v", err)
	}
	session.Add("Applied fix", map[string]string{
		"file":  filePath,
		"lines": fmt.Sprintf("%d", fileCtx.LineCount()),
	})

	// Track stats
	recordStats(result, session, true)

	// Print summary
	fmt.Println()
	printSuccess(fmt.Sprintf("Fixed %s", filePath))

	if verbose {
		aggregate := fixer.AggregateStats(result.Stats)
		if aggregate != nil {
		fmt.Printf("   %s %d input + %d output tokens\n",
			color.HiBlackString("Tokens:"),
			aggregate.PromptTokens,
			aggregate.CompletionTokens,
		)
		fmt.Printf("   %s %.1f tokens/sec\n",
			color.HiBlackString("Speed:"),
			aggregate.TokensPerSecond,
		)
		fmt.Printf("   %s %s\n",
			color.HiBlackString("Time:"),
			result.Duration.Round(time.Millisecond),
		)
		}
	}

	return nil
}

// parseFixArgs parses the fix command arguments
// Format: file [-start] [+end] ["instruction"]
func parseFixArgs(args []string) (file string, start, end int, instruction string, err error) {
	if len(args) == 0 {
		return "", 0, 0, "", fmt.Errorf("file path required")
	}

	file = args[0]

	// Parse remaining args
	lineRe := regexp.MustCompile(`^([+-])(\d+)$`)

	for i := 1; i < len(args); i++ {
		arg := args[i]

		// Check for line specifiers
		if matches := lineRe.FindStringSubmatch(arg); matches != nil {
			num, _ := strconv.Atoi(matches[2])
			if matches[1] == "-" {
				start = num
			} else {
				end = num
			}
			continue
		}

		// Check for quoted instruction (or unquoted text)
		// Accumulate remaining args as instruction
		instruction = strings.Join(args[i:], " ")
		// Remove surrounding quotes if present
		instruction = strings.Trim(instruction, "\"'")
		break
	}

	// Validate line range
	if start > 0 && end > 0 && start > end {
		return "", 0, 0, "", fmt.Errorf("start line (%d) cannot be greater than end line (%d)", start, end)
	}

	return file, start, end, instruction, nil
}

func countPlanSteps(plan string) int {
	lines := strings.Split(plan, "\n")
	count := 0
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" {
			continue
		}
		if strings.HasPrefix(trimmed, "-") || strings.HasPrefix(trimmed, "*") {
			count++
			continue
		}
		if len(trimmed) > 1 && trimmed[0] >= '0' && trimmed[0] <= '9' && strings.Contains(trimmed, ".") {
			count++
		}
	}
	if count == 0 && strings.TrimSpace(plan) != "" {
		return 1
	}
	return count
}

func mergeFacts(primary map[string]string, extra map[string]string) map[string]string {
	if len(primary) == 0 && len(extra) == 0 {
		return nil
	}
	merged := make(map[string]string, len(primary)+len(extra))
	for key, value := range primary {
		merged[key] = value
	}
	for key, value := range extra {
		merged[key] = value
	}
	return merged
}

func recordStats(result *fixer.AgentResult, session *session, applied bool) {
	if result == nil || len(result.Stats) == 0 {
		return
	}
	tracker := stats.GetTracker()
	for _, stat := range result.Stats {
		if stat == nil {
			continue
		}
		tracker.RecordInference(
			stat.PromptTokens,
			stat.CompletionTokens,
			time.Duration(stat.TotalDuration),
		)
	}
	if applied {
		tracker.RecordFileFix()
	}
	tracker.Save()

	aggregate := fixer.AggregateStats(result.Stats)
	if aggregate != nil {
		session.Add("Recorded stats", map[string]string{
			"prompt_tokens":     fmt.Sprintf("%d", aggregate.PromptTokens),
			"completion_tokens": fmt.Sprintf("%d", aggregate.CompletionTokens),
			"duration_ms":       fmt.Sprintf("%d", result.Duration.Milliseconds()),
			"calls":             fmt.Sprintf("%d", len(result.Stats)),
		})
	}
}

func countLines(text string) int {
	if text == "" {
		return 0
	}
	return strings.Count(text, "\n") + 1
}

// fixCmd is the explicit fix subcommand (optional - root handles it too)
var fixCmd = &cobra.Command{
	Use:   "fix [file] [-start] [+end] [instruction]",
	Short: "Fix code in a file",
	Long: `Fix code in a file using local AI.

Examples:
  obot fix main.go                    # Fix entire file
  obot fix main.go -10 +25            # Fix lines 10-25
  obot fix main.go "fix null check"   # Fix with instruction
  obot fix main.go -10 +25 "add error handling"`,
	RunE: runFix,
}

func init() {
	// The fix command is optional since root handles it
	// rootCmd.AddCommand(fixCmd)
}
