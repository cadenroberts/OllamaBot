package fixer

import (
	"context"
	"fmt"
	"time"

	"github.com/croberts/obot/internal/analyzer"
	"github.com/croberts/obot/internal/ollama"
)

// Engine handles the code fixing logic
type Engine struct {
	client *ollama.Client
}

// NewEngine creates a new fix engine
func NewEngine(client *ollama.Client) *Engine {
	return &Engine{client: client}
}

// FixResult contains the result of a fix operation
type FixResult struct {
	OriginalCode string
	FixedCode    string
	Stats        *ollama.InferenceStats
	Duration     time.Duration
	Changed      bool
}

// Fix performs a code fix on the given file context
func (e *Engine) Fix(ctx context.Context, fc *analyzer.FileContext, instruction string) (*FixResult, error) {
	startTime := time.Now()

	// Build the prompt
	prompt := BuildPrompt(fc, instruction)

	// Call the model
	response, stats, err := e.client.Generate(ctx, prompt)
	if err != nil {
		return nil, fmt.Errorf("generation failed: %w", err)
	}

	// Extract the fixed code
	fixedCode := ExtractCode(response, fc.Language)

	// Check if code actually changed
	originalCode := fc.GetTargetLines()
	changed := fixedCode != originalCode

	return &FixResult{
		OriginalCode: originalCode,
		FixedCode:    fixedCode,
		Stats:        stats,
		Duration:     time.Since(startTime),
		Changed:      changed,
	}, nil
}

// FixStream performs a code fix with streaming output
func (e *Engine) FixStream(ctx context.Context, fc *analyzer.FileContext, instruction string, callback ollama.StreamCallback) (*FixResult, error) {
	startTime := time.Now()

	// Build the prompt
	prompt := BuildPrompt(fc, instruction)

	// Call the model with streaming
	result, err := e.client.GenerateStream(ctx, prompt, callback)
	if err != nil {
		return nil, fmt.Errorf("generation failed: %w", err)
	}

	// Extract the fixed code
	fixedCode := ExtractCode(result.Content, fc.Language)

	// Check if code actually changed
	originalCode := fc.GetTargetLines()
	changed := fixedCode != originalCode

	return &FixResult{
		OriginalCode: originalCode,
		FixedCode:    fixedCode,
		Stats:        result.Stats,
		Duration:     time.Since(startTime),
		Changed:      changed,
	}, nil
}

// FixOptions configures the fix operation
type FixOptions struct {
	Instruction string
	FixType     FixType
	DryRun      bool
	ShowDiff    bool
	MaxTokens   int
	Temperature float64
}

// DefaultOptions returns default fix options
func DefaultOptions() FixOptions {
	return FixOptions{
		FixType:     FixGeneral,
		DryRun:      false,
		ShowDiff:    false,
		MaxTokens:   4096,
		Temperature: 0.3,
	}
}
