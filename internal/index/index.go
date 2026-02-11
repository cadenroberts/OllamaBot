package index

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/croberts/obot/internal/analyzer"
	"github.com/croberts/obot/internal/config"
	"github.com/croberts/obot/internal/fsutil"
	"github.com/croberts/obot/internal/ollama"
)

type SymbolType string

const (
	SymbolFunction  SymbolType = "function"
	SymbolMethod    SymbolType = "method"
	SymbolClass     SymbolType = "class"
	SymbolStruct    SymbolType = "struct"
	SymbolInterface SymbolType = "interface"
	SymbolVariable  SymbolType = "variable"
	SymbolConstant  SymbolType = "constant"
	SymbolTypeAlias SymbolType = "type"
)

type Symbol struct {
	Name      string     `json:"name"`
	Type      SymbolType `json:"type"`
	Line      int        `json:"line"`
	Signature string     `json:"signature,omitempty"`
}

type FileMeta struct {
	Path       string            `json:"path"`
	RelPath    string            `json:"rel_path"`
	SizeBytes  int64             `json:"size_bytes"`
	ModTime    time.Time         `json:"mod_time"`
	Language   analyzer.Language `json:"language"`
	Lines      int               `json:"lines"`
	TodoCount  int               `json:"todo_count"`
	FixmeCount int               `json:"fixme_count"`
	Symbols    []Symbol          `json:"symbols,omitempty"`
}

type Index struct {
	Root       string          `json:"root"`
	Files      []FileMeta      `json:"files"`
	Embeddings []FileEmbedding `json:"embeddings,omitempty"`
	CreatedAt  time.Time       `json:"created_at"`
}

// NewIndex creates a new indexer for the given root.
func NewIndex(root string) *Index {
	return &Index{
		Root:  root,
		Files: make([]FileMeta, 0),
	}
}

// Build populates the index by walking the root directory.
func (idx *Index) Build(ctx context.Context, opts Options) error {
	newIdx, err := Build(ctx, idx.Root, opts)
	if err != nil {
		return err
	}
	idx.Files = newIdx.Files
	idx.Embeddings = newIdx.Embeddings
	idx.CreatedAt = newIdx.CreatedAt
	return nil
}

// GetStats returns statistics about the current index.
func (idx *Index) GetStats() Stats {
	langMap := make(map[string]int)
	for _, f := range idx.Files {
		lang := string(f.Language)
		if lang == "" {
			lang = "Unknown"
		}
		langMap[lang]++
	}
	return Stats{
		TotalFiles:  len(idx.Files),
		LanguageMap: langMap,
	}
}

// Stats contains index statistics.
type Stats struct {
	TotalFiles  int
	LanguageMap map[string]int
}

type Options struct {
	MaxFileSize    int64
	IncludeHidden  bool
	IgnoreDirs     map[string]struct{}
	IgnoreExts     map[string]struct{}
	EnableSemantic bool
	OllamaClient   *ollama.Client
	EmbeddingModel string
}

func DefaultOptions() Options {
	return Options{
		MaxFileSize:   1 * 1024 * 1024, // 1MB
		IncludeHidden: false,
		IgnoreDirs:    fsutil.DefaultIgnoreDirs,
		IgnoreExts:    fsutil.DefaultIgnoreExts,
	}
}

func Build(ctx context.Context, root string, opts Options) (*Index, error) {
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

		lines, todoCount, fixmeCount, symbols, err := scanFile(path, walkRoot)
		if err != nil {
			return nil
		}

		fMeta := FileMeta{
			Path:       path,
			RelPath:    fsutil.RelPath(walkRoot, path),
			SizeBytes:  info.Size(),
			ModTime:    info.ModTime(),
			Language:   analyzer.DetectLanguage(path),
			Lines:      lines,
			TodoCount:  todoCount,
			FixmeCount: fixmeCount,
			Symbols:    symbols,
		}
		files = append(files, fMeta)

		return nil
	})
	if err != nil {
		return nil, err
	}

	embeddings := make([]FileEmbedding, 0)
	if opts.EnableSemantic && opts.OllamaClient != nil {
		semIdx := NewSemanticIndex(opts.OllamaClient, opts.EmbeddingModel)
		for _, f := range files {
			// Read file content for embedding
			content, err := os.ReadFile(f.Path)
			if err != nil {
				continue
			}
			if err := semIdx.AddFile(ctx, f.RelPath, string(content)); err != nil {
				continue
			}
		}
		embeddings = semIdx.embeddings
	}

	return &Index{
		Root:       walkRoot,
		Files:      files,
		Embeddings: embeddings,
		CreatedAt:  time.Now(),
	}, nil
}

func scanFile(path string, root string) (lines int, todoCount int, fixmeCount int, symbols []Symbol, err error) {
	f, err := os.Open(path)
	if err != nil {
		return 0, 0, 0, nil, err
	}
	defer f.Close()

	lang := analyzer.DetectLanguage(path)
	extractors := getExtractors(lang)

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

		for _, ext := range extractors {
			if matches := ext.regex.FindStringSubmatch(line); matches != nil {
				name := matches[ext.nameIdx]
				symbols = append(symbols, Symbol{
					Name:      name,
					Type:      ext.symType,
					Line:      lines,
					Signature: strings.TrimSpace(line),
				})
			}
		}
	}

	if err := scanner.Err(); err != nil {
		return lines, todoCount, fixmeCount, symbols, err
	}

	return lines, todoCount, fixmeCount, symbols, nil
}

type extractor struct {
	regex   *regexp.Regexp
	symType SymbolType
	nameIdx int
}

var (
	goFuncRegex   = regexp.MustCompile(`^func\s+([A-Z][a-zA-Z0-9_]*)\s*\(`)
	goMethodRegex = regexp.MustCompile(`^func\s*\([^)]+\)\s+([A-Z][a-zA-Z0-9_]*)\s*\(`)
	goStructRegex = regexp.MustCompile(`^type\s+([A-Z][a-zA-Z0-9_]*)\s+struct`)
	goIfaceRegex  = regexp.MustCompile(`^type\s+([A-Z][a-zA-Z0-9_]*)\s+interface`)

	pyFuncRegex  = regexp.MustCompile(`^def\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(`)
	pyClassRegex = regexp.MustCompile(`^class\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*[:\(]`)

	tsFuncRegex  = regexp.MustCompile(`^(?:export\s+)?function\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(`)
	tsClassRegex = regexp.MustCompile(`^(?:export\s+)?class\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*`)
	tsIfaceRegex = regexp.MustCompile(`^(?:export\s+)?interface\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*`)
)

func getExtractors(lang analyzer.Language) []extractor {
	switch lang {
	case analyzer.LangGo:
		return []extractor{
			{goFuncRegex, SymbolFunction, 1},
			{goMethodRegex, SymbolMethod, 1},
			{goStructRegex, SymbolStruct, 1},
			{goIfaceRegex, SymbolInterface, 1},
		}
	case analyzer.LangPython:
		return []extractor{
			{pyFuncRegex, SymbolFunction, 1},
			{pyClassRegex, SymbolClass, 1},
		}
	case analyzer.LangTypeScript, analyzer.LangJavaScript:
		return []extractor{
			{tsFuncRegex, SymbolFunction, 1},
			{tsClassRegex, SymbolClass, 1},
			{tsIfaceRegex, SymbolInterface, 1},
		}
	default:
		return nil
	}
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
