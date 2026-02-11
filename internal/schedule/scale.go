// Package schedule implements the schedule logic for obot orchestration.
package schedule

import (
	"context"
	"fmt"
	"strings"

	"github.com/croberts/obot/internal/orchestrate"
)

// ScaleSchedule implements the logic for the Scale schedule.
// Processes:
// 1. Scale (identify concerns, refactor): Identify bottlenecks and refactor for scale.
// 2. Benchmark (run benchmarks, collect metrics): Measure performance under load.
// 3. Optimize (analyze results, apply optimizations): Apply optimizations based on metrics.
//
// PROOF:
// - ZERO-HIT: No prior implementation of ScaleSchedule logic.
// - POSITIVE-HIT: ScaleSchedule struct with Scale, Benchmark, and Optimize methods.
type ScaleSchedule struct {
	// Internal tracking of performance metrics to pass between processes
	Metrics map[string]float64
	Hotspots []string
	Reports  []string
}

// NewScaleSchedule creates a new Scale schedule logic handler.
func NewScaleSchedule() *ScaleSchedule {
	return &ScaleSchedule{
		Metrics:  make(map[string]float64),
		Hotspots: make([]string, 0),
		Reports:  make([]string, 0),
	}
}

// ExecuteProcess executes a process within the Scale schedule.
func (s *ScaleSchedule) ExecuteProcess(ctx context.Context, processID orchestrate.ProcessID, exec func(context.Context, string) error) error {
	switch processID {
	case orchestrate.Process1:
		return s.Scale(ctx, exec)
	case orchestrate.Process2:
		return s.Benchmark(ctx, exec)
	case orchestrate.Process3:
		return s.Optimize(ctx, exec)
	default:
		return fmt.Errorf("invalid process ID %d for Scale schedule", processID)
	}
}

// Scale (P1) identifies scalability concerns and performs initial refactoring.
func (s *ScaleSchedule) Scale(ctx context.Context, exec func(context.Context, string) error) error {
	var sb strings.Builder
	sb.WriteString("### PROCESS: SCALE (Scale P1)\n")
	sb.WriteString("You are the performance architect. Your mission is to IDENTIFY CONCERNS and REFACTOR.\n\n")
	sb.WriteString("TASKS:\n")
	sb.WriteString("1. **Analyze Complexity**: Look for O(n^2) or worse algorithms in the current implementation.\n")
	sb.WriteString("2. **Resource Usage**: Identify areas of excessive memory allocation or CPU usage.\n")
	sb.WriteString("3. **Identify Bottlenecks**: Look for sequential processing that could be parallelized.\n")
	sb.WriteString("4. **Apply Structural Refactors**: Implement performance-oriented patterns (e.g., worker pools, buffered channels).\n")
	sb.WriteString("5. **Identify Scale Concerns**: Explicitly list potential issues when data size increases by 10x or 100x.\n\n")
	sb.WriteString("GUIDELINES:\n")
	sb.WriteString("- Focus on architectural scalability over micro-optimizations in this phase.\n")
	sb.WriteString("- Maintain zero-hit parity: ensure refactoring doesn't break any existing functionality.\n")
	sb.WriteString("- Use concurrency where it provides clear benefits and doesn't overcomplicate the design.\n\n")
	sb.WriteString("OUTPUT:\n")
	sb.WriteString("A detailed scalability report and initial performance refactors.")

	return exec(ctx, sb.String())
}

