package fsutil

import (
	"path/filepath"
	"testing"
)

func TestIsHiddenName(t *testing.T) {
	if !IsHiddenName(".git") {
		t.Error(".git should be hidden")
	}
	if !IsHiddenName(".env") {
		t.Error(".env should be hidden")
	}
	if IsHiddenName(".") {
		t.Error(". should not be hidden")
	}
	if IsHiddenName("..") {
		t.Error(".. should not be hidden")
	}
	if IsHiddenName("visible") {
		t.Error("visible should not be hidden")
	}
}

func TestShouldSkipDir(t *testing.T) {
	if !ShouldSkipDir(".git", false, nil) {
		t.Error("ShouldSkipDir should skip .git in DefaultIgnoreDirs")
	}
	if !ShouldSkipDir("node_modules", false, nil) {
		t.Error("ShouldSkipDir should skip node_modules")
	}
	if ShouldSkipDir("src", false, nil) {
		t.Error("ShouldSkipDir should not skip src")
	}
	if !ShouldSkipDir(".hidden", false, nil) {
		t.Error("ShouldSkipDir should skip hidden when includeHidden=false")
	}
	if ShouldSkipDir(".hidden", true, nil) {
		t.Error("ShouldSkipDir should not skip .hidden when includeHidden=true")
	}
}

func TestShouldSkipFile(t *testing.T) {
	if !ShouldSkipFile("foo.exe", false, nil) {
		t.Error("ShouldSkipFile should skip .exe")
	}
	if !ShouldSkipFile("image.png", false, nil) {
		t.Error("ShouldSkipFile should skip .png")
	}
	if ShouldSkipFile("main.go", false, nil) {
		t.Error("ShouldSkipFile should not skip .go")
	}
	if !ShouldSkipFile(".hidden", false, nil) {
		t.Error("ShouldSkipFile should skip hidden when includeHidden=false")
	}
}

func TestRelPath(t *testing.T) {
	got := RelPath("/a/b/c", "/a/b/c/d/file.go")
	if got != "d/file.go" && got != filepath.Join("d", "file.go") {
		t.Errorf("RelPath = %q, want d/file.go", got)
	}

	got = RelPath("", "/any/path")
	if got != "/any/path" {
		t.Errorf("RelPath with empty root should return path, got %q", got)
	}
}
