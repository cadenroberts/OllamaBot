# External Tool Integration Guide

This document describes how OllamaBot integrates with external tools such as linters, formatters, and test runners.

## Overview

OllamaBot uses a Unified Tool Registry (UTR) to define canonical tool identifiers. External tools are mapped to these identifiers and executed via the agent's executor.

## Canonical Tools

The following tools are defined for external integration:

- `system.lint`: Runs a linter on a specified path.
- `system.format`: Runs a formatter on a specified path.
- `system.test`: Runs tests on a specified path.

## Implementation Details (Go)

In the Go implementation (`internal/agent/executor.go`), these tools are handled by specialized methods that detect the project's language and invoke the appropriate shell command.

### Language Detection

The executor detects the language based on the file extension:

```go
func detectLanguage(path string) string {
	ext := filepath.Ext(path)
	switch ext {
	case ".go":
		return "go"
	case ".py":
		return "python"
	case ".js", ".jsx":
		return "javascript"
	case ".ts", ".tsx":
		return "typescript"
	default:
		return "unknown"
	}
}
```

### Integration Logic

Each tool maps the detected language to a command:

| Tool | Go | Python | JavaScript/TypeScript |
|------|----|--------|-----------------------|
| `lint` | `go vet` | `pylint` | `eslint` |
| `format` | `go fmt` | `black` | `prettier --write` |
| `test` | `go test -v` | `pytest` | `npm test` |

## Extending Integration

To add support for a new language or tool:

1.  Update `detectLanguage` in `internal/agent/executor.go` to support the new extension.
2.  Add a case to the switch statement in `handleLint`, `handleFormat`, or `handleTest`.
3.  Ensure the external tool is installed in the execution environment.

## Future Considerations

- **Configuration-based tools**: Allow users to override the default commands via `.obotrules` or configuration files.
- **Output parsing**: Implement parsers for linter/test output to provide structured feedback to the agent.
- **Environment management**: Automatically detect and use virtual environments (e.g., `venv`, `npm`) if present.
