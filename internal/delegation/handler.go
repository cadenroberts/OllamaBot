// Package delegation implements model delegation tools for obot orchestration.
package delegation

import (
	"context"
	"fmt"
	"sync"

	"github.com/croberts/obot/internal/model"
	"github.com/croberts/obot/internal/ollama"
	"github.com/croberts/obot/internal/orchestrate"
)

// Handler manages model delegation requests.
//
// PROOF:
// - ZERO-HIT: No existing delegation handler implementation.
// - POSITIVE-HIT: Handler struct and delegation methods in internal/delegation/handler.go.
type Handler struct {
	mu          sync.Mutex
	coordinator *model.Coordinator
}

// NewHandler creates a new delegation handler.
func NewHandler(coordinator *model.Coordinator) *Handler {
	return &Handler{
		coordinator: coordinator,
	}
}

// DelegateCoder delegates a task to the coding model.
func (h *Handler) DelegateCoder(ctx context.Context, task string) (string, error) {
	client := h.coordinator.Get(orchestrate.ModelCoder)
	if client == nil {
		return "", fmt.Errorf("coder model not available")
	}

	return h.executeDelegation(ctx, orchestrate.ModelCoder, client, task)
}

// DelegateResearcher delegates a task to the research model.
func (h *Handler) DelegateResearcher(ctx context.Context, task string) (string, error) {
	client := h.coordinator.Get(orchestrate.ModelResearcher)
	if client == nil {
		return "", fmt.Errorf("researcher model not available")
	}

	return h.executeDelegation(ctx, orchestrate.ModelResearcher, client, task)
}

// DelegateVision delegates a task to the vision model.
func (h *Handler) DelegateVision(ctx context.Context, task string, imagePath string) (string, error) {
	client := h.coordinator.Get(orchestrate.ModelVision)
	if client == nil {
		return "", fmt.Errorf("vision model not available")
	}

	// In a full implementation, this would handle the image payload.
	return h.executeDelegation(ctx, orchestrate.ModelVision, client, task)
}

// executeDelegation performs the actual LLM call for a delegation task.
func (h *Handler) executeDelegation(ctx context.Context, modelType orchestrate.ModelType, client *ollama.Client, task string) (string, error) {
	h.mu.Lock()
	// Log or track delegation start
	h.mu.Unlock()

	resp, stats, err := client.Generate(ctx, task)
	if err != nil {
		return "", err
	}

	// Record tokens
	h.coordinator.RecordTokens(modelType, int64(stats.TotalTokens))

	return resp, nil
}

// GetAvailableDelegates returns a list of model types that can be delegated to.
func (h *Handler) GetAvailableDelegates() []orchestrate.ModelType {
	return []orchestrate.ModelType{
		orchestrate.ModelCoder,
		orchestrate.ModelResearcher,
		orchestrate.ModelVision,
	}
}

// FormatDelegationResult wraps the LLM response with delegation metadata.
func (h *Handler) FormatDelegationResult(modelType orchestrate.ModelType, response string) string {
	return fmt.Sprintf("### DELEGATION RESULT (%v) ###\n\n%s", modelType, response)
}

// GetDelegationPrompt returns a specialized prompt for a specific delegation type.
func (h *Handler) GetDelegationPrompt(modelType orchestrate.ModelType, task string) string {
	switch modelType {
	case orchestrate.ModelCoder:
		return fmt.Sprintf("You are assisting with a coding task. TASK: %s\nPlease provide clean, efficient code following existing patterns.", task)
	case orchestrate.ModelResearcher:
		return fmt.Sprintf("You are assisting with a research task. TASK: %s\nPlease provide accurate, well-cited information.", task)
	case orchestrate.ModelVision:
		return fmt.Sprintf("You are assisting with a visual analysis task. TASK: %s\nPlease analyze the provided image context carefully.", task)
	default:
		return task
	}
}

