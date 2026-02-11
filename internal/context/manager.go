package context

import (
	"fmt"
	"path/filepath"
	"strings"

	"github.com/croberts/obot/internal/config"
)

// Manager builds token-budget-aware context for LLM prompts.
// Port of IDE ContextManager to Go.
type Manager struct {
	cfg        config.ContextConfig
	budget     *Budget
	memory     *Memory
	errors     *ErrorLearner
	compressor *Compressor
}

// FileContent represents a file to include in context.
type FileContent struct {
	Path      string
	Content   string
	Priority  float64 // 0.0–1.0, higher = more important
	Relevance float64 // Computed relevance score
}

// HistoryEntry represents a conversation turn.
type HistoryEntry struct {
	Role    string
	Content string
}

// BuildOptions specifies what to include in the built context.
type BuildOptions struct {
	Task        string
	Files       []FileContent
	ProjectInfo string
	History     []HistoryEntry
	MaxTokens   int
	Intent      string
}

// BuiltContext is the result of context building.
type BuiltContext struct {
	SystemPrompt  string
	UserPrompt    string
	TokensUsed    int
	TokenBudget   int
	FilesIncluded int
	Compressed    bool
}

// NewManager creates a new context manager from config.
func NewManager(cfg config.ContextConfig) *Manager {
	cfgDir := config.UnifiedConfigDir()

	return &Manager{
		cfg:    cfg,
		budget: NewBudget(cfg.MaxTokens, cfg.BudgetAllocation),
		memory: NewMemory(filepath.Join(cfgDir, "memory.json")),
		errors: NewErrorLearner(filepath.Join(cfgDir, "learned_patterns.json")),
		compressor: NewCompressor(
			cfg.Compression.Strategy,
			cfg.Compression.Preserve,
		),
	}
}

// Build constructs the full context within token budget constraints.
func (m *Manager) Build(opts BuildOptions) (*BuiltContext, error) {
	maxTokens := opts.MaxTokens
	if maxTokens <= 0 {
		maxTokens = m.cfg.MaxTokens
	}
	if maxTokens <= 0 {
		maxTokens = 32768
	}

	budget := NewBudget(maxTokens, m.cfg.BudgetAllocation)

	var systemParts []string
	var userParts []string
	totalUsed := 0
	compressed := false

	// 1. Task description
	if opts.Task != "" {
		taskText := opts.Task
		taskTokens := CountTokens(taskText)
		if taskTokens > budget.Task {
			taskText = TruncateToTokens(taskText, budget.Task)
			compressed = true
		}
		userParts = append(userParts, fmt.Sprintf("## Task\n%s", taskText))
		totalUsed += CountTokens(taskText)
	}

	// 2. Project info
	if opts.ProjectInfo != "" {
		projText := opts.ProjectInfo
		projTokens := CountTokens(projText)
		if projTokens > budget.Project {
			projText = TruncateToTokens(projText, budget.Project)
			compressed = true
		}
		userParts = append(userParts, fmt.Sprintf("## Project\n%s", projText))
		totalUsed += CountTokens(projText)
	}

	// 3. File content (largest budget slice)
	filesIncluded := 0
	if len(opts.Files) > 0 {
		filesBudget := budget.Files
		var fileParts []string

		for _, f := range opts.Files {
			content := f.Content
			contentTokens := CountTokens(content)

			if contentTokens > filesBudget {
				content = m.compressor.Compress(content, filesBudget)
				compressed = true
			}

			finalTokens := CountTokens(content)
			if totalUsed+finalTokens > maxTokens-budget.Reserve {
				break
			}

			fileParts = append(fileParts, fmt.Sprintf("### %s\n```\n%s\n```", f.Path, content))
			totalUsed += finalTokens
			filesBudget -= finalTokens
			filesIncluded++
		}

		if len(fileParts) > 0 {
			userParts = append(userParts, fmt.Sprintf("## Files\n%s", strings.Join(fileParts, "\n\n")))
		}
	}

	// 4. Conversation history
	if len(opts.History) > 0 {
		histBudget := budget.History
		var histParts []string
		histUsed := 0

		// Walk backward from most recent
		for i := len(opts.History) - 1; i >= 0; i-- {
			entry := opts.History[i]
			entryTokens := CountTokens(entry.Content)
			if histUsed+entryTokens > histBudget {
				break
			}
			histParts = append([]string{fmt.Sprintf("[%s]: %s", entry.Role, entry.Content)}, histParts...)
			histUsed += entryTokens
		}

		if len(histParts) > 0 {
			userParts = append(userParts, fmt.Sprintf("## History\n%s", strings.Join(histParts, "\n")))
			totalUsed += histUsed
		}
	}

	// 5. Memory patterns
	memEntries := m.memory.GetRecent(budget.Memory)
	if len(memEntries) > 0 {
		var memParts []string
		for _, e := range memEntries {
			memParts = append(memParts, fmt.Sprintf("[%s]: %s", e.Role, e.Content))
		}
		userParts = append(userParts, fmt.Sprintf("## Memory\n%s", strings.Join(memParts, "\n")))
		for _, e := range memEntries {
			totalUsed += e.Tokens
		}
	}

	// 6. Error patterns
	errPatterns := m.errors.GetTopPatterns(budget.Errors)
	if len(errPatterns) > 0 {
		var errParts []string
		for _, p := range errPatterns {
			line := fmt.Sprintf("- %s", p.Pattern)
			if p.Resolution != "" {
				line += fmt.Sprintf(" → %s", p.Resolution)
			}
			errParts = append(errParts, line)
		}
		userParts = append(userParts, fmt.Sprintf("## Known Error Patterns\n%s", strings.Join(errParts, "\n")))
	}

	// Build system prompt based on intent
	systemPrompt := buildSystemPrompt(opts.Intent)
	systemParts = append(systemParts, systemPrompt)

	return &BuiltContext{
		SystemPrompt:  strings.Join(systemParts, "\n\n"),
		UserPrompt:    strings.Join(userParts, "\n\n"),
		TokensUsed:    totalUsed,
		TokenBudget:   maxTokens,
		FilesIncluded: filesIncluded,
		Compressed:    compressed,
	}, nil
}

// RecordMemory adds a conversation entry to memory.
func (m *Manager) RecordMemory(role, content string) {
	m.memory.Add(role, content)
}

// RecordError records an error pattern for future reference.
func (m *Manager) RecordError(pattern, resolution string) {
	m.errors.Record(pattern, resolution)
}

// SaveState persists memory and error patterns to disk.
func (m *Manager) SaveState() error {
	if err := m.memory.Save(); err != nil {
		return err
	}
	return m.errors.Save()
}

// buildSystemPrompt creates a system prompt based on intent.
func buildSystemPrompt(intent string) string {
	base := "You are obot, a local AI-powered coding assistant. "

	switch intent {
	case "coding":
		return base + "Focus on producing correct, minimal, well-tested code changes."
	case "research":
		return base + "Focus on gathering accurate, relevant information from available sources."
	case "writing":
		return base + "Focus on clear, concise technical writing."
	case "vision":
		return base + "Analyze the provided visual content and describe findings."
	default:
		return base + "Help the user with their coding task."
	}
}
