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

	"github.com/croberts/obot/internal/agent"
	"github.com/croberts/obot/internal/consultation"
	"github.com/croberts/obot/internal/model"
	"github.com/croberts/obot/internal/ollama"
	"github.com/croberts/obot/internal/orchestrate"
	"github.com/croberts/obot/internal/planner"
	"github.com/croberts/obot/internal/resource"
	"github.com/croberts/obot/internal/router"
	"github.com/croberts/obot/internal/schedule"
	orchsession "github.com/croberts/obot/internal/session"
	"github.com/croberts/obot/internal/ui"
	"github.com/spf13/cobra"
)

var (
	// Orchestrate flags
	orchHub           string
	orchLab           string
	orchSessionID     string
	orchListSessions  bool
	orchRestoreState  string
	orchDryRun        bool
	orchExportPath    string
	orchMemoryLimit   string
	orchTokenLimit    int64
	orchTimeout       string
	orchNoColors      bool
	orchNoMemGraph    bool
	orchNoAnimations  bool
)

var orchestrateCmd = &cobra.Command{
	Use:   "orchestrate [options] [initial prompt]",
	Short: "Launch professional agentic orchestration",
	Long: `obot orchestrate - Professional-grade agentic orchestration framework

The orchestration system operates through 5 schedules, each containing 3 processes:

SCHEDULES:
  Knowledge   (Research → Crawl → Retrieve)      Model: RAG
  Plan        (Brainstorm → Clarify → Plan)      Model: Coder
  Implement   (Implement → Verify → Feedback)    Model: Coder
  Scale       (Scale → Benchmark → Optimize)     Model: Coder
  Production  (Analyze → Systemize → Harmonize)  Model: Coder+Vision

NAVIGATION RULES:
  Processes follow strict 1↔2↔3 adjacency:
  - From P1: go to P1 (repeat) or P2
  - From P2: go to P1, P2, or P3
  - From P3: go to P2, P3, or terminate schedule

HUMAN CONSULTATION:
  - Clarify (Plan schedule): Optional, on ambiguity detection
  - Feedback (Implement schedule): Mandatory

PROMPT TERMINATION:
  - All 5 schedules must have run at least once
  - Production must be the last terminated schedule
  - Orchestrator must justify no further improvement is possible

EXAMPLES:
  obot orchestrate
  obot orchestrate "Build a REST API"
  obot orchestrate --hub "my-api" "Build a REST API"
  obot orchestrate --session abc123
  obot orchestrate --list-sessions`,
	Args:                  cobra.ArbitraryArgs,
	DisableFlagsInUseLine: true,
	RunE:                  runOrchestrate,
}

func init() {
	// Git integration flags
	orchestrateCmd.Flags().StringVar(&orchHub, "hub", "", "Create GitHub repository with this name")
	orchestrateCmd.Flags().StringVar(&orchLab, "lab", "", "Create GitLab repository with this name")

	// Session management flags
	orchestrateCmd.Flags().StringVar(&orchSessionID, "session", "", "Resume existing session by ID")
	orchestrateCmd.Flags().BoolVar(&orchListSessions, "list-sessions", false, "List all sessions")
	orchestrateCmd.Flags().StringVar(&orchRestoreState, "restore", "", "Restore to specific state")
	orchestrateCmd.Flags().StringVar(&orchExportPath, "export", "", "Export session to path")

	// Resource limit flags
	orchestrateCmd.Flags().StringVar(&orchMemoryLimit, "memory-limit", "", "Set memory limit (e.g., 8GB)")
	orchestrateCmd.Flags().Int64Var(&orchTokenLimit, "token-limit", 0, "Set token limit (0 = unlimited)")
	orchestrateCmd.Flags().StringVar(&orchTimeout, "timeout", "", "Set overall timeout (e.g., 30m, 2h)")

	// UI flags
	orchestrateCmd.Flags().BoolVar(&orchNoColors, "no-colors", false, "Disable ANSI colors")
	orchestrateCmd.Flags().BoolVar(&orchNoMemGraph, "no-memory-graph", false, "Disable memory visualization")
	orchestrateCmd.Flags().BoolVar(&orchNoAnimations, "no-animations", false, "Disable animations")

	// Dry run
	orchestrateCmd.Flags().BoolVar(&orchDryRun, "dry-run", false, "Simulate without executing")

	// Add to root command
	rootCmd.AddCommand(orchestrateCmd)
}

