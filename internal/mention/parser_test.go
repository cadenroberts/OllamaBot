package mention

import (
	"testing"
)

func TestNewParser(t *testing.T) {
	p := NewParser()
	if p == nil {
		t.Fatal("NewParser returned nil")
	}
}

func TestParse_ColonFormat(t *testing.T) {
	p := NewParser()
	mentions := p.Parse("fix @file:foo.go the bug")
	if len(mentions) != 1 {
		t.Fatalf("expected 1 mention, got %d", len(mentions))
	}
	if mentions[0].Type != MentionFile {
		t.Errorf("expected MentionFile, got %s", mentions[0].Type)
	}
	if mentions[0].Value != "foo.go" {
		t.Errorf("expected value foo.go, got %q", mentions[0].Value)
	}
}

func TestParse_LegacyFormat(t *testing.T) {
	p := NewParser()
	mentions := p.Parse("check @foo.go")
	if len(mentions) != 1 {
		t.Fatalf("expected 1 mention, got %d", len(mentions))
	}
	if mentions[0].Type != MentionFile {
		t.Errorf("expected MentionFile for .go suffix, got %s", mentions[0].Type)
	}
}

func TestParse_Empty(t *testing.T) {
	p := NewParser()
	mentions := p.Parse("no mentions here")
	if len(mentions) != 0 {
		t.Errorf("expected 0 mentions, got %d", len(mentions))
	}
}

func TestStripMentions(t *testing.T) {
	p := NewParser()
	input := "fix @file:foo.go the bug"
	got := p.StripMentions(input)
	if got != "fix the bug" {
		t.Errorf("expected \"fix the bug\", got %q", got)
	}
}

func TestGetMentionsByType(t *testing.T) {
	p := NewParser()
	mentions := p.GetMentionsByType("use @file:a.go and @file:b.go", MentionFile)
	if len(mentions) != 2 {
		t.Fatalf("expected 2 file mentions, got %d", len(mentions))
	}
}

func TestValidate(t *testing.T) {
	p := NewParser()
	if !p.Validate(Mention{Type: MentionFile, Value: "x.go"}) {
		t.Error("expected valid file mention with value")
	}
	if p.Validate(Mention{Type: MentionFile, Value: ""}) {
		t.Error("expected invalid file mention with empty value")
	}
}

func TestAnalyze(t *testing.T) {
	p := NewParser()
	r := p.Analyze("review @file:main.go")
	if r == nil {
		t.Fatal("Analyze returned nil")
	}
	if r.Original != "review @file:main.go" {
		t.Errorf("Original mismatch: %q", r.Original)
	}
	if len(r.Mentions) != 1 {
		t.Errorf("expected 1 mention, got %d", len(r.Mentions))
	}
	if r.Counts[MentionFile] != 1 {
		t.Errorf("expected Counts[file]=1, got %d", r.Counts[MentionFile])
	}
}

func TestResult_FormatSummary(t *testing.T) {
	r := &Result{Mentions: []Mention{{Type: MentionFile, Value: "a.go"}}}
	s := r.FormatSummary()
	if s == "" || len(s) < 10 {
		t.Errorf("FormatSummary returned empty or too short: %q", s)
	}
	sEmpty := (&Result{}).FormatSummary()
	if sEmpty != "No mentions found." {
		t.Errorf("expected 'No mentions found.', got %q", sEmpty)
	}
}
