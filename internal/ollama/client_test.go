package ollama

import (
	"testing"
	"time"
)

func TestNewClient(t *testing.T) {
	c := NewClient()
	if c == nil {
		t.Fatal("NewClient() = nil")
	}
	if c.BaseURL() != DefaultBaseURL {
		t.Errorf("NewClient().BaseURL() = %q, want %q", c.BaseURL(), DefaultBaseURL)
	}
	if c.GetModel() != "" {
		t.Errorf("NewClient().GetModel() = %q, want empty", c.GetModel())
	}
}

func TestNewClient_WithBaseURL(t *testing.T) {
	url := "http://custom:11434"
	c := NewClient(WithBaseURL(url))
	if c.BaseURL() != url {
		t.Errorf("WithBaseURL: BaseURL() = %q, want %q", c.BaseURL(), url)
	}
}

func TestNewClient_WithModel(t *testing.T) {
	model := "llama3:8b"
	c := NewClient(WithModel(model))
	if c.GetModel() != model {
		t.Errorf("WithModel: GetModel() = %q, want %q", c.GetModel(), model)
	}
}

func TestNewClient_WithOptions(t *testing.T) {
	opts := map[string]any{"temperature": 0.7}
	c := NewClient(WithOptions(opts))
	if c == nil {
		t.Fatal("NewClient(WithOptions) = nil")
	}
}

func TestNewClient_WithTimeout(t *testing.T) {
	c := NewClient(WithTimeout(10 * time.Second))
	if c == nil {
		t.Fatal("NewClient(WithTimeout) = nil")
	}
}

func TestClient_SetModel_GetModel(t *testing.T) {
	c := NewClient()
	c.SetModel("codellama")
	if c.GetModel() != "codellama" {
		t.Errorf("SetModel/GetModel = %q, want codellama", c.GetModel())
	}
}
