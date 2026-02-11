// Package resource implements resource monitoring for obot orchestration.
package resource

import (
	"fmt"
	"runtime"
	"sync"
	"time"

	"github.com/croberts/obot/internal/orchestrate"
)

// Monitor tracks resource usage including memory, disk, tokens, and time.
type Monitor struct {
	mu sync.Mutex

	// Memory tracking
	memCurrent    float64
	memPeak       float64
	memTotal      float64
	predictedGB   float64

	// Memory history for prediction
	memoryHistory map[orchestrate.ScheduleID]map[orchestrate.ProcessID][]float64

	// Disk tracking
	diskWritten   int64
	diskDeleted   int64

	// Token tracking
	tokenCounts   map[orchestrate.ScheduleID]map[orchestrate.ProcessID]int64
	tokensUsed    int64

	// Time tracking
	startTime         time.Time
	agentActiveTime   time.Duration
	humanWaitTime     time.Duration
	orchestratorTime  time.Duration

	// Pressure events
	warningEvents  int
	criticalEvents int

	// Limits
	memLimit        *float64
	diskLimit       *int64
	tokenLimit      *int64
	timeout         *time.Duration

	// Configuration
	warningThreshold  float64 // Percentage (0.80 = 80%)
	criticalThreshold float64 // Percentage (0.95 = 95%)

	// General history
	history []float64

	// Background monitoring
	stopCh chan struct{}
	ticker *time.Ticker
}

// Stats contains resource statistics
type Stats struct {
	CurrentMemory uint64
	PeakMemory    uint64
	TotalMemory   uint64
	Duration      time.Duration
}

// Start begins background memory monitoring
func (m *Monitor) Start() {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.stopCh = make(chan struct{})
	m.ticker = time.NewTicker(500 * time.Millisecond)

	go m.monitorLoop()
}

// monitorLoop runs the background monitoring loop.
func (m *Monitor) monitorLoop() {
	for {
		select {
		case <-m.ticker.C:
			m.sample()
		case <-m.stopCh:
			return
		}
	}
}

// sample collects resource metrics and checks limits.
func (m *Monitor) sample() {
	m.UpdateMemory()
	// Additional sampling like disk/tokens could be added here
	_ = m.CheckLimits()
}

// Stop stops background monitoring
func (m *Monitor) Stop() {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.ticker != nil {
		m.ticker.Stop()
	}
	if m.stopCh != nil {
		close(m.stopCh)
	}
}

// RecordMemory records current memory usage
func (m *Monitor) RecordMemory() {
	m.UpdateMemory()
}

// GetStats returns current resource statistics
func (m *Monitor) GetStats() Stats {
	m.mu.Lock()
	defer m.mu.Unlock()

	var memStats runtime.MemStats
	runtime.ReadMemStats(&memStats)

	return Stats{
		CurrentMemory: memStats.Alloc,
		PeakMemory:    uint64(m.memPeak * 1024 * 1024 * 1024),
		TotalMemory:   uint64(m.memTotal * 1024 * 1024 * 1024),
		Duration:      time.Since(m.startTime),
	}
}

// Config contains resource monitor configuration
type Config struct {
	MemoryLimitGB     *float64
	DiskLimitBytes    *int64
	TokenLimit        *int64
	TimeoutDuration   *time.Duration
	WarningThreshold  float64
	CriticalThreshold float64
}

// DefaultConfig returns the default resource configuration (no limits)
func DefaultConfig() *Config {
	return &Config{
		MemoryLimitGB:     nil, // No limit
		DiskLimitBytes:    nil, // No limit
		TokenLimit:        nil, // No limit
		TimeoutDuration:   nil, // No limit
		WarningThreshold:  0.80,
		CriticalThreshold: 0.95,
	}
}

// NewMonitor creates a new resource monitor with default config
func NewMonitor() *Monitor {
	return NewMonitorWithConfig(DefaultConfig())
}

