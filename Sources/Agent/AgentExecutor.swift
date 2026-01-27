import Foundation
import SwiftUI

// MARK: - Optimized Agent Executor

@Observable
class AgentExecutor {
    private let ollamaService: OllamaService
    private let fileSystemService: FileSystemService
    
    // Context Management - SINGLE SOURCE from AppState (not duplicated)
    private let contextManager: ContextManager
    
    // MARK: - Consistent Error Handling
    
    /// Record error for learning and return failure result
    private func failWith(_ callId: String, tool: String, error: String, context: String) -> ToolResult {
        contextManager.recordError(error, context: context)
        contextManager.recordToolResult(tool, input: context, output: error, success: false)
        return ToolResult(toolCallId: callId, success: false, output: error)
    }
    
    // State
    var isRunning = false
    var currentTask = ""
    var steps: [AgentStep] = []
    var waitingForUser = false
    var userPrompt = ""
    private var pendingUserResponse: String?
    private var workingDirectory: URL?
    
    // Limits
    var maxSteps = 50
    private var stepCount = 0
    
    // Verification tracking
    private var delegationResults: [String: (success: Bool, output: String)] = [:]
    private var verificationAttempts = 0
    private let maxVerificationAttempts = 3
    
    // Performance
    private let toolResultCache = LRUCache<String, String>(capacity: 100)
    private let executionQueue: DispatchQueue
    
    init(ollamaService: OllamaService, fileSystemService: FileSystemService, contextManager: ContextManager) {
        self.ollamaService = ollamaService
        self.fileSystemService = fileSystemService
        self.contextManager = contextManager // Shared from AppState - single source of truth
        
        // High-priority concurrent queue for tool execution
        self.executionQueue = DispatchQueue(
            label: "com.ollamabot.agent",
            qos: .userInitiated,
            attributes: .concurrent
        )
    }
    
    // MARK: - Public API
    
    func start(task: String, workingDirectory: URL?) {
        guard !isRunning else { return }
        
        self.isRunning = true
        self.currentTask = task
        self.workingDirectory = workingDirectory
        self.steps = []
        self.stepCount = 0
        self.waitingForUser = false
        
        Task(priority: .userInitiated) {
            await runAgentLoop()
        }
    }
    
    func stop() {
        isRunning = false
        addStep(.system("Agent stopped by user"))
    }
    
    func provideUserInput(_ input: String) {
        pendingUserResponse = input
        waitingForUser = false
    }
    
    // MARK: - Agent Loop (with Context Management)
    
    private func runAgentLoop() async {
        addStep(.system("Starting task: \(currentTask)"))
        
        // Build comprehensive context using ContextManager
        let orchestratorContext = contextManager.buildOrchestratorContext(
            task: currentTask,
            workingDirectory: workingDirectory,
            previousSteps: steps
        )
        
        var messages: [[String: Any]] = [
            ["role": "system", "content": orchestratorContext.systemPrompt]
        ]
        
        // Add context as a system message if substantial
        if !orchestratorContext.combinedContext.isEmpty {
            messages.append([
                "role": "system", 
                "content": "CONTEXT:\n\(orchestratorContext.combinedContext)"
            ])
        }
        
        messages.append(["role": "user", "content": currentTask])
        
        while isRunning && stepCount < maxSteps {
            stepCount += 1
            
            do {
                let response = try await measureAsync("ollama_call") {
                    try await ollamaService.chatWithTools(
                        model: .qwen3,
                        messages: messages,
                        tools: AgentTools.all
                    )
                }
                
                if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
                    // Execute multiple tool calls in parallel when possible
                    let results = await executeToolsParallel(toolCalls)
                    
                    for (call, result) in zip(toolCalls, results) {
                        messages.append([
                            "role": "assistant",
                            "tool_calls": [[
                                "id": call.id,
                                "type": "function",
                                "function": ["name": call.name, "arguments": call.arguments]
                            ]]
                        ])
                        messages.append(result.asMessage)
                        
                        if call.name == "complete" {
                            addStep(.complete(result.output))
                            isRunning = false
                            return
                        }
                        
                        if call.name == "ask_user" {
                            await handleUserInput(call: call, messages: &messages)
                        }
                    }
                } else if let content = response.content, !content.isEmpty {
                    addStep(.thinking(content))
                    messages.append(["role": "assistant", "content": content])
                } else {
                    addStep(.error("Model returned empty response"))
                    break
                }
                
                // Minimal delay between iterations
                try? await Task.sleep(for: .milliseconds(50))
                
            } catch {
                addStep(.error("Error: \(error.localizedDescription)"))
                messages.append([
                    "role": "user",
                    "content": "An error occurred: \(error.localizedDescription). Try a different approach or use complete tool."
                ])
            }
        }
        
