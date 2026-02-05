// Package consultation implements human consultation for obot orchestration.
package consultation

import (
	"context"
	"fmt"
	"io"
	"strings"
	"sync"
	"time"
)

// Handler manages human consultation with timeout and AI substitute.
type Handler struct {
	mu sync.Mutex

	// I/O
	reader io.Reader
	writer io.Writer

	// Configuration
	timeoutSeconds   int
	countdownSeconds int
	aiSubstitute     bool

	// Callbacks
	onTimeout    func()
	onResponse   func(string, bool) // response, isAISubstitute
}

// Config contains consultation configuration
type Config struct {
	TimeoutSeconds   int
	CountdownSeconds int
	AISubstitute     bool
}

// DefaultConfig returns the default consultation configuration
func DefaultConfig() *Config {
	return &Config{
		TimeoutSeconds:   60,
		CountdownSeconds: 15,
		AISubstitute:     true,
	}
}

// NewHandler creates a new consultation handler
func NewHandler(reader io.Reader, writer io.Writer, config *Config) *Handler {
	if config == nil {
		config = DefaultConfig()
	}

	return &Handler{
		reader:           reader,
		writer:           writer,
		timeoutSeconds:   config.TimeoutSeconds,
		countdownSeconds: config.CountdownSeconds,
		aiSubstitute:     config.AISubstitute,
	}
}

// SetCallbacks sets the handler callbacks
func (h *Handler) SetCallbacks(onTimeout func(), onResponse func(string, bool)) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.onTimeout = onTimeout
	h.onResponse = onResponse
}

// ConsultationType represents the type of consultation
type ConsultationType string

const (
	ConsultationClarify  ConsultationType = "clarify"
	ConsultationFeedback ConsultationType = "feedback"
)

// Request represents a consultation request
type Request struct {
	Type      ConsultationType
	Question  string
	Context   string
	Options   []string // For Clarify: A, B, C, D
}

// Response represents a consultation response
type Response struct {
	Content      string
	IsAISubstitute bool
	Timestamp    time.Time
}

// RequestConsultation displays a consultation request and waits for response
func (h *Handler) RequestConsultation(ctx context.Context, req Request) (*Response, error) {
	// Display consultation UI
	h.displayConsultationUI(req)

	// Create response channel
	responseCh := make(chan string, 1)
	
	// Start countdown
	timeoutCtx, cancel := context.WithTimeout(ctx, time.Duration(h.timeoutSeconds)*time.Second)
	defer cancel()

	// Start countdown display goroutine
	countdownCh := make(chan struct{})
	go h.runCountdown(timeoutCtx, countdownCh)

	// Wait for response or timeout
	select {
	case response := <-responseCh:
		close(countdownCh)
		return &Response{
			Content:      response,
			IsAISubstitute: false,
			Timestamp:    time.Now(),
		}, nil

	case <-timeoutCtx.Done():
		close(countdownCh)
		if h.aiSubstitute {
			// Generate AI substitute response
			aiResponse := h.generateAISubstitute(req)
			if h.onResponse != nil {
				h.onResponse(aiResponse, true)
			}
			return &Response{
				Content:      aiResponse,
				IsAISubstitute: true,
				Timestamp:    time.Now(),
			}, nil
		}
		return nil, fmt.Errorf("consultation timeout")

	case <-ctx.Done():
		close(countdownCh)
		return nil, ctx.Err()
	}
}

// displayConsultationUI displays the consultation UI
func (h *Handler) displayConsultationUI(req Request) {
	var sb strings.Builder

	sb.WriteString("\n")
	sb.WriteString("┌─────────────────────────────────────────────────────────────────────┐\n")
	sb.WriteString("│ HUMAN CONSULTATION REQUESTED                                        │\n")
	sb.WriteString("│                                                                     │\n")
	sb.WriteString(fmt.Sprintf("│ Process: %-60s │\n", req.Type))
	sb.WriteString("│ Question:                                                           │\n")

	// Wrap question text
	words := strings.Fields(req.Question)
	line := "│   "
	for _, word := range words {
		if len(line)+len(word)+1 > 71 {
			sb.WriteString(line + strings.Repeat(" ", 72-len(line)) + "│\n")
			line = "│   "
		}
		line += word + " "
	}
	if len(line) > 4 {
		sb.WriteString(line + strings.Repeat(" ", 72-len(line)) + "│\n")
	}

	sb.WriteString("│                                                                     │\n")

	// Options for Clarify
	if req.Type == ConsultationClarify && len(req.Options) > 0 {
		sb.WriteString("│ Options:                                                            │\n")
		for i, opt := range req.Options {
			optLine := fmt.Sprintf("│   %c) %s", 'A'+i, opt)
			sb.WriteString(optLine + strings.Repeat(" ", 72-len(optLine)) + "│\n")
		}
		sb.WriteString("│                                                                     │\n")
	}

	sb.WriteString("│ ┌─────────────────────────────────────────────────────────────────┐ │\n")
	sb.WriteString("│ │ [Your response here...]                                         │ │\n")
	sb.WriteString("│ └─────────────────────────────────────────────────────────────────┘ │\n")
	sb.WriteString("│                                                                     │\n")
	sb.WriteString(fmt.Sprintf("│ Time remaining: %02d:00  [Respond]                                    │\n", h.timeoutSeconds))
	sb.WriteString("│                                                                     │\n")
	sb.WriteString("│ ⚠ After timeout, an AI model will respond on your behalf           │\n")
	sb.WriteString("└─────────────────────────────────────────────────────────────────────┘\n")

	fmt.Fprint(h.writer, sb.String())
}

