package agent

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/croberts/obot/internal/ollama"
	"github.com/croberts/obot/internal/orchestrate"
)

// DelegationRequest represents a request to delegate a task to another model.
type DelegationRequest struct {
	Role         string `json:"role"`
	Task         string `json:"task"`
	Context      string `json:"context,omitempty"`
	SystemPrompt string `json:"system_prompt,omitempty"`
}

// DelegationResponse represents the response from a delegated task.
type DelegationResponse struct {
	Role     string `json:"role"`
	Response string `json:"response"`
	Tokens   int64  `json:"tokens"`
	Success  bool   `json:"success"`
	Error    string `json:"error,omitempty"`
}

// DelegateTask delegates a task to a specific model role.
// This is the core implementation for agent-side delegation.
func (a *Agent) DelegateTask(ctx context.Context, req DelegationRequest) (*DelegationResponse, error) {
	if a.models == nil {
		return nil, fmt.Errorf("model coordinator not initialized")
	}

	// Determine model client based on role
	var client *ollama.Client
	var systemPrompt string

	role := strings.ToLower(req.Role)
	switch role {
	case "coder":
		client = a.models.Get(orchestrate.ModelCoder)
		systemPrompt = "You are a coding specialist. Produce correct, minimal code changes."
	case "researcher":
		client = a.models.Get(orchestrate.ModelResearcher)
		systemPrompt = "You are a research specialist. Gather accurate, relevant information."
	case "vision":
		client = a.models.Get(orchestrate.ModelVision)
		systemPrompt = "You are a vision specialist. Analyze visual content and describe findings."
	case "orchestrator":
		client = a.models.Get(orchestrate.ModelOrchestrator)
		systemPrompt = "You are an orchestration specialist. Help with high-level planning and coordination."
	default:
		// Try to find a client for the role anyway, but use the provided system prompt or a generic one
		client = a.models.Get(orchestrate.ModelType(role))
		systemPrompt = "You are a specialist in " + role + "."
	}

	if client == nil {
		return &DelegationResponse{
			Role:    role,
			Success: false,
			Error:   fmt.Sprintf("no client found for role: %s", role),
		}, fmt.Errorf("no client found for role: %s", role)
	}

	// Override system prompt if provided in request
	if req.SystemPrompt != "" {
		systemPrompt = req.SystemPrompt
	}

	// Build the messages for the chat
	messages := []ollama.Message{
		{Role: "system", Content: systemPrompt},
		{Role: "user", Content: req.Task},
	}

	// If context is provided, prepend it to the user task or add as a separate message
	if req.Context != "" {
		messages[1].Content = fmt.Sprintf("Context:\n%s\n\nTask:\n%s", req.Context, req.Task)
	}

	// Execute the delegation
	resp, stats, err := client.Chat(ctx, messages)
	if err != nil {
		return &DelegationResponse{
			Role:    role,
			Success: false,
			Error:   err.Error(),
		}, err
	}

	tokens := int64(0)
	if stats != nil {
		tokens = int64(stats.TotalTokens)
	}

	return &DelegationResponse{
		Role:     role,
		Response: resp,
		Tokens:   tokens,
		Success:  true,
	}, nil
}

// handleDelegate (internal) is called by executeAction to process ActionDelegate.
func (a *Agent) handleDelegate(ctx context.Context, action *Action) error {
	var req DelegationRequest
	
	// Content can be a simple string (task for default researcher) or JSON
	if strings.HasPrefix(strings.TrimSpace(action.Content), "{") {
		if err := json.Unmarshal([]byte(action.Content), &req); err != nil {
			// Fallback to treating it as a raw task if JSON parsing fails
			req = DelegationRequest{
				Role: "researcher",
				Task: action.Content,
			}
		}
	} else {
		// Default to researcher role for raw text delegation
		req = DelegationRequest{
			Role: "researcher",
			Task: action.Content,
		}
	}

	// Ensure role is set
	if req.Role == "" {
		req.Role = "researcher"
	}

	// Perform the delegation
	resp, err := a.DelegateTask(ctx, req)
	
	// Record the outcome in the action metadata
	if err != nil {
		action.Metadata["delegation_error"] = err.Error()
		return err
	}

	action.Metadata["delegation_role"] = resp.Role
	action.Metadata["delegation_tokens"] = resp.Tokens
	action.Metadata["delegation_success"] = resp.Success
	
	// The result is stored in the action output for the agent to see
	action.Output = resp.Response

	return nil
}

// Additional helper tools to expose delegation as distinct methods if needed

// DelegateToCoder delegates a specific coding task.
func (a *Agent) DelegateToCoder(ctx context.Context, task string, context string) (*DelegationResponse, error) {
	return a.DelegateTask(ctx, DelegationRequest{
		Role:    "coder",
		Task:    task,
		Context: context,
	})
}

// DelegateToResearcher delegates a specific research task.
func (a *Agent) DelegateToResearcher(ctx context.Context, query string) (*DelegationResponse, error) {
	return a.DelegateTask(ctx, DelegationRequest{
		Role: "researcher",
		Task: query,
	})
}

// DelegateToVision delegates a task requiring visual analysis.
func (a *Agent) DelegateToVision(ctx context.Context, task string, imageContext string) (*DelegationResponse, error) {
	return a.DelegateTask(ctx, DelegationRequest{
		Role:    "vision",
		Task:    task,
		Context: imageContext,
	})
}

// DelegateToOrchestrator delegates a task back to the orchestrator for high-level guidance.
func (a *Agent) DelegateToOrchestrator(ctx context.Context, task string) (*DelegationResponse, error) {
	return a.DelegateTask(ctx, DelegationRequest{
		Role: "orchestrator",
		Task: task,
	})
}

// End of delegation tools.
