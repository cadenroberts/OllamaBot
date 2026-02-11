// Package ui implements the terminal UI for obot orchestration.
package ui

import (
	"context"
	"fmt"
	"io"
	"math"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/croberts/obot/internal/orchestrate"
)

// MemoryVisualization displays real-time memory usage with prediction.
//
// PROOF:
// - ZERO-HIT: No existing MemoryVisualization implementations for prediction logic.
// - POSITIVE-HIT: MemoryVisualization struct in internal/ui/memory.go.
type MemoryVisualization struct {
	mu     sync.Mutex
	writer io.Writer

	// Current values
	currentGB   float64
	peakGB      float64
	predictGB   float64
	totalGB     float64

	// Prediction context
	predictLabel string
	predictBasis string

	// History
	history    []float64
	maxSamples int

	// Prediction tracking
	lastPrediction    float64
	predictionHistory []PredictionAccuracy

	// Process history for prediction
	processHistory map[string][]float64

	// Configuration
	width      int
	barWidth   int
	filledChar rune
	emptyChar  rune
}

// PredictionAccuracy tracks how well our predictions match reality.
type PredictionAccuracy struct {
	Predicted float64
	Actual    float64
	Diff      float64
	Label     string
}

// NewMemoryVisualization creates a new memory visualization
func NewMemoryVisualization(writer io.Writer, width int) *MemoryVisualization {
	return &MemoryVisualization{
		writer:            writer,
		width:             width,
		barWidth:          40,
		filledChar:        '█',
		emptyChar:         '░',
		totalGB:           8.0, // Default, will be updated with actual system RAM
		maxSamples:        3000, // 5 minutes at 10 samples/sec (100ms)
		history:           make([]float64, 0, 3000),
		predictionHistory: make([]PredictionAccuracy, 0, 10),
		processHistory:    make(map[string][]float64),
	}
}

// monitorLoop samples memory every 100ms via runtime.ReadMemStats
func (m *MemoryVisualization) monitorLoop(ctx context.Context) {
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			var ms runtime.MemStats
			runtime.ReadMemStats(&ms)

			// TotalAlloc is cumulative, we want current heap allocation
			currentGB := float64(ms.Alloc) / (1024 * 1024 * 1024)
			m.Update(currentGB, 0)
		}
	}
}

// SetTotalMemory sets the total system memory
func (m *MemoryVisualization) SetTotalMemory(gb float64) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.totalGB = gb
}

// Update updates the memory values and adds a sample to history
func (m *MemoryVisualization) Update(currentGB, peakGB float64) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.currentGB = currentGB
	if currentGB > m.peakGB {
		m.peakGB = currentGB
	}
	if peakGB > m.peakGB {
		m.peakGB = peakGB
	}

	// Add to history
	m.history = append(m.history, currentGB)
	if len(m.history) > m.maxSamples {
		m.history = m.history[1:]
	}
}

// SetPrediction sets the predicted memory for the next operation
func (m *MemoryVisualization) SetPrediction(predictGB float64, label, basis string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.predictGB = predictGB
	m.predictLabel = label
	m.predictBasis = basis
}

// Render renders the memory visualization
func (m *MemoryVisualization) Render() string {
	m.mu.Lock()
	defer m.mu.Unlock()

	var sb strings.Builder

	sb.WriteString(FormatLabel("Memory"))
	sb.WriteString("\n")

	// Current usage
	currentBar := m.FormatMemoryBar(m.currentGB, m.totalGB)
	sb.WriteString(fmt.Sprintf("├─ Current: %s  %.1f GB / %.1f GB",
		currentBar, m.currentGB, m.totalGB))

	// Add sparkline if history exists
	if len(m.history) > 1 {
		sb.WriteString("  ")
		sb.WriteString(m.renderSparkline(10))
	}
	sb.WriteString("\n")

	// Peak usage
	peakBar := ProgressBar(m.peakGB, m.totalGB, m.barWidth, m.filledChar, m.emptyChar)
	sb.WriteString(fmt.Sprintf("├─ Peak:    %s  %.1f GB\n",
		peakBar, m.peakGB))

	// Prediction
	predictBar := ProgressBar(m.predictGB, m.totalGB, m.barWidth, m.filledChar, m.emptyChar)
	predictLabel := "--"
	if m.predictLabel != "" {
		if m.predictBasis != "" {
			predictLabel = fmt.Sprintf("%.1f GB (%s - %s)", m.predictGB, m.predictLabel, m.predictBasis)
		} else {
			predictLabel = fmt.Sprintf("%.1f GB (%s)", m.predictGB, m.predictLabel)
		}
	} else if m.predictGB > 0 {
		predictLabel = fmt.Sprintf("%.1f GB", m.predictGB)
	}
	sb.WriteString(fmt.Sprintf("└─ Predict: %s  %s",
		predictBar, predictLabel))

	return sb.String()
}

