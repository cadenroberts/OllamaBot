package cli

import "github.com/fatih/color"

var (
	primaryColor     = color.New(color.FgBlue)
	primaryBoldColor = color.New(color.FgBlue, color.Bold)

	blue    = color.New(color.FgBlue).SprintFunc()
	cyan    = color.New(color.FgCyan).SprintFunc()
	magenta = color.New(color.FgMagenta).SprintFunc()
	green   = color.New(color.FgGreen).SprintFunc()
	yellow  = color.New(color.FgYellow).SprintFunc()
	red     = color.New(color.FgRed).SprintFunc()
)
