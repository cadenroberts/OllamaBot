package cli

import (
	"encoding/json"
	"fmt"

	"github.com/spf13/cobra"

	"github.com/croberts/obot/internal/review"
)

var (
	reviewMaxIssues   int
	reviewMaxFileSize int64
	reviewLineLength  int
	reviewJSON        bool
)

// reviewCmd runs local review checks without model calls
var reviewCmd = &cobra.Command{
	Use:   "review [path]",
	Short: "Run lightweight local review checks",
	Long: `Scan files for concrete issues such as TODO/FIXME, long lines,
trailing whitespace, and missing newlines. No model calls are made.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		session := startSession()
		defer session.Close()
		path := "."
		if len(args) > 0 {
			path = args[0]
		}

		issues, err := review.ScanPath(path, review.Options{
			MaxFileSize:  reviewMaxFileSize,
			MaxIssues:    reviewMaxIssues,
			LineLength:   reviewLineLength,
			IncludeHidden: false,
		})
		if err != nil {
			return err
		}
		session.Add("Completed review scan", map[string]string{
			"path":     path,
			"issues":   fmt.Sprintf("%d", len(issues)),
			"max_issues": fmt.Sprintf("%d", reviewMaxIssues),
		})

		if reviewJSON {
			data, err := json.MarshalIndent(issues, "", "  ")
			if err != nil {
				return err
			}
			fmt.Println(string(data))
			return nil
		}

		fmt.Print(review.RenderText(issues, path))
		return nil
	},
}

func init() {
	reviewCmd.Flags().IntVar(&reviewMaxIssues, "max-issues", 200, "Maximum issues to report")
	reviewCmd.Flags().Int64Var(&reviewMaxFileSize, "max-file-size", 1024*1024, "Skip files larger than this size (bytes)")
	reviewCmd.Flags().IntVar(&reviewLineLength, "line-length", 120, "Maximum line length")
	reviewCmd.Flags().BoolVar(&reviewJSON, "json", false, "Output as JSON")
}
