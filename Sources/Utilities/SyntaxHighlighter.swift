import Foundation
import AppKit

// MARK: - Optimized Syntax Highlighter

final class SyntaxHighlighter: @unchecked Sendable {
    let theme: Theme
    
    // Cache for highlighted results
    private let cache = LRUCache<String, NSAttributedString>(capacity: 100)
    
    // Compiled regex cache
    private var compiledRules: [String: [CompiledRule]] = [:]
    private let compileLock = NSLock()
    
    enum Theme {
        case light, dark
        
        var colors: ThemeColors {
            switch self {
            case .light: return .light
            case .dark: return .dark
            }
        }
    }
    
    struct ThemeColors {
        let text: NSColor
        let keyword: NSColor
        let string: NSColor
        let comment: NSColor
        let number: NSColor
        let type: NSColor
        let function: NSColor
        let property: NSColor
        let preprocessor: NSColor
        let background: NSColor
        
        static let light = ThemeColors(
            text: NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1),
            keyword: NSColor(red: 0.61, green: 0.13, blue: 0.58, alpha: 1),
            string: NSColor(red: 0.77, green: 0.10, blue: 0.09, alpha: 1),
            comment: NSColor(red: 0.42, green: 0.48, blue: 0.51, alpha: 1),
            number: NSColor(red: 0.11, green: 0.44, blue: 0.70, alpha: 1),
            type: NSColor(red: 0.11, green: 0.36, blue: 0.56, alpha: 1),
            function: NSColor(red: 0.32, green: 0.45, blue: 0.17, alpha: 1),
            property: NSColor(red: 0.28, green: 0.28, blue: 0.28, alpha: 1),
            preprocessor: NSColor(red: 0.47, green: 0.24, blue: 0.17, alpha: 1),
            background: NSColor.white
        )
        
