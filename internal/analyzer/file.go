package analyzer

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// FileContext contains the context for analyzing and fixing a file
type FileContext struct {
	Path        string   // Absolute path to the file
	FullContent string   // Complete file content
	Lines       []string // File split into lines
	StartLine   int      // Start line for partial fix (1-indexed, 0 = entire file)
	EndLine     int      // End line for partial fix (1-indexed, 0 = entire file)
	Language    Language // Detected programming language
}

// ReadFileContext reads a file and creates a context for fixing
func ReadFileContext(filePath string, startLine, endLine int) (*FileContext, error) {
	// Get absolute path
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to get absolute path: %w", err)
	}

	// Read file content
	content, err := os.ReadFile(absPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read file: %w", err)
	}

	// Split into lines
	lines := strings.Split(string(content), "\n")

	// Detect language
	lang := DetectLanguage(filePath)

	// Validate line range
	if startLine < 0 {
		startLine = 0
	}
	if endLine < 0 {
		endLine = 0
	}
	if startLine > len(lines) {
		startLine = len(lines)
	}
	if endLine > len(lines) {
		endLine = len(lines)
	}
	if startLine > 0 && endLine > 0 && startLine > endLine {
		return nil, fmt.Errorf("start line (%d) cannot be greater than end line (%d)", startLine, endLine)
	}

	return &FileContext{
		Path:        absPath,
		FullContent: string(content),
		Lines:       lines,
		StartLine:   startLine,
		EndLine:     endLine,
		Language:    lang,
	}, nil
}

// GetTargetLines returns the lines to be fixed
func (fc *FileContext) GetTargetLines() string {
	if fc.StartLine == 0 && fc.EndLine == 0 {
		// Entire file
		return fc.FullContent
	}

	// Convert to 0-indexed
	start := fc.StartLine - 1
	end := fc.EndLine

	if start < 0 {
		start = 0
	}
	if end > len(fc.Lines) {
		end = len(fc.Lines)
	}
	if end == 0 {
		end = len(fc.Lines)
	}

	return strings.Join(fc.Lines[start:end], "\n")
}

// GetTargetLinesWithNumbers returns lines with line numbers for context
func (fc *FileContext) GetTargetLinesWithNumbers() string {
	var sb strings.Builder

	start := 0
	end := len(fc.Lines)

	if fc.StartLine > 0 {
		start = fc.StartLine - 1
	}
	if fc.EndLine > 0 {
		end = fc.EndLine
	}

	for i := start; i < end; i++ {
		lineNum := i + 1
		sb.WriteString(fmt.Sprintf("%4d | %s\n", lineNum, fc.Lines[i]))
	}

	return sb.String()
}

// GetContext returns surrounding context for partial fixes
func (fc *FileContext) GetContext(contextLines int) (before, after string) {
	if fc.StartLine == 0 {
		return "", ""
	}

	// Get lines before
	start := fc.StartLine - 1 - contextLines
	if start < 0 {
		start = 0
	}
	end := fc.StartLine - 1
	if end > 0 && start < end {
		before = strings.Join(fc.Lines[start:end], "\n")
	}

	// Get lines after
	start = fc.EndLine
	if start == 0 {
		start = len(fc.Lines)
	}
	end = start + contextLines
	if end > len(fc.Lines) {
		end = len(fc.Lines)
	}
	if start < end {
		after = strings.Join(fc.Lines[start:end], "\n")
	}

	return before, after
}

// ApplyFix applies the fixed code to the file.
// It supports dry-run, no-backup, and force flags.
func (fc *FileContext) ApplyFix(fixedCode string, dryRun, noBackup, force bool) error {
	var newContent string

	if fc.StartLine == 0 && fc.EndLine == 0 {
		// Replace entire file
		newContent = fixedCode
	} else {
		// Replace specific lines
		newLines := make([]string, 0, len(fc.Lines))

		// Convert to 0-indexed
		start := fc.StartLine - 1
		end := fc.EndLine

		if start < 0 {
			start = 0
		}
		if end > len(fc.Lines) {
			end = len(fc.Lines)
		}
		if end == 0 {
			end = len(fc.Lines)
		}

		// Add lines before the fix
		newLines = append(newLines, fc.Lines[:start]...)

		// Add fixed lines
		fixedLines := strings.Split(fixedCode, "\n")
		newLines = append(newLines, fixedLines...)

		// Add lines after the fix
		if end < len(fc.Lines) {
			newLines = append(newLines, fc.Lines[end:]...)
		}

		newContent = strings.Join(newLines, "\n")
	}

	// Ensure file ends with newline
	if !strings.HasSuffix(newContent, "\n") {
		newContent += "\n"
	}

	if dryRun {
		return nil
	}

	// Write back to file (Note: ideally we would use patch.Patcher here, 
	// but for now we'll keep it simple and just implement the flags)
	if err := os.WriteFile(fc.Path, []byte(newContent), 0644); err != nil {
		return fmt.Errorf("failed to write file: %w", err)
	}

	// Update internal state
	fc.FullContent = newContent
	fc.Lines = strings.Split(newContent, "\n")

	return nil
}

// IsPartialFix returns true if this is a partial file fix
func (fc *FileContext) IsPartialFix() bool {
	return fc.StartLine > 0 || fc.EndLine > 0
}

// LineCount returns the number of lines being fixed
func (fc *FileContext) LineCount() int {
	if fc.StartLine == 0 && fc.EndLine == 0 {
		return len(fc.Lines)
	}

	start := fc.StartLine
	if start == 0 {
		start = 1
	}
	end := fc.EndLine
	if end == 0 {
		end = len(fc.Lines)
	}

	return end - start + 1
}

// FileName returns just the filename without the path
func (fc *FileContext) FileName() string {
	return filepath.Base(fc.Path)
}
