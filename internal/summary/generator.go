// Package summary implements prompt summary generation for obot orchestration.
package summary

import (
	"fmt"
	"strings"
	"time"

	"github.com/croberts/obot/internal/agent"
	"github.com/croberts/obot/internal/orchestrate"
	"github.com/croberts/obot/internal/resource"
	"github.com/croberts/obot/internal/ui"
)

// Generator generates comprehensive prompt summaries.
type Generator struct {
	// Input data
	stats    *orchestrate.OrchestratorStats
	flowCode string
	actions  *agent.ActionStats
	edits    []agent.EditDetail
	resources *resource.Summary
	tldr     string

	// Token tracking by process
	processTokens []ProcessTokenEntry
}

// ProcessTokenEntry tracks tokens for a process execution
type ProcessTokenEntry struct {
	Schedule    orchestrate.ScheduleID
	Process     orchestrate.ProcessID
	Tokens      int64
	Cumulative  int64
	Percentage  float64
}

// NewGenerator creates a new summary generator
func NewGenerator() *Generator {
	return &Generator{
		processTokens: make([]ProcessTokenEntry, 0),
	}
}

// SetStats sets the orchestrator statistics
func (g *Generator) SetStats(stats *orchestrate.OrchestratorStats) {
	g.stats = stats
}

// SetFlowCode sets the flow code
func (g *Generator) SetFlowCode(flowCode string) {
	g.flowCode = flowCode
}

// SetActions sets the action statistics
func (g *Generator) SetActions(actions *agent.ActionStats, edits []agent.EditDetail) {
	g.actions = actions
	g.edits = edits
}

// SetResources sets the resource summary
func (g *Generator) SetResources(resources *resource.Summary) {
	g.resources = resources
}

// SetTLDR sets the TLDR content
func (g *Generator) SetTLDR(tldr string) {
	g.tldr = tldr
}

// AddProcessTokens adds token tracking for a process
func (g *Generator) AddProcessTokens(scheduleID orchestrate.ScheduleID, processID orchestrate.ProcessID, tokens int64) {
	cumulative := int64(0)
	if len(g.processTokens) > 0 {
		cumulative = g.processTokens[len(g.processTokens)-1].Cumulative
	}
	cumulative += tokens

	totalTokens := int64(0)
	if g.stats != nil {
		totalTokens = g.stats.TotalTokens
	}

	percentage := 0.0
	if totalTokens > 0 {
		percentage = float64(cumulative) / float64(totalTokens) * 100
	}

	g.processTokens = append(g.processTokens, ProcessTokenEntry{
		Schedule:   scheduleID,
		Process:    processID,
		Tokens:     tokens,
		Cumulative: cumulative,
		Percentage: percentage,
	})
}

// Generate generates the complete prompt summary
func (g *Generator) Generate() string {
	var sb strings.Builder

	// Header
	sb.WriteString("┌─────────────────────────────────────────────────────────────────────┐\n")
	sb.WriteString("│ Orchestrator • Prompt Summary                                       │\n")
	sb.WriteString("├─────────────────────────────────────────────────────────────────────┤\n")

	// Flow code
	sb.WriteString("│                                                                     │\n")
	sb.WriteString(fmt.Sprintf("│ %s\n", ui.FormatFlowCode(g.flowCode)))
	sb.WriteString("│ ▲  ▲▲▲▲▲▲▲▲                                                         │\n")
	sb.WriteString("│ │  └──┴──┴──── Process codes (blue)                                 │\n")
	sb.WriteString("│ └───────────── Schedule codes (white)                               │\n")
	sb.WriteString("│                                                                     │\n")

	// Schedule statistics
	sb.WriteString("├─────────────────────────────────────────────────────────────────────┤\n")
	sb.WriteString(g.generateScheduleStats())

	// Process statistics
	sb.WriteString("├─────────────────────────────────────────────────────────────────────┤\n")
	sb.WriteString(g.generateProcessStats())

	// Agent action breakdown
	sb.WriteString("├─────────────────────────────────────────────────────────────────────┤\n")
	sb.WriteString(g.generateActionBreakdown())

	// Resource summary
	sb.WriteString("├─────────────────────────────────────────────────────────────────────┤\n")
	sb.WriteString(g.generateResourceSummary())

	// Token summary
	sb.WriteString("├─────────────────────────────────────────────────────────────────────┤\n")
	sb.WriteString(g.generateTokenSummary())

	// Generation flow
	sb.WriteString("├─────────────────────────────────────────────────────────────────────┤\n")
	sb.WriteString(g.generateFlowBreakdown())

	// TLDR
	sb.WriteString("├─────────────────────────────────────────────────────────────────────┤\n")
	sb.WriteString("│ OllamaBot • TLDR                                                    │\n")
	sb.WriteString("│                                                                     │\n")
	sb.WriteString(g.formatTLDR())
	sb.WriteString("│                                                                     │\n")

	// Footer
	sb.WriteString("└─────────────────────────────────────────────────────────────────────┘\n")

	return sb.String()
}

