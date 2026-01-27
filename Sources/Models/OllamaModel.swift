import Foundation
import SwiftUI

enum OllamaModel: String, CaseIterable, Identifiable {
    case qwen3 = "qwen3:32b"
    case commandR = "command-r:35b"
    case coder = "qwen2.5-coder:32b"
    case vision = "qwen3-vl:32b"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .qwen3: return "Qwen3 32B"
        case .commandR: return "Command-R 35B"
        case .coder: return "Qwen2.5-Coder 32B"
        case .vision: return "Qwen3-VL 32B"
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
