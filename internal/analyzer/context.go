package analyzer

import (
	"fmt"
	"strings"
)

// ContextBuilder builds context for the AI model
type ContextBuilder struct {
	fc          *FileContext
	instruction string
}

// NewContextBuilder creates a new context builder
func NewContextBuilder(fc *FileContext) *ContextBuilder {
	return &ContextBuilder{fc: fc}
}

// WithInstruction adds a user instruction
func (cb *ContextBuilder) WithInstruction(instruction string) *ContextBuilder {
	cb.instruction = instruction
	return cb
}

// BuildSystemPrompt builds the system prompt for code fixing
func (cb *ContextBuilder) BuildSystemPrompt() string {
	var sb strings.Builder

	sb.WriteString("You are an expert code fixer. Your task is to fix and improve code.\n\n")
	sb.WriteString("Rules:\n")
	sb.WriteString("1. Output ONLY the fixed code, no explanations\n")
	sb.WriteString("2. Preserve the original code style and formatting\n")
	sb.WriteString("3. Do not add unnecessary comments\n")
	sb.WriteString("4. Fix bugs, improve error handling, and follow best practices\n")
	sb.WriteString("5. If no issues are found, return the original code unchanged\n")

	if cb.fc.Language != LangUnknown {
		sb.WriteString(fmt.Sprintf("\nLanguage: %s\n", cb.fc.Language.DisplayName()))
	}

	return sb.String()
}

// BuildUserPrompt builds the user prompt with code context
func (cb *ContextBuilder) BuildUserPrompt() string {
	var sb strings.Builder

	// Add instruction if provided
	if cb.instruction != "" {
		sb.WriteString(fmt.Sprintf("Task: %s\n\n", cb.instruction))
	} else {
		sb.WriteString("Task: Fix any issues in the following code.\n\n")
	}

	// Add file info
	sb.WriteString(fmt.Sprintf("File: %s\n", cb.fc.FileName()))

	if cb.fc.IsPartialFix() {
		sb.WriteString(fmt.Sprintf("Lines: %d-%d\n", cb.fc.StartLine, cb.fc.EndLine))

		// Add surrounding context
		before, after := cb.fc.GetContext(5)
		if before != "" {
			sb.WriteString("\n--- Context before ---\n")
			sb.WriteString(before)
			sb.WriteString("\n--- End context ---\n")
		}

		sb.WriteString("\n--- Code to fix ---\n")
		sb.WriteString(cb.fc.GetTargetLines())
		sb.WriteString("\n--- End code ---\n")

		if after != "" {
			sb.WriteString("\n--- Context after ---\n")
			sb.WriteString(after)
			sb.WriteString("\n--- End context ---\n")
		}
	} else {
		sb.WriteString("\n```")
		sb.WriteString(string(cb.fc.Language))
		sb.WriteString("\n")
		sb.WriteString(cb.fc.FullContent)
		sb.WriteString("\n```\n")
	}

	sb.WriteString("\nOutput only the fixed code:")

	return sb.String()
}

// EstimateTokens provides a rough estimate of tokens in the context
func (cb *ContextBuilder) EstimateTokens() int {
	// Rough estimate: 4 characters per token
	systemPrompt := cb.BuildSystemPrompt()
	userPrompt := cb.BuildUserPrompt()

	totalChars := len(systemPrompt) + len(userPrompt)
	return totalChars / 4
}

// Summary returns a summary of what will be fixed
type Summary struct {
	File        string
	Language    string
	TotalLines  int
	TargetLines int
	IsPartial   bool
	Instruction string
}

// GetSummary returns a summary of the fix context
func (cb *ContextBuilder) GetSummary() Summary {
	return Summary{
		File:        cb.fc.FileName(),
		Language:    cb.fc.Language.DisplayName(),
		TotalLines:  len(cb.fc.Lines),
		TargetLines: cb.fc.LineCount(),
		IsPartial:   cb.fc.IsPartialFix(),
		Instruction: cb.instruction,
	}
}
