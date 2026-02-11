package context

import (
	"strings"

	"github.com/pkoukk/tiktoken-go"
)

// CountTokens counts tokens using the cl100k_base encoding (tiktoken).
func CountTokens(text string) int {
	if text == "" {
		return 0
	}

	tke, err := tiktoken.GetEncoding("cl100k_base")
	if err != nil {
		// Fallback to heuristic if tiktoken fails
		return (len(text) + 3) / 4
	}

	tokens := tke.Encode(text, nil, nil)
	return len(tokens)
}

// CountTokensLines counts tokens across multiple lines.
func CountTokensLines(lines []string) int {
	return CountTokens(strings.Join(lines, "\n"))
}

// TruncateToTokens truncates text to approximately maxTokens.
func TruncateToTokens(text string, maxTokens int) string {
	if maxTokens <= 0 {
		return ""
	}

	tke, err := tiktoken.GetEncoding("cl100k_base")
	if err != nil {
		// Fallback to heuristic
		maxChars := maxTokens * 4
		if len(text) <= maxChars {
			return text
		}
		return text[:maxChars]
	}

	tokens := tke.Encode(text, nil, nil)
	if len(tokens) <= maxTokens {
		return text
	}

	truncatedTokens := tokens[:maxTokens]
	return tke.Decode(truncatedTokens)
}
