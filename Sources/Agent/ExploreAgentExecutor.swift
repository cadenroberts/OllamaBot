import Foundation
import SwiftUI

// MARK: - Explore Agent Executor
// Autonomous, explorative agent that continuously improves projects
// Unlike Infinite Mode (task-focused), Explore Mode expands, specifies, and standardizes

@Observable
class ExploreAgentExecutor {
    
    // MARK: - Exploration Phases
    
    enum ExplorePhase: String, CaseIterable {
        case understanding = "Understanding"      // Initial project analysis
        case expanding = "Expanding"              // Adding new features
        case specifying = "Specifying"            // Adding edge cases, validation
        case standardizing = "Standardizing"      // Applying consistent patterns
        case documenting = "Documenting"          // Auto-documentation
        case reflecting = "Reflecting"            // Review and plan next cycle
        
        var icon: String {
            switch self {
            case .understanding: return "magnifyingglass"
            case .expanding: return "arrow.up.left.and.arrow.down.right"
            case .specifying: return "target"
            case .standardizing: return "checkmark.seal"
            case .documenting: return "doc.text"
            case .reflecting: return "brain"
            }
        }
        
        var description: String {
            switch self {
            case .understanding: return "Analyzing project structure and current state"
            case .expanding: return "Adding new features and capabilities"
            case .specifying: return "Adding edge cases, validation, error handling"
            case .standardizing: return "Applying consistent patterns across codebase"
            case .documenting: return "Updating documentation and comments"
            case .reflecting: return "Reviewing progress and planning next cycle"
            }
        }
    }
    
    // MARK: - Exploration Step
    
    struct ExploreStep: Identifiable {
        let id = UUID()
        let timestamp = Date()
        let phase: ExplorePhase
        let content: String
        var subSteps: [SubStep] = []
        var isComplete: Bool = false
        
        struct SubStep: Identifiable {
            let id = UUID()
            let description: String
            let tool: String?
            let output: String?
            let success: Bool
        }
    }
    
    // MARK: - Exploration Tree (tracks expansion history)
    
    struct ExpansionNode: Identifiable {
        let id = UUID()
        let description: String
        let depth: Int
        var children: [ExpansionNode] = []
        var isComplete: Bool = false
        var filesAffected: [String] = []
    }
    
    // MARK: - Services
    
    private let ollamaService: OllamaService
    private let fileSystemService: FileSystemService
    private let contextManager: ContextManager
    
    // MARK: - State
    
    var isRunning = false
    var isPaused = false
    var originalGoal: String = ""
    var currentPhase: ExplorePhase = .understanding
    var currentFocus: String = ""
    var steps: [ExploreStep] = []
    var expansionTree: [ExpansionNode] = []
    var cycleCount: Int = 0
    var changesThisCycle: Int = 0
    var totalChanges: Int = 0
    var workingDirectory: URL?
    
    // Auto-documentation
    var generatedDocs: [GeneratedDoc] = []
    
    struct GeneratedDoc: Identifiable {
        let id = UUID()
        let title: String
        let content: String
        let timestamp: Date
        let relatedFiles: [String]
    }
    
    // Configuration
    var maxExpansionDepth: Int = 3
    var changesBeforeDocumentation: Int = 5
    var pauseBetweenCycles: TimeInterval = 2.0
    var explorationStyle: ExplorationStyle = .balanced
    
    enum ExplorationStyle: String, CaseIterable {
        case conservative = "Conservative"  // Fewer changes, more validation
        case balanced = "Balanced"          // Default balance
        case aggressive = "Aggressive"      // More features, faster iteration
    }
    
    // MARK: - Initialization
    
    init(ollamaService: OllamaService, fileSystemService: FileSystemService, contextManager: ContextManager) {
        self.ollamaService = ollamaService
        self.fileSystemService = fileSystemService
        self.contextManager = contextManager
    }
    
    // MARK: - Public API
    
    func start(goal: String, workingDirectory: URL?) {
        guard !isRunning else { return }
        
        self.isRunning = true
        self.isPaused = false
        self.originalGoal = goal
        self.workingDirectory = workingDirectory
        self.steps = []
        self.expansionTree = []
        self.cycleCount = 0
        self.changesThisCycle = 0
        self.totalChanges = 0
        self.currentPhase = .understanding
        self.currentFocus = goal
        
        Task(priority: .userInitiated) {
            await runExploreLoop()
        }
    }
    
