package agent

import (
	"sort"
	"strings"

	"github.com/pmezard/go-difflib/difflib"
)

// Edit represents a file edit operation
type Edit struct {
	StartLine  int
	EndLine    int
	OldContent string
	NewContent string
}

// computeDiff uses go-difflib for unified diff and converts to obot style.
func computeDiff(oldContent, newContent string) *DiffSummary {
	oldLines := difflib.SplitLines(oldContent)
	newLines := difflib.SplitLines(newContent)

	summary := &DiffSummary{
		Additions:   make([]DiffLine, 0),
		Deletions:   make([]DiffLine, 0),
		Context:     make([]DiffLine, 0),
		Interleaved: make([]DiffLine, 0),
	}

	m := difflib.NewMatcher(oldLines, newLines)
	for _, op := range m.GetOpCodes() {
		switch op.Tag {
		case 'e': // equal
			for i := op.I1; i < op.I2; i++ {
				dl := DiffLine{
					LineNumber: i + 1,
					Content:    oldLines[i],
					Type:       DiffLineContext,
				}
				summary.Context = append(summary.Context, dl)
				summary.Interleaved = append(summary.Interleaved, dl)
			}
		case 'd': // delete
			for i := op.I1; i < op.I2; i++ {
				dl := DiffLine{
					LineNumber: i + 1,
					Content:    oldLines[i],
					Type:       DiffLineDelete,
				}
				summary.Deletions = append(summary.Deletions, dl)
				summary.Interleaved = append(summary.Interleaved, dl)
				summary.TotalRemoved++
			}
		case 'i': // insert
			for i := op.J1; i < op.J2; i++ {
				dl := DiffLine{
					LineNumber: i + 1,
					Content:    newLines[i],
					Type:       DiffLineAdd,
				}
				summary.Additions = append(summary.Additions, dl)
				summary.Interleaved = append(summary.Interleaved, dl)
				summary.TotalAdded++
			}
		case 'r': // replace
			// For small replacements (single line), perform character-level diffing
			if op.I2-op.I1 == 1 && op.J2-op.J1 == 1 {
				oldLine := oldLines[op.I1]
				newLine := newLines[op.J1]

				diffedOld, diffedNew := computeCharDiff(oldLine, newLine)

				dlDel := DiffLine{
					LineNumber: op.I1 + 1,
					Content:    diffedOld,
					Type:       DiffLineDelete,
				}
				summary.Deletions = append(summary.Deletions, dlDel)
				summary.Interleaved = append(summary.Interleaved, dlDel)
				summary.TotalRemoved++

				dlAdd := DiffLine{
					LineNumber: op.J1 + 1,
					Content:    diffedNew,
					Type:       DiffLineAdd,
				}
				summary.Additions = append(summary.Additions, dlAdd)
				summary.Interleaved = append(summary.Interleaved, dlAdd)
				summary.TotalAdded++
			} else {
				for i := op.I1; i < op.I2; i++ {
					dl := DiffLine{
						LineNumber: i + 1,
						Content:    oldLines[i],
						Type:       DiffLineDelete,
					}
					summary.Deletions = append(summary.Deletions, dl)
					summary.Interleaved = append(summary.Interleaved, dl)
					summary.TotalRemoved++
				}
				for i := op.J1; i < op.J2; i++ {
					dl := DiffLine{
						LineNumber: i + 1,
						Content:    newLines[i],
						Type:       DiffLineAdd,
					}
					summary.Additions = append(summary.Additions, dl)
					summary.Interleaved = append(summary.Interleaved, dl)
					summary.TotalAdded++
				}
			}
		}
	}

	return summary
}

