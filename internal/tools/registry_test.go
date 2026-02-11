package tools

import "testing"

func TestNewRegistry(t *testing.T) {
	r := NewRegistry()
	if r == nil {
		t.Fatal("NewRegistry() = nil")
	}
}

func TestRegistry_Get(t *testing.T) {
	r := NewRegistry()

	t1 := r.Get(ToolFileWrite)
	if t1 == nil {
		t.Fatal("Get(ToolFileWrite) = nil")
	}
	if t1.ID != ToolFileWrite {
		t.Errorf("Get(ToolFileWrite).ID = %q, want %q", t1.ID, ToolFileWrite)
	}
	if t1.Category != CategoryFile {
		t.Errorf("Get(ToolFileWrite).Category = %q, want %q", t1.Category, CategoryFile)
	}

	if r.Get(ToolID("nonexistent")) != nil {
		t.Error("Get(nonexistent) should return nil")
	}
}

func TestRegistry_IsValid(t *testing.T) {
	r := NewRegistry()

	if !r.IsValid(ToolFileWrite) {
		t.Error("IsValid(ToolFileWrite) = false, want true")
	}
	if r.IsValid(ToolID("nonexistent")) {
		t.Error("IsValid(nonexistent) = true, want false")
	}
}

func TestRegistry_GetByCLIAlias(t *testing.T) {
	r := NewRegistry()

	t1 := r.GetByCLIAlias("CreateFile")
	if t1 == nil {
		t.Fatal("GetByCLIAlias(CreateFile) = nil")
	}
	if t1.ID != ToolFileWrite {
		t.Errorf("GetByCLIAlias(CreateFile).ID = %q, want %q", t1.ID, ToolFileWrite)
	}
}

func TestRegistry_ListByCategory(t *testing.T) {
	r := NewRegistry()

	tools := r.ListByCategory(CategoryFile)
	if len(tools) == 0 {
		t.Error("ListByCategory(CategoryFile) returned empty")
	}
	for _, tool := range tools {
		if tool.Category != CategoryFile {
			t.Errorf("ListByCategory returned tool with category %q", tool.Category)
		}
	}
}
