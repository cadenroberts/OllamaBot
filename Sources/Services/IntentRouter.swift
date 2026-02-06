import Foundation

class IntentRouter {
    
    /// Routes a user message to the most appropriate model based on intent analysis
    func routeIntent(
        message: String,
        hasImages: Bool = false,
        hasCodeContext: Bool = false
    ) -> OllamaModel {
        // Vision model for images
        if hasImages {
            return .vision
        }
        
        let lowercasedMessage = message.lowercased()
        
        // Check for explicit model triggers
        for model in OllamaModel.allCases {
            for keyword in model.triggerKeywords {
                if lowercasedMessage.contains(keyword) {
                    // Special handling for code context
                    if model == .coder || (hasCodeContext && isCodeRelated(lowercasedMessage)) {
                        return .coder
                    }
                    return model
                }
            }
        }
        
        // Intent classification based on patterns
        if isCodeRelated(lowercasedMessage) {
            return .coder
        }
        
        if isResearchRelated(lowercasedMessage) {
            return .commandR
        }
        
        if isWritingRelated(lowercasedMessage) {
            return .qwen3
        }
        
        // Default to writing model for general tasks
        return .qwen3
    }
    
    /// Explains why a particular model was chosen
    func explainRouting(message: String, hasImages: Bool, hasCodeContext: Bool, selectedModel: OllamaModel) -> String {
        if hasImages {
            return "Vision model selected because images were attached"
        }
        
        let lowercasedMessage = message.lowercased()
        
        // Check which keywords matched
        for keyword in selectedModel.triggerKeywords {
            if lowercasedMessage.contains(keyword) {
                return "\(selectedModel.displayName) selected because '\(keyword)' was detected in your message"
            }
        }
        
        switch selectedModel {
        case .coder:
            return "Coder model selected based on code-related context"
        case .commandR:
            return "Research model selected for information retrieval"
        case .qwen3:
            return "Writing model selected for general reasoning and composition"
        case .vision:
            return "Vision model selected for image analysis"
        }
    }
    
    // MARK: - Private Helpers
    
    private func isCodeRelated(_ message: String) -> Bool {
        let codeIndicators = [
            "function", "class", "struct", "enum", "protocol",
            "implement", "code", "bug", "error", "fix", "refactor",
            "variable", "method", "api", "endpoint", "database",
            "syntax", "compile", "build", "debug", "test", "unit test",
            "import", "module", "package", "dependency",
            "swift", "python", "javascript", "typescript", "rust", "go",
            "algorithm", "data structure", "loop", "array", "dictionary",
            "async", "await", "promise", "callback", "closure"
        ]
        
        return codeIndicators.contains { message.contains($0) }
    }
    
    private func isResearchRelated(_ message: String) -> Bool {
        let researchIndicators = [
            "what is", "who is", "when did", "where is", "how does",
            "explain", "define", "describe", "tell me about",
            "search", "find", "look up", "research", "information",
            "source", "reference", "cite", "document", "article",
            "history", "background", "context", "overview",
            "compare", "difference between", "pros and cons",
            "best practices", "recommendations", "alternatives"
        ]
        
        return researchIndicators.contains { message.contains($0) }
    }
    
    private func isWritingRelated(_ message: String) -> Bool {
        let writingIndicators = [
            "write", "draft", "compose", "create", "generate",
            "email", "letter", "message", "blog", "article",
            "story", "poem", "essay", "report", "summary",
            "translate", "rewrite", "paraphrase", "edit",
            "tone", "style", "format", "structure",
            "creative", "professional", "casual", "formal"
        ]
        
        return writingIndicators.contains { message.contains($0) }
    }
}