// runCountdown runs the countdown display
func (h *Handler) runCountdown(ctx context.Context, stopCh <-chan struct{}) {
	remaining := h.timeoutSeconds
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			remaining--
			if remaining <= h.countdownSeconds && remaining > 0 {
				// Display visual countdown
				fmt.Fprintf(h.writer, "\r⚠ AI RESPONSE IN: %d... ", remaining)
			}
			if remaining <= 0 {
				return
			}
		case <-stopCh:
			return
		case <-ctx.Done():
			return
		}
	}
}

// generateAISubstitute generates an AI substitute response
func (h *Handler) generateAISubstitute(req Request) string {
	// In a real implementation, this would call the AI model
	// For now, return a placeholder
	switch req.Type {
	case ConsultationClarify:
		if len(req.Options) > 0 {
			return "A" // Default to first option
		}
		return "[AI-SUBSTITUTE] Proceeding with the most common interpretation."
	case ConsultationFeedback:
		return "[AI-SUBSTITUTE] The changes look good. Please continue with the implementation."
	default:
		return "[AI-SUBSTITUTE] No response provided."
	}
}

// FormatClarifyRequest formats a clarify request
func FormatClarifyRequest(context, ambiguity string, options []string) Request {
	var sb strings.Builder
	sb.WriteString("CLARIFY REQUEST\n")
	sb.WriteString("───────────────\n")
	sb.WriteString(fmt.Sprintf("Context: %s\n", context))
	sb.WriteString(fmt.Sprintf("Ambiguity: %s\n", ambiguity))
	sb.WriteString("Options:\n")
	for i, opt := range options {
		sb.WriteString(fmt.Sprintf("  %c) %s\n", 'A'+i, opt))
	}
	sb.WriteString("\nWhich option best matches your intent?")

	return Request{
		Type:    ConsultationClarify,
		Question: sb.String(),
		Options: options,
	}
}

// FormatFeedbackRequest formats a feedback request
func FormatFeedbackRequest(changes []ChangeDescription, verificationResults VerificationResults, questions []FeedbackQuestion) Request {
	var sb strings.Builder
	sb.WriteString("FEEDBACK DEMONSTRATION\n")
	sb.WriteString("──────────────────────\n")
	sb.WriteString("Changes Made:\n")

	for i, change := range changes {
		sb.WriteString(fmt.Sprintf("  %d. %s\n", i+1, change.Description))
		sb.WriteString(fmt.Sprintf("     File: %s\n", change.File))
		sb.WriteString(fmt.Sprintf("     Lines: %s\n\n", change.Lines))
	}

	sb.WriteString("Verification Results:\n")
	sb.WriteString(fmt.Sprintf("  ✓ Tests: %d/%d passed\n", verificationResults.TestsPassed, verificationResults.TestsTotal))
	sb.WriteString(fmt.Sprintf("  ✓ Lint: %d warnings, %d errors\n", verificationResults.LintWarnings, verificationResults.LintErrors))
	sb.WriteString(fmt.Sprintf("  ✓ Build: %s\n\n", verificationResults.BuildStatus))

	sb.WriteString("Questions for Review:\n")
	for i, q := range questions {
		sb.WriteString(fmt.Sprintf("  Q%d: %s\n", i+1, q.Question))
		sb.WriteString(fmt.Sprintf("      %s\n\n", strings.Join(q.Options, " ")))
	}

	return Request{
		Type:    ConsultationFeedback,
		Question: sb.String(),
	}
}

// ChangeDescription describes a change for feedback
type ChangeDescription struct {
	Description string
	File        string
	Lines       string
}

// VerificationResults contains verification results
type VerificationResults struct {
	TestsPassed  int
	TestsTotal   int
	LintWarnings int
	LintErrors   int
	BuildStatus  string
}

// FeedbackQuestion is a structured feedback question
type FeedbackQuestion struct {
	Question string
	Options  []string
}
