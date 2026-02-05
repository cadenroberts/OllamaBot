package fixer

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/croberts/obot/internal/analyzer"
	"github.com/croberts/obot/internal/ollama"
)

type QualityPreset string

const (
	QualityFast     QualityPreset = "fast"
	QualityBalanced QualityPreset = "balanced"
	QualityThorough QualityPreset = "thorough"
)

type AgentOptions struct {
	Quality     QualityPreset
	RepoSummary string
	MaxRounds   int
}

type AgentResult struct {
	FixedCode   string
	Plan        string
	ReviewNotes string
	ReviewOK    bool
	Iterations  int
	Stats       []*ollama.InferenceStats
	Duration    time.Duration
}

type Agent struct {
	client *ollama.Client
}

func NewAgent(client *ollama.Client) *Agent {
	return &Agent{client: client}
}

func ResolveQuality(value string) QualityPreset {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case string(QualityFast):
		return QualityFast
	case string(QualityThorough):
		return QualityThorough
	default:
		return QualityBalanced
	}
}

func (a *Agent) Fix(ctx context.Context, fc *analyzer.FileContext, instruction string, opts AgentOptions, stream ollama.StreamCallback) (*AgentResult, error) {
	start := time.Now()
	fixType := DetectFixType(instruction)
	quality := ResolveQuality(string(opts.Quality))

	maxRounds := opts.MaxRounds
	if maxRounds <= 0 {
		if quality == QualityThorough {
			maxRounds = 2
		} else {
			maxRounds = 1
		}
	}

	plan := ""
	stats := make([]*ollama.InferenceStats, 0, 3)

	if quality != QualityFast {
		planMsg := BuildPlanMessages(fc, instruction, opts.RepoSummary, fixType)
		content, stat, err := a.client.Chat(ctx, planMsg)
		if err != nil {
			return nil, fmt.Errorf("planning failed: %w", err)
		}
		plan = strings.TrimSpace(content)
		stats = append(stats, stat)
	}

	var fixed string
	var reviewNotes string
	var reviewOK bool
	iterations := 0

	for iterations < maxRounds {
		iterations++
		messages := BuildFixMessages(fc, instruction, opts.RepoSummary, plan, reviewNotes, fixType)

		if stream != nil {
			result, err := a.client.ChatStream(ctx, messages, stream)
			if err != nil {
				return nil, fmt.Errorf("generation failed: %w", err)
			}
			if result.Stats != nil {
				stats = append(stats, result.Stats)
			}
			fixed = ExtractCode(result.Content, fc.Language)
		} else {
			content, stat, err := a.client.Chat(ctx, messages)
			if err != nil {
				return nil, fmt.Errorf("generation failed: %w", err)
			}
			stats = append(stats, stat)
			fixed = ExtractCode(content, fc.Language)
		}

		if strings.TrimSpace(fixed) == "" {
			return nil, fmt.Errorf("model returned empty code")
		}

		if quality == QualityFast {
			break
		}

		reviewMsgs := BuildReviewMessages(fc, instruction, fc.GetTargetLines(), fixed)
		reviewContent, reviewStat, err := a.client.Chat(ctx, reviewMsgs)
		if err != nil {
			return nil, fmt.Errorf("review failed: %w", err)
		}
		stats = append(stats, reviewStat)

		reviewNotes = strings.TrimSpace(reviewContent)
		if strings.EqualFold(reviewNotes, "OK") {
			reviewOK = true
			break
		}

		if iterations >= maxRounds {
			break
		}
	}

	return &AgentResult{
		FixedCode:   fixed,
		Plan:        plan,
		ReviewNotes: reviewNotes,
		ReviewOK:    reviewOK,
		Iterations:  iterations,
		Stats:       stats,
		Duration:    time.Since(start),
	}, nil
}

func AggregateStats(stats []*ollama.InferenceStats) *ollama.InferenceStats {
	if len(stats) == 0 {
		return nil
	}

	total := &ollama.InferenceStats{}
	var evalDuration int64
	var evalCount int
	for _, s := range stats {
		if s == nil {
			continue
		}
		total.PromptTokens += s.PromptTokens
		total.CompletionTokens += s.CompletionTokens
		total.TotalTokens += s.TotalTokens
		total.PromptEvalDuration += s.PromptEvalDuration
		total.EvalDuration += s.EvalDuration
		total.TotalDuration += s.TotalDuration
		evalDuration += s.EvalDuration
		evalCount += s.CompletionTokens
	}
	if evalDuration > 0 && evalCount > 0 {
		total.TokensPerSecond = float64(evalCount) / (float64(evalDuration) / 1e9)
	}
	return total
}
