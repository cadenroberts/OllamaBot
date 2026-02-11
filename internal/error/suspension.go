// Package errs implements suspension handling for orchestration errors.
package errs

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"strings"

	"github.com/croberts/obot/internal/ollama"
	"github.com/croberts/obot/internal/ui"
)

// SuspensionAction represents the user's choice after a suspension.
type SuspensionAction string

const (
	ActionRetry       SuspensionAction = "R"
	ActionSkip        SuspensionAction = "S"
	ActionAbort       SuspensionAction = "A"
	ActionInvestigate SuspensionAction = "I"
)

// SessionInterface defines the required methods from the session manager.
type SessionInterface interface {
	GetFlowCode() string
}

// ErrorAnalysis contains the LLM-generated analysis of an error.
type ErrorAnalysis struct {
	WhatHappened      string
	WhichComponent    string
	RuleViolated      string
	RootCause         string
	Factors           []string
	ProposedSolutions []string
}

// SuspensionHandler manages system suspension when a critical error occurs.
type SuspensionHandler struct {
	writer  io.Writer
	reader  io.Reader
	aiModel *ollama.Client
	session SessionInterface
}

// NewSuspensionHandler creates a new suspension handler.
func NewSuspensionHandler(w io.Writer, r io.Reader, model *ollama.Client, session SessionInterface) *SuspensionHandler {
	return &SuspensionHandler{
		writer:  w,
		reader:  r,
		aiModel: model,
		session: session,
	}
}

// Handle processes an orchestration error, displaying UI and waiting for user action.
func (h *SuspensionHandler) Handle(err *OrchestrationError) SuspensionAction {
	h.displaySuspension(err)

	analysis := h.analyzeError(err)
	h.displayAnalysis(analysis)

	h.displaySolutions(analysis.ProposedSolutions)

	return h.waitForAction()
}

// displaySuspension renders the primary suspension box UI.
func (h *SuspensionHandler) displaySuspension(err *OrchestrationError) {
	var sb strings.Builder
	sb.WriteString("\n")
	sb.WriteString("┌─────────────────────────────────────────────────────────────────────┐\n")
	sb.WriteString("│ Orchestrator • SUSPENDED                                            │\n")
	sb.WriteString("├─────────────────────────────────────────────────────────────────────┤\n")
	sb.WriteString(fmt.Sprintf("│ ERROR CODE: %-55s │\n", err.Code))
	sb.WriteString(fmt.Sprintf("│ MESSAGE:    %-55s │\n", h.truncate(err.Message, 55)))
	sb.WriteString("│                                                                     │\n")
	sb.WriteString("│ FROZEN STATE:                                                       │\n")
	sb.WriteString(fmt.Sprintf("│   Schedule:   %-53s │\n", err.State.Schedule))
	sb.WriteString(fmt.Sprintf("│   Process:    %-53s │\n", err.State.Process))
	sb.WriteString(fmt.Sprintf("│   LastAction: %-53s │\n", err.State.LastAction))
	sb.WriteString(fmt.Sprintf("│   Flow Code:  %-53s │\n", h.formatFlowCodeWithError(err.State.FlowCode)))
	sb.WriteString("└─────────────────────────────────────────────────────────────────────┘\n")

	fmt.Fprint(h.writer, sb.String())
}

// analyzeError performs an LLM-based analysis or returns hardcoded analysis.
func (h *SuspensionHandler) analyzeError(err *OrchestrationError) ErrorAnalysis {
	if IsHardcoded(err.Code) {
		return ErrorAnalysis{
			WhatHappened:      GetHardcodedMessage(err.Code),
			WhichComponent:    err.Component,
			RuleViolated:      err.Rule,
			ProposedSolutions: err.Solutions,
		}
	}

	if h.aiModel == nil {
		return ErrorAnalysis{
			WhatHappened:      err.Message,
			WhichComponent:    err.Component,
			RuleViolated:      err.Rule,
			RootCause:         "An unexpected state transition or component failure occurred.",
			Factors:           []string{"Component misconfiguration", "Environmental factors"},
			ProposedSolutions: err.Solutions,
		}
	}

	prompt := fmt.Sprintf(`Analyze the following orchestration error and provide a structured analysis.
Error Code: %s
Message: %s
Component: %s
Rule: %s
State: Schedule=%s, Process=%s, LastAction=%s, FlowCode=%s

Format your response exactly as follows:
WHAT_HAPPENED: <description>
ROOT_CAUSE: <description>
FACTORS:
- <factor 1>
- <factor 2>
PROPOSED_SOLUTIONS:
- <solution 1>
- <solution 2>
`, err.Code, err.Message, err.Component, err.Rule, err.State.Schedule, err.State.Process, err.State.LastAction, err.State.FlowCode)

	response, _, llmErr := h.aiModel.Generate(context.Background(), prompt)
	if llmErr != nil {
		return ErrorAnalysis{
			WhatHappened:      err.Message,
			WhichComponent:    err.Component,
			RuleViolated:      err.Rule,
			RootCause:         fmt.Sprintf("LLM analysis failed: %v", llmErr),
			ProposedSolutions: err.Solutions,
		}
	}

	return h.parseAnalysis(response, err)
}