func runOrchestrate(cmd *cobra.Command, args []string) error {
	// Handle list sessions
	if orchListSessions {
		return listOrchestrateSessions()
	}

	// Handle restore
	if orchRestoreState != "" {
		return restoreOrchestrateState(orchRestoreState)
	}

	// Create context with cancellation
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle signals
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		fmt.Fprintln(os.Stderr, "\n"+ui.FormatWarning("Received interrupt signal, shutting down gracefully..."))
		cancel()
	}()

	// Print banner
	printOrchestrateBanner()

	// Build initial prompt from args or prompt user
	var initialPrompt string
	if len(args) > 0 {
		initialPrompt = strings.Join(args, " ")
	}

	// If no prompt provided, prompt user
	if initialPrompt == "" {
		initialPrompt = promptForInput()
		if initialPrompt == "" {
			fmt.Println(ui.FormatValueMuted("No prompt provided. Exiting."))
			return nil
		}
	}

	// Classify intent for model routing
	intentRouter := router.NewIntentRouter()
	intent := intentRouter.Classify(initialPrompt)
	modelRole := intentRouter.SelectModelRole(intent)
	fmt.Printf("%s %s %s\n", ui.FormatLabel("Intent"),
		ui.FormatBullet()+ui.FormatValue(string(intent)),
		ui.FormatValueMuted("("+modelRole+")"))

	// Initialize components
	orch := orchestrate.NewOrchestrator()
	orch.SetPrompt(initialPrompt)

	// Initialize session
	sess := orchsession.NewSession()
	sess.SetPrompt(initialPrompt)

	// Initialize resource monitor
	resMon := resource.NewMonitor()
	resMon.Start()
	defer resMon.Stop()

	// Initialize Ollama client
	var ollamaClient *ollama.Client
	if ollamaURL != "" {
		ollamaClient = ollama.NewClient(ollama.WithBaseURL(ollamaURL))
	} else {
		ollamaClient = ollama.NewClient()
	}

	// Initialize model coordinator
	modelCoord := model.NewCoordinator(ollamaClient)

	// Initialize agent
	ag := agent.NewAgent(modelCoord)

	// Create status display
	statusDisplay := ui.NewStatusDisplay(os.Stdout, 80, 250*time.Millisecond)

	// Set up orchestrator callbacks
	orch.SetCallbacks(
		func(state orchestrate.OrchestratorState) {
			statusDisplay.SetOrchestratorState(state)
		},
		func(schedID orchestrate.ScheduleID) {
			statusDisplay.SetSchedule(orchestrate.ScheduleNames[schedID])
			printScheduleStart(schedID)
		},
		func(schedID orchestrate.ScheduleID, procID orchestrate.ProcessID) {
			statusDisplay.SetProcess(orchestrate.ProcessNames[schedID][procID])
			printProcessStart(schedID, procID)
		},
		func(schedID orchestrate.ScheduleID, procID orchestrate.ProcessID) {
			printProcessTerminated(schedID, procID)
		},
		func(schedID orchestrate.ScheduleID) {
			printScheduleTerminated(schedID)
		},
		func(err error) {
			printOrchError(err)
		},
	)

	// Display configuration
	printConfiguration()

	// Show initial prompt
	fmt.Println()
	fmt.Printf("%s %s\n", ui.FormatLabel("Prompt"), ui.FormatBullet()+ui.FormatValue(initialPrompt))
	fmt.Println()

	// Draw initial status display
	fmt.Print(ui.FormatLabelBold("Orchestrator") + ui.FormatBullet() + ui.FormatValue("Begin") + "\n")

	// Run pre-orchestration planning (Merges item 278 Planner Integration)
	fmt.Printf("%s %s\n", ui.FormatLabelBold("Planner"), ui.FormatBullet()+ui.FormatValue("Building pre-schedule plan..."))
	plan, err := planner.BuildPlan(ctx, ".", initialPrompt, planner.DefaultOptions())
	if err != nil {
		fmt.Printf("%s %s\n", ui.FormatWarning("⚠"), "Planning failed, continuing with heuristic: "+err.Error())
	} else if plan != nil && len(plan.Tasks) > 0 {
		fmt.Println(ui.FormatValueMuted("  Pre-schedule analysis complete:"))
		for i, task := range plan.Tasks {
			if i >= 5 {
				fmt.Printf("    %s %s\n", ui.FormatBullet(), ui.FormatValueMuted(fmt.Sprintf("... and %d more", len(plan.Tasks)-5)))
				break
			}
			riskIcon := "🟢"
			if task.Risk == planner.RiskHigh {
				riskIcon = "🔴"
			} else if task.Risk == planner.RiskModerate {
				riskIcon = "🟡"
			}
			fmt.Printf("    %s %s %s\n", riskIcon, ui.FormatValue(task.ID), ui.FormatValueMuted(task.Message))

			// Feed into orchestration notes (Merges item 278 Planner Integration)
			orch.AddNote(fmt.Sprintf("Planned subtask [%s]: %s (Risk: %s, Rationale: %s)", task.ID, task.Message, task.Risk, task.Rationale), "planner")
		}
		fmt.Println()
	}

	fmt.Print(ui.FormatLabel("Schedule") + ui.FormatBullet() + ui.TextMuted + "..." + ui.Reset + "\n")
	fmt.Print(ui.FormatLabel("Process") + ui.FormatBullet() + ui.TextMuted + "..." + ui.Reset + "\n")
	fmt.Print(ui.FormatLabel("Agent") + ui.FormatBullet() + ui.TextMuted + "..." + ui.Reset + "\n")
	fmt.Println()

	// Start animation loop in background
	go statusDisplay.RunAnimationLoop()
	defer statusDisplay.StopAnimations()

	// Run the orchestration loop
	err = runOrchestrationLoop(ctx, orch, modelCoord, ag, resMon, sess, statusDisplay)
	if err != nil && err != context.Canceled {
		return err
	}

	// Print final summary
	printPromptSummary(orch, ag, resMon)

	return nil
}