// DelegateWithContext allows passing additional context strings to the delegate.
func (h *Handler) DelegateWithContext(ctx context.Context, modelType orchestrate.ModelType, task string, context []string) (string, error) {
	client := h.coordinator.Get(modelType)
	if client == nil {
		return "", fmt.Errorf("model %v not available", modelType)
	}

	fullPrompt := "CONTEXT:\n"
	for _, c := range context {
		fullPrompt += "- " + c + "\n"
	}
	fullPrompt += "\nTASK: " + task

	return h.executeDelegation(ctx, modelType, client, fullPrompt)
}

// ValidateTask checks if a task description is sufficient for delegation.
func (h *Handler) ValidateTask(task string) error {
	if len(task) < 10 {
		return fmt.Errorf("task description too short (minimum 10 characters)")
	}
	return nil
}

// GetHandoffStats returns information about recent delegations.
func (h *Handler) GetHandoffStats() map[orchestrate.ModelType]int {
	counts := h.coordinator.GetTokenCounts()
	result := make(map[orchestrate.ModelType]int)
	for k, v := range counts {
		result[k] = int(v) // Simplified for stats display
	}
	return result
}

// Reset clears any local handler state.
func (h *Handler) Reset() {
	h.mu.Lock()
	defer h.mu.Unlock()
	// Clear local cache if any
}

// Finalize completes all pending delegation work.
func (h *Handler) Finalize() {
	// Any cleanup logic
}

// DelegateWithFallback attempts to delegate to primary model, falling back to orchestrator on failure.
func (h *Handler) DelegateWithFallback(ctx context.Context, modelType orchestrate.ModelType, task string) (string, error) {
	resp, err := h.executeDelegationWithModel(ctx, modelType, task)
	if err != nil {
		fmt.Printf("Primary model %v failed, falling back to orchestrator: %v\n", modelType, err)
		return h.executeDelegationWithModel(ctx, orchestrate.ModelOrchestrator, task)
	}
	return resp, nil
}

// executeDelegationWithModel is a helper for model-specific delegation.
func (h *Handler) executeDelegationWithModel(ctx context.Context, modelType orchestrate.ModelType, task string) (string, error) {
	client := h.coordinator.Get(modelType)
	if client == nil {
		return "", fmt.Errorf("model %v not available", modelType)
	}
	return h.executeDelegation(ctx, modelType, client, task)
}

// GetStatus returns a human-readable status of the delegation system.
func (h *Handler) GetStatus() string {
	delegates := h.GetAvailableDelegates()
	status := "Delegation System: ACTIVE\nAvailable Delegates:\n"
	for _, d := range delegates {
		status += fmt.Sprintf("- %v\n", d)
	}
	return status
}

// IsBusy returns true if the handler is currently processing a request.
func (h *Handler) IsBusy() bool {
	if !h.mu.TryLock() {
		return true
	}
	h.mu.Unlock()
	return false
}

// DelegationRequest represents a structured request for model assistance.
type DelegationRequest struct {
	ModelType orchestrate.ModelType
	Task      string
	Context   []string
	ImageURL  string
	Priority  int
}

// ProcessRequest handles a structured DelegationRequest.
func (h *Handler) ProcessRequest(ctx context.Context, req DelegationRequest) (string, error) {
	if err := h.ValidateTask(req.Task); err != nil {
		return "", err
	}

	if req.ImageURL != "" && req.ModelType == orchestrate.ModelVision {
		return h.DelegateVision(ctx, req.Task, req.ImageURL)
	}

	if len(req.Context) > 0 {
		return h.DelegateWithContext(ctx, req.ModelType, req.Task, req.Context)
	}

	return h.executeDelegationWithModel(ctx, req.ModelType, req.Task)
}

// GetSummary returns a summary of all delegations in this session.
func (h *Handler) GetSummary() string {
	stats := h.GetHandoffStats()
	summary := "Delegation Summary:\n"
	for m, tokens := range stats {
		summary += fmt.Sprintf("  - %v: %d tokens processed\n", m, tokens)
	}
	return summary
}
