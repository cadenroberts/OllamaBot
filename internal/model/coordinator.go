// Package model implements multi-model coordination for obot orchestration.
package model

import (
	"context"
	"fmt"
	"sync"

	"github.com/croberts/obot/internal/ollama"
	"github.com/croberts/obot/internal/orchestrate"
)

// Coordinator manages model selection and coordination.
type Coordinator struct {
	mu sync.Mutex

	// Ollama client
	client *ollama.Client

	// Model configurations
	models map[orchestrate.ModelType]*ModelConfig

	// Active model
	activeModel orchestrate.ModelType

	// Ollama endpoint
	ollamaURL string

	// Statistics
	tokenCounts map[orchestrate.ModelType]int64
}

// ModelConfig contains configuration for a specific model
type ModelConfig struct {
	Type     orchestrate.ModelType
	Name     string // Ollama model name (e.g., "qwen3:latest")
	SystemPrompt string
	Temperature  float64
	MaxTokens    int
}

// DefaultModels returns the default model configurations
func DefaultModels() map[orchestrate.ModelType]*ModelConfig {
	return map[orchestrate.ModelType]*ModelConfig{
		orchestrate.ModelOrchestrator: {
			Type:        orchestrate.ModelOrchestrator,
			Name:        "qwen3:latest",
			Temperature: 0.3, // Lower temperature for more consistent orchestration
			MaxTokens:   4096,
			SystemPrompt: `You are the orchestrator for obot, a professional-grade agentic system.
Your role is TOOLER ONLY - you select schedules and processes but do NOT perform agent actions.
You cannot: create files, edit files, run commands, or generate code.
You can only: select schedules (1-5), select processes (1-3), terminate schedules, terminate prompt.

Navigation rules (STRICT):
- From P1: Can go to P1 or P2
- From P2: Can go to P1, P2, or P3
- From P3: Can go to P2, P3, or terminate schedule
- Schedule can ONLY terminate after P3

Prompt termination requires:
1. All 5 schedules run at least once
2. Production was the last terminated schedule
3. You can justify that no further improvement is possible`,
		},
		orchestrate.ModelCoder: {
			Type:        orchestrate.ModelCoder,
			Name:        "qwen2.5-coder:14b",
			Temperature: 0.7,
			MaxTokens:   8192,
			SystemPrompt: `You are the coding agent for obot orchestration.
You execute processes by performing file operations and running commands.
You are an EXECUTOR ONLY - you cannot make orchestration decisions.
You cannot: select schedules, navigate processes, terminate schedules, terminate prompt.
You can only: create/edit/delete files, create/delete directories, run commands.

Report your actions clearly using the format:
- Created {filename}
- Edited {filename} at lines {ranges}
- Deleted {filename}
- Ran {command} (exit {code})

Signal completion with: {ProcessName} Completed`,
		},
		orchestrate.ModelResearcher: {
			Type:        orchestrate.ModelResearcher,
			Name:        "nomic-embed-text",
			Temperature: 0.5,
			MaxTokens:   4096,
			SystemPrompt: `You are the researcher agent for obot orchestration.
You execute Knowledge schedule processes: Research, Crawl, Retrieve.
Focus on gathering accurate, relevant information.
Validate sources and structure information for use in other schedules.`,
		},
		orchestrate.ModelVision: {
			Type:        orchestrate.ModelVision,
			Name:        "llava:13b",
			Temperature: 0.5,
			MaxTokens:   4096,
			SystemPrompt: `You are the vision agent for obot orchestration.
You analyze UI components during the Production schedule's Harmonize process.
Focus on visual consistency, accessibility, and production readiness.
Report specific issues and recommendations for UI polish.`,
		},
	}
}

// NewCoordinator creates a new model coordinator
func NewCoordinator(client *ollama.Client) *Coordinator {
	url := ""
	if client != nil {
		url = client.BaseURL()
	}
	return &Coordinator{
		client:      client,
		models:      DefaultModels(),
		ollamaURL:   url,
		tokenCounts: make(map[orchestrate.ModelType]int64),
	}
}

// SetModel overrides a model configuration
func (c *Coordinator) SetModel(modelType orchestrate.ModelType, name string) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if config, ok := c.models[modelType]; ok {
		config.Name = name
	}
}

// GetModel returns the model configuration for a type
func (c *Coordinator) GetModel(modelType orchestrate.ModelType) *ModelConfig {
	c.mu.Lock()
	defer c.mu.Unlock()

	if config, ok := c.models[modelType]; ok {
		// Return a copy
		copy := *config
		return &copy
	}
	return nil
}

// SelectModelForSchedule returns the appropriate model(s) for a schedule
func (c *Coordinator) SelectModelForSchedule(scheduleID orchestrate.ScheduleID) []orchestrate.ModelType {
	switch scheduleID {
	case orchestrate.ScheduleKnowledge:
		return []orchestrate.ModelType{orchestrate.ModelResearcher}
	case orchestrate.ScheduleProduction:
		return []orchestrate.ModelType{orchestrate.ModelCoder, orchestrate.ModelVision}
	default:
		return []orchestrate.ModelType{orchestrate.ModelCoder}
	}
}

