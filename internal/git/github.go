package git

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

// GitHubClient handles communication with the GitHub API.
type GitHubClient struct {
	token   string
	baseURL string
	client  *http.Client
}

// NewGitHubClient creates a new GitHub client, reading the token from the specified path.
func NewGitHubClient(tokenPath string) (*GitHubClient, error) {
	path := expandPath(tokenPath)
	tokenBytes, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read GitHub token: %w", err)
	}

	return &GitHubClient{
		token:   strings.TrimSpace(string(tokenBytes)),
		baseURL: "https://api.github.com",
		client:  &http.Client{},
	}, nil
}

// setAuthHeader sets the Authorization header for GitHub API requests.
func (c *GitHubClient) setAuthHeader(req *http.Request) {
	req.Header.Set("Authorization", "token "+c.token)
}

// CreateRepository creates a new repository on GitHub.
func (c *GitHubClient) CreateRepository(name string) error {
	url := fmt.Sprintf("%s/user/repos", c.baseURL)

	payload := map[string]interface{}{
		"name":        name,
		"private":     false,
		"auto_init":   false,
		"description": "Created by obot orchestration",
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(body))
	if err != nil {
		return err
	}

	c.setAuthHeader(req)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("failed to create GitHub repository: %s - %s", resp.Status, string(respBody))
	}

	return nil
}

// CreatePullRequest creates a new pull request on GitHub.
func (c *GitHubClient) CreatePullRequest(owner, repo, title, body, head, base string) (string, error) {
	url := fmt.Sprintf("%s/repos/%s/%s/pulls", c.baseURL, owner, repo)

	payload := map[string]interface{}{
		"title": title,
		"body":  body,
		"head":  head,
		"base":  base,
	}

	jsonBody, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
	if err != nil {
		return "", err
	}

	c.setAuthHeader(req)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		respBody, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("failed to create pull request: %s - %s", resp.Status, string(respBody))
	}

	var result struct {
		HTMLURL string `json:"html_url"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}

	return result.HTMLURL, nil
}

// CreateIssue creates a new issue on GitHub.
func (c *GitHubClient) CreateIssue(owner, repo, title, body string) (int, error) {
	url := fmt.Sprintf("%s/repos/%s/%s/issues", c.baseURL, owner, repo)

	payload := map[string]interface{}{
		"title": title,
		"body":  body,
	}

	jsonBody, err := json.Marshal(payload)
	if err != nil {
		return 0, err
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
	if err != nil {
		return 0, err
	}

	c.setAuthHeader(req)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		respBody, _ := io.ReadAll(resp.Body)
		return 0, fmt.Errorf("failed to create issue: %s - %s", resp.Status, string(respBody))
	}

	var result struct {
		Number int `json:"number"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return 0, err
	}

	return result.Number, nil
}

// GetRepository retrieves repository information.
func (c *GitHubClient) GetRepository(owner, repo string) (map[string]interface{}, error) {
	url := fmt.Sprintf("%s/repos/%s/%s", c.baseURL, owner, repo)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}

	c.setAuthHeader(req)

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to get repository: %s", resp.Status)
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}

	return result, nil
}

// GetFileContent retrieves the content of a file from a repository.
func (c *GitHubClient) GetFileContent(owner, repo, path string) (string, error) {
	url := fmt.Sprintf("%s/repos/%s/%s/contents/%s", c.baseURL, owner, repo, path)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", err
	}

	c.setAuthHeader(req)
	req.Header.Set("Accept", "application/vnd.github.v3.raw")

	resp, err := c.client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("failed to get file content: %s", resp.Status)
	}

	content, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	return string(content), nil
}

// ListRepositories lists the repositories for the authenticated user.
func (c *GitHubClient) ListRepositories() ([]string, error) {
	url := fmt.Sprintf("%s/user/repos", c.baseURL)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}

	c.setAuthHeader(req)

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to list repositories: %s", resp.Status)
	}

	var repos []struct {
		FullName string `json:"full_name"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&repos); err != nil {
		return nil, err
	}

	names := make([]string, len(repos))
	for i, r := range repos {
		names[i] = r.FullName
	}

	return names, nil
}

// AddIssueComment adds a comment to an existing issue or pull request.
func (c *GitHubClient) AddIssueComment(owner, repo string, issueNumber int, body string) error {
	url := fmt.Sprintf("%s/repos/%s/%s/issues/%d/comments", c.baseURL, owner, repo, issueNumber)

	payload := map[string]interface{}{
		"body": body,
	}

	jsonBody, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
	if err != nil {
		return err
	}

	c.setAuthHeader(req)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("failed to add comment: %s - %s", resp.Status, string(respBody))
	}

	return nil
}

// ListBranches lists branches for a repository.
func (c *GitHubClient) ListBranches(owner, repo string) ([]string, error) {
	url := fmt.Sprintf("%s/repos/%s/%s/branches", c.baseURL, owner, repo)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}

	c.setAuthHeader(req)

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("failed to list branches: %s - %s", resp.Status, string(respBody))
	}

	var branches []struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&branches); err != nil {
		return nil, err
	}

	names := make([]string, len(branches))
	for i, b := range branches {
		names[i] = b.Name
	}
	return names, nil
}

// CreateRelease creates a new release on GitHub.
func (c *GitHubClient) CreateRelease(owner, repo, tag, title, body string) error {
	url := fmt.Sprintf("%s/repos/%s/%s/releases", c.baseURL, owner, repo)

	payload := map[string]interface{}{
		"tag_name": tag,
		"name":     title,
		"body":     body,
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return err
	}

	c.setAuthHeader(req)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("failed to create release: %s - %s", resp.Status, string(respBody))
	}

	return nil
}

// expandPath expands the tilde (~) in a file path to the user's home directory.
func expandPath(path string) string {
	if strings.HasPrefix(path, "~") {
		home, err := os.UserHomeDir()
		if err != nil {
			return path
		}
		return filepath.Join(home, path[1:])
	}
	return path
}
