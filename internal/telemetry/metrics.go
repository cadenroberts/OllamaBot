package telemetry

import (
	"sort"
	"sync"
	"time"
)

// PerformanceMetrics tracks key performance indicators for AI agent interactions.
type PerformanceMetrics struct {
	mu                 sync.Mutex
	FirstTokenLatency  time.Duration   `json:"first_token_latency"`
	PatchSuccessRate   float64         `json:"patch_success_rate"`
	UserAcceptanceRate float64         `json:"user_acceptance_rate"`
	MedianTimeToFix    time.Duration   `json:"median_time_to_fix"`

	fixDurations      []time.Duration
	totalPatches      int
	successfulPatches int
	totalAcceptance   int
	acceptedChanges   int
}

// RecordLatency updates the exponential moving average of first token latency.
func (m *PerformanceMetrics) RecordLatency(d time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.FirstTokenLatency == 0 {
		m.FirstTokenLatency = d
	} else {
		// Exponential moving average (alpha=0.3)
		m.FirstTokenLatency = time.Duration(float64(m.FirstTokenLatency)*0.7 + float64(d)*0.3)
	}
}

// RecordPatch records a patch result and updates the success rate.
func (m *PerformanceMetrics) RecordPatch(success bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.totalPatches++
	if success {
		m.successfulPatches++
	}
	m.PatchSuccessRate = float64(m.successfulPatches) / float64(m.totalPatches)
}

// RecordAcceptance records a user decision and updates the acceptance rate.
func (m *PerformanceMetrics) RecordAcceptance(accepted bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.totalAcceptance++
	if accepted {
		m.acceptedChanges++
	}
	m.UserAcceptanceRate = float64(m.acceptedChanges) / float64(m.totalAcceptance)
}

// AddFixDuration adds a completion time and recalculates the median.
func (m *PerformanceMetrics) AddFixDuration(d time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.fixDurations = append(m.fixDurations, d)
	sort.Slice(m.fixDurations, func(i, j int) bool {
		return m.fixDurations[i] < m.fixDurations[j]
	})

	l := len(m.fixDurations)
	if l == 0 {
		return
	}
	if l%2 == 1 {
		m.MedianTimeToFix = m.fixDurations[l/2]
	} else {
		m.MedianTimeToFix = (m.fixDurations[l/2-1] + m.fixDurations[l/2]) / 2
	}
}
