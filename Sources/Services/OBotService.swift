import Foundation

// MARK: - OBot Service
// Comprehensive rules, bots, context, and templates system
// Superior to Cursor's .cursorrules and Windsurf's workflows

/*
 OBot Directory Structure:
 
 project/
 ├── .obotrules           # Project-wide AI rules (like .cursorrules)
 ├── .obot/
 │   ├── config.json      # OBot configuration
 │   ├── bots/            # Custom bot definitions
 │   │   ├── refactor.yaml
 │   │   ├── document.yaml
 │   │   └── test-generator.yaml
 │   ├── context/         # Reusable context snippets
 │   │   ├── api-docs.md
 │   │   └── style-guide.md
 │   ├── templates/       # Code generation templates
 │   │   ├── component.swift.tmpl
 │   │   └── test.swift.tmpl
 │   └── history/         # Bot execution history
 │       └── 2024-01-27.json
 
 Key Advantages over Cursor/Windsurf:
 1. YAML-based bots with full workflow support (not just prompts)
 2. Chainable multi-step bots with branching logic
 3. Context snippets that can be @mentioned
 4. Template engine with variable interpolation
 5. Bot versioning and sharing
 6. Execution history and analytics
 7. Integration with cycle agents for complex tasks
 8. Hot-reload on file changes
*/

@Observable
final class OBotService {
    
    // MARK: - Configuration
    
    static let rulesFileName = ".obotrules"
    static let obotDirectory = ".obot"
    static let botsDirectory = "bots"
    static let contextDirectory = "context"
    static let templatesDirectory = "templates"
    static let historyDirectory = "history"
    
    // MARK: - State
    
    private(set) var projectRules: ProjectRules?
    private(set) var bots: [OBot] = []
    private(set) var contextSnippets: [ContextSnippet] = []
    private(set) var templates: [CodeTemplate] = []
    private(set) var isLoaded: Bool = false
    
    private var projectRoot: URL?
    private var fileWatcher: DispatchSourceFileSystemObject?
    
    // MARK: - Dependencies
    
    private let fileSystemService: FileSystemService
    private let contextManager: ContextManager
    
    init(fileSystemService: FileSystemService, contextManager: ContextManager) {
        self.fileSystemService = fileSystemService
        self.contextManager = contextManager
    }
    
    // MARK: - Loading
    
    /// Load all OBot configuration for a project
    func loadProject(_ root: URL) async {
        self.projectRoot = root
        
        // Load in parallel
        async let rulesTask = loadRules(root)
        async let botsTask = loadBots(root)
        async let contextTask = loadContextSnippets(root)
        async let templatesTask = loadTemplates(root)
        
        self.projectRules = await rulesTask
        self.bots = await botsTask
        self.contextSnippets = await contextTask
        self.templates = await templatesTask
        
        // Update context manager with rules
        if let rules = projectRules {
            contextManager.setProjectRules(rules)
        }
        
        isLoaded = true
        print("🤖 OBot loaded: \(bots.count) bots, \(contextSnippets.count) contexts, \(templates.count) templates")
        
        // Start watching for changes
        startFileWatcher(root)
    }
    
    // MARK: - Rules Loading
    
    private func loadRules(_ root: URL) async -> ProjectRules? {
        let rulesPath = root.appendingPathComponent(Self.rulesFileName)
        
        guard let content = fileSystemService.readFile(at: rulesPath) else {
            return nil
        }
        
        return ProjectRules.parse(content, source: rulesPath)
    }
    
    // MARK: - Bots Loading
    
    private func loadBots(_ root: URL) async -> [OBot] {
        let botsDir = root
            .appendingPathComponent(Self.obotDirectory)
            .appendingPathComponent(Self.botsDirectory)
        
        guard FileManager.default.fileExists(atPath: botsDir.path) else {
            return []
        }
        
        var loadedBots: [OBot] = []
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: botsDir,
                includingPropertiesForKeys: nil
            )
            
