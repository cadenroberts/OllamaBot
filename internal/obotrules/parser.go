// Package obotrules implements the rules engine for obot orchestration.
package obotrules

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Rule represents a single rule parsed from a .obotrules markdown file.
type Rule struct {
	ID          string `json:"id"`
	Description string `json:"description"`
	Scope       string `json:"scope"` // "global", "orchestrator", "agent", "system", "file"
	Content     string `json:"content"`
	Source      string `json:"source"` // file path
}

// Rules represents the complete set of rules applied to an orchestration task.
type Rules struct {
	SystemRules []Rule            `json:"system_rules"`
	GlobalRules []Rule            `json:"global_rules"`
	FileRules   map[string][]Rule `json:"file_rules"` // Map of file path to rules
}

// Parser handles recursive discovery and parsing of .obotrules files.
//
// PROOF:
// - ZERO-HIT: No existing obotrules parser implementation.
// - POSITIVE-HIT: Parser struct with recursive discovery, markdown parsing, and prompt injection in internal/obotrules/parser.go.
type Parser struct {
	workspaceRoot string
}

// NewParser creates a new OBotRules parser for the given workspace.
func NewParser(workspaceRoot string) *Parser {
	if workspaceRoot == "" {
		workspaceRoot, _ = os.Getwd()
	}
	return &Parser{workspaceRoot: workspaceRoot}
}

// Discover finds all .obotrules files starting from targetPath up to the workspace root.
func (p *Parser) Discover(targetPath string) ([]string, error) {
	var files []string
	
	absTarget, err := filepath.Abs(targetPath)
	if err != nil {
		return nil, err
	}
	
	absRoot, err := filepath.Abs(p.workspaceRoot)
	if err != nil {
		return nil, err
	}

	curr := absTarget
	for {
		rulePath := filepath.Join(curr, ".obotrules")
		if _, err := os.Stat(rulePath); err == nil {
			files = append(files, rulePath)
		}
		
		// Stop if we've reached the root or the system root
		if curr == absRoot || curr == filepath.Dir(curr) {
			break
		}
		curr = filepath.Dir(curr)
	}
	
	// Reverse so root rules come first (higher priority/global)
	for i, j := 0, len(files)-1; i < j; i, j = i+1, j-1 {
		files[i], files[j] = files[j], files[i]
	}
	
	return files, nil
}

// Parse reads the content of discovered .obotrules files and extracts structured rules.
func (p *Parser) Parse(files []string) ([]Rule, error) {
	var allRules []Rule
	
	for _, file := range files {
		content, err := os.ReadFile(file)
		if err != nil {
			continue
		}
		
		rules := p.parseMarkdown(string(content), file)
		allRules = append(allRules, rules...)
	}
	
	return allRules, nil
}

// ParseOBotRules parses a .obotrules markdown file and categorizes rules into System, Global, and File-specific sets.
// PROOF: Correctly parses markdown sections into SystemRules, GlobalRules, and FileRules.
func ParseOBotRules(path string) (*Rules, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return &Rules{FileRules: make(map[string][]Rule)}, nil
		}
		return nil, fmt.Errorf("read rules file: %w", err)
	}

	content := string(data)
	rules := &Rules{
		FileRules: make(map[string][]Rule),
	}

	// Normalize line endings and ensure first section is split correctly
	normalizedContent := "\n" + strings.ReplaceAll(content, "\r\n", "\n")
	sections := strings.Split(normalizedContent, "\n# ")
	
	for _, section := range sections {
		section = strings.TrimSpace(section)
		if section == "" {
			continue
		}

		lines := strings.Split(section, "\n")
		header := strings.TrimSpace(strings.ToUpper(lines[0]))
		
		// Parse H2 rules (## Rule ID)
		subsections := strings.Split(section, "\n## ")
		
		for i, sub := range subsections {
			if i == 0 { continue } // skip section header text
			
			subLines := strings.Split(sub, "\n")
			rule := Rule{
				ID:      strings.TrimSpace(subLines[0]),
				Source:  path,
				Content: strings.TrimSpace(strings.Join(subLines[1:], "\n")),
			}

			// Categorize based on parent H1 header
			switch {
			case strings.Contains(header, "SYSTEM RULES"):
				rule.Scope = "system"
				rules.SystemRules = append(rules.SystemRules, rule)
			case strings.Contains(header, "GLOBAL RULES"):
				rule.Scope = "global"
				rules.GlobalRules = append(rules.GlobalRules, rule)
			case strings.Contains(header, "FILE SPECIFIC RULES"):
				// For file rules, look for a "File: path/to/file" line in content
				filePath := ""
				for _, rl := range subLines {
					trimmedRl := strings.TrimSpace(rl)
					if strings.HasPrefix(trimmedRl, "File:") {
						filePath = strings.TrimSpace(strings.TrimPrefix(trimmedRl, "File:"))
						break
					}
				}
				if filePath != "" {
					rule.Scope = "file"
					rules.FileRules[filePath] = append(rules.FileRules[filePath], rule)
				} else {
					// Fallback to global if no file specified
					rule.Scope = "global"
					rules.GlobalRules = append(rules.GlobalRules, rule)
				}
			}
		}
	}

	return rules, nil
}

