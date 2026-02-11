// Package intent implements intent routing for obot orchestration.
package intent

import (
	"fmt"
	"sort"
	"strings"
	"sync"

	"github.com/croberts/obot/internal/orchestrate"
)

// IntentType identifies the classified intent of a user prompt.
type IntentType string

const (
	IntentCoding   IntentType = "coding"
	IntentResearch IntentType = "research"
	IntentWriting  IntentType = "writing"
	IntentVision   IntentType = "vision"
	IntentUnknown  IntentType = "unknown"
)

// ClassificationResult contains the details of an intent classification.
type ClassificationResult struct {
	Intent     IntentType
	Confidence float64
	Scores     map[IntentType]float64
	MatchedKeywords map[IntentType][]string
	Prompt     string
}

// Router classifies user prompts into intents using keyword analysis and scoring.
//
// PROOF:
// - ZERO-HIT: No existing intent router implementation.
// - POSITIVE-HIT: Router struct and keyword classification in internal/intent/router.go.
type Router struct {
	mu sync.Mutex
	
	// Keywords for classification
	keywords map[IntentType][]string
	
	// Weights for scoring
	weights map[IntentType]float64
}

// NewRouter creates a new intent router with default keywords and weights.
func NewRouter() *Router {
	r := &Router{
		keywords: make(map[IntentType][]string),
		weights:  make(map[IntentType]float64),
	}

	// Default keywords
	r.keywords[IntentCoding] = []string{
		"implement", "fix", "refactor", "code", "bug", "build", "test", 
		"feature", "function", "class", "method", "variable", "script",
		"compile", "debug", "deployment", "github", "git", "repo", "pr",
	}
	r.keywords[IntentResearch] = []string{
		"explain", "analyze", "how", "what", "why", "research", "search", 
		"find", "crawl", "web", "docs", "documentation", "tutorial",
		"investigate", "compare", "evaluate", "summary", "information",
	}
	r.keywords[IntentWriting] = []string{
		"document", "draft", "write", "comment", "readme", "text", 
		"description", "blog", "article", "email", "report", "memo",
		"essay", "note", "content", "copy", "grammar", "style",
	}
	r.keywords[IntentVision] = []string{
		"image", "screenshot", "ui", "visual", "look", "see", "layout", 
		"design", "color", "font", "css", "styling", "appearance",
		"icon", "logo", "button", "screenshot", "display", "view",
	}

	// Default weights
	r.weights[IntentCoding] = 1.0
	r.weights[IntentResearch] = 1.0
	r.weights[IntentWriting] = 1.0
	r.weights[IntentVision] = 1.2 // Vision keywords are often very specific

	return r
}

// Route classifies the prompt and returns the detected intent.
func (r *Router) Route(prompt string) IntentType {
	result := r.Classify(prompt)
	return result.Intent
}

// Classify performs a detailed classification of the prompt.
func (r *Router) Classify(prompt string) *ClassificationResult {
	r.mu.Lock()
	defer r.mu.Unlock()

	promptLower := strings.ToLower(prompt)
	scores := make(map[IntentType]float64)
	matchedKeywords := make(map[IntentType][]string)

	for intent, keywords := range r.keywords {
		score := 0.0
		for _, kw := range keywords {
			if strings.Contains(promptLower, kw) {
				score += 1.0
				matchedKeywords[intent] = append(matchedKeywords[intent], kw)
			}
		}
		scores[intent] = score * r.weights[intent]
	}

	// Find top intent
	var topIntent IntentType = IntentUnknown
	maxScore := 0.0
	totalScore := 0.0

	for intent, score := range scores {
		totalScore += score
		if score > maxScore {
			maxScore = score
			topIntent = intent
		}
	}

	confidence := 0.0
	if totalScore > 0 {
		confidence = maxScore / totalScore
	}

	return &ClassificationResult{
		Intent:          topIntent,
		Confidence:      confidence,
		Scores:          scores,
		MatchedKeywords: matchedKeywords,
		Prompt:          prompt,
	}
}

// AddKeywords adds new keywords to a specific intent.
func (r *Router) AddKeywords(intent IntentType, keywords ...string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.keywords[intent] = append(r.keywords[intent], keywords...)
}

// SetWeight sets the scoring weight for a specific intent.
func (r *Router) SetWeight(intent IntentType, weight float64) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.weights[intent] = weight
}

// GetModelForIntent returns the recommended model type for a given intent.
func (r *Router) GetModelForIntent(intent IntentType) orchestrate.ModelType {
	switch intent {
	case IntentCoding:
		return orchestrate.ModelCoder
	case IntentResearch:
		return orchestrate.ModelResearcher
	case IntentVision:
		return orchestrate.ModelVision
	case IntentWriting:
		return orchestrate.ModelCoder
	default:
		return orchestrate.ModelOrchestrator
	}
}

// RecommendSchedule returns the most appropriate starting schedule for an intent.
func (r *Router) RecommendSchedule(intent IntentType) orchestrate.ScheduleID {
	switch intent {
	case IntentCoding:
		return orchestrate.ScheduleImplement
	case IntentResearch:
		return orchestrate.ScheduleKnowledge
	case IntentVision:
		return orchestrate.ScheduleProduction // Vision often used in Production/Harmonize
	case IntentWriting:
		return orchestrate.SchedulePlan
	default:
		return orchestrate.ScheduleKnowledge
	}
}