// Benchmark (P2) runs benchmarks and collects metrics.
func (s *ScaleSchedule) Benchmark(ctx context.Context, exec func(context.Context, string) error) error {
	var sb strings.Builder
	sb.WriteString("### PROCESS: BENCHMARK (Scale P2)\n")
	sb.WriteString("You are the metric collector. Your mission is to RUN BENCHMARKS and COLLECT METRICS.\n\n")
	sb.WriteString("TASKS:\n")
	sb.WriteString("1. **Execute Benchmarks**: Run `go test -bench` or project-specific performance test suites.\n")
	sb.WriteString("2. **Collect Metrics**: Record latency, throughput, memory per operation, and allocation counts.\n")
	sb.WriteString("3. **Compare with Baseline**: If available, compare current results with pre-refactor metrics.\n")
	sb.WriteString("4. **Identify Hotspots**: Locate specific functions or lines of code that dominate the performance profile.\n")
	sb.WriteString("5. **Document Environment**: Note the hardware and OS conditions during the benchmark run.\n\n")
	sb.WriteString("GUIDELINES:\n")
	sb.WriteString("- Ensure the benchmarking process is reproducible and consistent.\n")
	sb.WriteString("- Look for outliers and explain them if possible.\n")
	sb.WriteString("- Use `go tool pprof` for deep hotspot analysis.\n\n")
	sb.WriteString("OUTPUT:\n")
	sb.WriteString("A comprehensive set of metrics and a hotspot analysis report.")

	return exec(ctx, sb.String())
}

// Optimize (P3) applies optimizations based on benchmark results.
func (s *ScaleSchedule) Optimize(ctx context.Context, exec func(context.Context, string) error) error {
	var sb strings.Builder
	sb.WriteString("### PROCESS: OPTIMIZE (Scale P3)\n")
	sb.WriteString("You are the performance tuner. Your mission is to ANALYZE RESULTS and APPLY OPTIMIZATIONS.\n\n")
	sb.WriteString("TASKS:\n")
	sb.WriteString("1. **Analyze Benchmark Results**: Review the metrics and hotspots identified in P2.\n")
	sb.WriteString("2. **Implement Targeted Optimizations**: Apply specific improvements to identified hotspots (e.g., caching, sync.Pool, bitwise ops).\n")
	sb.WriteString("3. **Verify Performance Gains**: Re-run quick benchmarks to confirm improvements.\n")
	sb.WriteString("4. **Apply Micro-optimizations**: If necessary, perform low-level tuning for maximum efficiency.\n")
	sb.WriteString("5. **Final Performance Report**: Summarize the final performance state and remaining deltas.\n\n")
	sb.WriteString("GUIDELINES:\n")
	sb.WriteString("- Prioritize optimizations with the highest ROI (return on investment).\n")
	sb.WriteString("- Avoid 'premature optimization' – focus on proven bottlenecks.\n")
	sb.WriteString("- Ensure correctness is maintained through verification tests.\n\n")
	sb.WriteString("OUTPUT:\n")
	sb.WriteString("A highly optimized codebase and a final performance summary.")

	return exec(ctx, sb.String())
}

// AddMetric adds a metric to the schedule.
func (s *ScaleSchedule) AddMetric(name string, value float64) {
	s.Metrics[name] = value
}

// AddHotspot adds a hotspot to the schedule.
func (s *ScaleSchedule) AddHotspot(hotspot string) {
	s.Hotspots = append(s.Hotspots, hotspot)
}

// AddReport adds a report to the schedule.
func (s *ScaleSchedule) AddReport(report string) {
	s.Reports = append(s.Reports, report)
}

// GetSummary returns a summary of the scaling progress.
func (s *ScaleSchedule) GetSummary() string {
	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("Metrics Collected: %d\n", len(s.Metrics)))
	sb.WriteString(fmt.Sprintf("Hotspots Identified: %d\n", len(s.Hotspots)))
	sb.WriteString(fmt.Sprintf("Reports Generated: %d\n", len(s.Reports)))
	return sb.String()
}

// GetConsultationRequirement returns the consultation requirements for this schedule.
func (s *ScaleSchedule) GetConsultationRequirement(processID orchestrate.ProcessID) (bool, string) {
	// Scale schedule typically doesn't require mandatory human consultation.
	return false, ""
}

// GetModelRequirement returns the preferred model for a process.
func (s *ScaleSchedule) GetModelRequirement(processID orchestrate.ProcessID) orchestrate.ModelType {
	return orchestrate.ModelCoder
}

// FinalizeSummary provides a concluding summary for the Scale schedule.
func (s *ScaleSchedule) FinalizeSummary(stats map[string]interface{}) string {
	return "Scale phase completed. Performance concerns identified, benchmarks executed, and optimizations applied."
}
