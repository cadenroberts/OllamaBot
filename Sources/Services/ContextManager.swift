import Foundation

// MARK: - Unified Context Manager
//
// The single source of truth for ALL context management in OllamaBot.
// Used by: Chat, Agent, Inline Completions, Git Operations
//
// Responsibilities:
// 1. Token budget allocation across context types
// 2. Semantic compression of large contexts
// 3. Inter-agent context passing (orchestrator ↔ specialists)
// 4. Conversation memory with intelligent pruning
// 5. Project semantic cache
// 6. Priority-based context inclusion
// 7. Chat context building (replaces ContextBuilder)
// 8. Language detection and file metadata

@Observable
final class ContextManager {
    
    // MARK: - Configuration
    
    struct Config {
        var maxTotalTokens: Int = 8192
        var reservedForResponse: Int = 2048
        var maxConversationHistory: Int = 20
        var maxFileContext: Int = 3000
        var maxProjectContext: Int = 1000
        var maxToolResults: Int = 2000
        
        var availableForContext: Int {
            maxTotalTokens - reservedForResponse
        }
    }
    
    var config = Config()
    
    // MARK: - Memory Stores
    
    /// Conversation memory - persists across agent runs
    private var conversationMemory: [MemoryEntry] = []
    
    /// Project semantic cache - understanding of codebase
    private var projectCache: ProjectSemanticCache?
    
    /// Recent tool results for reference (capped at 50)
    private var recentToolResults: [ToolResultEntry] = []
    private let maxToolResults = 50
    
    /// Error patterns for learning
    private var errorPatterns: [String: Int] = [:]
    
    /// Project rules from .obotrules (OBot integration)
    private(set) var projectRules: ProjectRules?
    
    // MARK: - OBot Rules Integration
    
    /// Set project rules from .obotrules file
    func setProjectRules(_ rules: ProjectRules) {
        self.projectRules = rules
        print("📋 ContextManager: Project rules loaded (\(rules.sections.count) sections)")
    }
    
    /// Clear project rules
    func clearProjectRules() {
        self.projectRules = nil
    }
    
    /// Get rules content formatted for AI context
    func getProjectRulesContext() -> String? {
        guard let rules = projectRules else { return nil }
        
        var context = "=== PROJECT RULES (.obotrules) ===\n"
        for section in rules.sections {
            context += "\n## \(section.title)\n\(section.content)\n"
        }
        return context
    }
    
    // MARK: - Language Mapping (Centralized)
    
    static let languageNames: [String: String] = [
        "swift": "Swift", "py": "Python", "js": "JavaScript",
        "ts": "TypeScript", "tsx": "TypeScript (React)", "jsx": "JavaScript (React)",
        "rs": "Rust", "go": "Go", "rb": "Ruby", "java": "Java",
        "kt": "Kotlin", "c": "C", "cpp": "C++", "cc": "C++", "cxx": "C++",
        "h": "C/C++ Header", "cs": "C#", "php": "PHP",
        "html": "HTML", "css": "CSS", "scss": "SCSS",
        "json": "JSON", "yaml": "YAML", "yml": "YAML",
        "xml": "XML", "md": "Markdown", "sh": "Shell", "bash": "Shell", "sql": "SQL"
    ]
    
    static func languageName(for ext: String) -> String {
        languageNames[ext.lowercased()] ?? "Plain Text"
    }
    
    // MARK: - Chat Context (replaces ContextBuilder)
    
    /// Build context for chat messages - used by AppState.sendMessage()
    func buildChatContext(
        message: String,
        editorContent: String?,
        selectedText: String?,
        openFiles: [FileItem],
        currentFile: FileItem?
    ) -> String? {
        var sections: [String] = []
        var tokenBudget = config.maxFileContext
        
        // 1. Selected text (highest priority)
        if let selected = selectedText, !selected.isEmpty {
            let trimmed = compressCode(selected, maxTokens: tokenBudget / 3)
            sections.append("=== SELECTED CODE ===\n\(trimmed)")
            tokenBudget -= estimateTokens(trimmed)
        }
        
        // 2. Current file content
        if let content = editorContent, !content.isEmpty, tokenBudget > 500 {
            let fileName = currentFile?.name ?? "Current File"
            let ext = currentFile?.url.pathExtension ?? ""
            let lang = Self.languageName(for: ext)
            
            let compressed = compressCode(content, maxTokens: tokenBudget / 2)
            sections.append("=== \(fileName) (\(lang)) ===\n\(compressed)")
            tokenBudget -= estimateTokens(compressed)
        }
        
        // 3. Open files list
        if !openFiles.isEmpty, tokenBudget > 100 {
            let fileList = openFiles.prefix(10).map { "• \($0.name)" }.joined(separator: "\n")
            sections.append("=== OPEN FILES ===\n\(fileList)")
        }
        
        // 4. Project structure (if cached)
        if let cache = projectCache, tokenBudget > 200 {
            sections.append("=== PROJECT: \(cache.rootPath.split(separator: "/").last ?? "") ===\n\(cache.structure.prefix(500))")
        }
        
        // 5. Project rules from .obotrules (if present)
        if let rulesContext = getProjectRulesContext(), tokenBudget > 300 {
            let compressed = compressCode(rulesContext, maxTokens: 500)
            sections.insert(compressed, at: 0) // Rules go first
        }
        
        return sections.isEmpty ? nil : sections.joined(separator: "\n\n")
    }
    
