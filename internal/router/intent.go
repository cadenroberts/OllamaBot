// Package router implements intent-based routing for multi-model delegation.
// Port of IDE IntentRouter to Go.
package router

import (
	"strings"
)

// Intent classifies the type of task.
type Intent string

const (
	IntentCoding   Intent = "coding"
	IntentResearch Intent = "research"
	IntentWriting  Intent = "writing"
	IntentVision   Intent = "vision"
	IntentGeneral  Intent = "general"
)

// IntentKeywords maps intents to trigger keywords.
var IntentKeywords = map[Intent][]string{
	IntentCoding: {
		"fix", "implement", "refactor", "optimize", "debug", "add", "remove",
		"create", "delete", "edit", "rename", "move", "copy", "build", "test",
		"lint", "format", "compile", "deploy", "migrate", "update", "upgrade",
		"patch", "merge", "rebase", "function", "class", "method", "variable",
		"import", "export", "module", "package", "dependency", "api", "endpoint",
		"route", "handler", "middleware", "model", "schema", "database", "query",
		"error", "bug", "issue", "crash", "panic", "exception",
	},
	IntentResearch: {
		"what is", "explain", "compare", "research", "find", "search", "look up",
		"how does", "why does", "when did", "documentation", "reference", "guide",
		"tutorial", "example", "best practice", "standard", "specification",
		"architecture", "design pattern", "algorithm", "data structure",
	},
	IntentWriting: {
		"write", "document", "summarize", "describe", "readme", "changelog",
		"comment", "annotate", "note", "report", "review", "analysis",
		"proposal", "specification", "plan",
	},
	IntentVision: {
		"screenshot", "image", "picture", "photo", "visual", "ui", "layout",
		"design", "mockup", "wireframe", "analyze image", "describe image",
		"extract text", "ocr",
	},
}

// IntentRouter classifies task intent from keywords.
type IntentRouter struct {
	keywords map[Intent][]string
}

// NewIntentRouter creates a new intent router with default keywords.
func NewIntentRouter() *IntentRouter {
	return &IntentRouter{
		keywords: IntentKeywords,
	}
}

// Classify determines the intent of a task description.
func (r *IntentRouter) Classify(task string) Intent {
	lower := strings.ToLower(task)

	scores := make(map[Intent]int)
	for intent, words := range r.keywords {
		for _, word := range words {
			if strings.Contains(lower, word) {
				scores[intent]++
			}
		}
	}

	// Find highest scoring intent
	bestIntent := IntentGeneral
	bestScore := 0
	for intent, score := range scores {
		if score > bestScore {
			bestScore = score
			bestIntent = intent
		}
	}

	return bestIntent
}

// SelectModelRole returns the model role name for a given intent.
func (r *IntentRouter) SelectModelRole(intent Intent) string {
	switch intent {
	case IntentCoding:
		return "coder"
	case IntentResearch:
		return "researcher"
	case IntentVision:
		return "vision"
	case IntentWriting:
		return "coder" // writing tasks use the coder model
	default:
		return "coder"
	}
}