    func pause() {
        isPaused = true
        addStep(phase: .reflecting, content: "Exploration paused by user")
    }
    
    func resume() {
        guard isPaused else { return }
        isPaused = false
        
        Task {
            await runExploreLoop()
        }
    }
    
    func stop() {
        isRunning = false
        isPaused = false
        addStep(phase: .reflecting, content: "Exploration stopped by user")
    }
    
    func redirectFocus(_ newFocus: String) {
        currentFocus = newFocus
        addStep(phase: .reflecting, content: "Focus redirected to: \(newFocus)")
    }
    
    // MARK: - Main Exploration Loop
    
    private func runExploreLoop() async {
        addStep(phase: .understanding, content: "Starting exploration: \(originalGoal)")
        
        while isRunning && !isPaused {
            cycleCount += 1
            changesThisCycle = 0
            
            // Phase 1: Understanding
            await executePhase(.understanding)
            guard isRunning && !isPaused else { break }
            
            // Phase 2: Expanding
            await executePhase(.expanding)
            guard isRunning && !isPaused else { break }
            
            // Phase 3: Specifying
            await executePhase(.specifying)
            guard isRunning && !isPaused else { break }
            
            // Phase 4: Standardizing
            await executePhase(.standardizing)
            guard isRunning && !isPaused else { break }
            
            // Phase 5: Documenting (after threshold changes)
            if totalChanges % changesBeforeDocumentation == 0 && totalChanges > 0 {
                await executePhase(.documenting)
            }
            guard isRunning && !isPaused else { break }
            
            // Phase 6: Reflecting
            await executePhase(.reflecting)
            guard isRunning && !isPaused else { break }
            
            // Brief pause between cycles
            try? await Task.sleep(nanoseconds: UInt64(pauseBetweenCycles * 1_000_000_000))
        }
    }
    
    // MARK: - Phase Execution
    
    private func executePhase(_ phase: ExplorePhase) async {
        currentPhase = phase
        
        // Build phase-specific context
        let context = buildExploreContext(for: phase)
        
        // Get AI guidance for this phase
        let guidance = await getPhaseGuidance(phase: phase, context: context)
        
        addStep(phase: phase, content: guidance.summary)
        
        // Execute phase actions
        for action in guidance.actions {
            guard isRunning && !isPaused else { return }
            
            let result = await executeAction(action, phase: phase)
            
            if result.madeChanges {
                changesThisCycle += 1
                totalChanges += 1
            }
            
            // Record as sub-step
            if var lastStep = steps.last {
                lastStep.subSteps.append(ExploreStep.SubStep(
                    description: action.description,
                    tool: action.tool,
                    output: result.output,
                    success: result.success
                ))
            }
        }
        
        // Mark phase complete
        if var lastStep = steps.last {
            lastStep.isComplete = true
        }
    }
    
    private func buildExploreContext(for phase: ExplorePhase) -> String {
        var context = """
        # Explore Mode Context
        
        ## Original Goal
        \(originalGoal)
        
        ## Current Focus
        \(currentFocus)
        
        ## Exploration Phase
        \(phase.rawValue): \(phase.description)
        
        ## Cycle Progress
        - Cycle: \(cycleCount)
        - Changes this cycle: \(changesThisCycle)
        - Total changes: \(totalChanges)
        - Expansion depth: \(currentExpansionDepth)
        
        ## Exploration Style
        \(explorationStyle.rawValue)
        
        """
        
        // Add project context from ContextManager
        if let projectContext = contextManager.getProjectRulesContext() {
            context += "\n## Project Rules\n\(projectContext)\n"
        }
        
        // Add recent changes
        if !expansionTree.isEmpty {
            context += "\n## Recent Expansions\n"
            for node in expansionTree.suffix(5) {
                context += "- \(node.description)\n"
            }
        }
        
        return context
    }
    
    private var currentExpansionDepth: Int {
        expansionTree.map { $0.depth }.max() ?? 0
    }
    
    // MARK: - AI Guidance
    
    struct PhaseGuidance {
        let summary: String
        let actions: [ExploreAction]
    }
    
