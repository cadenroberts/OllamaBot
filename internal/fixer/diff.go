package fixer

import (
	"strings"

	"github.com/pmezard/go-difflib/difflib"
)

func UnifiedDiff(original, fixed, filename string, context int) string {
	if context < 0 {
		context = 0
	}
	if filename == "" {
		filename = "file"
	}

	diff := difflib.UnifiedDiff{
		A:        difflib.SplitLines(ensureTrailingNewline(original)),
		B:        difflib.SplitLines(ensureTrailingNewline(fixed)),
		FromFile: filename,
		ToFile:   filename,
		Context:  context,
	}

	text, err := difflib.GetUnifiedDiffString(diff)
	if err != nil {
		return ""
	}
	return text
}

func ensureTrailingNewline(text string) string {
	if text == "" {
		return ""
	}
	if strings.HasSuffix(text, "\n") {
		return text
	}
	return text + "\n"
}
