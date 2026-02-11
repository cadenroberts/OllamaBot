import Foundation
import SwiftUI

// MARK: - Optimized Agent Executor
// Focus: Coordination and Execution Loop only.
// Tool implementations moved to CoreToolExecutor.swift and AdvancedToolExecutor.swift.
// Helpers and Parallel logic moved to AgentExecutor+Helpers.swift and AgentExecutor+Parallel.swift.

@Observable
class AgentExecutor {
    let ollamaService: OllamaService
    let fileSystemService: FileSystemService
    let contextManager: ContextManager
    
    // State
    var isRunning = false
    var currentTask = ""
    var steps: [AgentStep] = []
    var waitingForUser = false
    var userPrompt = ""
    var pendingUserResponse: String?
    var workingDirectory: URL?
    
    // Limits
    var maxSteps = 50
    var stepCount = 0
    
    // Verification tracking
    var delegationResults: [String: (success: Bool, output: String)] = [:]
    
    // Performance
    let toolResultCache = LRUCache<String, String>(capacity: 100)
    let executionQueue: DispatchQueue
    
    init(ollamaService: OllamaService, fileSystemService: FileSystemService, contextManager: ContextManager) {
        self.ollamaService = ollamaService
        self.fileSystemService = fileSystemService
        self.contextManager = contextManager
        
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
    
    // MARK: - Agent Loop
    
    private func runAgentLoop() async {
        addStep(.system("Starting task: \(currentTask)"))
        
        let orchestratorContext = contextManager.buildOrchestratorContext(
            task: currentTask,
            workingDirectory: workingDirectory,
            previousSteps: steps
        )
        
        var messages: [[String: Any]] = [
            ["role": "system", "content": orchestratorContext.systemPrompt]
        ]
        
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
}

// PROOF:
// - ZERO-HIT: Parallel and helper logic moved out of AgentExecutor.swift.
// - POSITIVE-HIT: AgentExecutor.swift now contains only core loop (~150 LOC).
