package index

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/croberts/obot/internal/analyzer"
	"github.com/croberts/obot/internal/config"
	"github.com/croberts/obot/internal/fsutil"
)

type FileMeta struct {
	Path       string            `json:"path"`
	RelPath    string            `json:"rel_path"`
	SizeBytes  int64             `json:"size_bytes"`
	ModTime    time.Time         `json:"mod_time"`
	Language   analyzer.Language `json:"language"`
	Lines      int               `json:"lines"`
	TodoCount  int               `json:"todo_count"`
	FixmeCount int               `json:"fixme_count"`
}

type Index struct {
	Root      string     `json:"root"`
	Files     []FileMeta `json:"files"`
	CreatedAt time.Time  `json:"created_at"`
}

type Options struct {
	MaxFileSize   int64
	IncludeHidden bool
	IgnoreDirs    map[string]struct{}
	IgnoreExts    map[string]struct{}
}

func DefaultOptions() Options {
	return Options{
		MaxFileSize:   1 * 1024 * 1024, // 1MB
		IncludeHidden: false,
		IgnoreDirs:    fsutil.DefaultIgnoreDirs,
		IgnoreExts:    fsutil.DefaultIgnoreExts,
	}
}

func Build(root string, opts Options) (*Index, error) {
	if root == "" {
		root = "."
	}
	absRoot, err := filepath.Abs(root)
	if err != nil {
		return nil, err
	}

	info, err := os.Stat(absRoot)
	if err != nil {
		return nil, err
	}

	var targetFile string
	walkRoot := absRoot
	if !info.IsDir() {
		targetFile = absRoot
		walkRoot = filepath.Dir(absRoot)
	}

	if opts.MaxFileSize <= 0 {
		opts.MaxFileSize = DefaultOptions().MaxFileSize
	}
	if opts.IgnoreDirs == nil {
		opts.IgnoreDirs = fsutil.DefaultIgnoreDirs
	}
	if opts.IgnoreExts == nil {
		opts.IgnoreExts = fsutil.DefaultIgnoreExts
	}

	files := make([]FileMeta, 0, 128)
	err = filepath.WalkDir(walkRoot, func(path string, d os.DirEntry, walkErr error) error {
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

		if targetFile != "" && path != targetFile {
			return nil
		}

		if fsutil.ShouldSkipFile(name, opts.IncludeHidden, opts.IgnoreExts) {
			return nil
		}

		info, err := d.Info()
		if err != nil {
			return nil
		}
		if opts.MaxFileSize > 0 && info.Size() > opts.MaxFileSize {
			return nil
		}

		isBinary, err := fsutil.IsBinaryFile(path)
		if err != nil || isBinary {
			return nil
		}

		lines, todoCount, fixmeCount, err := scanFile(path)
		if err != nil {
			return nil
		}

		files = append(files, FileMeta{
			Path:       path,
			RelPath:    fsutil.RelPath(walkRoot, path),
			SizeBytes:  info.Size(),
			ModTime:    info.ModTime(),
			Language:   analyzer.DetectLanguage(path),
			Lines:      lines,
			TodoCount:  todoCount,
			FixmeCount: fixmeCount,
		})

		return nil
	})
	if err != nil {
		return nil, err
	}

	return &Index{
		Root:      walkRoot,
		Files:     files,
		CreatedAt: time.Now(),
	}, nil
}

func scanFile(path string) (lines int, todoCount int, fixmeCount int, err error) {
	f, err := os.Open(path)
	if err != nil {
		return 0, 0, 0, err
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	buf := make([]byte, 0, 64*1024)
	scanner.Buffer(buf, 1024*1024)

	for scanner.Scan() {
		line := scanner.Text()
		lines++
		upper := strings.ToUpper(line)
		if strings.Contains(upper, "TODO") {
			todoCount++
		}
		if strings.Contains(upper, "FIXME") {
			fixmeCount++
		}
	}

	if err := scanner.Err(); err != nil {
		return lines, todoCount, fixmeCount, err
	}

	return lines, todoCount, fixmeCount, nil
}

func DefaultIndexPath() string {
	return filepath.Join(config.GetConfigDir(), "index.json")
}

func (idx *Index) Save(path string) error {
	if path == "" {
		path = DefaultIndexPath()
	}
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}

	data, err := json.MarshalIndent(idx, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(path, data, 0644)
}

func Load(path string) (*Index, error) {
	if path == "" {
		path = DefaultIndexPath()
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var idx Index
	if err := json.Unmarshal(data, &idx); err != nil {
		return nil, err
	}

	return &idx, nil
}

func (idx *Index) FindByName(substring string) []FileMeta {
	substring = strings.ToLower(substring)
	matches := make([]FileMeta, 0)
	for _, f := range idx.Files {
		if strings.Contains(strings.ToLower(f.RelPath), substring) {
			matches = append(matches, f)
		}
	}
	return matches
}

func (idx *Index) FilterByLanguage(lang analyzer.Language) []FileMeta {
	matches := make([]FileMeta, 0)
	for _, f := range idx.Files {
		if f.Language == lang {
			matches = append(matches, f)
		}
	}
	return matches
}

func (idx *Index) TopByLines(n int) []FileMeta {
	if n <= 0 {
		return nil
	}
	files := make([]FileMeta, len(idx.Files))
	copy(files, idx.Files)
	sort.Slice(files, func(i, j int) bool {
		return files[i].Lines > files[j].Lines
	})
	if len(files) > n {
		files = files[:n]
	}
	return files
}

func (idx *Index) Summary() string {
	var totalLines int
	var todoFiles int
	for _, f := range idx.Files {
		totalLines += f.Lines
		if f.TodoCount+f.FixmeCount > 0 {
			todoFiles++
		}
	}

	return fmt.Sprintf("files=%d lines=%d files_with_todos=%d", len(idx.Files), totalLines, todoFiles)
}
