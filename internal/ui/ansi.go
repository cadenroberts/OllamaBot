// Package ui implements the terminal UI for obot orchestration.
package ui

import (
	"fmt"
	"strings"
)

// OllamaBot Tokyo Night Theme - True Color (24-bit) ANSI codes
const (
	// Reset
	ANSIReset = "\033[0m"
	Reset     = ANSIReset

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
	ANSIWhite     = "\033[38;2;192;202;245m"
	ANSIWhiteBold = "\033[1;38;2;192;202;245m"
	ANSIWhiteDim  = "\033[2;38;2;192;202;245m"

	// Blue variants
	ANSIBlue     = TokyoBlue
	ANSIBlueBold = TokyoBlueBold

	// Green variants
	ANSIGreen = "\033[38;2;115;192;255m" // #73c0ff - Blue-tinted success

	// Red variants
	ANSIRed     = "\033[38;2;255;85;85m" // Bright red for deletions
	ANSIRedBold = "\033[1;38;2;255;85;85m"

	// Status colors
	ANSIYellow = "\033[38;2;224;175;104m" // #e0af68 - Warm yellow
	ANSICyan   = TokyoBlue                // Use Tokyo Blue as cyan

	// Model-specific colors
	OrchestratorColor = "\033[38;2;122;162;247m" // #7aa2f7 - Royal blue
	CoderColor        = "\033[38;2;125;207;255m" // #7dcfff - Cyan blue
	ResearcherColor   = "\033[38;2;42;195;222m"  // #2ac3de - Teal blue
	VisionColor       = "\033[38;2;90;143;212m"  // #5a8fd4 - Steel blue

	// Flow code colors
	FlowSchedule = ANSIWhiteBold
	FlowProcess  = TokyoBlue
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
	ANSIBold = "\033[1m"
	Bold     = ANSIBold
	ANSIDim  = "\033[2m"
	Dim      = ANSIDim
)

// Color wraps text with a color code and reset
func Color(color, text string) string {
	return color + text + ANSIReset
}

// Blue formats text with Tokyo blue color
func Blue(text string) string {
	return Color(ANSIBlue, text)
}

// BoldBlue formats text with bold Tokyo blue color
func BoldBlue(text string) string {
	return Color(ANSIBlueBold, text)
}

// Green formats text with green color
func Green(text string) string {
	return Color(ANSIGreen, text)
}

// Red formats text with red color
func Red(text string) string {
	return Color(ANSIRed, text)
}

// Yellow formats text with yellow color
func Yellow(text string) string {
	return Color(ANSIYellow, text)
}

// White formats text with white color
func White(text string) string {
	return Color(ANSIWhite, text)
}

// BoldWhite formats text with bold white color
func BoldWhite(text string) string {
	return Color(ANSIWhiteBold, text)
}

// FormatLabel formats a label with Tokyo blue color
func FormatLabel(label string) string {
	return ANSIBlue + label + ANSIReset
}

// FormatLabelBold formats a label with bold Tokyo blue color
func FormatLabelBold(label string) string {
	return ANSIBlueBold + label + ANSIReset
}

// FormatBullet returns a Tokyo blue bullet separator
func FormatBullet() string {
	return TextMuted + " • " + ANSIReset
}

// FormatValue formats a value (primary text color)
func FormatValue(value string) string {
	return TextPrimary + value + ANSIReset
}

// FormatValueMuted formats a value with muted color
func FormatValueMuted(value string) string {
	return TextMuted + value + ANSIReset
}

// FormatDiffAdd formats an addition line
func FormatDiffAdd(lineNum int, content string) string {
	return fmt.Sprintf("%s+  %4d │ %s%s", ANSIGreen, lineNum, content, ANSIReset)
}

// FormatDiffDelete formats a deletion line
func FormatDiffDelete(lineNum int, content string) string {
	return fmt.Sprintf("%s-  %4d │ %s%s", ANSIRed, lineNum, content, ANSIReset)
}

// FormatDiffContext formats a context line
func FormatDiffContext(lineNum int, content string) string {
	return fmt.Sprintf("%s   %4d │ %s%s", TextMuted, lineNum, content, ANSIReset)
}

// FormatError formats an error message
func FormatError(message string) string {
	return FlowError + message + ANSIReset
}

// FormatWarning formats a warning message
func FormatWarning(message string) string {
	return ANSIYellow + message + ANSIReset
}

// FormatSuccess formats a success message
func FormatSuccess(message string) string {
	return ANSIBlue + message + ANSIReset
}

// FormatOrchestrator formats orchestrator text
func FormatOrchestrator(text string) string {
	return OrchestratorColor + text + ANSIReset
}

// FormatCoder formats coder/agent text
func FormatCoder(text string) string {
	return CoderColor + text + ANSIReset
}

// FormatResearcher formats researcher text
func FormatResearcher(text string) string {
	return ResearcherColor + text + ANSIReset
}

// FormatVision formats vision text
func FormatVision(text string) string {
	return VisionColor + text + ANSIReset
}

// FormatFlowCode formats a flow code with proper colors
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
			if i < len(code) && code[i] >= '0' && code[i] <= '9' {
				result.WriteByte(code[i])
				i++
			}
			result.WriteString(ANSIReset)
		case 'P':
			result.WriteString(FlowProcess)
			result.WriteByte(c)
			i++
			for i < len(code) && code[i] >= '0' && code[i] <= '9' {
				result.WriteByte(code[i])
				i++
			}
			result.WriteString(ANSIReset)
		case 'X':
			result.WriteString(FlowError)
			result.WriteByte(c)
			result.WriteString(ANSIReset)
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

// ClearScreenFunc returns the ANSI code to clear the entire screen
func ClearScreenFunc() string {
	return ClearScreen
}

// CursorHomeFunc returns the ANSI code to move cursor to home position
func CursorHomeFunc() string {
	return CursorHome
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
	sb.WriteString("┌")
	sb.WriteString(strings.Repeat("─", width-2))
	sb.WriteString("┐\n")
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
	sb.WriteString("└")
	sb.WriteString(strings.Repeat("─", width-2))
	sb.WriteString("┘\n")
	return sb.String()
}

// BoxWithTitle draws a box with a title
func BoxWithTitle(title string, content []string, width int) string {
	var sb strings.Builder
	titlePadded := " " + title + " "
	sideWidth := (width - 2 - len(titlePadded)) / 2
	sb.WriteString("┌")
	sb.WriteString(strings.Repeat("─", sideWidth))
	sb.WriteString(titlePadded)
	sb.WriteString(strings.Repeat("─", width-2-sideWidth-len(titlePadded)))
	sb.WriteString("┐\n")
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
	sb.WriteString("└")
	sb.WriteString(strings.Repeat("─", width-2))
	sb.WriteString("┘\n")
	return sb.String()
}

// HorizontalLine creates a horizontal line
func HorizontalLine(width int, char rune) string {
	return strings.Repeat(string(char), width)
}

// Separator returns a styled separator line
func Separator(width int) string {
	return ANSIBlue + strings.Repeat("─", width) + ANSIReset
}
