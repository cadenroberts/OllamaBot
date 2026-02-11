package review

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDefaultOptions(t *testing.T) {
	opts := DefaultOptions()
	if opts.MaxFileSize <= 0 {
		t.Error("MaxFileSize should be positive")
	}
	if opts.MaxIssues <= 0 {
		t.Error("MaxIssues should be positive")
	}
	if opts.LineLength <= 0 {
		t.Error("LineLength should be positive")
	}
}

func TestScanFile_TrailingWhitespace(t *testing.T) {
	tmp := t.TempDir()
	fpath := filepath.Join(tmp, "test.go")
	content := "package main\nfunc foo() {\n\tx := 1   \n}\n"
	if err := os.WriteFile(fpath, []byte(content), 0644); err != nil {
		t.Fatalf("write: %v", err)
	}
	issues, err := ScanFile(fpath, DefaultOptions(), tmp)
	if err != nil {
		t.Fatalf("ScanFile: %v", err)
	}
	hasTrailing := false
	for _, i := range issues {
		if i.Kind == "trailing-whitespace" {
			hasTrailing = true
			break
		}
	}
	if !hasTrailing {
		t.Error("expected trailing-whitespace issue on line with trailing spaces")
	}
}

func TestScanFile_TabIndent(t *testing.T) {
	tmp := t.TempDir()
	fpath := filepath.Join(tmp, "test.go")
	content := "package main\n\tvar x int\n"
	if err := os.WriteFile(fpath, []byte(content), 0644); err != nil {
		t.Fatalf("write: %v", err)
	}
	issues, err := ScanFile(fpath, DefaultOptions(), tmp)
	if err != nil {
		t.Fatalf("ScanFile: %v", err)
	}
	hasTab := false
	for _, i := range issues {
		if i.Kind == "tab-indent" {
			hasTab = true
			break
		}
	}
	if !hasTab {
		t.Error("expected tab-indent issue")
	}
}

func TestScanFile_TODO(t *testing.T) {
	tmp := t.TempDir()
	fpath := filepath.Join(tmp, "test.go")
	content := "package main\n// TODO: implement this\n"
	if err := os.WriteFile(fpath, []byte(content), 0644); err != nil {
		t.Fatalf("write: %v", err)
	}
	issues, err := ScanFile(fpath, DefaultOptions(), tmp)
	if err != nil {
		t.Fatalf("ScanFile: %v", err)
	}
	hasTODO := false
	for _, i := range issues {
		if i.Kind == "todo" {
			hasTODO = true
			break
		}
	}
	if !hasTODO {
		t.Error("expected todo issue")
	}
}

func TestScanPath_Empty(t *testing.T) {
	tmp := t.TempDir()
	issues, err := ScanPath(tmp, DefaultOptions())
	if err != nil {
		t.Fatalf("ScanPath: %v", err)
	}
	if issues == nil {
		t.Error("issues should not be nil")
	}
}

func TestRenderText(t *testing.T) {
	issues := []Issue{
		{Path: "/a/b.go", RelPath: "b.go", Line: 1, Kind: "todo", Message: "TODO found.", Severity: "info"},
	}
	s := RenderText(issues, "/a")
	if !strings.Contains(s, "Review") {
		t.Error("RenderText should contain 'Review'")
	}
	if !strings.Contains(s, "todo") {
		t.Error("RenderText should contain issue kind")
	}
	sEmpty := RenderText(nil, ".")
	if !strings.Contains(sEmpty, "No issues") {
		t.Error("RenderText for empty should mention no issues")
	}
}
