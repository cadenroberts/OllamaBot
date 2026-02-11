import Foundation

// MARK: - Cost Tracking Service
/// Manages token usage and cost calculation, comparing local execution with cloud models.
///
/// PROOF:
/// - ZERO-HIT: No existing service for granular cost comparison and session-based tracking.
/// - POSITIVE-HIT: CostTrackingService with session persistence, Claude/GPT-4 comparison, and feature-based breakdown in Sources/Services/CostTrackingService.swift.
@Observable
final class CostTrackingService {
    
    /// Represents cost data for a single orchestration or chat session.
    struct SessionCost: Codable, Identifiable {
        let id: UUID
        let sessionID: String
        let timestamp: Date
        var inputTokens: Int64
        var outputTokens: Int64
        var localModel: String
        var cloudEquivalentModel: String // e.g. "claude-3-5-sonnet"
        
        var totalTokens: Int64 { inputTokens + outputTokens }
        
        /// Estimated cloud cost if this was run on a cloud provider (e.g. Anthropic, OpenAI).
        var cloudEstimatedCost: Double
        
        /// Local cost (defaults to $0.0 as it's locally hosted).
        var localCost: Double = 0.0
        
        /// Savings achieved by running locally.
        var savings: Double { cloudEstimatedCost - localCost }
        
        /// Feature category for breakdown (e.g. "Orchestration", "Inline Fix", "Research").
        var feature: String = "General"
    }
    
    // MARK: - State
    
    private(set) var sessions: [SessionCost] = []
    private(set) var totalSavings: Double = 0.0
    private(set) var totalTokens: Int64 = 0
    
    private let storageURL: URL
    
    // MARK: - Initialization
    
    init() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ollamabot")
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        
        storageURL = configDir.appendingPathComponent("costs.json")
        loadCosts()
    }
    
    // MARK: - Public Methods
    
    /// Records a usage event and calculates potential cloud costs.
    func trackUsage(
        sessionID: String,
        input: Int64,
        output: Int64,
        localModel: String,
        cloudEquivalent: String = "claude-3-5-sonnet",
        feature: String = "Orchestration"
    ) {
        let cloudCost = calculateCloudCost(input: input, output: output, model: cloudEquivalent)
        
        let session = SessionCost(
            id: UUID(),
            sessionID: sessionID,
            timestamp: Date(),
            inputTokens: input,
            outputTokens: output,
            localModel: localModel,
            cloudEquivalentModel: cloudEquivalent,
            cloudEstimatedCost: cloudCost,
            feature: feature
        )
        
        sessions.append(session)
        updateAggregates()
        saveCosts()
    }
    
    /// Returns the total savings for a specific feature.
    func savings(forFeature feature: String) -> Double {
        sessions.filter { $0.feature == feature }.reduce(0) { $0 + $1.savings }
    }
    
    /// Returns monthly savings breakdown.
    func monthlySavings() -> [String: Double] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        
        var breakdown: [String: Double] = [:]
        for session in sessions {
            let month = formatter.string(from: session.timestamp)
            breakdown[month, default: 0] += session.savings
        }
        return breakdown
    }
    
    /// Clears all tracking history.
    func clearHistory() {
        sessions = []
        totalSavings = 0
        totalTokens = 0
        saveCosts()
    }
    
    // MARK: - Private Helpers
    
    private func updateAggregates() {
        totalSavings = sessions.reduce(0) { $0 + $1.savings }
        totalTokens = sessions.reduce(0) { $0 + $1.totalTokens }
    }
    
    private func calculateCloudCost(input: Int64, output: Int64, model: String) -> Double {
        // Current market rates (simplified)
        let rates: [String: (input: Double, output: Double)] = [
            "claude-3-5-sonnet": (3.0, 15.0),   // $3/$15 per 1M tokens
            "gpt-4o": (5.0, 15.0),             // $5/$15 per 1M tokens
            "claude-3-opus": (15.0, 75.0),     // $15/$75 per 1M tokens
            "gpt-4-turbo": (10.0, 30.0)        // $10/$30 per 1M tokens
        ]
        
        let rate = rates[model.lowercased()] ?? rates["claude-3-5-sonnet"]!
        
        let inputCost = (Double(input) / 1_000_000.0) * rate.input
        let outputCost = (Double(output) / 1_000_000.0) * rate.output
        
        return inputCost + outputCost
    }
    
    private func saveCosts() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: storageURL)
        } catch {
            print("CostTrackingService: Failed to save costs: \(error)")
        }
    }
    
    private func loadCosts() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: storageURL)
            sessions = try JSONDecoder().decode([SessionCost].self, from: data)
            updateAggregates()
        } catch {
            print("CostTrackingService: Failed to load costs: \(error)")
        }
    }
}
