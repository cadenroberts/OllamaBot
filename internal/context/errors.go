package context

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"sync"
	"time"
)

// ErrorPattern represents a learned error pattern.
type ErrorPattern struct {
	Pattern    string    `json:"pattern"`
	Resolution string    `json:"resolution"`
	Frequency  int       `json:"frequency"`
	LastSeen   time.Time `json:"last_seen"`
}

// ErrorLearner tracks recurring error patterns and their resolutions.
type ErrorLearner struct {
	mu       sync.Mutex
	patterns []ErrorPattern
	path     string
}

// NewErrorLearner creates a new error learner.
func NewErrorLearner(storePath string) *ErrorLearner {
	el := &ErrorLearner{
		patterns: make([]ErrorPattern, 0),
		path:     storePath,
	}
	_ = el.load()
	return el
}

// Record records an error pattern. If the pattern already exists, increments frequency.
func (el *ErrorLearner) Record(pattern, resolution string) {
	el.mu.Lock()
	defer el.mu.Unlock()

	for i := range el.patterns {
		if el.patterns[i].Pattern == pattern {
			el.patterns[i].Frequency++
			el.patterns[i].LastSeen = time.Now()
			if resolution != "" {
				el.patterns[i].Resolution = resolution
			}
			return
		}
	}

	el.patterns = append(el.patterns, ErrorPattern{
		Pattern:    pattern,
		Resolution: resolution,
		Frequency:  1,
		LastSeen:   time.Now(),
	})
}

// GetTopPatterns returns the most frequent error patterns that fit within maxTokens.
func (el *ErrorLearner) GetTopPatterns(maxTokens int) []ErrorPattern {
	el.mu.Lock()
	defer el.mu.Unlock()

	sorted := make([]ErrorPattern, len(el.patterns))
	copy(sorted, el.patterns)
	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].Frequency > sorted[j].Frequency
	})

	result := make([]ErrorPattern, 0)
	usedTokens := 0
	for _, p := range sorted {
		tokens := CountTokens(p.Pattern + p.Resolution)
		if usedTokens+tokens > maxTokens {
			break
		}
		result = append(result, p)
		usedTokens += tokens
	}
	return result
}

// Save persists error patterns to disk.
func (el *ErrorLearner) Save() error {
	el.mu.Lock()
	defer el.mu.Unlock()

	if el.path == "" {
		return nil
	}

	dir := filepath.Dir(el.path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}

	data, err := json.MarshalIndent(el.patterns, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(el.path, data, 0644)
}

func (el *ErrorLearner) load() error {
	if el.path == "" {
		return nil
	}

	data, err := os.ReadFile(el.path)
	if err != nil {
		return nil
	}

	return json.Unmarshal(data, &el.patterns)
}
