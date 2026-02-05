package orchestrate

import (
	"fmt"
	"strings"
)

// FlowCode tracks the orchestration flow as a compact string
// Format: S{n}P{n}{n}{n}...S{m}P{n}...
// Example: S1P123S2P12 = Schedule 1 -> P1->P2->P3 -> Schedule 2 -> P1->P2
type FlowCode struct {
	code            strings.Builder
	currentSchedule ScheduleID
	hasError        bool
}

// NewFlowCode creates a new flow code tracker
func NewFlowCode() *FlowCode {
	return &FlowCode{}
}

// AddSchedule records a new schedule start
func (f *FlowCode) AddSchedule(scheduleID ScheduleID) {
	f.code.WriteString(fmt.Sprintf("S%d", scheduleID))
	f.currentSchedule = scheduleID
}

// AddProcess records a process execution
func (f *FlowCode) AddProcess(processID ProcessID) {
	f.code.WriteString(fmt.Sprintf("P%d", processID))
}

// MarkError marks an error at the current position
func (f *FlowCode) MarkError() {
	f.code.WriteString("X")
	f.hasError = true
}

// String returns the flow code string
func (f *FlowCode) String() string {
	return f.code.String()
}

// HasError returns true if an error was recorded
func (f *FlowCode) HasError() bool {
	return f.hasError
}

// Parse parses a flow code string into a sequence of events
func (f *FlowCode) Parse(code string) ([]FlowEvent, error) {
	events := make([]FlowEvent, 0)
	i := 0
	
	for i < len(code) {
		c := code[i]
		switch c {
		case 'S':
			i++
			if i >= len(code) {
				return nil, fmt.Errorf("unexpected end after S at position %d", i-1)
			}
			scheduleNum := int(code[i] - '0')
			if scheduleNum < 1 || scheduleNum > 5 {
				return nil, fmt.Errorf("invalid schedule number %d at position %d", scheduleNum, i)
			}
			events = append(events, FlowEvent{
				Type:     EventSchedule,
				Schedule: ScheduleID(scheduleNum),
			})
			i++
			
		case 'P':
			i++
			if i >= len(code) {
				return nil, fmt.Errorf("unexpected end after P at position %d", i-1)
			}
			processNum := int(code[i] - '0')
			if processNum < 1 || processNum > 3 {
				return nil, fmt.Errorf("invalid process number %d at position %d", processNum, i)
			}
			events = append(events, FlowEvent{
				Type:    EventProcess,
				Process: ProcessID(processNum),
			})
			i++
			
		case 'X':
			events = append(events, FlowEvent{
				Type: EventError,
			})
			i++
			
		default:
			return nil, fmt.Errorf("unexpected character '%c' at position %d", c, i)
		}
	}
	
	return events, nil
}

// FlowEventType identifies the type of flow event
type FlowEventType string

const (
	EventSchedule FlowEventType = "schedule"
	EventProcess  FlowEventType = "process"
	EventError    FlowEventType = "error"
)

// FlowEvent represents a single event in the flow
type FlowEvent struct {
	Type     FlowEventType
	Schedule ScheduleID
	Process  ProcessID
}

// FormatFlowCodeColored returns the flow code with ANSI colors
// Schedule codes (S1-S5) in white, process codes (P1-P3) in blue, X in red
func FormatFlowCodeColored(code string) string {
	var result strings.Builder
	
	const (
		white = "\033[37m"
		blue  = "\033[34m"
		red   = "\033[31m"
		reset = "\033[0m"
	)
	
	i := 0
	for i < len(code) {
		c := code[i]
		switch c {
		case 'S':
			i++
			if i < len(code) {
				result.WriteString(white)
				result.WriteString(fmt.Sprintf("S%c", code[i]))
				result.WriteString(reset)
				i++
			}
		case 'P':
			i++
			if i < len(code) {
				result.WriteString(blue)
				result.WriteString(fmt.Sprintf("P%c", code[i]))
				result.WriteString(reset)
				i++
			}
		case 'X':
			result.WriteString(red)
			result.WriteString("X")
			result.WriteString(reset)
			i++
		default:
			result.WriteByte(c)
			i++
		}
	}
	
	return result.String()
}

// CalculateFlowStats calculates statistics from a flow code
func CalculateFlowStats(code string) (*FlowStats, error) {
	events, err := (&FlowCode{}).Parse(code)
	if err != nil {
		return nil, err
	}
	
	stats := &FlowStats{
		ScheduleCounts: make(map[ScheduleID]int),
		ProcessCounts:  make(map[ScheduleID]map[ProcessID]int),
	}
	
	// Initialize process counts for all schedules
	for s := ScheduleKnowledge; s <= ScheduleProduction; s++ {
		stats.ProcessCounts[s] = make(map[ProcessID]int)
	}
	
	var currentSchedule ScheduleID
	
	for _, event := range events {
		switch event.Type {
		case EventSchedule:
			stats.TotalSchedulings++
			stats.ScheduleCounts[event.Schedule]++
			currentSchedule = event.Schedule
		case EventProcess:
			stats.TotalProcesses++
			stats.ProcessCounts[currentSchedule][event.Process]++
		case EventError:
			stats.HasError = true
		}
	}
	
	return stats, nil
}

// FlowStats contains statistics derived from a flow code
type FlowStats struct {
	TotalSchedulings int
	TotalProcesses   int
	ScheduleCounts   map[ScheduleID]int
	ProcessCounts    map[ScheduleID]map[ProcessID]int
	HasError         bool
}
