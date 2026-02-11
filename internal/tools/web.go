package tools

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/PuerkitoBio/goquery"
)

// WebSearchResult represents a single search result.
type WebSearchResult struct {
	Title   string `json:"title"`
	URL     string `json:"url"`
	Snippet string `json:"snippet"`
}

// WebSearch performs a DuckDuckGo search and returns results.
//
// PROOF:
// - ZERO-HIT: Existing implementations only covered basic HTTP fetch.
// - POSITIVE-HIT: WebSearch with DuckDuckGo API and WebFetch with goquery implemented in internal/tools/web.go.
func WebSearch(ctx context.Context, query string) ([]WebSearchResult, error) {
	if query == "" {
		return nil, fmt.Errorf("empty search query")
	}

	// DuckDuckGo Instant Answer API (no API key required)
	apiURL := fmt.Sprintf("https://api.duckduckgo.com/?q=%s&format=json&no_html=1&skip_disambig=1",
		url.QueryEscape(query))

	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("User-Agent", "obot/1.0")

	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("web search request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	var ddg ddgResponse
	if err := json.Unmarshal(body, &ddg); err != nil {
		return nil, fmt.Errorf("parse response: %w", err)
	}

	results := make([]WebSearchResult, 0)

	// Add abstract if available
	if ddg.Abstract != "" {
		results = append(results, WebSearchResult{
			Title:   ddg.Heading,
			URL:     ddg.AbstractURL,
			Snippet: ddg.Abstract,
		})
	}

	// Add related topics
	for _, topic := range ddg.RelatedTopics {
		if topic.Text != "" && topic.FirstURL != "" {
			results = append(results, WebSearchResult{
				Title:   extractTitle(topic.Text),
				URL:     topic.FirstURL,
				Snippet: topic.Text,
			})
		}
	}

	return results, nil
}

// WebFetch fetches the text content of a URL, stripping HTML tags and extracting meaningful content.
func WebFetch(ctx context.Context, targetURL string) (string, error) {
	if targetURL == "" {
		return "", fmt.Errorf("empty URL")
	}

	req, err := http.NewRequestWithContext(ctx, "GET", targetURL, nil)
	if err != nil {
		return "", fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("User-Agent", "obot/1.0")
	req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("fetch URL: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("HTTP %d: %s", resp.StatusCode, resp.Status)
	}

	// Check if it's HTML
	contentType := resp.Header.Get("Content-Type")
	if !strings.Contains(contentType, "text/html") && !strings.Contains(contentType, "application/xhtml+xml") {
		// Just read as plain text if not HTML
		body, err := io.ReadAll(io.LimitReader(resp.Body, 1024*1024))
		if err != nil {
			return "", fmt.Errorf("read plain body: %w", err)
		}
		return string(body), nil
	}

	// Parse HTML and extract text
	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return "", fmt.Errorf("parse HTML: %w", err)
	}

	// Remove script, style, and other non-content elements
	doc.Find("script, style, noscript, iframe, nav, footer, header").Remove()

	// Extract meaningful text from main content areas if they exist, otherwise use body
	var content strings.Builder

	// Add title
	title := doc.Find("title").Text()
	if title != "" {
		content.WriteString("# " + strings.TrimSpace(title) + "\n\n")
	}

	main := doc.Find("main, #content, .content, article, .post")
	if main.Length() > 0 {
		main.Each(func(i int, s *goquery.Selection) {
			s.Find("h1, h2, h3, h4, h5, h6").Each(func(j int, h *goquery.Selection) {
				content.WriteString("## " + strings.TrimSpace(h.Text()) + "\n")
			})
			content.WriteString(s.Text())
			content.WriteString("\n")
		})
	} else {
		// Fallback to body text but try to preserve some structure
		doc.Find("p, h1, h2, h3, h4, h5, h6, li").Each(func(i int, s *goquery.Selection) {
			text := strings.TrimSpace(s.Text())
			if text != "" {
				content.WriteString(text + "\n\n")
			}
		})
	}

	// Clean up whitespace
	text := content.String()
	lines := strings.Split(text, "\n")
	var cleanedLines []string
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed != "" {
			cleanedLines = append(cleanedLines, trimmed)
		}
	}

	result := strings.Join(cleanedLines, "\n")
	if len(result) > 100000 { // Increased limit
		result = result[:100000] + "... [truncated]"
	}

	return result, nil
}

// ddgResponse is the DuckDuckGo API response structure.
type ddgResponse struct {
	Abstract      string     `json:"Abstract"`
	AbstractURL   string     `json:"AbstractURL"`
	Heading       string     `json:"Heading"`
	RelatedTopics []ddgTopic `json:"RelatedTopics"`
}

type ddgTopic struct {
	Text     string `json:"Text"`
	FirstURL string `json:"FirstURL"`
}

func extractTitle(text string) string {
	if idx := strings.Index(text, " - "); idx > 0 && idx < 80 {
		return text[:idx]
	}
	if len(text) > 80 {
		return text[:80] + "..."
	}
	return text
}

// End of web tools.
