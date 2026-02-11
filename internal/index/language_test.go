package index

import (
	"testing"
	"time"

	"github.com/croberts/obot/internal/analyzer"
)

func TestLanguageStats(t *testing.T) {
	idx := &Index{
		Files: []FileMeta{
			{
				Path:      "main.go",
				RelPath:   "main.go",
				SizeBytes: 1000,
				Language:  analyzer.LangGo,
				Lines:     100,
			},
			{
				Path:      "util.go",
				RelPath:   "util.go",
				SizeBytes: 500,
				Language:  analyzer.LangGo,
				Lines:     50,
			},
			{
				Path:      "script.py",
				RelPath:   "script.py",
				SizeBytes: 200,
				Language:  analyzer.LangPython,
				Lines:     20,
			},
		},
		CreatedAt: time.Now(),
	}

	stats := idx.GetLanguageStats()

	if len(stats) != 2 {
		t.Errorf("expected 2 languages, got %d", len(stats))
	}

	goStats, ok := stats[analyzer.LangGo]
	if !ok {
		t.Fatal("expected Go stats")
	}
	if goStats.FileCount != 2 {
		t.Errorf("expected 2 Go files, got %d", goStats.FileCount)
	}
	if goStats.TotalLines != 150 {
		t.Errorf("expected 150 Go lines, got %d", goStats.TotalLines)
	}
	if goStats.TotalSize != 1500 {
		t.Errorf("expected 1500 Go bytes, got %d", goStats.TotalSize)
	}

	pyStats, ok := stats[analyzer.LangPython]
	if !ok {
		t.Fatal("expected Python stats")
	}
	if pyStats.FileCount != 1 {
		t.Errorf("expected 1 Python file, got %d", pyStats.FileCount)
	}
	if pyStats.TotalLines != 20 {
		t.Errorf("expected 20 Python lines, got %d", pyStats.TotalLines)
	}
	if pyStats.TotalSize != 200 {
		t.Errorf("expected 200 Python bytes, got %d", pyStats.TotalSize)
	}
}

func TestSummaryByLanguage(t *testing.T) {
	idx := &Index{
		Files: []FileMeta{
			{
				Path:      "main.go",
				RelPath:   "main.go",
				SizeBytes: 1000,
				Language:  analyzer.LangGo,
				Lines:     100,
			},
		},
	}

	summary := idx.SummaryByLanguage()
	if summary == "" {
		t.Fatal("expected summary, got empty string")
	}
	if !testing.Short() {
		t.Logf("\n%s", summary)
	}
}