    /// Build context for inline code completions
    func buildCompletionContext(
        code: String,
        cursorPosition: Int,
        language: String,
        filePath: String?
    ) -> String {
        let prefix = String(code.prefix(cursorPosition))
        let suffix = String(code.dropFirst(min(cursorPosition, code.count)))
        
        // Get surrounding lines
        let prefixLines = prefix.components(separatedBy: .newlines).suffix(20)
        let suffixLines = suffix.components(separatedBy: .newlines).prefix(5)
        
        return """
        Language: \(Self.languageName(for: language))
        File: \(filePath ?? "untitled")
        
        === Before Cursor ===
        \(prefixLines.joined(separator: "\n"))
        
        === After Cursor ===
        \(suffixLines.joined(separator: "\n"))
        """
    }
    
    /// Extract a snippet around a specific line (for error context, etc.)
    func extractSnippet(from content: String, aroundLine line: Int, contextLines: Int = 10) -> String {
        let lines = content.components(separatedBy: .newlines)
        guard line > 0, line <= lines.count else { return "" }
        
        let start = max(0, line - contextLines - 1)
        let end = min(lines.count, line + contextLines)
        
        var snippet = ""
        for i in start..<end {
            let marker = (i + 1 == line) ? ">>> " : "    "
            snippet += "\(marker)\(i + 1): \(lines[i])\n"
        }
        return snippet
    }
    
    // MARK: - Agent Context
    
    /// Build optimized context for the orchestrator agent
    func buildOrchestratorContext(
        task: String,
        workingDirectory: URL?,
        previousSteps: [AgentStep] = []
    ) -> OrchestratorContext {
        var budget = TokenBudget(total: config.availableForContext)
        var sections: [ContextSection] = []
        
        // 1. Task (always included, highest priority)
        let taskSection = ContextSection(
            type: .task,
            content: task,
            priority: .critical,
            estimatedTokens: estimateTokens(task)
        )
        sections.append(taskSection)
        budget.allocate(taskSection.estimatedTokens, for: .task)
        
        // 2. Working directory context
        if let dir = workingDirectory {
            let dirContext = buildDirectoryContext(dir, maxTokens: budget.remaining(for: .project))
            if !dirContext.isEmpty {
                let section = ContextSection(
                    type: .project,
                    content: dirContext,
                    priority: .high,
                    estimatedTokens: estimateTokens(dirContext)
                )
                sections.append(section)
                budget.allocate(section.estimatedTokens, for: .project)
            }
        }
        
        // 3. Recent steps summary (for continuity)
        if !previousSteps.isEmpty {
            let stepsSummary = summarizeSteps(previousSteps, maxTokens: budget.remaining(for: .history))
            let section = ContextSection(
                type: .history,
                content: stepsSummary,
                priority: .medium,
                estimatedTokens: estimateTokens(stepsSummary)
            )
            sections.append(section)
            budget.allocate(section.estimatedTokens, for: .history)
        }
        
        // 4. Relevant memories
        let memories = retrieveRelevantMemories(for: task, maxTokens: budget.remaining(for: .memory))
        if !memories.isEmpty {
            let memoryContent = memories.map { "• \($0.summary)" }.joined(separator: "\n")
            let section = ContextSection(
                type: .memory,
                content: "RELEVANT PAST CONTEXT:\n\(memoryContent)",
                priority: .medium,
                estimatedTokens: estimateTokens(memoryContent)
            )
            sections.append(section)
            budget.allocate(section.estimatedTokens, for: ContextSection.SectionType.memory)
        }
        
        // 5. Error patterns (if relevant)
        if let errorAdvice = getErrorAdvice(for: task) {
            let section = ContextSection(
                type: .errors,
                content: "⚠️ WATCH OUT: \(errorAdvice)",
                priority: .high,
                estimatedTokens: estimateTokens(errorAdvice)
            )
            sections.append(section)
            budget.allocate(section.estimatedTokens, for: ContextSection.SectionType.errors)
        }
        
        return OrchestratorContext(
            sections: sections,
            budget: budget,
            systemPrompt: buildSystemPrompt(workingDirectory: workingDirectory)
        )
    }
    
