package actions

import (
	"strings"
	"testing"
)

func TestNewRecorder(t *testing.T) {
	r := NewRecorder()
	if r == nil {
		t.Fatal("NewRecorder returned nil")
	}
	if r.HasActions() {
		t.Error("new recorder should have no actions")
	}
}

func TestRecorder_Add(t *testing.T) {
	r := NewRecorder()

	id := r.Add("fix the bug", map[string]string{"file": "main.go"})
	if id == "" {
		t.Fatal("Add returned empty id")
	}
	if !strings.HasPrefix(id, "A") {
		t.Errorf("id should start with A, got %q", id)
	}

	if !r.HasActions() {
		t.Error("recorder should have actions after Add")
	}

	id2 := r.Add("add tests", nil)
	if id2 == id {
		t.Error("second Add should return different id")
	}
}

func TestRecorder_RenderSummary(t *testing.T) {
	r := NewRecorder()
	if got := r.RenderSummary(); got != "" {
		t.Errorf("empty recorder RenderSummary should return empty string, got %q", got)
	}

	r.Add("first action", nil)
	r.Add("second action", map[string]string{"key": "val"})
	got := r.RenderSummary()
	if !strings.Contains(got, "Actions Summary") {
		t.Errorf("summary should contain 'Actions Summary', got %q", got)
	}
	if !strings.Contains(got, "first action") {
		t.Errorf("summary should contain first action, got %q", got)
	}
	if !strings.Contains(got, "second action") {
		t.Errorf("summary should contain second action, got %q", got)
	}
	if !strings.Contains(got, "Citations") {
		t.Errorf("summary should contain Citations section, got %q", got)
	}
}
