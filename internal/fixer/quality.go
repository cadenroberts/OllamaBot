package fixer

import (
	"fmt"
	"strings"

	"github.com/croberts/obot/internal/analyzer"
)

type QualityReport struct {
	Warnings []string
	Metrics  map[string]string
}

func (r QualityReport) Ok() bool {
	return len(r.Warnings) == 0
}

func (r QualityReport) Summary(max int) string {
	if len(r.Warnings) == 0 {
		return "no issues"
	}
	if max <= 0 || len(r.Warnings) <= max {
		return strings.Join(r.Warnings, "; ")
	}
	return strings.Join(r.Warnings[:max], "; ") + "..."
}

func QuickReview(original, fixed string, lang analyzer.Language) QualityReport {
	warnings := make([]string, 0, 4)
	metrics := make(map[string]string, 6)

	origLines := countLines(original)
	fixedLines := countLines(fixed)
	metrics["orig_lines"] = fmt.Sprintf("%d", origLines)
	metrics["fixed_lines"] = fmt.Sprintf("%d", fixedLines)

	if strings.TrimSpace(fixed) == "" {
		warnings = append(warnings, "empty output")
	}
	if strings.Contains(fixed, "```") {
		warnings = append(warnings, "contains markdown code fences")
	}

	if origLines > 0 {
		ratio := float64(fixedLines) / float64(origLines)
		metrics["line_ratio"] = fmt.Sprintf("%.2f", ratio)
		if ratio < 0.25 {
			warnings = append(warnings, "large line reduction")
		} else if ratio > 4.0 {
			warnings = append(warnings, "large line expansion")
		}
	}

	if HasCodeChanges(original, fixed) {
		metrics["changed"] = "true"
	} else {
		metrics["changed"] = "false"
	}

	origTodos := countTodoFixme(original)
	fixedTodos := countTodoFixme(fixed)
	metrics["todo_delta"] = fmt.Sprintf("%d", fixedTodos-origTodos)
	if fixedTodos-origTodos >= 2 {
		warnings = append(warnings, "introduced TODO/FIXME")
	}

	if usesBraces(lang) {
		braceOpen, braceClose, parenOpen, parenClose, bracketOpen, bracketClose := countBrackets(fixed)
		if braceOpen != braceClose {
			warnings = append(warnings, "unbalanced braces")
		}
		if parenOpen != parenClose {
			warnings = append(warnings, "unbalanced parentheses")
		}
		if bracketOpen != bracketClose {
			warnings = append(warnings, "unbalanced brackets")
		}
	}

	return QualityReport{
		Warnings: warnings,
		Metrics:  metrics,
	}
}

func countLines(text string) int {
	if text == "" {
		return 0
	}
	return strings.Count(text, "\n") + 1
}

func countTodoFixme(text string) int {
	upper := strings.ToUpper(text)
	return strings.Count(upper, "TODO") + strings.Count(upper, "FIXME")
}

func usesBraces(lang analyzer.Language) bool {
	switch lang {
	case analyzer.LangGo, analyzer.LangJavaScript, analyzer.LangTypeScript,
		analyzer.LangJava, analyzer.LangC, analyzer.LangCPP, analyzer.LangRust,
		analyzer.LangSwift, analyzer.LangKotlin, analyzer.LangPHP:
		return true
	default:
		return false
	}
}

func countBrackets(text string) (braceOpen int, braceClose int, parenOpen int, parenClose int, bracketOpen int, bracketClose int) {
	inSingle := false
	inDouble := false
	inLineComment := false
	inBlockComment := false
	escape := false

	for i := 0; i < len(text); i++ {
		ch := text[i]
		next := byte(0)
		if i+1 < len(text) {
			next = text[i+1]
		}

		if inLineComment {
			if ch == '\n' {
				inLineComment = false
			}
			continue
		}
		if inBlockComment {
			if ch == '*' && next == '/' {
				inBlockComment = false
				i++
			}
			continue
		}

		if !inSingle && !inDouble {
			if ch == '/' && next == '/' {
				inLineComment = true
				i++
				continue
			}
			if ch == '/' && next == '*' {
				inBlockComment = true
				i++
				continue
			}
		}

		if escape {
			escape = false
			continue
		}
		if ch == '\\' && (inSingle || inDouble) {
			escape = true
			continue
		}

		if ch == '\'' && !inDouble {
			inSingle = !inSingle
			continue
		}
		if ch == '"' && !inSingle {
			inDouble = !inDouble
			continue
		}

		if inSingle || inDouble {
			continue
		}

		switch ch {
		case '{':
			braceOpen++
		case '}':
			braceClose++
		case '(':
			parenOpen++
		case ')':
			parenClose++
		case '[':
			bracketOpen++
		case ']':
			bracketClose++
		}
	}

	return braceOpen, braceClose, parenOpen, parenClose, bracketOpen, bracketClose
}
