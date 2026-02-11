package consultation

import (
	"bytes"
	"context"
	"strings"
	"testing"
	"time"
)

func TestHandler_Request_Human(t *testing.T) {
	input := "Human response\n"
	reader := strings.NewReader(input)
	writer := &bytes.Buffer{}
	
	h := NewHandler(reader, writer, &Config{
		TimeoutSeconds: 1,
		AllowAISub:     false,
	})
	
	req := Request{
		Type:     ConsultationClarify,
		Question: "What should I do?",
	}
	
	resp, err := h.Request(context.Background(), req)
	if err != nil {
		t.Fatalf("Request failed: %v", err)
	}
	
	if resp.Content != "Human response" {
		t.Errorf("expected 'Human response', got '%s'", resp.Content)
	}
	if resp.Source != ResponseSourceHuman {
		t.Errorf("expected source human, got %s", resp.Source)
	}
}

func TestHandler_Request_Timeout_AISub(t *testing.T) {
	// Block reader to force timeout
	reader := &blockingReader{}
	writer := &bytes.Buffer{}
	
	h := NewHandler(reader, writer, &Config{
		TimeoutSeconds:   1,
		CountdownSeconds: 1,
		AllowAISub:       true,
	})
	
	req := Request{
		Type:     ConsultationFeedback,
		Question: "Is this okay?",
	}
	
	resp, err := h.Request(context.Background(), req)
	if err != nil {
		t.Fatalf("Request failed: %v", err)
	}
	
	if !strings.Contains(resp.Content, "[AI-SUBSTITUTE]") {
		t.Errorf("expected AI substitute response, got '%s'", resp.Content)
	}
	if resp.Source != ResponseSourceAISubstitute {
		t.Errorf("expected source ai_substitute, got %s", resp.Source)
	}
}

func TestHandler_Request_Timeout_Error(t *testing.T) {
	reader := &blockingReader{}
	writer := &bytes.Buffer{}
	
	h := NewHandler(reader, writer, &Config{
		TimeoutSeconds: 1,
		AllowAISub:     false,
	})
	
	req := Request{
		Type:     ConsultationClarify,
		Question: "Should I continue?",
	}
	
	_, err := h.Request(context.Background(), req)
	if err == nil || !strings.Contains(err.Error(), "timeout") {
		t.Errorf("expected timeout error, got %v", err)
	}
}

type blockingReader struct{}

func (r *blockingReader) Read(p []byte) (n int, err error) {
	time.Sleep(2 * time.Second)
	return 0, nil
}
