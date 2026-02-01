import Foundation

// MARK: - Advanced Agent Tools
// Additional tools to match Claude Code's capabilities

struct AdvancedAgentTools {
    
    // MARK: - File Discovery Tools
    
    /// Glob pattern file search (like Claude Code's file_search)
    static let globSearchTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "glob_search",
            "description": "Find files matching a glob pattern. Use for discovering files by name pattern.",
            "parameters": [
                "type": "object",
                "properties": [
                    "pattern": [
                        "type": "string",
                        "description": "Glob pattern (e.g., '**/*.swift', 'src/**/*.ts', '*.json')"
                    ],
                    "path": [
                        "type": "string",
                        "description": "Base directory to search from (optional, defaults to project root)"
                    ]
                ],
                "required": ["pattern"]
            ]
        ]
    ]
    
    /// Ripgrep-style content search
    static let grepTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "grep",
            "description": "Search file contents using regex. Fast ripgrep-style search with context lines.",
            "parameters": [
                "type": "object",
                "properties": [
                    "pattern": [
                        "type": "string",
                        "description": "Regex pattern to search for"
                    ],
                    "path": [
                        "type": "string",
                        "description": "File or directory to search in"
                    ],
                    "include": [
                        "type": "string",
                        "description": "File pattern to include (e.g., '*.swift')"
                    ],
                    "context_lines": [
                        "type": "integer",
                        "description": "Number of context lines before/after matches (default: 2)"
                    ],
                    "case_insensitive": [
                        "type": "boolean",
                        "description": "Case insensitive search (default: false)"
                    ]
                ],
                "required": ["pattern"]
            ]
        ]
    ]
    
    /// Batch file read
    static let batchReadTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "batch_read",
            "description": "Read multiple files at once. More efficient than multiple read_file calls.",
            "parameters": [
                "type": "object",
                "properties": [
                    "paths": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "Array of file paths to read"
                    ],
                    "max_lines_per_file": [
                        "type": "integer",
                        "description": "Maximum lines per file (optional, for large files)"
                    ]
                ],
                "required": ["paths"]
            ]
        ]
    ]
    
    // MARK: - Code Intelligence Tools
    
    /// Codebase semantic search
    static let codebaseSearchTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "codebase_search",
            "description": "Semantic search across the codebase. Find code by meaning, not just text.",
            "parameters": [
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "Natural language description of what you're looking for"
                    ],
                    "scope": [
                        "type": "string",
                        "description": "Scope to search: 'all', 'functions', 'classes', 'imports', 'comments'"
                    ]
                ],
                "required": ["query"]
            ]
        ]
    ]
    
    /// Find symbol definitions
    static let findDefinitionTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "find_definition",
            "description": "Find where a symbol (function, class, variable) is defined.",
            "parameters": [
                "type": "object",
                "properties": [
                    "symbol": [
                        "type": "string",
                        "description": "The symbol name to find"
                    ],
                    "type": [
                        "type": "string",
                        "description": "Symbol type: 'function', 'class', 'struct', 'enum', 'variable', 'any'"
                    ]
                ],
                "required": ["symbol"]
            ]
        ]
    ]
    
    /// Find symbol references
    static let findReferencesTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "find_references",
            "description": "Find all references/usages of a symbol.",
            "parameters": [
                "type": "object",
                "properties": [
                    "symbol": [
                        "type": "string",
                        "description": "The symbol name to find references for"
                    ]
                ],
                "required": ["symbol"]
            ]
        ]
    ]
    
    // MARK: - Development Tools
    
    /// Run linter
    static let lintTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "lint",
            "description": "Run linter on files and return errors/warnings.",
            "parameters": [
                "type": "object",
                "properties": [
                    "paths": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "Files or directories to lint (optional, defaults to changed files)"
                    ]
                ],
                "required": []
            ]
        ]
    ]
    
    /// Run tests
    static let testTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "run_tests",
            "description": "Run tests and return results.",
            "parameters": [
                "type": "object",
                "properties": [
                    "pattern": [
                        "type": "string",
                        "description": "Test name pattern to run (optional, runs all if not specified)"
                    ],
                    "path": [
                        "type": "string",
                        "description": "Directory containing tests"
                    ]
                ],
                "required": []
            ]
        ]
    ]
    
    /// Build project
    static let buildTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "build",
            "description": "Build the project and return any errors.",
            "parameters": [
                "type": "object",
                "properties": [
                    "target": [
                        "type": "string",
                        "description": "Build target (optional)"
                    ],
                    "configuration": [
                        "type": "string",
                        "description": "Build configuration: 'debug' or 'release'"
                    ]
                ],
                "required": []
            ]
        ]
    ]
    
    // MARK: - Task Management Tools
    
    /// Create/update task list
    static let todoTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "todo",
            "description": "Manage task list. Create, update, or complete tasks.",
            "parameters": [
                "type": "object",
                "properties": [
                    "action": [
                        "type": "string",
                        "description": "Action: 'list', 'add', 'update', 'complete', 'remove'"
                    ],
                    "task": [
                        "type": "string",
                        "description": "Task description (for add/update)"
                    ],
                    "id": [
                        "type": "string",
                        "description": "Task ID (for update/complete/remove)"
                    ],
                    "status": [
                        "type": "string",
                        "description": "Task status: 'pending', 'in_progress', 'completed'"
                    ]
                ],
                "required": ["action"]
            ]
        ]
    ]
    
    /// Memory/notes tool
    static let memoryTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "memory",
            "description": "Store or retrieve information for later use. Persists across sessions.",
            "parameters": [
                "type": "object",
                "properties": [
                    "action": [
                        "type": "string",
                        "description": "Action: 'store', 'retrieve', 'list', 'delete'"
                    ],
                    "key": [
                        "type": "string",
                        "description": "Memory key/identifier"
                    ],
                    "value": [
                        "type": "string",
                        "description": "Value to store (for 'store' action)"
                    ]
                ],
                "required": ["action"]
            ]
        ]
    ]
    
    // MARK: - Advanced File Operations
    
    /// Create directory
    static let mkdirTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "mkdir",
            "description": "Create a directory (and parent directories if needed).",
            "parameters": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "Directory path to create"
                    ]
                ],
                "required": ["path"]
            ]
        ]
    ]
    
    /// Move/rename file
    static let moveTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "move",
            "description": "Move or rename a file or directory.",
            "parameters": [
                "type": "object",
                "properties": [
                    "source": [
                        "type": "string",
                        "description": "Source path"
                    ],
                    "destination": [
                        "type": "string",
                        "description": "Destination path"
                    ]
                ],
                "required": ["source", "destination"]
            ]
        ]
    ]
    
    /// Delete file
    static let deleteTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "delete",
            "description": "Delete a file or empty directory.",
            "parameters": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "Path to delete"
                    ]
                ],
                "required": ["path"]
            ]
        ]
    ]
    
    // MARK: - Multi-Edit Tools
    
    /// Search and replace across files
    static let searchReplaceTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "search_replace",
            "description": "Search and replace text across multiple files.",
            "parameters": [
                "type": "object",
                "properties": [
                    "search": [
                        "type": "string",
                        "description": "Text or regex to search for"
                    ],
                    "replace": [
                        "type": "string",
                        "description": "Replacement text"
                    ],
                    "paths": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "Files to search in (optional, searches all code files)"
                    ],
                    "is_regex": [
                        "type": "boolean",
                        "description": "Treat search as regex (default: false)"
                    ],
                    "dry_run": [
                        "type": "boolean",
                        "description": "Preview changes without applying (default: false)"
                    ]
                ],
                "required": ["search", "replace"]
            ]
        ]
    ]
    
    /// Apply multiple edits to a file
    static let multiEditTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "multi_edit",
            "description": "Apply multiple edits to a single file atomically.",
            "parameters": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "File to edit"
                    ],
                    "edits": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "old_string": ["type": "string"],
                                "new_string": ["type": "string"]
                            ]
                        ],
                        "description": "Array of {old_string, new_string} edits to apply"
                    ]
                ],
                "required": ["path", "edits"]
            ]
        ]
    ]
    
    // MARK: - All Advanced Tools
    
    static let all: [[String: Any]] = [
        globSearchTool,
        grepTool,
        batchReadTool,
        codebaseSearchTool,
        findDefinitionTool,
        findReferencesTool,
        lintTool,
        testTool,
        buildTool,
        todoTool,
        memoryTool,
        mkdirTool,
        moveTool,
        deleteTool,
        searchReplaceTool,
        multiEditTool
    ]
}

