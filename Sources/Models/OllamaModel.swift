import Foundation
import SwiftUI

// MARK: - Model Role (constant, represents the capability)
enum OllamaModel: String, CaseIterable, Identifiable {
    case qwen3       // Orchestrator role
    case commandR    // Researcher role
    case coder       // Coder role
    case vision      // Vision role
    
    var id: String { rawValue }
    
    // MARK: - Dynamic Model Tag
    // The actual Ollama model tag is determined by the selected tier
    
    /// Default model tags (32B tier) - used when no tier config exists
    var defaultTag: String {
        switch self {
        case .qwen3: return "qwen3:32b"
        case .commandR: return "command-r:35b"
        case .coder: return "qwen2.5-coder:32b"
        case .vision: return "qwen3-vl:32b"
        }
    }
    
    /// Get the actual model tag for the current tier
    func tag(for tier: ModelTierManager?) -> String {
        guard let tierManager = tier else { return defaultTag }
        
        switch self {
        case .qwen3: return tierManager.orchestrator.ollamaTag
        case .commandR: return tierManager.researcher.ollamaTag
        case .coder: return tierManager.coder.ollamaTag
        case .vision: return tierManager.vision.ollamaTag
        }
    }
    
    /// For backwards compatibility - uses default tags
    var rawValue: String { defaultTag }
    
    // MARK: - Display Properties
    
    var displayName: String {
        switch self {
        case .qwen3: return "Orchestrator"
        case .commandR: return "Researcher"
        case .coder: return "Coder"
        case .vision: return "Vision"
        }
    }
    
    /// Display name with tier info
    func displayName(for tier: ModelTierManager?) -> String {
        guard let tierManager = tier else { return displayName }
        
        switch self {
        case .qwen3: return tierManager.orchestrator.name
        case .commandR: return tierManager.researcher.name
        case .coder: return tierManager.coder.name
        case .vision: return tierManager.vision.name
        }
    }
    
    var purpose: String {
        switch self {
        case .qwen3: return "Writing, reasoning & orchestration"
        case .commandR: return "Research, RAG & information retrieval"
        case .coder: return "Code generation & editing"
        case .vision: return "Image analysis & vision tasks"
        }
    }
    
    var icon: String {
        switch self {
        case .qwen3: return "pencil.and.outline"
        case .commandR: return "magnifyingglass.circle"
        case .coder: return "chevron.left.forwardslash.chevron.right"
        case .vision: return "eye"
        }
    }
    
    var color: SwiftUI.Color {
        switch self {
        case .qwen3: return DS.Colors.orchestrator
        case .commandR: return DS.Colors.researcher
        case .coder: return DS.Colors.coder
        case .vision: return DS.Colors.vision
        }
    }
    
    var shortcut: KeyEquivalent {
        switch self {
        case .qwen3: return "1"
        case .commandR: return "2"
        case .coder: return "3"
        case .vision: return "4"
        }
    }
    
    /// Capabilities this model excels at
    var capabilities: [String] {
        switch self {
        case .qwen3:
            return ["Writing", "Reasoning", "Planning", "Summarization", "General tasks"]
        case .commandR:
            return ["Research", "RAG", "Document analysis", "Q&A", "Citations"]
        case .coder:
            return ["Code generation", "Debugging", "Refactoring", "Code review", "Documentation"]
        case .vision:
            return ["Image analysis", "UI inspection", "Screenshot reading", "Visual reasoning"]
        }
    }
    
    /// Keywords that indicate this model should be selected
    var triggerKeywords: [String] {
        switch self {
        case .qwen3:
            return ["write", "draft", "compose", "think", "plan", "explain", "summarize", "describe"]
        case .commandR:
            return ["search", "find", "research", "document", "cite", "source", "reference", "look up"]
        case .coder:
            return ["code", "function", "class", "implement", "fix", "bug", "refactor", "debug", "programming"]
        case .vision:
            return ["image", "picture", "screenshot", "ui", "visual", "look at", "see", "analyze image"]
        }
    }
}