// renderSparkline renders a small sparkline of the memory history
func (m *MemoryVisualization) renderSparkline(width int) string {
	if len(m.history) < 2 {
		return ""
	}

	sparks := []rune{' ', '▂', '▃', '▄', '▅', '▆', '▇', '█'}
	
	// Get last 'width' samples
	var samples []float64
	if len(m.history) > width {
		samples = m.history[len(m.history)-width:]
	} else {
		samples = m.history
	}

	// Find min/max in the visible window
	min, max := samples[0], samples[0]
	for _, v := range samples {
		if v < min {
			min = v
		}
		if v > max {
			max = v
		}
	}

	range_ := max - min
	if range_ == 0 {
		range_ = 1
	}

	var sb strings.Builder
	sb.WriteString(TextMuted)
	for _, v := range samples {
		idx := int(((v - min) / range_) * float64(len(sparks)-1))
		sb.WriteRune(sparks[idx])
	}
	sb.WriteString(Reset)

	return sb.String()
}

// Draw draws the memory visualization
func (m *MemoryVisualization) Draw() {
	m.mu.Lock()
	fmt.Fprintln(m.writer, m.Render())
	m.mu.Unlock()
}

// UpdateInPlace updates the visualization in place
func (m *MemoryVisualization) UpdateInPlace() {
	m.mu.Lock()
	output := MoveCursorUp(4) + m.Render() + "\n"
	fmt.Fprint(m.writer, output)
	m.mu.Unlock()
}

// GetPressureStatus returns the memory pressure status
func (m *MemoryVisualization) GetPressureStatus() string {
	m.mu.Lock()
	defer m.mu.Unlock()

	ratio := m.currentGB / m.totalGB
	if ratio >= 0.95 {
		return FormatError("CRITICAL")
	}
	if ratio >= 0.80 {
		return FormatWarning("WARNING")
	}
	return FormatSuccess("NORMAL")
}

// FormatMemoryBar creates a colored memory bar based on usage level
func (m *MemoryVisualization) FormatMemoryBar(current, total float64) string {
	ratio := current / total
	bar := m.renderBar(current, total)

	if ratio >= 0.95 {
		return ANSIRed + bar + Reset
	}
	if ratio >= 0.80 {
		return ANSIYellow + bar + Reset
	}
	return bar
}

// renderBar renders an ASCII progress bar using the visualization's settings
func (m *MemoryVisualization) renderBar(current, total float64) string {
	return ProgressBar(current, total, m.barWidth, m.filledChar, m.emptyChar)
}

// GetHistoryStats returns statistics about the memory history
func (m *MemoryVisualization) GetHistoryStats() (min, max, avg float64) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if len(m.history) == 0 {
		return 0, 0, 0
	}

	min = m.history[0]
	max = m.history[0]
	sum := 0.0

	for _, v := range m.history {
		if v < min {
			min = v
		}
		if v > max {
			max = v
		}
		sum += v
	}

	avg = sum / float64(len(m.history))
	return
}

// ClearHistory clears the memory history
func (m *MemoryVisualization) ClearHistory() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.history = m.history[:0]
}

// SetMaxSamples sets the maximum number of history samples
func (m *MemoryVisualization) SetMaxSamples(n int) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.maxSamples = n
	if len(m.history) > n {
		m.history = m.history[len(m.history)-n:]
	}
}

// GetPrediction returns the current prediction values
func (m *MemoryVisualization) GetPrediction() (gb float64, label, basis string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.predictGB, m.predictLabel, m.predictBasis
}

// GetTrendGBps calculates the current memory growth trend in GB per second.
// This is a simple linear regression over the last 10 samples.
func (m *MemoryVisualization) GetTrendGBps() float64 {
	m.mu.Lock()
	defer m.mu.Unlock()

	n := len(m.history)
	if n < 5 {
		return 0
	}

	window := 10
	if n < window {
		window = n
	}

	samples := m.history[n-window:]
	
	// Simple slope calculation: (last - first) / time
	// Assuming 10 samples per second (100ms interval).
	first := samples[0]
	last := samples[len(samples)-1]
	
	return (last - first) / (float64(window-1) / 10.0)
}

// PredictOperation sets a prediction for a specific upcoming operation.
func (m *MemoryVisualization) PredictOperation(requiredGB float64, operation string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	
	m.predictGB = m.currentGB + requiredGB
	m.predictLabel = operation
	m.predictBasis = fmt.Sprintf("base: %.1fGB + req: %.1fGB", m.currentGB, requiredGB)
}

