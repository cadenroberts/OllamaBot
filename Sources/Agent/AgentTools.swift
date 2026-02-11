import Foundation

// MARK: - Tool Definitions (Ollama Function Calling Format)

/// Tools available to the agent - matches Ollama's tool calling schema
struct AgentTools {
    
    /// All available tools for the orchestrator
    static let all: [[String: Any]] = [
        // Core file tools
        readFileTool,
        writeFileTool,
        editFileTool,
        searchFilesTool,
        listDirectoryTool,
        runCommandTool,
        askUserTool,
        thinkTool,
        completeTool,
        // Multi-model delegation tools
        delegateToCoderTool,
        delegateToResearcherTool,
        delegateToVisionTool,
        takeScreenshotTool,
        // Web tools
        webSearchTool,
        fetchUrlTool,
        // Git tools
        gitStatusTool,
        gitDiffTool,
        gitCommitTool
    ] + AdvancedAgentTools.all  // Include advanced tools
    
    // MARK: - File Tools
    
    static let readFileTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "read_file",
            "description": "Read the contents of a file at the given path",
            "parameters": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "The file path to read"
                    ]
                ],
                "required": ["path"]
            ]
        ]
    ]
    
    static let writeFileTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "write_file",
            "description": "Write content to a file, creating it if it doesn't exist",
            "parameters": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "The file path to write to"
                    ],
                    "content": [
                        "type": "string",
                        "description": "The content to write"
                    ]
                ],
                "required": ["path", "content"]
            ]
        ]
    ]
    
    static let editFileTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "edit_file",
            "description": "Edit a file by replacing old_string with new_string OR by providing a line range (range) and new content. Line ranges are 1-indexed.",
            "parameters": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "The file path to edit"
                    ],
                    "old_string": [
                        "type": "string",
                        "description": "The exact string to find and replace (optional if using line ranges)"
                    ],
                    "new_string": [
                        "type": "string",
                        "description": "The string to replace it with (optional if using line ranges)"
                    ],
                    "range": [
                        "type": "string",
                        "description": "The line range to edit in format '-start +end' (e.g., '-10 +20'). 1-indexed. (optional)"
                    ],
                    "new_content": [
                        "type": "string",
                        "description": "The new content for the specified line range (optional)"
                    ]
                ],
                "required": ["path"]
            ]
        ]
    ]
    
    static let searchFilesTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "search_files",
            "description": "Search for files containing a pattern in their content",
            "parameters": [
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "The search query"
                    ],
                    "path": [
                        "type": "string",
                        "description": "Directory to search in (optional, defaults to project root)"
                    ]
                ],
                "required": ["query"]
            ]
        ]
    ]
    
    static let listDirectoryTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "list_directory",
            "description": "List files and directories at a path",
            "parameters": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "The directory path to list"
                    ]
                ],
                "required": ["path"]
            ]
        ]
    ]
    
    // MARK: - Terminal Tool
    
    static let runCommandTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "run_command",
            "description": "Run a shell command and return the output. Use for building, testing, git, etc.",
            "parameters": [
                "type": "object",
                "properties": [
                    "command": [
                        "type": "string",
                        "description": "The shell command to execute"
                    ],
                    "working_directory": [
                        "type": "string",
                        "description": "Directory to run command in (optional)"
                    ]
                ],
                "required": ["command"]
            ]
        ]
    ]
    
    // MARK: - Interaction Tools
    
    static let askUserTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "ask_user",
            "description": "Ask the user a question and wait for their response",
            "parameters": [
                "type": "object",
                "properties": [
                    "question": [
                        "type": "string",
                        "description": "The question to ask the user"
                    ]
                ],
                "required": ["question"]
            ]
        ]
    ]
    
    static let thinkTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "think",
            "description": "Think through a problem step by step. Use this to plan before taking action.",
            "parameters": [
                "type": "object",
                "properties": [
                    "thought": [
                        "type": "string",
                        "description": "Your reasoning and thought process"
                    ]
                ],
                "required": ["thought"]
            ]
        ]
    ]
    
    static let completeTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "complete",
            "description": "Signal that the task is complete",
            "parameters": [
                "type": "object",
                "properties": [
                    "summary": [
                        "type": "string",
                        "description": "Summary of what was accomplished"
                    ]
                ],
                "required": ["summary"]
            ]
        ]
    ]
    
    // MARK: - Multi-Model Delegation Tools
    
    /// Delegate coding tasks to Qwen2.5-Coder 32B
    static let delegateToCoderTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "delegate_to_coder",
            "description": "Delegate a coding task to the specialized Qwen2.5-Coder model. Use for complex code generation, refactoring, debugging, or code review. The coder model is optimized for programming tasks.",
            "parameters": [
                "type": "object",
                "properties": [
                    "task": [
                        "type": "string",
                        "description": "The coding task to perform (e.g., 'Write a function that...', 'Refactor this code to...', 'Debug this error...')"
                    ],
                    "context": [
                        "type": "string",
                        "description": "Relevant code context, file contents, or error messages to include"
                    ],
                    "language": [
                        "type": "string",
                        "description": "The programming language (e.g., 'swift', 'python', 'typescript')"
                    ]
                ],
                "required": ["task"]
            ]
        ]
    ]
    
    /// Delegate research tasks to Command-R 35B
    static let delegateToResearcherTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "delegate_to_researcher",
            "description": "Delegate a research or information retrieval task to the Command-R model. Optimized for RAG, document analysis, answering questions about concepts, and providing citations. Use when you need factual information or analysis.",
            "parameters": [
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "The research question or topic to investigate"
                    ],
                    "context": [
                        "type": "string",
                        "description": "Any relevant context, documents, or information to analyze"
                    ],
                    "format": [
                        "type": "string",
                        "description": "Desired output format (e.g., 'summary', 'bullet points', 'detailed analysis', 'comparison')"
                    ]
                ],
                "required": ["query"]
            ]
        ]
    ]
    
    /// Delegate vision tasks to Qwen3-VL 32B
    static let delegateToVisionTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "delegate_to_vision",
            "description": "Delegate an image analysis task to the Qwen3-VL vision model. Use for analyzing screenshots, UI inspection, reading text from images, or understanding visual content.",
            "parameters": [
                "type": "object",
                "properties": [
                    "task": [
                        "type": "string",
                        "description": "What to analyze or look for in the image"
                    ],
                    "image_path": [
                        "type": "string",
                        "description": "Path to the image file to analyze"
                    ]
                ],
                "required": ["task", "image_path"]
            ]
        ]
    ]
    
    /// Take a screenshot for analysis
    static let takeScreenshotTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "take_screenshot",
            "description": "Capture a screenshot of the current screen or a specific window for analysis. Returns the path to the saved screenshot.",
            "parameters": [
                "type": "object",
                "properties": [
                    "region": [
                        "type": "string",
                        "description": "What to capture: 'full' for entire screen, 'window' for frontmost window, or 'selection' for user selection"
                    ],
                    "filename": [
                        "type": "string",
                        "description": "Optional filename for the screenshot (defaults to timestamp)"
                    ]
                ],
                "required": []
            ]
        ]
    ]
    
    // MARK: - Web Tools
    
    /// Search the web using DuckDuckGo
    static let webSearchTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "web_search",
            "description": "Search the web for information using DuckDuckGo. Returns titles, URLs, and snippets of the top results. Use for finding documentation, tutorials, or current information.",
            "parameters": [
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "The search query"
                    ],
                    "max_results": [
                        "type": "integer",
                        "description": "Maximum number of results to return (default 5)"
                    ]
                ],
                "required": ["query"]
            ]
        ]
    ]
    
    /// Fetch content from a URL
    static let fetchUrlTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "fetch_url",
            "description": "Fetch and extract text content from a web URL. Useful for reading documentation pages, articles, or any web content.",
            "parameters": [
                "type": "object",
                "properties": [
                    "url": [
                        "type": "string",
                        "description": "The URL to fetch"
                    ],
                    "max_length": [
                        "type": "integer",
                        "description": "Maximum characters to return (default 5000)"
                    ]
                ],
                "required": ["url"]
            ]
        ]
    ]
    
    // MARK: - Git Tools
    
    /// Get git status
    static let gitStatusTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "git_status",
            "description": "Get the current git status including staged, unstaged, and untracked files, as well as branch information.",
            "parameters": [
                "type": "object",
                "properties": [:],
                "required": []
            ]
        ]
    ]
    
    /// Get git diff for a file
    static let gitDiffTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "git_diff",
            "description": "Get the git diff for a specific file or all changes. Shows what has changed since the last commit.",
            "parameters": [
                "type": "object",
                "properties": [
                    "file": [
                        "type": "string",
                        "description": "Optional file path to diff (omit for all changes)"
                    ],
                    "staged": [
                        "type": "boolean",
                        "description": "Show staged changes only (default false)"
                    ]
                ],
                "required": []
            ]
        ]
    ]
    
    /// Commit changes
    static let gitCommitTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "git_commit",
            "description": "Stage and commit changes to git. Use after making changes that should be saved.",
            "parameters": [
                "type": "object",
                "properties": [
                    "message": [
                        "type": "string",
                        "description": "The commit message"
                    ],
                    "files": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "Optional list of files to stage (omit to stage all)"
                    ]
                ],
                "required": ["message"]
            ]
        ]
    ]
}

