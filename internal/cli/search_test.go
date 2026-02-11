package cli

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/croberts/obot/internal/index"
)

func TestSearchIntegratesWithIndex(t *testing.T) {
	// Create a temp directory for our test index
	tmpDir, err := os.MkdirTemp("", "obot-search-test-*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	// Create a mock index
	idx := index.NewIndex(tmpDir)
	idx.Files = append(idx.Files, index.FileMeta{
		RelPath: "test.go",
		Path:    filepath.Join(tmpDir, "test.go"),
		Symbols: []index.Symbol{
			{Name: "TestFunction", Type: index.SymbolFunction, Line: 10},
		},
	})
	
	indexPath := filepath.Join(tmpDir, "index.json")
	if err := idx.Save(indexPath); err != nil {
		t.Fatal(err)
	}

	// Now we can test the index methods that the CLI uses
	loadedIdx, err := index.Load(indexPath)
	if err != nil {
		t.Fatalf("Failed to load index: %v", err)
	}

	// Test general search (as used in search.go)
	results := loadedIdx.Search("TestFunction")
	if len(results) == 0 {
		t.Error("Expected to find TestFunction in search results")
	}

	found := false
	for _, res := range results {
		if res.Symbol != nil && res.Symbol.Name == "TestFunction" {
			found = true
			break
		}
	}
	if !found {
		t.Error("Did not find TestFunction symbol in results")
	}

	// Test symbol-only search
	symResults := loadedIdx.SearchSymbols("TestFunction")
	if len(symResults) == 0 {
		t.Error("Expected to find TestFunction in symbol search results")
	}
}