// MARK: - Agent Task Tracker

@Observable
class AgentTaskTracker {
    struct Task: Identifiable, Codable {
        let id: String
        var content: String
        var status: Status
        var createdAt: Date
        var completedAt: Date?
        
        enum Status: String, Codable {
            case pending
            case inProgress = "in_progress"
            case completed
            case cancelled
        }
    }
    
    private(set) var tasks: [Task] = []
    private let storageURL: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageURL = appSupport.appendingPathComponent("OllamaBot/tasks.json")
        loadTasks()
    }
    
    func addTask(_ content: String) -> Task {
        let task = Task(
            id: UUID().uuidString,
            content: content,
            status: .pending,
            createdAt: Date()
        )
        tasks.append(task)
        saveTasks()
        return task
    }
    
    func updateTask(_ id: String, status: Task.Status) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].status = status
            if status == .completed {
                tasks[index].completedAt = Date()
            }
            saveTasks()
        }
    }
    
    func removeTask(_ id: String) {
        tasks.removeAll { $0.id == id }
        saveTasks()
    }
    
    private func loadTasks() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([Task].self, from: data) else {
            return
        }
        tasks = decoded
    }
    
    private func saveTasks() {
        try? FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(tasks) {
            try? data.write(to: storageURL)
        }
    }
}

