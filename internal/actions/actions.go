package actions

import (
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"
)

type Action struct {
	ID      string
	Time    time.Time
	Summary string
	Facts   map[string]string
}

type Recorder struct {
	mu      sync.Mutex
	actions []Action
}

func NewRecorder() *Recorder {
	return &Recorder{
		actions: make([]Action, 0, 16),
	}
}

func (r *Recorder) Add(summary string, facts map[string]string) string {
	r.mu.Lock()
	defer r.mu.Unlock()

	id := fmt.Sprintf("A%02d", len(r.actions)+1)
	var copied map[string]string
	if len(facts) > 0 {
		copied = make(map[string]string, len(facts))
		for k, v := range facts {
			copied[k] = v
		}
	}

	r.actions = append(r.actions, Action{
		ID:      id,
		Time:    time.Now().UTC(),
		Summary: strings.TrimSpace(summary),
		Facts:   copied,
	})

	return id
}

func (r *Recorder) HasActions() bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.actions) > 0
}

func (r *Recorder) RenderSummary() string {
	r.mu.Lock()
	actions := make([]Action, len(r.actions))
	copy(actions, r.actions)
	r.mu.Unlock()

	if len(actions) == 0 {
		return ""
	}

	var sb strings.Builder
	sb.WriteString("Actions Summary\n")
	sb.WriteString("---------------\n")
	for _, action := range actions {
		sb.WriteString(fmt.Sprintf("- [%s] %s\n", action.ID, action.Summary))
	}
	sb.WriteString("\nCitations\n")
	sb.WriteString("---------\n")
	for _, action := range actions {
		sb.WriteString(fmt.Sprintf("[%s] time=%s", action.ID, action.Time.Format(time.RFC3339)))
		if len(action.Facts) > 0 {
			sb.WriteString("; ")
			sb.WriteString(renderFacts(action.Facts))
		}
		sb.WriteString("\n")
	}

	return sb.String()
}

func renderFacts(facts map[string]string) string {
	keys := make([]string, 0, len(facts))
	for key := range facts {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	parts := make([]string, 0, len(keys))
	for _, key := range keys {
		parts = append(parts, fmt.Sprintf("%s=%s", key, facts[key]))
	}
	return strings.Join(parts, "; ")
}
