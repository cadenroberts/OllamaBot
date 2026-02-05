package fixer

import (
	"fmt"
	"strings"

	"github.com/croberts/obot/internal/analyzer"
)

// FixType represents the type of fix to perform
type FixType string

const (
	FixGeneral  FixType = "general"  // General code fixing
	FixLint     FixType = "lint"     // Fix linter errors
	FixBug      FixType = "bug"      // Fix bugs
	FixRefactor FixType = "refactor" // Small refactoring
	FixComplete FixType = "complete" // Complete TODO/FIXME
	FixOptimize FixType = "optimize" // Performance optimization
	FixDoc      FixType = "doc"      // Add/fix documentation
	FixTypes    FixType = "types"    // Fix/add type annotations
)

// SystemPrompts contains task-specific system prompts
var SystemPrompts = map[FixType]string{
	FixGeneral: `You are an expert code fixer. Analyze the code and fix any issues you find.

Rules:
- Output ONLY the corrected code, no explanations or markdown
- Preserve the original code style and indentation
- Fix bugs, improve error handling, follow best practices
- Do not add unnecessary comments
- If no issues are found, return the code unchanged`,

	FixLint: `You are a code quality expert. Fix linter errors and warnings in the code.

Rules:
- Output ONLY the corrected code, no explanations or markdown
- Fix unused variables, imports, and declarations
- Fix formatting and style issues
- Ensure proper error handling
- Follow language idioms and conventions
- Preserve functionality - only fix style/lint issues`,

	FixBug: `You are a debugging expert. Find and fix bugs in the code.

Focus on:
- Null/nil pointer dereferences
- Off-by-one errors
- Array bounds checking
- Type mismatches
- Logic errors
- Race conditions
- Resource leaks

Rules:
- Output ONLY the corrected code, no explanations or markdown
- Be conservative - only fix actual bugs
- Add defensive checks where appropriate
- Preserve the original logic intent`,

	FixRefactor: `You are a refactoring expert. Improve the code structure without changing functionality.

Focus on:
- Extract repeated code into functions
- Simplify complex conditionals
- Improve variable naming
- Reduce nesting depth
- Apply DRY principle
- Improve readability

Rules:
- Output ONLY the refactored code, no explanations or markdown
- Do NOT change the external behavior
- Preserve all existing functionality
- Keep changes minimal and focused`,

	FixComplete: `You are a code completion expert. Complete TODO and FIXME comments in the code.

Rules:
- Output ONLY the completed code, no explanations or markdown
- Implement the functionality described in TODO/FIXME comments
- Remove the TODO/FIXME comments after implementing
- Follow the existing code style
- Add appropriate error handling`,

	FixOptimize: `You are a performance optimization expert. Optimize the code for better performance.

Focus on:
- Reduce unnecessary allocations
- Use efficient data structures
- Avoid redundant computations
- Optimize loops and iterations
- Use language-specific optimizations

Rules:
- Output ONLY the optimized code, no explanations or markdown
- Do NOT change the external behavior
- Prefer readability over micro-optimizations
- Document any non-obvious optimizations with brief comments`,

	FixDoc: `You are a documentation expert. Add or improve code documentation.

Rules:
- Output ONLY the documented code, no explanations or markdown
- Add clear, concise documentation comments
- Document public functions, types, and constants
- Explain complex logic with inline comments
- Follow the language's documentation conventions
- Do not over-document obvious code`,

	FixTypes: `You are a type safety expert. Add or fix type annotations in the code.

Rules:
- Output ONLY the typed code, no explanations or markdown
- Add type annotations to function parameters and returns
- Fix incorrect type declarations
- Use proper generic types where appropriate
- Prefer explicit types over 'any' or 'unknown'`,
}

// DetectFixType tries to detect the appropriate fix type from an instruction
func DetectFixType(instruction string) FixType {
	lower := strings.ToLower(instruction)

	switch {
	case strings.Contains(lower, "lint") || strings.Contains(lower, "warning"):
		return FixLint
	case strings.Contains(lower, "bug") || strings.Contains(lower, "fix"):
		return FixBug
	case strings.Contains(lower, "refactor") || strings.Contains(lower, "clean"):
		return FixRefactor
	case strings.Contains(lower, "todo") || strings.Contains(lower, "implement") || strings.Contains(lower, "complete"):
		return FixComplete
	case strings.Contains(lower, "optim") || strings.Contains(lower, "perf") || strings.Contains(lower, "fast"):
		return FixOptimize
	case strings.Contains(lower, "doc") || strings.Contains(lower, "comment"):
		return FixDoc
	case strings.Contains(lower, "type"):
		return FixTypes
	default:
		return FixGeneral
	}
}

// BuildPrompt builds a complete prompt for the AI model
func BuildPrompt(fc *analyzer.FileContext, instruction string) string {
	var sb strings.Builder

	// Detect fix type
	fixType := DetectFixType(instruction)

	// Add system prompt
	systemPrompt := SystemPrompts[fixType]
	sb.WriteString(systemPrompt)
	sb.WriteString("\n\n")
	sb.WriteString(BuildContextBlock(fc, instruction, true))

	return sb.String()
}

// GetSystemPrompt returns the system prompt for a fix type
func GetSystemPrompt(fixType FixType) string {
	if prompt, ok := SystemPrompts[fixType]; ok {
		return prompt
	}
	return SystemPrompts[FixGeneral]
}

// BuildContextBlock builds the context section for a prompt
func BuildContextBlock(fc *analyzer.FileContext, instruction string, includeOutputInstruction bool) string {
	var sb strings.Builder

	// Add language hint
	if fc.Language != analyzer.LangUnknown {
		sb.WriteString(fmt.Sprintf("Language: %s\n\n", fc.Language.DisplayName()))
	}

	// Add instruction if provided
	if instruction != "" {
		sb.WriteString(fmt.Sprintf("Specific task: %s\n\n", instruction))
	}

	// Add file context
	sb.WriteString(fmt.Sprintf("File: %s\n", fc.FileName()))

	if fc.IsPartialFix() {
		sb.WriteString(fmt.Sprintf("Lines: %d-%d\n\n", fc.StartLine, fc.EndLine))

		// Add context before
		before, after := fc.GetContext(3)
		if before != "" {
			sb.WriteString("Context before:\n")
			sb.WriteString("```\n")
			sb.WriteString(before)
			sb.WriteString("\n```\n\n")
		}

		// Add target code
		sb.WriteString("Code to fix:\n")
		sb.WriteString("```")
		sb.WriteString(string(fc.Language))
		sb.WriteString("\n")
		sb.WriteString(fc.GetTargetLines())
		sb.WriteString("\n```\n\n")

		// Add context after
		if after != "" {
			sb.WriteString("Context after:\n")
			sb.WriteString("```\n")
			sb.WriteString(after)
			sb.WriteString("\n```\n\n")
		}

		if includeOutputInstruction {
			sb.WriteString("Output ONLY the fixed code for lines ")
			sb.WriteString(fmt.Sprintf("%d-%d", fc.StartLine, fc.EndLine))
			sb.WriteString(", nothing else:")
		}
	} else {
		// Full file
		sb.WriteString("\n```")
		sb.WriteString(string(fc.Language))
		sb.WriteString("\n")
		sb.WriteString(fc.FullContent)
		sb.WriteString("\n```\n\n")
		if includeOutputInstruction {
			sb.WriteString("Output ONLY the fixed code, nothing else:")
		}
	}

	return sb.String()
}
