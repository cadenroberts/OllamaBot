import Foundation
import SwiftUI

// MARK: - Agent Step

struct AgentStep: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let type: AgentStepType
}

enum AgentStepType {
    case system(String)
    case thinking(String)
    case tool(name: String, input: String, output: String)
    case userInput(String)
    case error(String)
    case complete(String)
    
    var icon: String {
        switch self {
        case .system: return "info.circle"
        case .thinking: return "brain"
        case .tool: return "wrench"
        case .userInput: return "person.fill.questionmark"
        case .error: return "exclamationmark.triangle"
        case .complete: return "checkmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .system: return DS.Colors.secondaryText
        case .thinking: return DS.Colors.orchestrator
        case .tool: return DS.Colors.coder
        case .userInput: return DS.Colors.warning
        case .error: return DS.Colors.error
        case .complete: return DS.Colors.success
        }
    }
}
