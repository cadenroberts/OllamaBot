// Package errs defines hardcoded error messages for OllamaBot.
package errs

import "fmt"

// HardcodedMessages maps error codes to pre-defined user-friendly messages.
// These are used by the suspension handler to provide consistent, helpful feedback.
var HardcodedMessages = map[ErrorCode]string{
	ErrOllamaUnavailable: "Ollama is not running. Start Ollama with: ollama serve",
	ErrFileSystemAccess:  "Disk space exhausted. Free space required: %s",
}

// GetHardcodedMessage returns a hardcoded message for the given error code,
// optionally formatting it with provided arguments.
func GetHardcodedMessage(code ErrorCode, args ...interface{}) string {
	if msg, ok := HardcodedMessages[code]; ok {
		if len(args) > 0 {
			return fmt.Sprintf(msg, args...)
		}
		return msg
	}
	return ""
}

// IsHardcoded returns true if the error code has a hardcoded message.
func IsHardcoded(code ErrorCode) bool {
	_, ok := HardcodedMessages[code]
	return ok
}
