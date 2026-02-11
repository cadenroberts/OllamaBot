// Package scan implements project health scanning.
package scan

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/croberts/obot/internal/analyzer"
)

// HealthIssue represents a detected problem in the codebase.
type HealthIssue struct {
	Path     string `json:"path"`
	Line     int    `json:"line"`
	Type     string `json:"type"` // "todo", "unused_import", "test_gap", "security"
	Severity string `json:"severity"` // "low", "medium", "high"
	Message  string `json:"message"`
}

// HealthReport contains the results of a health scan.
type HealthReport struct {
	Issues     []HealthIssue `json:"issues"`
	FilesScanned int          `json:"files_scanned"`
	Score      int           `json:"score"` // 0-100
}

// HealthScanner scans a repository for various health issues.
type HealthScanner struct {
	root string
}

// NewHealthScanner creates a new health scanner.
func NewHealthScanner(root string) *HealthScanner {
	return &HealthScanner{root: root}
}

// Scan performs a full health scan of the project.
func (s *HealthScanner) Scan() (*HealthReport, error) {
	report := &HealthReport{
		Issues: make([]HealthIssue, 0),
	}

	err := filepath.Walk(s.root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if info.IsDir() {
			if strings.Contains(path, ".git") || strings.Contains(path, "node_modules") {
				return filepath.SkipDir
			}
			return nil
		}

		// Only scan code files
		lang := analyzer.DetectLanguage(path)
		if !lang.IsCode() {
			return nil
		}

		report.FilesScanned++
		issues, err := s.scanFile(path)
		if err == nil {
			report.Issues = append(report.Issues, issues...)
		}

		return nil
	})

	if err != nil {
		return nil, err
	}

	// Calculate a simple health score
	if report.FilesScanned > 0 {
		deduction := len(report.Issues) * 2
		report.Score = 100 - deduction
		if report.Score < 0 {
			report.Score = 0
		}
	} else {
		report.Score = 100
	}

	return report, nil
}

// scanFile scans a single file for issues.
func (s *HealthScanner) scanFile(path string) ([]HealthIssue, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	issues := make([]HealthIssue, 0)
	scanner := bufio.NewScanner(f)
	lineNum := 0

	for scanner.Scan() {
		lineNum++
		line := scanner.Text()
		trimmed := strings.TrimSpace(line)

		// 1. TODO comments
		if strings.Contains(strings.ToUpper(line), "TODO") {
			issues = append(issues, HealthIssue{
				Path:     path,
				Line:     lineNum,
				Type:     "todo",
				Severity: "low",
				Message:  "Pending task found: " + trimmed,
			})
		}

		// 2. Unused imports (Simplified check for Go)
		if strings.HasSuffix(path, ".go") && strings.HasPrefix(trimmed, "import") {
			// This would need a more sophisticated parser to truly detect 'unused'
		}

		// 3. Security (Stub: look for sensitive keywords)
		sensitive := []string{"password", "secret", "token", "key"}
		for _, kw := range sensitive {
			if strings.Contains(strings.ToLower(line), kw) && strings.Contains(line, "=") {
				issues = append(issues, HealthIssue{
					Path:     path,
					Line:     lineNum,
					Type:     "security",
					Severity: "high",
					Message:  fmt.Sprintf("Potential sensitive data exposed: %s", kw),
				})
			}
		}

		// 4. Nesting Level
		indent := 0
		for _, c := range line {
			if c == ' ' {
				indent++
			} else if c == '\t' {
				indent += 4
			} else {
				break
			}
		}
		if indent > 24 { // Approx 6 levels of 4-space indentation
			issues = append(issues, HealthIssue{
				Path:     path,
				Line:     lineNum,
				Type:     "complexity",
				Severity: "medium",
				Message:  "Deeply nested code detected",
			})
		}
	}

	// 5. File length
	if lineNum > 500 {
		issues = append(issues, HealthIssue{
			Path:     path,
			Line:     lineNum,
			Type:     "complexity",
			Severity: "medium",
			Message:  fmt.Sprintf("Large file detected: %d lines", lineNum),
		})
	}

	return issues, scanner.Err()
}

// Summary returns a human-readable summary of the health report.
func (r *HealthReport) Summary() string {
	severityCounts := make(map[string]int)
	typeCounts := make(map[string]int)
	for _, issue := range r.Issues {
		severityCounts[issue.Severity]++
		typeCounts[issue.Type]++
	}

	return fmt.Sprintf("Score: %d | Files: %d | Issues: %d (High: %d, Med: %d, Low: %d)",
		r.Score, r.FilesScanned, len(r.Issues),
		severityCounts["high"], severityCounts["medium"], severityCounts["low"])
}