// MARK: - Tool Call Response

struct ToolCall: Identifiable {
    let id: String
    let name: String
    let arguments: [String: Any]
    
    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String ?? UUID().uuidString as String?,
              let function = dict["function"] as? [String: Any],
              let name = function["name"] as? String else {
            return nil
        }
        
        self.id = id
        self.name = name
        
        // Parse arguments from JSON string
        if let argsString = function["arguments"] as? String,
           let argsData = argsString.data(using: .utf8),
           let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
            self.arguments = args
        } else if let args = function["arguments"] as? [String: Any] {
            self.arguments = args
        } else {
            self.arguments = [:]
        }
    }
    
    func getString(_ key: String) -> String? {
        arguments[key] as? String
    }
    
    func getInt(_ key: String) -> Int? {
        if let val = arguments[key] as? Int { return val }
        if let str = arguments[key] as? String, let intVal = Int(str) { return intVal }
        return nil
    }
    
    func getBool(_ key: String) -> Bool? {
        if let val = arguments[key] as? Bool { return val }
        if let str = arguments[key] as? String {
            return str.lowercased() == "true"
        }
        return nil
    }
}

// MARK: - Tool Result

struct ToolResult {
    let toolCallId: String
    let success: Bool
    let output: String
    
    var asMessage: [String: Any] {
        [
            "role": "tool",
            "tool_call_id": toolCallId,
            "content": output
        ]
    }
}
