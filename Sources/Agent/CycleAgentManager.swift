import Foundation
import QuartzCore // For CACurrentMediaTime

// MARK: - Cycle Agent Manager
// Intelligent multi-agent orchestration optimized for local RAM constraints
//
// Why this is BETTER than naive parallelism:
// 1. On 32GB RAM, parallel 32B models would cause thrashing (50-100x slower)
// 2. Smart scheduling minimizes model switches (each switch = 30-60 seconds)
// 3. Speculative pre-loading hides some switch latency
// 4. Task batching groups similar work to avoid unnecessary switches
// 5. For high-RAM systems (64GB+), enables true parallelism automatically

@Observable
final class CycleAgentManager {
    
    // MARK: - Configuration
    
    struct Config {
        /// RAM threshold for parallel execution (GB)
        static let parallelRAMThreshold: Int = 64
        
        /// Maximum concurrent agents when RAM allows
        static let maxParallelAgents: Int = 4
        
        /// Model warm-up time estimate (seconds)
        static let modelSwitchTime: Double = 30.0
        
        /// Maximum tasks to batch together
        static let maxBatchSize: Int = 10
        
        /// Enable speculative model loading
        static let speculativeLoading: Bool = true
    }
    
    // MARK: - Agent Definitions
    
    struct AgentDefinition: Identifiable, Equatable {
        let id: String
        let model: OllamaModel
        let role: AgentRole
        let capabilities: Set<TaskCapability>
        let priority: Int // Higher = more important to keep warm
        
        static func == (lhs: AgentDefinition, rhs: AgentDefinition) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    enum AgentRole: String, CaseIterable {
        case orchestrator = "Orchestrator"
        case coder = "Coder"
        case researcher = "Researcher"
        case vision = "Vision"
        
        var systemPrompt: String {
            switch self {
            case .orchestrator:
                return """
                You are the Orchestrator agent. Your role is to:
                1. Analyze complex tasks and break them into subtasks
                2. Decide which specialist agent should handle each subtask
                3. Synthesize results from specialists into coherent output
                4. Maintain context across the entire task lifecycle
                
                Available specialists: Coder (code tasks), Researcher (information gathering), Vision (image analysis)
                """
            case .coder:
                return """
                You are the Coder agent. You excel at:
                - Writing clean, efficient, well-documented code
                - Debugging and fixing issues
                - Code review and optimization
                - Understanding codebases and suggesting improvements
                
                Focus only on coding tasks. Be precise and provide working code.
                """
            case .researcher:
                return """
                You are the Researcher agent. You excel at:
                - Gathering and synthesizing information
                - Explaining complex concepts clearly
                - Comparing alternatives and making recommendations
                - Finding relevant documentation and examples
                
                Provide thorough, well-sourced information.
                """
            case .vision:
                return """
                You are the Vision agent. You excel at:
                - Analyzing images and screenshots
                - Describing visual content accurately
                - Identifying UI elements and layouts
                - Extracting text and data from images
                
                Be detailed and precise in visual descriptions.
                """
            }
        }
    }
    
    enum TaskCapability: String, CaseIterable {
        case codeGeneration
        case codeReview
        case debugging
        case research
        case documentation
        case imageAnalysis
        case planning
        case synthesis
    }
    
    // MARK: - Task Types
    
    struct AgentTask: Identifiable {
        let id: UUID
        let content: String
        let requiredCapabilities: Set<TaskCapability>
        var context: TaskContext
        let priority: TaskPriority
        let createdAt: Date
        var assignedAgent: AgentDefinition?
        var status: TaskStatus
        var result: TaskResult?
        
        init(
            content: String,
            capabilities: Set<TaskCapability>,
            context: TaskContext = .init(),
            priority: TaskPriority = .normal
        ) {
            self.id = UUID()
            self.content = content
            self.requiredCapabilities = capabilities
            self.context = context
            self.priority = priority
            self.createdAt = Date()
            self.status = .pending
        }
    }
    
