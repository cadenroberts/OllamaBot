package analyzer

import (
	"path/filepath"
	"strings"
)

// Language represents a programming language
type Language string

const (
	LangGo         Language = "go"
	LangPython     Language = "python"
	LangJavaScript Language = "javascript"
	LangTypeScript Language = "typescript"
	LangRust       Language = "rust"
	LangC          Language = "c"
	LangCPP        Language = "cpp"
	LangJava       Language = "java"
	LangSwift      Language = "swift"
	LangKotlin     Language = "kotlin"
	LangRuby       Language = "ruby"
	LangPHP        Language = "php"
	LangShell      Language = "shell"
	LangSQL        Language = "sql"
	LangHTML       Language = "html"
	LangCSS        Language = "css"
	LangJSON       Language = "json"
	LangYAML       Language = "yaml"
	LangMarkdown   Language = "markdown"
	LangUnknown    Language = "unknown"
)

// extensionToLanguage maps file extensions to languages
var extensionToLanguage = map[string]Language{
	// Go
	".go": LangGo,

	// Python
	".py":   LangPython,
	".pyw":  LangPython,
	".pyi":  LangPython,
	".pyx":  LangPython,
	".pxd":  LangPython,

	// JavaScript/TypeScript
	".js":   LangJavaScript,
	".jsx":  LangJavaScript,
	".mjs":  LangJavaScript,
	".cjs":  LangJavaScript,
	".ts":   LangTypeScript,
	".tsx":  LangTypeScript,
	".mts":  LangTypeScript,
	".cts":  LangTypeScript,

	// Rust
	".rs": LangRust,

	// C/C++
	".c":   LangC,
	".h":   LangC,
	".cpp": LangCPP,
	".cc":  LangCPP,
	".cxx": LangCPP,
	".hpp": LangCPP,
	".hxx": LangCPP,

	// Java
	".java": LangJava,

	// Swift
	".swift": LangSwift,

	// Kotlin
	".kt":  LangKotlin,
	".kts": LangKotlin,

	// Ruby
	".rb":       LangRuby,
	".rake":     LangRuby,
	".gemspec":  LangRuby,

	// PHP
	".php":  LangPHP,
	".phtml": LangPHP,

	// Shell
	".sh":   LangShell,
	".bash": LangShell,
	".zsh":  LangShell,
	".fish": LangShell,

	// SQL
	".sql": LangSQL,

	// Web
	".html": LangHTML,
	".htm":  LangHTML,
	".css":  LangCSS,
	".scss": LangCSS,
	".sass": LangCSS,
	".less": LangCSS,

	// Data
	".json":  LangJSON,
	".jsonc": LangJSON,
	".yaml":  LangYAML,
	".yml":   LangYAML,

	// Documentation
	".md":       LangMarkdown,
	".markdown": LangMarkdown,
}

// DetectLanguage detects the programming language from a file path
func DetectLanguage(filePath string) Language {
	ext := strings.ToLower(filepath.Ext(filePath))
	if lang, ok := extensionToLanguage[ext]; ok {
		return lang
	}

	// Check for special filenames
	base := strings.ToLower(filepath.Base(filePath))
	switch base {
	case "makefile", "gnumakefile":
		return LangShell
	case "dockerfile":
		return LangShell
	case "gemfile", "rakefile":
		return LangRuby
	case "package.json", "tsconfig.json", "jsconfig.json":
		return LangJSON
	}

	return LangUnknown
}

// String returns the language name
func (l Language) String() string {
	return string(l)
}

// DisplayName returns a human-readable language name
func (l Language) DisplayName() string {
	switch l {
	case LangGo:
		return "Go"
	case LangPython:
		return "Python"
	case LangJavaScript:
		return "JavaScript"
	case LangTypeScript:
		return "TypeScript"
	case LangRust:
		return "Rust"
	case LangC:
		return "C"
	case LangCPP:
		return "C++"
	case LangJava:
		return "Java"
	case LangSwift:
		return "Swift"
	case LangKotlin:
		return "Kotlin"
	case LangRuby:
		return "Ruby"
	case LangPHP:
		return "PHP"
	case LangShell:
		return "Shell"
	case LangSQL:
		return "SQL"
	case LangHTML:
		return "HTML"
	case LangCSS:
		return "CSS"
	case LangJSON:
		return "JSON"
	case LangYAML:
		return "YAML"
	case LangMarkdown:
		return "Markdown"
	default:
		return "Unknown"
	}
}

// CommentStyle returns the comment syntax for a language
func (l Language) CommentStyle() (single string, multiStart string, multiEnd string) {
	switch l {
	case LangGo, LangRust, LangC, LangCPP, LangJava, LangSwift, LangKotlin, LangJavaScript, LangTypeScript, LangPHP:
		return "//", "/*", "*/"
	case LangPython, LangRuby, LangShell, LangYAML:
		return "#", "", ""
	case LangSQL:
		return "--", "/*", "*/"
	case LangHTML:
		return "", "<!--", "-->"
	case LangCSS:
		return "", "/*", "*/"
	default:
		return "//", "/*", "*/"
	}
}

// IsCode returns true if this is a programming language (not config/data)
func (l Language) IsCode() bool {
	switch l {
	case LangJSON, LangYAML, LangMarkdown, LangHTML, LangCSS:
		return false
	default:
		return true
	}
}
