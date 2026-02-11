// Package tools implements orchestration tools.
package tools

import (
	"fmt"
	"os/exec"
	"runtime"
	"time"
)

// TakeScreenshot captures the screen and saves it to the specified path.
// It supports macOS (screencapture) and Linux (scrot or import).
//
// PROOF:
// - ZERO-HIT: No existing screenshot implementation.
// - POSITIVE-HIT: TakeScreenshot with macOS and Linux support in internal/tools/screenshot.go.
func TakeScreenshot(outputPath string) error {
	switch runtime.GOOS {
	case "darwin":
		// macOS: use screencapture
		cmd := exec.Command("screencapture", "-x", outputPath) // -x: quiet mode
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("screencapture failed: %w", err)
		}
		return nil

	case "linux":
		// Linux: try scrot first, then fallback to ImageMagick 'import'
		if err := exec.Command("scrot", outputPath).Run(); err == nil {
			return nil
		}
		
		// Fallback to ImageMagick
		cmd := exec.Command("import", "-window", "root", outputPath)
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("linux screenshot failed (scrot and import both failed): %w", err)
		}
		return nil

	case "windows":
		// Windows: not explicitly requested in spec but good to have if possible
		// Usually requires PowerShell or third-party tool. 
		// Spec only mentioned macOS and Linux.
		return fmt.Errorf("screenshot tool not implemented for windows")

	default:
		return fmt.Errorf("unsupported platform for screenshot: %s", runtime.GOOS)
	}
}

// TakeWindowScreenshot captures a specific window.
// On macOS, it prompts the user to select a window.
func TakeWindowScreenshot(outputPath string) error {
	if runtime.GOOS != "darwin" {
		return fmt.Errorf("window screenshot currently only supported on macOS")
	}

	cmd := exec.Command("screencapture", "-i", outputPath) // -i: interactive mode
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("window capture failed: %w", err)
	}
	return nil
}

// IsScreenshotToolAvailable checks if the necessary platform tools are installed.
func IsScreenshotToolAvailable() bool {
	switch runtime.GOOS {
	case "darwin":
		_, err := exec.LookPath("screencapture")
		return err == nil
	case "linux":
		if _, err := exec.LookPath("scrot"); err == nil {
			return true
		}
		_, err := exec.LookPath("import")
		return err == nil
	default:
		return false
	}
}

// GetPlatformTools returns the name of the tools used for screenshots on the current platform.
func GetPlatformTools() []string {
	switch runtime.GOOS {
	case "darwin":
		return []string{"screencapture"}
	case "linux":
		return []string{"scrot", "import"}
	case "windows":
		return []string{}
	default:
		return []string{}
	}
}

// GetDefaultScreenshotPath returns a default path for saving screenshots.
func GetDefaultScreenshotPath() string {
	timestamp := fmt.Sprintf("%d", time.Now().Unix())
	return fmt.Sprintf("screenshot_%s.png", timestamp)
}
