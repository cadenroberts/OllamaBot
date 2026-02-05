package fixer

import (
	"regexp"
	"strings"

	"github.com/croberts/obot/internal/analyzer"
)

// ExtractCode extracts code from a model response
// Handles various response formats including code blocks
func ExtractCode(response string, lang analyzer.Language) string {
	response = strings.TrimSpace(response)

	// Try to extract from markdown code blocks
	if code := extractFromCodeBlock(response, lang); code != "" {
		return code
	}

	// Try to extract from generic code blocks
	if code := extractFromGenericCodeBlock(response); code != "" {
		return code
	}

	// If no code block, clean up the response
	return cleanResponse(response)
}

// extractFromCodeBlock extracts code from a markdown code block with language tag
func extractFromCodeBlock(response string, lang analyzer.Language) string {
	// Pattern: ```language\ncode\n```
	patterns := []string{
		// Specific language
		"(?s)```" + string(lang) + "\\s*\\n(.+?)\\n?```",
		// Common aliases
		"(?s)```" + langAlias(lang) + "\\s*\\n(.+?)\\n?```",
	}

	for _, pattern := range patterns {
		re := regexp.MustCompile(pattern)
		matches := re.FindStringSubmatch(response)
		if len(matches) > 1 {
			return strings.TrimSpace(matches[1])
		}
	}

	return ""
}

// extractFromGenericCodeBlock extracts code from any code block
func extractFromGenericCodeBlock(response string) string {
	// Pattern: ```\ncode\n``` or ```language\ncode\n```
	re := regexp.MustCompile("(?s)```(?:[a-z]+)?\\s*\\n(.+?)\\n?```")
	matches := re.FindStringSubmatch(response)
	if len(matches) > 1 {
		return strings.TrimSpace(matches[1])
	}

	return ""
}

// cleanResponse removes common artifacts from model responses
func cleanResponse(response string) string {
	// Remove "Here's the fixed code:" type prefixes
	prefixes := []string{
		"here's the fixed code:",
		"here is the fixed code:",
		"fixed code:",
		"corrected code:",
		"the fixed code is:",
		"output:",
	}

	lower := strings.ToLower(response)
	for _, prefix := range prefixes {
		if idx := strings.Index(lower, prefix); idx != -1 {
			response = response[idx+len(prefix):]
			break
		}
	}

	// Remove trailing explanations after the code
	// Look for common patterns that indicate explanation
	suffixes := []string{
		"\n\nthis fixes",
		"\n\nthe changes",
		"\n\ni've fixed",
		"\n\ni fixed",
		"\n\nexplanation:",
		"\n\nnote:",
		"\n\nchanges made:",
	}

	lower = strings.ToLower(response)
	for _, suffix := range suffixes {
		if idx := strings.Index(lower, suffix); idx != -1 {
			response = response[:idx]
			break
		}
	}

	return strings.TrimSpace(response)
}

// langAlias returns common aliases for a language
func langAlias(lang analyzer.Language) string {
	switch lang {
	case analyzer.LangJavaScript:
		return "js"
	case analyzer.LangTypeScript:
		return "ts"
	case analyzer.LangPython:
		return "py"
	case analyzer.LangShell:
		return "bash"
	case analyzer.LangCPP:
		return "c\\+\\+"
	default:
		return string(lang)
	}
}

// HasCodeChanges checks if the response contains actual code changes
func HasCodeChanges(original, fixed string) bool {
	// Normalize whitespace for comparison
	origNorm := normalizeWhitespace(original)
	fixedNorm := normalizeWhitespace(fixed)

	return origNorm != fixedNorm
}

// normalizeWhitespace normalizes whitespace for comparison
func normalizeWhitespace(s string) string {
	// Replace multiple whitespace with single space
	re := regexp.MustCompile(`\s+`)
	return strings.TrimSpace(re.ReplaceAllString(s, " "))
}

// DiffSummary returns a brief summary of changes
func DiffSummary(original, fixed string) string {
	origLines := strings.Split(original, "\n")
	fixedLines := strings.Split(fixed, "\n")

	added := 0
	removed := 0
	changed := 0

	// Simple line-based diff
	maxLen := len(origLines)
	if len(fixedLines) > maxLen {
		maxLen = len(fixedLines)
	}

	for i := 0; i < maxLen; i++ {
		var origLine, fixedLine string
		if i < len(origLines) {
			origLine = origLines[i]
		}
		if i < len(fixedLines) {
			fixedLine = fixedLines[i]
		}

		if origLine == "" && fixedLine != "" {
			added++
		} else if origLine != "" && fixedLine == "" {
			removed++
		} else if origLine != fixedLine {
			changed++
		}
	}

	var parts []string
	if added > 0 {
		parts = append(parts, strings.TrimSpace(strings.Repeat("+", 1))+" "+strings.TrimSpace(string(rune('0'+added)))+" added")
	}
	if removed > 0 {
		parts = append(parts, strings.TrimSpace(strings.Repeat("-", 1))+" "+strings.TrimSpace(string(rune('0'+removed)))+" removed")
	}
	if changed > 0 {
		parts = append(parts, strings.TrimSpace(string(rune('0'+changed)))+" changed")
	}

	if len(parts) == 0 {
		return "no changes"
	}

	return strings.Join(parts, ", ")
}