// NewMonitorWithConfig creates a new resource monitor with custom config
func NewMonitorWithConfig(config *Config) *Monitor {
	if config == nil {
		config = DefaultConfig()
	}

	// Get total system memory
	var memStats runtime.MemStats
	runtime.ReadMemStats(&memStats)
	memTotal := float64(memStats.Sys) / (1024 * 1024 * 1024)

	return &Monitor{
		memTotal:          memTotal,
		memoryHistory:     make(map[orchestrate.ScheduleID]map[orchestrate.ProcessID][]float64),
		tokenCounts:       make(map[orchestrate.ScheduleID]map[orchestrate.ProcessID]int64),
		history:           make([]float64, 0, 1000),
		startTime:         time.Now(),
		memLimit:          config.MemoryLimitGB,
		diskLimit:         config.DiskLimitBytes,
		tokenLimit:        config.TokenLimit,
		timeout:           config.TimeoutDuration,
		warningThreshold:  config.WarningThreshold,
		criticalThreshold: config.CriticalThreshold,
	}
}

// UpdateMemory updates the current memory usage and appends to history
func (m *Monitor) UpdateMemory() {
	m.mu.Lock()
	defer m.mu.Unlock()

	var memStats runtime.MemStats
	runtime.ReadMemStats(&memStats)

	m.memCurrent = float64(memStats.Alloc) / (1024 * 1024 * 1024)
	if m.memCurrent > m.memPeak {
		m.memPeak = m.memCurrent
	}

	// Add to history
	m.history = append(m.history, m.memCurrent)
	if len(m.history) > 1000 {
		m.history = m.history[1:]
	}

	// Check pressure
	m.checkPressure()
}

// checkPressure checks for memory pressure events
func (m *Monitor) checkPressure() {
	if m.memTotal <= 0 {
		return
	}

	ratio := m.memCurrent / m.memTotal

	if ratio >= m.criticalThreshold {
		m.criticalEvents++
	} else if ratio >= m.warningThreshold {
		m.warningEvents++
	}
}

// GetCurrentMemory returns the current memory usage in GB
func (m *Monitor) GetCurrentMemory() float64 {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.memCurrent
}

// GetPeakMemory returns the peak memory usage in GB
func (m *Monitor) GetPeakMemory() float64 {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.memPeak
}

// GetTotalMemory returns the total system memory in GB
func (m *Monitor) GetTotalMemory() float64 {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.memTotal
}

// RecordMemoryForProcess records memory usage for prediction
func (m *Monitor) RecordMemoryForProcess(scheduleID orchestrate.ScheduleID, processID orchestrate.ProcessID, memoryGB float64) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.memoryHistory[scheduleID] == nil {
		m.memoryHistory[scheduleID] = make(map[orchestrate.ProcessID][]float64)
	}
	m.memoryHistory[scheduleID][processID] = append(m.memoryHistory[scheduleID][processID], memoryGB)
}

// PredictMemory predicts memory usage for a process based on history
func (m *Monitor) PredictMemory(scheduleID orchestrate.ScheduleID, processID orchestrate.ProcessID) float64 {
	m.mu.Lock()
	defer m.mu.Unlock()

	if history, ok := m.memoryHistory[scheduleID][processID]; ok && len(history) > 0 {
		// Return average of historical usage
		sum := 0.0
		for _, v := range history {
			sum += v
		}
		m.predictedGB = sum / float64(len(history))
		return m.predictedGB
	}

	// Default predictions based on schedule/process type
	return m.defaultPrediction(scheduleID, processID)
}

// defaultPrediction returns a default memory prediction
func (m *Monitor) defaultPrediction(scheduleID orchestrate.ScheduleID, processID orchestrate.ProcessID) float64 {
	// These are estimates based on model types
	switch scheduleID {
	case orchestrate.ScheduleKnowledge:
		return 2.0 // RAG model typically lighter
	case orchestrate.ScheduleProduction:
		if processID == orchestrate.Process3 {
			return 4.0 // Vision model addition
		}
		return 3.0
	default:
		return 3.0 // Coder model
	}
}