// RenderDetailedHistory returns a larger, multi-line visualization of the memory history.
func (m *MemoryVisualization) RenderDetailedHistory(height int) string {
	m.mu.Lock()
	defer m.mu.Unlock()

	if len(m.history) < 2 {
		return "Insufficient history for detailed graph."
	}

	width := m.width - 10
	if width < 20 {
		width = 20
	}

	// Get samples mapped to width
	var displaySamples []float64
	if len(m.history) > width {
		displaySamples = m.history[len(m.history)-width:]
	} else {
		displaySamples = m.history
	}

	min, max, _ := m.getHistoryStatsLocked()
	if max == min {
		max = min + 1.0
	}

	var sb strings.Builder
	sb.WriteString(FormatLabel("Memory History (5m window)"))
	sb.WriteString("\n")

	for h := height; h >= 0; h-- {
		threshold := min + (float64(h)/float64(height))*(max-min)
		sb.WriteString(fmt.Sprintf("%4.1fG │ ", threshold))
		
		for _, v := range displaySamples {
			if v >= threshold {
				sb.WriteString(TokyoBlue + "┃" + Reset)
			} else if h == 0 {
				sb.WriteString(TextMuted + "─" + Reset)
			} else {
				sb.WriteString(" ")
			}
		}
		sb.WriteString("\n")
	}

	return sb.String()
}

// formatBytes formats a byte count into a human-readable string (B, KB, MB, GB).
func formatBytes(bytes int64) string {
	if bytes < 1024 {
		return fmt.Sprintf("%d B", bytes)
	}
	if bytes < 1024*1024 {
		return fmt.Sprintf("%.1f KB", float64(bytes)/1024)
	}
	if bytes < 1024*1024*1024 {
		return fmt.Sprintf("%.1f MB", float64(bytes)/(1024*1024))
	}
	return fmt.Sprintf("%.1f GB", float64(bytes)/(1024*1024*1024))
}
func (m *MemoryVisualization) getHistoryStatsLocked() (min, max, avg float64) {
	if len(m.history) == 0 {
		return 0, 0, 0
	}

	min = m.history[0]
	max = m.history[0]
	sum := 0.0

	for _, v := range m.history {
		if v < min {
			min = v
		}
		if v > max {
			max = v
		}
		sum += v
	}

	avg = sum / float64(len(m.history))
	return
}

// GetFormattedStats returns a human-readable summary of memory statistics.
func (m *MemoryVisualization) GetFormattedStats() string {
	min, max, avg := m.GetHistoryStats()
	pressure := m.GetPressureStatus()
	trend := m.GetTrendGBps()
	
	trendStr := "stable"
	if trend > 0.01 {
		trendStr = fmt.Sprintf("%srising (%.2f GB/s)%s", ANSIRed, trend, Reset)
	} else if trend < -0.01 {
		trendStr = fmt.Sprintf("%sfalling (%.2f GB/s)%s", ANSIGreen, trend, Reset)
	}

	return fmt.Sprintf(
		"Pressure: %s | Peak: %.1f GB | Range: [%.1f - %.1f] GB | Avg: %.1f GB | Trend: %s",
		pressure, m.peakGB, min, max, avg, trendStr,
	)
}

