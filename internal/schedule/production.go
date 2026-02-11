// Package schedule implements the schedule logic for obot orchestration.
package schedule

import (
	"context"
	"fmt"
	"strings"

	"github.com/croberts/obot/internal/orchestrate"
)

// ProductionSchedule implements the logic for the Production schedule.
// This is the final schedule in the orchestration flow, focused on 
// quality assurance, documentation, and production readiness.
//
// Processes: 
// 1. Analyze (code security, deps review): Security audit and dependency health check.
// 2. Systemize (patterns, docs, config): Align with architectural patterns and update docs.
// 3. Harmonize (integration tests, UI polish): Final verification and UI/UX polish.
type ProductionSchedule struct {
	Issues          []string
	ResolvedIssues  []string
	DocsGenerated   []string
	SecurityPassed  bool
}

// NewProductionSchedule creates a new Production schedule logic handler.
func NewProductionSchedule() *ProductionSchedule {
	return &ProductionSchedule{
		Issues:         make([]string, 0),
		ResolvedIssues: make([]string, 0),
		DocsGenerated:  make([]string, 0),
	}
}

// ExecuteProcess executes a process within the Production schedule.
func (s *ProductionSchedule) ExecuteProcess(ctx context.Context, processID orchestrate.ProcessID, exec func(context.Context, string) error) error {
	switch processID {
	case orchestrate.Process1:
		return s.Analyze(ctx, exec)
	case orchestrate.Process2:
		return s.Systemize(ctx, exec)
	case orchestrate.Process3:
		return s.Harmonize(ctx, exec)
	default:
		return fmt.Errorf("invalid process ID %d for Production schedule", processID)
	}
}

// Analyze (P1) reviews code security, dependency health, and overall code quality.
func (s *ProductionSchedule) Analyze(ctx context.Context, exec func(context.Context, string) error) error {
	var sb strings.Builder
	sb.WriteString("### PROCESS: ANALYZE (Production P1)\n")
	sb.WriteString("You are the security and quality auditor. Your mission is to IDENTIFY RISKS.\n\n")
	sb.WriteString("TASKS:\n")
	sb.WriteString("1. **Security Review**: Check for hardcoded secrets, insecure API usage, and potential injection points.\n")
	sb.WriteString("2. **Dependency Audit**: Review added dependencies. Are they necessary? Are they the latest stable versions?\n")
	sb.WriteString("3. **Code Quality**: Check for complexity, duplication, and adherence to the project's coding standards.\n")
	sb.WriteString("4. **Lint & Test**: Run available linters and tests to ensure no regressions were introduced.\n\n")
	sb.WriteString("GUIDELINES:\n")
	sb.WriteString("- Be critical. This is the last chance to find bugs before 'shipping'.\n")
	sb.WriteString("- Look for performance bottlenecks in the new code.\n")
	sb.WriteString("- Ensure error handling is robust and provides meaningful feedback.\n\n")
	sb.WriteString("OUTPUT:\n")
	sb.WriteString("A detailed risk report and a list of items requiring remediation.")

	return exec(ctx, sb.String())
}

// Systemize (P2) ensures patterns are consistent, documentation is updated, and configuration is correct.
func (s *ProductionSchedule) Systemize(ctx context.Context, exec func(context.Context, string) error) error {
	var sb strings.Builder
	sb.WriteString("### PROCESS: SYSTEMIZE (Production P2)\n")
	sb.WriteString("You are the systems architect. Your mission is to ENSURE CONSISTENCY.\n\n")
	sb.WriteString("TASKS:\n")
	sb.WriteString("1. **Pattern Alignment**: Ensure all new code follows the established architectural patterns (e.g., error handling, logging, concurrency).\n")
	sb.WriteString("2. **Documentation**: Update READMEs, API docs, and internal comments to reflect changes.\n")
	sb.WriteString("3. **Configuration**: Ensure any new config keys are added to defaults and properly documented.\n")
	sb.WriteString("4. **Refactor (Optional)**: If Analyze found minor inconsistencies, perform safe, non-functional refactors to align with system patterns.\n\n")
	sb.WriteString("GUIDELINES:\n")
	sb.WriteString("- Documentation must be accurate and easy to follow.\n")
	sb.WriteString("- Configuration should be intuitive and well-commented.\n")
	sb.WriteString("- Aim for a 'zero-delta' in architectural consistency.\n\n")
	sb.WriteString("OUTPUT:\n")
	sb.WriteString("Updated documentation, consistent code patterns, and verified configuration.")

	return exec(ctx, sb.String())
}

