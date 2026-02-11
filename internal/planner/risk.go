package planner

import (
	"path/filepath"
	"strings"

	"github.com/croberts/obot/internal/fixer"
)

// RiskLevel defines the categorized risk of a planned task.
type RiskLevel string

const (
	RiskSafe     RiskLevel = "safe"
	RiskModerate RiskLevel = "moderate"
	RiskHigh     RiskLevel = "high"
)

// RiskLabeler analyzes changes and labels them with a risk level.
// It provides rationale for the categorization to aid in orchestration decisions.
type RiskLabeler struct{}

// NewRiskLabeler creates a new RiskLabeler.
func NewRiskLabeler() *RiskLabeler {
	return &RiskLabeler{}
}

// Label analyzes a task and returns its risk level and rationale.
func (rl *RiskLabeler) Label(task Task) (RiskLevel, string) {
	msg := strings.ToLower(task.Message)
	file := strings.ToLower(task.File)
	ext := filepath.Ext(file)

	// High Risk Triggers
	if high, reason := rl.checkHighRisk(task, msg, file, ext); high {
		return RiskHigh, reason
	}

	// Moderate Risk Triggers
	if moderate, reason := rl.checkModerateRisk(task, msg, file, ext); moderate {
		return RiskModerate, reason
	}

	// Default to Safe
	return RiskSafe, "Low-impact change (documentation, tests, or localized logic)."
}

func (rl *RiskLabeler) checkHighRisk(task Task, msg, file, ext string) (bool, string) {
	// 1. Critical infrastructure and architectural keywords
	highRiskKeywords := []string{
		"auth", "security", "encrypt", "password", "database", "schema",
		"migration", "concurrency", "mutex", "locking", "infrastructure",
		"breaking change", "protocol", "distributed", "orchestrator",
		"executor", "kernel", "sandbox",
	}

	for _, kw := range highRiskKeywords {
		if strings.Contains(msg, kw) {
			return true, "Changes critical infrastructure or security logic (" + kw + ")."
		}
	}

	// 2. Critical system paths
	criticalPaths := []string{
		"internal/config",
		"internal/ollama",
		"internal/agent/executor.go",
		"internal/orchestrate",
		"internal/telemetry",
		"internal/process",
		"go.mod",
		"Package.swift",
	}

	for _, cp := range criticalPaths {
		if strings.Contains(file, cp) {
			return true, "Modifies a core system component (" + cp + ")."
		}
	}

	// 3. Fix types with high potential for side effects or structural change
	if task.FixType == fixer.FixRefactor || task.FixType == fixer.FixOptimize {
		return true, "Involves complex code modifications with high side-effect potential (" + string(task.FixType) + ")."
	}

	return false, ""
}

func (rl *RiskLabeler) checkModerateRisk(task Task, msg, file, ext string) (bool, string) {
	// 1. API and Interface keywords
	moderateRiskKeywords := []string{
		"api", "public", "interface", "struct", "export", "performance",
		"cache", "memory", "resource", "monitor", "webhook", "integration",
	}

	for _, kw := range moderateRiskKeywords {
		if strings.Contains(msg, kw) {
			return true, "Modifies public interfaces or performance-sensitive code (" + kw + ")."
		}
	}

	// 2. High-impact but non-critical file paths
	impactfulPaths := []string{
		"internal/cli",
		"internal/index",
		"internal/session",
		"internal/patch",
		"internal/summary",
		"internal/tools",
	}

	for _, ip := range impactfulPaths {
		if strings.Contains(file, ip) {
			return true, "Modifies high-impact user-facing or integration code (" + ip + ")."
		}
	}

	// 3. Logic changes in compiled files (not just docs/tests)
	if ext == ".go" || ext == ".swift" || ext == ".py" || ext == ".ts" {
		// Test files are safe — they don't affect production code
		if strings.HasSuffix(file, "_test.go") || strings.HasSuffix(file, "_test.py") || strings.HasSuffix(file, ".test.ts") || strings.HasSuffix(file, ".spec.ts") {
			return false, ""
		}
		if task.FixType != fixer.FixDoc && task.FixType != fixer.FixLint {
			return true, "Modifies functional logic in a non-core file."
		}
	}

	return false, ""
}