// runOrchestrationLoop executes the main orchestration loop
func runOrchestrationLoop(
	ctx context.Context,
	orch *orchestrate.Orchestrator,
	modelCoord *model.Coordinator,
	ag *agent.Agent,
	resMon *resource.Monitor,
	sess *orchsession.Session,
	statusDisplay *ui.StatusDisplay,
) error {
	// Select schedule function - uses the orchestrator model
	selectScheduleFn := func(ctx context.Context) (orchestrate.ScheduleID, error) {
		// For first run, start with Knowledge
		if orch.GetStats().TotalSchedulings == 0 {
			return orchestrate.ScheduleKnowledge, nil
		}

		// Use the orchestrator model to decide next schedule
		scheduleID, shouldTerminate, err := modelCoord.SelectNextSchedule(ctx, orch)
		if err != nil {
			return 0, err
		}

		if shouldTerminate {
			return 0, nil // Signal to terminate prompt
		}

		return scheduleID, nil
	}

	// Select process function - uses navigation rules
	selectProcessFn := func(ctx context.Context, schedID orchestrate.ScheduleID, lastProc orchestrate.ProcessID) (orchestrate.ProcessID, bool, error) {
		// First process is always Process1
		if lastProc == 0 {
			return orchestrate.Process1, false, nil
		}

		// Use model to decide next process
		nextProc, shouldTerminate, err := modelCoord.SelectNextProcess(ctx, orch, schedID, lastProc)
		if err != nil {
			return 0, false, err
		}

		return nextProc, shouldTerminate, nil
	}

	// Execute process function - runs the agent
	executeProcessFn := func(ctx context.Context, schedID orchestrate.ScheduleID, procID orchestrate.ProcessID) error {
		// Get the logic handler for this schedule
		handler := schedule.GetLogicHandler(schedID)
		if handler != nil {
			// Execute using the logic handler
			return handler.ExecuteProcess(ctx, procID, func(ctx context.Context, prompt string) error {
				modelName := modelCoord.GetModelForSchedule(schedID)
				return executeAgentProcess(ctx, ag, modelCoord, orch, schedID, procID, modelName, resMon, statusDisplay)
			})
		}

		// Fallback to direct execution if no handler
		modelName := modelCoord.GetModelForSchedule(schedID)
		return executeAgentProcess(ctx, ag, modelCoord, orch, schedID, procID, modelName, resMon, statusDisplay)
	}

	// Run the orchestrator
	return orch.Run(ctx, selectScheduleFn, selectProcessFn, executeProcessFn)
}