    /// Build context for delegating to a specialist model
    func buildDelegationContext(
        for model: OllamaModel,
        task: String,
        orchestratorContext: String,
        relevantFiles: [String: String] = [:]
    ) -> DelegationContext {
        var content = ""
        var estimatedTokens = 0
        let maxTokens = OllamaService.modelContextWindows[model] ?? 8192
        let availableTokens = maxTokens - config.reservedForResponse
        
        // Task is always included
        content += "## TASK\n\(task)\n\n"
        estimatedTokens += estimateTokens(task)
        
        // Add relevant file contents (compressed if needed)
        if !relevantFiles.isEmpty {
            content += "## RELEVANT CODE\n"
            for (filename, fileContent) in relevantFiles {
                let maxFileTokens = (availableTokens - estimatedTokens) / max(1, relevantFiles.count)
                let compressed = compressCode(fileContent, maxTokens: maxFileTokens)
                content += "### \(filename)\n```\n\(compressed)\n```\n\n"
                estimatedTokens += estimateTokens(compressed) + 10
                
                if estimatedTokens > availableTokens * 8 / 10 { break }
            }
        }
        
        // Add orchestrator hints (compressed)
        if !orchestratorContext.isEmpty && estimatedTokens < availableTokens * 9 / 10 {
            let remainingTokens = availableTokens - estimatedTokens - 100
            let compressedContext = compressContext(orchestratorContext, maxTokens: remainingTokens)
            content += "## CONTEXT\n\(compressedContext)\n"
        }
        
        return DelegationContext(
            model: model,
            content: content,
            estimatedTokens: estimatedTokens,
            systemPrompt: buildSpecialistSystemPrompt(for: model)
        )
    }
    
    /// Record a memory entry from agent execution
    func recordMemory(_ entry: MemoryEntry) {
        conversationMemory.append(entry)
        
        // Prune old memories if over limit
        if conversationMemory.count > config.maxConversationHistory * 2 {
            pruneMemories()
        }
    }
    
    /// Record an error pattern for learning
    func recordError(_ error: String, context: String) {
        let key = categorizeError(error)
        errorPatterns[key, default: 0] += 1
    }
    
    /// Record tool result for future reference
    func recordToolResult(_ name: String, input: String, output: String, success: Bool) {
        let entry = ToolResultEntry(
            toolName: name,
            input: input,
            output: String(output.prefix(500)),
            success: success,
            timestamp: Date()
        )
        recentToolResults.append(entry)
        
        // Keep capped
        if recentToolResults.count > maxToolResults {
            recentToolResults.removeFirst()
        }
    }
    
    /// Update project semantic cache
    func updateProjectCache(root: URL, files: [FileItem]) {
        projectCache = ProjectSemanticCache(
            rootPath: root.path,
            fileCount: files.count,
            structure: buildProjectStructure(files),
            lastUpdated: Date()
        )
    }
    
    // MARK: - Private Helpers
    
    private func buildSystemPrompt(workingDirectory: URL?) -> String {
        """
        You are ORCHESTRATOR (Qwen3 32B), the central coordinator of OllamaBot.
        
        YOUR ROLE: Plan, delegate, and verify. You THINK before acting.
        
        YOUR SPECIALISTS:
        • delegate_to_coder - Qwen2.5-Coder 32B for code generation/debugging
        • delegate_to_researcher - Command-R 35B for research/documentation  
        • delegate_to_vision - Qwen3-VL 32B for image/screenshot analysis
        
        YOUR TOOLS: think, read_file, write_file, edit_file, search_files, list_directory, run_command, web_search, fetch_url, git_status, git_diff, git_commit, ask_user, complete
        
        WORKFLOW:
        1. THINK - Understand the task, plan your approach
        2. GATHER - Read relevant files, search codebase
        3. DELEGATE - Send specialized tasks to appropriate model
        4. VERIFY - Check results, run tests if applicable
        5. COMPLETE - Summarize what was done
        
        RULES:
        • Always use think() first to plan
        • Delegate complex coding to coder, research to researcher
        • Make small, targeted edits (not whole file rewrites)
        • Verify changes compile/work before completing
        
        CWD: \(workingDirectory?.path ?? "Not set")
        """
    }
    
