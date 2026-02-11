package agent

import (
	"context"
	"fmt"

	"github.com/croberts/obot/internal/ollama"
)

// DelegationResult holds the result of a multi-model delegation.
type DelegationResult struct {
	Model    string
	Response string
	Tokens   int
	Success  bool
}

// DelegateToCoder delegates a coding task to the coder model.
func (a *Agent) DelegateToCoder(ctx context.Context, task string, fileContext string) (*DelegationResult, error) {
	return a.delegateTo(ctx, "coder", task, fileContext,
		"You are a coding specialist. Produce correct, minimal code changes.")
}

// DelegateToResearcher delegates a research query to the researcher model.
func (a *Agent) DelegateToResearcher(ctx context.Context, query string) (*DelegationResult, error) {
	return a.delegateTo(ctx, "researcher", query, "",
		"You are a research specialist. Gather accurate, relevant information.")
}

// DelegateToVision delegates a vision task to the vision model.
func (a *Agent) DelegateToVision(ctx context.Context, task string, imagePath string) (*DelegationResult, error) {
	contextStr := ""
	if imagePath != "" {
		contextStr = fmt.Sprintf("Image path: %s", imagePath)
	}
	return a.delegateTo(ctx, "vision", task, contextStr,
		"You are a vision specialist. Analyze visual content and describe findings.")
}

// delegateTo performs the actual delegation to a model role.
func (a *Agent) delegateTo(ctx context.Context, role string, task string, fileContext string, systemPrompt string) (*DelegationResult, error) {
	if a.client == nil {
		return nil, fmt.Errorf("no ollama client configured")
	}

	// Build prompt
	prompt := task
	if fileContext != "" {
		prompt = fmt.Sprintf("%s\n\nContext:\n%s", task, fileContext)
	}

	messages := []ollama.Message{
		{Role: "system", Content: systemPrompt},
		{Role: "user", Content: prompt},
	}

	response, stats, err := a.client.Chat(ctx, messages)
	if err != nil {
		return &DelegationResult{Model: role, Success: false}, fmt.Errorf("delegation to %s: %w", role, err)
	}

	tokens := 0
	if stats != nil {
		tokens = int(stats.TotalTokens)
	}

	action := Action{
		Type:    ActionDelegate,
		Content: fmt.Sprintf("role=%s tokens=%d", role, tokens),
	}
	a.recordAction(action)

	return &DelegationResult{
		Model:    role,
		Response: response,
		Tokens:   tokens,
		Success:  true,
	}, nil
}
