package ui

import (
	"fmt"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/croberts/obot/internal/agent"
)

// DiffPreviewWidget displays file changes before they are applied with syntax highlighting.
type DiffPreviewWidget struct {
	Width int
}

// NewDiffPreviewWidget creates a new DiffPreviewWidget.
func NewDiffPreviewWidget(width int) *DiffPreviewWidget {
	if width <= 0 {
		width = 100
	}
	return &DiffPreviewWidget{Width: width}
}

// Render formats a DiffSummary into a styled terminal string.
func (p *DiffPreviewWidget) Render(path string, diff *agent.DiffSummary) string {
	if diff == nil {
		return Yellow(" No changes to preview for: " + path)
	}

	var sb strings.Builder

	// Summary line
	summary := fmt.Sprintf(" %s %s %s",
		FormatLabelBold("PREVIEW"),
		FormatValue(path),
		fmt.Sprintf("(%s, %s)",
			Green(fmt.Sprintf("+%d", diff.TotalAdded)),
			Red(fmt.Sprintf("-%d", diff.TotalRemoved))))

	sb.WriteString("\n" + summary + "\n")
	sb.WriteString(Separator(p.Width) + "\n")

	ext := strings.ToLower(filepath.Ext(path))

	// Group changes by type for clarity in preview
	if len(diff.Deletions) > 0 {
		for _, line := range diff.Deletions {
			sb.WriteString(FormatDiffDelete(line.LineNumber, p.highlight(line.Content, ext)) + "\n")
		}
	}
	if len(diff.Additions) > 0 {
		for _, line := range diff.Additions {
			sb.WriteString(FormatDiffAdd(line.LineNumber, p.highlight(line.Content, ext)) + "\n")
		}
	}

	sb.WriteString(Separator(p.Width) + "\n")
	return sb.String()
}

// highlight applies basic syntax highlighting to a line of code using regex.
func (p *DiffPreviewWidget) highlight(line string, ext string) string {
	if line == "" {
		return ""
	}

	// Define keywords for common languages
	var kwPattern string
	switch ext {
	case ".go":
		kwPattern = `\b(package|import|func|type|struct|interface|var|const|if|else|for|range|return|nil|error|string|int|bool|make|map|chan|go|select|case|default|defer|panic|recover)\b`
	case ".py":
		kwPattern = `\b(def|class|if|else|elif|for|while|return|yield|import|from|as|try|except|finally|with|pass|break|continue|lambda|in|is|and|or|not|None|True|False)\b`
	case ".swift":
		kwPattern = `\b(import|class|struct|enum|protocol|extension|func|var|let|if|else|guard|switch|case|default|return|self|init|try|catch|throw|throws|await|async|public|private|internal|fileprivate|static)\b`
	case ".md":
		if strings.HasPrefix(strings.TrimSpace(line), "#") {
			return TokyoBlueBold + line + ANSIReset
		}
		return line
	}

	highlighted := line

	// Highlight keywords
	if kwPattern != "" {
		reKw := regexp.MustCompile(kwPattern)
		highlighted = reKw.ReplaceAllString(highlighted, TokyoBlueBold+"$1"+ANSIReset)
	}

	// Highlight strings
	reStr := regexp.MustCompile(`"[^"]*"|'[^']*'`)
	highlighted = reStr.ReplaceAllStringFunc(highlighted, func(s string) string {
		return ANSIYellow + s + ANSIReset
	})

	// Highlight comments
	var commentPrefix string
	switch ext {
	case ".go", ".swift", ".js", ".ts", ".cpp", ".c":
		commentPrefix = "//"
	case ".py", ".sh", ".yaml", ".yml", ".rb":
		commentPrefix = "#"
	}

	if commentPrefix != "" {
		if idx := strings.Index(highlighted, commentPrefix); idx != -1 {
			// Ensure we don't highlight a comment prefix inside a string
			// This is a simplified check
			if !p.isInString(highlighted, idx) {
				highlighted = highlighted[:idx] + TextMuted + highlighted[idx:] + ANSIReset
			}
		}
	}

	return highlighted
}

// isInString is a very basic check to see if a position is likely inside a string.
func (p *DiffPreviewWidget) isInString(line string, pos int) bool {
	inQuote := false
	for i, char := range line {
		if i >= pos {
			break
		}
		if char == '"' || char == '\'' {
			inQuote = !inQuote
		}
	}
	return inQuote
}

// RenderDiffView renders a full diff view within a box.
func (p *DiffPreviewWidget) RenderDiffView(title string, diffLines []string) string {
	return BoxWithTitle(title, diffLines, p.Width)
}
