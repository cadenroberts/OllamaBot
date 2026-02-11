import Foundation

// MARK: - Agent Executor Coordination Helpers
// Separated from AgentExecutor.swift to maintain ~200 LOC target.

extension AgentExecutor {
    
    func failWith(_ callId: String, tool: String, error: String, context: String) -> ToolResult {
        contextManager.recordError(error, context: context)
        contextManager.recordToolResult(tool, input: context, output: error, success: false)
        return ToolResult(toolCallId: callId, success: false, output: error)
    }
    
    func handleUserInput(call: ToolCall, messages: inout [[String: Any]]) async {
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
    
    func resolveURL(_ path: String) -> URL {
        if path.hasPrefix("/") { return URL(fileURLWithPath: path) }
        else if let workDir = workingDirectory { return workDir.appendingPathComponent(path) }
        else { return URL(fileURLWithPath: path) }
    }
    
    func addStep(_ type: AgentStepType) {
        let step = AgentStep(type: type)
        DispatchQueue.main.async { self.steps.append(step) }
    }
    
    func updateLastToolStep(output: String) {
        guard let lastIndex = steps.lastIndex(where: { if case .tool = $0.type { return true }; return false }) else { return }
        if case .tool(let name, let input, _) = steps[lastIndex].type {
            steps[lastIndex] = AgentStep(type: .tool(name: name, input: input, output: output))
        }
    }
}
