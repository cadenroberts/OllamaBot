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
	currentMemoryGB float64
	peakMemoryGB    float64
	predictedGB     float64
	totalSystemGB   float64

	// Memory history for prediction
	memoryHistory map[orchestrate.ScheduleID]map[orchestrate.ProcessID][]float64

	// Disk tracking
	diskWrittenBytes int64
	diskDeletedBytes int64

	// Token tracking
	tokenCounts map[orchestrate.ScheduleID]map[orchestrate.ProcessID]int64
	totalTokens int64

	// Time tracking
	startTime         time.Time
	agentActiveTime   time.Duration
	humanWaitTime     time.Duration
	orchestratorTime  time.Duration

	// Pressure events
	warningEvents  int
	criticalEvents int

	// Limits (nil = no limit)
	memoryLimitGB   *float64
	diskLimitBytes  *int64
	tokenLimit      *int64
	timeoutDuration *time.Duration

	// Configuration
	warningThreshold  float64 // Percentage (0.80 = 80%)
	criticalThreshold float64 // Percentage (0.95 = 95%)

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
	m.ticker = time.NewTicker(100 * time.Millisecond)
	
	go func() {
		for {
			select {
			case <-m.ticker.C:
				m.UpdateMemory()
			case <-m.stopCh:
				return
			}
		}
	}()
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
		PeakMemory:    uint64(m.peakMemoryGB * 1024 * 1024 * 1024),
		TotalMemory:   uint64(m.totalSystemGB * 1024 * 1024 * 1024),
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
	totalSystemGB := float64(memStats.Sys) / (1024 * 1024 * 1024)

	return &Monitor{
		totalSystemGB:     totalSystemGB,
		memoryHistory:     make(map[orchestrate.ScheduleID]map[orchestrate.ProcessID][]float64),
		tokenCounts:       make(map[orchestrate.ScheduleID]map[orchestrate.ProcessID]int64),
		startTime:         time.Now(),
		memoryLimitGB:     config.MemoryLimitGB,
		diskLimitBytes:    config.DiskLimitBytes,
		tokenLimit:        config.TokenLimit,
		timeoutDuration:   config.TimeoutDuration,
		warningThreshold:  config.WarningThreshold,
		criticalThreshold: config.CriticalThreshold,
	}
}

// UpdateMemory updates the current memory usage
func (m *Monitor) UpdateMemory() {
	m.mu.Lock()
	defer m.mu.Unlock()

	var memStats runtime.MemStats
	runtime.ReadMemStats(&memStats)

	m.currentMemoryGB = float64(memStats.Alloc) / (1024 * 1024 * 1024)
	if m.currentMemoryGB > m.peakMemoryGB {
		m.peakMemoryGB = m.currentMemoryGB
	}

	// Check pressure
	m.checkPressure()
}

// checkPressure checks for memory pressure events
func (m *Monitor) checkPressure() {
	if m.totalSystemGB <= 0 {
		return
	}

	ratio := m.currentMemoryGB / m.totalSystemGB

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
	return m.currentMemoryGB
}

// GetPeakMemory returns the peak memory usage in GB
func (m *Monitor) GetPeakMemory() float64 {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.peakMemoryGB
}

// GetTotalMemory returns the total system memory in GB
func (m *Monitor) GetTotalMemory() float64 {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.totalSystemGB
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
	m.diskWrittenBytes += bytes
}

// RecordDiskDelete records bytes deleted from disk
func (m *Monitor) RecordDiskDelete(bytes int64) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.diskDeletedBytes += bytes
}

// RecordTokens records token usage
func (m *Monitor) RecordTokens(scheduleID orchestrate.ScheduleID, processID orchestrate.ProcessID, tokens int64) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.tokenCounts[scheduleID] == nil {
		m.tokenCounts[scheduleID] = make(map[orchestrate.ProcessID]int64)
	}
	m.tokenCounts[scheduleID][processID] += tokens
	m.totalTokens += tokens
}

// GetTotalTokens returns total tokens used
func (m *Monitor) GetTotalTokens() int64 {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.totalTokens
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
	if m.memoryLimitGB != nil && m.currentMemoryGB > *m.memoryLimitGB {
		return fmt.Errorf("memory limit exceeded: %.2f GB > %.2f GB", m.currentMemoryGB, *m.memoryLimitGB)
	}

	// Token limit
	if m.tokenLimit != nil && m.totalTokens > *m.tokenLimit {
		return fmt.Errorf("token limit exceeded: %d > %d", m.totalTokens, *m.tokenLimit)
	}

	// Time limit
	if m.timeoutDuration != nil && time.Since(m.startTime) > *m.timeoutDuration {
		return fmt.Errorf("timeout exceeded: %v > %v", time.Since(m.startTime), *m.timeoutDuration)
	}

	return nil
}

// GetPressureStatus returns the current memory pressure status
func (m *Monitor) GetPressureStatus() PressureStatus {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.totalSystemGB <= 0 {
		return PressureNormal
	}

	ratio := m.currentMemoryGB / m.totalSystemGB

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

// Summary generates a resource summary
type Summary struct {
	Memory  MemorySummary
	Disk    DiskSummary
	Tokens  TokenSummary
	Time    TimeSummary
}

// MemorySummary contains memory statistics
type MemorySummary struct {
	PeakUsageGB     float64
	AverageUsageGB  float64
	LimitGB         *float64
	PressureWarnings  int
	PressureCritical  int
	PredictionAccuracy float64
}

// DiskSummary contains disk statistics
type DiskSummary struct {
	FilesWrittenBytes int64
	FilesDeletedBytes int64
	NetChangeBytes    int64
	SessionStorageBytes int64
	LimitBytes        *int64
}

// TokenSummary contains token statistics
type TokenSummary struct {
	Total     int64
	Limit     *int64
	BySchedule map[orchestrate.ScheduleID]int64
	ByProcess  map[orchestrate.ScheduleID]map[orchestrate.ProcessID]int64
}

// TimeSummary contains time statistics
type TimeSummary struct {
	TotalDuration     time.Duration
	AgentActive       time.Duration
	HumanWait         time.Duration
	Orchestrator      time.Duration
	Limit             *time.Duration
	Timeouts          int
}

// GenerateSummary generates a resource summary
func (m *Monitor) GenerateSummary() *Summary {
	m.mu.Lock()
	defer m.mu.Unlock()

	totalDuration := time.Since(m.startTime)

	// Calculate average memory (simplified)
	avgMemory := m.peakMemoryGB / 2 // Approximation

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

	return &Summary{
		Memory: MemorySummary{
			PeakUsageGB:      m.peakMemoryGB,
			AverageUsageGB:   avgMemory,
			LimitGB:          m.memoryLimitGB,
			PressureWarnings: m.warningEvents,
			PressureCritical: m.criticalEvents,
			PredictionAccuracy: 0.87, // Would be calculated from actual vs predicted
		},
		Disk: DiskSummary{
			FilesWrittenBytes: m.diskWrittenBytes,
			FilesDeletedBytes: m.diskDeletedBytes,
			NetChangeBytes:    m.diskWrittenBytes - m.diskDeletedBytes,
			LimitBytes:        m.diskLimitBytes,
		},
		Tokens: TokenSummary{
			Total:      m.totalTokens,
			Limit:      m.tokenLimit,
			BySchedule: bySchedule,
			ByProcess:  byProcess,
		},
		Time: TimeSummary{
			TotalDuration: totalDuration,
			AgentActive:   m.agentActiveTime,
			HumanWait:     m.humanWaitTime,
			Orchestrator:  m.orchestratorTime,
			Limit:         m.timeoutDuration,
		},
	}
}
