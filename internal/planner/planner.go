package planner

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/croberts/obot/internal/fixer"
	"github.com/croberts/obot/internal/fsutil"
	"github.com/croberts/obot/internal/index"
)

type Task struct {
	ID       string         `json:"id"`
	Kind     string         `json:"kind"`
	File     string         `json:"file"`
	Line     int            `json:"line,omitempty"`
	Message  string         `json:"message"`
	FixType  fixer.FixType  `json:"fix_type"`
	Severity string         `json:"severity,omitempty"`
}

type Plan struct {
	Root         string         `json:"root"`
	Instruction  string         `json:"instruction,omitempty"`
	FixType      fixer.FixType  `json:"fix_type"`
	CreatedAt    time.Time      `json:"created_at"`
	FilesScanned int            `json:"files_scanned"`
	Tasks        []Task         `json:"tasks"`
	Notes        []string       `json:"notes,omitempty"`
}

type Options struct {
	MaxTasks     int
	MaxFiles     int
	MaxFileSize  int64
	IncludeHidden bool
}

func DefaultOptions() Options {
	return Options{
		MaxTasks:     50,
		MaxFiles:     10,
		MaxFileSize:  1 * 1024 * 1024,
		IncludeHidden: false,
	}
}

func BuildPlan(path string, instruction string, opts Options) (*Plan, error) {
	if path == "" {
		path = "."
	}
	if opts.MaxTasks <= 0 {
		opts.MaxTasks = DefaultOptions().MaxTasks
	}
	if opts.MaxFiles <= 0 {
		opts.MaxFiles = DefaultOptions().MaxFiles
	}
	if opts.MaxFileSize <= 0 {
		opts.MaxFileSize = DefaultOptions().MaxFileSize
	}

	absPath, err := filepath.Abs(path)
	if err != nil {
		return nil, err
	}

	info, err := os.Stat(absPath)
	if err != nil {
		return nil, err
	}

	root := absPath
	var targetFile string
	if !info.IsDir() {
		targetFile = absPath
		root = filepath.Dir(absPath)
	}

	idx, err := index.Build(root, index.Options{
		MaxFileSize:   opts.MaxFileSize,
		IncludeHidden: opts.IncludeHidden,
	})
	if err != nil {
		return nil, err
	}

	files := idx.Files
	if targetFile != "" {
		filtered := make([]index.FileMeta, 0, 1)
		for _, f := range files {
			if f.Path == targetFile {
				filtered = append(filtered, f)
				break
			}
		}
		files = filtered
	}

	fixType := fixer.DetectFixType(instruction)
	tasks := make([]Task, 0)

	for _, f := range files {
		if f.TodoCount+f.FixmeCount == 0 {
			continue
		}
		todos, err := scanTodos(f.Path)
		if err != nil {
			continue
		}
		for _, t := range todos {
			kind := strings.ToLower(t.Kind)
			tasks = append(tasks, Task{
				ID:      nextTaskID(len(tasks) + 1),
				Kind:    kind,
				File:    f.Path,
				Line:    t.Line,
				Message: t.Message,
				FixType: fixer.FixComplete,
			})
			if len(tasks) >= opts.MaxTasks {
				break
			}
		}
		if len(tasks) >= opts.MaxTasks {
			break
		}
	}

	if len(tasks) == 0 {
		candidates := idx.TopByLines(opts.MaxFiles)
		if targetFile != "" {
			candidates = files
		}

		for _, f := range candidates {
			taskKind := "instruction"
			taskMessage := instruction
			taskFixType := fixType

			if instruction == "" {
				taskKind = "review"
				taskMessage = "Review this file for issues and improvements."
				taskFixType = fixer.FixGeneral
			}

			tasks = append(tasks, Task{
				ID:      nextTaskID(len(tasks) + 1),
				Kind:    taskKind,
				File:    f.Path,
				Message: taskMessage,
				FixType: taskFixType,
			})
			if len(tasks) >= opts.MaxTasks {
				break
			}
		}
	}

	plan := &Plan{
		Root:         root,
		Instruction:  instruction,
		FixType:      fixType,
		CreatedAt:    time.Now(),
		FilesScanned: len(files),
		Tasks:        tasks,
	}

	if len(files) == 0 {
		plan.Notes = append(plan.Notes, "No files matched the provided path.")
	}

	return plan, nil
}

type todoRef struct {
	Line    int
	Kind    string
	Message string
}

func scanTodos(path string) ([]todoRef, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	buf := make([]byte, 0, 64*1024)
	scanner.Buffer(buf, 1024*1024)

	todos := make([]todoRef, 0, 4)
	lineNum := 0

	for scanner.Scan() {
		lineNum++
		line := scanner.Text()
		upper := strings.ToUpper(line)
		if strings.Contains(upper, "TODO") {
			message := extractTodoMessage(line, "TODO")
			todos = append(todos, todoRef{
				Line:    lineNum,
				Kind:    "TODO",
				Message: message,
			})
			continue
		}
		if strings.Contains(upper, "FIXME") {
			message := extractTodoMessage(line, "FIXME")
			todos = append(todos, todoRef{
				Line:    lineNum,
				Kind:    "FIXME",
				Message: message,
			})
		}
	}

	if err := scanner.Err(); err != nil {
		return todos, err
	}

	return todos, nil
}

func extractTodoMessage(line string, token string) string {
	upper := strings.ToUpper(line)
	idx := strings.Index(upper, token)
	if idx == -1 {
		return strings.TrimSpace(line)
	}
	message := line[idx+len(token):]
	message = strings.TrimLeft(message, " :#-")
	message = strings.TrimSpace(message)
	if message == "" {
		message = fmt.Sprintf("%s item", strings.ToLower(token))
	}
	return message
}

func nextTaskID(n int) string {
	return fmt.Sprintf("T-%03d", n)
}

func RenderText(plan *Plan) string {
	var sb strings.Builder

	sb.WriteString("Plan\n")
	sb.WriteString("----\n")
	sb.WriteString(fmt.Sprintf("Root: %s\n", plan.Root))
	if plan.Instruction != "" {
		sb.WriteString(fmt.Sprintf("Instruction: %s\n", plan.Instruction))
	}
	sb.WriteString(fmt.Sprintf("Fix type: %s\n", plan.FixType))
	sb.WriteString(fmt.Sprintf("Files scanned: %d\n", plan.FilesScanned))
	sb.WriteString(fmt.Sprintf("Tasks: %d\n", len(plan.Tasks)))
	sb.WriteString("\n")

	if len(plan.Notes) > 0 {
		sb.WriteString("Notes:\n")
		for _, note := range plan.Notes {
			sb.WriteString(fmt.Sprintf("  - %s\n", note))
		}
		sb.WriteString("\n")
	}

	if len(plan.Tasks) == 0 {
		sb.WriteString("No tasks generated.\n")
		return sb.String()
	}

	sb.WriteString("Tasks:\n")
	for _, task := range plan.Tasks {
		rel := fsutil.RelPath(plan.Root, task.File)
		if task.Line > 0 {
			sb.WriteString(fmt.Sprintf("  - [%s] %s:%d (%s) %s\n", task.ID, rel, task.Line, task.Kind, task.Message))
		} else {
			sb.WriteString(fmt.Sprintf("  - [%s] %s (%s) %s\n", task.ID, rel, task.Kind, task.Message))
		}
	}

	return sb.String()
}