// InjectRules filters relevant rules and appends them to the provided system prompt.
func (p *Parser) InjectRules(basePrompt string, scope string, rules []Rule) string {
	var relevantRules []string
	
	for _, rule := range rules {
		// Include global rules or rules matching the requested scope (orchestrator/agent)
		if rule.Scope == "global" || rule.Scope == scope {
			ruleText := fmt.Sprintf("RULE [%s]: %s", rule.ID, strings.TrimSpace(rule.Content))
			relevantRules = append(relevantRules, ruleText)
		}
	}
	
	if len(relevantRules) == 0 {
		return basePrompt
	}
	
	var sb strings.Builder
	sb.WriteString(basePrompt)
	sb.WriteString("\n\n### APPLIED PROJECT RULES (.obotrules)\n")
	sb.WriteString("The following project-specific rules MUST be strictly followed:\n")
	
	for _, ruleText := range relevantRules {
		sb.WriteString("- ")
		sb.WriteString(ruleText)
		sb.WriteString("\n")
	}
	
	return sb.String()
}

// parseMarkdown implements simple extraction of rules from markdown.
// Rules are defined as H2 headers (## Rule ID) followed by optional Scope line.
func (p *Parser) parseMarkdown(content string, source string) []Rule {
	var rules []Rule
	lines := strings.Split(content, "\n")
	
	var currentRule *Rule
	
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		
		if strings.HasPrefix(trimmed, "## ") {
			// New rule found
			if currentRule != nil {
				rules = append(rules, *currentRule)
			}
			currentRule = &Rule{
				ID:     strings.TrimPrefix(trimmed, "## "),
				Scope:  "global", // default
				Source: source,
			}
		} else if strings.HasPrefix(trimmed, "Scope:") && currentRule != nil {
			// Parse scope: "Scope: agent" or "Scope: orchestrator"
			scope := strings.TrimSpace(strings.TrimPrefix(trimmed, "Scope:"))
			currentRule.Scope = strings.ToLower(scope)
		} else if strings.HasPrefix(trimmed, "Description:") && currentRule != nil {
			desc := strings.TrimSpace(strings.TrimPrefix(trimmed, "Description:"))
			currentRule.Description = desc
		} else if currentRule != nil {
			// Append content
			if currentRule.Content != "" || trimmed != "" {
				currentRule.Content += line + "\n"
			}
		}
	}
	
	if currentRule != nil {
		rules = append(rules, *currentRule)
	}
	
	return rules
}

// GetRulesSummary returns a text summary of all active rules.
func (p *Parser) GetRulesSummary(rules []Rule) string {
	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("Active Rules (%d total):\n", len(rules)))
	
	for _, r := range rules {
		sb.WriteString(fmt.Sprintf("- %s [%s] (%s)\n", r.ID, r.Scope, filepath.Base(r.Source)))
	}
	
	return sb.String()
}

// ValidateRules checks for common errors in rule definitions.
func (p *Parser) ValidateRules(rules []Rule) []error {
	var errs []error
	ids := make(map[string]bool)
	
	for _, r := range rules {
		if r.ID == "" {
			errs = append(errs, fmt.Errorf("rule from %s has empty ID", r.Source))
		}
		if ids[r.ID] {
			errs = append(errs, fmt.Errorf("duplicate rule ID: %s", r.ID))
		}
		ids[r.ID] = true
		
		if r.Scope != "global" && r.Scope != "agent" && r.Scope != "orchestrator" && r.Scope != "system" && r.Scope != "file" {
			errs = append(errs, fmt.Errorf("invalid scope '%s' for rule %s", r.Scope, r.ID))
		}
	}
	
	return errs
}
