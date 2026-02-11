package index

import (
	"fmt"
	"sort"
	"strings"

	"github.com/croberts/obot/internal/analyzer"
)

// LanguageStats contains aggregated statistics for a single language.
type LanguageStats struct {
	Language   analyzer.Language `json:"language"`
	FileCount  int               `json:"file_count"`
	TotalLines int               `json:"total_lines"`
	TotalSize  int64             `json:"total_size"`
}

// LanguageMap maps languages to their statistics.
type LanguageMap map[analyzer.Language]*LanguageStats

// GetLanguageStats returns aggregated statistics by language from the index.
func (idx *Index) GetLanguageStats() LanguageMap {
	stats := make(LanguageMap)
	for _, f := range idx.Files {
		s, ok := stats[f.Language]
		if !ok {
			s = &LanguageStats{
				Language: f.Language,
			}
			stats[f.Language] = s
		}
		s.FileCount++
		s.TotalLines += f.Lines
		s.TotalSize += f.SizeBytes
	}
	return stats
}

// SummaryByLanguage returns a formatted string summary of the index by language.
func (idx *Index) SummaryByLanguage() string {
	stats := idx.GetLanguageStats()

	// Sort languages by file count for consistent output
	langs := make([]analyzer.Language, 0, len(stats))
	for l := range stats {
		langs = append(langs, l)
	}
	sort.Slice(langs, func(i, j int) bool {
		return stats[langs[i]].FileCount > stats[langs[j]].FileCount
	})

	var sb strings.Builder
	sb.WriteString("Language Summary:\n")
	for _, l := range langs {
		s := stats[l]
		sb.WriteString(fmt.Sprintf("  - %-12s: files=%-4d lines=%-6d size=%s\n",
			l.DisplayName(), s.FileCount, s.TotalLines, formatSize(s.TotalSize)))
	}
	return sb.String()
}

// formatSize returns a human-readable size string.
func formatSize(bytes int64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := int64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(bytes)/float64(div), "KMGTPE"[exp])
}
