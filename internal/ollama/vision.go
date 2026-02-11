// Package ollama implements the Ollama API client with multimodal support.
package ollama

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// GenerateWithVision sends a prompt and one or more images to the vision model.
// Images are automatically read from the provided file paths and base64 encoded.
//
// This extends the Ollama client for multimodal capabilities.
func (c *Client) GenerateWithVision(ctx context.Context, prompt string, imagePaths []string) (string, *InferenceStats, error) {
	if len(imagePaths) == 0 {
		return c.Generate(ctx, prompt)
	}

	encodedImages := make([]string, 0, len(imagePaths))
	for _, path := range imagePaths {
		data, err := os.ReadFile(path)
		if err != nil {
			return "", nil, fmt.Errorf("failed to read image file %s: %w", path, err)
		}
		
		// Validate file extension
		ext := strings.ToLower(filepath.Ext(path))
		if ext != ".jpg" && ext != ".jpeg" && ext != ".png" && ext != ".webp" {
			return "", nil, fmt.Errorf("unsupported image format: %s (supported: jpg, png, webp)", ext)
		}

		encodedImages = append(encodedImages, base64.StdEncoding.EncodeToString(data))
	}

	reqBody := GenerateRequest{
		Model:     c.model,
		Prompt:    prompt,
		Images:    encodedImages,
		Stream:    false,
		Options:   c.options,
		KeepAlive: "30m",
	}

	return c.visionRequest(ctx, "/api/generate", reqBody)
}

// visionRequest performs the actual HTTP request for vision operations.
func (c *Client) visionRequest(ctx context.Context, path string, reqBody interface{}) (string, *InferenceStats, error) {
	body, err := json.Marshal(reqBody)
	if err != nil {
		return "", nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	url := c.baseURL + path
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(body))
	if err != nil {
		return "", nil, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	// Set a longer timeout for vision tasks if not already set
	client := c.httpClient
	if client.Timeout < 10*time.Minute {
		newClient := *client
		newClient.Timeout = 10 * time.Minute
		client = &newClient
	}

	resp, err := client.Do(req)
	if err != nil {
		return "", nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return "", nil, fmt.Errorf("API error (status %d): %s", resp.StatusCode, string(respBody))
	}

	// For vision, we usually use /api/generate
	var genResp GenerateResponse
	if err := json.NewDecoder(resp.Body).Decode(&genResp); err != nil {
		return "", nil, fmt.Errorf("failed to decode response: %w", err)
	}

	stats := CalculateStats(&genResp, c.model)
	return genResp.Response, &stats, nil
}

// AnalyzeUI uses the vision model to analyze a UI screenshot or component.
func (c *Client) AnalyzeUI(ctx context.Context, screenshotPath string, componentName string) (string, error) {
	prompt := fmt.Sprintf(`Analyze the following UI component: %s. 
Please describe:
1. Visual layout and alignment.
2. Color scheme and contrast.
3. Accessibility concerns.
4. Any inconsistencies with standard UI patterns.
5. Suggestions for improvement.`, componentName)

	resp, _, err := c.GenerateWithVision(ctx, prompt, []string{screenshotPath})
	return resp, err
}

// CompareImages uses the vision model to compare two images (e.g., mockup vs implementation).
func (c *Client) CompareImages(ctx context.Context, mockupPath, actualPath string) (string, error) {
	prompt := `Compare these two images. 
Image 1 is the design mockup.
Image 2 is the actual implementation.
Identify any visual differences, alignment issues, or missing elements.`

	resp, _, err := c.GenerateWithVision(ctx, prompt, []string{mockupPath, actualPath})
	return resp, err
}

// VisionHealthCheck verifies that the vision model is responsive.
func (c *Client) VisionHealthCheck(ctx context.Context) error {
	// A tiny 1x1 black pixel PNG in base64
	tinyPixel := "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="
	
	reqBody := GenerateRequest{
		Model:     c.model,
		Prompt:    "What is in this image?",
		Images:    []string{tinyPixel},
		Stream:    false,
		Options:   map[string]any{"num_predict": 10},
		KeepAlive: "1m",
	}

	_, _, err := c.visionRequest(ctx, "/api/generate", reqBody)
	return err
}

// GetVisionCapabilities returns the capabilities of the current vision model.
func (c *Client) GetVisionCapabilities() []string {
	return []string{
		"OCR",
		"Object Detection",
		"UI Analysis",
		"Image Comparison",
		"Color Analysis",
	}
}
