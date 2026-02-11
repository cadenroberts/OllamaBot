package orchestrate

import (
	"context"
)

// OrchestratorPlugin represents a plugin that can hook into the orchestration lifecycle.
// Plugins allow extending the orchestrator's functionality without modifying its core logic.
type OrchestratorPlugin interface {
	// Name returns the unique name of the plugin.
	Name() string

	// OnStateChange is called when the orchestrator state changes.
	OnStateChange(ctx context.Context, state OrchestratorState) error

	// OnScheduleStart is called before a schedule begins.
	OnScheduleStart(ctx context.Context, scheduleID ScheduleID) error

	// OnScheduleEnd is called after a schedule finishes.
	OnScheduleEnd(ctx context.Context, scheduleID ScheduleID) error

	// OnProcessStart is called before a process begins.
	OnProcessStart(ctx context.Context, scheduleID ScheduleID, processID ProcessID) error

	// OnProcessEnd is called after a process finishes.
	OnProcessEnd(ctx context.Context, scheduleID ScheduleID, processID ProcessID) error

	// OnError is called when an error occurs during orchestration.
	OnError(ctx context.Context, err error)
}

// BaseOrchestratorPlugin provides a default implementation for the OrchestratorPlugin interface.
type BaseOrchestratorPlugin struct {
	pluginName string
}

// NewBaseOrchestratorPlugin creates a new base orchestrator plugin.
func NewBaseOrchestratorPlugin(name string) *BaseOrchestratorPlugin {
	return &BaseOrchestratorPlugin{pluginName: name}
}

func (p *BaseOrchestratorPlugin) Name() string {
	return p.pluginName
}

func (p *BaseOrchestratorPlugin) OnStateChange(ctx context.Context, state OrchestratorState) error {
	return nil
}

func (p *BaseOrchestratorPlugin) OnScheduleStart(ctx context.Context, scheduleID ScheduleID) error {
	return nil
}

func (p *BaseOrchestratorPlugin) OnScheduleEnd(ctx context.Context, scheduleID ScheduleID) error {
	return nil
}

func (p *BaseOrchestratorPlugin) OnProcessStart(ctx context.Context, scheduleID ScheduleID, processID ProcessID) error {
	return nil
}

func (p *BaseOrchestratorPlugin) OnProcessEnd(ctx context.Context, scheduleID ScheduleID, processID ProcessID) error {
	return nil
}

func (p *BaseOrchestratorPlugin) OnError(ctx context.Context, err error) {}
