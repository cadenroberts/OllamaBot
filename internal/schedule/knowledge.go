// Package schedule implements the schedule logic for obot orchestration.
package schedule

import (
	"context"
	"fmt"
	"strings"

	"github.com/croberts/obot/internal/orchestrate"
)

// KnowledgeSchedule implements the logic for the Knowledge schedule.
// Processes: 
// 1. Research (identify gaps): Analyze intent and identify what's missing.
// 2. Crawl (extract content): Gather technical details from files and web.
// 3. Retrieve (structure info): Organize findings into a structured context.
type KnowledgeSchedule struct {
	// Internal tracking of findings to pass between processes
	Gaps      []string
	Sources   []string
	Findings  []string
}

// NewKnowledgeSchedule creates a new Knowledge schedule logic handler.
func NewKnowledgeSchedule() *KnowledgeSchedule {
	return &KnowledgeSchedule{
		Gaps:     make([]string, 0),
		Sources:  make([]string, 0),
		Findings: make([]string, 0),
	}
}

// ExecuteProcess executes a process within the Knowledge schedule.
func (s *KnowledgeSchedule) ExecuteProcess(ctx context.Context, processID orchestrate.ProcessID, exec func(context.Context, string) error) error {
	switch processID {
	case orchestrate.Process1:
		return s.Research(ctx, exec)
	case orchestrate.Process2:
		return s.Crawl(ctx, exec)
	case orchestrate.Process3:
		return s.Retrieve(ctx, exec)
	default:
		return fmt.Errorf("invalid process ID %d for Knowledge schedule", processID)
	}
}

// Research (P1) identifies knowledge gaps and plans the research.
func (s *KnowledgeSchedule) Research(ctx context.Context, exec func(context.Context, string) error) error {
	var sb strings.Builder
	sb.WriteString("### PROCESS: RESEARCH (Knowledge P1)\n")
	sb.WriteString("You are the researcher. Your mission is to IDENTIFY GAPS.\n\n")
	sb.WriteString("TASKS:\n")
	sb.WriteString("1. **Scan Workspace**: Use `list_dir` and `grep` to understand the current project structure.\n")
	sb.WriteString("2. **Identify Gaps**: Compare the user's prompt with available code/docs. What is missing?\n")
	sb.WriteString("3. **Identify Sources**: Find relevant files, APIs, or documentation that might contain the missing info.\n")
	sb.WriteString("4. **Plan Crawl**: List specific files or topics that need deep inspection in the next phase.\n\n")
	sb.WriteString("GUIDELINES:\n")
	sb.WriteString("- Focus on architectural patterns and existing conventions.\n")
	sb.WriteString("- Do NOT start implementing yet.\n")
	sb.WriteString("- If external info is needed, note it for the Crawl phase.\n\n")
	sb.WriteString("OUTPUT:\n")
	sb.WriteString("A clear list of knowledge gaps and a plan for the Crawl phase.")

	return exec(ctx, sb.String())
}

// Crawl (P2) extracts content from identified sources.
func (s *KnowledgeSchedule) Crawl(ctx context.Context, exec func(context.Context, string) error) error {
	var sb strings.Builder
	sb.WriteString("### PROCESS: CRAWL (Knowledge P2)\n")
	sb.WriteString("You are the crawler. Your mission is to EXTRACT CONTENT.\n\n")
	sb.WriteString("TASKS:\n")
	sb.WriteString("1. **Deep Read**: Use `read_file` on the sources identified in Research.\n")
	sb.WriteString("2. **Web Search**: If internal info is insufficient, use `web_search` and `web_fetch` for documentation or examples.\n")
	sb.WriteString("3. **Extract Details**: Capture exact signatures, types, constants, and logic flows.\n")
	sb.WriteString("4. **Verify Findings**: Cross-reference information between multiple files.\n\n")
	sb.WriteString("GUIDELINES:\n")
	sb.WriteString("- Be extremely thorough. Small details matter for implementation.\n")
	sb.WriteString("- Look for edge cases in existing code.\n")
	sb.WriteString("- Capture error handling patterns used in the codebase.\n\n")
	sb.WriteString("OUTPUT:\n")
	sb.WriteString("A collection of technical details and verified facts.")

	return exec(ctx, sb.String())
}

// Retrieve (P3) structures the information into a usable form for planning.
func (s *KnowledgeSchedule) Retrieve(ctx context.Context, exec func(context.Context, string) error) error {
	var sb strings.Builder
	sb.WriteString("### PROCESS: RETRIEVE (Knowledge P3)\n")
	sb.WriteString("You are the knowledge integrator. Your mission is to STRUCTURE INFO.\n\n")
	sb.WriteString("TASKS:\n")
	sb.WriteString("1. **Synthesize**: Combine all findings from Research and Crawl into a coherent whole.\n")
	sb.WriteString("2. **Structure Context**: Organize the info by category (Types, Logic, UI, DB, etc.).\n")
	sb.WriteString("3. **Identify Constraints**: Clearly list what we CANNOT or should not do based on current code.\n")
	sb.WriteString("4. **Emit Notes**: Use `core_note` to record key findings for the orchestrator.\n\n")
	sb.WriteString("GUIDELINES:\n")
	sb.WriteString("- The goal is to provide a 'ready-to-use' context for the Plan schedule.\n")
	sb.WriteString("- Highlight any contradictions found during the Crawl phase.\n")
	sb.WriteString("- Ensure dependencies between components are clearly mapped.\n\n")
	sb.WriteString("OUTPUT:\n")
	sb.WriteString("A structured knowledge base and a set of session notes.")

	return exec(ctx, sb.String())
}

// AddGap adds an identified gap to the schedule.
func (s *KnowledgeSchedule) AddGap(gap string) {
	s.Gaps = append(s.Gaps, gap)
}

// AddSource adds a source to the schedule.
func (s *KnowledgeSchedule) AddSource(source string) {
	s.Sources = append(s.Sources, source)
}

// AddFinding adds a finding to the schedule.
func (s *KnowledgeSchedule) AddFinding(finding string) {
	s.Findings = append(s.Findings, finding)
}

// GetSummary returns a summary of the knowledge gathered.
func (s *KnowledgeSchedule) GetSummary() string {
	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("Knowledge Gaps: %d\n", len(s.Gaps)))
	sb.WriteString(fmt.Sprintf("Sources Identified: %d\n", len(s.Sources)))
	sb.WriteString(fmt.Sprintf("Technical Findings: %d\n", len(s.Findings)))
	return sb.String()
}

// GetConsultationRequirement returns the consultation requirements for this schedule.
func (s *KnowledgeSchedule) GetConsultationRequirement(processID orchestrate.ProcessID) (bool, string) {
	// Knowledge schedule typically doesn't require mandatory human consultation.
	return false, ""
}

// GetModelRequirement returns the preferred model for a process.
func (s *KnowledgeSchedule) GetModelRequirement(processID orchestrate.ProcessID) orchestrate.ModelType {
	return orchestrate.ModelResearcher
}

// FinalizeSummary provides a concluding summary for the Knowledge schedule.
func (s *KnowledgeSchedule) FinalizeSummary(stats map[string]interface{}) string {
	return "Knowledge phase completed. Gaps identified, sources crawled, and context structured."
}