// Explain returns a human-readable explanation of the classification.
func (r *ClassificationResult) Explain() string {
	if r.Intent == IntentUnknown {
		return "Could not determine intent from prompt."
	}

	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("Detected intent: %s (confidence: %.2f)\n", r.Intent, r.Confidence))
	
	if keywords, ok := r.MatchedKeywords[r.Intent]; ok && len(keywords) > 0 {
		sb.WriteString(fmt.Sprintf("Matched keywords: %s\n", strings.Join(keywords, ", ")))
	}

	// Show other possible intents if they had scores
	var others []IntentType
	for intent, score := range r.Scores {
		if intent != r.Intent && score > 0 {
			others = append(others, intent)
		}
	}

	if len(others) > 0 {
		sort.Slice(others, func(i, j int) bool {
			return r.Scores[others[i]] > r.Scores[others[j]]
		})
		sb.WriteString("Other possibilities:\n")
		for _, intent := range others {
			sb.WriteString(fmt.Sprintf("- %s (score: %.1f)\n", intent, r.Scores[intent]))
		}
	}

	return sb.String()
}

// GetFormattedReport returns a professional report of the classification.
func (r *ClassificationResult) GetFormattedReport() string {
	report := "--- Intent Classification Report ---\n"
	report += fmt.Sprintf("Prompt: %s\n", r.Prompt)
	report += r.Explain()
	report += "-----------------------------------\n"
	return report
}

// IsAmbiguous returns true if the classification confidence is below a threshold.
func (r *ClassificationResult) IsAmbiguous(threshold float64) bool {
	return r.Confidence < threshold
}

// GetSecondaryIntent returns the second most likely intent.
func (r *ClassificationResult) GetSecondaryIntent() IntentType {
	var intents []IntentType
	for intent := range r.Scores {
		if intent != r.Intent {
			intents = append(intents, intent)
		}
	}

	sort.Slice(intents, func(i, j int) bool {
		return r.Scores[intents[i]] > r.Scores[intents[j]]
	})

	if len(intents) > 0 && r.Scores[intents[0]] > 0 {
		return intents[0]
	}

	return IntentUnknown
}

// RouterHistory tracks recent classifications.
type RouterHistory struct {
	mu      sync.Mutex
	results []*ClassificationResult
	maxSize int
}

// NewRouterHistory creates a new history tracker.
func NewRouterHistory(maxSize int) *RouterHistory {
	return &RouterHistory{
		results: make([]*ClassificationResult, 0),
		maxSize: maxSize,
	}
}

// Record adds a result to the history.
func (h *RouterHistory) Record(result *ClassificationResult) {
	h.mu.Lock()
	defer h.mu.Unlock()

	h.results = append(h.results, result)
	if len(h.results) > h.maxSize {
		h.results = h.results[1:]
	}
}

// GetDominantIntent returns the most frequent intent in the history.
func (h *RouterHistory) GetDominantIntent() IntentType {
	h.mu.Lock()
	defer h.mu.Unlock()

	if len(h.results) == 0 {
		return IntentUnknown
	}

	counts := make(map[IntentType]int)
	for _, res := range h.results {
		counts[res.Intent]++
	}

	var dominant IntentType = IntentUnknown
	maxCount := 0
	for intent, count := range counts {
		if count > maxCount {
			maxCount = count
			dominant = intent
		}
	}

	return dominant
}

// Clear removes all history.
func (h *RouterHistory) Clear() {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.results = make([]*ClassificationResult, 0)
}

// PromptCleaner cleans and normalizes prompts for better classification.
type PromptCleaner struct{}

// Clean removes noise and normalizes the prompt.
func (c *PromptCleaner) Clean(prompt string) string {
	// Simple cleaning for now
	p := strings.ToLower(prompt)
	p = strings.TrimSpace(p)
	// Remove common punctuation
	p = strings.ReplaceAll(p, "?", " ")
	p = strings.ReplaceAll(p, "!", " ")
	p = strings.ReplaceAll(p, ".", " ")
	p = strings.ReplaceAll(p, ",", " ")
	return p
}

// ComplexRouter uses multiple strategies for classification.
type ComplexRouter struct {
	simpleRouter *Router
	cleaner      *PromptCleaner
	history      *RouterHistory
}

// NewComplexRouter creates a new complex router.
func NewComplexRouter() *ComplexRouter {
	return &ComplexRouter{
		simpleRouter: NewRouter(),
		cleaner:      &PromptCleaner{},
		history:      NewRouterHistory(10),
	}
}

// Route classifies the prompt using cleaning and history context.
func (r *ComplexRouter) Route(prompt string) *ClassificationResult {
	cleaned := r.cleaner.Clean(prompt)
	result := r.simpleRouter.Classify(cleaned)
	
	// Consider history if confidence is low
	if result.Confidence < 0.4 {
		dominant := r.history.GetDominantIntent()
		if dominant != IntentUnknown {
			// Boost the dominant intent score slightly
			result.Scores[dominant] += 0.5
			// Recalculate top intent and confidence
			r.recalculate(result)
		}
	}

	r.history.Record(result)
	return result
}

func (r *ComplexRouter) recalculate(res *ClassificationResult) {
	var topIntent IntentType = IntentUnknown
	maxScore := 0.0
	totalScore := 0.0

	for intent, score := range res.Scores {
		totalScore += score
		if score > maxScore {
			maxScore = score
			topIntent = intent
		}
	}

	res.Intent = topIntent
	if totalScore > 0 {
		res.Confidence = maxScore / totalScore
	}
}
