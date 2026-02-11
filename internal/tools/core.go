// Package tools provides utility functions for various agent tools.
package tools

import (
	"context"
	"fmt"
	"strings"
)

// Think allows the agent to express internal reasoning without performing actions.
func Think(thought string) string {
	// Simply return the thought string. In a real implementation, 
	// this might be logged or displayed specially in the UI.
	return strings.TrimSpace(thought)
}

// Complete returns the signal string used to indicate process completion.
func Complete() string {
	return "COMPLETE"
}

// AskUser is a placeholder for requesting human intervention.
// Real implementation should route through the consultation handler.
func AskUser(ctx context.Context, question string) (string, error) {
	// For now, return an error indicating it should be handled via consultation package.
	return "", fmt.Errorf("AskUser must be handled via the consultation package")
}

// Note formats a string as a persistent session note.
func Note(content string) string {
	return strings.TrimSpace(content)
}
