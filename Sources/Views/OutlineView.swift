import Foundation
import SwiftUI

// MARK: - Outline View (Symbol Navigation)

struct OutlineView: View {
    @Environment(AppState.self) private var appState
    @State private var symbols: [CodeSymbol] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var expandedGroups: Set<SymbolKind> = Set(SymbolKind.allCases)
    
    var filteredSymbols: [CodeSymbol] {
        guard !searchText.isEmpty else { return symbols }
        return symbols.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var groupedSymbols: [(SymbolKind, [CodeSymbol])] {
        let grouped = Dictionary(grouping: filteredSymbols) { $0.kind }
        return SymbolKind.allCases.compactMap { kind in
            guard let syms = grouped[kind], !syms.isEmpty else { return nil }
            return (kind, syms.sorted { $0.line < $1.line })
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            DSSectionHeader(title: "OUTLINE")
            
            DSDivider()
            
            // Search
            DSTextField(placeholder: "Filter symbols...", text: $searchText, icon: "magnifyingglass")
                .padding(DS.Spacing.sm)
            
            // Symbols
            if isLoading {
                Spacer()
                DSLoadingSpinner()
                Spacer()
            } else if symbols.isEmpty {
                DSEmptyState(
                    icon: "list.bullet.indent",
                    title: "No Symbols",
                    message: "Open a file to see its symbols"
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groupedSymbols, id: \.0) { kind, syms in
                            SymbolGroupView(
                                kind: kind,
                                symbols: syms,
                                isExpanded: expandedGroups.contains(kind),
                                onToggle: { toggleGroup(kind) },
                                onSelect: { symbol in
                                    navigateToSymbol(symbol)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: appState.editorContent) { _, _ in
            parseSymbols()
        }
        .onAppear {
            parseSymbols()
        }
    }
    
    private func toggleGroup(_ kind: SymbolKind) {
        if expandedGroups.contains(kind) {
            expandedGroups.remove(kind)
        } else {
            expandedGroups.insert(kind)
        }
    }
    
    private func navigateToSymbol(_ symbol: CodeSymbol) {
        appState.goToLine = symbol.line
        // Note: In a real implementation, this would scroll the editor to the line
    }
    
    private func parseSymbols() {
        guard !appState.editorContent.isEmpty else {
            symbols = []
            return
        }
        
        isLoading = true
        
        // Parse in background
        Task.detached(priority: .userInitiated) { [content = appState.editorContent, file = appState.selectedFile] in
            let parsed = await SymbolParser.parse(content: content, language: file?.language ?? "swift")
            
            await MainActor.run {
                self.symbols = parsed
                self.isLoading = false
            }
        }
    }
}

// MARK: - Symbol Group View

struct SymbolGroupView: View {
    let kind: SymbolKind
    let symbols: [CodeSymbol]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSelect: (CodeSymbol) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header
            Button(action: onToggle) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                        .frame(width: 12)
                    
                    Image(systemName: kind.icon)
                        .font(.caption)
                        .foregroundStyle(kind.color)
                    
                    Text(kind.displayName)
                        .font(DS.Typography.caption.weight(.semibold))
                        .foregroundStyle(DS.Colors.secondaryText)
                    
                    Text("(\(symbols.count))")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    
                    Spacer()
                }
                .padding(.vertical, DS.Spacing.xs)
            }
            .buttonStyle(.plain)
            
            // Symbols
            if isExpanded {
                ForEach(symbols) { symbol in
                    SymbolRow(symbol: symbol, onSelect: { onSelect(symbol) })
                }
            }
        }
    }
}

struct SymbolRow: View {
    let symbol: CodeSymbol
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DS.Spacing.sm) {
                Spacer()
                    .frame(width: 16)
                
                Image(systemName: symbol.kind.icon)
                    .font(.caption)
                    .foregroundStyle(symbol.kind.color)
                    .frame(width: 16)
                
                Text(symbol.name)
                    .font(DS.Typography.mono(11))
                    .foregroundStyle(DS.Colors.text)
                    .lineLimit(1)
                
                Spacer()
                
                Text(":\(symbol.line)")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, DS.Spacing.xs)
            .background(isHovered ? DS.Colors.surface : .clear)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Code Symbol Model

struct CodeSymbol: Identifiable {
    let id = UUID()
    let name: String
    let kind: SymbolKind
    let line: Int
    let range: Range<String.Index>?
    var children: [CodeSymbol]
    
    init(name: String, kind: SymbolKind, line: Int, range: Range<String.Index>? = nil, children: [CodeSymbol] = []) {
        self.name = name
        self.kind = kind
        self.line = line
        self.range = range
        self.children = children
    }
}

enum SymbolKind: String, CaseIterable {
    case `class`
    case `struct`
    case `enum`
    case `protocol`
    case function
    case method
    case property
    case variable
    case constant
    case `extension`
    case `typealias`
    case `import`
    