    private func buildSpecialistSystemPrompt(for model: OllamaModel) -> String {
        switch model {
        case .coder:
            return """
            You are CODER (Qwen2.5-Coder 32B), a specialized code expert.
            
            YOUR ROLE: Write clean, efficient, working code.
            
            RULES:
            • Output ONLY code unless explanation is explicitly requested
            • Follow existing code style and conventions
            • Include necessary imports
            • Handle edge cases
            • Use descriptive variable names
            
            OUTPUT FORMAT: Code first, minimal explanation after.
            """
            
        case .commandR:
            return """
            You are RESEARCHER (Command-R 35B), an information specialist.
            
            YOUR ROLE: Provide accurate, well-structured information.
            
            RULES:
            • Be concise but complete
            • Cite sources when possible
            • Structure with headers/bullets for clarity
            • Distinguish facts from opinions
            • Note any uncertainties
            
            OUTPUT FORMAT: Structured response with clear sections.
            """
            
        case .vision:
            return """
            You are VISION (Qwen3-VL 32B), a visual analysis expert.
            
            YOUR ROLE: Analyze images and describe what you see.
            
            RULES:
            • Describe layout, elements, text, colors
            • Note any UI issues or anomalies
            • Be specific about positions (top-left, center, etc.)
            • Extract any readable text
            
            OUTPUT FORMAT: Structured description of visual elements.
            """
            
        case .qwen3:
            return "" // Orchestrator uses main system prompt
        }
    }
    
    private func buildDirectoryContext(_ dir: URL, maxTokens: Int) -> String {
        guard let cache = projectCache, cache.rootPath == dir.path else {
            return "Project: \(dir.lastPathComponent)"
        }
        
        var context = "PROJECT: \(dir.lastPathComponent)\n"
        context += "Files: \(cache.fileCount)\n"
        
        // Add structure summary if space allows
        if maxTokens > 200 {
            context += "\nSTRUCTURE:\n\(cache.structure.prefix(maxTokens * 3))"
        }
        
        return context
    }
    
    private func summarizeSteps(_ steps: [AgentStep], maxTokens: Int) -> String {
        let recentSteps = steps.suffix(10)
        var summary = "RECENT ACTIONS:\n"
        
        for step in recentSteps {
            let line: String
            switch step.type {
            case .thinking(let thought):
                line = "• Thought: \(thought.prefix(50))..."
            case .tool(let name, let input, _):
                line = "• \(name): \(input.prefix(30))"
            case .complete(let msg):
                line = "• Completed: \(msg.prefix(50))"
            default:
                continue
            }
            
            if estimateTokens(summary + line) > maxTokens { break }
            summary += line + "\n"
        }
        
        return summary
    }
    
    private func retrieveRelevantMemories(for task: String, maxTokens: Int) -> [MemoryEntry] {
        // Simple keyword matching (could be upgraded to embeddings)
        let taskWords = Set(task.lowercased().split(separator: " ").map(String.init))
        
        let scored = conversationMemory.map { memory -> (MemoryEntry, Int) in
            let memoryWords = Set(memory.summary.lowercased().split(separator: " ").map(String.init))
            let overlap = taskWords.intersection(memoryWords).count
            return (memory, overlap)
        }
        
        let relevant = scored
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0.0 }
        