        static let dark = ThemeColors(
            text: NSColor(red: 0.87, green: 0.88, blue: 0.90, alpha: 1),
            keyword: NSColor(red: 0.99, green: 0.47, blue: 0.54, alpha: 1),
            string: NSColor(red: 0.89, green: 0.77, blue: 0.55, alpha: 1),
            comment: NSColor(red: 0.47, green: 0.55, blue: 0.61, alpha: 1),
            number: NSColor(red: 0.82, green: 0.63, blue: 0.98, alpha: 1),
            type: NSColor(red: 0.60, green: 0.86, blue: 0.98, alpha: 1),
            function: NSColor(red: 0.65, green: 0.82, blue: 0.56, alpha: 1),
            property: NSColor(red: 0.76, green: 0.85, blue: 0.94, alpha: 1),
            preprocessor: NSColor(red: 0.99, green: 0.72, blue: 0.52, alpha: 1),
            background: NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
        )
    }
    
    struct CompiledRule {
        let regex: NSRegularExpression
        let color: NSColor
        let captureGroup: Int
    }
    
    init(theme: Theme) {
        self.theme = theme
    }
    
    // MARK: - Main Highlight Function (Cached)
    
    func highlight(_ code: String, language: String) -> NSAttributedString {
        // Generate cache key
        let cacheKey = "\(language):\(code.hashValue)"
        
        // Check cache first
        if let cached = cache.get(cacheKey) {
            return cached
        }
        
        // Perform highlighting
        let result = highlightInternal(code, language: language)
        
        // Cache the result (size = character count / 100 as rough estimate)
        cache.set(cacheKey, result, size: max(1, code.count / 100))
        
        return result
    }
    
    // MARK: - Incremental Highlight (For Large Files)
    
    func highlightIncremental(
        textStorage: NSTextStorage,
        editedRange: NSRange,
        language: String
    ) {
        // Find affected line range
        let content = textStorage.string
        let lineRange = (content as NSString).lineRange(for: editedRange)
        
        // Only re-highlight the affected lines
        let lineContent = (content as NSString).substring(with: lineRange)
        let highlighted = highlightInternal(lineContent, language: language)
        
        // Apply attributes only to the changed range
        textStorage.beginEditing()
        textStorage.setAttributes([:], range: lineRange)
        highlighted.enumerateAttributes(in: NSRange(location: 0, length: highlighted.length)) { attrs, range, _ in
            let adjustedRange = NSRange(location: lineRange.location + range.location, length: range.length)
            textStorage.addAttributes(attrs, range: adjustedRange)
        }
        textStorage.endEditing()
    }
    
    // MARK: - Internal Highlighting (Optimized)
    
    private func highlightInternal(_ code: String, language: String) -> NSAttributedString {
        let rules = getCompiledRules(for: language)
        let colors = theme.colors
        
        // Create result with base attributes
        let baseFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let result = NSMutableAttributedString(string: code, attributes: [
            .font: baseFont,
            .foregroundColor: colors.text
        ])
        
        let nsRange = NSRange(location: 0, length: code.utf16.count)
        
        // Skip highlighting for very large files (> 100KB)
        // Quality tradeoff: large files are rare and slow to highlight
        guard code.count < 100_000 else {
            return result
        }
        
        // Begin batch editing for better performance
        result.beginEditing()
        
        // Apply rules (order matters - later rules override earlier)
        for rule in rules {
            rule.regex.enumerateMatches(in: code, options: .withoutAnchoringBounds, range: nsRange) { match, _, stop in
                guard let match = match else { return }
                
                let matchRange = rule.captureGroup > 0 && match.numberOfRanges > rule.captureGroup
                    ? match.range(at: rule.captureGroup)
                    : match.range
                
                guard matchRange.location != NSNotFound else { return }
                result.addAttribute(.foregroundColor, value: rule.color, range: matchRange)
            }
        }
        
        result.endEditing()
        return result
    }
    
    // MARK: - Rule Compilation (Cached)
    
    private func getCompiledRules(for language: String) -> [CompiledRule] {
        compileLock.lock()
        defer { compileLock.unlock() }
        
        let key = language.lowercased()
        
        if let cached = compiledRules[key] {
            return cached
        }
        
        let tokenRules = getTokenRules(for: key)
        var compiled: [CompiledRule] = []
        compiled.reserveCapacity(tokenRules.count)
        
        for rule in tokenRules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: rule.options) else {
                continue
            }
            compiled.append(CompiledRule(
                regex: regex,
                color: colorFor(rule.type),
                captureGroup: rule.captureGroup
            ))
        }
        
        compiledRules[key] = compiled
        return compiled
    }
    
    private func colorFor(_ type: TokenType) -> NSColor {
        let c = theme.colors
        switch type {
        case .keyword: return c.keyword
        case .string: return c.string
        case .comment: return c.comment
        case .number: return c.number
        case .type: return c.type
        case .function: return c.function
        case .property: return c.property
        case .preprocessor: return c.preprocessor
        case .text: return c.text
        }
    }
    
    // MARK: - Token Rules by Language
    
    private func getTokenRules(for language: String) -> [TokenRule] {
        switch language {
        case "swift": return swiftRules
        case "python", "py": return pythonRules
        case "javascript", "js": return jsRules
        case "typescript", "ts", "tsx": return tsRules
        case "json": return jsonRules
        case "rust", "rs": return rustRules
        case "go": return goRules
        case "bash", "sh", "zsh": return shellRules
        default: return commonRules
        }
    }
    
    private var commonRules: [TokenRule] {
        [
            TokenRule(type: .string, pattern: #""(?:[^"\\]|\\.)*""#),
            TokenRule(type: .string, pattern: #"'(?:[^'\\]|\\.)*'"#),
            TokenRule(type: .comment, pattern: #"//.*$"#, options: .anchorsMatchLines),
            TokenRule(type: .comment, pattern: #"/\*[\s\S]*?\*/"#),
            TokenRule(type: .comment, pattern: #"#.*$"#, options: .anchorsMatchLines),
            TokenRule(type: .number, pattern: #"\b\d+\.?\d*\b"#),
        ]
    }
    
    private var swiftRules: [TokenRule] {
        [
            TokenRule(type: .string, pattern: #"\"\"\"[\s\S]*?\"\"\""#),
            TokenRule(type: .string, pattern: #""(?:[^"\\]|\\.)*""#),
            TokenRule(type: .comment, pattern: #"//.*$"#, options: .anchorsMatchLines),
            TokenRule(type: .comment, pattern: #"/\*[\s\S]*?\*/"#),
            TokenRule(type: .preprocessor, pattern: #"#\w+"#),
            TokenRule(type: .keyword, pattern: #"\b(func|var|let|if|else|guard|return|class|struct|enum|protocol|extension|import|public|private|fileprivate|internal|open|static|final|override|mutating|throws|throw|try|catch|async|await|actor|some|any|where|case|switch|default|for|while|repeat|break|continue|in|as|is|nil|true|false|self|Self|init|deinit|convenience|required|lazy|weak|unowned|inout|typealias|associatedtype|subscript|get|set|willSet|didSet|defer|do)\b"#),
            TokenRule(type: .type, pattern: #"\b[A-Z][A-Za-z0-9_]*\b"#),
            TokenRule(type: .function, pattern: #"\b([a-z_][a-zA-Z0-9_]*)\s*\("#, captureGroup: 1),
            TokenRule(type: .number, pattern: #"\b\d+\.?\d*\b"#),
            TokenRule(type: .preprocessor, pattern: #"@\w+"#),
        ]
    }
    
    private var pythonRules: [TokenRule] {
        [
            TokenRule(type: .string, pattern: #"('''[\s\S]*?'''|\"\"\"[\s\S]*?\"\"\")"#),
            TokenRule(type: .string, pattern: #"[rf]?\"(?:[^\"\\]|\\.)*\"|'(?:[^'\\]|\\.)*'"#),
            TokenRule(type: .comment, pattern: #"#.*$"#, options: .anchorsMatchLines),
            TokenRule(type: .keyword, pattern: #"\b(def|class|if|elif|else|for|while|try|except|finally|with|as|import|from|return|yield|lambda|pass|break|continue|raise|assert|global|nonlocal|True|False|None|and|or|not|in|is|async|await)\b"#),
            TokenRule(type: .preprocessor, pattern: #"@\w+"#),
            TokenRule(type: .function, pattern: #"\b([a-z_][a-zA-Z0-9_]*)\s*\("#, captureGroup: 1),
            TokenRule(type: .type, pattern: #"\b[A-Z][A-Za-z0-9_]*\b"#),
            TokenRule(type: .number, pattern: #"\b\d+\.?\d*\b"#),
        ]
    }
    
    private var jsRules: [TokenRule] {
        [
            TokenRule(type: .string, pattern: #"`[^`]*`"#),
            TokenRule(type: .string, pattern: #""(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'"#),
            TokenRule(type: .comment, pattern: #"//.*$"#, options: .anchorsMatchLines),
            TokenRule(type: .comment, pattern: #"/\*[\s\S]*?\*/"#),
            TokenRule(type: .keyword, pattern: #"\b(function|var|let|const|if|else|for|while|do|switch|case|default|break|continue|return|try|catch|finally|throw|new|delete|typeof|instanceof|in|of|class|extends|super|import|export|from|as|async|await|yield|this|null|undefined|true|false)\b"#),
            TokenRule(type: .function, pattern: #"\b([a-z_][a-zA-Z0-9_]*)\s*\("#, captureGroup: 1),
            TokenRule(type: .type, pattern: #"\b[A-Z][A-Za-z0-9_]*\b"#),
            TokenRule(type: .number, pattern: #"\b\d+\.?\d*\b"#),
        ]
    }
    
    private var tsRules: [TokenRule] {
        jsRules + [
            TokenRule(type: .type, pattern: #":\s*([A-Z][A-Za-z0-9_<>[\]|&]*)"#, captureGroup: 1),
            TokenRule(type: .keyword, pattern: #"\b(type|interface|enum|namespace|declare|readonly|abstract|implements|private|public|protected|keyof|infer|never|unknown|any)\b"#),
        ]
    }
    
    private var jsonRules: [TokenRule] {
        [
            TokenRule(type: .property, pattern: #""[^"]+"\s*:"#),
            TokenRule(type: .string, pattern: #":\s*"[^"]*""#),
            TokenRule(type: .number, pattern: #"\b\d+\.?\d*\b"#),
            TokenRule(type: .keyword, pattern: #"\b(true|false|null)\b"#),
        ]
    }
    
    private var rustRules: [TokenRule] {
        [
            TokenRule(type: .string, pattern: #""(?:[^"\\]|\\.)*""#),
            TokenRule(type: .string, pattern: "r\"[^\"]*\""),
            TokenRule(type: .comment, pattern: #"//.*$"#, options: .anchorsMatchLines),
            TokenRule(type: .comment, pattern: #"/\*[\s\S]*?\*/"#),
            TokenRule(type: .preprocessor, pattern: #"\b\w+!"#),
            TokenRule(type: .keyword, pattern: #"\b(fn|let|mut|const|if|else|match|loop|while|for|in|break|continue|return|struct|enum|impl|trait|pub|mod|use|as|self|super|crate|where|async|await|move|ref|type|static|unsafe|extern|dyn)\b"#),
            TokenRule(type: .type, pattern: #"\b[A-Z][A-Za-z0-9_]*\b"#),
            TokenRule(type: .number, pattern: #"\b\d+\.?\d*\b"#),
            TokenRule(type: .preprocessor, pattern: #"'[a-z_]+"#),
        ]
    }
    
    private var goRules: [TokenRule] {
        [
            TokenRule(type: .string, pattern: #""(?:[^"\\]|\\.)*"|`[^`]*`"#),
            TokenRule(type: .comment, pattern: #"//.*$"#, options: .anchorsMatchLines),
            TokenRule(type: .comment, pattern: #"/\*[\s\S]*?\*/"#),
            TokenRule(type: .keyword, pattern: #"\b(func|var|const|type|struct|interface|map|chan|if|else|for|range|switch|case|default|break|continue|return|go|defer|select|package|import|true|false|nil)\b"#),
            TokenRule(type: .type, pattern: #"\b(int|int8|int16|int32|int64|uint|uint8|uint16|uint32|uint64|float32|float64|complex64|complex128|string|bool|byte|rune|error|any)\b"#),
            TokenRule(type: .type, pattern: #"\b[A-Z][A-Za-z0-9_]*\b"#),
            TokenRule(type: .function, pattern: #"\b([a-z_][a-zA-Z0-9_]*)\s*\("#, captureGroup: 1),
            TokenRule(type: .number, pattern: #"\b\d+\.?\d*\b"#),
        ]
    }
    
    private var shellRules: [TokenRule] {
        [
            TokenRule(type: .string, pattern: #""(?:[^"\\]|\\.)*"|'[^']*'"#),
            TokenRule(type: .comment, pattern: #"#.*$"#, options: .anchorsMatchLines),
            TokenRule(type: .keyword, pattern: #"\b(if|then|else|elif|fi|for|while|do|done|case|esac|in|function|return|exit|local|export|source)\b"#),
            TokenRule(type: .property, pattern: #"\$\{?[a-zA-Z_][a-zA-Z0-9_]*\}?"#),
            TokenRule(type: .function, pattern: #"^\s*[a-zA-Z_][a-zA-Z0-9_-]*"#, options: .anchorsMatchLines),
        ]
    }
}

// MARK: - Token Types

enum TokenType {
    case keyword, string, comment, number, type, function, property, preprocessor, text
}

struct TokenRule {
    let type: TokenType
    let pattern: String
    var options: NSRegularExpression.Options = []
    var captureGroup: Int = 0
}
