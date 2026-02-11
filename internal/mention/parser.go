// Package mention implements mention parsing for user prompts.
package mention

import (
	"context"
	"fmt"
	"regexp"
	"strings"
	"sync"
)

// MentionType identifies the type of mention (e.g., @file, @bot).
type MentionType string

const (
	MentionFile      MentionType = "file"
	MentionBot       MentionType = "bot"
	MentionContext   MentionType = "context"
	MentionCodebase  MentionType = "codebase"
	MentionSelection MentionType = "selection"
	MentionClipboard MentionType = "clipboard"
	MentionRecent    MentionType = "recent"
	MentionGit       MentionType = "git"
	MentionURL       MentionType = "url"
	MentionPackage   MentionType = "package"
)

// Mention represents a parsed mention from a prompt.
type Mention struct {
	Type  MentionType
	Value string
	Raw   string
	Start int
	End   int
}

// Parser parses mentions from strings using regex and rules.
//
// PROOF:
// - ZERO-HIT: No existing mention parser implementation.
// - POSITIVE-HIT: Parser struct and mention type definitions in internal/mention/parser.go.
type Parser struct {
	mu sync.Mutex
	
	// Regex for detecting mentions
	mentionRegex *regexp.Regexp
}

// NewParser creates a new mention parser.
func NewParser() *Parser {
	return &Parser{
		// Supports: @type:value format using specific regex: @(\w+):(.+?)(\s|$)
		mentionRegex: regexp.MustCompile(`@(\w+):(.+?)(\s|$)`),
	}
}

// Parse extracts all mentions from a prompt using the specified regex pattern.
func (p *Parser) Parse(prompt string) []Mention {
	p.mu.Lock()
	defer p.mu.Unlock()

	// Find matches for @type:value
	matches := p.mentionRegex.FindAllStringSubmatchIndex(prompt, -1)
	mentions := make([]Mention, 0, len(matches))

	for _, m := range matches {
		raw := prompt[m[0]:m[1]]
		mType := prompt[m[2]:m[3]]
		mValue := prompt[m[4]:m[5]]
		
		mentionType, cleanValue := p.resolveType(mType, mValue)
		
		mentions = append(mentions, Mention{
			Type:  mentionType,
			Value: cleanValue,
			Raw:   strings.TrimSpace(raw),
			Start: m[0],
			End:   m[1],
		})
	}

	// Fallback/Legacy support for @file.go etc.
	legacyRegex := regexp.MustCompile(`@([a-zA-Z0-9_\-\.\/]+)`)
	legacyMatches := legacyRegex.FindAllStringSubmatchIndex(prompt, -1)
	
	for _, m := range legacyMatches {
		// Skip if already captured by the primary regex
		captured := false
		for _, existing := range mentions {
			if m[0] >= existing.Start && m[1] <= existing.End {
				captured = true
				break
			}
		}
		if captured { continue }

		raw := prompt[m[0]:m[1]]
		value := prompt[m[2]:m[3]]
		
		if strings.Contains(value, ":") { continue } // Handled by primary regex

		mentionType, cleanValue := p.classify(value)
		mentions = append(mentions, Mention{
			Type:  mentionType,
			Value: cleanValue,
			Raw:   raw,
			Start: m[0],
			End:   m[1],
		})
	}

	return mentions
}

// resolveType maps the regex groups to MentionType
func (p *Parser) resolveType(t, v string) (MentionType, string) {
	switch strings.ToLower(t) {
	case "file": return MentionFile, v
	case "bot": return MentionBot, v
	case "ctx", "context": return MentionContext, v
	case "git": return MentionGit, v
	case "pkg", "package": return MentionPackage, v
	case "url": return MentionURL, v
	default: return MentionType(t), v
	}
}

