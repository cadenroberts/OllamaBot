package context

import (
	"strings"
)

// CompressionStrategy defines how content is compressed.
type CompressionStrategy string

const (
	// StrategySemanticTruncate preserves imports/signatures/errors, truncates body.
	StrategySemanticTruncate CompressionStrategy = "semantic_truncate"
)

// Compressor compresses file content to fit within token budgets.
type Compressor struct {
	Strategy CompressionStrategy
	Preserve []string // sections to preserve: imports, exports, signatures, errors
}

// NewCompressor creates a compressor from config.
func NewCompressor(strategy string, preserve []string) *Compressor {
	s := StrategySemanticTruncate
	if strategy != "" {
		s = CompressionStrategy(strategy)
	}
	return &Compressor{
		Strategy: s,
		Preserve: preserve,
	}
}

// Compress reduces content to fit within maxTokens.
func (c *Compressor) Compress(content string, maxTokens int) string {
	if CountTokens(content) <= maxTokens {
		return content
	}

	switch c.Strategy {
	case StrategySemanticTruncate:
		return c.semanticTruncate(content, maxTokens)
	default:
		return TruncateToTokens(content, maxTokens)
	}
}

// semanticTruncate preserves high-value sections and truncates the rest.
func (c *Compressor) semanticTruncate(content string, maxTokens int) string {
	lines := strings.Split(content, "\n")

	// Phase 1: Extract preserved sections
	preserved := make([]string, 0)
	body := make([]string, 0)

	for _, line := range lines {
		if c.isPreservedLine(line) {
			preserved = append(preserved, line)
		} else {
			body = append(body, line)
		}
	}

	// Phase 2: Allocate tokens
	preservedText := strings.Join(preserved, "\n")
	preservedTokens := CountTokens(preservedText)

	remainingTokens := maxTokens - preservedTokens
	if remainingTokens <= 0 {
		return TruncateToTokens(preservedText, maxTokens)
	}

	// Phase 3: Fill remaining budget with body lines
	var result strings.Builder
	result.WriteString(preservedText)
	if len(preserved) > 0 {
		result.WriteString("\n\n// ... compressed ...\n\n")
	}

	usedTokens := preservedTokens + 4 // account for separator
	for _, line := range body {
		lineTokens := CountTokens(line)
		if usedTokens+lineTokens > maxTokens {
			result.WriteString("\n// ... truncated ...")
			break
		}
		result.WriteString(line)
		result.WriteString("\n")
		usedTokens += lineTokens
	}

	return result.String()
}

// isPreservedLine checks if a line matches any preserve rule.
func (c *Compressor) isPreservedLine(line string) bool {
	trimmed := strings.TrimSpace(line)
	for _, rule := range c.Preserve {
		switch rule {
		case "imports":
			if strings.HasPrefix(trimmed, "import ") || strings.HasPrefix(trimmed, "from ") ||
				strings.HasPrefix(trimmed, "require(") || strings.HasPrefix(trimmed, "use ") ||
				strings.HasPrefix(trimmed, "#include") {
				return true
			}
		case "exports":
			if strings.HasPrefix(trimmed, "export ") || strings.HasPrefix(trimmed, "module.exports") {
				return true
			}
		case "signatures":
			if strings.HasPrefix(trimmed, "func ") || strings.HasPrefix(trimmed, "def ") ||
				strings.HasPrefix(trimmed, "class ") || strings.HasPrefix(trimmed, "type ") ||
				strings.HasPrefix(trimmed, "interface ") || strings.HasPrefix(trimmed, "struct ") ||
				strings.HasPrefix(trimmed, "pub fn ") || strings.HasPrefix(trimmed, "fn ") {
				return true
			}
		case "errors":
			if strings.Contains(trimmed, "error") || strings.Contains(trimmed, "Error") ||
				strings.Contains(trimmed, "TODO") || strings.Contains(trimmed, "FIXME") ||
				strings.Contains(trimmed, "HACK") || strings.Contains(trimmed, "BUG") {
				return true
			}
		}
	}
	return false
}