// MARK: - Agent Memory Store

@Observable
class AgentMemoryStore {
    private(set) var memories: [String: String] = [:]
    private let storageURL: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageURL = appSupport.appendingPathComponent("OllamaBot/memory.json")
        loadMemories()
    }
    
    func store(key: String, value: String) {
        memories[key] = value
        saveMemories()
    }
    
    func retrieve(key: String) -> String? {
        memories[key]
    }
    
    func delete(key: String) {
        memories.removeValue(forKey: key)
        saveMemories()
    }
    
    func list() -> [String] {
        Array(memories.keys).sorted()
    }
    
    private func loadMemories() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        memories = decoded
    }
    
    private func saveMemories() {
        try? FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(memories) {
            try? data.write(to: storageURL)
        }
    }
}

// MARK: - Symbol Index

class SymbolIndex {
    struct Symbol: Identifiable {
        let id = UUID()
        let name: String
        let kind: Kind
        let file: String
        let line: Int
        let signature: String?
        
        enum Kind: String {
            case function, method, `class`, `struct`, `enum`, `protocol`, variable, constant, property
        }
    }
    
    private var symbols: [Symbol] = []
    private var indexedFiles: Set<String> = []
    
    func indexFile(_ path: String, content: String) {
        guard !indexedFiles.contains(path) else { return }
        
        let lines = content.components(separatedBy: .newlines)
        
        for (lineNum, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Swift patterns
            if let match = extractSwiftSymbol(trimmed, file: path, line: lineNum + 1) {
                symbols.append(match)
            }
            // TypeScript/JavaScript patterns
            else if let match = extractTSSymbol(trimmed, file: path, line: lineNum + 1) {
                symbols.append(match)
            }
            // Python patterns
            else if let match = extractPythonSymbol(trimmed, file: path, line: lineNum + 1) {
                symbols.append(match)
            }
        }
        
        indexedFiles.insert(path)
    }
    