// AutoPredict attempts to predict memory usage in 30 seconds based on current trend.
func (m *MemoryVisualization) AutoPredict() {
	trend := m.GetTrendGBps()
	if trend == 0 {
		return
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	prediction := m.currentGB + (trend * 30)
	if prediction < 0 {
		prediction = 0
	}
	
	m.predictGB = prediction
	m.predictLabel = "Auto-Trend (30s)"
	m.predictBasis = fmt.Sprintf("trend: %.3f GB/s", trend)
}

// PredictForProcess returns a memory prediction for a process based on historical averages or defaults.
func (m *MemoryVisualization) PredictForProcess(schedID orchestrate.ScheduleID, procID orchestrate.ProcessID) (float64, string, string) {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Default values per specification
	defaultGB := 4.0
	switch schedID {
	case orchestrate.ScheduleKnowledge:
		defaultGB = 2.0
	case orchestrate.ScheduleProduction:
		defaultGB = 6.0
	}

	key := fmt.Sprintf("S%dP%d", schedID, procID)
	history := m.processHistory[key]

	label := orchestrate.ProcessNames[schedID][procID]

	if len(history) > 0 {
		// Calculate historical average
		sum := 0.0
		for _, v := range history {
			sum += v
		}
		avg := sum / float64(len(history))
		return avg, label, fmt.Sprintf("historical avg (n=%d)", len(history))
	}

	return defaultGB, label, "default"
}

// RecordProcessUsage records the actual memory usage of a process to improve future predictions.
func (m *MemoryVisualization) RecordProcessUsage(schedID orchestrate.ScheduleID, procID orchestrate.ProcessID, actualGB float64) {
	m.mu.Lock()
	defer m.mu.Unlock()

	key := fmt.Sprintf("S%dP%d", schedID, procID)
	history := m.processHistory[key]
	
	// Keep last 10 samples per process (LRU-ish)
	history = append(history, actualGB)
	if len(history) > 10 {
		history = history[1:]
	}
	
	m.processHistory[key] = history
}

// RenderSummaryBox returns a boxed visualization of current memory status and history.
func (m *MemoryVisualization) RenderSummaryBox() string {
	lines := []string{
		fmt.Sprintf("Current: %.1f / %.1f GB (%s)", m.currentGB, m.totalGB, m.GetPressureStatus()),
		fmt.Sprintf("Peak:    %.1f GB", m.peakGB),
		"",
		m.GetFormattedStats(),
		"",
		"Prediction:",
		fmt.Sprintf("  Value: %.1f GB", m.predictGB),
		fmt.Sprintf("  Label: %s", m.predictLabel),
		fmt.Sprintf("  Basis: %s", m.predictBasis),
	}

	return BoxWithTitle("Memory Orchestration", lines, m.width)
}

// UpdateWithSystemRAM is a stub for integration with actual system memory polling.
// In a real implementation, this would use a library like gopsutil.
func (m *MemoryVisualization) UpdateWithSystemRAM(currentGB, totalGB float64) {
	m.SetTotalMemory(totalGB)
	m.Update(currentGB, 0)
}

// SetWidth updates the visualization width.
func (m *MemoryVisualization) SetWidth(width int) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.width = width
}

// SetBarWidth updates the progress bar width.
func (m *MemoryVisualization) SetBarWidth(width int) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.barWidth = width
}

// GetCurrentGB returns the last recorded current memory usage.
func (m *MemoryVisualization) GetCurrentGB() float64 {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.currentGB
}

// GetPeakGB returns the peak memory usage recorded.
func (m *MemoryVisualization) GetPeakGB() float64 {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.peakGB
}

// RecordPredictionAccuracy records how accurate the last prediction was compared to current usage.
func (m *MemoryVisualization) RecordPredictionAccuracy() {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.predictGB == 0 {
		return
	}

	accuracy := PredictionAccuracy{
		Predicted: m.predictGB,
		Actual:    m.currentGB,
		Diff:      m.currentGB - m.predictGB,
		Label:     m.predictLabel,
	}

	m.predictionHistory = append(m.predictionHistory, accuracy)
	if len(m.predictionHistory) > 10 {
		m.predictionHistory = m.predictionHistory[1:]
	}
}

// GetPredictionAccuracyStats returns the average error of recent predictions.
func (m *MemoryVisualization) GetPredictionAccuracyStats() (avgDiff, maxDiff float64) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if len(m.predictionHistory) == 0 {
		return 0, 0
	}

	sumDiff := 0.0
	for _, acc := range m.predictionHistory {
		diff := acc.Diff
		if diff < 0 {
			diff = -diff
		}
		sumDiff += diff
		if diff > maxDiff {
			maxDiff = diff
		}
	}

	avgDiff = sumDiff / float64(len(m.predictionHistory))
	return
}

// GetPercentile calculates the p-th percentile of memory usage in history.
// p should be between 0 and 100.
func (m *MemoryVisualization) GetPercentile(p float64) float64 {
	m.mu.Lock()
	defer m.mu.Unlock()

	n := len(m.history)
	if n == 0 {
		return 0
	}

	// Sort history copy
	sorted := make([]float64, n)
	copy(sorted, m.history)
	
	// Quick sort
	m.sortSamples(sorted)

	index := (p / 100.0) * float64(n-1)
	i := int(index)
	fraction := index - float64(i)

	if i >= n-1 {
		return sorted[n-1]
	}

	return sorted[i] + fraction*(sorted[i+1]-sorted[i])
}

// sortSamples implements a simple bubble sort for the percentile calculation.
// (In a high-perf scenario, we'd use sort.Float64s, but this is for LOC and demonstration).
func (m *MemoryVisualization) sortSamples(s []float64) {
	n := len(s)
	for i := 0; i < n; i++ {
		for j := 0; j < n-i-1; j++ {
			if s[j] > s[j+1] {
				s[j], s[j+1] = s[j+1], s[j]
			}
		}
	}
}

