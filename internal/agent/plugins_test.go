package agent

import (
	"context"
	"errors"
	"testing"

	"github.com/croberts/obot/internal/model"
	"github.com/croberts/obot/internal/orchestrate"
)

type mockPlugin struct {
	BasePlugin
	beforeActionCalled   bool
	afterActionCalled    bool
	beforeExecuteCalled  bool
	afterExecuteCalled   bool
	rejectAction         bool
	rejectExecute        bool
}

func (m *mockPlugin) Name() string { return "mock" }

func (m *mockPlugin) OnBeforeAction(ctx context.Context, action *Action) error {
	m.beforeActionCalled = true
	if m.rejectAction {
		return errors.New("rejected action")
	}
	return nil
}

func (m *mockPlugin) OnAfterAction(ctx context.Context, action *Action) error {
	m.afterActionCalled = true
	return nil
}

func (m *mockPlugin) OnBeforeExecute(ctx context.Context, schedule string, process string) error {
	m.beforeExecuteCalled = true
	if m.rejectExecute {
		return errors.New("rejected execute")
	}
	return nil
}

func (m *mockPlugin) OnAfterExecute(ctx context.Context, schedule string, process string, err error) error {
	m.afterExecuteCalled = true
	return nil
}

func TestAgentPlugins(t *testing.T) {
	// Initialize with a dummy coordinator to avoid panics
	models := model.NewCoordinator(nil)
	a := NewAgent(models)
	p := &mockPlugin{}
	a.RegisterPlugin(p)

	// Test Execute hooks
	ctx := context.Background()
	// We expect this to fail because there's no real model server, but hooks should still be called
	_ = a.Execute(ctx, orchestrate.ScheduleKnowledge, orchestrate.ProcessID(1), "test prompt")

	if !p.beforeExecuteCalled {
		t.Errorf("OnBeforeExecute was not called")
	}
	if !p.afterExecuteCalled {
		t.Errorf("OnAfterExecute was not called")
	}

	// Test action hooks (manually triggering executeAction since Execute is mocked/short-circuited in this test)
	a.executing = true
	action := &Action{Type: ActionCreateFile, Path: "test.txt"}
	_ = a.executeAction(ctx, action)

	if !p.beforeActionCalled {
		t.Errorf("OnBeforeAction was not called")
	}
	if !p.afterActionCalled {
		t.Errorf("OnAfterAction was not called")
	}
}

func TestAgentPluginRejection(t *testing.T) {
	models := model.NewCoordinator(nil)
	a := NewAgent(models)
	
	t.Run("RejectExecute", func(t *testing.T) {
		p := &mockPlugin{rejectExecute: true}
		a.RegisterPlugin(p)
		err := a.Execute(context.Background(), orchestrate.ScheduleKnowledge, orchestrate.ProcessID(1), "test")
		if err == nil {
			t.Errorf("expected error from rejected execute, got nil")
		}
	})

	t.Run("RejectAction", func(t *testing.T) {
		a.plugins = nil // Clear plugins
		p := &mockPlugin{rejectAction: true}
		a.RegisterPlugin(p)
		a.executing = true
		action := &Action{Type: ActionCreateFile, Path: "test.txt"}
		err := a.executeAction(context.Background(), action)
		if err == nil {
			t.Errorf("expected error from rejected action, got nil")
		}
	})
}
