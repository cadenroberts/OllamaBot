package errs

import (
	"strings"
	"testing"
)

func TestRegistry_hasErrorCodes(t *testing.T) {
	if len(Registry) == 0 {
		t.Fatal("Registry should not be empty")
	}
	if _, ok := Registry[ErrInvalidTransition]; !ok {
		t.Error("Registry missing ErrInvalidTransition")
	}
	if _, ok := Registry[ErrOllamaUnavailable]; !ok {
		t.Error("Registry missing ErrOllamaUnavailable")
	}
}

func TestIsRecoverable(t *testing.T) {
	if !IsRecoverable(ErrInvalidTransition) {
		t.Error("ErrInvalidTransition should be recoverable")
	}
	if IsRecoverable(ErrAgentTermination) {
		t.Error("ErrAgentTermination should not be recoverable")
	}
	if !IsRecoverable(ErrOllamaUnavailable) {
		t.Error("ErrOllamaUnavailable should be recoverable")
	}
	if IsRecoverable(ErrorCode("E999")) {
		t.Error("unknown code should not be recoverable")
	}
}

func TestFormatError(t *testing.T) {
	got := FormatError(ErrInvalidTransition)
	if got == "" {
		t.Fatal("FormatError returned empty")
	}
	if !strings.Contains(got, "E001") {
		t.Errorf("FormatError should contain code, got %q", got)
	}
	if !strings.Contains(got, "Invalid") {
		t.Errorf("FormatError should contain description, got %q", got)
	}

	unknown := FormatError(ErrorCode("E999"))
	if !strings.Contains(unknown, "Unknown") {
		t.Errorf("unknown code should format as Unknown, got %q", unknown)
	}
}

func TestNewAppError(t *testing.T) {
	err := NewAppError(ErrInvalidInput, "test message")
	if err == nil {
		t.Fatal("NewAppError returned nil")
	}
	if err.Code != ErrInvalidInput {
		t.Errorf("Code = %v, want ErrInvalidInput", err.Code)
	}
	if err.Message != "test message" {
		t.Errorf("Message = %q, want test message", err.Message)
	}
	if err.Error() == "" {
		t.Error("Error() should return non-empty string")
	}
}

func TestGetMetadata(t *testing.T) {
	meta, ok := GetMetadata(ErrModelNotFound)
	if !ok {
		t.Fatal("GetMetadata should find ErrModelNotFound")
	}
	if meta.Code != ErrModelNotFound {
		t.Errorf("meta.Code = %v, want ErrModelNotFound", meta.Code)
	}
	if meta.Description == "" {
		t.Error("Description should not be empty")
	}
	if meta.ActionHint == "" {
		t.Error("ActionHint should not be empty")
	}

	_, ok = GetMetadata(ErrorCode("E999"))
	if ok {
		t.Error("unknown code should return ok=false")
	}
}
