package monitor

import (
	"bytes"
	"testing"
)

func TestStartMemoryGraph_Disabled(t *testing.T) {
	Disable()
	stop := StartMemoryGraph(&bytes.Buffer{}, Options{Enabled: true})
	stop()
	// When disabled, StartMemoryGraph returns a no-op; stop should not block
}

func TestStartMemoryGraph_NotEnabled(t *testing.T) {
	stop := StartMemoryGraph(&bytes.Buffer{}, Options{Enabled: false})
	stop()
	// When Enabled=false, returns no-op; stop should not block
}

func TestStartMemoryGraph_NilWriter(t *testing.T) {
	// Nil writer falls back to os.Stderr; without terminal it returns no-op
	// Use a buffer - isTerminal returns false for bytes.Buffer, so it returns no-op
	stop := StartMemoryGraph(&bytes.Buffer{}, Options{Enabled: true})
	stop()
}

func TestOptions_Defaults(t *testing.T) {
	opts := Options{}
	if opts.Interval != 0 {
		t.Errorf("default Interval should be 0, got %v", opts.Interval)
	}
	if opts.Width != 0 {
		t.Errorf("default Width should be 0, got %d", opts.Width)
	}
}

func TestBuildLine(t *testing.T) {
	dst := make([]byte, 0, 128)
	barBuf := make([]byte, 24)
	result := buildLine(dst, barBuf, "mem", 1.5, 2.0, 3, 0.5, []float64{0.4, 0.5, 0.6}, 3)
	if len(result) == 0 {
		t.Error("buildLine returned empty")
	}
	if !bytes.Contains(result, []byte("mem")) {
		t.Error("buildLine should contain label")
	}
}

func TestAppendSpark(t *testing.T) {
	dst := appendSpark(nil, []float64{0.0, 0.5, 1.0}, 3)
	if len(dst) != 3 {
		t.Errorf("appendSpark should return 3 chars, got %d", len(dst))
	}
}

func TestAppendFloat(t *testing.T) {
	dst := appendFloat(nil, 1.5)
	if len(dst) == 0 {
		t.Error("appendFloat returned empty")
	}
}

func TestAppendSpaces(t *testing.T) {
	dst := appendSpaces(nil, 5)
	if len(dst) != 5 {
		t.Errorf("appendSpaces(5) should return 5 bytes, got %d", len(dst))
	}
}

func TestIsTerminal(t *testing.T) {
	var buf bytes.Buffer
	if isTerminal(&buf) {
		t.Error("bytes.Buffer should not be a terminal")
	}
}
