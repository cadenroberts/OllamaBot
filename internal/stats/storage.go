package stats

import (
	"encoding/json"
	"os"
	"path/filepath"
	"time"
)

// StoredStats is the JSON-serializable format for stats
type StoredStats struct {
	TotalInputTokens  int    `json:"total_input_tokens"`
	TotalOutputTokens int    `json:"total_output_tokens"`
	TotalInferences   int    `json:"total_inferences"`
	FilesFixes        int    `json:"files_fixed"`
	Sessions          int    `json:"sessions"`
	FirstUse          string `json:"first_use"`
	LastUse           string `json:"last_use"`
	TotalTimeNs       int64  `json:"total_inference_time_ns"`
	FastestNs         int64  `json:"fastest_inference_ns"`
	SlowestNs         int64  `json:"slowest_inference_ns"`
}

// getStatsPath returns the path to the stats file
func getStatsPath() string {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		homeDir = "."
	}
	return filepath.Join(homeDir, ".config", "obot", "stats.json")
}

// Save persists the tracker data to disk
func (t *Tracker) Save() error {
	t.mu.RLock()
	defer t.mu.RUnlock()

	stored := StoredStats{
		TotalInputTokens:  t.data.TotalInputTokens,
		TotalOutputTokens: t.data.TotalOutputTokens,
		TotalInferences:   t.data.TotalInferences,
		FilesFixes:        t.data.FilesFixes,
		Sessions:          t.data.Sessions,
		FirstUse:          t.data.FirstUse.Format(time.RFC3339),
		LastUse:           t.data.LastUse.Format(time.RFC3339),
		TotalTimeNs:       int64(t.data.TotalInferenceTime),
		FastestNs:         int64(t.data.FastestInference),
		SlowestNs:         int64(t.data.SlowestInference),
	}

	data, err := json.MarshalIndent(stored, "", "  ")
	if err != nil {
		return err
	}

	// Ensure directory exists
	statsPath := getStatsPath()
	if err := os.MkdirAll(filepath.Dir(statsPath), 0755); err != nil {
		return err
	}

	return os.WriteFile(statsPath, data, 0644)
}

// Load loads the tracker data from disk
func (t *Tracker) Load() error {
	t.mu.Lock()
	defer t.mu.Unlock()

	statsPath := getStatsPath()
	data, err := os.ReadFile(statsPath)
	if err != nil {
		if os.IsNotExist(err) {
			// No existing stats, start fresh
			return nil
		}
		return err
	}

	var stored StoredStats
	if err := json.Unmarshal(data, &stored); err != nil {
		return err
	}

	// Parse times
	firstUse, _ := time.Parse(time.RFC3339, stored.FirstUse)
	lastUse, _ := time.Parse(time.RFC3339, stored.LastUse)

	// Apply loaded data
	t.data.TotalInputTokens = stored.TotalInputTokens
	t.data.TotalOutputTokens = stored.TotalOutputTokens
	t.data.TotalInferences = stored.TotalInferences
	t.data.FilesFixes = stored.FilesFixes
	t.data.Sessions = stored.Sessions + 1 // Increment session count
	t.data.FirstUse = firstUse
	t.data.LastUse = lastUse
	t.data.TotalInferenceTime = time.Duration(stored.TotalTimeNs)
	t.data.FastestInference = time.Duration(stored.FastestNs)
	t.data.SlowestInference = time.Duration(stored.SlowestNs)

	// Update session start
	t.data.SessionStart = time.Now()

	return nil
}

// GetStatsFilePath returns the path to the stats file
func GetStatsFilePath() string {
	return getStatsPath()
}