// executeAgentProcess runs the agent for a specific process
func executeAgentProcess(
	ctx context.Context,
	ag *agent.Agent,
	modelCoord *model.Coordinator,
	orch *orchestrate.Orchestrator,
	schedID orchestrate.ScheduleID,
	procID orchestrate.ProcessID,
	modelName string,
	resMon *resource.Monitor,
	statusDisplay *ui.StatusDisplay,
) error {
	processName := orchestrate.ProcessNames[schedID][procID]
	prompt := orch.GetPrompt()

	// Update agent action display
	statusDisplay.SetAgentAction(fmt.Sprintf("Executing %s...", processName))

	// Set agent context
	ag.SetContext(schedID, procID)

	// Set action callback to update UI
	ag.SetActionCallback(func(a agent.Action) {
		statusDisplay.SetAgentAction(a.ActionOutput())
		printAgentAction(string(a.Type), a.Path)
		resMon.RecordDiskWrite(int64(len(a.Content))) // Simple disk tracking
	})

	// Execute the process using the agent
	// The agent will select the correct model based on schedule/process
	err := ag.Execute(ctx, schedID, procID, prompt)
	if err != nil {
		return err
	}

	// Mark process completion
	statusDisplay.SetAgentAction(fmt.Sprintf("%s Completed", processName))

	// Record stats
	stats := ag.GetStats()
	orch.RecordActions(stats.TotalActions)

	return nil
}

// handleHumanConsultation handles Clarify or Feedback processes
func handleHumanConsultation(
	ctx context.Context,
	orch *orchestrate.Orchestrator,
	consultType orchestrate.ConsultationType,
	schedID orchestrate.ScheduleID,
	procID orchestrate.ProcessID,
) {
	processName := orchestrate.ProcessNames[schedID][procID]

	// Initialize consultation handler
	handler := consultation.NewHandler(os.Stdin, os.Stdout, nil)

	req := consultation.Request{
		Type:     consultation.ConsultationType(consultType),
		Question: fmt.Sprintf("Consultation requested for %s process in %s schedule.", processName, orchestrate.ScheduleNames[schedID]),
	}

	if consultType == orchestrate.ConsultationOptional {
		fmt.Printf("\n%s %s\n", ui.FormatLabel("Human Consultation"),
			ui.FormatBullet()+ui.FormatValueMuted("(Optional) "+processName))
	} else {
		fmt.Printf("\n%s %s\n", ui.FormatLabel("Human Consultation"),
			ui.FormatBullet()+ui.FormatValue("(Required) "+processName))
	}

	resp, err := handler.Request(ctx, req)
	if err != nil {
		fmt.Printf("%s %s\n", ui.FormatError("✗"), err.Error())
		return
	}

	if resp.Source == consultation.ResponseSourceHuman {
		orch.AddNote(resp.Content, "user")
		fmt.Printf("%s %s\n", ui.FormatSuccess("✓"), "Response recorded")
	} else {
		fmt.Printf("%s %s\n", ui.FormatWarning("⏱"), "Timeout - AI substitute used: "+resp.Content)
		orch.AddNote(resp.Content, "ai-substitute")
	}
}

// OllamaBot ASCII Logo - Tokyo Blue themed
func getOllamaBotLogo() string {
	return ui.TokyoBlue + `
    ╭─────────────────────────────────────╮
    │                                     │
    │   ` + ui.TokyoBlueBold + `█▀█ █   █   ▄▀█ █▀▄▀█ ▄▀█` + ui.TokyoBlue + `   │
    │   ` + ui.TokyoBlueBold + `█▄█ █▄▄ █▄▄ █▀█ █ ▀ █ █▀█` + ui.TokyoBlue + `   │
    │         ` + ui.TextPrimary + `B   O   T` + ui.TokyoBlue + `             │
    │                                     │
    ╰─────────────────────────────────────╯` + ui.Reset
}

// Compact logo for status display
func getCompactLogo() string {
	return ui.TokyoBlueBold + "◉" + ui.Reset
}

func printOrchestrateBanner() {
	fmt.Println(getOllamaBotLogo())
	fmt.Println()
	
	// version already includes platform info via version.Short()
	fmt.Printf("  %s %s\n",
		ui.FormatLabelBold("obot orchestrate"),
		ui.FormatValueMuted("v"+version))
	fmt.Printf("  %s\n", ui.FormatValueMuted("Professional Agentic Orchestration"))
}