    var displayName: String {
        switch self {
        case .class: return "Classes"
        case .struct: return "Structs"
        case .enum: return "Enums"
        case .protocol: return "Protocols"
        case .function: return "Functions"
        case .method: return "Methods"
        case .property: return "Properties"
        case .variable: return "Variables"
        case .constant: return "Constants"
        case .extension: return "Extensions"
        case .typealias: return "Type Aliases"
        case .import: return "Imports"
        }
    }
    
    var icon: String {
        switch self {
        case .class: return "c.square"
        case .struct: return "s.square"
        case .enum: return "e.square"
        case .protocol: return "p.square"
        case .function: return "f.square"
        case .method: return "m.square"
        case .property: return "square.fill"
        case .variable: return "v.square"
        case .constant: return "k.square"
        case .extension: return "plus.square"
        case .typealias: return "t.square"
        case .import: return "arrow.down.square"
        }
    }
    
    var color: Color {
        switch self {
        case .class: return DS.Colors.orchestrator
        case .struct: return DS.Colors.coder
        case .enum: return DS.Colors.success
        case .protocol: return DS.Colors.info
        case .function, .method: return DS.Colors.warning
        case .property, .variable: return DS.Colors.accent
        case .constant: return DS.Colors.researcher
        case .extension: return DS.Colors.vision
        case .typealias: return DS.Colors.secondaryText
        case .import: return DS.Colors.tertiaryText
        }
    }
}

// MARK: - Symbol Parser

enum SymbolParser {
    static func parse(content: String, language: String) async -> [CodeSymbol] {
        switch language.lowercased() {
        case "swift":
            return parseSwift(content)
        case "python", "py":
            return parsePython(content)
        case "javascript", "js", "typescript", "ts", "tsx", "jsx":
            return parseJavaScript(content)
        default:
            return parseGeneric(content)
        }
    }
    
    // MARK: - Swift Parser
    
    private static func parseSwift(_ content: String) -> [CodeSymbol] {
        var symbols: [CodeSymbol] = []
        let lines = content.components(separatedBy: .newlines)
        
        let accessModifiers = ["public", "private", "internal", "fileprivate", "open"]
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lineNum = index + 1
            let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            guard !words.isEmpty else { continue }
            
            // Find keyword position (skip access modifiers)
            var keywordIdx = 0
            while keywordIdx < words.count && (accessModifiers.contains(words[keywordIdx]) || words[keywordIdx].hasPrefix("@")) {
                keywordIdx += 1
            }
            
            guard keywordIdx < words.count else { continue }
            
            let keyword = words[keywordIdx]
            let nameIdx = keywordIdx + 1
            
            if keyword == "class" && nameIdx < words.count {
                let name = extractName(from: words[nameIdx])
                symbols.append(CodeSymbol(name: name, kind: .class, line: lineNum))
            }
            else if keyword == "struct" && nameIdx < words.count {
                let name = extractName(from: words[nameIdx])
                symbols.append(CodeSymbol(name: name, kind: .struct, line: lineNum))
            }
            else if keyword == "enum" && nameIdx < words.count {
                let name = extractName(from: words[nameIdx])
                symbols.append(CodeSymbol(name: name, kind: .enum, line: lineNum))
            }
            else if keyword == "protocol" && nameIdx < words.count {
                let name = extractName(from: words[nameIdx])
                symbols.append(CodeSymbol(name: name, kind: .protocol, line: lineNum))
            }
            else if keyword == "func" && nameIdx < words.count {
                let name = extractFunctionName(from: words[nameIdx])
                let kind: SymbolKind = line.hasPrefix("    ") || line.hasPrefix("\t") ? .method : .function
                symbols.append(CodeSymbol(name: name + "()", kind: kind, line: lineNum))
            }
            else if keyword == "var" && nameIdx < words.count {
                let name = extractName(from: words[nameIdx])
                symbols.append(CodeSymbol(name: name, kind: .property, line: lineNum))
            }
            else if keyword == "let" && nameIdx < words.count {
                let name = extractName(from: words[nameIdx])
                symbols.append(CodeSymbol(name: name, kind: .constant, line: lineNum))
            }
            else if keyword == "extension" && nameIdx < words.count {
                let name = extractName(from: words[nameIdx])
                symbols.append(CodeSymbol(name: name, kind: .extension, line: lineNum))
            }
            else if keyword == "typealias" && nameIdx < words.count {
                let name = extractName(from: words[nameIdx])
                symbols.append(CodeSymbol(name: name, kind: .typealias, line: lineNum))
            }
            else if keyword == "import" && nameIdx < words.count {
                symbols.append(CodeSymbol(name: words[nameIdx], kind: .import, line: lineNum))
            }
        }
        
        return symbols
    }
    
