package ollama

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

// StreamCallback is called for each token received
type StreamCallback func(token string)

// StreamResult contains the final result of a streaming request
type StreamResult struct {
	Content string
	Stats   *InferenceStats
	Error   error
}

// GenerateStream sends a prompt and streams the response
func (c *Client) GenerateStream(ctx context.Context, prompt string, callback StreamCallback) (*StreamResult, error) {
	reqBody := GenerateRequest{
		Model:     c.model,
		Prompt:    prompt,
		Stream:    true,
		Options:   c.options,
		KeepAlive: "30m",
	}

	body, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", c.baseURL+"/api/generate", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API error (status %d): %s", resp.StatusCode, string(respBody))
	}

	return c.processGenerateStream(resp.Body, callback)
}

// processGenerateStream processes the streaming response body
func (c *Client) processGenerateStream(body io.Reader, callback StreamCallback) (*StreamResult, error) {
	result := &StreamResult{}
	var fullContent string
	var lastResp GenerateResponse

	scanner := bufio.NewScanner(body)
	// Increase buffer size for large responses
	buf := make([]byte, 0, 64*1024)
	scanner.Buffer(buf, 1024*1024)

	for scanner.Scan() {
		line := scanner.Bytes()
		if len(line) == 0 {
			continue
		}

		var genResp GenerateResponse
		if err := json.Unmarshal(line, &genResp); err != nil {
			// Skip malformed lines
			continue
		}

		// Accumulate content
		fullContent += genResp.Response

		// Call callback with new token
		if callback != nil && genResp.Response != "" {
			callback(genResp.Response)
		}

		// Store last response for stats
		if genResp.Done {
			lastResp = genResp
		}
	}

	if err := scanner.Err(); err != nil {
		result.Error = fmt.Errorf("stream read error: %w", err)
		return result, result.Error
	}

	result.Content = fullContent
	stats := CalculateStats(&lastResp, c.model)
	result.Stats = &stats

	return result, nil
}

// ChatStream sends messages and streams the response
func (c *Client) ChatStream(ctx context.Context, messages []Message, callback StreamCallback) (*StreamResult, error) {
	reqBody := ChatRequest{
		Model:     c.model,
		Messages:  messages,
		Stream:    true,
		Options:   c.options,
		KeepAlive: "30m",
	}

	body, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", c.baseURL+"/api/chat", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API error (status %d): %s", resp.StatusCode, string(respBody))
	}

	return c.processChatStream(resp.Body, callback)
}

// processChatStream processes the streaming chat response body
func (c *Client) processChatStream(body io.Reader, callback StreamCallback) (*StreamResult, error) {
	result := &StreamResult{}
	var fullContent string
	var lastResp ChatResponse

	scanner := bufio.NewScanner(body)
	buf := make([]byte, 0, 64*1024)
	scanner.Buffer(buf, 1024*1024)

	for scanner.Scan() {
		line := scanner.Bytes()
		if len(line) == 0 {
			continue
		}

		var chatResp ChatResponse
		if err := json.Unmarshal(line, &chatResp); err != nil {
			continue
		}

		// Accumulate content
		fullContent += chatResp.Message.Content

		// Call callback with new token
		if callback != nil && chatResp.Message.Content != "" {
			callback(chatResp.Message.Content)
		}

		// Store last response for stats
		if chatResp.Done {
			lastResp = chatResp
		}
	}

	if err := scanner.Err(); err != nil {
		result.Error = fmt.Errorf("stream read error: %w", err)
		return result, result.Error
	}

	result.Content = fullContent
	stats := CalculateChatStats(&lastResp, c.model)
	result.Stats = &stats

	return result, nil
}

// GenerateStreamChan returns a channel that receives tokens
func (c *Client) GenerateStreamChan(ctx context.Context, prompt string) (<-chan string, <-chan *StreamResult) {
	tokenCh := make(chan string, 100)
	resultCh := make(chan *StreamResult, 1)

	go func() {
		defer close(tokenCh)
		defer close(resultCh)

		result, err := c.GenerateStream(ctx, prompt, func(token string) {
			select {
			case tokenCh <- token:
			case <-ctx.Done():
				return
			}
		})

		if err != nil {
			resultCh <- &StreamResult{Error: err}
			return
		}

		resultCh <- result
	}()

	return tokenCh, resultCh
}

// ChatStreamChan returns a channel that receives tokens
func (c *Client) ChatStreamChan(ctx context.Context, messages []Message) (<-chan string, <-chan *StreamResult) {
	tokenCh := make(chan string, 100)
	resultCh := make(chan *StreamResult, 1)

	go func() {
		defer close(tokenCh)
		defer close(resultCh)

		result, err := c.ChatStream(ctx, messages, func(token string) {
			select {
			case tokenCh <- token:
			case <-ctx.Done():
				return
			}
		})

		if err != nil {
			resultCh <- &StreamResult{Error: err}
			return
		}

		resultCh <- result
	}()

	return tokenCh, resultCh
}
