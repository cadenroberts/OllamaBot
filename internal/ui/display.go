// Package ui implements the terminal UI for obot orchestration.
package ui

import (
	"fmt"
	"io"
	"strings"
	"sync"
	"time"

	"github.com/croberts/obot/internal/orchestrate"
)

// StatusDisplay manages the stationary 4-line status display.
type StatusDisplay struct {
	mu     sync.Mutex
	writer io.Writer

	// Current values
	orchestratorState string
	scheduleName      string
	processName       string
	agentAction       string

	// Animation state
	animationTick int
	animating     map[string]bool

	// Configuration
	width         int
	dotInterval   time.Duration
	stopAnimation chan struct{}
}

// NewStatusDisplay creates a new status display
func NewStatusDisplay(writer io.Writer, width int, dotInterval time.Duration) *StatusDisplay {
	return &StatusDisplay{
		writer:            writer,
		width:             width,
		dotInterval:       dotInterval,
		orchestratorState: "",
		scheduleName:      "",
		processName:       "",
		agentAction:       "",
		animating:         make(map[string]bool),
		stopAnimation:     make(chan struct{}),
	}
}

// SetOrchestratorState sets the orchestrator state
func (d *StatusDisplay) SetOrchestratorState(state orchestrate.OrchestratorState) {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.orchestratorState = string(state)
	d.animating["orchestrator"] = false
}

// SetSchedule sets the current schedule
func (d *StatusDisplay) SetSchedule(name string) {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.scheduleName = name
	d.animating["schedule"] = false
}

// SetProcess sets the current process
func (d *StatusDisplay) SetProcess(name string) {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.processName = name
	d.animating["process"] = false
}

// SetAgentAction sets the current agent action
func (d *StatusDisplay) SetAgentAction(action string) {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.agentAction = action
	d.animating["agent"] = false
}

// StartAnimation starts the dot animation for a component
func (d *StatusDisplay) StartAnimation(component string) {
	d.mu.Lock()
	d.animating[component] = true
	d.mu.Unlock()
}

// StopAnimations stops all animations
func (d *StatusDisplay) StopAnimations() {
	close(d.stopAnimation)
}

// getAnimatedDots returns the current animation dots
func (d *StatusDisplay) getAnimatedDots() string {
	dots := []string{".", "..", "...", "..", ".", ""}
	return dots[d.animationTick%len(dots)]
}

// Render renders the status display
func (d *StatusDisplay) Render() string {
	d.mu.Lock()
	defer d.mu.Unlock()

	var sb strings.Builder

	// Orchestrator line
	sb.WriteString(FormatLabelBold("Orchestrator"))
	sb.WriteString(FormatBullet())
	if d.animating["orchestrator"] || d.orchestratorState == "" {
		sb.WriteString(d.getAnimatedDots())
	} else {
		sb.WriteString(FormatValue(d.orchestratorState))
	}
	sb.WriteString("\n")

	// Schedule line
	sb.WriteString(FormatLabel("Schedule"))
	sb.WriteString(FormatBullet())
	if d.animating["schedule"] || d.scheduleName == "" {
		sb.WriteString(d.getAnimatedDots())
	} else {
		sb.WriteString(FormatValue(d.scheduleName))
	}
	sb.WriteString("\n")

	// Process line
	sb.WriteString(FormatLabel("Process"))
	sb.WriteString(FormatBullet())
	if d.animating["process"] || d.processName == "" {
		sb.WriteString(d.getAnimatedDots())
	} else {
		sb.WriteString(FormatValue(d.processName))
	}
	sb.WriteString("\n")

	// Agent line
	sb.WriteString(FormatLabel("Agent"))
	sb.WriteString(FormatBullet())
	if d.animating["agent"] || d.agentAction == "" {
		sb.WriteString(d.getAnimatedDots())
	} else {
		sb.WriteString(FormatValue(d.agentAction))
	}

	return sb.String()
}

// Update updates the display in place
func (d *StatusDisplay) Update() {
	d.mu.Lock()
	d.animationTick++
	d.mu.Unlock()

	// Move cursor up 4 lines, clear, and re-render
	output := CursorSave + MoveCursorUp(4)
	for i := 0; i < 4; i++ {
		output += ClearLine + "\n"
	}
	output += MoveCursorUp(4) + d.Render() + CursorRestore

	d.mu.Lock()
	fmt.Fprint(d.writer, output)
	d.mu.Unlock()
}

// Draw draws the initial display
func (d *StatusDisplay) Draw() {
	d.mu.Lock()
	fmt.Fprintln(d.writer, d.Render())
	d.mu.Unlock()
}

// RunAnimationLoop runs the animation loop
func (d *StatusDisplay) RunAnimationLoop() {
	ticker := time.NewTicker(d.dotInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			hasAnimation := false
			d.mu.Lock()
			for _, animating := range d.animating {
				if animating {
					hasAnimation = true
					break
				}
			}
			d.mu.Unlock()

			if hasAnimation {
				d.Update()
			}
		case <-d.stopAnimation:
			return
		}
	}
}

// Clear clears the display
func (d *StatusDisplay) Clear() {
	d.mu.Lock()
	defer d.mu.Unlock()

	output := MoveCursorUp(4)
	for i := 0; i < 4; i++ {
		output += ClearLine + "\n"
	}
	output += MoveCursorUp(4)
	fmt.Fprint(d.writer, output)
}
