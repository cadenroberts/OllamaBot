package context

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/croberts/obot/internal/analyzer"
	"github.com/croberts/obot/internal/fsutil"
	"github.com/croberts/obot/internal/index"
	"github.com/croberts/obot/internal/planner"
)

type Summary struct {
	Root         string
	TargetFile   string
	TotalFiles   int
	Languages    []LangCount
	TopFiles     []index.FileMeta
	TodoFiles    []index.FileMeta
	SiblingFiles []string
	PlanTasks    []planner.Task
}

type LangCount struct {
	Language analyzer.Language
	Count    int
}

type Options struct {
	MaxFileSize    int64
	MaxLanguages   int
	MaxTopFiles    int
	MaxTodoFiles   int
	MaxSiblingFiles int
	MaxPlanTasks   int
}

func DefaultOptions() Options {
	return Options{
		MaxFileSize:    512 * 1024,
		MaxLanguages:   5,
		MaxTopFiles:    6,
		MaxTodoFiles:   6,
		MaxSiblingFiles: 8,
		MaxPlanTasks:   10,
	}
}

func BuildSummary(ctx context.Context, targetPath string, instruction string, opts Options) (*Summary, error) {
	if targetPath == "" {
		targetPath = "."
	}
	if opts.MaxFileSize <= 0 {
		opts.MaxFileSize = DefaultOptions().MaxFileSize
	}
	if opts.MaxLanguages <= 0 {
		opts.MaxLanguages = DefaultOptions().MaxLanguages
	}
	if opts.MaxTopFiles <= 0 {
		opts.MaxTopFiles = DefaultOptions().MaxTopFiles
	}
	if opts.MaxTodoFiles <= 0 {
		opts.MaxTodoFiles = DefaultOptions().MaxTodoFiles
	}
	if opts.MaxSiblingFiles <= 0 {
		opts.MaxSiblingFiles = DefaultOptions().MaxSiblingFiles
	}
	if opts.MaxPlanTasks <= 0 {
		opts.MaxPlanTasks = DefaultOptions().MaxPlanTasks
	}

	absPath, err := filepath.Abs(targetPath)
	if err != nil {
		return nil, err
	}

	info, err := os.Stat(absPath)
	if err != nil {
		return nil, err
	}

	root := absPath
	targetFile := ""
	if !info.IsDir() {
		targetFile = absPath
		root = filepath.Dir(absPath)
	}

	idx, err := index.Build(ctx, root, index.Options{
		MaxFileSize:   opts.MaxFileSize,
		IncludeHidden: false,
	})
	if err != nil {
		return nil, err
	}

	langCounts := make(map[analyzer.Language]int)
	for _, f := range idx.Files {
		langCounts[f.Language]++
	}
	langs := make([]LangCount, 0, len(langCounts))
	for lang, count := range langCounts {
		if lang == analyzer.LangUnknown {
			continue
		}
		langs = append(langs, LangCount{Language: lang, Count: count})
	}
	sort.Slice(langs, func(i, j int) bool {
		return langs[i].Count > langs[j].Count
	})
	if len(langs) > opts.MaxLanguages {
		langs = langs[:opts.MaxLanguages]
	}

	topFiles := idx.TopByLines(opts.MaxTopFiles)
	todoFiles := topTodoFiles(idx.Files, opts.MaxTodoFiles)

	siblings := make([]string, 0)
	if targetFile != "" {
		siblings = listSiblingFiles(targetFile, opts.MaxSiblingFiles)
	}

	plan, err := planner.BuildPlan(ctx, root, instruction, planner.Options{
		MaxTasks:     opts.MaxPlanTasks,
		MaxFiles:     opts.MaxTopFiles,
		MaxFileSize:  opts.MaxFileSize,
		IncludeHidden: false,
	})
	if err != nil {
		plan = &planner.Plan{}
	}

	return &Summary{
		Root:         root,
		TargetFile:   targetFile,
		TotalFiles:   len(idx.Files),
		Languages:    langs,
		TopFiles:     topFiles,
		TodoFiles:    todoFiles,
		SiblingFiles: siblings,
		PlanTasks:    plan.Tasks,
	}, nil
}

func (s *Summary) RenderText() string {
	var sb strings.Builder
	sb.WriteString("Repo Context\n")
	sb.WriteString("-----------\n")
	sb.WriteString(fmt.Sprintf("root: %s\n", s.Root))
	sb.WriteString(fmt.Sprintf("files: %d\n", s.TotalFiles))

	if len(s.Languages) > 0 {
		sb.WriteString("languages: ")
		for i, item := range s.Languages {
			if i > 0 {
				sb.WriteString(", ")
			}
			sb.WriteString(fmt.Sprintf("%s(%d)", item.Language.DisplayName(), item.Count))
		}
		sb.WriteString("\n")
	}

	if len(s.TopFiles) > 0 {
		sb.WriteString("top files:\n")
		for _, f := range s.TopFiles {
			sb.WriteString(fmt.Sprintf("- %s (%d lines)\n", f.RelPath, f.Lines))
		}
	}

	if len(s.TodoFiles) > 0 {
		sb.WriteString("todo hotspots:\n")
		for _, f := range s.TodoFiles {
			sb.WriteString(fmt.Sprintf("- %s (todo:%d fixme:%d)\n", f.RelPath, f.TodoCount, f.FixmeCount))
		}
	}

	if len(s.SiblingFiles) > 0 {
		sb.WriteString("sibling files:\n")
		for _, name := range s.SiblingFiles {
			sb.WriteString(fmt.Sprintf("- %s\n", name))
		}
	}

	if len(s.PlanTasks) > 0 {
		sb.WriteString("local signals:\n")
		for _, task := range s.PlanTasks {
			location := task.File
			if s.Root != "" {
				location = fsutil.RelPath(s.Root, task.File)
			}
			if task.Line > 0 {
				sb.WriteString(fmt.Sprintf("- %s:%d %s\n", location, task.Line, task.Message))
			} else {
				sb.WriteString(fmt.Sprintf("- %s %s\n", location, task.Message))
			}
		}
	}

	return sb.String()
}

func topTodoFiles(files []index.FileMeta, limit int) []index.FileMeta {
	filtered := make([]index.FileMeta, 0)
	for _, f := range files {
		if f.TodoCount+f.FixmeCount > 0 {
			filtered = append(filtered, f)
		}
	}
	sort.Slice(filtered, func(i, j int) bool {
		return (filtered[i].TodoCount+filtered[i].FixmeCount) > (filtered[j].TodoCount+filtered[j].FixmeCount)
	})
	if limit > 0 && len(filtered) > limit {
		filtered = filtered[:limit]
	}
	return filtered
}

func listSiblingFiles(path string, limit int) []string {
	dir := filepath.Dir(path)
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}

	siblings := make([]string, 0, limit)
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if fsutil.ShouldSkipFile(name, false, nil) {
			continue
		}
		if filepath.Join(dir, name) == path {
			continue
		}
		siblings = append(siblings, name)
		if limit > 0 && len(siblings) >= limit {
			break
		}
	}
	return siblings
}