    struct ExploreAction {
        let description: String
        let tool: String?
        let parameters: [String: String]
    }
    
    struct ActionResult {
        let success: Bool
        let output: String
        let madeChanges: Bool
    }
    
    private func getPhaseGuidance(phase: ExplorePhase, context: String) async -> PhaseGuidance {
        let systemPrompt = buildPhasePrompt(phase: phase)
        
        do {
            var guidance = ""
            let stream = ollamaService.chat(
                model: .qwen3,  // Orchestrator
                messages: [("user", context)],
                context: systemPrompt,
                images: []
            )
            
            for try await chunk in stream {
                guidance += chunk
            }
            
            return parseGuidance(guidance, phase: phase)
        } catch {
            return PhaseGuidance(
                summary: "Error getting guidance: \(error.localizedDescription)",
                actions: []
            )
        }
    }
    
    private func buildPhasePrompt(phase: ExplorePhase) -> String {
        let basePrompt = """
        You are an AI assistant in Explore Mode. Your job is to continuously improve a project by:
        - \(phase.description)
        
        Always stay true to the original goal while exploring improvements.
        
        Response Format:
        SUMMARY: <brief description of what you'll do>
        ACTIONS:
        - ACTION: <description> | TOOL: <tool_name> | PARAMS: <param1=value1, param2=value2>
        
        Available tools: read_file, write_file, edit_file, search_files, list_directory, run_command
        """
        
        switch phase {
        case .understanding:
            return basePrompt + "\n\nFocus on analyzing the project structure, understanding existing code, and identifying areas for improvement."
            
        case .expanding:
            return basePrompt + "\n\nFocus on adding new features, capabilities, or enhancements that align with the original goal. Be creative but practical."
            
        case .specifying:
            return basePrompt + "\n\nFocus on adding edge case handling, input validation, error handling, and making the code more robust."
            
        case .standardizing:
            return basePrompt + "\n\nFocus on applying consistent patterns, naming conventions, and best practices across the codebase."
            
        case .documenting:
            return basePrompt + "\n\nFocus on updating documentation, adding comments, and ensuring the code is well-documented."
            
        case .reflecting:
            return basePrompt + "\n\nFocus on reviewing what was done, evaluating quality, and planning the next expansion areas."
        }
    }
    