            for file in files where file.pathExtension == "yaml" || file.pathExtension == "yml" {
                if let content = fileSystemService.readFile(at: file),
                   let bot = OBot.parse(content, source: file) {
                    loadedBots.append(bot)
                }
            }
        } catch {
            print("Error loading bots: \(error)")
        }
        
        return loadedBots.sorted { $0.name < $1.name }
    }
    
    // MARK: - Context Loading
    
    private func loadContextSnippets(_ root: URL) async -> [ContextSnippet] {
        let contextDir = root
            .appendingPathComponent(Self.obotDirectory)
            .appendingPathComponent(Self.contextDirectory)
        
        guard FileManager.default.fileExists(atPath: contextDir.path) else {
            return []
        }
        
        var snippets: [ContextSnippet] = []
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: contextDir,
                includingPropertiesForKeys: nil
            )
            
            for file in files where file.pathExtension == "md" || file.pathExtension == "txt" {
                if let content = fileSystemService.readFile(at: file) {
                    let snippet = ContextSnippet(
                        id: file.deletingPathExtension().lastPathComponent,
                        name: file.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "-", with: " ").capitalized,
                        content: content,
                        source: file
                    )
                    snippets.append(snippet)
                }
            }
        } catch {
            print("Error loading context snippets: \(error)")
        }
        
        return snippets.sorted { $0.name < $1.name }
    }
    
    // MARK: - Templates Loading
    
    private func loadTemplates(_ root: URL) async -> [CodeTemplate] {
        let templatesDir = root
            .appendingPathComponent(Self.obotDirectory)
            .appendingPathComponent(Self.templatesDirectory)
        
        guard FileManager.default.fileExists(atPath: templatesDir.path) else {
            return []
        }
        
        var loadedTemplates: [CodeTemplate] = []
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: templatesDir,
                includingPropertiesForKeys: nil
            )
            
            for file in files where file.pathExtension == "tmpl" || file.pathExtension == "template" {
                if let content = fileSystemService.readFile(at: file) {
                    let template = CodeTemplate.parse(content, source: file)
                    loadedTemplates.append(template)
                }
            }
        } catch {
            print("Error loading templates: \(error)")
        }
        
        return loadedTemplates.sorted { $0.name < $1.name }
    }
    
    // MARK: - File Watching
    
    private func startFileWatcher(_ root: URL) {
        let obotDir = root.appendingPathComponent(Self.obotDirectory)
        
        guard FileManager.default.fileExists(atPath: obotDir.path) else { return }
        
        let fd = open(obotDir.path, O_EVTONLY)
        guard fd >= 0 else { return }
        
        fileWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        
        fileWatcher?.setEventHandler { [weak self] in
            guard let self = self, let root = self.projectRoot else { return }
            Task {
                await self.loadProject(root)
            }
        }
        
        fileWatcher?.setCancelHandler {
            close(fd)
        }
        
        fileWatcher?.resume()
    }
    
    // MARK: - Bot Execution
    
    /// Execute a bot with the given input
    func executeBot(_ bot: OBot, input: String, context: BotExecutionContext) async throws -> BotExecutionResult {
        var result = BotExecutionResult(botId: bot.id, startTime: Date())
        
        // Build initial context
        var stepContext = context
        stepContext.input = input
        
        // Execute each step
        for (index, step) in bot.steps.enumerated() {
            result.currentStep = index
            
            let stepResult = try await executeStep(step, context: stepContext, bot: bot)
            result.stepResults.append(stepResult)
            
            // Check for early exit conditions
            if stepResult.shouldExit {
                break
            }
            
            // Pass output to next step
            stepContext.previousOutput = stepResult.output
            stepContext.variables.merge(stepResult.variables) { _, new in new }
        }
        
        result.endTime = Date()
        result.finalOutput = result.stepResults.last?.output ?? ""
        
        // Save to history
        await saveExecutionHistory(result)
        
        return result
    }
    
    private func executeStep(_ step: OBot.Step, context: BotExecutionContext, bot: OBot) async throws -> StepResult {
        switch step.type {
        case .prompt:
            return try await executePromptStep(step, context: context)
        case .code:
            return try await executeCodeStep(step, context: context)
        case .file:
            return try await executeFileStep(step, context: context)
        case .condition:
            return try await executeConditionStep(step, context: context, bot: bot)
        case .loop:
            return try await executeLoopStep(step, context: context, bot: bot)
        case .delegate:
            return try await executeDelegateStep(step, context: context)
        case .template:
            return try await executeTemplateStep(step, context: context)
        }
    }
    
    private func executePromptStep(_ step: OBot.Step, context: BotExecutionContext) async throws -> StepResult {
        // Interpolate variables in prompt
        let prompt = interpolate(step.content, with: context.variables)
        
        // This would integrate with OllamaService - placeholder for now
        return StepResult(
            stepId: step.id,
            type: .prompt,
            input: prompt,
            output: "AI response would go here",
            success: true
        )
    }
    
    private func executeCodeStep(_ step: OBot.Step, context: BotExecutionContext) async throws -> StepResult {
        // Execute code transformation
        let code = interpolate(step.content, with: context.variables)
        
        return StepResult(
            stepId: step.id,
            type: .code,
            input: code,
            output: code, // Code steps pass through
            success: true
        )
    }
    
    private func executeFileStep(_ step: OBot.Step, context: BotExecutionContext) async throws -> StepResult {
        guard let root = projectRoot else {
            throw OBotError.noProjectRoot
        }
        
        let filePath = interpolate(step.content, with: context.variables)
        let fileURL = root.appendingPathComponent(filePath)
        
        if let content = fileSystemService.readFile(at: fileURL) {
            return StepResult(
                stepId: step.id,
                type: .file,
                input: filePath,
                output: content,
                success: true,
                variables: ["file_content": content, "file_path": filePath]
            )
        } else {
            return StepResult(
                stepId: step.id,
                type: .file,
                input: filePath,
                output: "",
                success: false,
                error: "File not found: \(filePath)"
            )
        }
    }
    
    private func executeConditionStep(_ step: OBot.Step, context: BotExecutionContext, bot: OBot) async throws -> StepResult {
        // Evaluate condition
        let condition = interpolate(step.content, with: context.variables)
        let result = evaluateCondition(condition, context: context)
        
        return StepResult(
            stepId: step.id,
            type: .condition,
            input: condition,
            output: result ? "true" : "false",
            success: true,
            shouldExit: !result && step.exitOnFalse
        )
    }
    
    private func executeLoopStep(_ step: OBot.Step, context: BotExecutionContext, bot: OBot) async throws -> StepResult {
        // Parse loop configuration
        let items = context.variables[step.loopVariable ?? "items"] as? [String] ?? []
        var outputs: [String] = []
        
        for item in items {
            var loopContext = context
            loopContext.variables["item"] = item
            
            // Execute nested steps
            for nestedStep in step.nestedSteps {
                let result = try await executeStep(nestedStep, context: loopContext, bot: bot)
                outputs.append(result.output)
            }
        }
        
        return StepResult(
            stepId: step.id,
            type: .loop,
            input: step.content,
            output: outputs.joined(separator: "\n"),
            success: true
        )
    }
    
    private func executeDelegateStep(_ step: OBot.Step, context: BotExecutionContext) async throws -> StepResult {
        // Delegate to another bot or agent
        let targetBot = step.delegateTarget ?? ""
        
        return StepResult(
            stepId: step.id,
            type: .delegate,
            input: targetBot,
            output: "Delegated to \(targetBot)",
            success: true
        )
    }
    
    private func executeTemplateStep(_ step: OBot.Step, context: BotExecutionContext) async throws -> StepResult {
        let templateName = step.templateName ?? step.content
        
        guard let template = templates.first(where: { $0.id == templateName }) else {
            return StepResult(
                stepId: step.id,
                type: .template,
                input: templateName,
                output: "",
                success: false,
                error: "Template not found: \(templateName)"
            )
        }
        
        let rendered = template.render(with: context.variables)
        
        return StepResult(
            stepId: step.id,
            type: .template,
            input: templateName,
            output: rendered,
            success: true
        )
    }
    
    // MARK: - Utilities
    
    private func interpolate(_ text: String, with variables: [String: Any]) -> String {
        var result = text
        
        for (key, value) in variables {
            let pattern = "{{\(key)}}"
            result = result.replacingOccurrences(of: pattern, with: String(describing: value))
        }
        
        return result
    }
    
    private func evaluateCondition(_ condition: String, context: BotExecutionContext) -> Bool {
        // Simple condition evaluation
        // Supports: {{var}} == "value", {{var}} != "value", {{var}} contains "text"
        
        let parts = condition.components(separatedBy: " ")
        guard parts.count >= 3 else { return false }
        
        let leftRaw = parts[0]
        let op = parts[1]
        let rightRaw = parts[2...].joined(separator: " ")
        
        let left = interpolate(leftRaw, with: context.variables)
        let right = rightRaw.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        
        switch op {
        case "==": return left == right
        case "!=": return left != right
        case "contains": return left.contains(right)
        case "startsWith": return left.hasPrefix(right)
        case "endsWith": return left.hasSuffix(right)
        default: return false
        }
    }
    
    private func saveExecutionHistory(_ result: BotExecutionResult) async {
        guard let root = projectRoot else { return }
        
        let historyDir = root
            .appendingPathComponent(Self.obotDirectory)
            .appendingPathComponent(Self.historyDirectory)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: historyDir, withIntermediateDirectories: true)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "\(dateFormatter.string(from: Date())).json"
        let historyFile = historyDir.appendingPathComponent(fileName)
        
        // Load existing history
        var history: [[String: Any]] = []
        if let existingData = fileSystemService.readFile(at: historyFile),
           let existingHistory = try? JSONSerialization.jsonObject(with: Data(existingData.utf8)) as? [[String: Any]] {
            history = existingHistory
        }
        
        // Add new entry
        history.append(result.toDictionary())
        
        // Save
        if let data = try? JSONSerialization.data(withJSONObject: history, options: .prettyPrinted) {
            fileSystemService.writeFile(content: String(data: data, encoding: .utf8) ?? "", to: historyFile)
        }
    }
    
    // MARK: - Bot Management
    
    /// Create a new bot
    func createBot(_ bot: OBot) async throws {
        guard let root = projectRoot else {
            throw OBotError.noProjectRoot
        }
        
        let botsDir = root
            .appendingPathComponent(Self.obotDirectory)
            .appendingPathComponent(Self.botsDirectory)
        
        // Create directory if needed
        try FileManager.default.createDirectory(at: botsDir, withIntermediateDirectories: true)
        
        let botFile = botsDir.appendingPathComponent("\(bot.id).yaml")
        let yaml = bot.toYAML()
        
        fileSystemService.writeFile(content: yaml, to: botFile)
        
        // Reload
        self.bots = await loadBots(root)
    }
    
    /// Delete a bot
    func deleteBot(_ bot: OBot) async throws {
        guard let root = projectRoot, let source = bot.source else {
            throw OBotError.noProjectRoot
        }
        
        try FileManager.default.removeItem(at: source)
        
        // Reload
        self.bots = await loadBots(root)
    }
    
    // MARK: - Context Snippet Management
    
    /// Get context snippet by ID
    func getContextSnippet(_ id: String) -> ContextSnippet? {
        contextSnippets.first { $0.id == id }
    }
    
    /// Get all @mentionable items (bots + context snippets)
    func getMentionables() -> [Mentionable] {
        var items: [Mentionable] = []
        
        // Add bots
        items.append(contentsOf: bots.map { bot in
            Mentionable(
                id: "bot:\(bot.id)",
                name: bot.name,
                type: .bot,
                icon: bot.icon ?? "cpu",
                description: bot.description
            )
        })
        
        // Add context snippets
        items.append(contentsOf: contextSnippets.map { snippet in
            Mentionable(
                id: "context:\(snippet.id)",
                name: snippet.name,
                type: .context,
                icon: "doc.text",
                description: "Context: \(snippet.name)"
            )
        })
        
        // Add templates
        items.append(contentsOf: templates.map { template in
            Mentionable(
                id: "template:\(template.id)",
                name: template.name,
                type: .template,
                icon: "doc.badge.gearshape",
                description: template.description
            )
        })
        
        return items
    }
    
    // MARK: - Scaffold Generation
    
    /// Generate default .obot directory structure
    func scaffoldOBotDirectory(at root: URL) async throws {
        let obotDir = root.appendingPathComponent(Self.obotDirectory)
        
        // Create directories
        let directories = [
            obotDir,
            obotDir.appendingPathComponent(Self.botsDirectory),
            obotDir.appendingPathComponent(Self.contextDirectory),
            obotDir.appendingPathComponent(Self.templatesDirectory),
            obotDir.appendingPathComponent(Self.historyDirectory)
        ]
        
        for dir in directories {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        // Create default .obotrules
        let rulesContent = """
        # OllamaBot Project Rules
        # These rules are automatically included in every AI conversation
        
        ## Project Context
        - This is a [describe your project]
        - Main language: [Swift/Python/TypeScript/etc]
        - Framework: [SwiftUI/React/etc]
        
        ## Coding Standards
        - Follow existing code style and conventions
        - Write clean, well-documented code
        - Include error handling
        - Write tests for new functionality
        
        ## Response Preferences
        - Be concise but thorough
        - Explain significant changes
        - Suggest improvements when relevant
        
        ## File Organization
        - Place new files in appropriate directories
        - Follow existing naming conventions
        - Keep related code together
        """
        
        let rulesPath = root.appendingPathComponent(Self.rulesFileName)
        fileSystemService.writeFile(content: rulesContent, to: rulesPath)
        
        // Create example bot
        let exampleBot = """
        # Example OBot: Code Refactor
        # Run with @refactor in chat or from command palette
        
        name: Refactor Code
        id: refactor
        description: Intelligently refactor selected code for better readability and performance
        icon: wand.and.stars
        
        # Input can come from selection or explicit input
        input:
          type: selection  # or 'text', 'file', 'files'
          required: true
          placeholder: "Select code to refactor"
        
        # Steps are executed in order
        steps:
          - type: prompt
            name: Analyze
            content: |
              Analyze this code and identify:
              1. Code smells and anti-patterns
              2. Performance issues
              3. Readability problems
              
              Code to analyze:
              ```
              {{input}}
              ```
        
          - type: prompt
            name: Refactor
            content: |
              Based on the analysis, refactor the code to:
              1. Fix identified issues
              2. Improve readability
              3. Follow best practices
              
              Original code:
              ```
              {{input}}
              ```
              
              Provide the refactored code with comments explaining changes.
        
        # Output configuration
        output:
          type: replace  # or 'insert', 'new_file', 'panel'
          format: code
        """
        
        let botPath = obotDir
            .appendingPathComponent(Self.botsDirectory)
            .appendingPathComponent("refactor.yaml")
        fileSystemService.writeFile(content: exampleBot, to: botPath)
        
        // Create example context
        let exampleContext = """
        # API Documentation
        
        This context snippet contains API documentation that can be @mentioned in conversations.
        
        ## Usage
        
        In the chat, type `@api-docs` to include this context.
        
        ## Your API Docs
        
        Add your API documentation here...
        """
        
        let contextPath = obotDir
            .appendingPathComponent(Self.contextDirectory)
            .appendingPathComponent("api-docs.md")
        fileSystemService.writeFile(content: exampleContext, to: contextPath)
        
        // Create example template
        let exampleTemplate = """
        {{!-- 
        Template: Swift View Component
        Variables: name, description
        --}}
        
        import SwiftUI
        
        /// {{description}}
        struct {{name}}View: View {
            @Environment(AppState.self) private var appState
            
            var body: some View {
                VStack {
                    Text("{{name}}")
                }
            }
        }
        
        #Preview {
            {{name}}View()
                .environment(AppState())
        }
        """
        
        let templatePath = obotDir
            .appendingPathComponent(Self.templatesDirectory)
            .appendingPathComponent("swift-view.swift.tmpl")
        fileSystemService.writeFile(content: exampleTemplate, to: templatePath)
        
        // Reload
        await loadProject(root)
    }
}

