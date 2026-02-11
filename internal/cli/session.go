package cli

import (
	"fmt"
	"os"

	"github.com/croberts/obot/internal/actions"
	"github.com/croberts/obot/internal/monitor"
)

type cliSession struct {
	recorder *actions.Recorder
	stopMem  func()
	summaryEnabled bool
}

func startSession() *cliSession {
	return &cliSession{
		recorder: actions.NewRecorder(),
		summaryEnabled: !noSummary,
	}
}

func (s *cliSession) Add(summary string, facts map[string]string) string {
	return s.recorder.Add(summary, facts)
}

func (s *cliSession) StartMemoryGraph() {
	if !memGraphEnabled {
		return
	}
	if s.stopMem != nil {
		return
	}
	s.stopMem = monitor.StartMemoryGraph(os.Stderr, monitor.Options{
		Label:   "mem",
		Enabled: true,
	})
}

func (s *cliSession) StopMemoryGraph() {
	if s.stopMem == nil {
		return
	}
	s.stopMem()
	s.stopMem = nil
}

func (s *cliSession) Close() {
	s.StopMemoryGraph()
	if s.summaryEnabled && s.recorder.HasActions() {
		fmt.Println()
		fmt.Print(s.recorder.RenderSummary())
	}
}
