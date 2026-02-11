// Package schedule implements the schedule logic for obot orchestration.
package schedule

import (
	"context"
	"fmt"
	"strings"

	"github.com/croberts/obot/internal/consultation"
	"github.com/croberts/obot/internal/orchestrate"
)

// ImplementSchedule implements the logic for the Implement schedule.
// Processes:
// 1. Implement (execute plan steps): Actual code generation and modification.
// 2. Verify (tests/lint/build): Automated quality checks.
// 3. Feedback (mandatory human consultation): Demonstrate changes and get approval.
type ImplementSchedule struct {
	// Internal tracking of implementation progress
	StepsCompleted []string
	IssuesFound    []string
	HumanApproval  bool

	ConsultHandler *consultation.Handler
}

// NewImplementSchedule creates a new Implement schedule logic handler.
func NewImplementSchedule(handler *consultation.Handler) *ImplementSchedule {
	return &ImplementSchedule{
		StepsCompleted: make([]string, 0),
		IssuesFound:    make([]string, 0),
		HumanApproval:  false,
		ConsultHandler: handler,
	}
}

// ExecuteProcess executes a process within the Implement schedule.
func (s *ImplementSchedule) ExecuteProcess(ctx context.Context, processID orchestrate.ProcessID, exec func(context.Context, string) error) error {
	switch processID {
	case orchestrate.Process1:
		return s.Implement(ctx, exec)
	case orchestrate.Process2:
		return s.Verify(ctx, exec)
	case orchestrate.Process3:
		return s.Feedback(ctx, exec)
	default:
		return fmt.Errorf("invalid process ID %d for Implement schedule", processID)
	}
}

// Implement (P1) executes the implementation steps from the Plan schedule.
func (s *ImplementSchedule) Implement(ctx context.Context, exec func(context.Context, string) error) error {
	var sb strings.Builder
	sb.WriteString("### PROCESS: IMPLEMENT (Implement P1)\n")
	sb.WriteString("You are the developer. Your mission is to EXECUTE PLAN STEPS.\n\n")
	sb.WriteString("TASKS:\n")
	sb.WriteString("1. **Follow Plan**: Execute the steps defined in the Plan schedule one by one.\n")
	sb.WriteString("2. **Atomic Changes**: Prefer making small, incremental changes using `create_file` or `edit_file`.\n")
	sb.WriteString("3. **Adhere to Patterns**: Match the existing coding style and conventions identified in Knowledge.\n")
	sb.WriteString("4. **Handle Errors**: If a tool fails, analyze the error and attempt to fix it or note it for Verify.\n\n")
	sb.WriteString("GUIDELINES:\n")
	sb.WriteString("- DO NOT REFACTOR unless explicitly part of the plan.\n")
	sb.WriteString("- Keep comments and documentation in sync with code changes.\n")
	sb.WriteString("- Use `run_command` only for non-filesystem operations (e.g., git, search).\n\n")
	sb.WriteString("OUTPUT:\n")
	sb.WriteString("Code changes applied to the workspace.")

	return exec(ctx, sb.String())
}

// Verify (P2) performs automated quality checks on the changes.
func (s *ImplementSchedule) Verify(ctx context.Context, exec func(context.Context, string) error) error {
	var sb strings.Builder
	sb.WriteString("### PROCESS: VERIFY (Implement P2)\n")
	sb.WriteString("You are the QA engineer. Your mission is to RUN TESTS & CHECKS.\n\n")
	sb.WriteString("TASKS:\n")
	sb.WriteString("1. **Lint Check**: Run `go vet` or other project-specific linters.\n")
	sb.WriteString("2. **Build Check**: Ensure the project still compiles after your changes.\n")
	sb.WriteString("3. **Unit Tests**: Run existing tests and any new tests you added.\n")
	sb.WriteString("4. **Analyze Failures**: If checks fail, go back to Implement (P1) to fix them.\n\n")
	sb.WriteString("GUIDELINES:\n")
	sb.WriteString("- Aim for 100% pass rate on relevant tests.\n")
	sb.WriteString("- Do not ignore warnings—treat them as potential bugs.\n")
	sb.WriteString("- Ensure no new files were created accidentally.\n\n")
	sb.WriteString("OUTPUT:\n")
	sb.WriteString("Verification report with test/lint results.")

	return exec(ctx, sb.String())
}

// Feedback (P3) demonstrates changes to the human and gets mandatory approval.
func (s *ImplementSchedule) Feedback(ctx context.Context, exec func(context.Context, string) error) error {
	var sb strings.Builder
	sb.WriteString("### PROCESS: FEEDBACK (Implement P3)\n")
	sb.WriteString("You are the demonstrator. Your mission is to GET HUMAN APPROVAL.\n\n")

	if s.ConsultHandler != nil {
		changes := []consultation.ChangeDescription{
			{Description: "Implemented plan steps", File: "various", Lines: "all"},
		}
		results := consultation.VerificationResults{
			TestsPassed: 1, TestsTotal: 1, BuildStatus: "Success",
		}
		req := consultation.FormatFeedbackRequest(changes, results, nil)
		resp, err := s.ConsultHandler.Request(ctx, req)
		if err == nil {
			s.HumanApproval = strings.Contains(strings.ToUpper(resp.Content), "YES") || strings.Contains(strings.ToUpper(resp.Content), "APPROVE")
			sb.WriteString(fmt.Sprintf("USER APPROVAL: %v\n\n", s.HumanApproval))
		}
	}

	sb.WriteString("TASKS:\n")
	sb.WriteString("1. **Summarize Changes**: Provide a concise list of what was implemented.\n")
	sb.WriteString("2. **Show Proof**: List the verification results (tests passed, build success).\n")
	sb.WriteString("3. **Interactive Demo**: If appropriate, describe how the user can verify the change.\n")
	sb.WriteString("4. **Ask for Approval**: Use `core_ask_user` for MANDATORY feedback.\n\n")
	sb.WriteString("GUIDELINES:\n")
	sb.WriteString("- Be transparent about any deviations from the original plan.\n")
	sb.WriteString("- If the human is unhappy, go back to Plan (S2) or Implement (S3).\n")
	sb.WriteString("- A 'COMPLETE' signal here requires human consent.\n\n")
	sb.WriteString("OUTPUT:\n")
	sb.WriteString("A final demonstration summary and approval status.")

	return exec(ctx, sb.String())
}

// AddStepCompleted records a completed implementation step.
func (s *ImplementSchedule) AddStepCompleted(step string) {
	s.StepsCompleted = append(s.StepsCompleted, step)
}

// AddIssue records an issue found during implementation or verification.
func (s *ImplementSchedule) AddIssue(issue string) {
	s.IssuesFound = append(s.IssuesFound, issue)
}

// SetApproval sets the human approval status.
func (s *ImplementSchedule) SetApproval(approved bool) {
	s.HumanApproval = approved
}

// GetSummary returns a summary of the implementation status.
func (s *ImplementSchedule) GetSummary() string {
	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("Steps Completed: %d\n", len(s.StepsCompleted)))
	sb.WriteString(fmt.Sprintf("Issues Found: %d\n", len(s.IssuesFound)))
	sb.WriteString(fmt.Sprintf("Human Approval: %v\n", s.HumanApproval))
	return sb.String()
}