// SelectModelForProcess returns the model for a specific process
func (c *Coordinator) SelectModelForProcess(scheduleID orchestrate.ScheduleID, processID orchestrate.ProcessID) orchestrate.ModelType {
	// Production Harmonize uses vision model alongside coder
	if scheduleID == orchestrate.ScheduleProduction && processID == orchestrate.Process3 {
		return orchestrate.ModelVision
	}

	// Knowledge schedule always uses researcher
	if scheduleID == orchestrate.ScheduleKnowledge {
		return orchestrate.ModelResearcher
	}

	// Default to coder
	return orchestrate.ModelCoder
}

// RecordTokens records token usage for a model
func (c *Coordinator) RecordTokens(modelType orchestrate.ModelType, tokens int64) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.tokenCounts[modelType] += tokens
}

// GetTokenCounts returns token counts by model
func (c *Coordinator) GetTokenCounts() map[orchestrate.ModelType]int64 {
	c.mu.Lock()
	defer c.mu.Unlock()

	result := make(map[orchestrate.ModelType]int64)
	for k, v := range c.tokenCounts {
		result[k] = v
	}
	return result
}

// Handoff transfers control between models
type Handoff struct {
	From     orchestrate.ModelType
	To       orchestrate.ModelType
	Schedule orchestrate.ScheduleID
	Process  orchestrate.ProcessID
	Context  string // Context to pass
}

// HandoffProtocol executes a model handoff
func (c *Coordinator) HandoffProtocol(ctx context.Context, handoff Handoff) error {
	c.mu.Lock()
	c.activeModel = handoff.To
	c.mu.Unlock()

	// Log the handoff
	// In a real implementation, this would manage model lifecycle
	return nil
}

// GetActiveModel returns the currently active model
func (c *Coordinator) GetActiveModel() orchestrate.ModelType {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.activeModel
}

// ValidateModels checks if all required models are available
func (c *Coordinator) ValidateModels(ctx context.Context) error {
	// In a real implementation, this would check with Ollama
	for modelType, config := range c.models {
		if config.Name == "" {
			return fmt.Errorf("model %s not configured", modelType)
		}
	}
	return nil
}

// GetModelForSchedule returns the primary model name for a schedule
func (c *Coordinator) GetModelForSchedule(scheduleID orchestrate.ScheduleID) string {
	modelType := c.SelectModelForProcess(scheduleID, orchestrate.Process1)
	c.mu.Lock()
	defer c.mu.Unlock()
	
	if config, ok := c.models[modelType]; ok {
		return config.Name
	}
	return "qwen2.5-coder:14b"
}

// GetSystemPrompt returns the system prompt for a schedule/process combination
func (c *Coordinator) GetSystemPrompt(scheduleID orchestrate.ScheduleID, processID orchestrate.ProcessID) string {
	modelType := c.SelectModelForProcess(scheduleID, processID)
	c.mu.Lock()
	defer c.mu.Unlock()
	
	if config, ok := c.models[modelType]; ok {
		return config.SystemPrompt
	}
	return ""
}

// SelectNextSchedule uses the orchestrator model to decide the next schedule
func (c *Coordinator) SelectNextSchedule(ctx context.Context, orch *orchestrate.Orchestrator) (orchestrate.ScheduleID, bool, error) {
	stats := orch.GetStats()
	
	// Check if we can and should terminate
	if orch.CanTerminatePrompt() {
		// Use orchestrator model to decide - for now, simple heuristic
		// In full implementation, this would call the LLM
		return 0, true, nil
	}
	
	// Simple round-robin for demonstration
	// In full implementation, the orchestrator LLM would decide
	for schedID := orchestrate.ScheduleKnowledge; schedID <= orchestrate.ScheduleProduction; schedID++ {
		if stats.SchedulingsByID[schedID] == 0 {
			return schedID, false, nil
		}
	}
	
	// If all schedules have run once, return to Production
	return orchestrate.ScheduleProduction, false, nil
}

// SelectNextProcess uses the model to decide the next process
func (c *Coordinator) SelectNextProcess(ctx context.Context, orch *orchestrate.Orchestrator, schedID orchestrate.ScheduleID, lastProc orchestrate.ProcessID) (orchestrate.ProcessID, bool, error) {
	// Enforce navigation rules
	switch lastProc {
	case orchestrate.Process1:
		// From P1: go to P2
		return orchestrate.Process2, false, nil
	case orchestrate.Process2:
		// From P2: go to P3
		return orchestrate.Process3, false, nil
	case orchestrate.Process3:
		// From P3: terminate schedule
		return 0, true, nil
	default:
		return orchestrate.Process1, false, nil
	}
}
