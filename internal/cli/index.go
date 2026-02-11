package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/croberts/obot/internal/index"
)

var indexCmd = &cobra.Command{
	Use:   "index",
	Short: "Manage the project code index",
	Long:  `Build and manage the local code index for fast search and symbol lookup.`,
}

var indexBuildCmd = &cobra.Command{
	Use:   "build [path]",
	Short: "Build or update the code index",
	Long:  `Walks the project directory and builds a JSON index of files and symbols.`,
	Args:  cobra.MaximumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		root := "."
		if len(args) > 0 {
			root = args[0]
		}

		printInfo(fmt.Sprintf("Building index for %s...", root))

		opts := index.DefaultOptions()
		idx := index.NewIndex(root)
		if err := idx.Build(cmd.Context(), opts); err != nil {
			return fmt.Errorf("failed to build index: %w", err)
		}

		if err := idx.Save(""); err != nil {
			return fmt.Errorf("failed to save index: %w", err)
		}

		stats := idx.GetStats()
		printSuccess(fmt.Sprintf("Index built successfully! (%d files indexed)", stats.TotalFiles))
		
		return nil
	},
}

func init() {
	indexCmd.AddCommand(indexBuildCmd)
	rootCmd.AddCommand(indexCmd)
}