        if stepCount >= maxSteps {
            addStep(.system("Reached maximum step limit (\(maxSteps))"))
        }
        
        isRunning = false
    }
    
    // MARK: - Parallel Tool Execution (Optimized)
    
    // Pre-computed set of tools safe for parallel execution
    private static let parallelizableTools: Set<String> = ["read_file", "list_directory", "search_files", "think"]
    
    private func executeToolsParallel(_ calls: [ToolCall]) async -> [ToolResult] {
        // Fast path: single call
        guard calls.count > 1 else {
            if let call = calls.first {
                return [await executeTool(call)]
            }
            return []
        }
        
        var results: [ToolResult] = []
        results.reserveCapacity(calls.count)
        
        // Group consecutive parallelizable calls
        var parallelGroup: [ToolCall] = []
        parallelGroup.reserveCapacity(calls.count)
        
        @Sendable func executeParallelGroup(_ group: [ToolCall]) async -> [ToolResult] {
            guard !group.isEmpty else { return [] }
            
            // For small groups, avoid TaskGroup overhead
            if group.count <= 2 {
                var groupResults: [ToolResult] = []
                groupResults.reserveCapacity(group.count)
                for call in group {
                    groupResults.append(await self.executeTool(call))
                }
                return groupResults
            }
            
            // True parallel execution for larger groups
            return await withTaskGroup(of: (Int, ToolResult).self, returning: [ToolResult].self) { taskGroup in
                for (idx, call) in group.enumerated() {
                    taskGroup.addTask { [self] in
                        return (idx, await self.executeTool(call))
                    }
                }
                
                var collected: [(Int, ToolResult)] = []
                collected.reserveCapacity(group.count)
                for await result in taskGroup { collected.append(result) }
                return collected.sorted { $0.0 < $1.0 }.map { $0.1 }
            }
        }
        
        for call in calls {
            if Self.parallelizableTools.contains(call.name) {
                parallelGroup.append(call)
            } else {
                // Execute parallel group first
                if !parallelGroup.isEmpty {
                    let groupResults = await executeParallelGroup(parallelGroup)
                    results.append(contentsOf: groupResults)
                    parallelGroup.removeAll(keepingCapacity: true)
                }
                
                // Execute sequential tool
                results.append(await executeTool(call))
            }
        }
        
        // Handle remaining parallel group
        if !parallelGroup.isEmpty {
            let groupResults = await executeParallelGroup(parallelGroup)
            results.append(contentsOf: groupResults)
        }
        
        return results
    }
    
    // MARK: - Tool Execution (Cached)
    
    private func executeTool(_ call: ToolCall) async -> ToolResult {
        // Check cache for read-only operations
        let cacheKey = "\(call.name):\(call.arguments.description)"
        
        if ["read_file", "list_directory"].contains(call.name),
           let cached = toolResultCache.get(cacheKey) {
            return ToolResult(toolCallId: call.id, success: true, output: cached)
        }
        
        let result: ToolResult
        
        switch call.name {
        case "read_file":
            result = await executeReadFile(call)
        case "write_file":
            result = await executeWriteFile(call)
        case "edit_file":
            result = await executeEditFile(call)
        case "search_files":
            result = await executeSearchFiles(call)
        case "list_directory":
            result = await executeListDirectory(call)
        case "run_command":
            result = await executeRunCommand(call)
        case "ask_user":
            result = executeAskUser(call)
        case "think":
            result = executeThink(call)
        case "complete":
            result = executeComplete(call)
        // Multi-model delegation
        case "delegate_to_coder":
            result = await executeDelegateToCoder(call)
        case "delegate_to_researcher":
            result = await executeDelegateToResearcher(call)
        case "delegate_to_vision":
            result = await executeDelegateToVision(call)
        case "take_screenshot":
            result = await executeTakeScreenshot(call)
        // Web tools
        case "web_search":
            result = await executeWebSearch(call)
        case "fetch_url":
            result = await executeFetchUrl(call)
        // Git tools
        case "git_status":
            result = await executeGitStatus(call)
        case "git_diff":
            result = await executeGitDiff(call)
        case "git_commit":
            result = await executeGitCommit(call)
        default:
            addStep(.error("Unknown tool: \(call.name)"))
            result = ToolResult(toolCallId: call.id, success: false, output: "Unknown tool: \(call.name)")
        }
        
        // Cache successful read-only results
        if result.success && ["read_file", "list_directory"].contains(call.name) {
            toolResultCache.set(cacheKey, result.output, size: max(1, result.output.count / 100))
        }
        
        return result
    }
    
    // MARK: - Tool Implementations
    
    private func executeReadFile(_ call: ToolCall) async -> ToolResult {
        guard let path = call.getString("path") else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing path parameter")
        }
        
        let url = resolveURL(path)
        
        // Use memory-mapped reading for large files
        let reader = MappedFileReader(url: url)
        
        do {
            let content = try reader.read()
            addStep(.tool(name: "read_file", input: path, output: "Read \(content.count) characters"))
            return ToolResult(toolCallId: call.id, success: true, output: content)
        } catch {
            addStep(.tool(name: "read_file", input: path, output: "File not found"))
            return ToolResult(toolCallId: call.id, success: false, output: "File not found: \(path)")
        }
    }
    
    private func executeWriteFile(_ call: ToolCall) async -> ToolResult {
        guard let path = call.getString("path"),
              let content = call.getString("content") else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing path or content parameter")
        }
        
        let url = resolveURL(path)
        
        // Create directory if needed
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            
            // Invalidate cache for this file
            toolResultCache.clear()
            
            addStep(.tool(name: "write_file", input: path, output: "Wrote \(content.count) characters"))
            return ToolResult(toolCallId: call.id, success: true, output: "Successfully wrote to \(path)")
        } catch {
            return failWith(call.id, tool: "write_file", error: "Write failed: \(error.localizedDescription)", context: path)
        }
    }
    
    private func executeEditFile(_ call: ToolCall) async -> ToolResult {
        guard let path = call.getString("path"),
              let oldString = call.getString("old_string"),
              let newString = call.getString("new_string") else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing parameters")
        }
        
        let url = resolveURL(path)
        
        guard var content = try? String(contentsOf: url, encoding: .utf8) else {
            return ToolResult(toolCallId: call.id, success: false, output: "File not found: \(path)")
        }
        
        if content.contains(oldString) {
            content = content.replacingOccurrences(of: oldString, with: newString)
            try? content.write(to: url, atomically: true, encoding: .utf8)
            
            toolResultCache.clear()
            
            addStep(.tool(name: "edit_file", input: path, output: "Replaced text"))
            return ToolResult(toolCallId: call.id, success: true, output: "Successfully edited \(path)")
        } else {
            addStep(.tool(name: "edit_file", input: path, output: "Text not found"))
            return ToolResult(toolCallId: call.id, success: false, output: "Could not find the specified text in \(path)")
        }
    }
    
    private func executeSearchFiles(_ call: ToolCall) async -> ToolResult {
        guard let query = call.getString("query") else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing query parameter")
        }
        
        let searchPath = call.getString("path")
        let url = searchPath != nil ? resolveURL(searchPath!) : workingDirectory ?? URL(fileURLWithPath: NSHomeDirectory())
        
        let results = fileSystemService.searchContent(in: url, matching: query, maxResults: 20)
        
        var output = "Found \(results.count) files:\n"
        for (file, matches) in results {
            output += "\n\(file.url.path):\n"
            for match in matches.prefix(3) {
                output += "  \(match)\n"
            }
        }
        
        addStep(.tool(name: "search_files", input: query, output: "Found \(results.count) files"))
        return ToolResult(toolCallId: call.id, success: true, output: output)
    }
    
    private func executeListDirectory(_ call: ToolCall) async -> ToolResult {
        guard let path = call.getString("path") else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing path parameter")
        }
        
        let url = resolveURL(path)
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
            
            var output = "Contents of \(path):\n"
            for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                output += isDir ? "📁 " : "📄 "
                output += "\(item.lastPathComponent)\n"
            }
            
            addStep(.tool(name: "list_directory", input: path, output: "\(contents.count) items"))
            return ToolResult(toolCallId: call.id, success: true, output: output)
        } catch {
            return failWith(call.id, tool: "list_directory", error: "Error listing directory: \(error.localizedDescription)", context: path)
        }
    }
    
    private func executeRunCommand(_ call: ToolCall) async -> ToolResult {
        guard let command = call.getString("command") else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing command parameter")
        }
        
        let workDir = call.getString("working_directory").map { resolveURL($0) } ?? workingDirectory
        
        addStep(.tool(name: "run_command", input: command, output: "Running..."))
        
        return await withCheckedContinuation { continuation in
            executionQueue.async {
                do {
                    let process = Process()
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    
                    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                    process.arguments = ["-c", command]
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe
                    process.currentDirectoryURL = workDir
                    
                    try process.run()
                    process.waitUntilExit()
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                    
                    let exitCode = process.terminationStatus
                    let fullOutput = output + (errorOutput.isEmpty ? "" : "\nSTDERR:\n\(errorOutput)")
                    
                    DispatchQueue.main.async {
                        self.updateLastToolStep(output: "Exit code: \(exitCode)")
                    }
                    
                    continuation.resume(returning: ToolResult(
                        toolCallId: call.id,
                        success: exitCode == 0,
                        output: "Exit code: \(exitCode)\n\(fullOutput)"
                    ))
                } catch {
                    continuation.resume(returning: ToolResult(
                        toolCallId: call.id,
                        success: false,
                        output: "Failed to run command: \(error.localizedDescription)"
                    ))
                }
            }
        }
    }
    
    private func executeAskUser(_ call: ToolCall) -> ToolResult {
        let question = call.getString("question") ?? "Please provide input"
        addStep(.userInput(question))
        return ToolResult(toolCallId: call.id, success: true, output: "Waiting for user response...")
    }
    
    private func executeThink(_ call: ToolCall) -> ToolResult {
        let thought = call.getString("thought") ?? ""
        addStep(.thinking(thought))
        return ToolResult(toolCallId: call.id, success: true, output: "Thought recorded")
    }
    
    private func executeComplete(_ call: ToolCall) -> ToolResult {
        let summary = call.getString("summary") ?? "Task completed"
        return ToolResult(toolCallId: call.id, success: true, output: summary)
    }
    
    // MARK: - Helpers
    
    private func handleUserInput(call: ToolCall, messages: inout [[String: Any]]) async {
        userPrompt = call.getString("question") ?? "Please provide input:"
        waitingForUser = true
        
        while waitingForUser && isRunning {
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        if let response = pendingUserResponse {
            messages.append(["role": "user", "content": response])
            pendingUserResponse = nil
        }
    }
    
    private func resolveURL(_ path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        } else if let workDir = workingDirectory {
            return workDir.appendingPathComponent(path)
        } else {
            return URL(fileURLWithPath: path)
        }
    }
    
    private func addStep(_ type: AgentStepType) {
        let step = AgentStep(type: type)
        DispatchQueue.main.async {
            self.steps.append(step)
        }
    }
    
    private func updateLastToolStep(output: String) {
        guard let lastIndex = steps.lastIndex(where: {
            if case .tool = $0.type { return true }
            return false
        }) else { return }
        
        if case .tool(let name, let input, _) = steps[lastIndex].type {
            steps[lastIndex] = AgentStep(type: .tool(name: name, input: input, output: output))
        }
    }
    
    // REMOVED: buildSystemMessage() - now unified in ContextManager.buildOrchestratorContext()
    
    // MARK: - Multi-Model Delegation
    
    /// Delegate coding task to Qwen2.5-Coder (with context management)
    private func executeDelegateToCoder(_ call: ToolCall) async -> ToolResult {
        guard let task = call.getString("task") else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing 'task' parameter")
        }
        
        let rawContext = call.getString("context") ?? ""
        let language = call.getString("language") ?? "swift"
        
        addStep(.tool(name: "delegate_to_coder", input: task, output: "Delegating to Qwen2.5-Coder..."))
        
        // Gather relevant files for context
        var relevantFiles: [String: String] = [:]
        if let dir = workingDirectory {
            // Search for files mentioned in task or context
            let searchTerms = extractFileReferences(from: task + " " + rawContext)
            for term in searchTerms.prefix(3) {
                if let url = findFile(named: term, in: dir),
                   let content = try? String(contentsOf: url, encoding: .utf8) {
                    relevantFiles[url.lastPathComponent] = content
                }
            }
        }
        
        // Build optimized context using ContextManager
        let delegationContext = contextManager.buildDelegationContext(
            for: .coder,
            task: task,
            orchestratorContext: "Language: \(language)\n\(rawContext)",
            relevantFiles: relevantFiles
        )
        
        // Construct prompt with specialist system prompt
        let prompt = "\(delegationContext.systemPrompt)\n\n\(delegationContext.content)"
        
        do {
            let response = try await ollamaService.generate(
                prompt: prompt, 
                model: .coder, 
                useCache: false,
                taskType: .coding
            )
            
            // Record tool result for future reference
            contextManager.recordToolResult("delegate_to_coder", input: task, output: response, success: true)
            
            // Store for verification
            delegationResults["coder_\(call.id)"] = (true, response)
            
            DispatchQueue.main.async {
                self.updateLastToolStep(output: "Coder responded (\(response.count) chars)")
            }
            
            return ToolResult(toolCallId: call.id, success: true, output: response)
        } catch {
            return failWith(call.id, tool: "delegate_to_coder", error: "Coder delegation failed: \(error.localizedDescription)", context: task)
        }
    }
    
    /// Extract file references from text (e.g., "main.swift", "utils.py")
    private func extractFileReferences(from text: String) -> [String] {
        let pattern = #"\b[\w-]+\.(swift|py|ts|tsx|js|jsx|rs|go|java|rb|c|cpp|h|json|yaml|yml|md)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return []
        }
        
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        
        return matches.compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }
    
    /// Find a file by name in directory
    private func findFile(named name: String, in directory: URL) -> URL? {
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        
        while let url = enumerator?.nextObject() as? URL {
            if url.lastPathComponent == name {
                return url
            }
        }
        return nil
    }
    
    /// Delegate research task to Command-R (with context management)
    private func executeDelegateToResearcher(_ call: ToolCall) async -> ToolResult {
        guard let query = call.getString("query") else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing 'query' parameter")
        }
        
        let rawContext = call.getString("context") ?? ""
        let format = call.getString("format") ?? "detailed"
        
        addStep(.tool(name: "delegate_to_researcher", input: query, output: "Delegating to Command-R..."))
        
        // Build optimized context
        let delegationContext = contextManager.buildDelegationContext(
            for: .commandR,
            task: query,
            orchestratorContext: "Format: \(format)\n\(rawContext)",
            relevantFiles: [:]
        )
        
        let prompt = "\(delegationContext.systemPrompt)\n\n\(delegationContext.content)"
        
        do {
            let response = try await ollamaService.generate(
                prompt: prompt, 
                model: .commandR, 
                useCache: false,
                taskType: .research
            )
            
            // Record for future reference
            contextManager.recordToolResult("delegate_to_researcher", input: query, output: response, success: true)
            delegationResults["researcher_\(call.id)"] = (true, response)
            
            DispatchQueue.main.async {
                self.updateLastToolStep(output: "Researcher responded (\(response.count) chars)")
            }
            
            return ToolResult(toolCallId: call.id, success: true, output: response)
        } catch {
            return failWith(call.id, tool: "delegate_to_researcher", error: "Research delegation failed: \(error.localizedDescription)", context: query)
        }
    }
    
    /// Delegate vision task to Qwen3-VL
    private func executeDelegateToVision(_ call: ToolCall) async -> ToolResult {
        guard let task = call.getString("task"),
              let imagePath = call.getString("image_path") else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing 'task' or 'image_path' parameter")
        }
        
        let imageURL = resolveURL(imagePath)
        
        guard let imageData = try? Data(contentsOf: imageURL) else {
            return ToolResult(toolCallId: call.id, success: false, output: "Could not read image at: \(imagePath)")
        }
        
        addStep(.tool(name: "delegate_to_vision", input: task, output: "Analyzing image with Qwen3-VL..."))
        
        let messages: [(String, String)] = [
            ("user", "Analyze this image: \(task)")
        ]
        
        do {
            var response = ""
            let stream = ollamaService.chat(
                model: .vision,
                messages: messages,
                context: nil,
                images: [imageData]
            )
            
            for try await chunk in stream {
                response += chunk
            }
            
            DispatchQueue.main.async {
                self.updateLastToolStep(output: "Vision analyzed (\(response.count) chars)")
            }
            
            return ToolResult(toolCallId: call.id, success: true, output: response)
        } catch {
            return ToolResult(toolCallId: call.id, success: false, output: "Vision delegation failed: \(error.localizedDescription)")
        }
    }
    
    /// Take a screenshot for analysis
    private func executeTakeScreenshot(_ call: ToolCall) async -> ToolResult {
        let region = call.getString("region") ?? "full"
        let filename = call.getString("filename") ?? "screenshot_\(Int(Date().timeIntervalSince1970)).png"
        
        addStep(.tool(name: "take_screenshot", input: region, output: "Capturing screenshot..."))
        
        // Determine screenshot path
        let screenshotDir = workingDirectory ?? FileManager.default.temporaryDirectory
        let screenshotPath = screenshotDir.appendingPathComponent(filename)
        
        return await withCheckedContinuation { continuation in
            executionQueue.async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                
                switch region {
                case "window":
                    process.arguments = ["-w", screenshotPath.path]
                case "selection":
                    process.arguments = ["-i", screenshotPath.path]
                default: // "full"
                    process.arguments = ["-x", screenshotPath.path]
                }
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: screenshotPath.path) {
                        DispatchQueue.main.async {
                            self.updateLastToolStep(output: "Screenshot saved: \(filename)")
                        }
                        continuation.resume(returning: ToolResult(
                            toolCallId: call.id,
                            success: true,
                            output: "Screenshot saved to: \(screenshotPath.path)\n\nUse delegate_to_vision with this path to analyze it."
                        ))
                    } else {
                        continuation.resume(returning: ToolResult(
                            toolCallId: call.id,
                            success: false,
                            output: "Screenshot capture failed"
                        ))
                    }
                } catch {
                    continuation.resume(returning: ToolResult(
                        toolCallId: call.id,
                        success: false,
                        output: "Screenshot error: \(error.localizedDescription)"
                    ))
                }
            }
        }
    }
    
    // MARK: - Web Tool Implementations
    
    /// Search the web using DuckDuckGo
    private func executeWebSearch(_ call: ToolCall) async -> ToolResult {
        guard let query = call.getString("query") else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing 'query' parameter")
        }
        
        let maxResults = (call.arguments["max_results"] as? Int) ?? 5
        
        addStep(.tool(name: "web_search", input: query, output: "Searching the web..."))
        
        // URL encode the query
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encoded)") else {
            return ToolResult(toolCallId: call.id, success: false, output: "Invalid search query")
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else {
                return ToolResult(toolCallId: call.id, success: false, output: "Failed to decode search results")
            }
            
            let results = parseSearchResults(html, maxResults: maxResults)
            
            var output = "Search results for '\(query)':\n\n"
            for (index, result) in results.enumerated() {
                output += "\(index + 1). \(result.title)\n"
                output += "   URL: \(result.url)\n"
                output += "   \(result.snippet)\n\n"
            }
            
            DispatchQueue.main.async {
                self.updateLastToolStep(output: "Found \(results.count) results")
            }
            
            return ToolResult(toolCallId: call.id, success: true, output: output)
        } catch {
            return ToolResult(toolCallId: call.id, success: false, output: "Search failed: \(error.localizedDescription)")
        }
    }
    
    private func parseSearchResults(_ html: String, maxResults: Int) -> [(title: String, url: String, snippet: String)] {
        var results: [(String, String, String)] = []
        
        // Simple regex to extract DuckDuckGo results
        let pattern = #"<a[^>]*class="result__a"[^>]*href="([^"]*)"[^>]*>([^<]*)</a>"#
        let snippetPattern = #"<a[^>]*class="result__snippet"[^>]*>([^<]*)</a>"#
        
        guard let linkRegex = try? NSRegularExpression(pattern: pattern),
              let snippetRegex = try? NSRegularExpression(pattern: snippetPattern) else {
            return []
        }
        
        let range = NSRange(html.startIndex..., in: html)
        let linkMatches = linkRegex.matches(in: html, range: range)
        let snippetMatches = snippetRegex.matches(in: html, range: range)
        
        for (index, match) in linkMatches.prefix(maxResults).enumerated() {
            guard let urlRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html) else { continue }
            
            var url = String(html[urlRange])
            let title = String(html[titleRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "&amp;", with: "&")
            
            // DuckDuckGo wraps URLs
            if url.contains("uddg="), let actualUrl = url.components(separatedBy: "uddg=").last?
                .components(separatedBy: "&").first?
                .removingPercentEncoding {
                url = actualUrl
            }
            
            guard url.hasPrefix("http") else { continue }
            
            var snippet = ""
            if index < snippetMatches.count,
               let snippetRange = Range(snippetMatches[index].range(at: 1), in: html) {
                snippet = String(html[snippetRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "<b>", with: "")
                    .replacingOccurrences(of: "</b>", with: "")
            }
            
            results.append((title, url, snippet))
        }
        
        return results
    }
    
    /// Fetch content from a URL
    private func executeFetchUrl(_ call: ToolCall) async -> ToolResult {
        guard let urlString = call.getString("url"),
              let url = URL(string: urlString) else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing or invalid 'url' parameter")
        }
        
        let maxLength = (call.arguments["max_length"] as? Int) ?? 5000
        
        addStep(.tool(name: "fetch_url", input: urlString, output: "Fetching content..."))
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard var html = String(data: data, encoding: .utf8) else {
                return ToolResult(toolCallId: call.id, success: false, output: "Failed to decode page content")
            }
            
            // Extract text content
            html = html.replacingOccurrences(of: #"<script[^>]*>[\s\S]*?</script>"#, with: "", options: .regularExpression)
            html = html.replacingOccurrences(of: #"<style[^>]*>[\s\S]*?</style>"#, with: "", options: .regularExpression)
            html = html.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            html = html.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            html = html.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Truncate if needed
            if html.count > maxLength {
                html = String(html.prefix(maxLength)) + "\n\n[Content truncated...]"
            }
            
            DispatchQueue.main.async {
                self.updateLastToolStep(output: "Fetched \(html.count) chars")
            }
            
            return ToolResult(toolCallId: call.id, success: true, output: "Content from \(urlString):\n\n\(html)")
        } catch {
            return ToolResult(toolCallId: call.id, success: false, output: "Fetch failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Git Tool Implementations
    
    /// Get git status
    private func executeGitStatus(_ call: ToolCall) async -> ToolResult {
        guard let dir = workingDirectory else {
            return ToolResult(toolCallId: call.id, success: false, output: "No working directory set")
        }
        
        addStep(.tool(name: "git_status", input: "", output: "Getting git status..."))
        
        let result = runGitCommand(["status", "--porcelain", "-b"], in: dir)
        
        if result.isEmpty {
            return ToolResult(toolCallId: call.id, success: true, output: "Working directory is clean")
        }
        
        DispatchQueue.main.async {
            self.updateLastToolStep(output: "Status retrieved")
        }
        
        return ToolResult(toolCallId: call.id, success: true, output: "Git status:\n\n\(result)")
    }
    
    /// Get git diff
    private func executeGitDiff(_ call: ToolCall) async -> ToolResult {
        guard let dir = workingDirectory else {
            return ToolResult(toolCallId: call.id, success: false, output: "No working directory set")
        }
        
        let file = call.getString("file")
        let staged = (call.arguments["staged"] as? Bool) ?? false
        
        var args = ["diff"]
        if staged { args.append("--cached") }
        if let f = file { args.append(f) }
        
        addStep(.tool(name: "git_diff", input: file ?? "all", output: "Getting diff..."))
        
        let result = runGitCommand(args, in: dir)
        
        if result.isEmpty {
            return ToolResult(toolCallId: call.id, success: true, output: "No changes to show")
        }
        
        DispatchQueue.main.async {
            self.updateLastToolStep(output: "Diff retrieved")
        }
        
        return ToolResult(toolCallId: call.id, success: true, output: "Git diff:\n\n\(result)")
    }
    
    /// Commit changes
    private func executeGitCommit(_ call: ToolCall) async -> ToolResult {
        guard let dir = workingDirectory else {
            return ToolResult(toolCallId: call.id, success: false, output: "No working directory set")
        }
        
        guard let message = call.getString("message") else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing 'message' parameter")
        }
        
        addStep(.tool(name: "git_commit", input: message, output: "Committing changes..."))
        
        // Stage files
        if let files = call.arguments["files"] as? [String] {
            for file in files {
                _ = runGitCommand(["add", file], in: dir)
            }
        } else {
            _ = runGitCommand(["add", "-A"], in: dir)
        }
        
        // Commit
        let result = runGitCommand(["commit", "-m", message], in: dir)
        
        if result.contains("error") || result.contains("fatal") {
            return ToolResult(toolCallId: call.id, success: false, output: "Commit failed:\n\(result)")
        }
        
        DispatchQueue.main.async {
            self.updateLastToolStep(output: "Committed successfully")
        }
        
        return ToolResult(toolCallId: call.id, success: true, output: "Commit successful:\n\(result)")
    }
    
    /// Helper to run git commands
    private func runGitCommand(_ args: [String], in directory: URL) -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = directory
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Agent Step

struct AgentStep: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let type: AgentStepType
}

enum AgentStepType {
    case system(String)
    case thinking(String)
    case tool(name: String, input: String, output: String)
    case userInput(String)
    case error(String)
    case complete(String)
    
    var icon: String {
        switch self {
        case .system: return "info.circle"
        case .thinking: return "brain"
        case .tool: return "wrench"
        case .userInput: return "person.fill.questionmark"
        case .error: return "exclamationmark.triangle"
        case .complete: return "checkmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .system: return DS.Colors.secondaryText
        case .thinking: return DS.Colors.orchestrator
        case .tool: return DS.Colors.coder
        case .userInput: return DS.Colors.warning
        case .error: return DS.Colors.error
        case .complete: return DS.Colors.success
        }
    }
}