    private func parseGuidance(_ response: String, phase: ExplorePhase) -> PhaseGuidance {
        var summary = phase.description
        var actions: [ExploreAction] = []
        
        let lines = response.components(separatedBy: "\n")
        
        for line in lines {
            if line.hasPrefix("SUMMARY:") {
                summary = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("- ACTION:") {
                let parts = line.components(separatedBy: "|")
                if parts.count >= 1 {
                    let desc = parts[0].replacingOccurrences(of: "- ACTION:", with: "").trimmingCharacters(in: .whitespaces)
                    var tool: String?
                    var params: [String: String] = [:]
                    
                    for part in parts.dropFirst() {
                        let trimmed = part.trimmingCharacters(in: .whitespaces)
                        if trimmed.hasPrefix("TOOL:") {
                            tool = trimmed.replacingOccurrences(of: "TOOL:", with: "").trimmingCharacters(in: .whitespaces)
                        } else if trimmed.hasPrefix("PARAMS:") {
                            let paramStr = trimmed.replacingOccurrences(of: "PARAMS:", with: "").trimmingCharacters(in: .whitespaces)
                            for pair in paramStr.components(separatedBy: ",") {
                                let kv = pair.components(separatedBy: "=")
                                if kv.count == 2 {
                                    params[kv[0].trimmingCharacters(in: .whitespaces)] = kv[1].trimmingCharacters(in: .whitespaces)
                                }
                            }
                        }
                    }
                    
                    actions.append(ExploreAction(description: desc, tool: tool, parameters: params))
                }
            }
        }
        
        // Limit actions based on exploration style
        let maxActions: Int
        switch explorationStyle {
        case .conservative: maxActions = 2
        case .balanced: maxActions = 4
        case .aggressive: maxActions = 8
        }
        
        return PhaseGuidance(
            summary: summary,
            actions: Array(actions.prefix(maxActions))
        )
    }
    
    // MARK: - Action Execution
    
    private func executeAction(_ action: ExploreAction, phase: ExplorePhase) async -> ActionResult {
        guard let tool = action.tool else {
            return ActionResult(success: true, output: action.description, madeChanges: false)
        }
        
        switch tool {
        case "read_file":
            if let path = action.parameters["path"] {
                let fullPath = resolvePath(path)
                if let content = fileSystemService.readFile(at: fullPath) {
                    return ActionResult(success: true, output: "Read \(path)", madeChanges: false)
                }
            }
            return ActionResult(success: false, output: "Failed to read file", madeChanges: false)
            
        case "write_file":
            if let path = action.parameters["path"], let content = action.parameters["content"] {
                let fullPath = resolvePath(path)
                fileSystemService.writeFile(content: content, to: fullPath)
                addExpansionNode(description: "Created \(path)", depth: currentExpansionDepth + 1, files: [path])
                return ActionResult(success: true, output: "Wrote \(path)", madeChanges: true)
            }
            return ActionResult(success: false, output: "Failed to write file", madeChanges: false)
            
        case "edit_file":
            if let path = action.parameters["path"],
               let search = action.parameters["search"],
               let replace = action.parameters["replace"] {
                let fullPath = resolvePath(path)
                if var content = fileSystemService.readFile(at: fullPath) {
                    content = content.replacingOccurrences(of: search, with: replace)
                    fileSystemService.writeFile(content: content, to: fullPath)
                    addExpansionNode(description: "Edited \(path)", depth: currentExpansionDepth, files: [path])
                    return ActionResult(success: true, output: "Edited \(path)", madeChanges: true)
                }
            }
            return ActionResult(success: false, output: "Failed to edit file", madeChanges: false)
            
        case "search_files":
            if let query = action.parameters["query"] {
                // Search would use FileIndexer
                return ActionResult(success: true, output: "Searched for: \(query)", madeChanges: false)
            }
            return ActionResult(success: false, output: "No search query", madeChanges: false)
            
        case "list_directory":
            if let path = action.parameters["path"] {
                let fullPath = resolvePath(path)
                let files = fileSystemService.listDirectory(fullPath)
                return ActionResult(success: true, output: "Listed \(files.count) items in \(path)", madeChanges: false)
            }
            return ActionResult(success: false, output: "No path specified", madeChanges: false)
            
        default:
            return ActionResult(success: false, output: "Unknown tool: \(tool)", madeChanges: false)
        }
    }
    
    private func resolvePath(_ path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        } else if let wd = workingDirectory {
            return wd.appendingPathComponent(path)
        }
        return URL(fileURLWithPath: path)
    }
    
    // MARK: - Expansion Tree
    
    private func addExpansionNode(description: String, depth: Int, files: [String]) {
        guard depth <= maxExpansionDepth else { return }
        
        let node = ExpansionNode(
            description: description,
            depth: depth,
            filesAffected: files
        )
        expansionTree.append(node)
    }
    
    // MARK: - Step Management
    
    private func addStep(phase: ExplorePhase, content: String) {
        let step = ExploreStep(phase: phase, content: content)
        
        Task { @MainActor in
            self.steps.append(step)
        }
    }
    
    // MARK: - Documentation Generation
    
    private func generateDocumentation() async -> GeneratedDoc {
        let context = """
        Generate documentation for the recent changes:
        
        ## Changes Made
        \(expansionTree.suffix(10).map { "- \($0.description)" }.joined(separator: "\n"))
        
        ## Files Affected
        \(Set(expansionTree.suffix(10).flatMap { $0.filesAffected }).joined(separator: ", "))
        
        Create a brief summary document in markdown format.
        """
        
        var content = "# Auto-Generated Documentation\n\n"
        
        do {
            let stream = ollamaService.chat(
                model: .qwen3,
                messages: [("user", context)],
                context: "You are a technical writer. Generate clear, concise documentation.",
                images: []
            )
            
            for try await chunk in stream {
                content += chunk
            }
        } catch {
            content += "Documentation generation failed: \(error.localizedDescription)"
        }
        
        let doc = GeneratedDoc(
            title: "Cycle \(cycleCount) Documentation",
            content: content,
            timestamp: Date(),
            relatedFiles: Set(expansionTree.suffix(10).flatMap { $0.filesAffected }).map { $0 }
        )
        
        generatedDocs.append(doc)
        return doc
    }
}