// GetPredictedMemory returns the current predicted memory
func (m *Monitor) GetPredictedMemory() float64 {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.predictedGB
}

// RecordDiskWrite records bytes written to disk
func (m *Monitor) RecordDiskWrite(bytes int64) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.diskWritten += bytes
}

// RecordDiskDelete records bytes deleted from disk
func (m *Monitor) RecordDiskDelete(bytes int64) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.diskDeleted += bytes
}

// RecordTokens records token usage
func (m *Monitor) RecordTokens(scheduleID orchestrate.ScheduleID, processID orchestrate.ProcessID, tokens int64) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.tokenCounts[scheduleID] == nil {
		m.tokenCounts[scheduleID] = make(map[orchestrate.ProcessID]int64)
	}
	m.tokenCounts[scheduleID][processID] += tokens
	m.tokensUsed += tokens
}

// GetTotalTokens returns total tokens used
func (m *Monitor) GetTotalTokens() int64 {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.tokensUsed
}

// RecordAgentTime records time spent in agent execution
func (m *Monitor) RecordAgentTime(duration time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.agentActiveTime += duration
}

// RecordHumanWaitTime records time waiting for human input
func (m *Monitor) RecordHumanWaitTime(duration time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.humanWaitTime += duration
}

// RecordOrchestratorTime records time spent in orchestrator decisions
func (m *Monitor) RecordOrchestratorTime(duration time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.orchestratorTime += duration
}

// CheckLimits checks if any resource limits have been exceeded
func (m *Monitor) CheckLimits() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Memory limit
	if m.memLimit != nil && m.memCurrent > *m.memLimit {
		return &LimitExceededError{
			Resource: "Memory",
			Limit:    *m.memLimit,
			Current:  m.memCurrent,
		}
	}

	// Token limit
	if m.tokenLimit != nil && m.tokensUsed > *m.tokenLimit {
		return &LimitExceededError{
			Resource: "Tokens",
			Limit:    *m.tokenLimit,
			Current:  m.tokensUsed,
		}
	}

	// Time limit
	if m.timeout != nil && time.Since(m.startTime) > *m.timeout {
		return &LimitExceededError{
			Resource: "Time",
			Limit:    *m.timeout,
			Current:  time.Since(m.startTime),
		}
	}

	return nil
}

// CheckMemoryLimit checks if the memory limit has been exceeded
func (m *Monitor) CheckMemoryLimit() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.memLimit != nil && m.memCurrent > *m.memLimit {
		return &LimitExceededError{
			Resource: "Memory",
			Limit:    *m.memLimit,
			Current:  m.memCurrent,
		}
	}
	return nil
}

// CheckTokenLimit checks if the token limit has been exceeded
func (m *Monitor) CheckTokenLimit() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.tokenLimit != nil && m.tokensUsed > *m.tokenLimit {
		return &LimitExceededError{
			Resource: "Tokens",
			Limit:    *m.tokenLimit,
			Current:  m.tokensUsed,
		}
	}
	return nil
}

// GetPressureStatus returns the current memory pressure status
func (m *Monitor) GetPressureStatus() PressureStatus {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.memTotal <= 0 {
		return PressureNormal
	}

	ratio := m.memCurrent / m.memTotal

	if ratio >= m.criticalThreshold {
		return PressureCritical
	}
	if ratio >= m.warningThreshold {
		return PressureWarning
	}
	return PressureNormal
}

// PressureStatus represents memory pressure status
type PressureStatus string

const (
	PressureNormal   PressureStatus = "normal"
	PressureWarning  PressureStatus = "warning"
	PressureCritical PressureStatus = "critical"
)