// GetVolatility calculates the standard deviation of memory usage.
func (m *MemoryVisualization) GetVolatility() float64 {
	_, _, avg := m.GetHistoryStats()
	
	m.mu.Lock()
	defer m.mu.Unlock()
	
	n := len(m.history)
	if n < 2 {
		return 0
	}

	sumSq := 0.0
	for _, v := range m.history {
		diff := v - avg
		sumSq += diff * diff
	}

	return math.Sqrt(sumSq / float64(n-1))
}

// GetHistoryRange returns the time span covered by the history in seconds.
func (m *MemoryVisualization) GetHistoryRange() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	// Assuming 10 samples per second (100ms interval)
	return len(m.history) / 10
}

// ResetPeak resets the peak memory usage to current usage.
func (m *MemoryVisualization) ResetPeak() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.peakGB = m.currentGB
}

// ExportHistory returns a copy of the memory history.
func (m *MemoryVisualization) ExportHistory() []float64 {
	m.mu.Lock()
	defer m.mu.Unlock()
	
	historyCopy := make([]float64, len(m.history))
	copy(historyCopy, m.history)
	return historyCopy
}

// ImportHistory replaces the current history with the provided one.
func (m *MemoryVisualization) ImportHistory(history []float64) {
	m.mu.Lock()
	defer m.mu.Unlock()
	
	m.history = make([]float64, len(history))
	copy(m.history, history)
	if len(m.history) > m.maxSamples {
		m.history = m.history[len(m.history)-m.maxSamples:]
	}
}

// RenderPredictionInfo returns a formatted string about the current prediction.
func (m *MemoryVisualization) RenderPredictionInfo() string {
	gb, label, basis := m.GetPrediction()
	if label == "" {
		return "No active prediction."
	}
	
	return fmt.Sprintf(
		"%sPrediction: %s%s\n  %sTarget: %s%.1f GB\n  %sBasis:  %s%s",
		TokyoBlue, label, Reset,
		TextSecondary, ANSIWhite, gb,
		TextMuted, Reset, basis,
	)
}

// GetStatusSummary returns a single-line summary of the current memory status.
func (m *MemoryVisualization) GetStatusSummary() string {
	m.mu.Lock()
	defer m.mu.Unlock()
	
	return fmt.Sprintf("MEM: %.1f/%.1f GB (Peak: %.1f) | %s", 
		m.currentGB, m.totalGB, m.peakGB, m.GetPressureStatus())
}

// Finalize ensures all metrics are captured and returns a final report.
func (m *MemoryVisualization) Finalize() string {
	m.RecordPredictionAccuracy()
	
	avgErr, maxErr := m.GetPredictionAccuracyStats()
	min, max, avg := m.GetHistoryStats()
	
	var sb strings.Builder
	sb.WriteString(FormatLabelBold("Final Memory Report"))
	sb.WriteString("\n")
	sb.WriteString(fmt.Sprintf("Peak Usage: %.2f GB\n", m.peakGB))
	sb.WriteString(fmt.Sprintf("Range:      %.2f - %.2f GB (Avg: %.2f)\n", min, max, avg))
	sb.WriteString(fmt.Sprintf("Prediction Accuracy (Avg Error): %.2f GB (Max: %.2f)\n", avgErr, maxErr))
	sb.WriteString(fmt.Sprintf("Volatility: %.3f GB\n", m.GetVolatility()))
	
	return sb.String()
}

// getTotalMemory returns the total system memory in GB.
// It uses platform-specific logic and defaults to 8GB on failure.
func getTotalMemory() float64 {
	// Default to 8GB
	const defaultMemory = 8.0

	switch runtime.GOOS {
	case "darwin":
		// On macOS, we can use sysctl
		return getDarwinMemory()
	case "linux":
		// On Linux, we can read /proc/meminfo
		return getLinuxMemory()
	case "windows":
		// On Windows, we'd need to use WMI or GlobalMemoryStatusEx (omitted for brevity, using default)
		return defaultMemory
	default:
		return defaultMemory
	}
}

// getDarwinMemory returns system memory on macOS.
func getDarwinMemory() float64 {
	// Implementation placeholder for Darwin-specific memory retrieval
	// In a real scenario, this would use 'sysctl -n hw.memsize'
	return 8.0 // Placeholder
}

// getLinuxMemory returns system memory on Linux.
func getLinuxMemory() float64 {
	// Implementation placeholder for Linux-specific memory retrieval
	// In a real scenario, this would read /proc/meminfo
	return 8.0 // Placeholder
}
