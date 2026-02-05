package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	versioninfo "github.com/croberts/obot/internal/version"
)

// versionCmd prints full version information
var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Show detailed version info",
	RunE: func(cmd *cobra.Command, args []string) error {
		fmt.Print(versioninfo.Full())
		return nil
	},
}
