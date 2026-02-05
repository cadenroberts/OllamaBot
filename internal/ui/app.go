// Package ui implements the terminal UI for obot orchestration.
package ui

import (
	"context"
	"fmt"
	"io"
	"strings"
	"sync"
	"time"

	"github.com/croberts/obot/internal/orchestrate"
)

// App is the main terminal UI application for obot orchestrate.
type App struct {
	mu sync.Mutex

	// I/O
	reader io.Reader
	writer io.Writer

	// Components
	display *StatusDisplay
	memory  *MemoryVisualization
	output  *OutputArea

	// State
	version       string
	prompt        string
	isRunning     bool
	noteTarget    NoteTarget
	stopCh        chan struct{}

	// Callbacks
	onPromptSubmit func(string)
	onNoteSubmit   func(string, NoteTarget)
	onStop         func()
}

// NoteTarget indicates where notes should be sent
type NoteTarget string

const (
	NoteTargetOrchestrator NoteTarget = "orchestrator"
	NoteTargetAgent        NoteTarget = "agent"
)

// Config contains UI configuration
type Config struct {
	DotIntervalMS    int
	MemoryUpdateMS   int
	Width            int
	Colors           bool
	MemoryGraph      bool
	Animations       bool
}

// DefaultConfig returns the default UI configuration
func DefaultConfig() *Config {
	return &Config{
		DotIntervalMS:  250,
		MemoryUpdateMS: 100,
		Width:          80,
		Colors:         true,
		MemoryGraph:    true,
		Animations:     true,
	}
}

// NewApp creates a new terminal UI application
func NewApp(reader io.Reader, writer io.Writer, config *Config, version string) *App {
	if config == nil {
		config = DefaultConfig()
	}

	app := &App{
		reader:     reader,
		writer:     writer,
		version:    version,
		noteTarget: NoteTargetOrchestrator,
		stopCh:     make(chan struct{}),
	}

	// Initialize components
	app.display = NewStatusDisplay(writer, config.Width, time.Duration(config.DotIntervalMS)*time.Millisecond)
	app.memory = NewMemoryVisualization(writer, config.Width)
	app.output = NewOutputArea(writer, config.Width)

	return app
}

// SetCallbacks sets the UI callbacks
func (a *App) SetCallbacks(
	onPromptSubmit func(string),
	onNoteSubmit func(string, NoteTarget),
	onStop func(),
) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.onPromptSubmit = onPromptSubmit
	a.onNoteSubmit = onNoteSubmit
	a.onStop = onStop
}

// Run starts the UI application
func (a *App) Run(ctx context.Context) error {
	// Draw initial UI
	a.drawHeader()
	a.drawSeparator()
	a.display.Draw()
	a.drawSeparator()
	a.memory.Draw()
	a.drawSeparator()
	a.output.Draw()
	a.drawSeparator()
	a.drawInputArea()

	// Start animation loop
	go a.display.RunAnimationLoop()

	// Main event loop would go here
	// For now, just wait for context cancellation
	select {
	case <-ctx.Done():
		a.cleanup()
		return ctx.Err()
	case <-a.stopCh:
		a.cleanup()
		return nil
	}
}

// drawHeader draws the header with logo and version
func (a *App) drawHeader() {
	header := `
  ┌─────────┐
  │ 🦙      │  obot orchestrate v` + a.version + `
  └─────────┘
`
	fmt.Fprint(a.writer, header)
}

// drawSeparator draws a horizontal separator
func (a *App) drawSeparator() {
	fmt.Fprintln(a.writer, Separator(78))
}

// drawInputArea draws the input area
func (a *App) drawInputArea() {
	var sb strings.Builder

	sb.WriteString("┌")
	sb.WriteString(strings.Repeat("─", 76))
	sb.WriteString("┐\n")

	sb.WriteString("│ Type your prompt here...")
	sb.WriteString(strings.Repeat(" ", 50))
	sb.WriteString(" │\n")

	sb.WriteString("└")
	sb.WriteString(strings.Repeat("─", 76))
	sb.WriteString("┘\n")

	// Buttons
	if a.isRunning {
		sb.WriteString(strings.Repeat(" ", 58))
		sb.WriteString(FormatLabel("[Stop]"))
	} else {
		sb.WriteString(strings.Repeat(" ", 58))
		sb.WriteString(FormatLabel("[Send]"))
	}
	sb.WriteString("\n\n")

	// Note destination toggle
	if a.noteTarget == NoteTargetOrchestrator {
		sb.WriteString(FormatLabelBold("[🧠 Orchestrator]"))
		sb.WriteString(" ")
		sb.WriteString(FormatLabel("[</> Coder]"))
	} else {
		sb.WriteString(FormatLabel("[🧠 Orchestrator]"))
		sb.WriteString(" ")
		sb.WriteString(FormatLabelBold("[</> Coder]"))
	}
	sb.WriteString("  ← Toggle for note destination\n")

	fmt.Fprint(a.writer, sb.String())
}

