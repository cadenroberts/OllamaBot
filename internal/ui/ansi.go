// Package ui implements the terminal UI for obot orchestration.
package ui

import (
	"fmt"
	"strings"
)

// OllamaBot Tokyo Night Theme - True Color (24-bit) ANSI codes
// Primary: #7dcfff (125, 207, 255) - Tokyo Cyan-Blue
// Background: #1a1b26 (26, 27, 38) - Dark background
// Secondary BG: #24283b (36, 40, 59) - Slightly lighter
// Text: #c0caf5 (192, 202, 245) - Light blue-white
// Muted: #565f89 (86, 95, 137) - Muted text
// Border: #3b4261 (59, 66, 97) - Border color
const (
	// Reset
	Reset = "\033[0m"

	// OllamaBot Tokyo Blue Theme - True Color
	TokyoBlue     = "\033[38;2;125;207;255m" // #7dcfff - Primary accent
	TokyoBlueBold = "\033[1;38;2;125;207;255m"
	TokyoBlueDim  = "\033[2;38;2;125;207;255m"

	// Text colors
	TextPrimary   = "\033[38;2;192;202;245m" // #c0caf5
	TextSecondary = "\033[38;2;154;165;206m" // #9aa5ce
	TextMuted     = "\033[38;2;86;95;137m"   // #565f89
	TextBorder    = "\033[38;2;59;66;97m"    // #3b4261

	// White variants
	White     = "\033[38;2;192;202;245m" // Use text primary as white
	WhiteBold = "\033[1;38;2;192;202;245m"
	WhiteDim  = "\033[2;38;2;192;202;245m"

	// Labels (Blue theme) - backwards compatible aliases
	BlueBold = TokyoBlueBold
	Blue     = TokyoBlue

	// Diff colors - keep green/red for visibility
	Green    = "\033[38;2;115;192;255m" // #73c0ff - Blue-tinted success
	Red      = "\033[38;2;255;85;85m"   // Bright red for deletions
	RedBold  = "\033[1;38;2;255;85;85m"
	DiffAdd  = "\033[38;2;158;206;106m" // #9ece6a - Green for additions
	DiffDel  = "\033[38;2;247;118;142m" // #f7768e - Red for deletions

	// Status colors
	Yellow = "\033[38;2;224;175;104m" // #e0af68 - Warm yellow
	Cyan   = TokyoBlue                // Use Tokyo Blue as cyan

	// Model-specific colors
	OrchestratorColor = "\033[38;2;122;162;247m" // #7aa2f7 - Royal blue
	CoderColor        = "\033[38;2;125;207;255m" // #7dcfff - Cyan blue
	ResearcherColor   = "\033[38;2;42;195;222m"  // #2ac3de - Teal blue
	VisionColor       = "\033[38;2;90;143;212m"  // #5a8fd4 - Steel blue

	// Flow code colors (specific to specification)
	FlowSchedule = WhiteBold          // White for S1-S5
	FlowProcess  = TokyoBlue          // Blue for P123
	FlowError    = "\033[38;2;247;118;142m" // Red for X

	// Background colors
	BgDark      = "\033[48;2;26;27;38m"  // #1a1b26
	BgSecondary = "\033[48;2;36;40;59m"  // #24283b
	BgSelection = "\033[48;2;51;70;124m" // #33467c

	// Cursor control
	CursorUp      = "\033[%dA"
	CursorDown    = "\033[%dB"
	CursorForward = "\033[%dC"
	CursorBack    = "\033[%dD"
	CursorSave    = "\033[s"
	CursorRestore = "\033[u"
	ClearLine     = "\033[2K"
	ClearToEnd    = "\033[K"
	CursorHome    = "\033[H"
	ClearScreen   = "\033[2J"

	// Hide/show cursor
	HideCursor = "\033[?25l"
	ShowCursor = "\033[?25h"

	// Bold/Dim modifiers
	Bold = "\033[1m"
	Dim  = "\033[2m"
)

// FormatLabel formats a label with Tokyo blue color
func FormatLabel(label string) string {
	return TokyoBlue + label + Reset
}

// FormatLabelBold formats a label with bold Tokyo blue color
func FormatLabelBold(label string) string {
	return TokyoBlueBold + label + Reset
}

// FormatBullet returns a Tokyo blue bullet separator
func FormatBullet() string {
	return TextMuted + " • " + Reset
}

// FormatValue formats a value (primary text color)
func FormatValue(value string) string {
	return TextPrimary + value + Reset
}

// FormatValueMuted formats a value with muted color
func FormatValueMuted(value string) string {
	return TextMuted + value + Reset
}

// FormatDiffAdd formats an addition line (green for visibility)
func FormatDiffAdd(lineNum int, content string) string {
	return fmt.Sprintf("%s+  %4d │ %s%s", DiffAdd, lineNum, content, Reset)
}

// FormatDiffDelete formats a deletion line (red for visibility)
func FormatDiffDelete(lineNum int, content string) string {
	return fmt.Sprintf("%s-  %4d │ %s%s", DiffDel, lineNum, content, Reset)
}

