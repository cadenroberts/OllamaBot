package version

import (
	"strings"
	"testing"
)

func TestShort(t *testing.T) {
	s := Short()
	if s == "" {
		t.Fatal("Short() returned empty string")
	}
	if !strings.Contains(s, "dev") && !strings.Contains(s, "v") {
		t.Errorf("Short() = %q, expected version substring", s)
	}
}

func TestFull(t *testing.T) {
	s := Full()
	if s == "" {
		t.Fatal("Full() returned empty string")
	}
	if !strings.Contains(s, "obot") {
		t.Errorf("Full() = %q, expected 'obot' prefix", s[:50])
	}
	if !strings.Contains(s, "commit:") {
		t.Errorf("Full() missing 'commit:' line")
	}
	if !strings.Contains(s, "platform:") {
		t.Errorf("Full() missing 'platform:' line")
	}
}

func TestGet(t *testing.T) {
	info := Get()
	if info.Version == "" {
		t.Error("Get().Version is empty")
	}
	if info.OS == "" {
		t.Error("Get().OS is empty")
	}
	if info.Arch == "" {
		t.Error("Get().Arch is empty")
	}
	if info.Platform == "" {
		t.Error("Get().Platform is empty")
	}
}