// parseAnalysis parses the LLM response into an ErrorAnalysis struct.
func (h *SuspensionHandler) parseAnalysis(response string, err *OrchestrationError) ErrorAnalysis {
	analysis := ErrorAnalysis{
		WhichComponent: err.Component,
		RuleViolated:   err.Rule,
	}

	lines := strings.Split(response, "\n")
	currentSection := ""

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		if strings.HasPrefix(line, "WHAT_HAPPENED:") {
			analysis.WhatHappened = strings.TrimSpace(strings.TrimPrefix(line, "WHAT_HAPPENED:"))
			currentSection = ""
		} else if strings.HasPrefix(line, "ROOT_CAUSE:") {
			analysis.RootCause = strings.TrimSpace(strings.TrimPrefix(line, "ROOT_CAUSE:"))
			currentSection = ""
		} else if strings.HasPrefix(line, "FACTORS:") {
			currentSection = "factors"
		} else if strings.HasPrefix(line, "PROPOSED_SOLUTIONS:") {
			currentSection = "solutions"
		} else if strings.HasPrefix(line, "-") {
			item := strings.TrimSpace(strings.TrimPrefix(line, "-"))
			if currentSection == "factors" {
				analysis.Factors = append(analysis.Factors, item)
			} else if currentSection == "solutions" {
				analysis.ProposedSolutions = append(analysis.ProposedSolutions, item)
			}
		}
	}

	// Fallbacks if parsing failed
	if analysis.WhatHappened == "" {
		analysis.WhatHappened = err.Message
	}
	if len(analysis.ProposedSolutions) == 0 {
		analysis.ProposedSolutions = err.Solutions
	}

	return analysis
}

// displayAnalysis renders the error analysis box.
func (h *SuspensionHandler) displayAnalysis(analysis ErrorAnalysis) {
	var sb strings.Builder
	sb.WriteString("\n")
	sb.WriteString("┌─ ERROR ANALYSIS ────────────────────────────────────────────────────┐\n")

	sb.WriteString("│ WHAT HAPPENED:                                                      │\n")
	h.wrapAndPrint(&sb, analysis.WhatHappened, 67)
	sb.WriteString("│                                                                     │\n")

	if analysis.RootCause != "" {
		sb.WriteString("│ ROOT CAUSE:                                                         │\n")
		h.wrapAndPrint(&sb, analysis.RootCause, 67)
		sb.WriteString("│                                                                     │\n")
	}

	if len(analysis.Factors) > 0 {
		sb.WriteString("│ CONTRIBUTING FACTORS:                                               │\n")
		for _, factor := range analysis.Factors {
			h.wrapAndPrint(&sb, "• "+factor, 67)
		}
		sb.WriteString("│                                                                     │\n")
	}

	sb.WriteString(fmt.Sprintf("│ VIOLATED COMPONENT: %-47s │\n", analysis.WhichComponent))
	sb.WriteString(fmt.Sprintf("│ RULE VIOLATED:      %-47s │\n", analysis.RuleViolated))
	sb.WriteString("└─────────────────────────────────────────────────────────────────────┘\n")

	fmt.Fprint(h.writer, sb.String())
}

// displaySolutions renders the solutions and action options.
func (h *SuspensionHandler) displaySolutions(solutions []string) {
	var sb strings.Builder
	sb.WriteString("\nPROPOSED SOLUTIONS:\n")
	for i, sol := range solutions {
		sb.WriteString(fmt.Sprintf("  %d. %s\n", i+1, sol))
	}

	sb.WriteString("\nCONTINUATION OPTIONS:\n")
	sb.WriteString("  [R]etry      Attempt to re-execute the failed process\n")
	sb.WriteString("  [S]kip       Advance to the next valid process state\n")
	sb.WriteString("  [A]bort      Terminate the current session\n")
	sb.WriteString("  [I]nvestigate Start an interactive shell at this state\n")
	sb.WriteString("\nSelect action: ")

	fmt.Fprint(h.writer, sb.String())
}

// waitForAction reads a single character from stdin to determine the user's choice.
func (h *SuspensionHandler) waitForAction() SuspensionAction {
	scanner := bufio.NewScanner(h.reader)
	for scanner.Scan() {
		input := strings.ToUpper(strings.TrimSpace(scanner.Text()))
		switch input {
		case "R":
			return ActionRetry
		case "S":
			return ActionSkip
		case "A":
			return ActionAbort
		case "I":
			return ActionInvestigate
		}
		fmt.Fprint(h.writer, "Invalid option. Please select [R/S/A/I]: ")
	}
	return ActionAbort // Default to abort on error
}

// formatFlowCodeWithError appends a red X marker to the flow code and applies colors.
func (h *SuspensionHandler) formatFlowCodeWithError(flowCode string) string {
	return ui.FormatFlowCode(flowCode + "X")
}

// wrapAndPrint word-wraps text to fit a specific width within the box UI.
func (h *SuspensionHandler) wrapAndPrint(sb *strings.Builder, text string, width int) {
	words := strings.Fields(text)
	line := "│ "
	for _, word := range words {
		if len(line)+len(word)+1 > width+2 {
			sb.WriteString(line + strings.Repeat(" ", width+3-len(line)) + "│\n")
			line = "│ "
		}
		line += word + " "
	}
	if len(line) > 2 {
		sb.WriteString(line + strings.Repeat(" ", width+3-len(line)) + "│\n")
	}
}

// truncate shortens a string to a maximum length with ellipsis.
func (h *SuspensionHandler) truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen-3] + "..."
}