        return Array(relevant)
    }
    
    private func getErrorAdvice(for task: String) -> String? {
        // Check if task mentions something we've seen errors with
        for (pattern, count) in errorPatterns where count >= 2 {
            if task.lowercased().contains(pattern.lowercased()) {
                return "Previously encountered issues with '\(pattern)'. Be careful."
            }
        }
        return nil
    }
    
    private func categorizeError(_ error: String) -> String {
        let lowered = error.lowercased()
        if lowered.contains("permission") { return "permissions" }
        if lowered.contains("not found") { return "file_not_found" }
        if lowered.contains("syntax") { return "syntax_error" }
        if lowered.contains("timeout") { return "timeout" }
        if lowered.contains("memory") { return "memory" }
        return "general"
    }
    
    private func pruneMemories() {
        // Keep most recent and most accessed
        let sorted = conversationMemory.sorted { $0.accessCount > $1.accessCount }
        let topAccessed = sorted.prefix(config.maxConversationHistory / 2)
        let recent = conversationMemory.suffix(config.maxConversationHistory / 2)
        
        conversationMemory = Array(Set(topAccessed).union(Set(recent)))
    }
    
    private func buildProjectStructure(_ files: [FileItem]) -> String {
        var byDir: [String: [String]] = [:]
        
        for file in files.prefix(100) {
            let dir = file.url.deletingLastPathComponent().lastPathComponent
            byDir[dir, default: []].append(file.name)
        }
        
        var structure = ""
        for (dir, files) in byDir.sorted(by: { $0.key < $1.key }).prefix(10) {
            structure += "\(dir)/\n"
            for file in files.prefix(5) {
                structure += "  \(file)\n"
            }
            if files.count > 5 {
                structure += "  ... +\(files.count - 5) more\n"
            }
        }
        
        return structure
    }
    
    // MARK: - Compression Utilities
    
    private func compressCode(_ code: String, maxTokens: Int) -> String {
        let tokens = estimateTokens(code)
        if tokens <= maxTokens { return code }
        
        // Strategy: Keep first part, last part, and important lines
        let lines = code.components(separatedBy: .newlines)
        let targetLines = maxTokens / 4 // Rough estimate
        
        if lines.count <= targetLines { return code }
        
        let keepStart = targetLines / 3
        let keepEnd = targetLines / 3
        
        var compressed = lines.prefix(keepStart).joined(separator: "\n")
        compressed += "\n\n// ... \(lines.count - keepStart - keepEnd) lines omitted ...\n\n"
        compressed += lines.suffix(keepEnd).joined(separator: "\n")
        
        return compressed
    }
    
    private func compressContext(_ context: String, maxTokens: Int) -> String {
        let tokens = estimateTokens(context)
        if tokens <= maxTokens { return context }
        
        // Just truncate for now (could be smarter with summarization)
        let ratio = Double(maxTokens) / Double(tokens)
        let targetChars = Int(Double(context.count) * ratio * 0.9)
        
        return String(context.prefix(targetChars)) + "\n[truncated]"
    }
    
    private func estimateTokens(_ text: String) -> Int {
        // Rough estimate: ~4 chars per token for English
        text.count / 4
    }
}

// MARK: - Supporting Types

struct ContextSection {
    enum SectionType {
        case task, project, file, history, memory, errors, toolResults
    }
    
    enum Priority: Int, Comparable {
        case low = 0, medium = 1, high = 2, critical = 3
        
        static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    let type: SectionType
    let content: String
    let priority: Priority
    let estimatedTokens: Int
}

struct TokenBudget {
    let total: Int
    var allocated: [ContextSection.SectionType: Int] = [:]
    
    init(total: Int) {
        self.total = total
        self.allocated = [:]
    }
    
    mutating func allocate(_ tokens: Int, for type: ContextSection.SectionType) {
        allocated[type, default: 0] += tokens
    }
    
    func remaining(for type: ContextSection.SectionType) -> Int {
        let used = allocated.values.reduce(0, +)
        let typeMax: Int
        switch type {
        case .task: typeMax = total / 4
        case .project: typeMax = total / 6
        case .file: typeMax = total / 3
        case .history: typeMax = total / 8
        case .memory: typeMax = total / 8
        case .errors: typeMax = total / 16
        case .toolResults: typeMax = total / 6
        }
        return min(total - used, typeMax)
    }
    
    var totalRemaining: Int {
        total - allocated.values.reduce(0, +)
    }
}

struct OrchestratorContext {
    let sections: [ContextSection]
    let budget: TokenBudget
    let systemPrompt: String
    
    var combinedContext: String {
        sections
            .sorted { $0.priority > $1.priority }
            .map { $0.content }
            .joined(separator: "\n\n---\n\n")
    }
}

struct DelegationContext {
    let model: OllamaModel
    let content: String
    let estimatedTokens: Int
    let systemPrompt: String
}

struct MemoryEntry: Hashable {
    let id = UUID()
    let summary: String
    let task: String
    let result: String
    let timestamp: Date
    var accessCount: Int = 0
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MemoryEntry, rhs: MemoryEntry) -> Bool {
        lhs.id == rhs.id
    }
}

struct ToolResultEntry {
    let toolName: String
    let input: String
    let output: String
    let success: Bool
    let timestamp: Date
}

struct ProjectSemanticCache {
    let rootPath: String
    let fileCount: Int
    let structure: String
    let lastUpdated: Date
}

// MARK: - Tool Result Ring Buffer (uses RingBuffer from PerformanceCore)

typealias ToolResultBuffer = [ToolResultEntry]