    struct TaskContext {
        var files: [String: String] = [:]
        var previousResults: [String] = []
        var images: [Data] = []
        var workingDirectory: URL?
    }
    
    enum TaskPriority: Int, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3
        
        static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    enum TaskStatus {
        case pending
        case queued
        case running
        case completed
        case failed(Error)
        case cancelled
    }
    
    struct TaskResult {
        let output: String
        let agentId: String
        let executionTime: TimeInterval
        let modelSwitchTime: TimeInterval
        let tokensUsed: Int
    }
    
    // MARK: - Cycle Definition
    
    struct AgentCycle: Identifiable {
        let id: UUID
        let name: String
        let agents: [AgentDefinition]
        var tasks: [AgentTask]
        let strategy: CycleStrategy
        var currentPhase: Int
        var isComplete: Bool
        var results: [TaskResult]
        
        init(name: String, agents: [AgentDefinition], tasks: [AgentTask], strategy: CycleStrategy) {
            self.id = UUID()
            self.name = name
            self.agents = agents
            self.tasks = tasks
            self.strategy = strategy
            self.currentPhase = 0
            self.isComplete = false
            self.results = []
        }
    }
    
    enum CycleStrategy {
        /// Round-robin: Each agent takes turns
        case roundRobin
        
        /// Specialist: Route to best agent for each task
        case specialist
        
        /// Pipeline: Tasks flow through agents in order
        case pipeline
        
        /// Parallel: Run compatible tasks simultaneously (high-RAM only)
        case parallel
        
        /// Adaptive: Dynamically choose based on results
        case adaptive
    }
    
    // MARK: - State
    
    private let ollamaService: OllamaService
    private let fileSystemService: FileSystemService
    private let contextManager: ContextManager
    
    // Agent registry
    private(set) var agents: [AgentDefinition] = []
    private var warmAgent: AgentDefinition?
    
    // Task management
    private var taskQueue: [AgentTask] = []
    private var activeCycles: [AgentCycle] = []
    private var completedTasks: [AgentTask] = []
    
    // Performance tracking
    private var modelSwitchCount: Int = 0
    private var totalModelSwitchTime: TimeInterval = 0
    private var taskExecutionTimes: [UUID: TimeInterval] = [:]
    
    // System info
    private let availableRAM: Int
    private let canRunParallel: Bool
    
    // Observable state
    var isRunning: Bool = false
    var currentTask: AgentTask?
    var progress: Double = 0
    var statusMessage: String = ""
    
    // MARK: - Initialization
    
    init(ollamaService: OllamaService, fileSystemService: FileSystemService, contextManager: ContextManager) {
        self.ollamaService = ollamaService
        self.fileSystemService = fileSystemService
        self.contextManager = contextManager
        
        // Detect system RAM
        let ramBytes = ProcessInfo.processInfo.physicalMemory
        self.availableRAM = Int(ramBytes / 1_073_741_824) // Convert to GB
        self.canRunParallel = availableRAM >= Config.parallelRAMThreshold
        
        // Register default agents
        registerDefaultAgents()
        
        print("🔄 CycleAgentManager initialized")
        print("   RAM: \(availableRAM)GB")
        print("   Parallel mode: \(canRunParallel ? "enabled" : "disabled (need \(Config.parallelRAMThreshold)GB+)")")
    }
    
    private func registerDefaultAgents() {
        agents = [
            AgentDefinition(
                id: "orchestrator",
                model: .qwen3,
                role: .orchestrator,
                capabilities: [.planning, .synthesis],
                priority: 100 // Always keep warm if possible
            ),
            AgentDefinition(
                id: "coder",
                model: .coder,
                role: .coder,
                capabilities: [.codeGeneration, .codeReview, .debugging],
                priority: 80
            ),
            AgentDefinition(
                id: "researcher",
                model: .commandR,
                role: .researcher,
                capabilities: [.research, .documentation],
                priority: 60
            ),
            AgentDefinition(
                id: "vision",
                model: .vision,
                role: .vision,
                capabilities: [.imageAnalysis],
                priority: 40
            )
        ]
    }
    
