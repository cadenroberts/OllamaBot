import Foundation

class ContextBuilder {
    
    /// Builds comprehensive context for the AI model based on current IDE state
    func buildContext(
        message: String,
        editorContent: String?,
        selectedText: String?,
        openFiles: [FileItem],
        fileSystemService: FileSystemService
    ) -> String? {
        var contextParts: [String] = []
        
        // Add selected text context (highest priority)
        if let selectedText = selectedText, !selectedText.isEmpty {
            contextParts.append("""
            === SELECTED TEXT ===
            \(selectedText)
            """)
        }
        
        // Add current file context
        if let content = editorContent, !content.isEmpty {
            // Truncate if too long
            let truncatedContent: String
            if content.count > 10000 {
                let startIndex = content.startIndex
                let endIndex = content.index(startIndex, offsetBy: 10000)
                truncatedContent = String(content[startIndex..<endIndex]) + "\n... (truncated)"
            } else {
                truncatedContent = content
            }
            
            contextParts.append("""
            === CURRENT FILE CONTENT ===
            \(truncatedContent)
            """)
        }
        
        // Add open files list
        if !openFiles.isEmpty {
            let fileList = openFiles.map { "- \($0.name) (\($0.url.path))" }.joined(separator: "\n")
            contextParts.append("""
            === OPEN FILES ===
            \(fileList)
            """)
        }
        
        // Return nil if no context to provide
        if contextParts.isEmpty {
            return nil
        }
        
        return contextParts.joined(separator: "\n\n")
    }
    
    /// Builds context specifically for code-related tasks
    func buildCodeContext(
        editorContent: String,
        selectedText: String?,
        fileName: String,
        fileExtension: String,
        cursorPosition: (line: Int, column: Int)?
    ) -> String {
        var context = """
        File: \(fileName)
        Language: \(languageName(for: fileExtension))
        """
        
        if let position = cursorPosition {
            context += "\nCursor: Line \(position.line), Column \(position.column)"
        }
        
        if let selected = selectedText, !selected.isEmpty {
            context += "\n\n=== SELECTED CODE ===\n\(selected)"
        }
        
        context += "\n\n=== FULL FILE ===\n\(editorContent)"
        
        return context
    }
    
    /// Extracts relevant snippets around a specific location
    func extractRelevantSnippet(
        from content: String,
        aroundLine lineNumber: Int,
        contextLines: Int = 10
    ) -> String {
        let lines = content.components(separatedBy: .newlines)
        let startLine = max(0, lineNumber - contextLines - 1)
        let endLine = min(lines.count, lineNumber + contextLines)
        
        var snippet = ""
        for i in startLine..<endLine {
            let linePrefix = i + 1 == lineNumber ? ">>> " : "    "
            snippet += "\(linePrefix)\(i + 1): \(lines[i])\n"
        }
        
        return snippet
    }
    
    /// Builds project context from directory structure
    func buildProjectContext(from root: URL, fileSystemService: FileSystemService) -> String {
        let files = fileSystemService.getAllFiles(in: root)
        
        var byExtension: [String: Int] = [:]
        for file in files {
            let ext = file.fileExtension ?? "other"
            byExtension[ext, default: 0] += 1
        }
        
        var context = "Project: \(root.lastPathComponent)\n"
        context += "Total files: \(files.count)\n\n"
        context += "File types:\n"
        
        for (ext, count) in byExtension.sorted(by: { $0.value > $1.value }).prefix(10) {
            context += "  .\(ext): \(count)\n"
        }
        
        return context
    }
    
    // MARK: - Private Helpers
    
    private func languageName(for extension: String) -> String {
        switch `extension`.lowercased() {
        case "swift": return "Swift"
        case "py": return "Python"
        case "js": return "JavaScript"
        case "ts": return "TypeScript"
        case "tsx": return "TypeScript (React)"
        case "jsx": return "JavaScript (React)"
        case "rs": return "Rust"
        case "go": return "Go"
        case "rb": return "Ruby"
        case "java": return "Java"
        case "kt": return "Kotlin"
        case "c": return "C"
        case "cpp", "cc", "cxx": return "C++"
        case "h": return "C/C++ Header"
        case "cs": return "C#"
        case "php": return "PHP"
        case "html": return "HTML"
        case "css": return "CSS"
        case "scss": return "SCSS"
        case "json": return "JSON"
        case "yaml", "yml": return "YAML"
        case "xml": return "XML"
        case "md": return "Markdown"
        case "sh", "bash": return "Shell"
        case "sql": return "SQL"
        default: return "Plain Text"
        }
    }
}
