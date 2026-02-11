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
		sessions, err := session.ListAllSessions()
		if err != nil {
			return fmt.Errorf("list sessions: %w", err)
		}

		if len(sessions) == 0 {
			printInfo("No sessions found.")
			return nil
		}

		fmt.Printf("\n%s Sessions:\n\n", cyan("📋"))

		for _, sid := range sessions {
			info, err := session.GetSessionInfo(sid)
			if err != nil {
				fmt.Printf("  • %s %s\n", red("✗"), sid)
				continue
			}

			status := green("✓")
			if info.Format == "legacy" {
				status = yellow("⚠")
			}

			fmt.Printf("  %s %s", status, cyan(sid))
			if info.Format == "legacy" {
				fmt.Printf(" %s", yellow("[legacy format]"))
			}
			fmt.Println()
			fmt.Printf("    Task: %s\n", info.Description)
			fmt.Printf("    Platform: %s | Steps: %d\n", info.Platform, info.StepCount)
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
		usf, err := session.LoadAnySession(args[0])
		if err != nil {
			return fmt.Errorf("load session: %w", err)
		}

		if err := session.SaveAnySession(usf); err != nil {
			return fmt.Errorf("export session: %w", err)
		}

		printSuccess(fmt.Sprintf("Session %s exported (migrated to unified format)", usf.SessionID))
		return nil
	},
}

var sessionShowCmd = &cobra.Command{
	Use:   "show [session-id]",
	Short: "Show session details",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		usf, err := session.LoadAnySession(args[0])
		if err != nil {
			return fmt.Errorf("load session: %w", err)
		}

		info, _ := session.GetSessionInfo(args[0])
		
		fmt.Printf("\n%s Session: %s\n\n", cyan("📋"), cyan(usf.SessionID))
		fmt.Printf("  Version:  %s\n", usf.Version)
		if info != nil && info.Format == "legacy" {
			fmt.Printf("  Format:   %s\n", yellow("legacy (auto-migrated on save)"))
		}
		fmt.Printf("  Platform: %s\n", usf.PlatformOrigin)
		fmt.Printf("  Created:  %s\n", usf.CreatedAt.Format("2006-01-02 15:04:05"))
		fmt.Printf("  Updated:  %s\n", usf.UpdatedAt.Format("2006-01-02 15:04:05"))
		fmt.Printf("  Status:   %s\n", usf.Task.Status)
		fmt.Println()

		fmt.Printf("  %s Task\n", cyan("📝"))
		fmt.Printf("    Description: %s\n", usf.Task.Description)
		if usf.Task.Intent != "" {
			fmt.Printf("    Intent:      %s\n", usf.Task.Intent)
		}
		fmt.Println()

		if usf.Orchestration.FlowCode != "" {
			fmt.Printf("  %s Orchestration\n", cyan("🔄"))
			fmt.Printf("    Flow Code: %s\n", green(usf.Orchestration.FlowCode))
			fmt.Printf("    Schedule:  S%d P%d\n", usf.Orchestration.CurrentSchedule, usf.Orchestration.CurrentProcess)
			fmt.Println()
		}

		fmt.Printf("  %s Stats\n", cyan("📊"))
		fmt.Printf("    Tokens:   %d\n", usf.Stats.TotalTokens)
		fmt.Printf("    Steps:    %d\n", len(usf.Steps))
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
				fmt.Printf("    %s #%d %s\n", status, step.StepNumber, step.ToolID)
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

var sessionMigrateCmd = &cobra.Command{
	Use:   "migrate",
	Short: "Migrate all legacy USFSession format sessions to UnifiedSession format",
	Long: `Converts all sessions stored in the legacy USFSession format (subdirectory with session.usf)
to the current UnifiedSession format (flat .json files). The legacy directories are renamed to
.migrated_<sessionID> for backup purposes.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		fmt.Println("Scanning for legacy format sessions...")
		
		count, err := session.MigrateAllSessions()
		if err != nil {
			return fmt.Errorf("migration failed: %w", err)
		}

		if count == 0 {
			printInfo("No legacy sessions found. All sessions are already in unified format.")
		} else {
			printSuccess(fmt.Sprintf("Successfully migrated %d session(s) to unified format.", count))
			fmt.Println("\nLegacy session directories have been renamed to .migrated_<sessionID>")
			fmt.Println("You can safely delete them after verifying the migration.")
		}

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
	usfSessionCmd.AddCommand(sessionMigrateCmd)
}