    func findDefinition(_ name: String, kind: Symbol.Kind? = nil) -> [Symbol] {
        symbols.filter { symbol in
            symbol.name == name && (kind == nil || symbol.kind == kind)
        }
    }
    
    func findReferences(_ name: String, in content: String, file: String) -> [(line: Int, context: String)] {
        var refs: [(Int, String)] = []
        let lines = content.components(separatedBy: .newlines)
        
        for (lineNum, line) in lines.enumerated() {
            if line.contains(name) {
                refs.append((lineNum + 1, line.trimmingCharacters(in: .whitespaces)))
            }
        }
        
        return refs
    }
    
    private func extractSwiftSymbol(_ line: String, file: String, line lineNum: Int) -> Symbol? {
        // func name(
        if line.hasPrefix("func ") {
            let parts = line.dropFirst(5).components(separatedBy: "(")
            if let name = parts.first?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
                return Symbol(name: name, kind: .function, file: file, line: lineNum, signature: line)
            }
        }
        // class Name
        else if line.hasPrefix("class ") {
            let parts = line.dropFirst(6).components(separatedBy: CharacterSet(charactersIn: " :{"))
            if let name = parts.first?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
                return Symbol(name: name, kind: .class, file: file, line: lineNum, signature: nil)
            }
        }
        // struct Name
        else if line.hasPrefix("struct ") {
            let parts = line.dropFirst(7).components(separatedBy: CharacterSet(charactersIn: " :{"))
            if let name = parts.first?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
                return Symbol(name: name, kind: .struct, file: file, line: lineNum, signature: nil)
            }
        }
        // enum Name
        else if line.hasPrefix("enum ") {
            let parts = line.dropFirst(5).components(separatedBy: CharacterSet(charactersIn: " :{"))
            if let name = parts.first?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
                return Symbol(name: name, kind: .enum, file: file, line: lineNum, signature: nil)
            }
        }
        // protocol Name
        else if line.hasPrefix("protocol ") {
            let parts = line.dropFirst(9).components(separatedBy: CharacterSet(charactersIn: " :{"))
            if let name = parts.first?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
                return Symbol(name: name, kind: .protocol, file: file, line: lineNum, signature: nil)
            }
        }
        
        return nil
    }
    
    private func extractTSSymbol(_ line: String, file: String, line lineNum: Int) -> Symbol? {
        // function name( or async function name(
        if line.contains("function ") {
            if let range = line.range(of: "function ") {
                let after = String(line[range.upperBound...])
                let parts = after.components(separatedBy: "(")
                if let name = parts.first?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
                    return Symbol(name: name, kind: .function, file: file, line: lineNum, signature: line)
                }
            }
        }
        // class Name
        else if line.hasPrefix("class ") || line.contains(" class ") {
            if let range = line.range(of: "class ") {
                let after = String(line[range.upperBound...])
                let parts = after.components(separatedBy: CharacterSet(charactersIn: " {"))
                if let name = parts.first?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
                    return Symbol(name: name, kind: .class, file: file, line: lineNum, signature: nil)
                }
            }
        }
        
        return nil
    }
    
    private func extractPythonSymbol(_ line: String, file: String, line lineNum: Int) -> Symbol? {
        // def name(
        if line.hasPrefix("def ") {
            let parts = line.dropFirst(4).components(separatedBy: "(")
            if let name = parts.first?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
                return Symbol(name: name, kind: .function, file: file, line: lineNum, signature: line)
            }
        }
        // class Name
        else if line.hasPrefix("class ") {
            let parts = line.dropFirst(6).components(separatedBy: CharacterSet(charactersIn: " (:"))
            if let name = parts.first?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
                return Symbol(name: name, kind: .class, file: file, line: lineNum, signature: nil)
            }
        }
        
        return nil
    }
}