// classify determines the type of mention based on its value.
func (p *Parser) classify(value string) (MentionType, string) {
	lower := strings.ToLower(value)

	// Direct matches for types
	if strings.HasPrefix(lower, "file:") {
		return MentionFile, value[5:]
	}
	if strings.HasPrefix(lower, "bot:") {
		return MentionBot, value[4:]
	}
	if strings.HasPrefix(lower, "ctx:") || strings.HasPrefix(lower, "context:") {
		return MentionContext, value[strings.Index(value, ":")+1:]
	}
	if lower == "codebase" {
		return MentionCodebase, ""
	}
	if lower == "selection" {
		return MentionSelection, ""
	}
	if lower == "clipboard" {
		return MentionClipboard, ""
	}
	if lower == "recent" {
		return MentionRecent, ""
	}
	if strings.HasPrefix(lower, "git:") {
		return MentionGit, value[4:]
	}
	if strings.HasPrefix(lower, "http://") || strings.HasPrefix(lower, "https://") {
		return MentionURL, value
	}
	if strings.HasPrefix(lower, "pkg:") || strings.HasPrefix(lower, "package:") {
		return MentionPackage, value[strings.Index(value, ":")+1:]
	}

	// Implicit classification by suffix or content
	if strings.HasSuffix(lower, ".go") || strings.HasSuffix(lower, ".swift") || 
	   strings.HasSuffix(lower, ".md") || strings.Contains(lower, "/") {
		return MentionFile, value
	}

	if lower == "git" {
		return MentionGit, ""
	}

	return MentionBot, value
}

// Validate checks if a mention's value is valid for its type.
func (p *Parser) Validate(m Mention) bool {
	switch m.Type {
	case MentionFile:
		return len(m.Value) > 0
	case MentionBot:
		return len(m.Value) > 0
	case MentionURL:
		return strings.HasPrefix(m.Value, "http")
	case MentionGit:
		return true // Could be empty for current branch
	default:
		return true
	}
}

// StripMentions returns the prompt with all mentions removed.
func (p *Parser) StripMentions(prompt string) string {
	mentions := p.Parse(prompt)
	if len(mentions) == 0 {
		return prompt
	}

	// Work backwards to avoid shifting indices
	result := prompt
	for i := len(mentions) - 1; i >= 0; i-- {
		m := mentions[i]
		result = result[:m.Start] + result[m.End:]
	}

	return strings.TrimSpace(result)
}

// GetMentionsByType returns only mentions of a specific type.
func (p *Parser) GetMentionsByType(prompt string, mType MentionType) []Mention {
	all := p.Parse(prompt)
	filtered := make([]Mention, 0)
	for _, m := range all {
		if m.Type == mType {
			filtered = append(filtered, m)
		}
	}
	return filtered
}

// Resolver defines the interface for resolving mention values to actual content.
type Resolver interface {
	ReadFile(path string) (string, error)
	BuildCodebaseContext() (string, error)
	RunGitCommand(args []string) (string, error)
	GetClipboard() (string, error)
	GetRecentContext() (string, error)
}

// ResolveMention resolves a single mention to its actual content using the provided resolver.
func (p *Parser) ResolveMention(ctx context.Context, m Mention, r Resolver) (string, error) {
	if r == nil {
		return "", fmt.Errorf("no resolver provided")
	}

	switch m.Type {
	case MentionFile:
		return r.ReadFile(m.Value)
	case MentionCodebase:
		return r.BuildCodebaseContext()
	case MentionGit:
		args := []string{"show", "--summary"}
		if m.Value != "" {
			args = []string{"show", m.Value}
		}
		return r.RunGitCommand(args)
	case MentionClipboard:
		return r.GetClipboard()
	case MentionRecent:
		return r.GetRecentContext()
	case MentionContext:
		return fmt.Sprintf("Context ID: %s", m.Value), nil // Basic for now
	default:
		return fmt.Sprintf("[%s:%s]", m.Type, m.Value), nil
	}
}

// Result contains the parsing outcome and analysis.
type Result struct {
	Original string
	Cleaned  string
	Mentions []Mention
	Counts   map[MentionType]int
}

// Analyze returns a detailed result of the parsing.
func (p *Parser) Analyze(prompt string) *Result {
	mentions := p.Parse(prompt)
	counts := make(map[MentionType]int)
	for _, m := range mentions {
		counts[m.Type]++
	}

	return &Result{
		Original: prompt,
		Cleaned:  p.StripMentions(prompt),
		Mentions: mentions,
		Counts:   counts,
	}
}

// FormatSummary returns a human-readable summary of parsed mentions.
func (r *Result) FormatSummary() string {
	if len(r.Mentions) == 0 {
		return "No mentions found."
	}

	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("Found %d mention(s):\n", len(r.Mentions)))
	for _, m := range r.Mentions {
		val := m.Value
		if val == "" {
			val = "(default)"
		}
		sb.WriteString(fmt.Sprintf("- [%s] %s\n", m.Type, val))
	}
	return sb.String()
}