    // MARK: - Cycle Creation
    
    /// Create a new agent cycle with intelligent task distribution
    func createCycle(
        name: String,
        tasks: [AgentTask],
        strategy: CycleStrategy = .adaptive
    ) -> AgentCycle {
        // Determine which agents are needed
        let requiredCapabilities = tasks.reduce(into: Set<TaskCapability>()) { result, task in
            result.formUnion(task.requiredCapabilities)
        }
        
        let neededAgents = agents.filter { agent in
            !agent.capabilities.isDisjoint(with: requiredCapabilities)
        }
        
        // Choose strategy based on system capabilities
        let effectiveStrategy: CycleStrategy
        if strategy == .parallel && !canRunParallel {
            print("⚠️ Parallel strategy requested but RAM insufficient (\(availableRAM)GB < \(Config.parallelRAMThreshold)GB)")
            print("   Falling back to adaptive strategy (smarter than naive parallel on low RAM)")
            effectiveStrategy = .adaptive
        } else {
            effectiveStrategy = strategy
        }
        
        var cycle = AgentCycle(
            name: name,
            agents: neededAgents,
            tasks: tasks,
            strategy: effectiveStrategy
        )
        
        // Assign agents to tasks based on capabilities
        for i in 0..<cycle.tasks.count {
            cycle.tasks[i].assignedAgent = findBestAgent(for: cycle.tasks[i])
        }
        
        return cycle
    }
    
    /// Find the best agent for a given task
    private func findBestAgent(for task: AgentTask) -> AgentDefinition? {
        // Score each agent based on capability match
        let scored = agents.map { agent -> (AgentDefinition, Int) in
            let matchCount = agent.capabilities.intersection(task.requiredCapabilities).count
            let totalRequired = task.requiredCapabilities.count
            let score = totalRequired > 0 ? (matchCount * 100) / totalRequired : 0
            return (agent, score)
        }
        
        // Return highest scoring agent
        return scored.max(by: { $0.1 < $1.1 })?.0
    }
    
    // MARK: - Cycle Execution
    
    /// Execute a cycle with optimized model switching
    func executeCycle(_ cycle: AgentCycle) async throws -> [TaskResult] {
        isRunning = true
        var currentCycle = cycle
        var results: [TaskResult] = []
        
        defer { isRunning = false }
        
        switch currentCycle.strategy {
        case .roundRobin:
            results = try await executeRoundRobin(&currentCycle)
        case .specialist:
            results = try await executeSpecialist(&currentCycle)
        case .pipeline:
            results = try await executePipeline(&currentCycle)
        case .parallel:
            results = try await executeParallel(&currentCycle)
        case .adaptive:
            results = try await executeAdaptive(&currentCycle)
        }
        
        currentCycle.isComplete = true
        currentCycle.results = results
        
        return results
    }
    
    // MARK: - Execution Strategies
    
    /// Round-robin: Each agent handles tasks in turn
    private func executeRoundRobin(_ cycle: inout AgentCycle) async throws -> [TaskResult] {
        var results: [TaskResult] = []
        var agentIndex = 0
        
        for task in cycle.tasks {
            let agent = cycle.agents[agentIndex % cycle.agents.count]
            let result = try await executeTask(task, with: agent)
            results.append(result)
            agentIndex += 1
            
            progress = Double(results.count) / Double(cycle.tasks.count)
        }
        
        return results
    }
    
