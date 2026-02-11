// Package consultation implements human consultation for obot orchestration.
package consultation

import (
	"context"
	"fmt"
	"io"
	"strings"
	"sync"
	"time"

	"github.com/croberts/obot/internal/ollama"
	"github.com/croberts/obot/internal/ui"
)

// ResponseSource indicates who provided the consultation response.
type ResponseSource string

const (
	ResponseSourceHuman        ResponseSource = "human"
	ResponseSourceAISubstitute ResponseSource = "ai_substitute"
)

// Handler manages human consultation with timeout and AI substitute.
type Handler struct {
	mu sync.Mutex

	// I/O
	reader io.Reader
	writer io.Writer

	// AI Model
	aiModel *ollama.Client

	// Configuration
	timeoutSeconds   int
	countdownSeconds int
	allowAISub       bool

	// Callbacks
	onTimeout    func()
	onResponse   func(string, ResponseSource) // response, source
}

// Config contains consultation configuration
type Config struct {
	TimeoutSeconds   int
	CountdownSeconds int
	AllowAISub       bool
	AIModel          *ollama.Client
}

// DefaultConfig returns the default consultation configuration
func DefaultConfig() *Config {
	return &Config{
		TimeoutSeconds:   60,
		CountdownSeconds: 15,
		AllowAISub:       true,
		AIModel:          nil,
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
		aiModel:          config.AIModel,
		timeoutSeconds:   config.TimeoutSeconds,
		countdownSeconds: config.CountdownSeconds,
		allowAISub:       config.AllowAISub,
	}
}

// SetCallbacks sets the handler callbacks
func (h *Handler) SetCallbacks(onTimeout func(), onResponse func(string, ResponseSource)) {
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
	Source       ResponseSource
	Timestamp    time.Time
}

// Request displays a consultation request and waits for response
func (h *Handler) Request(ctx context.Context, req Request) (*Response, error) {
	// Display consultation UI
	h.displayConsultation(req)

	// Create response channel
	responseCh := make(chan string, 1)
	errorCh := make(chan error, 1)

	// Start input reader
	go func() {
		resp, err := h.readInput()
		if err != nil {
			errorCh <- err
			return
		}
		responseCh <- resp
	}()
	
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
		if h.onResponse != nil {
			h.onResponse(response, ResponseSourceHuman)
		}
		return &Response{
			Content:   response,
			Source:    ResponseSourceHuman,
			Timestamp: time.Now(),
		}, nil

	case err := <-errorCh:
		close(countdownCh)
		return nil, err

	case <-timeoutCtx.Done():
		close(countdownCh)
		if h.onTimeout != nil {
			h.onTimeout()
		}
		if h.allowAISub {
			// Generate AI substitute response
			aiResponse := h.generateAISubstitute(ctx, req)
			if h.onResponse != nil {
				h.onResponse(aiResponse, ResponseSourceAISubstitute)
			}
			return &Response{
				Content:   aiResponse,
				Source:    ResponseSourceAISubstitute,
				Timestamp: time.Now(),
			}, nil
		}
		return nil, fmt.Errorf("consultation timeout")

	case <-ctx.Done():
		close(countdownCh)
		return nil, ctx.Err()
	}
}

