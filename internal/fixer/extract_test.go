package fixer

import (
	"testing"

	"github.com/croberts/obot/internal/analyzer"
)

func TestExtractCode(t *testing.T) {
	tests := []struct {
		name     string
		response string
		lang     analyzer.Language
		expected string
	}{
		{
			name:     "code_block_with_language",
			response: "```go\nfunc main() {\n    fmt.Println(\"hello\")\n}\n```",
			lang:     analyzer.LangGo,
			expected: "func main() {\n    fmt.Println(\"hello\")\n}",
		},
		{
			name:     "code_block_generic",
			response: "```\nprint('hello')\n```",
			lang:     analyzer.LangPython,
			expected: "print('hello')",
		},
		{
			name:     "plain_code_no_block",
			response: "func main() {\n    return\n}",
			lang:     analyzer.LangGo,
			expected: "func main() {\n    return\n}",
		},
		{
			name:     "code_with_prefix",
			response: "Here's the fixed code:\nfunc main() {}",
			lang:     analyzer.LangGo,
			expected: "func main() {}",
		},
		{
			name:     "code_with_explanation_after",
			response: "func main() {}\n\nThis fixes the issue by...",
			lang:     analyzer.LangGo,
			expected: "func main() {}",
		},
		{
			name:     "python_code_block",
			response: "```python\ndef hello():\n    print('world')\n```",
			lang:     analyzer.LangPython,
			expected: "def hello():\n    print('world')",
		},
		{
			name:     "javascript_alias",
			response: "```js\nconst x = 1;\n```",
			lang:     analyzer.LangJavaScript,
			expected: "const x = 1;",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := ExtractCode(tt.response, tt.lang)
			if result != tt.expected {
				t.Errorf("ExtractCode() = %q, want %q", result, tt.expected)
			}
		})
	}
}

func TestHasCodeChanges(t *testing.T) {
	tests := []struct {
		name     string
		original string
		fixed    string
		expected bool
	}{
		{
			name:     "identical",
			original: "func main() {}",
			fixed:    "func main() {}",
			expected: false,
		},
		{
			name:     "whitespace_only",
			original: "func main() {}",
			fixed:    "func  main()  {}",
			expected: false,
		},
		{
			name:     "actual_change",
			original: "func main() {}",
			fixed:    "func main() { return }",
			expected: true,
		},
		{
			name:     "newline_differences_only",
			original: "func main() {\n}",
			fixed:    "func main() {\n\n}",
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := HasCodeChanges(tt.original, tt.fixed)
			if result != tt.expected {
				t.Errorf("HasCodeChanges() = %v, want %v", result, tt.expected)
			}
		})
	}
}

func TestDetectFixType(t *testing.T) {
	tests := []struct {
		instruction string
		expected    FixType
	}{
		{"fix the linter warnings", FixLint},
		{"fix lint errors", FixLint},
		{"there's a bug in this code", FixBug},
		{"fix the null pointer", FixBug},
		{"refactor this function", FixRefactor},
		{"clean up this code", FixRefactor},
		{"implement the TODO", FixComplete},
		{"complete this function", FixComplete},
		{"optimize for performance", FixOptimize},
		{"make this faster", FixOptimize},
		{"add documentation", FixDoc},
		{"add comments", FixDoc},
		{"fix the types", FixTypes},
		{"add type annotations", FixTypes},
		{"make it better", FixGeneral},
		{"", FixGeneral},
	}

	for _, tt := range tests {
		t.Run(tt.instruction, func(t *testing.T) {
			result := DetectFixType(tt.instruction)
			if result != tt.expected {
				t.Errorf("DetectFixType(%q) = %v, want %v", tt.instruction, result, tt.expected)
			}
		})
	}
}
