import Foundation

// MARK: - Agent Executor Parallel Execution
// Separated from AgentExecutor.swift to maintain ~200 LOC target.

extension AgentExecutor {
    
    private static let parallelizableTools: Set<String> = ["read_file", "list_directory", "search_files", "think"]
    
    func executeToolsParallel(_ calls: [ToolCall]) async -> [ToolResult] {
        guard calls.count > 1 else {
            if let call = calls.first { return [await executeTool(call)] }
            return []
        }
        
        var results: [ToolResult] = []
        var parallelGroup: [ToolCall] = []
        
        for call in calls {
            if Self.parallelizableTools.contains(call.name) {
                parallelGroup.append(call)
            } else {
                if !parallelGroup.isEmpty {
                    results.append(contentsOf: await executeParallelGroup(parallelGroup))
                    parallelGroup.removeAll(keepingCapacity: true)
                }
                results.append(await executeTool(call))
            }
        }
        
        if !parallelGroup.isEmpty {
            results.append(contentsOf: await executeParallelGroup(parallelGroup))
        }
        
        return results
    }
    
    private func executeParallelGroup(_ group: [ToolCall]) async -> [ToolResult] {
        if group.count <= 2 {
            var groupResults: [ToolResult] = []
            for call in group { groupResults.append(await self.executeTool(call)) }
            return groupResults
        }
        
        return await withTaskGroup(of: (Int, ToolResult).self, returning: [ToolResult].self) { taskGroup in
            for (idx, call) in group.enumerated() {
                taskGroup.addTask { [self] in (idx, await self.executeTool(call)) }
            }
            var collected: [(Int, ToolResult)] = []
            for await result in taskGroup { collected.append(result) }
            return collected.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
}