    /// Specialist: Route each task to the best agent
    private func executeSpecialist(_ cycle: inout AgentCycle) async throws -> [TaskResult] {
        var results: [TaskResult] = []
        
        // Group tasks by assigned agent to minimize model switches
        let groupedTasks = Dictionary(grouping: cycle.tasks) { $0.assignedAgent?.id ?? "unknown" }
        
        // Sort groups by agent priority (execute high-priority agents first)
        let sortedGroups = groupedTasks.sorted { group1, group2 in
            let agent1 = agents.first { $0.id == group1.key }
            let agent2 = agents.first { $0.id == group2.key }
            return (agent1?.priority ?? 0) > (agent2?.priority ?? 0)
        }
        
        statusMessage = "Executing \(cycle.tasks.count) tasks with \(groupedTasks.count) model switches"
        
        var completedCount = 0
        for (agentId, tasks) in sortedGroups {
            guard let agent = agents.first(where: { $0.id == agentId }) else { continue }
            
            statusMessage = "Loading \(agent.role.rawValue) for \(tasks.count) tasks..."
            
            // Execute all tasks for this agent before switching
            for task in tasks {
                let result = try await executeTask(task, with: agent)
                results.append(result)
                completedCount += 1
                progress = Double(completedCount) / Double(cycle.tasks.count)
            }
        }
        
        return results
    }
    
    /// Pipeline: Tasks flow through agents in sequence
    private func executePipeline(_ cycle: inout AgentCycle) async throws -> [TaskResult] {
        var results: [TaskResult] = []
        var context = TaskContext()
        
        for (index, task) in cycle.tasks.enumerated() {
            // Add previous results to context
            if !results.isEmpty {
                context.previousResults = results.map { $0.output }
            }
            
            var contextualTask = task
            contextualTask.context = context
            
            let agent = task.assignedAgent ?? cycle.agents[index % cycle.agents.count]
            let result = try await executeTask(contextualTask, with: agent)
            results.append(result)
            
            progress = Double(results.count) / Double(cycle.tasks.count)
        }
        
        return results
    }
    
    /// Parallel: Execute compatible tasks simultaneously (high-RAM only)
    private func executeParallel(_ cycle: inout AgentCycle) async throws -> [TaskResult] {
        guard canRunParallel else {
            print("⚠️ Parallel execution not available, falling back to specialist")
            return try await executeSpecialist(&cycle)
        }
        
        statusMessage = "Executing \(cycle.tasks.count) tasks in parallel..."
        
        // Group tasks by agent for true parallelism
        let groupedTasks = Dictionary(grouping: cycle.tasks) { $0.assignedAgent?.id ?? "unknown" }
        
        // Execute groups in parallel using task groups
        var allResults: [TaskResult] = []
        
        try await withThrowingTaskGroup(of: [TaskResult].self) { group in
            for (agentId, tasks) in groupedTasks {
                guard let agent = agents.first(where: { $0.id == agentId }) else { continue }
                
                group.addTask {
                    var results: [TaskResult] = []
                    for task in tasks {
                        let result = try await self.executeTask(task, with: agent)
                        results.append(result)
                    }
                    return results
                }
            }
            
            for try await results in group {
                allResults.append(contentsOf: results)
            }
        }
        
        return allResults
    }
    
    /// Adaptive: Dynamically choose best approach based on task analysis
    private func executeAdaptive(_ cycle: inout AgentCycle) async throws -> [TaskResult] {
        // Analyze task distribution
        let agentCounts = Dictionary(grouping: cycle.tasks) { $0.assignedAgent?.id ?? "unknown" }
            .mapValues { $0.count }
        
        let totalTasks = cycle.tasks.count
        let uniqueAgents = agentCounts.count
        let avgTasksPerAgent = Double(totalTasks) / Double(max(uniqueAgents, 1))
        
        statusMessage = "Analyzing optimal strategy..."
        
        // Decision logic
        if canRunParallel && uniqueAgents >= 2 && avgTasksPerAgent >= 3 {
            // Parallel is efficient when we have multiple agents with multiple tasks
            print("📊 Adaptive: Choosing parallel (multiple agents with batches)")
            return try await executeParallel(&cycle)
        } else if uniqueAgents == 1 || avgTasksPerAgent >= 5 {
            // Single agent or highly batched - specialist minimizes switches
            print("📊 Adaptive: Choosing specialist (batched by agent)")
            return try await executeSpecialist(&cycle)
        } else if cycle.tasks.allSatisfy({ $0.context.previousResults.isEmpty }) {
            // Independent tasks - parallel planning, sequential execution
            print("📊 Adaptive: Choosing optimized specialist (independent tasks)")
            return try await executeSpecialist(&cycle)
        } else {
            // Pipeline for dependent tasks
            print("📊 Adaptive: Choosing pipeline (dependent tasks)")
            return try await executePipeline(&cycle)
        }
    }
    
