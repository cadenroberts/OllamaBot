import Foundation

// MARK: - Advanced Tool Executor
// Executes the advanced tools defined in AdvancedTools.swift

extension AgentExecutor {
    
    // MARK: - Tool Router
    
    func executeAdvancedTool(_ call: ToolCall) async -> ToolResult? {
        switch call.name {
        case "glob_search":
            return await executeGlobSearch(call)
        case "grep":
            return await executeGrep(call)
        case "batch_read":
            return await executeBatchRead(call)
        case "codebase_search":
            return await executeCodebaseSearch(call)
        case "find_definition":
            return await executeFindDefinition(call)
        case "find_references":
            return await executeFindReferences(call)
        case "lint":
            return await executeLint(call)
        case "run_tests":
            return await executeRunTests(call)
        case "build":
            return await executeBuild(call)
        case "todo":
            return executeTodo(call)
        case "memory":
            return executeMemory(call)
        case "mkdir":
            return executeMkdir(call)
        case "move":
            return executeMove(call)
        case "delete":
            return executeDelete(call)
        case "search_replace":
            return await executeSearchReplace(call)
        case "multi_edit":
            return executeMultiEdit(call)
        default:
            return nil // Not an advanced tool
        }
    }
    
    // MARK: - Glob Search
    
    private func executeGlobSearch(_ call: ToolCall) async -> ToolResult {
        guard let pattern = call.arguments["pattern"] as? String else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing pattern")
        }
        
        let basePath = (call.arguments["path"] as? String) ?? "."
        let searchDir = resolveWorkingPath(basePath)
        
        var matches: [String] = []
        let enumerator = FileManager.default.enumerator(
            at: searchDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        while let url = enumerator?.nextObject() as? URL {
            let relativePath = url.path.replacingOccurrences(of: searchDir.path + "/", with: "")
            if matchesGlob(relativePath, pattern: pattern) {
                matches.append(relativePath)
            }
        }
        
        let output = matches.isEmpty ? "No files found matching '\(pattern)'" : matches.joined(separator: "\n")
        return ToolResult(toolCallId: call.id, success: true, output: output)
    }
    
    private func matchesGlob(_ path: String, pattern: String) -> Bool {
        // Convert glob to regex
        var regex = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "**/", with: "(.*/)?")
            .replacingOccurrences(of: "*", with: "[^/]*")
            .replacingOccurrences(of: "?", with: ".")
        
        regex = "^" + regex + "$"
        
