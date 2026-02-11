package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	usfsession "github.com/croberts/obot/internal/session"
)

var usfSessionCmd = &cobra.Command{
	Use:   "session",
	Short: "Manage obot sessions (USF format)",
	Long:  `List, export, and inspect sessions in the Unified Session Format.`,
}

var sessionListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all sessions",
	RunE: func(cmd *cobra.Command, args []string) error {
		sessions, err := usfsession.ListUSFSessions()
		if err != nil {
			return fmt.Errorf("list sessions: %w", err)
		}

		if len(sessions) == 0 {
			printInfo("No sessions found.")
			return nil
		}

		fmt.Printf("\n%s Sessions (USF):\n\n", cyan("📋"))

		for _, sid := range sessions {
			usf, err := usfsession.LoadUSF(sid)
			if err != nil {
				fmt.Printf("  • %s %s\n", red("✗"), sid)
				continue
			}

			status := green("✓")
			if usf.Task.Status != "completed" {
				status = yellow("⟳")
			}

			fmt.Printf("  %s %s\n", status, cyan(sid))
			fmt.Printf("    Task: %s\n", usf.Task.Description)
			fmt.Printf("    Platform: %s | Steps: %d | Tokens: %d\n",
				usf.PlatformOrigin, len(usf.Steps), usf.Stats.TotalTokens)
			if usf.Orchestration.FlowCode != "" {
				fmt.Printf("    Flow: %s\n", usf.Orchestration.FlowCode)
			}
			fmt.Println()
		}

		return nil
	},
}

var sessionExportCmd = &cobra.Command{
	Use:   "export [session-id]",
	Short: "Export a session in USF JSON",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		usf, err := usfsession.LoadUSF(args[0])
		if err != nil {
			return fmt.Errorf("load session: %w", err)
		}

		// Re-save (in case format needs updating)
		if err := usfsession.SaveUSF(usf); err != nil {
			return fmt.Errorf("export session: %w", err)
		}

		printSuccess(fmt.Sprintf("Session %s exported to ~/.config/ollamabot/sessions/", usf.SessionID))
		return nil
	},
}

var sessionShowCmd = &cobra.Command{
	Use:   "show [session-id]",
	Short: "Show session details",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		usf, err := usfsession.LoadUSF(args[0])
		if err != nil {
			return fmt.Errorf("load session: %w", err)
		}

		fmt.Printf("\n%s Session: %s\n\n", cyan("📋"), cyan(usf.SessionID))
		fmt.Printf("  Version:  %s\n", usf.Version)
		fmt.Printf("  Platform: %s\n", usf.PlatformOrigin)
		fmt.Printf("  Created:  %s\n", usf.CreatedAt.Format("2006-01-02 15:04:05"))
		fmt.Printf("  Updated:  %s\n", usf.UpdatedAt.Format("2006-01-02 15:04:05"))
		fmt.Printf("  Status:   %s\n", usf.Task.Status)
		fmt.Println()

		fmt.Printf("  %s Task\n", cyan("📝"))
		fmt.Printf("    Description: %s\n", usf.Task.Description)
		fmt.Printf("    Intent:      %s\n", usf.Task.Intent)
		fmt.Printf("    Quality:     %s\n", usf.Task.QualityPreset)
		fmt.Println()

		if usf.Orchestration.FlowCode != "" {
			fmt.Printf("  %s Orchestration\n", cyan("🔄"))
			fmt.Printf("    Flow Code: %s\n", green(usf.Orchestration.FlowCode))
			fmt.Printf("    Schedule:  S%d P%d\n", usf.Orchestration.CurrentSchedule, usf.Orchestration.CurrentProcess)
			fmt.Println()
		}

		fmt.Printf("  %s Stats\n", cyan("📊"))
		fmt.Printf("    Tokens:   %d\n", usf.Stats.TotalTokens)
		fmt.Printf("    Files:    %d modified, %d created\n", usf.Stats.FilesModified, usf.Stats.FilesCreated)
		fmt.Printf("    Steps:    %d\n", len(usf.Steps))
		fmt.Printf("    Checkpoints: %d\n", len(usf.Checkpoints))

		if usf.Stats.EstimatedCostSaved > 0 {
			fmt.Printf("    Savings:  $%.2f\n", usf.Stats.EstimatedCostSaved)
		}
		fmt.Println()

		if len(usf.Steps) > 0 {
			fmt.Printf("  %s Steps (last 10)\n", cyan("📝"))
			start := 0
			if len(usf.Steps) > 10 {
				start = len(usf.Steps) - 10
			}
			for _, step := range usf.Steps[start:] {
				status := green("✓")
				if !step.Success {
					status = red("✗")
				}
				fmt.Printf("    %s #%d %s", status, step.StepNumber, step.ToolID)
				if step.Tokens > 0 {
					fmt.Printf(" (%d tokens)", step.Tokens)
				}
				fmt.Println()
			}
		}

		return nil
	},
}

func init() {
	usfSessionCmd.AddCommand(sessionListCmd)
	usfSessionCmd.AddCommand(sessionExportCmd)
	usfSessionCmd.AddCommand(sessionShowCmd)
}
