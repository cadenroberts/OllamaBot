package cli

import (
	"fmt"
	"os"
	"strings"

	"github.com/fatih/color"
	"github.com/spf13/cobra"

	"github.com/croberts/obot/internal/index"
)

var (
	searchType    string
	searchLang    string
	searchFiles   bool
	searchSymbols bool
	searchUses    bool
)

var searchCmd = &cobra.Command{
	Use:   "search <query>",
	Short: "Search indexed files and symbols",
	Long: `Search for text in file paths and symbol names across the project index.
You can filter by symbol type (function, method, class, struct, interface) or programming language.`,
	Args: cobra.MinimumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		query := strings.Join(args, " ")

		// Load index
		idx, err := index.Load("")
		if err != nil {
			if os.IsNotExist(err) {
				return fmt.Errorf("index not found. Run 'obot fs index' first")
			}
			return err
		}

		var results []index.SearchResult
		if searchFiles {
			matches := idx.FindByName(query)
			for _, m := range matches {
				results = append(results, index.SearchResult{File: m})
			}
		} else if searchSymbols {
			results = idx.SearchSymbols(query)
		} else if searchUses {
			results = idx.SearchUses(query)
		} else if searchType != "" {
			results = idx.SearchSymbolsByType(query, index.SymbolType(searchType))
		} else {
			results = idx.Search(query)
		}

		// Filter by language if specified
		if searchLang != "" {
			filtered := make([]index.SearchResult, 0)
			for _, res := range results {
				if string(res.File.Language) == strings.ToLower(searchLang) {
					filtered = append(filtered, res)
				}
			}
			results = filtered
		}

		if len(results) == 0 {
			fmt.Printf("No results found for '%s'%s\n", query, formatFilters())
			return nil
		}

		fmt.Printf("Search results for '%s'%s:\n\n", query, formatFilters())
		for _, res := range results {
			if res.Symbol != nil {
				fmt.Printf("  %s %s (%s) at line %d\n",
					color.CyanString(res.File.RelPath),
					color.YellowString(res.Symbol.Name),
					color.HiBlackString(string(res.Symbol.Type)),
					res.Symbol.Line)
			} else {
				fmt.Printf("  %s\n", color.CyanString(res.File.RelPath))
			}
		}

		return nil
	},
}

func formatFilters() string {
	filters := []string{}
	if searchFiles {
		filters = append(filters, "files")
	}
	if searchSymbols {
		filters = append(filters, "symbols")
	}
	if searchUses {
		filters = append(filters, "uses")
	}
	if searchType != "" {
		filters = append(filters, fmt.Sprintf("type=%s", searchType))
	}
	if searchLang != "" {
		filters = append(filters, fmt.Sprintf("lang=%s", searchLang))
	}
	if len(filters) > 0 {
		return " [" + strings.Join(filters, ", ") + "]"
	}
	return ""
}

var symbolsCmd = &cobra.Command{
	Use:   "symbols <query>",
	Short: "Search indexed symbols specifically",
	Args:  cobra.MinimumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		searchSymbols = true
		return searchCmd.RunE(cmd, args)
	},
}

func init() {
	searchCmd.Flags().StringVarP(&searchType, "type", "t", "", "Filter by symbol type (function|class|struct|interface|method)")
	searchCmd.Flags().StringVarP(&searchLang, "lang", "l", "", "Filter by programming language")
	searchCmd.Flags().BoolVar(&searchFiles, "files", false, "Search only in file paths")
	searchCmd.Flags().BoolVar(&searchSymbols, "symbols", false, "Search only in symbol names")
	searchCmd.Flags().BoolVar(&searchUses, "uses", false, "Search for usages in file contents")
}
