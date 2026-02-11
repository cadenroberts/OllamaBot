// Package planner implements pre-orchestration planning logic.
package planner

import (
	"context"
	"fmt"
	"strings"

	"github.com/croberts/obot/internal/ollama"
)

// TaskDecomposer breaks down complex prompts into manageable subtasks.
type TaskDecomposer struct {
	client *ollama.Client
	model  string
}

// Subtask represents a single unit of work derived from a larger prompt.
type Subtask struct {
	ID          string `json:"id"`
	Description string `json:"description"`
	Priority    int    `json:"priority"`
	DependsOn   []string `json:"depends_on,omitempty"`
}

// NewTaskDecomposer creates a new decomposer.
func NewTaskDecomposer(client *ollama.Client, model string) *TaskDecomposer {
	if model == "" {
		model = "qwen3:32b" // Default orchestrator model
	}
	return &TaskDecomposer{
		client: client,
		model:  model,
	}
}

// Decompose analyzes a prompt and returns a list of subtasks.
func (d *TaskDecomposer) Decompose(ctx context.Context, prompt string) ([]Subtask, error) {
	if d.client == nil {
		// Stub implementation for when model is not available
		return []Subtask{
			{ID: "T1", Description: "Initial analysis of: " + prompt, Priority: 1},
		}, nil
	}

	systemPrompt := `You are a Technical Project Manager. 
Break down the following user prompt into a structured list of technical subtasks.
Provide the output in the following format:
ID: [T1, T2, ...]
DESCRIPTION: [What needs to be done]
PRIORITY: [1-5]
DEPENDS_ON: [IDs of dependencies or 'None']`

	resp, _, err := d.client.Generate(ctx, systemPrompt+"\n\nUser Prompt: "+prompt)
	if err != nil {
		return nil, fmt.Errorf("decomposition failed: %w", err)
	}

	return d.parseDecomposition(resp), nil
}

// parseDecomposition parses the LLM response into Subtask objects.
func (d *TaskDecomposer) parseDecomposition(resp string) []Subtask {
	subtasks := make([]Subtask, 0)
	lines := strings.Split(resp, "\n")
	
	var current *Subtask
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		upper := strings.ToUpper(line)
		if strings.HasPrefix(upper, "ID:") {
			if current != nil {
				subtasks = append(subtasks, *current)
			}
			current = &Subtask{ID: strings.TrimSpace(line[3:])}
		} else if current != nil {
			if strings.HasPrefix(upper, "DESCRIPTION:") {
				current.Description = strings.TrimSpace(line[12:])
			} else if strings.HasPrefix(upper, "PRIORITY:") {
				fmt.Sscanf(strings.TrimSpace(line[9:]), "%d", &current.Priority)
			} else if strings.HasPrefix(upper, "DEPENDS_ON:") {
				deps := strings.TrimSpace(line[11:])
				if strings.ToLower(deps) != "none" {
					current.DependsOn = strings.Split(deps, ",")
					for i := range current.DependsOn {
						current.DependsOn[i] = strings.TrimSpace(current.DependsOn[i])
					}
				}
			}
		}
	}

	if current != nil {
		subtasks = append(subtasks, *current)
	}

	return subtasks
}