func printConfiguration() {
	if orchHub == "" && orchLab == "" && orchMemoryLimit == "" && orchTokenLimit == 0 && orchTimeout == "" && !orchDryRun {
		return
	}

	fmt.Println()
	fmt.Println(ui.FormatLabel("Configuration"))
	if orchHub != "" {
		fmt.Printf("  %s %s\n", ui.FormatValueMuted("GitHub:"), ui.FormatValue(orchHub))
	}
	if orchLab != "" {
		fmt.Printf("  %s %s\n", ui.FormatValueMuted("GitLab:"), ui.FormatValue(orchLab))
	}
	if orchMemoryLimit != "" {
		fmt.Printf("  %s %s\n", ui.FormatValueMuted("Memory Limit:"), ui.FormatValue(orchMemoryLimit))
	}
	if orchTokenLimit > 0 {
		fmt.Printf("  %s %s\n", ui.FormatValueMuted("Token Limit:"), ui.FormatValue(fmt.Sprintf("%d", orchTokenLimit)))
	}
	if orchTimeout != "" {
		fmt.Printf("  %s %s\n", ui.FormatValueMuted("Timeout:"), ui.FormatValue(orchTimeout))
	}
	if orchDryRun {
		fmt.Printf("  %s %s\n", ui.FormatValueMuted("Mode:"), ui.FormatWarning("DRY RUN"))
	}
}

func printScheduleStart(schedID orchestrate.ScheduleID) {
	name := orchestrate.ScheduleNames[schedID]
	fmt.Printf("\n%s %s\n", ui.FormatLabelBold("Schedule"), ui.FormatBullet()+ui.FormatValue(name))
}

func printProcessStart(schedID orchestrate.ScheduleID, procID orchestrate.ProcessID) {
	name := orchestrate.ProcessNames[schedID][procID]
	fmt.Printf("%s %s\n", ui.FormatLabel("Process"), ui.FormatBullet()+ui.FormatValue(name))
}

func printProcessTerminated(schedID orchestrate.ScheduleID, procID orchestrate.ProcessID) {
	name := orchestrate.ProcessNames[schedID][procID]
	fmt.Printf("%s %s\n", ui.FormatLabel("Process"), ui.FormatBullet()+ui.FormatValueMuted(name+" Terminated"))
}

func printScheduleTerminated(schedID orchestrate.ScheduleID) {
	name := orchestrate.ScheduleNames[schedID]
	fmt.Printf("%s %s\n\n", ui.FormatLabel("Schedule"), ui.FormatBullet()+ui.FormatValueMuted(name+" Terminated"))
}

func printAgentAction(action, target string) {
	fmt.Printf("%s %s %s\n", ui.FormatLabel("Agent"), ui.FormatBullet()+ui.FormatValue(action), ui.FormatValueMuted(target))
}

func printOrchError(err error) {
	fmt.Printf("\n%s %s\n", ui.FormatError("Error"), ui.FormatBullet()+err.Error())
}

func promptForInput() string {
	fmt.Println()
	fmt.Printf("%s %s\n", ui.FormatLabel("→"), ui.FormatValue("Enter your prompt:"))
	fmt.Print(ui.TokyoBlue + "  > " + ui.Reset)

	reader := bufio.NewReader(os.Stdin)
	input, err := reader.ReadString('\n')
	if err != nil {
		return ""
	}
	return strings.TrimSpace(input)
}

