package cli

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/spf13/cobra"

	"github.com/croberts/obot/internal/planner"
)

var (
	planMaxTasks    int
	planMaxFiles    int
	planMaxFileSize int64
	planJSON        bool
)

// planCmd builds a local plan without running the model
var planCmd = &cobra.Command{
	Use:   "plan [path] [instruction]",
	Short: "Generate a concrete fix plan from local context",
	Long: `Build a local plan by scanning files and TODO/FIXME markers.
No model calls are made. Useful for fast scoping before running fixes.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		session := startSession()
		defer session.Close()
		path := "."
		instruction := ""

		if len(args) > 0 {
			path = args[0]
		}
		if len(args) > 1 {
			instruction = strings.Join(args[1:], " ")
		}

		plan, err := planner.BuildPlan(path, instruction, planner.Options{
			MaxTasks:     planMaxTasks,
			MaxFiles:     planMaxFiles,
			MaxFileSize:  planMaxFileSize,
			IncludeHidden: false,
		})
		if err != nil {
			return err
		}
		session.Add("Generated plan", map[string]string{
			"root":          plan.Root,
			"fix_type":      string(plan.FixType),
			"files_scanned": fmt.Sprintf("%d", plan.FilesScanned),
			"tasks":         fmt.Sprintf("%d", len(plan.Tasks)),
		})

		if planJSON {
			data, err := json.MarshalIndent(plan, "", "  ")
			if err != nil {
				return err
			}
			fmt.Println(string(data))
			return nil
		}

		fmt.Print(planner.RenderText(plan))
		return nil
	},
}

func init() {
	planCmd.Flags().IntVar(&planMaxTasks, "max-tasks", 50, "Maximum tasks to include")
	planCmd.Flags().IntVar(&planMaxFiles, "max-files", 10, "Maximum files to consider")
	planCmd.Flags().Int64Var(&planMaxFileSize, "max-file-size", 1024*1024, "Skip files larger than this size (bytes)")
	planCmd.Flags().BoolVar(&planJSON, "json", false, "Output as JSON")
}
