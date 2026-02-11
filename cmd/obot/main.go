// Package main is the entry point for the obot CLI binary.
package main

import (
	"os"

	"github.com/croberts/obot/internal/cli"
	"github.com/croberts/obot/internal/version"
)

// Build-time variables injected via -ldflags.
var (
	Version = "dev"
	Commit  = "none"
	Date    = "unknown"
	BuiltBy = "unknown"
)

func main() {
	version.Set(version.Info{
		Version: Version,
		Commit:  Commit,
		Date:    Date,
		BuiltBy: BuiltBy,
	})
	cli.SetVersion(Version)

	if err := cli.Execute(); err != nil {
		os.Exit(1)
	}
}
