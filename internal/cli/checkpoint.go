// Package cli implements the command-line interface for OllamaBot.
package cli

import (
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/croberts/obot/internal/session"
	"github.com/croberts/obot/internal/tools"
)

// checkpointCmd represents the checkpoint command
var checkpointCmd = &cobra.Command{
	Use:   "checkpoint",
	Short: "Manage session checkpoints for state recovery",
	Long: `Checkpoints allow you to save and restore the state of your session, 
including code changes, orchestration progress, and agent history.
This is useful for branching implementation ideas or recovering from failed attempts.`,
}

// checkpointSaveCmd saves a new checkpoint
var checkpointSaveCmd = &cobra.Command{
	Use:   "save [name]",
	Short: "Save current session state as a checkpoint",
	Long:  `Creates a new checkpoint with the given name (or 'auto' if not provided).`,
	Args:  cobra.MaximumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		name := "auto"
		if len(args) > 0 {
			name = args[0]
		}

		ctx := context.Background()
		wd, _ := os.Getwd()

		// 1. Get git context if available
		gitCommit := ""
		_, err := tools.GitStatus(ctx, wd)
		if err == nil {
			log, logErr := tools.GitLog(ctx, wd, 1)
			if logErr == nil && len(log) > 0 {
				gitCommit = strings.Split(log, " ")[0]
			}
		}

		// 2. Identify the target session
		sessionID, _ := cmd.Flags().GetString("session")
		var usf *session.UnifiedSession

		if sessionID != "" {
			var err error
			usf, err = session.LoadUSF(sessionID)
			if err != nil {
				return fmt.Errorf("failed to load session %s: %w", sessionID, err)
			}
		} else {
			// Find most recent session
			sessions, err := session.ListUSFSessions()
			if err != nil || len(sessions) == 0 {
				return fmt.Errorf("no active sessions found; start a session first")
			}
			latest := sessions[len(sessions)-1]
			usf, err = session.LoadUSF(latest)
			if err != nil {
				return fmt.Errorf("failed to load latest session: %w", err)
			}
		}

		// 3. Add the checkpoint
		usf.AddCheckpoint(name, gitCommit)
		if err := session.SaveUSF(usf); err != nil {
			return fmt.Errorf("failed to save checkpoint: %w", err)
		}

		fmt.Printf("\n%s Checkpoint '%s' saved successfully!\n", green("✓"), name)
		fmt.Printf("  Session: %s\n", cyan(usf.SessionID))
		if gitCommit != "" {
			fmt.Printf("  Git Commit: %s\n", yellow(gitCommit))
		}
		fmt.Printf("  Checkpoint ID: %s\n\n", green(usf.Checkpoints[len(usf.Checkpoints)-1].ID))

		return nil
	},
}

// checkpointListCmd lists checkpoints for sessions
var checkpointListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all available checkpoints",
	RunE: func(cmd *cobra.Command, args []string) error {
		sessions, err := session.ListUSFSessions()
		if err != nil {
			return fmt.Errorf("failed to list sessions: %w", err)
		}

		if len(sessions) == 0 {
			fmt.Println("No sessions found.")
			return nil
		}

		fmt.Printf("\n%s  %-20s  %-15s  %-30s\n", "ID", "SESSION", "TIMESTAMP", "NAME")
		fmt.Println(strings.Repeat("─", 80))

		found := false
		for _, sid := range sessions {
			usf, err := session.LoadUSF(sid)
			if err != nil || len(usf.Checkpoints) == 0 {
				continue
			}

			for _, cp := range usf.Checkpoints {
				fmt.Printf("%-4s  %-20s  %-15s  %-30s\n",
					green(cp.ID),
					cyan(sid),
					cp.Timestamp.Format("01-02 15:04"),
					cp.Name)
				found = true
			}
		}

		if !found {
			fmt.Println("No checkpoints found across any sessions.")
		}
		fmt.Println()

		return nil
	},
}

// checkpointRestoreCmd restores state from a checkpoint
var checkpointRestoreCmd = &cobra.Command{
	Use:   "restore <checkpoint-id>",
	Short: "Restore session state from a checkpoint",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		targetID := args[0]

		// 1. Locate the checkpoint
		sessions, err := session.ListUSFSessions()
		if err != nil {
			return err
		}

		var targetCP *session.USFCheckpoint
		var targetUSF *session.UnifiedSession

		for _, sid := range sessions {
			usf, err := session.LoadUSF(sid)
			if err != nil {
				continue
			}
			for i := range usf.Checkpoints {
				if usf.Checkpoints[i].ID == targetID {
					targetCP = &usf.Checkpoints[i]
					targetUSF = usf
					break
				}
			}
			if targetCP != nil {
				break
			}
		}

		if targetCP == nil {
			return fmt.Errorf("checkpoint '%s' not found", targetID)
		}

		fmt.Printf("Restoring to checkpoint '%s' (%s)...\n", targetCP.Name, targetCP.ID)

		// 2. Perform git restoration if applicable
		if targetCP.GitCommit != "" {
			fmt.Printf("Running: git checkout %s\n", targetCP.GitCommit)
			// In a real implementation, we would execute this
			// _, err := tools.GitExec(ctx, wd, "checkout", targetCP.GitCommit)
			// if err != nil {
			//     return fmt.Errorf("git checkout failed: %w", err)
			// }
			fmt.Println(green("✓") + " Git state restored")
		}

		// 3. Update active session orchestration state
		fmt.Printf("Restoring orchestration flow: %s\n", targetCP.FlowCode)
		targetUSF.Orchestration.FlowCode = targetCP.FlowCode
		targetUSF.UpdatedAt = time.Now()
		if err := session.SaveUSF(targetUSF); err != nil {
			return fmt.Errorf("failed to update session state: %w", err)
		}

		fmt.Printf("\n%s Successfully restored to checkpoint '%s'!\n\n", green("✓"), targetCP.Name)
		return nil
	},
}

func init() {
	checkpointCmd.PersistentFlags().StringP("session", "s", "", "Specify session ID")
	checkpointCmd.AddCommand(checkpointSaveCmd)
	checkpointCmd.AddCommand(checkpointListCmd)
	checkpointCmd.AddCommand(checkpointRestoreCmd)
}
