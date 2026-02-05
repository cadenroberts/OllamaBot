package stats

import (
	"sync"
	"time"
)

var (
	globalTracker *Tracker
	trackerOnce   sync.Once
)

// GetTracker returns the global stats tracker
func GetTracker() *Tracker {
	trackerOnce.Do(func() {
		globalTracker = NewTracker()
		globalTracker.Load()
	})
	return globalTracker
}

// Tracker tracks usage statistics
type Tracker struct {
	mu   sync.RWMutex
	data *StatsData
}

// StatsData contains all tracked statistics
type StatsData struct {
	// Token usage
	TotalInputTokens  int `json:"total_input_tokens"`
	TotalOutputTokens int `json:"total_output_tokens"`

	// Usage counts
	TotalInferences int `json:"total_inferences"`
	FilesFixes      int `json:"files_fixed"`
	Sessions        int `json:"sessions"`

	// Time tracking
	TotalInferenceTime time.Duration `json:"total_inference_time"`
	FirstUse           time.Time     `json:"first_use"`
	LastUse            time.Time     `json:"last_use"`
	SessionStart       time.Time     `json:"session_start"`

	// Performance
	FastestInference time.Duration `json:"fastest_inference"`
	SlowestInference time.Duration `json:"slowest_inference"`
}

// NewTracker creates a new stats tracker
func NewTracker() *Tracker {
	now := time.Now()
	return &Tracker{
		data: &StatsData{
			FirstUse:     now,
			LastUse:      now,
			SessionStart: now,
			Sessions:     1,
		},
	}
}

// RecordInference records an inference operation
func (t *Tracker) RecordInference(inputTokens, outputTokens int, duration time.Duration) {
	t.mu.Lock()
	defer t.mu.Unlock()

	t.data.TotalInputTokens += inputTokens
	t.data.TotalOutputTokens += outputTokens
	t.data.TotalInferences++
	t.data.TotalInferenceTime += duration
	t.data.LastUse = time.Now()

	// Track fastest/slowest
	if t.data.FastestInference == 0 || duration < t.data.FastestInference {
		t.data.FastestInference = duration
	}
	if duration > t.data.SlowestInference {
		t.data.SlowestInference = duration
	}
}

// RecordFileFix records a file fix
func (t *Tracker) RecordFileFix() {
	t.mu.Lock()
	defer t.mu.Unlock()

	t.data.FilesFixes++
	t.data.LastUse = time.Now()
}

// GetSummary returns a summary of statistics
func (t *Tracker) GetSummary() Summary {
	t.mu.RLock()
	defer t.mu.RUnlock()

	savings := CalculateCostSavings(t.data.TotalInputTokens, t.data.TotalOutputTokens)

	// Calculate monthly projection based on usage rate
	var monthlyProjection float64
	if !t.data.FirstUse.IsZero() {
		duration := time.Since(t.data.FirstUse)
		if duration > 0 {
			daysUsed := duration.Hours() / 24
			if daysUsed < 1 {
				daysUsed = 1
			}
			dailyRate := savings.ClaudeOpus / daysUsed
			monthlyProjection = dailyRate * 30
		}
	}

	return Summary{
		TotalTokens:         t.data.TotalInputTokens + t.data.TotalOutputTokens,
		InputTokens:         t.data.TotalInputTokens,
		OutputTokens:        t.data.TotalOutputTokens,
		TotalInferences:     t.data.TotalInferences,
		FilesFixes:          t.data.FilesFixes,
		Sessions:            t.data.Sessions,
		FirstUse:            t.data.FirstUse,
		LastUse:             t.data.LastUse,
		TotalInferenceTime:  t.data.TotalInferenceTime,
		ClaudeOpusSavings:   savings.ClaudeOpus,
		ClaudeSonnetSavings: savings.ClaudeSonnet,
		GPT4oSavings:        savings.GPT4o,
		MonthlyProjection:   monthlyProjection,
	}
}

// Summary contains summarized statistics
type Summary struct {
	TotalTokens         int
	InputTokens         int
	OutputTokens        int
	TotalInferences     int
	FilesFixes          int
	Sessions            int
	FirstUse            time.Time
	LastUse             time.Time
	TotalInferenceTime  time.Duration
	ClaudeOpusSavings   float64
	ClaudeSonnetSavings float64
	GPT4oSavings        float64
	MonthlyProjection   float64
}

// Reset resets all statistics
func (t *Tracker) Reset() {
	t.mu.Lock()
	defer t.mu.Unlock()

	now := time.Now()
	t.data = &StatsData{
		FirstUse:     now,
		LastUse:      now,
		SessionStart: now,
		Sessions:     1,
	}
}
