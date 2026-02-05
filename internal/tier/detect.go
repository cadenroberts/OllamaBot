package tier

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"

	"github.com/fatih/color"
)

// SystemInfo contains detected system information
type SystemInfo struct {
	RAMGB        int       // Total RAM in GB
	OS           string    // Operating system
	Arch         string    // Architecture
	NumCPU       int       // Number of CPUs
	DetectedTier ModelTier // Auto-detected tier
}

// DetectSystem detects system specifications and returns optimal tier
func DetectSystem() SystemInfo {
	// Get total physical memory
	ramGB := getSystemRAM()

	info := SystemInfo{
		RAMGB:  ramGB,
		OS:     runtime.GOOS,
		Arch:   runtime.GOARCH,
		NumCPU: runtime.NumCPU(),
	}

	// Determine tier based on RAM
	info.DetectedTier = detectTierFromRAM(ramGB)

	return info
}

// getSystemRAM returns total system RAM in GB
func getSystemRAM() int {
	// Try to read from /proc/meminfo on Linux
	if runtime.GOOS == "linux" {
		if ram := readLinuxMemInfo(); ram > 0 {
			return ram
		}
	}

	// For macOS, use sysctl
	if runtime.GOOS == "darwin" {
		if ram := readDarwinMemInfo(); ram > 0 {
			return ram
		}
	}

	// Default to 16GB if we can't detect
	// This is a safe middle-ground for most development machines
	return 16
}

// readLinuxMemInfo reads RAM from /proc/meminfo
func readLinuxMemInfo() int {
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return 0
	}

	var memTotal uint64
	_, err = fmt.Sscanf(string(data), "MemTotal: %d kB", &memTotal)
	if err != nil {
		return 0
	}

	return int(memTotal / 1024 / 1024) // Convert KB to GB
}

// readDarwinMemInfo reads RAM on macOS using sysctl command
func readDarwinMemInfo() int {
	// Use sysctl command to get hw.memsize (pure Go, no CGO)
	cmd := exec.Command("sysctl", "-n", "hw.memsize")
	output, err := cmd.Output()
	if err != nil {
		return 0
	}

	// Parse the output (bytes)
	memBytes, err := strconv.ParseInt(strings.TrimSpace(string(output)), 10, 64)
	if err != nil {
		return 0
	}

	// Convert bytes to GB
	return int(memBytes / 1024 / 1024 / 1024)
}

// detectTierFromRAM determines the optimal tier based on available RAM
func detectTierFromRAM(ramGB int) ModelTier {
	switch {
	case ramGB >= 64:
		return TierAdvanced
	case ramGB >= 32:
		return TierPerformance
	case ramGB >= 24:
		return TierBalanced
	case ramGB >= 16:
		return TierCompact
	default:
		return TierMinimal
	}
}

// GetModelForTier returns the coder model variant for a given tier
func GetModelForTier(t ModelTier) ModelVariant {
	if model, ok := CoderModels[t]; ok {
		return model
	}
	// Default to compact tier
	return CoderModels[TierCompact]
}

// PrintSystemInfo prints detected system info with colors
func PrintSystemInfo(info SystemInfo) {
	cyan := color.New(color.FgCyan).SprintFunc()
	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()

	model := GetModelForTier(info.DetectedTier)
	tierInfo := GetTierInfo(info.DetectedTier)

	fmt.Println()
	fmt.Printf("%s System detected:\n", cyan("⚡"))
	fmt.Printf("   RAM: %s\n", green(fmt.Sprintf("%dGB", info.RAMGB)))
	fmt.Printf("   OS:  %s/%s\n", info.OS, info.Arch)
	fmt.Printf("   CPUs: %d\n", info.NumCPU)
	fmt.Println()
	fmt.Printf("%s Selected tier: %s\n", cyan("🎯"), yellow(info.DetectedTier.DisplayName()))
	fmt.Printf("   Model: %s (%s)\n", model.Name, model.Parameters)
	fmt.Printf("   Expected speed: %s tokens/sec\n", tierInfo.TokensPerSecond)
	fmt.Println()
}

// Manager holds the current tier configuration
type Manager struct {
	SystemInfo    SystemInfo
	SelectedTier  ModelTier
	SelectedModel ModelVariant
	OverrideModel string // User-specified model override
}

// NewManager creates a new tier manager with auto-detection
func NewManager() *Manager {
	info := DetectSystem()
	model := GetModelForTier(info.DetectedTier)

	return &Manager{
		SystemInfo:    info,
		SelectedTier:  info.DetectedTier,
		SelectedModel: model,
	}
}

// SetModelOverride sets a user-specified model override
func (m *Manager) SetModelOverride(modelTag string) {
	m.OverrideModel = modelTag
}

// GetActiveModel returns the model to use (override or auto-detected)
func (m *Manager) GetActiveModel() string {
	if m.OverrideModel != "" {
		return m.OverrideModel
	}
	return m.SelectedModel.OllamaTag
}

// GetContextWindow returns the context window for the active model
func (m *Manager) GetContextWindow() int {
	if m.OverrideModel != "" {
		// For overridden models, use a reasonable default
		return 8192
	}
	return m.SelectedModel.ContextWindow
}
