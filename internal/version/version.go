package version

import (
	"fmt"
	"runtime"
	"runtime/debug"
	"strings"
)

type Info struct {
	Version       string
	Commit        string
	Date          string
	BuiltBy       string
	GoVersion     string
	OS            string
	Arch          string
	Platform      string
	PlatformHuman string
	ModulePath    string
	VCSModified   bool
}

var state = Info{
	Version: "dev",
	Commit:  "none",
	Date:    "unknown",
	BuiltBy: "unknown",
}

func Set(info Info) {
	state = info
}

func Get() Info {
	info := state

	if info.Version == "" {
		info.Version = "dev"
	}
	if info.Commit == "" {
		info.Commit = "none"
	}
	if info.Date == "" {
		info.Date = "unknown"
	}
	if info.BuiltBy == "" {
		info.BuiltBy = "unknown"
	}

	info.OS = runtime.GOOS
	info.Arch = runtime.GOARCH
	info.Platform = fmt.Sprintf("%s/%s", info.OS, info.Arch)
	info.PlatformHuman = platformLabel(info.OS, info.Arch)
	info.GoVersion = runtime.Version()

	if bi, ok := debug.ReadBuildInfo(); ok {
		if info.GoVersion == "" || info.GoVersion == "unknown" {
			info.GoVersion = bi.GoVersion
		}
		if info.ModulePath == "" {
			info.ModulePath = bi.Main.Path
		}
		for _, setting := range bi.Settings {
			switch setting.Key {
			case "vcs.revision":
				if info.Commit == "none" || info.Commit == "unknown" {
					info.Commit = setting.Value
				}
			case "vcs.time":
				if info.Date == "unknown" {
					info.Date = setting.Value
				}
			case "vcs.modified":
				info.VCSModified = setting.Value == "true"
			}
		}
	}

	return info
}

func Short() string {
	info := Get()
	commit := shortCommit(info.Commit)
	platform := info.PlatformHuman
	if commit != "" {
		return fmt.Sprintf("%s (%s, %s)", info.Version, platform, commit)
	}
	return fmt.Sprintf("%s (%s)", info.Version, platform)
}

func Full() string {
	info := Get()
	commit := info.Commit
	if commit == "" {
		commit = "unknown"
	}
	if info.VCSModified {
		commit = commit + " (modified)"
	}

	lines := []string{
		fmt.Sprintf("obot %s", info.Version),
		fmt.Sprintf("commit:   %s", commit),
		fmt.Sprintf("built:    %s", info.Date),
		fmt.Sprintf("platform: %s", info.PlatformHuman),
		fmt.Sprintf("go:       %s", info.GoVersion),
	}
	if info.BuiltBy != "" && info.BuiltBy != "unknown" {
		lines = append(lines, fmt.Sprintf("built by: %s", info.BuiltBy))
	}
	if info.ModulePath != "" {
		lines = append(lines, fmt.Sprintf("module:   %s", info.ModulePath))
	}

	return strings.Join(lines, "\n") + "\n"
}

func shortCommit(commit string) string {
	if commit == "" || commit == "none" || commit == "unknown" {
		return ""
	}
	if len(commit) > 12 {
		return commit[:12]
	}
	return commit
}

func platformLabel(goos, goarch string) string {
	if goos == "darwin" {
		switch goarch {
		case "arm64":
			return "darwin/arm64 (Apple Silicon)"
		case "amd64":
			return "darwin/amd64 (Intel)"
		}
	}
	return fmt.Sprintf("%s/%s", goos, goarch)
}
