# Patchset Summary

## Baseline Snapshot

- **Branch:** main
- **HEAD:** 6b3162e7f3a199e1050c3e628984eb2400ca7b96
- **Tracked files:** 3,477
- **Primary entry points:**
  - Go CLI: `cmd/obot/main.go` -> `internal/cli/root.go` (`cli.Execute()`)
  - Swift IDE: `Sources/OllamaBotApp.swift` (SwiftUI `@main`)
  - Build: `make build` (Go), `swift build` (Swift)
- **Build:** `make build` produces `bin/obot`. Version injection via ldflags.
- **Tests:** 38/38 Go packages pass. Swift tests exist in `Tests/` (2 files).
- **Run:** Requires a running Ollama instance at `http://localhost:11434`.