// FormatDiffContext formats a context line
func FormatDiffContext(lineNum int, content string) string {
	return fmt.Sprintf("%s   %4d │ %s%s", TextMuted, lineNum, content, Reset)
}

// FormatError formats an error message
func FormatError(message string) string {
	return FlowError + message + Reset
}

// FormatWarning formats a warning message
func FormatWarning(message string) string {
	return Yellow + message + Reset
}

// FormatSuccess formats a success message
func FormatSuccess(message string) string {
	return TokyoBlue + message + Reset
}

// FormatOrchestrator formats orchestrator text
func FormatOrchestrator(text string) string {
	return OrchestratorColor + text + Reset
}

// FormatCoder formats coder/agent text
func FormatCoder(text string) string {
	return CoderColor + text + Reset
}

// FormatResearcher formats researcher text
func FormatResearcher(text string) string {
	return ResearcherColor + text + Reset
}

// FormatVision formats vision text
func FormatVision(text string) string {
	return VisionColor + text + Reset
}

// FormatFlowCode formats a flow code with proper colors
// S = white, P = blue, X = red
func FormatFlowCode(code string) string {
	var result strings.Builder
	i := 0

	for i < len(code) {
		c := code[i]
		switch c {
		case 'S':
			result.WriteString(FlowSchedule)
			result.WriteByte(c)
			i++
			// Include schedule number
			if i < len(code) && code[i] >= '0' && code[i] <= '9' {
				result.WriteByte(code[i])
				i++
			}
			result.WriteString(Reset)
		case 'P':
			result.WriteString(FlowProcess)
			result.WriteByte(c)
			i++
			// Include all process numbers
			for i < len(code) && code[i] >= '0' && code[i] <= '9' {
				result.WriteByte(code[i])
				i++
			}
			result.WriteString(Reset)
		case 'X':
			result.WriteString(FlowError)
			result.WriteByte(c)
			result.WriteString(Reset)
			i++
		default:
			result.WriteByte(c)
			i++
		}
	}

	return result.String()
}

// MoveCursorUp moves cursor up n lines
func MoveCursorUp(n int) string {
	return fmt.Sprintf(CursorUp, n)
}

// MoveCursorDown moves cursor down n lines
func MoveCursorDown(n int) string {
	return fmt.Sprintf(CursorDown, n)
}

// MoveCursorForward moves cursor forward n columns
func MoveCursorForward(n int) string {
	return fmt.Sprintf(CursorForward, n)
}

// MoveCursorBack moves cursor back n columns
func MoveCursorBack(n int) string {
	return fmt.Sprintf(CursorBack, n)
}

// ProgressBar creates an ASCII progress bar
func ProgressBar(current, max float64, width int, filled, empty rune) string {
	if max <= 0 {
		return strings.Repeat(string(empty), width)
	}

	ratio := current / max
	if ratio > 1.0 {
		ratio = 1.0
	}
	if ratio < 0 {
		ratio = 0
	}

	filledCount := int(ratio * float64(width))
	emptyCount := width - filledCount

	return strings.Repeat(string(filled), filledCount) + strings.Repeat(string(empty), emptyCount)
}

// Box draws a box around content
func Box(content []string, width int) string {
	var sb strings.Builder

	// Top border
	sb.WriteString("┌")
	sb.WriteString(strings.Repeat("─", width-2))
	sb.WriteString("┐\n")

	// Content
	for _, line := range content {
		sb.WriteString("│ ")
		// Pad or truncate line
		if len(line) > width-4 {
			sb.WriteString(line[:width-4])
		} else {
			sb.WriteString(line)
			sb.WriteString(strings.Repeat(" ", width-4-len(line)))
		}
		sb.WriteString(" │\n")
	}

	// Bottom border
	sb.WriteString("└")
	sb.WriteString(strings.Repeat("─", width-2))
	sb.WriteString("┘\n")

	return sb.String()
}

// BoxWithTitle draws a box with a title
func BoxWithTitle(title string, content []string, width int) string {
	var sb strings.Builder

	// Top border with title
	titlePadded := " " + title + " "
	sideWidth := (width - 2 - len(titlePadded)) / 2
	sb.WriteString("┌")
	sb.WriteString(strings.Repeat("─", sideWidth))
	sb.WriteString(titlePadded)
	sb.WriteString(strings.Repeat("─", width-2-sideWidth-len(titlePadded)))
	sb.WriteString("┐\n")

	// Content
	for _, line := range content {
		sb.WriteString("│ ")
		if len(line) > width-4 {
			sb.WriteString(line[:width-4])
		} else {
			sb.WriteString(line)
			sb.WriteString(strings.Repeat(" ", width-4-len(line)))
		}
		sb.WriteString(" │\n")
	}

	// Bottom border
	sb.WriteString("└")
	sb.WriteString(strings.Repeat("─", width-2))
	sb.WriteString("┘\n")

	return sb.String()
}

// HorizontalLine creates a horizontal line with a separator character
func HorizontalLine(width int, char rune) string {
	return strings.Repeat(string(char), width)
}

// Separator returns a styled separator line
func Separator(width int) string {
	return Blue + strings.Repeat("─", width) + Reset
}
