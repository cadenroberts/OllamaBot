package cli

import "github.com/fatih/color"

var (
	primaryColor     = color.New(color.FgBlue)
	primaryBoldColor = color.New(color.FgBlue, color.Bold)

	cyan    = primaryColor.SprintFunc()
	magenta = primaryColor.SprintFunc()
	green   = color.New(color.FgGreen).SprintFunc()
	yellow  = color.New(color.FgYellow).SprintFunc()
	red     = color.New(color.FgRed).SprintFunc()
)