// cleanup cleans up the UI
func (a *App) cleanup() {
	a.display.StopAnimations()
	fmt.Fprint(a.writer, ShowCursor)
}

// UpdateOrchestratorState updates the orchestrator state display
func (a *App) UpdateOrchestratorState(state orchestrate.OrchestratorState) {
	a.display.SetOrchestratorState(state)
}

// UpdateSchedule updates the schedule display
func (a *App) UpdateSchedule(scheduleID orchestrate.ScheduleID) {
	name := orchestrate.ScheduleNames[scheduleID]
	a.display.SetSchedule(name)
}

// UpdateProcess updates the process display
func (a *App) UpdateProcess(scheduleID orchestrate.ScheduleID, processID orchestrate.ProcessID) {
	name := orchestrate.ProcessNames[scheduleID][processID]
	a.display.SetProcess(name)
}

// UpdateAgentAction updates the agent action display
func (a *App) UpdateAgentAction(action string) {
	a.display.SetAgentAction(action)
}

// UpdateMemory updates the memory display
func (a *App) UpdateMemory(currentGB, peakGB float64) {
	a.memory.Update(currentGB, peakGB)
	a.memory.UpdateInPlace()
}

// SetMemoryPrediction sets the memory prediction
func (a *App) SetMemoryPrediction(predictGB float64, label string) {
	a.memory.SetPrediction(predictGB, label)
}

// AppendOutput appends content to the output area
func (a *App) AppendOutput(content string) {
	a.output.Append(content)
}

// SetRunning sets the running state
func (a *App) SetRunning(running bool) {
	a.mu.Lock()
	a.isRunning = running
	a.mu.Unlock()
}

// ToggleNoteTarget toggles the note destination
func (a *App) ToggleNoteTarget() {
	a.mu.Lock()
	if a.noteTarget == NoteTargetOrchestrator {
		a.noteTarget = NoteTargetAgent
	} else {
		a.noteTarget = NoteTargetOrchestrator
	}
	a.mu.Unlock()
}

// Stop stops the application
func (a *App) Stop() {
	close(a.stopCh)
}

// OutputArea manages the scrollable output area.
type OutputArea struct {
	mu      sync.Mutex
	writer  io.Writer
	width   int
	lines   []string
	maxLines int
}

// NewOutputArea creates a new output area
func NewOutputArea(writer io.Writer, width int) *OutputArea {
	return &OutputArea{
		writer:   writer,
		width:    width,
		lines:    make([]string, 0),
		maxLines: 1000, // Keep last 1000 lines
	}
}

// Append appends content to the output area
func (o *OutputArea) Append(content string) {
	o.mu.Lock()
	defer o.mu.Unlock()

	// Split content into lines
	newLines := strings.Split(content, "\n")
	o.lines = append(o.lines, newLines...)

	// Trim if too many lines
	if len(o.lines) > o.maxLines {
		o.lines = o.lines[len(o.lines)-o.maxLines:]
	}
}

// Draw draws the output area
func (o *OutputArea) Draw() {
	o.mu.Lock()
	defer o.mu.Unlock()

	fmt.Fprintln(o.writer, "  Output Area (scrollable)")
	fmt.Fprintln(o.writer, "")

	// Show last few lines
	start := len(o.lines) - 10
	if start < 0 {
		start = 0
	}
	for i := start; i < len(o.lines); i++ {
		fmt.Fprintln(o.writer, "  "+o.lines[i])
	}

	fmt.Fprintln(o.writer, "")
}

// Clear clears the output area
func (o *OutputArea) Clear() {
	o.mu.Lock()
	defer o.mu.Unlock()
	o.lines = make([]string, 0)
}

// GetLines returns all lines
func (o *OutputArea) GetLines() []string {
	o.mu.Lock()
	defer o.mu.Unlock()
	result := make([]string, len(o.lines))
	copy(result, o.lines)
	return result
}
