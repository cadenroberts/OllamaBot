package fixer

import (
	"fmt"
	"strings"

	"github.com/croberts/obot/internal/analyzer"
	"github.com/croberts/obot/internal/ollama"
)

func BuildPlanMessages(fc *analyzer.FileContext, instruction string, repoSummary string, fixType FixType) []ollama.Message {
	system := strings.TrimSpace(fmt.Sprintf(`You are a senior software planner.
Create a concise fix plan for the task. Do NOT output code.
Return a numbered list with at most 8 steps. Include key risks if any.
`))

	user := buildContextForPlan(fc, instruction, repoSummary, fixType)

	return []ollama.Message{
		{Role: "system", Content: system},
		{Role: "user", Content: user},
	}
}

func BuildFixMessages(fc *analyzer.FileContext, instruction string, repoSummary string, plan string, reviewNotes string, fixType FixType) []ollama.Message {
	system := strings.TrimSpace(fmt.Sprintf(`%s

Follow the plan if provided. Use the review notes to correct mistakes.
Output ONLY the fixed code, nothing else. Do not add markdown fences.`, SystemPrompts[fixType]))

	var sb strings.Builder
	if plan != "" {
		sb.WriteString("Plan:\n")
		sb.WriteString(plan)
		sb.WriteString("\n\n")
	}
	if reviewNotes != "" {
		sb.WriteString("Review notes:\n")
		sb.WriteString(reviewNotes)
		sb.WriteString("\n\n")
	}
	if repoSummary != "" {
		sb.WriteString("Repo context:\n")
		sb.WriteString(repoSummary)
		sb.WriteString("\n\n")
	}
	sb.WriteString(BuildContextBlock(fc, instruction, true))

	return []ollama.Message{
		{Role: "system", Content: system},
		{Role: "user", Content: sb.String()},
	}
}

func BuildReviewMessages(fc *analyzer.FileContext, instruction string, original string, fixed string) []ollama.Message {
	system := strings.TrimSpace(`You are a strict code reviewer.
Compare the original and proposed code. If the fix is correct and safe,
output EXACTLY: OK
Otherwise list issues as bullet points, with line references if possible.
Do NOT output code.`)

	var sb strings.Builder
	if fc.Language != analyzer.LangUnknown {
		sb.WriteString(fmt.Sprintf("Language: %s\n", fc.Language.DisplayName()))
	}
	if instruction != "" {
		sb.WriteString(fmt.Sprintf("Task: %s\n", instruction))
	}

	sb.WriteString("Original:\n```")
	sb.WriteString(string(fc.Language))
	sb.WriteString("\n")
	sb.WriteString(original)
	sb.WriteString("\n```\n\n")

	sb.WriteString("Proposed:\n```")
	sb.WriteString(string(fc.Language))
	sb.WriteString("\n")
	sb.WriteString(fixed)
	sb.WriteString("\n```\n")

	return []ollama.Message{
		{Role: "system", Content: system},
		{Role: "user", Content: sb.String()},
	}
}

func buildContextForPlan(fc *analyzer.FileContext, instruction string, repoSummary string, fixType FixType) string {
	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("Fix type: %s\n\n", fixType))
	if repoSummary != "" {
		sb.WriteString("Repo context:\n")
		sb.WriteString(repoSummary)
		sb.WriteString("\n\n")
	}
	sb.WriteString(BuildContextBlock(fc, instruction, false))
	return sb.String()
}