// computeCharDiff performs character-level diffing between two strings.
// It returns the strings with ANSI escape codes for highlighting differences.
func computeCharDiff(oldLine, newLine string) (string, string) {
	oldChars := strings.Split(oldLine, "")
	newChars := strings.Split(newLine, "")

	m := difflib.NewMatcher(oldChars, newChars)
	var oldRes, newRes strings.Builder

	// ANSI constants (local to avoid dependency on ui package)
	const (
		reset     = "\033[0m"
		redBg     = "\033[41;37m" // Red background, white text
		greenBg   = "\033[42;30m" // Green background, black text
		redUnder  = "\033[4;31m"  // Red underline
		greenUnder = "\033[4;32m" // Green underline
	)

	for _, op := range m.GetOpCodes() {
		switch op.Tag {
		case 'e': // equal
			for i := op.I1; i < op.I2; i++ {
				oldRes.WriteString(oldChars[i])
				newRes.WriteString(oldChars[i])
			}
		case 'd': // delete
			oldRes.WriteString(redUnder)
			for i := op.I1; i < op.I2; i++ {
				oldRes.WriteString(oldChars[i])
			}
			oldRes.WriteString(reset)
		case 'i': // insert
			newRes.WriteString(greenUnder)
			for i := op.J1; i < op.J2; i++ {
				newRes.WriteString(newChars[i])
			}
			newRes.WriteString(reset)
		case 'r': // replace
			oldRes.WriteString(redUnder)
			for i := op.I1; i < op.I2; i++ {
				oldRes.WriteString(oldChars[i])
			}
			oldRes.WriteString(reset)

			newRes.WriteString(greenUnder)
			for i := op.J1; i < op.J2; i++ {
				newRes.WriteString(newChars[i])
			}
			newRes.WriteString(reset)
		}
	}

	return oldRes.String(), newRes.String()
}

// computeLineRanges merged line ranges using max overlap algorithm.
func computeLineRanges(edits []Edit) []LineRange {
	if len(edits) == 0 {
		return nil
	}

	// Sort edits by start line
	sorted := make([]Edit, len(edits))
	copy(sorted, edits)
	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].StartLine < sorted[j].StartLine
	})

	// Merge overlapping ranges
	ranges := make([]LineRange, 0)
	current := LineRange{Start: sorted[0].StartLine, End: sorted[0].EndLine}

	for i := 1; i < len(sorted); i++ {
		edit := sorted[i]
		if edit.StartLine <= current.End+1 {
			// Merge
			if edit.EndLine > current.End {
				current.End = edit.EndLine
			}
		} else {
			// New range
			ranges = append(ranges, current)
			current = LineRange{Start: edit.StartLine, End: edit.EndLine}
		}
	}
	ranges = append(ranges, current)

	return ranges
}

// ComputeDiffFromEdits computes a diff summary from a list of edits.
func ComputeDiffFromEdits(edits []Edit) *DiffSummary {
	summary := &DiffSummary{
		Additions:   make([]DiffLine, 0),
		Deletions:   make([]DiffLine, 0),
		Context:     make([]DiffLine, 0),
		Interleaved: make([]DiffLine, 0),
	}
	for _, edit := range edits {
		if edit.OldContent != "" {
			lines := splitLines(edit.OldContent)
			for i, line := range lines {
				dl := DiffLine{
					LineNumber: edit.StartLine + i,
					Content:    line,
					Type:       DiffLineDelete,
				}
				summary.Deletions = append(summary.Deletions, dl)
				summary.Interleaved = append(summary.Interleaved, dl)
			}
			summary.TotalRemoved += len(lines)
		}
		if edit.NewContent != "" {
			lines := splitLines(edit.NewContent)
			for i, line := range lines {
				dl := DiffLine{
					LineNumber: edit.StartLine + i,
					Content:    line,
					Type:       DiffLineAdd,
				}
				summary.Additions = append(summary.Additions, dl)
				summary.Interleaved = append(summary.Interleaved, dl)
			}
			summary.TotalAdded += len(lines)
		}
	}
	return summary
}

// RenderInterleaved returns the interleaved diff as a formatted string.
func (ds *DiffSummary) RenderInterleaved() string {
	var result strings.Builder
	for _, line := range ds.Interleaved {
		switch line.Type {
		case DiffLineAdd:
			result.WriteString("+ " + line.Content + "\n")
		case DiffLineDelete:
			result.WriteString("- " + line.Content + "\n")
		case DiffLineContext:
			result.WriteString("  " + line.Content + "\n")
		}
	}
	return result.String()
}

// splitLines splits a string into lines
func splitLines(s string) []string {
	if s == "" {
		return nil
	}

	lines := make([]string, 0)
	start := 0
	for i := 0; i < len(s); i++ {
		if s[i] == '\n' {
			lines = append(lines, s[start:i])
			start = i + 1
		}
	}
	if start < len(s) {
		lines = append(lines, s[start:])
	}
	return lines
}