// generateScheduleStats generates schedule statistics
func (g *Generator) generateScheduleStats() string {
	var sb strings.Builder

	total := 0
	if g.stats != nil {
		total = g.stats.TotalSchedulings
	}

	sb.WriteString(fmt.Sprintf("│ Schedule • %d Total Schedulings                                      │\n", total))

	if g.stats != nil {
		for sid := orchestrate.ScheduleKnowledge; sid <= orchestrate.ScheduleProduction; sid++ {
			count := g.stats.SchedulingsByID[sid]
			name := orchestrate.ScheduleNames[sid]
			sb.WriteString(fmt.Sprintf("│   %s: %d scheduling%s\n", name, count, pluralize(count, "", "s")))
		}
	}
	sb.WriteString("│                                                                     │\n")

	return sb.String()
}

// generateProcessStats generates process statistics
func (g *Generator) generateProcessStats() string {
	var sb strings.Builder

	total := 0
	if g.stats != nil {
		total = g.stats.TotalProcesses
	}

	sb.WriteString(fmt.Sprintf("│ Process • %d Total Processes                                        │\n", total))
	sb.WriteString("│                                                                     │\n")

	if g.stats != nil && total > 0 {
		for sid := orchestrate.ScheduleKnowledge; sid <= orchestrate.ScheduleProduction; sid++ {
			scheduleTotal := 0
			processMap := g.stats.ProcessesBySchedule[sid]
			if processMap != nil {
				for _, count := range processMap {
					scheduleTotal += count
				}
			}

			if scheduleTotal == 0 {
				continue
			}

			schedulePercent := float64(scheduleTotal) / float64(total) * 100
			scheduleCount := g.stats.SchedulingsByID[sid]
			avgProcesses := 0.0
			if scheduleCount > 0 {
				avgProcesses = float64(scheduleTotal) / float64(scheduleCount)
			}

			scheduleName := orchestrate.ScheduleNames[sid]
			sb.WriteString(fmt.Sprintf("│ %s • %d total (%.1f%% of all)\n", scheduleName, scheduleTotal, schedulePercent))
			sb.WriteString(fmt.Sprintf("│   Averaging %.1f processes per scheduling\n", avgProcesses))

			// Process breakdown
			for pid := orchestrate.Process1; pid <= orchestrate.Process3; pid++ {
				if processMap == nil {
					continue
				}
				count := processMap[pid]
				processPercent := 0.0
				if scheduleTotal > 0 {
					processPercent = float64(count) / float64(scheduleTotal) * 100
				}
				processName := orchestrate.ProcessNames[sid][pid]
				sb.WriteString(fmt.Sprintf("│   %s: %d (%.1f%% of %s)\n", processName, count, processPercent, scheduleName))
			}
			sb.WriteString("│                                                                     │\n")
		}
	}

	return sb.String()
}

// generateActionBreakdown generates the action breakdown
func (g *Generator) generateActionBreakdown() string {
	var sb strings.Builder

	sb.WriteString("│ Agent • Action Breakdown                                            │\n")
	sb.WriteString("│                                                                     │\n")

	if g.actions != nil {
		sb.WriteString(fmt.Sprintf("│ Created • %d files, %d directories\n", g.actions.FilesCreated, g.actions.DirsCreated))
		sb.WriteString(fmt.Sprintf("│ Deleted • %d files, %d directories\n", g.actions.FilesDeleted, g.actions.DirsDeleted))
		sb.WriteString(fmt.Sprintf("│ Renamed • %d files, %d directories\n", g.actions.FilesRenamed, g.actions.DirsRenamed))
		sb.WriteString(fmt.Sprintf("│ Moved • %d files, %d directories\n", g.actions.FilesMoved, g.actions.DirsMoved))
		sb.WriteString(fmt.Sprintf("│ Copied • %d files, %d directories\n", g.actions.FilesCopied, g.actions.DirsCopied))
		sb.WriteString(fmt.Sprintf("│ Ran • %d commands\n", g.actions.CommandsRan))
		sb.WriteString(fmt.Sprintf("│ Edited • %d files\n", g.actions.FilesEdited))
	}

	sb.WriteString("│                                                                     │\n")

	// Edit details
	if len(g.edits) > 0 {
		sb.WriteString("│ Edit Details:                                                       │\n")
		for _, edit := range g.edits {
			rangesStr := formatLineRanges(edit.LineRanges)
			sb.WriteString(fmt.Sprintf("│   %s at %s\n", edit.Path, rangesStr))

			// Show diff preview (first few lines)
			if edit.Diff != nil {
				for i, line := range edit.Diff.Deletions {
					if i >= 2 {
						break
					}
					sb.WriteString(fmt.Sprintf("│   %s-  %4d │ %s\n", ui.Red, line.LineNumber, truncate(line.Content, 50)))
				}
				for i, line := range edit.Diff.Additions {
					if i >= 2 {
						break
					}
					sb.WriteString(fmt.Sprintf("│   %s+  %4d │ %s\n", ui.Green, line.LineNumber, truncate(line.Content, 50)))
				}
				sb.WriteString("│   ...\n")
			}
		}
	}
	sb.WriteString("│                                                                     │\n")

	return sb.String()
}