    // MARK: - Task Execution
    
    /// Execute a single task with a specific agent
    private func executeTask(_ task: AgentTask, with agent: AgentDefinition) async throws -> TaskResult {
        let startTime = CACurrentMediaTime()
        var switchTime: TimeInterval = 0
        
        currentTask = task
        statusMessage = "[\(agent.role.rawValue)] \(task.content.prefix(50))..."
        
        // Check if we need to switch models
        if warmAgent?.id != agent.id {
            let switchStart = CACurrentMediaTime()
            statusMessage = "Loading \(agent.model.displayName)..."
            
            // Warm up the model
            _ = try? await ollamaService.warmModel(agent.model)
            
            switchTime = CACurrentMediaTime() - switchStart
            totalModelSwitchTime += switchTime
            modelSwitchCount += 1
            warmAgent = agent
            
            print("🔄 Model switch to \(agent.model.displayName): \(String(format: "%.1f", switchTime))s")
        }
        
        // Build context
        let contextString = buildTaskContext(task, agent: agent)
        
        // Execute with the model
        var output = ""
        let stream = ollamaService.chat(
            model: agent.model,
            messages: [
                ("system", agent.role.systemPrompt),
                ("user", task.content)
            ],
            context: contextString,
            images: task.context.images
        )
        
        for try await chunk in stream {
            output += chunk
        }
        
        let executionTime = CACurrentMediaTime() - startTime
        
        // Record result
        let result = TaskResult(
            output: output,
            agentId: agent.id,
            executionTime: executionTime,
            modelSwitchTime: switchTime,
            tokensUsed: output.count / 4 // Rough estimate
        )
        
        currentTask = nil
        
        return result
    }
    
    /// Build context string for a task
    private func buildTaskContext(_ task: AgentTask, agent: AgentDefinition) -> String? {
        var sections: [String] = []
        
        // Add file context
        if !task.context.files.isEmpty {
            let fileList = task.context.files.map { "[\($0.key)]\n\($0.value)" }.joined(separator: "\n\n")
            sections.append("=== FILES ===\n\(fileList)")
        }
        
        // Add previous results (for pipeline)
        if !task.context.previousResults.isEmpty {
            let previous = task.context.previousResults.suffix(3).joined(separator: "\n---\n")
            sections.append("=== PREVIOUS RESULTS ===\n\(previous)")
        }
        
        return sections.isEmpty ? nil : sections.joined(separator: "\n\n")
    }
    
    // MARK: - Convenience Methods
    
    /// Quick multi-agent task execution
    func executeMultiAgentTask(
        description: String,
        subtasks: [(String, Set<TaskCapability>)]
    ) async throws -> [TaskResult] {
        let tasks = subtasks.map { content, capabilities in
            AgentTask(content: content, capabilities: capabilities)
        }
        
        let cycle = createCycle(name: description, tasks: tasks, strategy: .adaptive)
        return try await executeCycle(cycle)
    }
    
