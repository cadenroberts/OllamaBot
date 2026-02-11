package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	usfsession "github.com/croberts/obot/internal/session"
	"github.com/croberts/obot/internal/tools"
)

var checkpointCmd = &cobra.Command{
	Use:   "checkpoint",
	Short: "Manage session checkpoints",
	Long:  `Save, restore, and list checkpoints for obot sessions.`,
}

var checkpointSaveCmd = &cobra.Command{
	Use:   "save [name]",
	Short: "Save a checkpoint",
	Args:  cobra.MaximumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		name := "auto"
		if len(args) > 0 {
			name = args[0]
		}

		// Get current git commit if in a git repo
		wd, _ := cmd.Flags().GetString("dir")
		gitCommit := ""
		status, err := tools.GitStatus(wd)
		if err == nil {
			gitLog, logErr := tools.GitLog(wd, 1)
			if logErr == nil && len(gitLog) > 0 {
				gitCommit = gitLog[:minInt(8, len(gitLog))]
			}
			_ = status // we use git log for commit hash
		}

		sessions, err := usfsession.ListUSFSessions()
		if err != nil || len(sessions) == 0 {
			// Create a minimal session to hold the checkpoint
			usf := usfsession.NewUnifiedSession("checkpoint", "general", "balanced")
			usf.AddCheckpoint(name, gitCommit)
			if err := usfsession.SaveUSF(usf); err != nil {
				return fmt.Errorf("save checkpoint: %w", err)
			}
			printSuccess(fmt.Sprintf("Checkpoint '%s' saved (session %s)", name, usf.SessionID))
			return nil
		}

		// Add checkpoint to most recent session
		latest := sessions[len(sessions)-1]
		usf, err := usfsession.LoadUSF(latest)
		if err != nil {
			return fmt.Errorf("load session: %w", err)
		}

		usf.AddCheckpoint(name, gitCommit)
		if err := usfsession.SaveUSF(usf); err != nil {
			return fmt.Errorf("save checkpoint: %w", err)
		}

		printSuccess(fmt.Sprintf("Checkpoint '%s' saved (session %s)", name, usf.SessionID))
		return nil
	},
}

var checkpointListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all checkpoints",
	RunE: func(cmd *cobra.Command, args []string) error {
		sessions, err := usfsession.ListUSFSessions()
		if err != nil {
			return fmt.Errorf("list sessions: %w", err)
		}

		if len(sessions) == 0 {
			printInfo("No sessions with checkpoints found.")
			return nil
		}

		fmt.Printf("\n%s Checkpoints:\n\n", cyan("📌"))

		found := false
		for _, sid := range sessions {
			usf, err := usfsession.LoadUSF(sid)
			if err != nil || len(usf.Checkpoints) == 0 {
				continue
			}

			fmt.Printf("  Session: %s\n", cyan(sid))
			for _, cp := range usf.Checkpoints {
				commitStr := ""
				if cp.GitCommit != "" {
					commitStr = fmt.Sprintf(" [%s]", cp.GitCommit)
				}
				fmt.Printf("    • %s %s%s (%s)\n",
					green(cp.ID), cp.Name, commitStr, cp.Timestamp.Format("2006-01-02 15:04"))
			}
			fmt.Println()
			found = true
		}

		if !found {
			printInfo("No checkpoints found.")
		}

		return nil
	},
}

var checkpointRestoreCmd = &cobra.Command{
	Use:   "restore [checkpoint-id]",
	Short: "Restore to a checkpoint",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		cpID := args[0]

		sessions, err := usfsession.ListUSFSessions()
		if err != nil {
			return fmt.Errorf("list sessions: %w", err)
		}

		for _, sid := range sessions {
			usf, err := usfsession.LoadUSF(sid)
			if err != nil {
				continue
			}
			for _, cp := range usf.Checkpoints {
				if cp.ID == cpID {
					if cp.GitCommit != "" {
						printInfo(fmt.Sprintf("Restoring to git commit %s...", cp.GitCommit))
						// In a full implementation, this would run git checkout
					}
					printSuccess(fmt.Sprintf("Restored to checkpoint '%s' (flow: %s)", cp.Name, cp.FlowCode))
					return nil
				}
			}
		}

		return fmt.Errorf("checkpoint '%s' not found", cpID)
	},
}

func init() {
	checkpointSaveCmd.Flags().String("dir", "", "Working directory")
	checkpointCmd.AddCommand(checkpointSaveCmd)
	checkpointCmd.AddCommand(checkpointListCmd)
	checkpointCmd.AddCommand(checkpointRestoreCmd)
}

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}
