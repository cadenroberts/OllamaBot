package fsutil

import (
	"bytes"
	"io"
	"os"
	"path/filepath"
	"strings"
)

var DefaultIgnoreDirs = map[string]struct{}{
	".git":        {},
	".hg":         {},
	".svn":        {},
	".idea":       {},
	".vscode":     {},
	"node_modules": {},
	"vendor":      {},
	"dist":        {},
	"build":       {},
	"bin":         {},
	"obj":         {},
	"target":      {},
	"coverage":    {},
}

var DefaultIgnoreExts = map[string]struct{}{
	".exe":   {},
	".dll":   {},
	".so":    {},
	".dylib": {},
	".zip":   {},
	".tar":   {},
	".gz":    {},
	".tgz":   {},
	".png":   {},
	".jpg":   {},
	".jpeg":  {},
	".gif":   {},
	".webp":  {},
	".pdf":   {},
	".ico":   {},
	".icns":  {},
	".mp4":   {},
	".mov":   {},
	".avi":   {},
	".mp3":   {},
	".wav":   {},
	".woff":  {},
	".woff2": {},
}

func IsHiddenName(name string) bool {
	return strings.HasPrefix(name, ".") && name != "." && name != ".."
}

func ShouldSkipDir(name string, includeHidden bool, ignore map[string]struct{}) bool {
	if !includeHidden && IsHiddenName(name) {
		return true
	}
	if ignore == nil {
		ignore = DefaultIgnoreDirs
	}
	_, ok := ignore[name]
	return ok
}

func ShouldSkipFile(name string, includeHidden bool, ignoreExts map[string]struct{}) bool {
	if !includeHidden && IsHiddenName(name) {
		return true
	}
	ext := strings.ToLower(filepath.Ext(name))
	if ignoreExts == nil {
		ignoreExts = DefaultIgnoreExts
	}
	_, ok := ignoreExts[ext]
	return ok
}

func IsBinaryFile(path string) (bool, error) {
	f, err := os.Open(path)
	if err != nil {
		return false, err
	}
	defer f.Close()

	buf := make([]byte, 8000)
	n, err := f.Read(buf)
	if err != nil && err != io.EOF {
		return false, err
	}

	return bytes.IndexByte(buf[:n], 0) != -1, nil
}

func RelPath(root, path string) string {
	if root == "" {
		return path
	}
	rel, err := filepath.Rel(root, path)
	if err != nil {
		return path
	}
	return rel
}
