package ollama

// Message represents a chat message
type Message struct {
	Role    string   `json:"role"`             // "system", "user", "assistant"
	Content string   `json:"content"`          // Message content
	Images  []string `json:"images,omitempty"` // Base64 encoded images
}

// GenerateRequest is the request body for /api/generate
type GenerateRequest struct {
	Model     string         `json:"model"`
	Prompt    string         `json:"prompt"`
	Images    []string       `json:"images,omitempty"` // Base64 encoded images
	Stream    bool           `json:"stream"`
	Options   map[string]any `json:"options,omitempty"`
	KeepAlive string         `json:"keep_alive,omitempty"`
}

// GenerateResponse is a single response chunk from /api/generate
type GenerateResponse struct {
	Model              string `json:"model"`
	CreatedAt          string `json:"created_at"`
	Response           string `json:"response"`
	Done               bool   `json:"done"`
	Context            []int  `json:"context,omitempty"`
	TotalDuration      int64  `json:"total_duration,omitempty"`
	LoadDuration       int64  `json:"load_duration,omitempty"`
	PromptEvalCount    int    `json:"prompt_eval_count,omitempty"`
	PromptEvalDuration int64  `json:"prompt_eval_duration,omitempty"`
	EvalCount          int    `json:"eval_count,omitempty"`
	EvalDuration       int64  `json:"eval_duration,omitempty"`
}

// ChatRequest is the request body for /api/chat
type ChatRequest struct {
	Model     string         `json:"model"`
	Messages  []Message      `json:"messages"`
	Stream    bool           `json:"stream"`
	Options   map[string]any `json:"options,omitempty"`
	KeepAlive string         `json:"keep_alive,omitempty"`
}

// ChatResponse is a single response chunk from /api/chat
type ChatResponse struct {
	Model              string  `json:"model"`
	CreatedAt          string  `json:"created_at"`
	Message            Message `json:"message"`
	Done               bool    `json:"done"`
	TotalDuration      int64   `json:"total_duration,omitempty"`
	LoadDuration       int64   `json:"load_duration,omitempty"`
	PromptEvalCount    int     `json:"prompt_eval_count,omitempty"`
	PromptEvalDuration int64   `json:"prompt_eval_duration,omitempty"`
	EvalCount          int     `json:"eval_count,omitempty"`
	EvalDuration       int64   `json:"eval_duration,omitempty"`
}

// ModelInfo represents information about a model from /api/tags
type ModelInfo struct {
	Name       string `json:"name"`
	ModifiedAt string `json:"modified_at"`
	Size       int64  `json:"size"`
	Digest     string `json:"digest"`
}

// TagsResponse is the response from /api/tags
type TagsResponse struct {
	Models []ModelInfo `json:"models"`
}

// EmbeddingRequest is the request body for /api/embeddings
type EmbeddingRequest struct {
	Model   string         `json:"model"`
	Prompt  string         `json:"prompt"`
	Options map[string]any `json:"options,omitempty"`
}

// EmbeddingResponse is the response from /api/embeddings
type EmbeddingResponse struct {
	Embedding []float64 `json:"embedding"`
}

// InferenceStats holds statistics from an inference
type InferenceStats struct {
	Model              string
	PromptTokens       int
	CompletionTokens   int
	TotalTokens        int
	PromptEvalDuration int64 // nanoseconds
	EvalDuration       int64 // nanoseconds
	TotalDuration      int64 // nanoseconds
	TokensPerSecond    float64
}

// CalculateStats calculates inference statistics from a response
func CalculateStats(resp *GenerateResponse, model string) InferenceStats {
	stats := InferenceStats{
		Model:              model,
		PromptTokens:       resp.PromptEvalCount,
		CompletionTokens:   resp.EvalCount,
		TotalTokens:        resp.PromptEvalCount + resp.EvalCount,
		PromptEvalDuration: resp.PromptEvalDuration,
		EvalDuration:       resp.EvalDuration,
		TotalDuration:      resp.TotalDuration,
	}

	// Calculate tokens per second
	if resp.EvalDuration > 0 {
		// EvalDuration is in nanoseconds
		seconds := float64(resp.EvalDuration) / 1e9
		stats.TokensPerSecond = float64(resp.EvalCount) / seconds
	}

	return stats
}

// CalculateChatStats calculates inference statistics from a chat response
func CalculateChatStats(resp *ChatResponse, model string) InferenceStats {
	stats := InferenceStats{
		Model:              model,
		PromptTokens:       resp.PromptEvalCount,
		CompletionTokens:   resp.EvalCount,
		TotalTokens:        resp.PromptEvalCount + resp.EvalCount,
		PromptEvalDuration: resp.PromptEvalDuration,
		EvalDuration:       resp.EvalDuration,
		TotalDuration:      resp.TotalDuration,
	}

	// Calculate tokens per second
	if resp.EvalDuration > 0 {
		seconds := float64(resp.EvalDuration) / 1e9
		stats.TokensPerSecond = float64(resp.EvalCount) / seconds
	}

	return stats
}
