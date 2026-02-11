package git

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
)

// GitLabClient handles communication with the GitLab API.
type GitLabClient struct {
	token   string
	baseURL string
	client  *http.Client
}

// NewGitLabClient creates a new GitLab client, reading the token from the specified path.
func NewGitLabClient(tokenPath string) (*GitLabClient, error) {
	path := expandPath(tokenPath)
	tokenBytes, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read GitLab token: %w", err)
	}

	return &GitLabClient{
		token:   strings.TrimSpace(string(tokenBytes)),
		baseURL: "https://gitlab.com/api/v4",
		client:  &http.Client{},
	}, nil
}

// CreateRepository creates a new project/repository on GitLab.
func (c *GitLabClient) CreateRepository(name string) error {
	url := fmt.Sprintf("%s/projects", c.baseURL)

	payload := map[string]interface{}{
		"name":        name,
		"visibility":  "public",
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

	req.Header.Set("Private-Token", c.token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("failed to create GitLab repository: %s - %s", resp.Status, string(respBody))
	}

	return nil
}

// CreateMergeRequest is a stub for future implementation.
func (c *GitLabClient) CreateMergeRequest(projectID, sourceBranch, targetBranch, title string) error {
	return nil
}

// CreateIssue is a stub for future implementation.
func (c *GitLabClient) CreateIssue(projectID, title, description string) error {
	return nil
}

// ListBranches is a stub for future implementation.
func (c *GitLabClient) ListBranches(projectID string) ([]string, error) {
	return []string{"main"}, nil
}

// CreateRelease is a stub for future implementation.
func (c *GitLabClient) CreateRelease(projectID, tagName, description string) error {
	return nil
}