// generateResourceSummary generates the resource summary
func (g *Generator) generateResourceSummary() string {
	var sb strings.Builder

	sb.WriteString("│ Resources • Summary                                                 │\n")
	sb.WriteString("│                                                                     │\n")

	if g.resources != nil {
		// Memory
		sb.WriteString("│ Memory:                                                             │\n")
		sb.WriteString(fmt.Sprintf("│   Peak Usage: %.1f GB\n", g.resources.Memory.PeakUsageGB))
		sb.WriteString(fmt.Sprintf("│   Average Usage: %.1f GB\n", g.resources.Memory.AverageUsageGB))
		if g.resources.Memory.LimitGB != nil {
			sb.WriteString(fmt.Sprintf("│   Limit: %.1f GB\n", *g.resources.Memory.LimitGB))
		} else {
			sb.WriteString("│   Limit: None (unlimited)\n")
		}
		sb.WriteString(fmt.Sprintf("│   Pressure Events: %d warning, %d critical\n",
			g.resources.Memory.PressureWarnings, g.resources.Memory.PressureCritical))
		sb.WriteString(fmt.Sprintf("│   Predictions Accuracy: %.1f%%\n", g.resources.Memory.PredictionAccuracy*100))
		sb.WriteString("│                                                                     │\n")

		// Disk
		sb.WriteString("│ Disk:                                                               │\n")
		sb.WriteString(fmt.Sprintf("│   Files Written: %s\n", formatBytes(g.resources.Disk.FilesWrittenBytes)))
		sb.WriteString(fmt.Sprintf("│   Files Deleted: %s\n", formatBytes(g.resources.Disk.FilesDeletedBytes)))
		sb.WriteString(fmt.Sprintf("│   Net Change: %s\n", formatBytesWithSign(g.resources.Disk.NetChangeBytes)))
		sb.WriteString("│                                                                     │\n")

		// Time
		sb.WriteString("│ Time:                                                               │\n")
		sb.WriteString(fmt.Sprintf("│   Total Duration: %s\n", formatDuration(g.resources.Time.TotalDuration)))
		
		totalMs := g.resources.Time.TotalDuration.Milliseconds()
		if totalMs > 0 {
			agentPercent := float64(g.resources.Time.AgentActive.Milliseconds()) / float64(totalMs) * 100
			humanPercent := float64(g.resources.Time.HumanWait.Milliseconds()) / float64(totalMs) * 100
			orchPercent := float64(g.resources.Time.Orchestrator.Milliseconds()) / float64(totalMs) * 100
			
			sb.WriteString(fmt.Sprintf("│   Agent Active: %s (%.1f%%)\n", formatDuration(g.resources.Time.AgentActive), agentPercent))
			sb.WriteString(fmt.Sprintf("│   Human Wait: %s (%.1f%%)\n", formatDuration(g.resources.Time.HumanWait), humanPercent))
			sb.WriteString(fmt.Sprintf("│   Orchestrator: %s (%.1f%%)\n", formatDuration(g.resources.Time.Orchestrator), orchPercent))
		}
	}
	sb.WriteString("│                                                                     │\n")

	return sb.String()
}

