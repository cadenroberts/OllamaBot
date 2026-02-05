// Package ui implements the terminal UI for obot orchestration.
package ui

import (
	"fmt"
	"io"
	"strings"
	"sync"
)

// MemoryVisualization displays real-time memory usage with prediction.
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

	// Configuration
	width     int
	barWidth  int
	filledChar rune
	emptyChar  rune
}

// NewMemoryVisualization creates a new memory visualization
func NewMemoryVisualization(writer io.Writer, width int) *MemoryVisualization {
	return &MemoryVisualization{
		writer:      writer,
		width:       width,
		barWidth:    40,
		filledChar:  '█',
		emptyChar:   '░',
		totalGB:     8.0, // Default, will be updated with actual system RAM
	}
}

// SetTotalMemory sets the total system memory
func (m *MemoryVisualization) SetTotalMemory(gb float64) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.totalGB = gb
}

// Update updates the memory values
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
}

// SetPrediction sets the predicted memory for the next operation
func (m *MemoryVisualization) SetPrediction(predictGB float64, label string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.predictGB = predictGB
	m.predictLabel = label
}

// Render renders the memory visualization
func (m *MemoryVisualization) Render() string {
	m.mu.Lock()
	defer m.mu.Unlock()

	var sb strings.Builder

	sb.WriteString(FormatLabel("Memory"))
	sb.WriteString("\n")

	// Current usage
	currentBar := ProgressBar(m.currentGB, m.totalGB, m.barWidth, m.filledChar, m.emptyChar)
	sb.WriteString(fmt.Sprintf("├─ Current: %s  %.1f GB / %.1f GB\n",
		currentBar, m.currentGB, m.totalGB))

	// Peak usage
	peakBar := ProgressBar(m.peakGB, m.totalGB, m.barWidth, m.filledChar, m.emptyChar)
	sb.WriteString(fmt.Sprintf("├─ Peak:    %s  %.1f GB\n",
		peakBar, m.peakGB))

	// Prediction
	predictBar := ProgressBar(m.predictGB, m.totalGB, m.barWidth, m.filledChar, m.emptyChar)
	predictLabel := "--"
	if m.predictLabel != "" {
		predictLabel = fmt.Sprintf("%.1f GB (%s)", m.predictGB, m.predictLabel)
	} else if m.predictGB > 0 {
		predictLabel = fmt.Sprintf("%.1f GB", m.predictGB)
	}
	sb.WriteString(fmt.Sprintf("└─ Predict: %s  %s",
		predictBar, predictLabel))

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
	bar := ProgressBar(current, total, m.barWidth, m.filledChar, m.emptyChar)

	if ratio >= 0.95 {
		return Red + bar + Reset
	}
	if ratio >= 0.80 {
		return Yellow + bar + Reset
	}
	return bar
}
