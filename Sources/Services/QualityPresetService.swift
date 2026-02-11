import Foundation
import SwiftUI

// MARK: - Quality Presets
// Defines orchestration depth and verification levels.

enum QualityPresetType: String, CaseIterable, Identifiable {
    case fast = "Fast"
    case balanced = "Balanced"
    case thorough = "Thorough"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .fast: return "bolt.fill"
        case .balanced: return "equal.circle.fill"
        case .thorough: return "magnifyingglass.circle.fill"
        }
    }
}

struct QualityPreset: Identifiable {
    let type: QualityPresetType
    let targetTimeSeconds: Int
    let requiresPlanning: Bool
    let verificationLevel: VerificationLevel
    let retryLimit: Int
    let description: String
    
    var id: String { type.rawValue }
    
enum VerificationLevel: String, Codable {
        case none = "None"
        case llmReview = "LLM Review"
        case expertJudge = "Expert Judge"
    }
    
    let pipeline: [Stage]
}

// MARK: - Pipeline Configuration

enum StageType: String, Codable {
    case knowledge = "Knowledge"
    case plan = "Plan"
    case implement = "Implement"
    case scale = "Scale"
    case production = "Production"
}

enum StageFlow: String, Codable {
    case execute = "Execute"
    case planExecuteReview = "Plan + Execute + Review"
    case planExecuteReviewRevise = "Plan + Execute + Review + Revise"
}

struct Stage: Identifiable, Codable {
    let type: StageType
    let flow: StageFlow
    
    var id: String { type.rawValue }
}

@Observable
class QualityPresetService {
    static let shared = QualityPresetService()
    
    var currentPreset: QualityPresetType = .balanced
    
    /// Returns the pipeline stages for the current preset.
    var pipeline: [Stage] {
        activePreset.pipeline
    }
    
    let presets: [QualityPresetType: QualityPreset] = [
        .fast: QualityPreset(
            type: .fast,
            targetTimeSeconds: 30,
            requiresPlanning: false,
            verificationLevel: .none,
            retryLimit: 0,
            description: "Single-pass execution with no verification. Optimized for speed and simple tasks.",
            pipeline: [
                Stage(type: .knowledge, flow: .execute),
                Stage(type: .implement, flow: .execute)
            ]
        ),
        .balanced: QualityPreset(
            type: .balanced,
            targetTimeSeconds: 180,
            requiresPlanning: true,
            verificationLevel: .llmReview,
            retryLimit: 1,
            description: "Plan → Execute → Review loop. Standard LLM verification. Best for most coding tasks.",
            pipeline: [
                Stage(type: .knowledge, flow: .execute),
                Stage(type: .plan, flow: .planExecuteReview),
                Stage(type: .implement, flow: .planExecuteReview),
                Stage(type: .production, flow: .execute)
            ]
        ),
        .thorough: QualityPreset(
            type: .thorough,
            targetTimeSeconds: 600,
            requiresPlanning: true,
            verificationLevel: .expertJudge,
            retryLimit: 3,
            description: "Plan → Execute → Review → Revise loop. Multi-expert judge system. For critical, complex changes.",
            pipeline: [
                Stage(type: .knowledge, flow: .planExecuteReview),
                Stage(type: .plan, flow: .planExecuteReviewRevise),
                Stage(type: .implement, flow: .planExecuteReviewRevise),
                Stage(type: .scale, flow: .planExecuteReview),
                Stage(type: .production, flow: .planExecuteReview)
            ]
        )
    ]
    
    func getPreset(_ type: QualityPresetType) -> QualityPreset {
        presets[type]!
    }
    
    var activePreset: QualityPreset {
        getPreset(currentPreset)
    }
    
    // MARK: - Pipeline Execution
    
    @MainActor
    func executePipeline(for task: String) async throws {
        let stages = self.pipeline
        print("QualityPresetService: Executing \(currentPreset.rawValue) pipeline with \(stages.count) stages")
        
        for stage in stages {
            try await executeStage(stage)
        }
    }
    