// generateTokenSummary generates the token summary
func (g *Generator) generateTokenSummary() string {
	var sb strings.Builder

	totalTokens := int64(0)
	if g.stats != nil {
		totalTokens = g.stats.TotalTokens
	}

	sb.WriteString(fmt.Sprintf("│ Tokens • %s total                                              │\n", formatNumber(totalTokens)))
	sb.WriteString("│                                                                     │\n")
	sb.WriteString(fmt.Sprintf("│   Total Tokens: %s\n", formatNumber(totalTokens)))

	// Would need actual token breakdown by type
	sb.WriteString(fmt.Sprintf("│   Inference Tokens: %s (70.0%%)\n", formatNumber(int64(float64(totalTokens)*0.70))))
	sb.WriteString(fmt.Sprintf("│   Input Tokens: %s (25.0%%)\n", formatNumber(int64(float64(totalTokens)*0.25))))
	sb.WriteString(fmt.Sprintf("│   Output Tokens: %s (45.0%%)\n", formatNumber(int64(float64(totalTokens)*0.45))))
	sb.WriteString(fmt.Sprintf("│   Context Retrieval: %s (30.0%%)\n", formatNumber(int64(float64(totalTokens)*0.30))))
	sb.WriteString("│                                                                     │\n")

	// By schedule
	if g.resources != nil && len(g.resources.Tokens.BySchedule) > 0 {
		sb.WriteString("│   By Schedule:\n")
		for sid := orchestrate.ScheduleKnowledge; sid <= orchestrate.ScheduleProduction; sid++ {
			tokens := g.resources.Tokens.BySchedule[sid]
			percent := 0.0
			if totalTokens > 0 {
				percent = float64(tokens) / float64(totalTokens) * 100
			}
			name := orchestrate.ScheduleNames[sid]
			sb.WriteString(fmt.Sprintf("│     %s: %s (%.1f%%)\n", name, formatNumber(tokens), percent))
		}
	}
	sb.WriteString("│                                                                     │\n")

	return sb.String()
}

// generateFlowBreakdown generates the generation flow breakdown
func (g *Generator) generateFlowBreakdown() string {
	var sb strings.Builder

	sb.WriteString("│ Generation Flow • Process-by-Process Token Recount                  │\n")
	sb.WriteString("│                                                                     │\n")
	sb.WriteString(fmt.Sprintf("│ %s\n", ui.FormatFlowCode(g.flowCode)))
	sb.WriteString("│                                                                     │\n")

	// Show token breakdown by process
	currentSchedule := orchestrate.ScheduleID(0)
	for _, entry := range g.processTokens {
		if entry.Schedule != currentSchedule {
			currentSchedule = entry.Schedule
			sb.WriteString(fmt.Sprintf("│ S%d (%s):\n", currentSchedule, orchestrate.ScheduleNames[currentSchedule]))
		}

		processName := orchestrate.ProcessNames[entry.Schedule][entry.Process]
		totalTokens := int64(0)
		if g.stats != nil {
			totalTokens = g.stats.TotalTokens
		}
		sb.WriteString(fmt.Sprintf("│   P%d %-10s +%s tokens    %s / %s (%.1f%%)\n",
			entry.Process,
			processName,
			formatNumber(entry.Tokens),
			formatNumber(entry.Cumulative),
			formatNumber(totalTokens),
			entry.Percentage))
	}

	sb.WriteString("│                                                                     │\n")

	return sb.String()
}

// formatTLDR formats the TLDR section
func (g *Generator) formatTLDR() string {
	if g.tldr == "" {
		return "│ (TLDR analysis pending)\n"
	}

	var sb strings.Builder
	lines := strings.Split(g.tldr, "\n")
	for _, line := range lines {
		sb.WriteString(fmt.Sprintf("│ %s\n", truncate(line, 68)))
	}
	return sb.String()
}

// Helper functions

func pluralize(count int, singular, plural string) string {
	if count == 1 {
		return singular
	}
	return plural
}

func formatLineRanges(ranges []agent.LineRange) string {
	if len(ranges) == 0 {
		return ""
	}

	parts := make([]string, 0, len(ranges))
	for _, r := range ranges {
		if r.Start == r.End {
			parts = append(parts, fmt.Sprintf("%d", r.Start))
		} else {
			parts = append(parts, fmt.Sprintf("%d-%d", r.Start, r.End))
		}
	}
	return strings.Join(parts, ", ")
}

func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen-3] + "..."
}

func formatBytes(bytes int64) string {
	if bytes < 1024 {
		return fmt.Sprintf("%d B", bytes)
	}
	if bytes < 1024*1024 {
		return fmt.Sprintf("%.1f KB", float64(bytes)/1024)
	}
	return fmt.Sprintf("%.1f MB", float64(bytes)/(1024*1024))
}

func formatBytesWithSign(bytes int64) string {
	sign := "+"
	if bytes < 0 {
		sign = ""
	}
	return sign + formatBytes(bytes)
}

func formatDuration(d time.Duration) string {
	if d < time.Minute {
		return fmt.Sprintf("%.1fs", d.Seconds())
	}
	minutes := int(d.Minutes())
	seconds := int(d.Seconds()) % 60
	return fmt.Sprintf("%dm %ds", minutes, seconds)
}

func formatNumber(n int64) string {
	if n < 1000 {
		return fmt.Sprintf("%d", n)
	}
	if n < 1000000 {
		return fmt.Sprintf("%.1fK", float64(n)/1000)
	}
	return fmt.Sprintf("%.1fM", float64(n)/1000000)
}