// displayConsultation displays the consultation UI
func (h *Handler) displayConsultation(req Request) {
	var sb strings.Builder

	width := 71
	sb.WriteString("\n")
	sb.WriteString(ui.TextBorder + "┌" + strings.Repeat("─", width-2) + "┐" + ui.ANSIReset + "\n")
	sb.WriteString(ui.TextBorder + "│ " + ui.ANSIBlueBold + "HUMAN CONSULTATION REQUESTED" + strings.Repeat(" ", width-31) + ui.TextBorder + "│" + ui.ANSIReset + "\n")
	sb.WriteString(ui.TextBorder + "│" + strings.Repeat(" ", width-2) + "│" + ui.ANSIReset + "\n")
	sb.WriteString(ui.TextBorder + "│ " + ui.TextSecondary + "Process: " + ui.TextPrimary + fmt.Sprintf("%-52s", req.Type) + ui.TextBorder + " │" + ui.ANSIReset + "\n")
	sb.WriteString(ui.TextBorder + "│ " + ui.TextSecondary + "Question:" + strings.Repeat(" ", width-11) + ui.TextBorder + "│" + ui.ANSIReset + "\n")

	// Wrap question text
	words := strings.Fields(req.Question)
	line := "│   "
	for _, word := range words {
		// Calculate length without ANSI codes for wrapping
		if len(line)+len(word)+1 > width-4 {
			sb.WriteString(ui.TextBorder + line + strings.Repeat(" ", width-len(line)-1) + ui.TextBorder + "│" + ui.ANSIReset + "\n")
			line = "│   "
		}
		line += word + " "
	}
	if len(line) > 4 {
		sb.WriteString(ui.TextBorder + line + strings.Repeat(" ", width-len(line)-1) + ui.TextBorder + "│" + ui.ANSIReset + "\n")
	}

	sb.WriteString(ui.TextBorder + "│" + strings.Repeat(" ", width-2) + "│" + ui.ANSIReset + "\n")

	// Options for Clarify
	if req.Type == ConsultationClarify && len(req.Options) > 0 {
		sb.WriteString(ui.TextBorder + "│ " + ui.TextSecondary + "Options:" + strings.Repeat(" ", width-10) + ui.TextBorder + "│" + ui.ANSIReset + "\n")
		for i, opt := range req.Options {
			optText := fmt.Sprintf("%c) %s", 'A'+i, opt)
			if len(optText) > width-8 {
				optText = optText[:width-11] + "..."
			}
			optLine := fmt.Sprintf("│   %s%s", ui.ANSIBlue, optText)
			// Need to calculate real length for padding
			realLen := 4 + len(optText)
			sb.WriteString(ui.TextBorder + optLine + ui.ANSIReset + strings.Repeat(" ", width-realLen-1) + ui.TextBorder + "│" + ui.ANSIReset + "\n")
		}
		sb.WriteString(ui.TextBorder + "│" + strings.Repeat(" ", width-2) + "│" + ui.ANSIReset + "\n")
	}

	sb.WriteString(ui.TextBorder + "│ " + ui.TextBorder + "┌" + strings.Repeat("─", width-6) + "┐ " + ui.TextBorder + "│" + ui.ANSIReset + "\n")
	sb.WriteString(ui.TextBorder + "│ " + ui.TextBorder + "│ " + ui.TextMuted + "[Your response here...]" + strings.Repeat(" ", width-29) + ui.TextBorder + "│ " + ui.TextBorder + "│" + ui.ANSIReset + "\n")
	sb.WriteString(ui.TextBorder + "│ " + ui.TextBorder + "└" + strings.Repeat("─", width-6) + "┘ " + ui.TextBorder + "│" + ui.ANSIReset + "\n")
	sb.WriteString(ui.TextBorder + "│" + strings.Repeat(" ", width-2) + "│" + ui.ANSIReset + "\n")
	
	remainingStr := h.formatDuration(h.timeoutSeconds)
	footer := fmt.Sprintf("Time remaining: %s  [Respond]", remainingStr)
	sb.WriteString(ui.TextBorder + "│ " + ui.TextSecondary + footer + strings.Repeat(" ", width-len(footer)-4) + ui.TextBorder + " │" + ui.ANSIReset + "\n")
	sb.WriteString(ui.TextBorder + "│" + strings.Repeat(" ", width-2) + "│" + ui.ANSIReset + "\n")
	
	warning := "⚠ After timeout, an AI model will respond on your behalf"
	sb.WriteString(ui.TextBorder + "│ " + ui.ANSIYellow + warning + strings.Repeat(" ", width-len(warning)-3) + ui.TextBorder + "│" + ui.ANSIReset + "\n")
	sb.WriteString(ui.TextBorder + "└" + strings.Repeat("─", width-2) + "┘" + ui.ANSIReset + "\n")

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
				h.displayCountdown(remaining)
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

// displayCountdown displays the countdown warning
func (h *Handler) displayCountdown(remaining int) {
	fmt.Fprintf(h.writer, "\r%s⚠ AI RESPONSE IN: %s... %s", ui.ANSIYellow, h.formatDuration(remaining), ui.ANSIReset)
}

// readInput reads up to 4096 bytes from the input reader
func (h *Handler) readInput() (string, error) {
	buf := make([]byte, 4096)
	n, err := h.reader.Read(buf)
	if err != nil && err != io.EOF {
		return "", err
	}
	return strings.TrimSpace(string(buf[:n])), nil
}

// formatDuration formats seconds as MM:SS
func (h *Handler) formatDuration(seconds int) string {
	minutes := seconds / 60
	secs := seconds % 60
	return fmt.Sprintf("%02d:%02d", minutes, secs)
}

// generateAISubstitute generates an AI substitute response.
//
// PROOF:
// - ZERO-HIT: Existing implementation was basic.
// - POSITIVE-HIT: Enhanced generateAISubstitute with detailed prompt and robust fallback in internal/consultation/handler.go.
func (h *Handler) generateAISubstitute(ctx context.Context, req Request) string {
	if h.aiModel != nil {
		prompt := h.formatAISubstitutePrompt(req)

		resp, _, err := h.aiModel.Generate(ctx, prompt)
		if err == nil && resp != "" {
			return strings.TrimSpace(resp)
		}
	}

	return h.getFallbackResponse(req)
}

// formatAISubstitutePrompt generates the prompt for the AI substitute.
func (h *Handler) formatAISubstitutePrompt(req Request) string {
	options := "None"
	if len(req.Options) > 0 {
		options = strings.Join(req.Options, ", ")
	}

	return fmt.Sprintf(`Act as human-in-the-loop for an agentic system. The human did not respond within the timeout. 
Provide a reasonable and safe response to the question below to allow the process to continue.

INSTRUCTIONS:
1. If the question is about approval, approve if the changes seem reasonable.
2. If the question is about choosing an approach, choose the most standard or safe approach.
3. If the question is about clarification, provide a sensible default interpretation.
4. Keep the response concise and professional.
5. If options are provided (A, B, C, etc.), pick the best one and explain why briefly.

CONTEXT:
%s

TYPE:
%s

QUESTION:
%s

OPTIONS:
%s

Your response:`, req.Context, req.Type, req.Question, options)
}

// getFallbackResponse provides a fallback response when AI generation fails.
func (h *Handler) getFallbackResponse(req Request) string {
	switch req.Type {
	case ConsultationClarify:
		if len(req.Options) > 0 {
			return "A" // Default to first option
		}
		return "[AI-SUBSTITUTE] Proceeding with the most common interpretation to avoid block."
	case ConsultationFeedback:
		return "[AI-SUBSTITUTE] The changes appear reasonable and follow standard patterns. Proceeding with the current state."
	default:
		return "[AI-SUBSTITUTE] No response provided. Defaulting to safe continuation."
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
		Type:     ConsultationClarify,
		Question: sb.String(),
		Options:  options,
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
		Type:     ConsultationFeedback,
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