// MARK: - Data Models

/// Project-wide rules from .obotrules
struct ProjectRules {
    let content: String
    let source: URL
    let sections: [RulesSection]
    
    struct RulesSection {
        let title: String
        let content: String
    }
    
    static func parse(_ content: String, source: URL) -> ProjectRules {
        var sections: [RulesSection] = []
        var currentTitle = ""
        var currentContent = ""
        
        for line in content.components(separatedBy: "\n") {
            if line.hasPrefix("## ") {
                // Save previous section
                if !currentTitle.isEmpty {
                    sections.append(RulesSection(title: currentTitle, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                currentTitle = String(line.dropFirst(3))
                currentContent = ""
            } else {
                currentContent += line + "\n"
            }
        }
        
        // Save last section
        if !currentTitle.isEmpty {
            sections.append(RulesSection(title: currentTitle, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        
        return ProjectRules(content: content, source: source, sections: sections)
    }
}

/// Custom bot definition
struct OBot: Identifiable, Equatable {
    let id: String
    var name: String
    var description: String
    var icon: String?
    var input: InputConfig
    var steps: [Step]
    var output: OutputConfig
    var source: URL?
    
    struct InputConfig: Equatable {
        var type: InputType
        var required: Bool
        var placeholder: String?
        
        enum InputType: String {
            case selection, text, file, files
        }
    }
    
    struct Step: Identifiable, Equatable {
        let id: String
        var type: StepType
        var name: String
        var content: String
        var exitOnFalse: Bool = false
        var loopVariable: String?
        var nestedSteps: [Step] = []
        var delegateTarget: String?
        var templateName: String?
        
        enum StepType: String {
            case prompt, code, file, condition, loop, delegate, template
        }
    }
    
    struct OutputConfig: Equatable {
        var type: OutputType
        var format: String?
        var fileName: String?
        
        enum OutputType: String {
            case replace, insert, newFile = "new_file", panel
        }
    }
    
    static func == (lhs: OBot, rhs: OBot) -> Bool {
        lhs.id == rhs.id
    }
    
    static func parse(_ yaml: String, source: URL) -> OBot? {
        // Simple YAML parser for bot definition
        var id = ""
        var name = ""
        var description = ""
        var icon: String?
        var inputType = InputConfig.InputType.selection
        var inputRequired = true
        var placeholder: String?
        var steps: [Step] = []
        var outputType = OutputConfig.OutputType.replace
        var outputFormat: String?
        
        var currentSection = ""
        var currentStepType = ""
        var currentStepName = ""
        var currentStepContent = ""
        var inSteps = false
        var contentIndent = 0
        
        for line in yaml.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments and empty lines
            if trimmed.hasPrefix("#") || trimmed.isEmpty { continue }
            
            // Top-level keys
            if !line.hasPrefix(" ") && !line.hasPrefix("\t") {
                if trimmed.hasPrefix("name:") {
                    name = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("id:") {
                    id = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("description:") {
                    description = trimmed.dropFirst(12).trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("icon:") {
                    icon = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
                } else if trimmed == "input:" {
                    currentSection = "input"
                } else if trimmed == "steps:" {
                    currentSection = "steps"
                    inSteps = true
                } else if trimmed == "output:" {
                    currentSection = "output"
                    inSteps = false
                }
            }
            // Section content
            else if currentSection == "input" {
                if trimmed.hasPrefix("type:") {
                    if let type = InputConfig.InputType(rawValue: trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)) {
                        inputType = type
                    }
                } else if trimmed.hasPrefix("required:") {
                    inputRequired = trimmed.contains("true")
                } else if trimmed.hasPrefix("placeholder:") {
                    placeholder = trimmed.dropFirst(12).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                }
            }
            else if currentSection == "steps" && inSteps {
                if trimmed.hasPrefix("- type:") {
                    // Save previous step
                    if !currentStepType.isEmpty {
                        if let type = Step.StepType(rawValue: currentStepType) {
                            steps.append(Step(
                                id: UUID().uuidString,
                                type: type,
                                name: currentStepName,
                                content: currentStepContent.trimmingCharacters(in: .whitespacesAndNewlines)
                            ))
                        }
                    }
                    currentStepType = trimmed.dropFirst(7).trimmingCharacters(in: .whitespaces)
                    currentStepName = ""
                    currentStepContent = ""
                    contentIndent = 0
                } else if trimmed.hasPrefix("name:") {
                    currentStepName = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("content:") {
                    // Check if content is inline or multiline
                    let contentPart = trimmed.dropFirst(8).trimmingCharacters(in: .whitespaces)
                    if contentPart == "|" {
                        contentIndent = line.prefix(while: { $0 == " " }).count + 2
                    } else {
                        currentStepContent = String(contentPart)
                    }
                } else if contentIndent > 0 && line.prefix(while: { $0 == " " }).count >= contentIndent {
                    currentStepContent += line.dropFirst(contentIndent) + "\n"
                }
            }
            else if currentSection == "output" {
                if trimmed.hasPrefix("type:") {
                    if let type = OutputConfig.OutputType(rawValue: trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)) {
                        outputType = type
                    }
                } else if trimmed.hasPrefix("format:") {
                    outputFormat = trimmed.dropFirst(7).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        // Save last step
        if !currentStepType.isEmpty {
            if let type = Step.StepType(rawValue: currentStepType) {
                steps.append(Step(
                    id: UUID().uuidString,
                    type: type,
                    name: currentStepName,
                    content: currentStepContent.trimmingCharacters(in: .whitespacesAndNewlines)
                ))
            }
        }
        
        guard !id.isEmpty else { return nil }
        
        return OBot(
            id: id,
            name: name.isEmpty ? id : name,
            description: description,
            icon: icon,
            input: InputConfig(type: inputType, required: inputRequired, placeholder: placeholder),
            steps: steps,
            output: OutputConfig(type: outputType, format: outputFormat),
            source: source
        )
    }
    
    func toYAML() -> String {
        var yaml = """
        name: \(name)
        id: \(id)
        description: \(description)
        icon: \(icon ?? "cpu")
        
        input:
          type: \(input.type.rawValue)
          required: \(input.required)
        """
        
        if let placeholder = input.placeholder {
            yaml += "\n  placeholder: \"\(placeholder)\""
        }
        
        yaml += "\n\nsteps:"
        
        for step in steps {
            yaml += """
            
              - type: \(step.type.rawValue)
                name: \(step.name)
                content: |
            """
            for line in step.content.components(separatedBy: "\n") {
                yaml += "\n      \(line)"
            }
        }
        
        yaml += """
        
        
        output:
          type: \(output.type.rawValue)
        """
        
        if let format = output.format {
            yaml += "\n  format: \(format)"
        }
        
        return yaml
    }
}

/// Reusable context snippet
struct ContextSnippet: Identifiable {
    let id: String
    let name: String
    let content: String
    let source: URL
}

/// Code generation template
struct CodeTemplate: Identifiable {
    let id: String
    let name: String
    let description: String
    let content: String
    let variables: [TemplateVariable]
    let source: URL
    
    struct TemplateVariable {
        let name: String
        let description: String?
        let defaultValue: String?
        let required: Bool
    }
    
    static func parse(_ content: String, source: URL) -> CodeTemplate {
        let fileName = source.deletingPathExtension().lastPathComponent
        
        // Extract metadata from template comments
        var description = ""
        var variables: [TemplateVariable] = []
        
        // Look for {{!-- ... --}} comments at start
        if content.hasPrefix("{{!--") {
            if let endIndex = content.range(of: "--}}") {
                let metaContent = String(content[content.index(content.startIndex, offsetBy: 5)..<endIndex.lowerBound])
                
                for line in metaContent.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("Template:") {
                        // Name is in the first line
                    } else if trimmed.hasPrefix("Variables:") {
                        let varList = trimmed.dropFirst(10).trimmingCharacters(in: .whitespaces)
                        for varName in varList.components(separatedBy: ",") {
                            variables.append(TemplateVariable(
                                name: varName.trimmingCharacters(in: .whitespaces),
                                description: nil,
                                defaultValue: nil,
                                required: true
                            ))
                        }
                    } else if !trimmed.isEmpty {
                        description += trimmed + " "
                    }
                }
            }
        }
        
        return CodeTemplate(
            id: fileName,
            name: fileName.replacingOccurrences(of: "-", with: " ").capitalized,
            description: description.trimmingCharacters(in: .whitespaces),
            content: content,
            variables: variables,
            source: source
        )
    }
    
    func render(with values: [String: Any]) -> String {
        var result = content
        
        // Remove template metadata comments
        if let range = result.range(of: "{{!--[\\s\\S]*?--}}", options: .regularExpression) {
            result.removeSubrange(range)
        }
        
        // Replace variables
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: String(describing: value))
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Item that can be @mentioned
struct Mentionable: Identifiable {
    let id: String
    let name: String
    let type: MentionType
    let icon: String
    let description: String
    
    enum MentionType {
        case bot, context, template, file
    }
}

// MARK: - Execution Types

struct BotExecutionContext {
    var input: String = ""
    var previousOutput: String = ""
    var variables: [String: Any] = [:]
    var selectedFile: FileItem?
    var selectedText: String?
}

struct BotExecutionResult {
    let botId: String
    let startTime: Date
    var endTime: Date?
    var currentStep: Int = 0
    var stepResults: [StepResult] = []
    var finalOutput: String = ""
    
    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }
    
    func toDictionary() -> [String: Any] {
        [
            "botId": botId,
            "startTime": ISO8601DateFormatter().string(from: startTime),
            "endTime": endTime.map { ISO8601DateFormatter().string(from: $0) } ?? "",
            "duration": duration,
            "stepCount": stepResults.count,
            "success": stepResults.allSatisfy { $0.success }
        ]
    }
}

struct StepResult {
    let stepId: String
    let type: OBot.Step.StepType
    let input: String
    var output: String
    var success: Bool
    var error: String?
    var variables: [String: Any] = [:]
    var shouldExit: Bool = false
}

// MARK: - Errors

enum OBotError: LocalizedError {
    case noProjectRoot
    case botNotFound(String)
    case templateNotFound(String)
    case executionFailed(String)
    case invalidYAML(String)
    
    var errorDescription: String? {
        switch self {
        case .noProjectRoot: return "No project root set"
        case .botNotFound(let id): return "Bot not found: \(id)"
        case .templateNotFound(let id): return "Template not found: \(id)"
        case .executionFailed(let msg): return "Execution failed: \(msg)"
        case .invalidYAML(let msg): return "Invalid YAML: \(msg)"
        }
    }
}

// MARK: - ContextManager Extension
// Note: setProjectRules is now implemented directly in ContextManager.swift
