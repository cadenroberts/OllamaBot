package review

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/croberts/obot/internal/fsutil"
)

type Issue struct {
	Path     string `json:"path"`
	RelPath  string `json:"rel_path"`
	Line     int    `json:"line,omitempty"`
	Kind     string `json:"kind"`
	Message  string `json:"message"`
	Severity string `json:"severity"`
}

type Options struct {
	MaxFileSize   int64
	IncludeHidden bool
	IgnoreDirs    map[string]struct{}
	IgnoreExts    map[string]struct{}
	MaxIssues     int
	LineLength    int
}

func DefaultOptions() Options {
	return Options{
		MaxFileSize:   1 * 1024 * 1024,
		IncludeHidden: false,
		IgnoreDirs:    fsutil.DefaultIgnoreDirs,
		IgnoreExts:    fsutil.DefaultIgnoreExts,
		MaxIssues:     200,
		LineLength:    120,
	}
}

func ScanPath(path string, opts Options) ([]Issue, error) {
	if path == "" {
		path = "."
	}
	if opts.MaxFileSize <= 0 {
		opts.MaxFileSize = DefaultOptions().MaxFileSize
	}
	if opts.MaxIssues <= 0 {
		opts.MaxIssues = DefaultOptions().MaxIssues
	}
	if opts.LineLength <= 0 {
		opts.LineLength = DefaultOptions().LineLength
	}
	if opts.IgnoreDirs == nil {
		opts.IgnoreDirs = fsutil.DefaultIgnoreDirs
	}
	if opts.IgnoreExts == nil {
		opts.IgnoreExts = fsutil.DefaultIgnoreExts
	}

	absPath, err := filepath.Abs(path)
	if err != nil {
		return nil, err
	}

	info, err := os.Stat(absPath)
	if err != nil {
		return nil, err
	}

	if !info.IsDir() {
		return ScanFile(absPath, opts, filepath.Dir(absPath))
	}

	issues := make([]Issue, 0, 64)
	stopErr := errors.New("max issues reached")

	err = filepath.WalkDir(absPath, func(filePath string, d os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		name := d.Name()
		if d.IsDir() {
			if fsutil.ShouldSkipDir(name, opts.IncludeHidden, opts.IgnoreDirs) {
				return filepath.SkipDir
			}
			return nil
		}

		if fsutil.ShouldSkipFile(name, opts.IncludeHidden, opts.IgnoreExts) {
			return nil
		}

		info, err := d.Info()
		if err != nil {
			return nil
		}
		if info.Size() > opts.MaxFileSize {
			return nil
		}

		isBinary, err := fsutil.IsBinaryFile(filePath)
		if err != nil || isBinary {
			return nil
		}

		fileIssues, err := ScanFile(filePath, opts, absPath)
		if err != nil {
			return nil
		}
		issues = append(issues, fileIssues...)
		if len(issues) >= opts.MaxIssues {
			return stopErr
		}

		return nil
	})

	if err != nil && err != stopErr {
		return issues, err
	}

	return issues, nil
}

func ScanFile(path string, opts Options, root string) ([]Issue, error) {
	if opts.LineLength <= 0 {
		opts.LineLength = DefaultOptions().LineLength
	}

	info, err := os.Stat(path)
	if err != nil {
		return nil, err
	}
	if opts.MaxFileSize > 0 && info.Size() > opts.MaxFileSize {
		return nil, nil
	}

	issues := make([]Issue, 0, 8)

	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	buf := make([]byte, 0, 64*1024)
	scanner.Buffer(buf, 1024*1024)

	lineNum := 0
	for scanner.Scan() {
		lineNum++
		line := scanner.Text()

		if strings.TrimRight(line, " \t") != line {
			issues = append(issues, Issue{
				Path:     path,
				RelPath:  fsutil.RelPath(root, path),
				Line:     lineNum,
				Kind:     "trailing-whitespace",
				Message:  "Line has trailing whitespace.",
				Severity: "warning",
			})
		}

		if strings.Contains(line, "\t") {
			issues = append(issues, Issue{
				Path:     path,
				RelPath:  fsutil.RelPath(root, path),
				Line:     lineNum,
				Kind:     "tab-indent",
				Message:  "Line contains a tab character.",
				Severity: "info",
			})
		}

		if len([]rune(line)) > opts.LineLength {
			issues = append(issues, Issue{
				Path:     path,
				RelPath:  fsutil.RelPath(root, path),
				Line:     lineNum,
				Kind:     "long-line",
				Message:  fmt.Sprintf("Line exceeds %d characters.", opts.LineLength),
				Severity: "warning",
			})
		}

		upper := strings.ToUpper(line)
		if strings.Contains(upper, "TODO") {
			issues = append(issues, Issue{
				Path:     path,
				RelPath:  fsutil.RelPath(root, path),
				Line:     lineNum,
				Kind:     "todo",
				Message:  "TODO found.",
				Severity: "info",
			})
		}
		if strings.Contains(upper, "FIXME") {
			issues = append(issues, Issue{
				Path:     path,
				RelPath:  fsutil.RelPath(root, path),
				Line:     lineNum,
				Kind:     "fixme",
				Message:  "FIXME found.",
				Severity: "warning",
			})
		}
	}

	if err := scanner.Err(); err != nil {
		return issues, err
	}

	data, err := os.ReadFile(path)
	if err == nil && len(data) > 0 && data[len(data)-1] != '\n' {
		issues = append(issues, Issue{
			Path:     path,
			RelPath:  fsutil.RelPath(root, path),
			Kind:     "missing-newline",
			Message:  "File does not end with a newline.",
			Severity: "warning",
		})
	}

	return issues, nil
}

func RenderText(issues []Issue, root string) string {
	var sb strings.Builder
	sb.WriteString("Review\n")
	sb.WriteString("------\n")
	sb.WriteString(fmt.Sprintf("Issues: %d\n\n", len(issues)))

	if len(issues) == 0 {
		sb.WriteString("No issues found.\n")
		return sb.String()
	}

	for _, issue := range issues {
		rel := issue.RelPath
		if rel == "" {
			rel = fsutil.RelPath(root, issue.Path)
		}
		if issue.Line > 0 {
			sb.WriteString(fmt.Sprintf("- %s:%d [%s] %s - %s\n", rel, issue.Line, issue.Severity, issue.Kind, issue.Message))
		} else {
			sb.WriteString(fmt.Sprintf("- %s [%s] %s - %s\n", rel, issue.Severity, issue.Kind, issue.Message))
		}
	}

	return sb.String()
}
