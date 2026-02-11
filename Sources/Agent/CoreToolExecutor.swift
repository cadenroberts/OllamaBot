import Foundation
import SwiftUI

// MARK: - Core Tool Executor
// Executes the core tools defined in AgentTools.swift

extension AgentExecutor {
    
    // MARK: - Tool Execution (Cached)
    
    func executeTool(_ call: ToolCall) async -> ToolResult {
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
            // Try advanced tools
            if let advancedResult = await executeAdvancedTool(call) {
                result = advancedResult
            } else {
                addStep(.error("Unknown tool: \(call.name)"))
                result = ToolResult(toolCallId: call.id, success: false, output: "Unknown tool: \(call.name)")
            }
        }
        
        // Cache successful read-only results
        if result.success && ["read_file", "list_directory"].contains(call.name) {
            toolResultCache.set(cacheKey, result.output, size: max(1, result.output.count / 100))
        }
        
        return result
    }
    
    // MARK: - Tool Implementations
    
    func executeReadFile(_ call: ToolCall) async -> ToolResult {
        guard let path = call.getString("path") else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing path parameter")
        }
        
        let url = resolveURL(path)
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
    
    func executeWriteFile(_ call: ToolCall) async -> ToolResult {
        guard let path = call.getString("path"),
              let content = call.getString("content") else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing path or content parameter")
        }
        
        let url = resolveURL(path)
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            toolResultCache.clear()
            addStep(.tool(name: "write_file", input: path, output: "Wrote \(content.count) characters"))
            return ToolResult(toolCallId: call.id, success: true, output: "Successfully wrote to \(path)")
        } catch {
            return failWith(call.id, tool: "write_file", error: "Write failed: \(error.localizedDescription)", context: path)
        }
    }
    
    func executeEditFile(_ call: ToolCall) async -> ToolResult {
        guard let path = call.getString("path") else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing path parameter")
        }
        
        let url = resolveURL(path)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return ToolResult(toolCallId: call.id, success: false, output: "File not found: \(path)")
        }
        
        var lines = content.components(separatedBy: .newlines)
        var edited = false
        var outputMessage = ""

        // 1. Targeted line range edit: -start +end syntax (UOP standard)
        // Also supports: -line (single line), start-end (standard range)
        if let rangeString = call.getString("range") ?? call.getString("line_range"),
           let newContent = call.getString("new_content") {
            
            let patterns = [
                #"-(\d+)\s*\+(\d+)"#, // -10 +20 (from line 10 to 20)
                #"(\d+)-(\d+)"#,      // 10-20
                #"-(\d+)"#            // -10 (single line 10)
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: rangeString, range: NSRange(rangeString.startIndex..., in: rangeString)) {
                    
                    var start: Int?
                    var end: Int?
                    
                    if match.numberOfRanges == 3 {
                        // Range: -start +end or start-end
                        if let sRange = Range(match.range(at: 1), in: rangeString),
                           let eRange = Range(match.range(at: 2), in: rangeString) {
                            start = Int(rangeString[sRange])
                            end = Int(rangeString[eRange])
                        }
                    } else if match.numberOfRanges == 2 {
                        // Single line: -line
                        if let sRange = Range(match.range(at: 1), in: rangeString) {
                            start = Int(rangeString[sRange])
                            end = start
                        }
                    }
                    
                    if let s = start, let e = end {
                        let startIndex = max(0, s - 1)
                        let endIndex = min(lines.count, e)
                        
                        if startIndex <= endIndex {
                            let replacementLines = newContent.components(separatedBy: .newlines)
                            lines.replaceSubrange(startIndex..<endIndex, with: replacementLines)
                            edited = true
                            outputMessage = "Successfully applied targeted edit to lines \(s)-\(e) in \(path)"
                            break
                        }
                    }
                }
            }
        }
        
        // 1.1 Direct start_line/end_line integers
        if !edited, let s = call.getInt("start_line"), let e = call.getInt("end_line"),
           let newContent = call.getString("new_content") ?? call.getString("content") {
            let startIndex = max(0, s - 1)
            let endIndex = min(lines.count, e)
            
            if startIndex <= endIndex {
                let replacementLines = newContent.components(separatedBy: .newlines)
                lines.replaceSubrange(startIndex..<endIndex, with: replacementLines)
                edited = true
                outputMessage = "Successfully applied targeted edit to lines \(s)-\(e) in \(path)"
            }
        }
        
        // 2. Original string-based edit (fallback)
        if !edited, let oldString = call.getString("old_string"),
           let newString = call.getString("new_string") {
            
            if content.contains(oldString) {
                let newContent = content.replacingOccurrences(of: oldString, with: newString)
                lines = newContent.components(separatedBy: .newlines)
                edited = true
                outputMessage = "Successfully replaced text in \(path)"
            } else {
                return ToolResult(toolCallId: call.id, success: false, output: "Could not find the specified text in \(path)")
            }
        }
        
        if edited {
            let finalContent = lines.joined(separator: "\n")
            do {
                try finalContent.write(to: url, atomically: true, encoding: .utf8)
                toolResultCache.clear()
                addStep(.tool(name: "edit_file", input: path, output: outputMessage))
                return ToolResult(toolCallId: call.id, success: true, output: outputMessage)
            } catch {
                return failWith(call.id, tool: "edit_file", error: "Failed to write file: \(error.localizedDescription)", context: path)
            }
        }
        
        return ToolResult(toolCallId: call.id, success: false, output: "No valid edit parameters provided for \(path)")
    }
    
    func executeSearchFiles(_ call: ToolCall) async -> ToolResult {
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
    
    func executeListDirectory(_ call: ToolCall) async -> ToolResult {
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
    
    func executeRunCommand(_ call: ToolCall) async -> ToolResult {
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
                    continuation.resume(returning: ToolResult(toolCallId: call.id, success: exitCode == 0, output: "Exit code: \(exitCode)\n\(fullOutput)"))
                } catch {
                    continuation.resume(returning: ToolResult(toolCallId: call.id, success: false, output: "Failed to run command: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    func executeAskUser(_ call: ToolCall) -> ToolResult {
        let question = call.getString("question") ?? "Please provide input"
        addStep(.userInput(question))
        return ToolResult(toolCallId: call.id, success: true, output: "Waiting for user response...")
    }
    
    func executeThink(_ call: ToolCall) -> ToolResult {
        let thought = call.getString("thought") ?? ""
        addStep(.thinking(thought))
        return ToolResult(toolCallId: call.id, success: true, output: "Thought recorded")
    }
    
    func executeComplete(_ call: ToolCall) -> ToolResult {
        let summary = call.getString("summary") ?? "Task completed"
        return ToolResult(toolCallId: call.id, success: true, output: summary)
    }
    
    // MARK: - Multi-Model Delegation
    
    func executeDelegateToCoder(_ call: ToolCall) async -> ToolResult {
        guard let task = call.getString("task") else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing 'task' parameter")
        }
        
        let rawContext = call.getString("context") ?? ""
        let language = call.getString("language") ?? "swift"
        addStep(.tool(name: "delegate_to_coder", input: task, output: "Delegating to Qwen2.5-Coder..."))
        
        var relevantFiles: [String: String] = [:]
        if let dir = workingDirectory {
            let searchTerms = extractFileReferences(from: task + " " + rawContext)
            for term in searchTerms.prefix(3) {
                if let url = findFile(named: term, in: dir),
                   let content = try? String(contentsOf: url, encoding: .utf8) {
                    relevantFiles[url.lastPathComponent] = content
                }
            }
        }
        
        let delegationContext = contextManager.buildDelegationContext(for: .coder, task: task, orchestratorContext: "Language: \(language)\n\(rawContext)", relevantFiles: relevantFiles)
        let prompt = "\(delegationContext.systemPrompt)\n\n\(delegationContext.content)"
        
        do {
            let response = try await ollamaService.generate(prompt: prompt, model: .coder, useCache: false, taskType: .coding)
            contextManager.recordToolResult("delegate_to_coder", input: task, output: response, success: true)
            delegationResults["coder_\(call.id)"] = (true, response)
            DispatchQueue.main.async { self.updateLastToolStep(output: "Coder responded (\(response.count) chars)") }
            return ToolResult(toolCallId: call.id, success: true, output: response)
        } catch {
            return failWith(call.id, tool: "delegate_to_coder", error: "Coder delegation failed: \(error.localizedDescription)", context: task)
        }
    }
    
    func executeDelegateToResearcher(_ call: ToolCall) async -> ToolResult {
        guard let query = call.getString("query") else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing 'query' parameter")
        }
        
        let rawContext = call.getString("context") ?? ""
        let format = call.getString("format") ?? "detailed"
        addStep(.tool(name: "delegate_to_researcher", input: query, output: "Delegating to Command-R..."))
        
        let delegationContext = contextManager.buildDelegationContext(for: .commandR, task: query, orchestratorContext: "Format: \(format)\n\(rawContext)", relevantFiles: [:])
        let prompt = "\(delegationContext.systemPrompt)\n\n\(delegationContext.content)"
        
        do {
            let response = try await ollamaService.generate(prompt: prompt, model: .commandR, useCache: false, taskType: .research)
            contextManager.recordToolResult("delegate_to_researcher", input: query, output: response, success: true)
            delegationResults["researcher_\(call.id)"] = (true, response)
            DispatchQueue.main.async { self.updateLastToolStep(output: "Researcher responded (\(response.count) chars)") }
            return ToolResult(toolCallId: call.id, success: true, output: response)
        } catch {
            return failWith(call.id, tool: "delegate_to_researcher", error: "Research delegation failed: \(error.localizedDescription)", context: query)
        }
    }
    
    func executeDelegateToVision(_ call: ToolCall) async -> ToolResult {
        guard let task = call.getString("task"), let imagePath = call.getString("image_path") else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing 'task' or 'image_path' parameter")
        }
        
        let imageURL = resolveURL(imagePath)
        guard let imageData = try? Data(contentsOf: imageURL) else {
            return ToolResult(toolCallId: call.id, success: false, output: "Could not read image at: \(imagePath)")
        }
        
        addStep(.tool(name: "delegate_to_vision", input: task, output: "Analyzing image with Qwen3-VL..."))
        let messages: [(String, String)] = [("user", "Analyze this image: \(task)")]
        
        do {
            var response = ""
            let stream = ollamaService.chat(model: .vision, messages: messages, context: nil, images: [imageData])
            for try await chunk in stream { response += chunk }
            DispatchQueue.main.async { self.updateLastToolStep(output: "Vision analyzed (\(response.count) chars)") }
            return ToolResult(toolCallId: call.id, success: true, output: response)
        } catch {
            return ToolResult(toolCallId: call.id, success: false, output: "Vision delegation failed: \(error.localizedDescription)")
        }
    }
    
    func executeTakeScreenshot(_ call: ToolCall) async -> ToolResult {
        let region = call.getString("region") ?? "full"
        let filename = call.getString("filename") ?? "screenshot_\(Int(Date().timeIntervalSince1970)).png"
        addStep(.tool(name: "take_screenshot", input: region, output: "Capturing screenshot..."))
        
        let screenshotDir = workingDirectory ?? FileManager.default.temporaryDirectory
        let screenshotPath = screenshotDir.appendingPathComponent(filename)
        
        return await withCheckedContinuation { continuation in
            executionQueue.async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                switch region {
                case "window": process.arguments = ["-w", screenshotPath.path]
                case "selection": process.arguments = ["-i", screenshotPath.path]
                default: process.arguments = ["-x", screenshotPath.path]
                }
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: screenshotPath.path) {
                        DispatchQueue.main.async { self.updateLastToolStep(output: "Screenshot saved: \(filename)") }
                        continuation.resume(returning: ToolResult(toolCallId: call.id, success: true, output: "Screenshot saved to: \(screenshotPath.path)\n\nUse delegate_to_vision with this path to analyze it."))
                    } else {
                        continuation.resume(returning: ToolResult(toolCallId: call.id, success: false, output: "Screenshot capture failed"))
                    }
                } catch {
                    continuation.resume(returning: ToolResult(toolCallId: call.id, success: false, output: "Screenshot error: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    // MARK: - Web tools
    
    func executeWebSearch(_ call: ToolCall) async -> ToolResult {
        guard let query = call.getString("query") else { return ToolResult(toolCallId: call.id, success: false, output: "Missing query") }
        let maxResults = (call.arguments["max_results"] as? Int) ?? 5
        addStep(.tool(name: "web_search", input: query, output: "Searching the web..."))
        
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encoded)") else {
            return ToolResult(toolCallId: call.id, success: false, output: "Invalid search query")
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return ToolResult(toolCallId: call.id, success: false, output: "Decode failed") }
            let results = parseSearchResults(html, maxResults: maxResults)
            var output = "Search results:\n\n"
            for (index, result) in results.enumerated() {
                output += "\(index + 1). \(result.title)\n   URL: \(result.url)\n   \(result.snippet)\n\n"
            }
            DispatchQueue.main.async { self.updateLastToolStep(output: "Found \(results.count) results") }
            return ToolResult(toolCallId: call.id, success: true, output: output)
        } catch { return ToolResult(toolCallId: call.id, success: false, output: "Search failed: \(error.localizedDescription)") }
    }
    
    func executeFetchUrl(_ call: ToolCall) async -> ToolResult {
        guard let urlString = call.getString("url"), let url = URL(string: urlString) else { return ToolResult(toolCallId: call.id, success: false, output: "Missing or invalid url") }
        let maxLength = (call.arguments["max_length"] as? Int) ?? 5000
        addStep(.tool(name: "fetch_url", input: urlString, output: "Fetching content..."))
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard var html = String(data: data, encoding: .utf8) else { return ToolResult(toolCallId: call.id, success: false, output: "Decode failed") }
            html = html.replacingOccurrences(of: #"<script[^>]*>[\s\S]*?</script>"#, with: "", options: .regularExpression)
            html = html.replacingOccurrences(of: #"<style[^>]*>[\s\S]*?</style>"#, with: "", options: .regularExpression)
            html = html.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            html = html.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
            if html.count > maxLength { html = String(html.prefix(maxLength)) + "\n\n[Truncated...]" }
            DispatchQueue.main.async { self.updateLastToolStep(output: "Fetched \(html.count) chars") }
            return ToolResult(toolCallId: call.id, success: true, output: "Content:\n\n\(html)")
        } catch { return ToolResult(toolCallId: call.id, success: false, output: "Fetch failed: \(error.localizedDescription)") }
    }
    
    // MARK: - Git tools
    
    func executeGitStatus(_ call: ToolCall) async -> ToolResult {
        guard let dir = workingDirectory else { return ToolResult(toolCallId: call.id, success: false, output: "No workdir") }
        addStep(.tool(name: "git_status", input: "", output: "Getting status..."))
        let result = runGitCommand(["status", "--porcelain", "-b"], in: dir)
        DispatchQueue.main.async { self.updateLastToolStep(output: "Status retrieved") }
        return ToolResult(toolCallId: call.id, success: true, output: "Git status:\n\n\(result)")
    }
    
    func executeGitDiff(_ call: ToolCall) async -> ToolResult {
        guard let dir = workingDirectory else { return ToolResult(toolCallId: call.id, success: false, output: "No workdir") }
        let file = call.getString("file")
        let staged = (call.arguments["staged"] as? Bool) ?? false
        var args = ["diff"]
        if staged { args.append("--cached") }
        if let f = file { args.append(f) }
        addStep(.tool(name: "git_diff", input: file ?? "all", output: "Getting diff..."))
        let result = runGitCommand(args, in: dir)
        DispatchQueue.main.async { self.updateLastToolStep(output: "Diff retrieved") }
        return ToolResult(toolCallId: call.id, success: true, output: "Git diff:\n\n\(result)")
    }
    
    func executeGitCommit(_ call: ToolCall) async -> ToolResult {
        guard let dir = workingDirectory else { return ToolResult(toolCallId: call.id, success: false, output: "No workdir") }
        guard let message = call.getString("message") else { return ToolResult(toolCallId: call.id, success: false, output: "Missing message") }
        addStep(.tool(name: "git_commit", input: message, output: "Committing..."))
        if let files = call.arguments["files"] as? [String] { for file in files { _ = runGitCommand(["add", file], in: dir) } }
        else { _ = runGitCommand(["add", "-A"], in: dir) }
        let result = runGitCommand(["commit", "-m", message], in: dir)
        if result.contains("error") || result.contains("fatal") { return ToolResult(toolCallId: call.id, success: false, output: "Failed:\n\(result)") }
        DispatchQueue.main.async { self.updateLastToolStep(output: "Committed") }
        return ToolResult(toolCallId: call.id, success: true, output: "Success:\n\(result)")
    }
    
    // MARK: - Internal Helpers
    
    func extractFileReferences(from text: String) -> [String] {
        let pattern = #"\b[\w-]+\.(swift|py|ts|tsx|js|jsx|rs|go|java|rb|c|cpp|h|json|yaml|yml|md)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        return matches.compactMap { match in Range(match.range, in: text).map { String(text[$0]) } }
    }
    
    func findFile(named name: String, in directory: URL) -> URL? {
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])
        while let url = enumerator?.nextObject() as? URL { if url.lastPathComponent == name { return url } }
        return nil
    }
    
    func runGitCommand(_ args: [String], in directory: URL) -> String {
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
        } catch { return "Error: \(error.localizedDescription)" }
    }
    
    func parseSearchResults(_ html: String, maxResults: Int) -> [(title: String, url: String, snippet: String)] {
        var results: [(String, String, String)] = []
        let pattern = #"<a[^>]*class="result__a"[^>]*href="([^"]*)"[^>]*>([^<]*)</a>"#
        let snippetPattern = #"<a[^>]*class="result__snippet"[^>]*>([^<]*)</a>"#
        guard let linkRegex = try? NSRegularExpression(pattern: pattern),
              let snippetRegex = try? NSRegularExpression(pattern: snippetPattern) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        let linkMatches = linkRegex.matches(in: html, range: range)
        let snippetMatches = snippetRegex.matches(in: html, range: range)
        for (index, match) in linkMatches.prefix(maxResults).enumerated() {
            guard let urlRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html) else { continue }
            var url = String(html[urlRange])
            let title = String(html[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "&amp;", with: "&")
            if url.contains("uddg="), let actualUrl = url.components(separatedBy: "uddg=").last?.components(separatedBy: "&").first?.removingPercentEncoding { url = actualUrl }
            guard url.hasPrefix("http") else { continue }
            var snippet = ""
            if index < snippetMatches.count, let snippetRange = Range(snippetMatches[index].range(at: 1), in: html) {
                snippet = String(html[snippetRange]).trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "<b>", with: "").replacingOccurrences(of: "</b>", with: "")
            }
            results.append((title, url, snippet))
        }
        return results
    }
}