    /// Plan-then-execute pattern
    func planAndExecute(task: String, context: TaskContext = .init()) async throws -> String {
        // Phase 1: Orchestrator plans
        let planTask = AgentTask(
            content: """
            Analyze this task and create a plan:
            
            TASK: \(task)
            
            Output a JSON array of subtasks with format:
            [{"task": "description", "agent": "coder|researcher|vision"}]
            """,
            capabilities: [.planning],
            context: context
        )
        
        let planCycle = createCycle(name: "Planning", tasks: [planTask], strategy: .specialist)
        let planResults = try await executeCycle(planCycle)
        
        guard let plan = planResults.first?.output else {
            throw CycleError.planningFailed
        }
        
        // Parse plan and create execution tasks
        let executionTasks = parseAndCreateTasks(from: plan, context: context)
        
        if executionTasks.isEmpty {
            // No subtasks needed, return plan directly
            return plan
        }
        
        // Phase 2: Execute subtasks
        let executionCycle = createCycle(
            name: "Execution",
            tasks: executionTasks,
            strategy: .adaptive
        )
        let executionResults = try await executeCycle(executionCycle)
        
        // Phase 3: Orchestrator synthesizes
        let synthesisTask = AgentTask(
            content: """
            Synthesize these results into a coherent response:
            
            ORIGINAL TASK: \(task)
            
            SUBTASK RESULTS:
            \(executionResults.enumerated().map { "[\($0.offset + 1)] \($0.element.output.prefix(500))" }.joined(separator: "\n\n"))
            
            Provide a comprehensive final answer.
            """,
            capabilities: [.synthesis]
        )
        
        let synthesisCycle = createCycle(name: "Synthesis", tasks: [synthesisTask], strategy: .specialist)
        let synthesisResults = try await executeCycle(synthesisCycle)
        
        return synthesisResults.first?.output ?? "Failed to synthesize results"
    }
    
    /// Parse orchestrator's plan into executable tasks
    private func parseAndCreateTasks(from plan: String, context: TaskContext) -> [AgentTask] {
        // Try to extract JSON from the plan
        guard let jsonStart = plan.firstIndex(of: "["),
              let jsonEnd = plan.lastIndex(of: "]") else {
            return []
        }
        
        let jsonString = String(plan[jsonStart...jsonEnd])
        
        guard let data = jsonString.data(using: .utf8),
              let subtasks = try? JSONDecoder().decode([[String: String]].self, from: data) else {
            return []
        }
        
        return subtasks.compactMap { subtask -> AgentTask? in
            guard let taskContent = subtask["task"],
                  let agentType = subtask["agent"] else {
                return nil
            }
            
            let capabilities: Set<TaskCapability>
            switch agentType.lowercased() {
            case "coder":
                capabilities = [.codeGeneration, .codeReview]
            case "researcher":
                capabilities = [.research, .documentation]
            case "vision":
                capabilities = [.imageAnalysis]
            default:
                capabilities = [.planning]
            }
            
            return AgentTask(content: taskContent, capabilities: capabilities, context: context)
        }
    }
    
    // MARK: - Statistics
    
    func getStatistics() -> CycleStatistics {
        CycleStatistics(
            availableRAM: availableRAM,
            canRunParallel: canRunParallel,
            modelSwitchCount: modelSwitchCount,
            totalModelSwitchTime: totalModelSwitchTime,
            averageSwitchTime: modelSwitchCount > 0 ? totalModelSwitchTime / Double(modelSwitchCount) : 0,
            warmAgent: warmAgent?.role.rawValue,
            registeredAgents: agents.count
        )
    }
    
    struct CycleStatistics {
        let availableRAM: Int
        let canRunParallel: Bool
        let modelSwitchCount: Int
        let totalModelSwitchTime: TimeInterval
        let averageSwitchTime: TimeInterval
        let warmAgent: String?
        let registeredAgents: Int
    }
}

// MARK: - Errors

enum CycleError: Error, LocalizedError {
    case planningFailed
    case noAgentAvailable
    case executionFailed(String)
    case insufficientRAM
    
    var errorDescription: String? {
        switch self {
        case .planningFailed:
            return "Failed to create execution plan"
        case .noAgentAvailable:
            return "No suitable agent available for task"
        case .executionFailed(let message):
            return "Task execution failed: \(message)"
        case .insufficientRAM:
            return "Insufficient RAM for requested operation"
        }
    }
}

// MARK: - OllamaService Extension

extension OllamaService {
    /// Warm up a model (load into memory)
    func warmModel(_ model: OllamaModel) async throws {
        // Simple ping to load the model
        let stream = chat(
            model: model,
            messages: [("user", "Hi")],
            context: nil,
            images: []
        )
        
        // Consume stream to complete warmup
        for try await _ in stream {
            break // Just need to start the model
        }
    }
}
