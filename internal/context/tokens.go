package context

import "strings"

// CountTokens estimates token count using the len/4 heuristic.
// Both CLI and IDE use simple heuristics; the inference latency dominates.
func CountTokens(text string) int {
	if text == "" {
		return 0
	}
	// Rough approximation: 1 token ≈ 4 characters for English text.
	return (len(text) + 3) / 4
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
	maxChars := maxTokens * 4
	if len(text) <= maxChars {
		return text
	}
	return text[:maxChars]
}
