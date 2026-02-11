package cli

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"

	"github.com/spf13/cobra"

	"github.com/croberts/obot/internal/review"
)

var (
	reviewMaxIssues   int
	reviewMaxFileSize int64
	reviewLineLength  int
	reviewJSON        bool
	reviewDiff        bool
	reviewTests       bool
)

// reviewCmd runs local review checks without model calls
var reviewCmd = &cobra.Command{
	Use:   "review [path]",
	Short: "Run lightweight local review checks",
	Long: `Scan files for concrete issues such as TODO/FIXME, long lines,
trailing whitespace, and missing newlines. Optionally runs tests 
or shows diffs. No model calls are made.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		session := startSession()
		defer session.Close()
		path := "."
		if len(args) > 0 {
			path = args[0]
		}

		if reviewDiff {
			fmt.Println(cyan("\n--- Reviewing Diffs ---"))
			// Use git to get staged changes
			diff, err := getStagedDiff()
			if err != nil {
				fmt.Printf("Error getting staged diff: %v\n", err)
			} else if diff == "" {
				fmt.Println("No staged changes found to review.")
			} else {
				fmt.Println(diff)
			}
		}

		if reviewTests {
			fmt.Println(cyan("\n--- Running Tests ---"))
			// Run project tests
			err := runProjectTests()
			if err != nil {
				fmt.Printf("%s Tests failed: %v\n", red("✗"), err)
			} else {
				fmt.Println(green("✓") + " All tests passed.")
			}
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
	reviewCmd.Flags().BoolVar(&reviewDiff, "diff", false, "Review staged changes (diff)")
	reviewCmd.Flags().BoolVar(&reviewTests, "tests", false, "Run project tests as part of review")
}

func getStagedDiff() (string, error) {
	cmd := exec.Command("git", "diff", "--cached", "--color=always")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", err
	}
	return string(output), nil
}

func runProjectTests() error {
	// Detect project type and run appropriate tests
	if _, err := os.Stat("go.mod"); err == nil {
		cmd := exec.Command("go", "test", "./...")
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		return cmd.Run()
	}
	if _, err := os.Stat("package.json"); err == nil {
		cmd := exec.Command("npm", "test")
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		return cmd.Run()
	}
	return fmt.Errorf("could not detect project type for testing")
}
