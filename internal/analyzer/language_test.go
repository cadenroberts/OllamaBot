package analyzer

import (
	"testing"
)

func TestDetectLanguage(t *testing.T) {
	tests := []struct {
		filename string
		expected Language
	}{
		// Go
		{"main.go", LangGo},
		{"server.go", LangGo},

		// Python
		{"script.py", LangPython},
		{"module.pyw", LangPython},

		// JavaScript/TypeScript
		{"app.js", LangJavaScript},
		{"component.jsx", LangJavaScript},
		{"index.ts", LangTypeScript},
		{"component.tsx", LangTypeScript},

		// Rust
		{"main.rs", LangRust},

		// C/C++
		{"main.c", LangC},
		{"header.h", LangC},
		{"main.cpp", LangCPP},
		{"class.hpp", LangCPP},

		// Java
		{"Main.java", LangJava},

		// Swift
		{"ViewController.swift", LangSwift},

		// Shell
		{"build.sh", LangShell},
		{"deploy.bash", LangShell},

		// Config/Data
		{"config.json", LangJSON},
		{"settings.yaml", LangYAML},
		{"settings.yml", LangYAML},

		// Web
		{"index.html", LangHTML},
		{"styles.css", LangCSS},
		{"styles.scss", LangCSS},

		// Special files
		{"Makefile", LangShell},
		{"Dockerfile", LangShell},
		{"Gemfile", LangRuby},

		// Unknown
		{"README", LangUnknown},
		{"data.xyz", LangUnknown},
	}

	for _, tt := range tests {
		t.Run(tt.filename, func(t *testing.T) {
			result := DetectLanguage(tt.filename)
			if result != tt.expected {
				t.Errorf("DetectLanguage(%q) = %v, want %v", tt.filename, result, tt.expected)
			}
		})
	}
}

func TestLanguageDisplayName(t *testing.T) {
	tests := []struct {
		lang     Language
		expected string
	}{
		{LangGo, "Go"},
		{LangPython, "Python"},
		{LangJavaScript, "JavaScript"},
		{LangTypeScript, "TypeScript"},
		{LangRust, "Rust"},
		{LangSwift, "Swift"},
		{LangUnknown, "Unknown"},
	}

	for _, tt := range tests {
		t.Run(string(tt.lang), func(t *testing.T) {
			result := tt.lang.DisplayName()
			if result != tt.expected {
				t.Errorf("%v.DisplayName() = %v, want %v", tt.lang, result, tt.expected)
			}
		})
	}
}

func TestLanguageIsCode(t *testing.T) {
	codeLanguages := []Language{
		LangGo, LangPython, LangJavaScript, LangTypeScript,
		LangRust, LangC, LangCPP, LangJava, LangSwift,
	}

	nonCodeLanguages := []Language{
		LangJSON, LangYAML, LangMarkdown, LangHTML, LangCSS,
	}

	for _, lang := range codeLanguages {
		if !lang.IsCode() {
			t.Errorf("%v.IsCode() = false, want true", lang)
		}
	}

	for _, lang := range nonCodeLanguages {
		if lang.IsCode() {
			t.Errorf("%v.IsCode() = true, want false", lang)
		}
	}
}

func TestLanguageCommentStyle(t *testing.T) {
	tests := []struct {
		lang             Language
		expectedSingle   string
		expectedMultiS   string
		expectedMultiE   string
	}{
		{LangGo, "//", "/*", "*/"},
		{LangPython, "#", "", ""},
		{LangRuby, "#", "", ""},
		{LangShell, "#", "", ""},
		{LangHTML, "", "<!--", "-->"},
		{LangCSS, "", "/*", "*/"},
		{LangSQL, "--", "/*", "*/"},
	}

	for _, tt := range tests {
		t.Run(string(tt.lang), func(t *testing.T) {
			single, multiStart, multiEnd := tt.lang.CommentStyle()
			if single != tt.expectedSingle {
				t.Errorf("%v.CommentStyle() single = %q, want %q", tt.lang, single, tt.expectedSingle)
			}
			if multiStart != tt.expectedMultiS {
				t.Errorf("%v.CommentStyle() multiStart = %q, want %q", tt.lang, multiStart, tt.expectedMultiS)
			}
			if multiEnd != tt.expectedMultiE {
				t.Errorf("%v.CommentStyle() multiEnd = %q, want %q", tt.lang, multiEnd, tt.expectedMultiE)
			}
		})
	}
}
