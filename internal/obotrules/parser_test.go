package obotrules

import (
	"os"
	"path/filepath"
	"testing"
)

func TestNewParser(t *testing.T) {
	p := NewParser("/tmp")
	if p == nil {
		t.Fatal("NewParser returned nil")
	}
	p2 := NewParser("")
	if p2 == nil {
		t.Fatal("NewParser with empty root returned nil")
	}
}

func TestParseMarkdown(t *testing.T) {
	p := NewParser(".")
	content := `## rule1
Scope: global
Description: A test rule
Content here.

## rule2
Scope: agent
Other content.`
	rules := p.parseMarkdown(content, "/test/file")
	if len(rules) != 2 {
		t.Fatalf("expected 2 rules, got %d", len(rules))
	}
	if rules[0].ID != "rule1" {
		t.Errorf("rule1 ID: got %q", rules[0].ID)
	}
	if rules[0].Scope != "global" {
		t.Errorf("rule1 scope: got %q", rules[0].Scope)
	}
	if rules[1].Scope != "agent" {
		t.Errorf("rule2 scope: got %q", rules[1].Scope)
	}
}

func TestDiscover(t *testing.T) {
	tmp := t.TempDir()
	p := NewParser(tmp)
	files, err := p.Discover(tmp)
	if err != nil {
		t.Fatalf("Discover failed: %v", err)
	}
	if len(files) > 0 {
		t.Logf("Discovered %d files (none expected in empty dir)", len(files))
	}
	// Create .obotrules
	rulePath := filepath.Join(tmp, ".obotrules")
	if err := os.WriteFile(rulePath, []byte("## test\n"), 0644); err != nil {
		t.Fatalf("write rules file: %v", err)
	}
	files, err = p.Discover(tmp)
	if err != nil {
		t.Fatalf("Discover failed: %v", err)
	}
	if len(files) != 1 {
		t.Errorf("expected 1 file, got %d", len(files))
	}
}

func TestParseOBotRules_NotExist(t *testing.T) {
	rules, err := ParseOBotRules("/nonexistent/path/.obotrules")
	if err != nil {
		t.Fatalf("ParseOBotRules on nonexistent should return empty rules, got err: %v", err)
	}
	if rules == nil {
		t.Fatal("expected non-nil Rules")
	}
	if rules.FileRules == nil {
		t.Error("FileRules should be initialized")
	}
}

func TestParseOBotRules_ValidFile(t *testing.T) {
	tmp := t.TempDir()
	path := filepath.Join(tmp, ".obotrules")
	content := `

# System Rules

## SYS1
System rule content.

# Global Rules

## GLOB1
Global rule content.
`
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatalf("write: %v", err)
	}
	rules, err := ParseOBotRules(path)
	if err != nil {
		t.Fatalf("ParseOBotRules: %v", err)
	}
	if len(rules.SystemRules) < 1 {
		t.Errorf("expected at least 1 system rule, got %d", len(rules.SystemRules))
	}
	if len(rules.GlobalRules) < 1 {
		t.Errorf("expected at least 1 global rule, got %d", len(rules.GlobalRules))
	}
}

func TestInjectRules(t *testing.T) {
	p := NewParser(".")
	base := "Base prompt"
	rules := []Rule{
		{ID: "r1", Scope: "global", Content: "Content 1"},
		{ID: "r2", Scope: "agent", Content: "Content 2"},
	}
	result := p.InjectRules(base, "agent", rules)
	if result == base {
		t.Error("InjectRules should have modified base when rules match")
	}
	if len(result) <= len(base) {
		t.Errorf("result should be longer than base")
	}
}

func TestValidateRules(t *testing.T) {
	p := NewParser(".")
	valid := []Rule{{ID: "a", Scope: "global"}, {ID: "b", Scope: "agent"}}
	errs := p.ValidateRules(valid)
	if len(errs) != 0 {
		t.Errorf("valid rules should have no errors: %v", errs)
	}
	invalid := []Rule{{ID: "", Scope: "global"}, {ID: "x", Scope: "invalid"}}
	errs = p.ValidateRules(invalid)
	if len(errs) == 0 {
		t.Error("invalid rules should produce errors")
	}
}

func TestGetRulesSummary(t *testing.T) {
	p := NewParser(".")
	rules := []Rule{{ID: "r1", Scope: "global", Source: "/a/b.obotrules"}}
	s := p.GetRulesSummary(rules)
	if s == "" || len(s) < 10 {
		t.Errorf("GetRulesSummary returned empty or too short: %q", s)
	}
}
