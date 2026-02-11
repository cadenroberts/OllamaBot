package index

import (
	"context"
	"fmt"
	"math"
	"sort"

	"github.com/croberts/obot/internal/ollama"
)

// Embedding represents a vector embedding for a piece of text.
type Embedding []float32

// FileEmbedding stores embeddings for a file.
type FileEmbedding struct {
	RelPath   string    `json:"rel_path"`
	Embedding Embedding `json:"embedding"`
}

// SemanticIndex manages embeddings for semantic search.
type SemanticIndex struct {
	client     *ollama.Client
	model      string
	embeddings []FileEmbedding
}

// NewSemanticIndex creates a new semantic index using Ollama.
func NewSemanticIndex(client *ollama.Client, model string) *SemanticIndex {
	if model == "" {
		model = "nomic-embed-text"
	}
	return &SemanticIndex{
		client:     client,
		model:      model,
		embeddings: make([]FileEmbedding, 0),
	}
}

// AddFile generates and adds an embedding for a file.
func (s *SemanticIndex) AddFile(ctx context.Context, relPath, content string) error {
	emb, err := s.generateEmbedding(ctx, content)
	if err != nil {
		return err
	}
	s.embeddings = append(s.embeddings, FileEmbedding{
		RelPath:   relPath,
		Embedding: emb,
	})
	return nil
}

// Search performs a cosine similarity search against the index.
func (s *SemanticIndex) Search(ctx context.Context, query string, limit int) ([]string, error) {
	if len(s.embeddings) == 0 {
		return []string{}, nil
	}

	queryEmb, err := s.generateEmbedding(ctx, query)
	if err != nil {
		return nil, err
	}

	type match struct {
		relPath string
		score   float32
	}
	matches := make([]match, len(s.embeddings))

	for i, fe := range s.embeddings {
		matches[i] = match{
			relPath: fe.RelPath,
			score:   cosineSimilarity(queryEmb, fe.Embedding),
		}
	}

	// Sort by score descending
	sort.Slice(matches, func(i, j int) bool {
		return matches[i].score > matches[j].score
	})

	if len(matches) > limit {
		matches = matches[:limit]
	}

	result := make([]string, len(matches))
	for i, m := range matches {
		result[i] = m.relPath
	}

	return result, nil
}

func (s *SemanticIndex) generateEmbedding(ctx context.Context, text string) (Embedding, error) {
	// Truncate text if it's too long for the embedding model (heuristic)
	if len(text) > 8192 {
		text = text[:8192]
	}

	resp, err := s.client.Embeddings(ctx, s.model, text)
	if err != nil {
		return nil, fmt.Errorf("failed to generate embedding: %w", err)
	}

	emb := make(Embedding, len(resp))
	for i, v := range resp {
		emb[i] = float32(v)
	}
	return emb, nil
}

func cosineSimilarity(a, b Embedding) float32 {
	if len(a) != len(b) || len(a) == 0 {
		return 0
	}
	var dotProduct, normA, normB float32
	for i := range a {
		dotProduct += a[i] * b[i]
		normA += a[i] * a[i]
		normB += b[i] * b[i]
	}
	if normA == 0 || normB == 0 {
		return 0
	}
	return dotProduct / (float32(math.Sqrt(float64(normA))) * float32(math.Sqrt(float64(normB))))
}

// PROOF:
// - ZERO-HIT: No SemanticIndex or embedding logic existed in internal/index.
// - POSITIVE-HIT: SemanticIndex implemented in internal/index/embeddings.go using Ollama embeddings API.
// - PARITY: Supports nomic-embed-text and cosine similarity search.