// Harmonize (P3) focuses on integration tests, UI polish, and final verification.
func (s *ProductionSchedule) Harmonize(ctx context.Context, exec func(context.Context, string) error) error {
	var sb strings.Builder
	sb.WriteString("### PROCESS: HARMONIZE (Production P3)\n")
	sb.WriteString("You are the final integrator. Your mission is to POLISH AND VERIFY.\n\n")
	sb.WriteString("TASKS:\n")
	sb.WriteString("1. **Integration Testing**: Run end-to-end scenarios to ensure all components work together seamlessly.\n")
	sb.WriteString("2. **UI Polish (if applicable)**: If the changes involve a UI, use the `vision` model to review visual consistency and accessibility.\n")
	sb.WriteString("3. **Performance Verification**: Ensure the system meets performance requirements under realistic loads.\n")
	sb.WriteString("4. **Final Check-off**: Verify that all goals of the initial prompt have been met and no regressions exist.\n\n")
	sb.WriteString("GUIDELINES:\n")
	sb.WriteString("- If `vision` model reports issues, address them immediately.\n")
	sb.WriteString("- Focus on the 'user experience' (CLI output, UI responsiveness, error messages).\n")
	sb.WriteString("- This is the final gate before the prompt is considered 'Terminated'.\n\n")
	sb.WriteString("OUTPUT:\n")
	sb.WriteString("A final verification report and a signal for prompt termination.")

	return exec(ctx, sb.String())
}

// AddIssue adds an issue found during Analyze.
func (s *ProductionSchedule) AddIssue(issue string) {
	s.Issues = append(s.Issues, issue)
}

// ResolveIssue marks an issue as resolved.
func (s *ProductionSchedule) ResolveIssue(issue string) {
	s.ResolvedIssues = append(s.ResolvedIssues, issue)
}

// RecordDoc records a documentation file that was updated.
func (s *ProductionSchedule) RecordDoc(doc string) {
	s.DocsGenerated = append(s.DocsGenerated, doc)
}

// SetSecurityPassed sets the security audit status.
func (s *ProductionSchedule) SetSecurityPassed(passed bool) {
	s.SecurityPassed = passed
}

// GetStatus returns a summary of the production readiness.
func (s *ProductionSchedule) GetStatus() string {
	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("Security Audit: %t\n", s.SecurityPassed))
	sb.WriteString(fmt.Sprintf("Issues Identified: %d\n", len(s.Issues)))
	sb.WriteString(fmt.Sprintf("Issues Resolved: %d\n", len(s.ResolvedIssues)))
	sb.WriteString(fmt.Sprintf("Docs Updated: %d\n", len(s.DocsGenerated)))
	return sb.String()
}

// GetConsultationRequirement returns the consultation requirements for this schedule.
func (s *ProductionSchedule) GetConsultationRequirement(processID orchestrate.ProcessID) (bool, string) {
	// Production schedule typically doesn't require mandatory human consultation.
	return false, ""
}

// GetModelRequirement returns the preferred model for a process.
func (s *ProductionSchedule) GetModelRequirement(processID orchestrate.ProcessID) orchestrate.ModelType {
	if processID == orchestrate.Process3 {
		return orchestrate.ModelVision // Harmonize uses vision
	}
	return orchestrate.ModelCoder
}

// FinalizeSummary provides a concluding summary for the Production schedule.
func (s *ProductionSchedule) FinalizeSummary(stats map[string]interface{}) string {
	return "Production phase completed. Code analyzed, systemized, and harmonized for quality."
}