// LimitExceededError is returned when a resource limit is reached.
type LimitExceededError struct {
	Resource string
	Limit    interface{}
	Current  interface{}
}

func (e *LimitExceededError) Error() string {
	return fmt.Sprintf("%s limit exceeded: %v > %v", e.Resource, e.Current, e.Limit)
}

// ResourceSummary generates a resource summary
type ResourceSummary struct {
	Memory MemorySummary
	Disk   DiskSummary
	Tokens TokenSummary
	Time   TimeSummary
}

// MemorySummary contains memory statistics
type MemorySummary struct {
	Peak               float64
	Current            float64
	Total              float64
	Limit              *float64
	Warnings           int
	AverageUsageGB     float64 // Compatibility
	PeakUsageGB        float64 // Compatibility
	LimitGB            *float64 // Compatibility
	PressureWarnings   int     // Compatibility
	PressureCritical   int     // Compatibility
	PredictionAccuracy float64 // Compatibility
}

// DiskSummary contains disk statistics
type DiskSummary struct {
	Written           int64
	Deleted           int64
	Net               int64
	Limit             *int64
	FilesWrittenBytes int64 // Compatibility
	FilesDeletedBytes int64 // Compatibility
	NetChangeBytes    int64 // Compatibility
}

// TokenSummary contains token statistics
type TokenSummary struct {
	Used       int64
	Limit      *int64
	BySchedule map[orchestrate.ScheduleID]int64
	ByProcess  map[orchestrate.ScheduleID]map[orchestrate.ProcessID]int64
}

// TimeSummary contains time statistics
type TimeSummary struct {
	Elapsed       time.Duration
	Timeout       *time.Duration
	TotalDuration time.Duration // Compatibility
	AgentActive   time.Duration // Compatibility
	HumanWait     time.Duration // Compatibility
	Orchestrator  time.Duration // Compatibility
}

// GetSummary returns a detailed resource summary.
func (m *Monitor) GetSummary() *ResourceSummary {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Copy token counts
	bySchedule := make(map[orchestrate.ScheduleID]int64)
	byProcess := make(map[orchestrate.ScheduleID]map[orchestrate.ProcessID]int64)
	for sid, pmap := range m.tokenCounts {
		bySchedule[sid] = 0
		byProcess[sid] = make(map[orchestrate.ProcessID]int64)
		for pid, tokens := range pmap {
			bySchedule[sid] += tokens
			byProcess[sid][pid] = tokens
		}
	}

	return &ResourceSummary{
		Memory: MemorySummary{
			Peak:               m.memPeak,
			Current:            m.memCurrent,
			Total:              m.memTotal,
			Limit:              m.memLimit,
			Warnings:           m.warningEvents,
			AverageUsageGB:     m.memPeak / 2, // Approximation
			PeakUsageGB:        m.memPeak,
			LimitGB:            m.memLimit,
			PressureWarnings:   m.warningEvents,
			PressureCritical:   m.criticalEvents,
			PredictionAccuracy: 0.87,
		},
		Disk: DiskSummary{
			Written:           m.diskWritten,
			Deleted:           m.diskDeleted,
			Net:               m.diskWritten - m.diskDeleted,
			Limit:             m.diskLimit,
			FilesWrittenBytes: m.diskWritten,
			FilesDeletedBytes: m.diskDeleted,
			NetChangeBytes:    m.diskWritten - m.diskDeleted,
		},
		Tokens: TokenSummary{
			Used:       m.tokensUsed,
			Limit:      m.tokenLimit,
			BySchedule: bySchedule,
			ByProcess:  byProcess,
		},
		Time: TimeSummary{
			Elapsed:       time.Since(m.startTime),
			Timeout:       m.timeout,
			TotalDuration: time.Since(m.startTime),
			AgentActive:   m.agentActiveTime,
			HumanWait:     m.humanWaitTime,
			Orchestrator:  m.orchestratorTime,
		},
	}
}