func printPromptSummary(orch *orchestrate.Orchestrator, ag *agent.Agent, resMon *resource.Monitor) {
	stats := orch.GetStats()
	flowCode := orch.GetFlowCode()
	memStats := resMon.GetStats()

	fmt.Println()
	fmt.Println(ui.TokyoBlue + "─────────────────────────────────────────────────────────────" + ui.Reset)
	fmt.Println()
	fmt.Printf("%s %s\n", ui.FormatLabelBold("Orchestrator"), ui.FormatBullet()+ui.FormatValue("Prompt Summary"))
	fmt.Println()

	// Flow code with colors
	fmt.Printf("%s %s\n", ui.FormatLabel("Flow"), ui.FormatBullet()+ui.FormatFlowCode(flowCode))
	fmt.Println()

	// Schedule stats
	fmt.Printf("%s %s\n", ui.FormatLabel("Schedules"), ui.FormatBullet()+ui.FormatValue(fmt.Sprintf("%d Total", stats.TotalSchedulings)))
	for schedID := orchestrate.ScheduleKnowledge; schedID <= orchestrate.ScheduleProduction; schedID++ {
		count := stats.SchedulingsByID[schedID]
		if count > 0 {
			fmt.Printf("  %s %s\n", ui.FormatValueMuted("•"), 
				ui.FormatValue(fmt.Sprintf("%d %s", count, orchestrate.ScheduleNames[schedID])))
		}
	}
	fmt.Println()

	// Process stats
	fmt.Printf("%s %s\n", ui.FormatLabel("Processes"), ui.FormatBullet()+ui.FormatValue(fmt.Sprintf("%d Total", stats.TotalProcesses)))
	fmt.Println()

	// Resource stats
	fmt.Printf("%s\n", ui.FormatLabel("Resources"))
	fmt.Printf("  %s %s\n", ui.FormatValueMuted("Peak Memory:"), 
		ui.FormatValue(formatBytes(memStats.PeakMemory)))
	fmt.Printf("  %s %s\n", ui.FormatValueMuted("Duration:"), 
		ui.FormatValue(stats.EndTime.Sub(stats.StartTime).Round(time.Millisecond).String()))
	fmt.Println()

	// Token stats
	fmt.Printf("%s %s\n", ui.FormatLabel("Tokens"), ui.FormatBullet()+ui.FormatValue(fmt.Sprintf("%d Total", stats.TotalTokens)))
	fmt.Println()

	// Agent action summary
	actionStats := ag.GetStats()
	fmt.Printf("%s\n", ui.FormatLabel("Agent Actions"))
	if actionStats.FilesCreated > 0 {
		fmt.Printf("  %s %s\n", ui.FormatValueMuted("Created:"), ui.FormatValue(fmt.Sprintf("%d files", actionStats.FilesCreated)))
	}
	if actionStats.FilesEdited > 0 {
		fmt.Printf("  %s %s\n", ui.FormatValueMuted("Edited:"), ui.FormatValue(fmt.Sprintf("%d files", actionStats.FilesEdited)))
	}
	if actionStats.FilesDeleted > 0 {
		fmt.Printf("  %s %s\n", ui.FormatValueMuted("Deleted:"), ui.FormatValue(fmt.Sprintf("%d files", actionStats.FilesDeleted)))
	}
	if actionStats.CommandsRan > 0 {
		fmt.Printf("  %s %s\n", ui.FormatValueMuted("Commands:"), ui.FormatValue(fmt.Sprintf("%d run", actionStats.CommandsRan)))
	}
	fmt.Println()

	fmt.Println(ui.TokyoBlue + "─────────────────────────────────────────────────────────────" + ui.Reset)
	fmt.Println()
}

func formatBytes(bytes uint64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := uint64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(bytes)/float64(div), "KMGTPE"[exp])
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func listOrchestrateSessions() error {
	printOrchestrateBanner()
	fmt.Println()
	fmt.Println(ui.FormatLabel("Sessions"))

	// Check for sessions directory (unified config path)
	homeDir, _ := os.UserHomeDir()
	sessionsDir := homeDir + "/.config/ollamabot/sessions"

	entries, err := os.ReadDir(sessionsDir)
	if err != nil {
		fmt.Printf("  %s\n", ui.FormatValueMuted("No sessions found"))
		fmt.Printf("  %s %s\n", ui.FormatValueMuted("Sessions directory:"), ui.FormatValue(sessionsDir))
		return nil
	}

	if len(entries) == 0 {
		fmt.Printf("  %s\n", ui.FormatValueMuted("No sessions found"))
		return nil
	}

	for _, entry := range entries {
		if entry.IsDir() {
			info, _ := entry.Info()
			fmt.Printf("  %s %s %s\n",
				ui.FormatValue(entry.Name()),
				ui.FormatValueMuted("-"),
				ui.FormatValueMuted(info.ModTime().Format("2006-01-02 15:04")))
		}
	}
	fmt.Println()
	return nil
}

func restoreOrchestrateState(stateID string) error {
	printOrchestrateBanner()
	fmt.Println()
	fmt.Printf("%s %s %s\n", ui.FormatLabel("Restore"), ui.FormatBullet(), ui.FormatValue(stateID))
	fmt.Println()

	// Look for restore script
	homeDir, _ := os.UserHomeDir()
	restoreScript := fmt.Sprintf("%s/.config/ollamabot/sessions/%s/restore.sh", homeDir, stateID)

	if _, err := os.Stat(restoreScript); os.IsNotExist(err) {
		fmt.Printf("  %s %s\n", ui.FormatError("✗"), "Session not found: "+stateID)
		return nil
	}

	fmt.Printf("  %s %s\n", ui.FormatValueMuted("Found:"), ui.FormatValue(restoreScript))
	fmt.Printf("  %s %s\n", ui.FormatValueMuted("Run:"), ui.FormatValue("bash "+restoreScript))
	fmt.Println()
	return nil
}
