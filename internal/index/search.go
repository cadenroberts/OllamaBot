package index

import (
	"context"
	"os"
	"sort"
	"strings"

	"github.com/croberts/obot/internal/analyzer"
	"github.com/croberts/obot/internal/ollama"
)

// SearchResult represents a match in a symbol search.
type SearchResult struct {
	Symbol *Symbol  `json:"symbol,omitempty"`
	File   FileMeta `json:"file"`
}

// Search searches for a substring in file paths and symbol names.
func (idx *Index) Search(query string) []SearchResult {
	query = strings.ToLower(query)
	results := make([]SearchResult, 0)

	for _, f := range idx.Files {
		// Match path
		if strings.Contains(strings.ToLower(f.RelPath), query) {
			results = append(results, SearchResult{File: f})
			continue
		}

		// Match symbols
		for _, s := range f.Symbols {
			if strings.Contains(strings.ToLower(s.Name), query) {
				sym := s // Copy
				results = append(results, SearchResult{File: f, Symbol: &sym})
			}
		}
	}

	return results
}

// SemanticSearch performs a semantic search using embeddings.
func (idx *Index) SemanticSearch(ctx context.Context, client *ollama.Client, query string, limit int) ([]SearchResult, error) {
	if len(idx.Embeddings) == 0 {
		return nil, nil
	}

	semIdx := &SemanticIndex{
		client:     client,
		model:      "nomic-embed-text", // Default
		embeddings: idx.Embeddings,
	}

	matches, err := semIdx.Search(ctx, query, limit)
	if err != nil {
		return nil, err
	}

	// Map relative paths back to SearchResult
	results := make([]SearchResult, 0, len(matches))
	fileMap := make(map[string]FileMeta)
	for _, f := range idx.Files {
		fileMap[f.RelPath] = f
	}

	for _, relPath := range matches {
		if f, ok := fileMap[relPath]; ok {
			results = append(results, SearchResult{File: f})
		}
	}

	return results, nil
}

// SearchSymbols searches for symbols by name across the entire index.
func (idx *Index) SearchSymbols(query string) []SearchResult {
	query = strings.ToLower(query)
	results := make([]SearchResult, 0)

	for _, file := range idx.Files {
		for _, sym := range file.Symbols {
			if strings.Contains(strings.ToLower(sym.Name), query) {
				s := sym // Copy
				results = append(results, SearchResult{
					Symbol: &s,
					File:   file,
				})
			}
		}
	}

	return results
}

// SearchSymbolsByType searches for symbols of a specific type.
func (idx *Index) SearchSymbolsByType(query string, symType SymbolType) []SearchResult {
	query = strings.ToLower(query)
	results := make([]SearchResult, 0)

	for _, file := range idx.Files {
		for _, sym := range file.Symbols {
			if sym.Type == symType && (query == "" || strings.Contains(strings.ToLower(sym.Name), query)) {
				s := sym // Copy
				results = append(results, SearchResult{
					Symbol: &s,
					File:   file,
				})
			}
		}
	}

	return results
}

// FindFunctions searches for functions matching the query.
func (idx *Index) FindFunctions(query string) []SearchResult {
	return idx.SearchSymbolsByType(query, SymbolFunction)
}

// FindMethods searches for methods matching the query.
func (idx *Index) FindMethods(query string) []SearchResult {
	return idx.SearchSymbolsByType(query, SymbolMethod)
}

// FindClasses searches for classes or structs matching the query.
func (idx *Index) FindClasses(query string) []SearchResult {
	results := idx.SearchSymbolsByType(query, SymbolClass)
	results = append(results, idx.SearchSymbolsByType(query, SymbolStruct)...)
	return results
}

// FindInterfaces searches for interfaces matching the query.
func (idx *Index) FindInterfaces(query string) []SearchResult {
	return idx.SearchSymbolsByType(query, SymbolInterface)
}

// FilterByLanguage filters files by programming language.
func (idx *Index) FilterByLanguage(lang analyzer.Language) []FileMeta {
	matches := make([]FileMeta, 0)
	for _, f := range idx.Files {
		if f.Language == lang {
			matches = append(matches, f)
		}
	}
	return matches
}

// TopByLines returns the top N files by line count.
func (idx *Index) TopByLines(n int) []FileMeta {
	files := make([]FileMeta, len(idx.Files))
	copy(files, idx.Files)

	sort.Slice(files, func(i, j int) bool {
		return files[i].Lines > files[j].Lines
	})

	if n > 0 && len(files) > n {
		return files[:n]
	}
	return files
}

// SearchUses searches for occurrences of a string in file contents.
func (idx *Index) SearchUses(query string) []SearchResult {
	query = strings.ToLower(query)
	results := make([]SearchResult, 0)

	for _, f := range idx.Files {
		content, err := os.ReadFile(f.Path)
		if err != nil {
			continue
		}

		if strings.Contains(strings.ToLower(string(content)), query) {
			results = append(results, SearchResult{File: f})
		}
	}

	return results
}