        return path.range(of: regex, options: .regularExpression) != nil
    }
    
    // MARK: - Grep
    
    private func executeGrep(_ call: ToolCall) async -> ToolResult {
        guard let pattern = call.arguments["pattern"] as? String else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing pattern")
        }
        
        let searchPath = (call.arguments["path"] as? String) ?? "."
        let includePattern = call.arguments["include"] as? String
        let contextLines = (call.arguments["context_lines"] as? Int) ?? 2
        let caseInsensitive = (call.arguments["case_insensitive"] as? Bool) ?? false
        
        let searchDir = resolveWorkingPath(searchPath)
        var results: [String] = []
        
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return ToolResult(toolCallId: call.id, success: false, output: "Invalid regex pattern")
        }
        
        let enumerator = FileManager.default.enumerator(
            at: searchDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        while let url = enumerator?.nextObject() as? URL {
            // Skip if include pattern specified and doesn't match
            if let include = includePattern {
                if !matchesGlob(url.lastPathComponent, pattern: include) {
                    continue
                }
            }
            
            // Skip binary files
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            
            let lines = content.components(separatedBy: .newlines)
            var fileMatches: [(line: Int, context: String)] = []
            
            for (i, line) in lines.enumerated() {
                let range = NSRange(line.startIndex..., in: line)
                if regex.firstMatch(in: line, range: range) != nil {
                    // Get context
                    let start = max(0, i - contextLines)
                    let end = min(lines.count - 1, i + contextLines)
                    var context = ""
                    for j in start...end {
                        let marker = j == i ? ">" : " "
                        context += "\(marker) \(j + 1): \(lines[j])\n"
                    }
                    fileMatches.append((i + 1, context))
                }
            }
            
            if !fileMatches.isEmpty {
                let relativePath = url.path.replacingOccurrences(of: searchDir.path + "/", with: "")
                results.append("=== \(relativePath) ===")
                for match in fileMatches {
                    results.append(match.context)
                }
            }
        }
        
        let output = results.isEmpty ? "No matches found for '\(pattern)'" : results.joined(separator: "\n")
        return ToolResult(toolCallId: call.id, success: true, output: output)
    }
    
    // MARK: - Batch Read
    
    private func executeBatchRead(_ call: ToolCall) async -> ToolResult {
        guard let paths = call.arguments["paths"] as? [String] else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing paths array")
        }
        
        let maxLines = call.arguments["max_lines_per_file"] as? Int
        var results: [String] = []
        
        for path in paths {
            let fileURL = resolveWorkingPath(path)
            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                var fileContent = content
                if let max = maxLines {
                    let lines = content.components(separatedBy: .newlines)
                    if lines.count > max {
                        fileContent = lines.prefix(max).joined(separator: "\n") + "\n... (\(lines.count - max) more lines)"
                    }
                }
                results.append("=== \(path) ===\n\(fileContent)")
            } else {
                results.append("=== \(path) === [ERROR: Could not read file]")
            }
        }
        
        return ToolResult(toolCallId: call.id, success: true, output: results.joined(separator: "\n\n"))
    }
    
    // MARK: - Codebase Search
    
    private func executeCodebaseSearch(_ call: ToolCall) async -> ToolResult {
        guard let query = call.arguments["query"] as? String else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing query")
        }
        
        // This would integrate with a semantic search system
        // For now, do keyword-based search
        let keywords = query.lowercased().components(separatedBy: .whitespaces)
        var results: [(path: String, score: Int, preview: String)] = []
        
        guard let workDir = workingDirectory else {
            return ToolResult(toolCallId: call.id, success: false, output: "No working directory")
        }
        
        let enumerator = FileManager.default.enumerator(
            at: workDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        while let url = enumerator?.nextObject() as? URL {
            guard isCodeFile(url),
                  let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            
            let lowercased = content.lowercased()
            var score = 0
            for keyword in keywords {
                if lowercased.contains(keyword) {
                    score += 1
                }
            }
            
            if score > 0 {
                let relativePath = url.path.replacingOccurrences(of: workDir.path + "/", with: "")
                let preview = String(content.prefix(200)).replacingOccurrences(of: "\n", with: " ")
                results.append((relativePath, score, preview))
            }
        }
        
        results.sort { $0.score > $1.score }
        
        if results.isEmpty {
            return ToolResult(toolCallId: call.id, success: true, output: "No relevant files found for '\(query)'")
        }
        
        var output = "Found \(results.count) relevant files:\n\n"
        for (path, score, preview) in results.prefix(10) {
            output += "[\(score)] \(path)\n  \(preview)...\n\n"
        }
        
        return ToolResult(toolCallId: call.id, success: true, output: output)
    }
    
    // MARK: - Find Definition
    
    private func executeFindDefinition(_ call: ToolCall) async -> ToolResult {
        guard let symbol = call.arguments["symbol"] as? String else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing symbol")
        }
        
        guard let workDir = workingDirectory else {
            return ToolResult(toolCallId: call.id, success: false, output: "No working directory")
        }
        
        var definitions: [String] = []
        
        let enumerator = FileManager.default.enumerator(
            at: workDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        // Patterns for different languages
        let patterns = [
            "func \(symbol)\\s*\\(",           // Swift function
            "class \(symbol)[\\s:{]",           // Class
            "struct \(symbol)[\\s:{]",          // Struct
            "enum \(symbol)[\\s:{]",            // Enum
            "protocol \(symbol)[\\s:{]",        // Protocol
            "def \(symbol)\\s*\\(",             // Python
            "function \(symbol)\\s*\\(",        // JS/TS function
            "const \(symbol)\\s*=",             // JS/TS const
            "let \(symbol)\\s*=",               // JS/TS let
            "var \(symbol)\\s*[=:]"             // Variable
        ]
        
        let combinedPattern = patterns.joined(separator: "|")
        guard let regex = try? NSRegularExpression(pattern: combinedPattern, options: []) else {
            return ToolResult(toolCallId: call.id, success: false, output: "Invalid symbol")
        }
        
        while let url = enumerator?.nextObject() as? URL {
            guard isCodeFile(url),
                  let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            
            let lines = content.components(separatedBy: .newlines)
            for (i, line) in lines.enumerated() {
                let range = NSRange(line.startIndex..., in: line)
                if regex.firstMatch(in: line, range: range) != nil {
                    let relativePath = url.path.replacingOccurrences(of: workDir.path + "/", with: "")
                    definitions.append("\(relativePath):\(i + 1): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        
        if definitions.isEmpty {
            return ToolResult(toolCallId: call.id, success: true, output: "No definition found for '\(symbol)'")
        }
        
        return ToolResult(toolCallId: call.id, success: true, output: "Definitions of '\(symbol)':\n" + definitions.joined(separator: "\n"))
    }
    
    // MARK: - Find References
    
    private func executeFindReferences(_ call: ToolCall) async -> ToolResult {
        guard let symbol = call.arguments["symbol"] as? String else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing symbol")
        }
        
        guard let workDir = workingDirectory else {
            return ToolResult(toolCallId: call.id, success: false, output: "No working directory")
        }
        
        var references: [String] = []
        
        let enumerator = FileManager.default.enumerator(
            at: workDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        while let url = enumerator?.nextObject() as? URL {
            guard isCodeFile(url),
                  let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            
            let lines = content.components(separatedBy: .newlines)
            for (i, line) in lines.enumerated() {
                // Word boundary match
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: symbol))\\b"
                if line.range(of: pattern, options: .regularExpression) != nil {
                    let relativePath = url.path.replacingOccurrences(of: workDir.path + "/", with: "")
                    references.append("\(relativePath):\(i + 1): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        
        if references.isEmpty {
            return ToolResult(toolCallId: call.id, success: true, output: "No references found for '\(symbol)'")
        }
        
        return ToolResult(toolCallId: call.id, success: true, output: "References to '\(symbol)' (\(references.count) found):\n" + references.prefix(50).joined(separator: "\n"))
    }
    
    // MARK: - Lint
    
    private func executeLint(_ call: ToolCall) async -> ToolResult {
        guard let workDir = workingDirectory else {
            return ToolResult(toolCallId: call.id, success: false, output: "No working directory")
        }
        
        // Detect project type and run appropriate linter
        var lintCommand = ""
        
        if FileManager.default.fileExists(atPath: workDir.appendingPathComponent("Package.swift").path) {
            // Swift project
            lintCommand = "swift build 2>&1 | grep -E '(error:|warning:)' | head -50"
        } else if FileManager.default.fileExists(atPath: workDir.appendingPathComponent("package.json").path) {
            // Node.js project
            lintCommand = "npm run lint 2>&1 || npx eslint . 2>&1 | head -50"
        } else if FileManager.default.fileExists(atPath: workDir.appendingPathComponent("requirements.txt").path) {
            // Python project
            lintCommand = "python -m flake8 . 2>&1 | head -50 || python -m pylint . 2>&1 | head -50"
        } else {
            return ToolResult(toolCallId: call.id, success: true, output: "No recognized project type for linting")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", lintCommand]
        process.currentDirectoryURL = workDir
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return ToolResult(toolCallId: call.id, success: true, output: output.isEmpty ? "No lint errors found" : output)
        } catch {
            return ToolResult(toolCallId: call.id, success: false, output: "Lint failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Run Tests
    
    private func executeRunTests(_ call: ToolCall) async -> ToolResult {
        guard let workDir = workingDirectory else {
            return ToolResult(toolCallId: call.id, success: false, output: "No working directory")
        }
        
        let pattern = call.arguments["pattern"] as? String
        var testCommand = ""
        
        if FileManager.default.fileExists(atPath: workDir.appendingPathComponent("Package.swift").path) {
            testCommand = pattern != nil ? "swift test --filter '\(pattern!)'" : "swift test"
        } else if FileManager.default.fileExists(atPath: workDir.appendingPathComponent("package.json").path) {
            testCommand = pattern != nil ? "npm test -- --grep '\(pattern!)'" : "npm test"
        } else if FileManager.default.fileExists(atPath: workDir.appendingPathComponent("pytest.ini").path) ||
                  FileManager.default.fileExists(atPath: workDir.appendingPathComponent("setup.py").path) {
            testCommand = pattern != nil ? "pytest -k '\(pattern!)'" : "pytest"
        } else {
            return ToolResult(toolCallId: call.id, success: true, output: "No recognized test framework")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", testCommand]
        process.currentDirectoryURL = workDir
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let success = process.terminationStatus == 0
            
            return ToolResult(toolCallId: call.id, success: success, output: output)
        } catch {
            return ToolResult(toolCallId: call.id, success: false, output: "Tests failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Build
    
    private func executeBuild(_ call: ToolCall) async -> ToolResult {
        guard let workDir = workingDirectory else {
            return ToolResult(toolCallId: call.id, success: false, output: "No working directory")
        }
        
        let config = (call.arguments["configuration"] as? String) ?? "debug"
        var buildCommand = ""
        
        if FileManager.default.fileExists(atPath: workDir.appendingPathComponent("Package.swift").path) {
            buildCommand = config == "release" ? "swift build -c release" : "swift build"
        } else if FileManager.default.fileExists(atPath: workDir.appendingPathComponent("package.json").path) {
            buildCommand = "npm run build"
        } else if FileManager.default.fileExists(atPath: workDir.appendingPathComponent("Makefile").path) {
            buildCommand = "make"
        } else if FileManager.default.fileExists(atPath: workDir.appendingPathComponent("Cargo.toml").path) {
            buildCommand = config == "release" ? "cargo build --release" : "cargo build"
        } else {
            return ToolResult(toolCallId: call.id, success: true, output: "No recognized build system")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", buildCommand]
        process.currentDirectoryURL = workDir
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let success = process.terminationStatus == 0
            
            return ToolResult(toolCallId: call.id, success: success, output: success ? "Build succeeded\n\(output)" : "Build failed\n\(output)")
        } catch {
            return ToolResult(toolCallId: call.id, success: false, output: "Build failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Todo
    
    private func executeTodo(_ call: ToolCall) -> ToolResult {
        guard let action = call.arguments["action"] as? String else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing action")
        }
        
        let tracker = AgentTaskTracker()
        
        switch action {
        case "list":
            let tasks = tracker.tasks.map { "[\($0.status.rawValue)] \($0.id.prefix(8)): \($0.content)" }
            return ToolResult(toolCallId: call.id, success: true, output: tasks.isEmpty ? "No tasks" : tasks.joined(separator: "\n"))
            
        case "add":
            guard let task = call.arguments["task"] as? String else {
                return ToolResult(toolCallId: call.id, success: false, output: "Missing task")
            }
            let newTask = tracker.addTask(task)
            return ToolResult(toolCallId: call.id, success: true, output: "Added task: \(newTask.id.prefix(8))")
            
        case "update", "complete":
            guard let id = call.arguments["id"] as? String else {
                return ToolResult(toolCallId: call.id, success: false, output: "Missing task id")
            }
            let status: AgentTaskTracker.Task.Status = action == "complete" ? .completed : 
                AgentTaskTracker.Task.Status(rawValue: call.arguments["status"] as? String ?? "in_progress") ?? .inProgress
            tracker.updateTask(id, status: status)
            return ToolResult(toolCallId: call.id, success: true, output: "Updated task \(id.prefix(8)) to \(status.rawValue)")
            
        case "remove":
            guard let id = call.arguments["id"] as? String else {
                return ToolResult(toolCallId: call.id, success: false, output: "Missing task id")
            }
            tracker.removeTask(id)
            return ToolResult(toolCallId: call.id, success: true, output: "Removed task \(id.prefix(8))")
            
        default:
            return ToolResult(toolCallId: call.id, success: false, output: "Unknown action: \(action)")
        }
    }
    
    // MARK: - Memory
    
    private func executeMemory(_ call: ToolCall) -> ToolResult {
        guard let action = call.arguments["action"] as? String else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing action")
        }
        
        let store = AgentMemoryStore()
        
        switch action {
        case "store":
            guard let key = call.arguments["key"] as? String,
                  let value = call.arguments["value"] as? String else {
                return ToolResult(toolCallId: call.id, success: false, output: "Missing key or value")
            }
            store.store(key: key, value: value)
            return ToolResult(toolCallId: call.id, success: true, output: "Stored '\(key)'")
            
        case "retrieve":
            guard let key = call.arguments["key"] as? String else {
                return ToolResult(toolCallId: call.id, success: false, output: "Missing key")
            }
            if let value = store.retrieve(key: key) {
                return ToolResult(toolCallId: call.id, success: true, output: value)
            } else {
                return ToolResult(toolCallId: call.id, success: false, output: "Key '\(key)' not found")
            }
            
        case "list":
            let keys = store.list()
            return ToolResult(toolCallId: call.id, success: true, output: keys.isEmpty ? "No stored memories" : keys.joined(separator: "\n"))
            
        case "delete":
            guard let key = call.arguments["key"] as? String else {
                return ToolResult(toolCallId: call.id, success: false, output: "Missing key")
            }
            store.delete(key: key)
            return ToolResult(toolCallId: call.id, success: true, output: "Deleted '\(key)'")
            
        default:
            return ToolResult(toolCallId: call.id, success: false, output: "Unknown action: \(action)")
        }
    }
    
    // MARK: - Mkdir
    
    private func executeMkdir(_ call: ToolCall) -> ToolResult {
        guard let path = call.arguments["path"] as? String else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing path")
        }
        
        let dirURL = resolveWorkingPath(path)
        
        do {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            return ToolResult(toolCallId: call.id, success: true, output: "Created directory: \(path)")
        } catch {
            return ToolResult(toolCallId: call.id, success: false, output: "Failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Move
    
    private func executeMove(_ call: ToolCall) -> ToolResult {
        guard let source = call.arguments["source"] as? String,
              let destination = call.arguments["destination"] as? String else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing source or destination")
        }
        
        let sourceURL = resolveWorkingPath(source)
        let destURL = resolveWorkingPath(destination)
        
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destURL)
            return ToolResult(toolCallId: call.id, success: true, output: "Moved \(source) to \(destination)")
        } catch {
            return ToolResult(toolCallId: call.id, success: false, output: "Failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Delete
    
    private func executeDelete(_ call: ToolCall) -> ToolResult {
        guard let path = call.arguments["path"] as? String else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing path")
        }
        
        let fileURL = resolveWorkingPath(path)
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            return ToolResult(toolCallId: call.id, success: true, output: "Deleted: \(path)")
        } catch {
            return ToolResult(toolCallId: call.id, success: false, output: "Failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Search Replace
    
    private func executeSearchReplace(_ call: ToolCall) async -> ToolResult {
        guard let search = call.arguments["search"] as? String,
              let replace = call.arguments["replace"] as? String else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing search or replace")
        }
        
        let isRegex = (call.arguments["is_regex"] as? Bool) ?? false
        let dryRun = (call.arguments["dry_run"] as? Bool) ?? false
        let paths = call.arguments["paths"] as? [String]
        
        guard let workDir = workingDirectory else {
            return ToolResult(toolCallId: call.id, success: false, output: "No working directory")
        }
        
        var changes: [(file: String, count: Int)] = []
        
        let filesToSearch: [URL]
        if let specified = paths {
            filesToSearch = specified.map { resolveWorkingPath($0) }
        } else {
            var urls: [URL] = []
            let enumerator = FileManager.default.enumerator(
                at: workDir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            while let url = enumerator?.nextObject() as? URL {
                if isCodeFile(url) {
                    urls.append(url)
                }
            }
            filesToSearch = urls
        }
        
        for url in filesToSearch {
            guard var content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            
            let originalContent = content
            
            if isRegex {
                if let regex = try? NSRegularExpression(pattern: search) {
                    content = regex.stringByReplacingMatches(
                        in: content,
                        range: NSRange(content.startIndex..., in: content),
                        withTemplate: replace
                    )
                }
            } else {
                content = content.replacingOccurrences(of: search, with: replace)
            }
            
            if content != originalContent {
                let relativePath = url.path.replacingOccurrences(of: workDir.path + "/", with: "")
                let count = originalContent.components(separatedBy: search).count - 1
                changes.append((relativePath, count))
                
                if !dryRun {
                    try? content.write(to: url, atomically: true, encoding: .utf8)
                }
            }
        }
        
        if changes.isEmpty {
            return ToolResult(toolCallId: call.id, success: true, output: "No matches found for '\(search)'")
        }
        
        let prefix = dryRun ? "[DRY RUN] Would change" : "Changed"
        var output = "\(prefix) \(changes.count) files:\n"
        for (file, count) in changes {
            output += "  \(file): \(count) replacements\n"
        }
        
        return ToolResult(toolCallId: call.id, success: true, output: output)
    }
    
    // MARK: - Multi Edit
    
    private func executeMultiEdit(_ call: ToolCall) -> ToolResult {
        guard let path = call.arguments["path"] as? String,
              let edits = call.arguments["edits"] as? [[String: String]] else {
            return ToolResult(toolCallId: call.id, success: false, output: "Missing path or edits")
        }
        
        let fileURL = resolveWorkingPath(path)
        
        guard var content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return ToolResult(toolCallId: call.id, success: false, output: "Could not read file")
        }
        
        var appliedCount = 0
        
        for edit in edits {
            guard let oldString = edit["old_string"],
                  let newString = edit["new_string"] else { continue }
            
            if content.contains(oldString) {
                content = content.replacingOccurrences(of: oldString, with: newString)
                appliedCount += 1
            }
        }
        
        if appliedCount > 0 {
            do {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
                return ToolResult(toolCallId: call.id, success: true, output: "Applied \(appliedCount)/\(edits.count) edits to \(path)")
            } catch {
                return ToolResult(toolCallId: call.id, success: false, output: "Failed to write: \(error.localizedDescription)")
            }
        } else {
            return ToolResult(toolCallId: call.id, success: false, output: "No edits could be applied (old_string not found)")
        }
    }
    
    // MARK: - Helpers
    
    private func resolveWorkingPath(_ path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        return (workingDirectory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).appendingPathComponent(path)
    }
    
    private func isCodeFile(_ url: URL) -> Bool {
        let codeExtensions: Set<String> = [
            "swift", "ts", "tsx", "js", "jsx", "py", "rb", "go", "rs",
            "java", "kt", "cpp", "c", "h", "hpp", "cs", "php", "vue",
            "svelte", "html", "css", "scss", "json", "yaml", "yml",
            "toml", "xml", "md", "sh", "bash", "zsh", "sql"
        ]
        return codeExtensions.contains(url.pathExtension.lowercased())
    }
}