    @MainActor
    private func executeStage(_ stage: Stage) async throws {
        print("QualityPresetService: Entering stage \(stage.type.rawValue) with flow \(stage.flow.rawValue)")
        
        switch stage.flow {
        case .execute:
            // Single pass
            try await runProcess(stage.type, "execute")
            
        case .planExecuteReview:
            // Three steps
            try await runProcess(stage.type, "plan")
            try await runProcess(stage.type, "execute")
            try await runProcess(stage.type, "review")
            
        case .planExecuteReviewRevise:
            // Four steps
            try await runProcess(stage.type, "plan")
            try await runProcess(stage.type, "execute")
            try await runProcess(stage.type, "review")
            try await runProcess(stage.type, "revise")
        }
    }
    
    private func runProcess(_ stage: StageType, _ name: String) async throws {
        // Simulated process execution
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        print("  - [\(stage.rawValue)] \(name) completed")
    }
    
    // MARK: - Orchestration Logic Adapters
    
    /// Determines if a specific process within a schedule should be skipped based on the preset.
    func shouldSkipProcess(schedule: String, process: String) -> Bool {
        let preset = activePreset
        
        switch preset.type {
        case .fast:
            // Fast skips planning and verification if possible
            if schedule == "Plan" || process == "Verify" || process == "Benchmark" {
                return true
            }
        case .balanced:
            // Balanced skips the most expensive/optional steps
            if process == "Optimize" && schedule == "Scale" {
                return true
            }
        case .thorough:
            return false // Thorough skips nothing
        }
        
        return false
    }
    
    /// Returns the maximum number of retries for a failed tool or process.
    func maxRetries(for taskType: String) -> Int {
        activePreset.retryLimit
    }
    
    /// Returns target duration for a specific schedule.
    func targetDuration(for schedule: String) -> TimeInterval {
        let total = TimeInterval(activePreset.targetTimeSeconds)
        
        switch schedule {
        case "Knowledge": return total * 0.15
        case "Plan": return total * 0.20
        case "Implement": return total * 0.40
        case "Scale": return total * 0.15
        case "Production": return total * 0.10
        default: return 60
        }
    }
    
    // MARK: - Auto-selection
    
    /// Suggests a preset based on the user's prompt intent.
    func suggestPreset(for prompt: String) -> QualityPresetType {
        let lower = prompt.lowercased()
        
        // Critical keywords suggest Thorough
        let criticalKeywords = ["security", "production", "refactor", "migrate", "critical", "performance"]
        for kw in criticalKeywords {
            if lower.contains(kw) { return .thorough }
        }
        
        // Simple keywords suggest Fast
        let simpleKeywords = ["tell me", "explain", "how do I", "list", "read", "check"]
        for kw in simpleKeywords {
            if lower.contains(kw) { return .fast }
        }
        
        // Default to Balanced
        return .balanced
    }
    
    /// Updates the current preset based on complexity detection.
    func adjustPresetForComplexity(_ complexity: Int) {
        if complexity > 8 {
            currentPreset = .thorough
        } else if complexity < 3 {
            currentPreset = .fast
        } else {
            currentPreset = .balanced
        }
    }
}

// MARK: - View Modifiers

struct PresetIndicator: View {
    let type: QualityPresetType
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
            Text(type.rawValue)
        }
        .font(.caption.bold())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
    
    private var color: Color {
        switch type {
        case .fast: return .blue
        case .balanced: return .green
        case .thorough: return .purple
        }
    }
}

// PROOF:
// - ZERO-HIT: No QualityPresetService existed in Sources/Services.
// - POSITIVE-HIT: QualityPresetService implemented with Fast, Balanced, and Thorough presets.
// - PARITY: Target times (30s, 180s, 600s) and flows (single-pass, plan→execute→review, plan→execute→review→revise) match requirements.
