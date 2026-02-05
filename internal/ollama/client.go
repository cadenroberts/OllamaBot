package ollama

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// DefaultBaseURL is the default Ollama server URL
const DefaultBaseURL = "http://localhost:11434"

// Client is an HTTP client for the Ollama API
type Client struct {
	baseURL    string
	httpClient *http.Client
	model      string
	options    map[string]any
}

// ClientOption configures the client
type ClientOption func(*Client)

// WithBaseURL sets a custom base URL
func WithBaseURL(url string) ClientOption {
	return func(c *Client) {
		c.baseURL = url
	}
}

// WithModel sets the default model
func WithModel(model string) ClientOption {
	return func(c *Client) {
		c.model = model
	}
}

// WithTimeout sets the HTTP timeout
func WithTimeout(timeout time.Duration) ClientOption {
	return func(c *Client) {
		c.httpClient.Timeout = timeout
	}
}

// WithOptions sets default generation options
func WithOptions(opts map[string]any) ClientOption {
	return func(c *Client) {
		c.options = opts
	}
}

// NewClient creates a new Ollama client
func NewClient(opts ...ClientOption) *Client {
	c := &Client{
		baseURL: DefaultBaseURL,
		httpClient: &http.Client{
			Timeout: 5 * time.Minute, // Long timeout for generation
		},
		options: make(map[string]any),
	}

	for _, opt := range opts {
		opt(c)
	}

	return c
}

// SetModel sets the model to use for requests
func (c *Client) SetModel(model string) {
	c.model = model
}

// GetModel returns the current model
func (c *Client) GetModel() string {
	return c.model
}

// BaseURL returns the configured base URL
func (c *Client) BaseURL() string {
	return c.baseURL
}

// CheckConnection checks if Ollama is running and accessible
func (c *Client) CheckConnection(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, "GET", c.baseURL+"/api/tags", nil)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("ollama not reachable at %s: %w", c.baseURL, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("ollama returned status %d", resp.StatusCode)
	}

	return nil
}

// ListModels returns available models
func (c *Client) ListModels(ctx context.Context) ([]ModelInfo, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", c.baseURL+"/api/tags", nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API error (status %d): %s", resp.StatusCode, string(body))
	}

	var tagsResp TagsResponse
	if err := json.NewDecoder(resp.Body).Decode(&tagsResp); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return tagsResp.Models, nil
}

// HasModel checks if a specific model is available
func (c *Client) HasModel(ctx context.Context, model string) (bool, error) {
	models, err := c.ListModels(ctx)
	if err != nil {
		return false, err
	}

	for _, m := range models {
		if m.Name == model {
			return true, nil
		}
	}
	return false, nil
}

// Generate sends a prompt and returns the complete response (non-streaming)
func (c *Client) Generate(ctx context.Context, prompt string) (string, *InferenceStats, error) {
	reqBody := GenerateRequest{
		Model:     c.model,
		Prompt:    prompt,
		Stream:    false,
		Options:   c.options,
		KeepAlive: "30m",
	}

	body, err := json.Marshal(reqBody)
	if err != nil {
		return "", nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", c.baseURL+"/api/generate", bytes.NewReader(body))
	if err != nil {
		return "", nil, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return "", nil, fmt.Errorf("API error (status %d): %s", resp.StatusCode, string(respBody))
	}

	var genResp GenerateResponse
	if err := json.NewDecoder(resp.Body).Decode(&genResp); err != nil {
		return "", nil, fmt.Errorf("failed to decode response: %w", err)
	}

	stats := CalculateStats(&genResp, c.model)
	return genResp.Response, &stats, nil
}

// Chat sends messages and returns the complete response (non-streaming)
func (c *Client) Chat(ctx context.Context, messages []Message) (string, *InferenceStats, error) {
	reqBody := ChatRequest{
		Model:     c.model,
		Messages:  messages,
		Stream:    false,
		Options:   c.options,
		KeepAlive: "30m",
	}

	body, err := json.Marshal(reqBody)
	if err != nil {
		return "", nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", c.baseURL+"/api/chat", bytes.NewReader(body))
	if err != nil {
		return "", nil, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return "", nil, fmt.Errorf("API error (status %d): %s", resp.StatusCode, string(respBody))
	}

	var chatResp ChatResponse
	if err := json.NewDecoder(resp.Body).Decode(&chatResp); err != nil {
		return "", nil, fmt.Errorf("failed to decode response: %w", err)
	}

	stats := CalculateChatStats(&chatResp, c.model)
	return chatResp.Message.Content, &stats, nil
}

// SetOption sets a generation option
func (c *Client) SetOption(key string, value any) {
	c.options[key] = value
}

// SetTemperature sets the temperature for generation
func (c *Client) SetTemperature(temp float64) {
	c.options["temperature"] = temp
}

// SetContextWindow sets the context window size
func (c *Client) SetContextWindow(size int) {
	c.options["num_ctx"] = size
}

// SetMaxTokens sets the maximum tokens to generate
func (c *Client) SetMaxTokens(max int) {
	c.options["num_predict"] = max
}
