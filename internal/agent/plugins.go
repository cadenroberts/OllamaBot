package agent

import (
	"context"
)

// Plugin represents an agent plugin that can hook into the execution lifecycle.
// Plugins allow extending the agent's functionality without modifying its core logic.
type Plugin interface {
	// Name returns the unique name of the plugin.
	Name() string

	// OnBeforeAction is called before an action is executed.
	// If it returns an error, the action execution is aborted.
	OnBeforeAction(ctx context.Context, action *Action) error

	// OnAfterAction is called after an action has been executed.
	OnAfterAction(ctx context.Context, action *Action) error

	// OnBeforeExecute is called before the agent begins executing a process.
	OnBeforeExecute(ctx context.Context, schedule string, process string) error

	// OnAfterExecute is called after the agent has finished executing a process.
	OnAfterExecute(ctx context.Context, schedule string, process string, err error) error
}

// BasePlugin provides a default implementation for the Plugin interface.
// Other plugins can embed BasePlugin to only implement the methods they need.
type BasePlugin struct {
	pluginName string
}

// NewBasePlugin creates a new base plugin with the given name.
func NewBasePlugin(name string) *BasePlugin {
	return &BasePlugin{pluginName: name}
}

func (p *BasePlugin) Name() string {
	return p.pluginName
}

func (p *BasePlugin) OnBeforeAction(ctx context.Context, action *Action) error {
	return nil
}

func (p *BasePlugin) OnAfterAction(ctx context.Context, action *Action) error {
	return nil
}

func (p *BasePlugin) OnBeforeExecute(ctx context.Context, schedule string, process string) error {
	return nil
}

func (p *BasePlugin) OnAfterExecute(ctx context.Context, schedule string, process string, err error) error {
	return nil
}