    private static func extractName(from word: String) -> String {
        // Remove anything after : or < or { or (
        var name = word
        for char in [":", "<", "{", "(", ","] {
            if let idx = name.firstIndex(of: Character(char)) {
                name = String(name[..<idx])
            }
        }
        return name
    }
    
    private static func extractFunctionName(from word: String) -> String {
        // Remove anything after (
        if let idx = word.firstIndex(of: "(") {
            return String(word[..<idx])
        }
        return extractName(from: word)
    }
    
    // MARK: - Python Parser
    
    private static func parsePython(_ content: String) -> [CodeSymbol] {
        var symbols: [CodeSymbol] = []
        let lines = content.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lineNum = index + 1
            let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            guard words.count >= 2 else { continue }
            
            if words[0] == "class" {
                let name = extractName(from: words[1])
                symbols.append(CodeSymbol(name: name, kind: .class, line: lineNum))
            }
            else if words[0] == "def" {
                let name = extractFunctionName(from: words[1])
                let kind: SymbolKind = line.hasPrefix("    ") ? .method : .function
                symbols.append(CodeSymbol(name: name + "()", kind: kind, line: lineNum))
            }
            else if words[0] == "import" {
                symbols.append(CodeSymbol(name: words[1], kind: .import, line: lineNum))
            }
            else if words[0] == "from" && words.count >= 4 && words[2] == "import" {
                symbols.append(CodeSymbol(name: words[3], kind: .import, line: lineNum))
            }
            else if !line.hasPrefix(" ") && !line.hasPrefix("\t") && words.count >= 2 && words[1].hasPrefix("=") {
                let name = words[0]
                if !name.hasPrefix("_") && !name.hasPrefix("#") {
                    symbols.append(CodeSymbol(name: name, kind: .variable, line: lineNum))
                }
            }
        }
        
        return symbols
    }
    
    // MARK: - JavaScript/TypeScript Parser
    
    private static func parseJavaScript(_ content: String) -> [CodeSymbol] {
        var symbols: [CodeSymbol] = []
        let lines = content.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lineNum = index + 1
            var words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            guard !words.isEmpty else { continue }
            
            // Skip 'export' and 'default'
            while !words.isEmpty && (words[0] == "export" || words[0] == "default" || words[0] == "async") {
                words.removeFirst()
            }
            
            guard words.count >= 2 else { continue }
            
            let keyword = words[0]
            
            if keyword == "class" {
                let name = extractName(from: words[1])
                symbols.append(CodeSymbol(name: name, kind: .class, line: lineNum))
            }
            else if keyword == "interface" {
                let name = extractName(from: words[1])
                symbols.append(CodeSymbol(name: name, kind: .protocol, line: lineNum))
            }
            else if keyword == "type" && words.count >= 2 {
                let name = extractName(from: words[1])
                symbols.append(CodeSymbol(name: name, kind: .typealias, line: lineNum))
            }
            else if keyword == "enum" {
                let name = extractName(from: words[1])
                symbols.append(CodeSymbol(name: name, kind: .enum, line: lineNum))
            }
            else if keyword == "function" {
                let name = extractFunctionName(from: words[1])
                symbols.append(CodeSymbol(name: name + "()", kind: .function, line: lineNum))
            }
            else if keyword == "const" {
                let name = extractName(from: words[1])
                // Check if it's an arrow function
                if trimmed.contains("=>") || trimmed.contains("= (") || trimmed.contains("= async") {
                    symbols.append(CodeSymbol(name: name + "()", kind: .function, line: lineNum))
                } else {
                    symbols.append(CodeSymbol(name: name, kind: .constant, line: lineNum))
                }
            }
            else if keyword == "let" || keyword == "var" {
                let name = extractName(from: words[1])
                symbols.append(CodeSymbol(name: name, kind: .variable, line: lineNum))
            }
            else if keyword == "import" {
                // Find 'from' and extract module name
                if let fromIdx = words.firstIndex(of: "from"), fromIdx + 1 < words.count {
                    var moduleName = words[fromIdx + 1]
                    moduleName = moduleName.trimmingCharacters(in: CharacterSet(charactersIn: "\"';"))
                    symbols.append(CodeSymbol(name: moduleName, kind: .import, line: lineNum))
                }
            }
        }
        
        return symbols
    }
    
    // MARK: - Generic Parser
    
    private static func parseGeneric(_ content: String) -> [CodeSymbol] {
        var symbols: [CodeSymbol] = []
        let lines = content.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lineNum = index + 1
            let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            guard words.count >= 2 else { continue }
            
            let keyword = words[0]
            
            if keyword == "function" || keyword == "func" || keyword == "def" {
                let name = extractFunctionName(from: words[1])
                symbols.append(CodeSymbol(name: name + "()", kind: .function, line: lineNum))
            }
            else if keyword == "class" {
                let name = extractName(from: words[1])
                symbols.append(CodeSymbol(name: name, kind: .class, line: lineNum))
            }
        }
        
        return symbols
    }
}
