package cli

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/croberts/obot/internal/session"
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
		sessions, err := session.ListUSFSessionIDs("")
		if err != nil {
			return fmt.Errorf("list sessions: %w", err)
		}

		if len(sessions) == 0 {
			printInfo("No sessions found.")
			return nil
		}

		fmt.Printf("\n%s Sessions (USF):\n\n", cyan("📋"))

		for _, sid := range sessions {
			usf, err := session.LoadUSFSession("", sid)
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
				usf.Platform, len(usf.History), usf.Stats.TotalTokens)
			if usf.OrchestrationState.FlowCode != "" {
				fmt.Printf("    Flow: %s\n", usf.OrchestrationState.FlowCode)
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
		usf, err := session.LoadUSFSession("", args[0])
		if err != nil {
			return fmt.Errorf("load session: %w", err)
		}

		if err := usf.Save(""); err != nil {
			return fmt.Errorf("export session: %w", err)
		}

		printSuccess(fmt.Sprintf("Session %s exported", usf.SessionID))
		return nil
	},
}

var sessionShowCmd = &cobra.Command{
	Use:   "show [session-id]",
	Short: "Show session details",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		usf, err := session.LoadUSFSession("", args[0])
		if err != nil {
			return fmt.Errorf("load session: %w", err)
		}

		fmt.Printf("\n%s Session: %s\n\n", cyan("📋"), cyan(usf.SessionID))
		fmt.Printf("  Version:  %s\n", usf.Version)
		fmt.Printf("  Platform: %s\n", usf.Platform)
		fmt.Printf("  Created:  %s\n", usf.CreatedAt.Format("2006-01-02 15:04:05"))
		fmt.Printf("  Updated:  %s\n", usf.UpdatedAt.Format("2006-01-02 15:04:05"))
		fmt.Printf("  Status:   %s\n", usf.Task.Status)
		fmt.Println()

		fmt.Printf("  %s Task\n", cyan("📝"))
		fmt.Printf("    Description: %s\n", usf.Task.Description)
		fmt.Printf("    Prompt:      %s\n", usf.Task.Prompt)
		fmt.Println()

		if usf.OrchestrationState.FlowCode != "" {
			fmt.Printf("  %s Orchestration\n", cyan("🔄"))
			fmt.Printf("    Flow Code: %s\n", green(usf.OrchestrationState.FlowCode))
			fmt.Printf("    Schedule:  S%d P%d\n", usf.OrchestrationState.Schedule, usf.OrchestrationState.Process)
			fmt.Println()
		}

		fmt.Printf("  %s Stats\n", cyan("📊"))
		fmt.Printf("    Tokens:   %d\n", usf.Stats.TotalTokens)
		fmt.Printf("    Steps:    %d\n", len(usf.History))
		fmt.Println()

		if len(usf.History) > 0 {
			fmt.Printf("  %s Steps (last 10)\n", cyan("📝"))
			start := 0
			if len(usf.History) > 10 {
				start = len(usf.History) - 10
			}
			for _, step := range usf.History[start:] {
				fmt.Printf("    %s #%d S%d P%d\n", green("✓"), step.Sequence, step.Schedule, step.Process)
			}
		}

		return nil
	},
}

var sessionSaveCmd = &cobra.Command{
	Use:   "save",
	Short: "Save the current active session",
	RunE: func(cmd *cobra.Command, args []string) error {
		mgr := session.NewManager("")
		if err := mgr.Checkpoint(); err != nil {
			return err
		}
		printSuccess("Current session saved.")
		return nil
	},
}

var sessionLoadCmd = &cobra.Command{
	Use:   "load [session-id]",
	Short: "Load a session as active",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		mgr := session.NewManager("")
		if err := mgr.Load(args[0]); err != nil {
			return err
		}
		printSuccess(fmt.Sprintf("Session %s loaded.", args[0]))
		return nil
	},
}

var sessionImportCmd = &cobra.Command{
	Use:   "import [file.usf]",
	Short: "Import a session from a USF file",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		data, err := os.ReadFile(args[0])
		if err != nil {
			return err
		}

		var usf session.USFSession
		if err := json.Unmarshal(data, &usf); err != nil {
			return err
		}

		homeDir, _ := os.UserHomeDir()
		baseDir := filepath.Join(homeDir, ".config", "ollamabot", "sessions")
		s := session.ImportUSF(&usf, baseDir)
		if err := s.Save(); err != nil {
			return err
		}

		printSuccess(fmt.Sprintf("Session %s imported successfully.", s.ID))
		return nil
	},
}

func init() {
	usfSessionCmd.AddCommand(sessionListCmd)
	usfSessionCmd.AddCommand(sessionExportCmd)
	usfSessionCmd.AddCommand(sessionShowCmd)
	usfSessionCmd.AddCommand(sessionSaveCmd)
	usfSessionCmd.AddCommand(sessionLoadCmd)
	usfSessionCmd.AddCommand(sessionImportCmd)
}
