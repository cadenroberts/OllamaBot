import Foundation
import QuartzCore

// MARK: - Performance Tracking Service
// Comprehensive metrics tracking for OllamaBot benchmarks and cost savings

@Observable
final class PerformanceTrackingService {
    
    // MARK: - Cost Constants (per 1K tokens)
    
    struct APICosts {
        // GPT-4 Turbo pricing (as of 2024)
        static let gpt4Input: Double = 0.01      // $0.01 per 1K input tokens
        static let gpt4Output: Double = 0.03    // $0.03 per 1K output tokens
        
        // Claude 3 Opus pricing
        static let claude3Input: Double = 0.015  // $0.015 per 1K input tokens
        static let claude3Output: Double = 0.075 // $0.075 per 1K output tokens
        
        // Claude 3.5 Sonnet pricing
        static let claudeSonnetInput: Double = 0.003
        static let claudeSonnetOutput: Double = 0.015
        
        // GPT-4o pricing
        static let gpt4oInput: Double = 0.005
        static let gpt4oOutput: Double = 0.015
    }
    
    // MARK: - Data Structures
    
    struct InferenceMetrics: Identifiable, Codable {
        let id: UUID
        let model: String
        let startTime: Date
        let endTime: Date
        let timeToFirstToken: TimeInterval     // TTFT
        let totalTokens: Int
        let inputTokens: Int
        let outputTokens: Int
        let tokensPerSecond: Double            // TPS
        let wasWarmStart: Bool                 // Was model already in memory?
        
        var totalTime: TimeInterval {
            endTime.timeIntervalSince(startTime)
        }
    }
    
    struct ModelSwitchMetrics: Identifiable, Codable {
        let id: UUID
        let fromModel: String?
        let toModel: String
        let switchTime: TimeInterval
        let timestamp: Date
        let wasColdLoad: Bool
    }
    
    struct SessionStats: Codable {
        var startTime: Date
        var totalInputTokens: Int = 0
        var totalOutputTokens: Int = 0
        var totalInferences: Int = 0
        var totalModelSwitches: Int = 0
        var totalSwitchTime: TimeInterval = 0
        var fileOperations: Int = 0
        var tasksCompleted: Int = 0
        
        var totalTokens: Int {
            totalInputTokens + totalOutputTokens
        }
        
        var sessionDuration: TimeInterval {
            Date().timeIntervalSince(startTime)
        }
        
        // Cost savings calculations
        func gpt4CostSavings() -> Double {
            let inputCost = Double(totalInputTokens) / 1000.0 * APICosts.gpt4Input
            let outputCost = Double(totalOutputTokens) / 1000.0 * APICosts.gpt4Output
            return inputCost + outputCost
        }
        
        func claude3CostSavings() -> Double {
            let inputCost = Double(totalInputTokens) / 1000.0 * APICosts.claude3Input
            let outputCost = Double(totalOutputTokens) / 1000.0 * APICosts.claude3Output
            return inputCost + outputCost
        }
        
        func gpt4oCostSavings() -> Double {
            let inputCost = Double(totalInputTokens) / 1000.0 * APICosts.gpt4oInput
            let outputCost = Double(totalOutputTokens) / 1000.0 * APICosts.gpt4oOutput
            return inputCost + outputCost
        }
        
        func claudeSonnetCostSavings() -> Double {
            let inputCost = Double(totalInputTokens) / 1000.0 * APICosts.claudeSonnetInput
            let outputCost = Double(totalOutputTokens) / 1000.0 * APICosts.claudeSonnetOutput
            return inputCost + outputCost
        }
    }
    
    struct PerModelStats: Codable {
        var model: String
        var totalInferences: Int = 0
        var totalTokens: Int = 0
        var totalTime: TimeInterval = 0
        var ttftSum: TimeInterval = 0
        var warmStarts: Int = 0
        var coldStarts: Int = 0
        
        var averageTPS: Double {
            guard totalTime > 0 else { return 0 }
            return Double(totalTokens) / totalTime
        }
        
        var averageTTFT: Double {
            guard totalInferences > 0 else { return 0 }
            return ttftSum / Double(totalInferences)
        }
        
        var cacheHitRate: Double {
            let total = warmStarts + coldStarts
            guard total > 0 else { return 0 }
            return Double(warmStarts) / Double(total) * 100
        }
    }
    
    // MARK: - Stored State
    
    private(set) var sessionStats: SessionStats
    private(set) var modelStats: [String: PerModelStats] = [:]
    private(set) var recentInferences: [InferenceMetrics] = []
    private(set) var recentSwitches: [ModelSwitchMetrics] = []
    
    // Live tracking state
    private var currentInferenceStart: Date?
    private var currentInferenceModel: String?
    private var currentFirstTokenTime: Date?
    private var currentTokenCount: Int = 0
    private var currentInputTokens: Int = 0
    private var lastActiveModel: String?
    
    // Memory usage tracking
    private(set) var currentMemoryUsageGB: Double = 0
    private(set) var peakMemoryUsageGB: Double = 0
    
    // MARK: - Persistence
    
    private let statsFileURL: URL
    private let maxRecentInferences = 100
    private let maxRecentSwitches = 50
    
    init() {
        // Initialize session
        sessionStats = SessionStats(startTime: Date())
        
        // Setup persistence
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let ollamaBotDir = appSupport.appendingPathComponent("OllamaBot", isDirectory: true)
        try? FileManager.default.createDirectory(at: ollamaBotDir, withIntermediateDirectories: true)
        statsFileURL = ollamaBotDir.appendingPathComponent("performance_stats.json")
        
        // Load historical stats
        loadStats()
        
        // Start memory monitoring
        startMemoryMonitoring()
        
        print("📊 PerformanceTrackingService initialized")
    }
    
    // MARK: - Inference Tracking API
    
    /// Call when starting an inference request
    func startInference(model: String, inputTokenEstimate: Int) {
        currentInferenceStart = Date()
        currentInferenceModel = model
        currentFirstTokenTime = nil
        currentTokenCount = 0
        currentInputTokens = inputTokenEstimate
        
        // Track if this is a warm or cold start
        if lastActiveModel != model {
            // Model switch occurred
            let switchMetrics = ModelSwitchMetrics(
                id: UUID(),
                fromModel: lastActiveModel,
                toModel: model,
                switchTime: 0, // Will be updated when first token arrives
                timestamp: Date(),
                wasColdLoad: lastActiveModel != nil
            )
            recordModelSwitch(switchMetrics)
        }
    }
    
    /// Call when first token is received
    func recordFirstToken() {
        currentFirstTokenTime = Date()
    }
    
    /// Call to increment token count during streaming
    func incrementTokens(_ count: Int = 1) {
        currentTokenCount += count
    }
    
    /// Call when inference completes
    func endInference() {
        guard let start = currentInferenceStart,
              let model = currentInferenceModel else { return }
        
        let end = Date()
        let ttft = currentFirstTokenTime?.timeIntervalSince(start) ?? 0
        let totalTime = end.timeIntervalSince(start)
        let tps = totalTime > 0 ? Double(currentTokenCount) / totalTime : 0
        
        let metrics = InferenceMetrics(
            id: UUID(),
            model: model,
            startTime: start,
            endTime: end,
            timeToFirstToken: ttft,
            totalTokens: currentTokenCount,
            inputTokens: currentInputTokens,
            outputTokens: currentTokenCount,
            tokensPerSecond: tps,
            wasWarmStart: lastActiveModel == model
        )
        
        recordInference(metrics)
        
        // Update last active model
        lastActiveModel = model
        
        // Reset tracking state
        currentInferenceStart = nil
        currentInferenceModel = nil
        currentFirstTokenTime = nil
        currentTokenCount = 0
        currentInputTokens = 0
    }
    
    // MARK: - Recording Methods
    
    private func recordInference(_ metrics: InferenceMetrics) {
        // Update session stats
        sessionStats.totalInputTokens += metrics.inputTokens
        sessionStats.totalOutputTokens += metrics.outputTokens
        sessionStats.totalInferences += 1
        
        // Update per-model stats
        var stats = modelStats[metrics.model] ?? PerModelStats(model: metrics.model)
        stats.totalInferences += 1
        stats.totalTokens += metrics.totalTokens
        stats.totalTime += metrics.totalTime
        stats.ttftSum += metrics.timeToFirstToken
        if metrics.wasWarmStart {
            stats.warmStarts += 1
        } else {
            stats.coldStarts += 1
        }
        modelStats[metrics.model] = stats
        
        // Keep recent inferences
        recentInferences.append(metrics)
        if recentInferences.count > maxRecentInferences {
            recentInferences.removeFirst()
        }
        
        // Auto-save periodically
        if sessionStats.totalInferences % 10 == 0 {
            saveStats()
        }
        
        // Log
        print("📊 Inference: \(metrics.model) - \(metrics.totalTokens) tokens @ \(String(format: "%.1f", metrics.tokensPerSecond)) tok/s, TTFT: \(String(format: "%.2f", metrics.timeToFirstToken))s")
    }
    
    private func recordModelSwitch(_ metrics: ModelSwitchMetrics) {
        sessionStats.totalModelSwitches += 1
        sessionStats.totalSwitchTime += metrics.switchTime
        
        recentSwitches.append(metrics)
        if recentSwitches.count > maxRecentSwitches {
            recentSwitches.removeFirst()
        }
    }
    
    /// Record a file operation
    func recordFileOperation() {
        sessionStats.fileOperations += 1
    }
    
    /// Record a completed task
    func recordTaskCompleted() {
        sessionStats.tasksCompleted += 1
    }
    
    // MARK: - Computed Metrics
    
    /// Average tokens per second across all models
    var averageTPS: Double {
        guard !modelStats.isEmpty else { return 0 }
        let totalTokens = modelStats.values.reduce(0) { $0 + $1.totalTokens }
        let totalTime = modelStats.values.reduce(0.0) { $0 + $1.totalTime }
        return totalTime > 0 ? Double(totalTokens) / totalTime : 0
    }
    
    /// Average time to first token
    var averageTTFT: Double {
        guard !modelStats.isEmpty else { return 0 }
        let totalTTFT = modelStats.values.reduce(0.0) { $0 + $1.ttftSum }
        let totalInferences = modelStats.values.reduce(0) { $0 + $1.totalInferences }
        return totalInferences > 0 ? totalTTFT / Double(totalInferences) : 0
    }
    
    /// Overall cache hit rate
    var cacheHitRate: Double {
        guard !modelStats.isEmpty else { return 0 }
        let totalWarm = modelStats.values.reduce(0) { $0 + $1.warmStarts }
        let totalCold = modelStats.values.reduce(0) { $0 + $1.coldStarts }
        let total = totalWarm + totalCold
        return total > 0 ? Double(totalWarm) / Double(total) * 100 : 0
    }
    
    /// Average model switch time
    var averageSwitchTime: Double {
        guard sessionStats.totalModelSwitches > 0 else { return 0 }
        return sessionStats.totalSwitchTime / Double(sessionStats.totalModelSwitches)
    }
    
    /// Best performing model (highest TPS)
    var bestPerformingModel: (name: String, tps: Double)? {
        guard let best = modelStats.values.max(by: { $0.averageTPS < $1.averageTPS }),
              best.averageTPS > 0 else { return nil }
        return (best.model, best.averageTPS)
    }
    
    /// Get sorted model performance
    func getModelPerformanceRanking() -> [(model: String, tps: Double, ttft: Double, inferences: Int)] {
        modelStats.values
            .sorted { $0.averageTPS > $1.averageTPS }
            .map { ($0.model, $0.averageTPS, $0.averageTTFT, $0.totalInferences) }
    }
    
    // MARK: - Cost Savings Summary
    
    struct CostSavingsSummary {
        let totalTokens: Int
        let inputTokens: Int
        let outputTokens: Int
        let gpt4Savings: Double
        let gpt4oSavings: Double
        let claude3Savings: Double
        let claudeSonnetSavings: Double
        let monthlyProjection: Double  // Based on current usage rate
        let dataKeptLocal: Int         // Bytes (always equal to total chars * 4 roughly)
    }
    
    func getCostSavingsSummary() -> CostSavingsSummary {
        let duration = sessionStats.sessionDuration
        let dailyRate = duration > 0 ? Double(sessionStats.totalTokens) / (duration / 86400) : 0
        let monthlyTokenProjection = dailyRate * 30
        let monthlyGPT4Projection = (monthlyTokenProjection / 1000.0) * (APICosts.gpt4Input + APICosts.gpt4Output) / 2
        
        return CostSavingsSummary(
            totalTokens: sessionStats.totalTokens,
            inputTokens: sessionStats.totalInputTokens,
            outputTokens: sessionStats.totalOutputTokens,
            gpt4Savings: sessionStats.gpt4CostSavings(),
            gpt4oSavings: sessionStats.gpt4oCostSavings(),
            claude3Savings: sessionStats.claude3CostSavings(),
            claudeSonnetSavings: sessionStats.claudeSonnetCostSavings(),
            monthlyProjection: monthlyGPT4Projection,
            dataKeptLocal: sessionStats.totalTokens * 4  // ~4 bytes per token
        )
    }
    
    // MARK: - Memory Monitoring
    
    private func startMemoryMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
        updateMemoryUsage()
    }
    
    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedGB = Double(info.resident_size) / 1_073_741_824  // Bytes to GB
            currentMemoryUsageGB = usedGB
            peakMemoryUsageGB = max(peakMemoryUsageGB, usedGB)
        }
    }
    
    // MARK: - Persistence
    
    private struct SavedStats: Codable {
        var sessionStats: SessionStats
        var modelStats: [String: PerModelStats]
        var lifetimeTokens: Int
        var lifetimeSavings: Double
    }
    
    private func saveStats() {
        let saved = SavedStats(
            sessionStats: sessionStats,
            modelStats: modelStats,
            lifetimeTokens: sessionStats.totalTokens,
            lifetimeSavings: sessionStats.gpt4CostSavings()
        )
        
        if let data = try? JSONEncoder().encode(saved) {
            try? data.write(to: statsFileURL)
        }
    }
    
    private func loadStats() {
        guard let data = try? Data(contentsOf: statsFileURL),
              let saved = try? JSONDecoder().decode(SavedStats.self, from: data) else {
            return
        }
        
        // We start a new session but can load historical model stats
        // modelStats = saved.modelStats
        print("📊 Loaded historical stats: \(saved.lifetimeTokens) lifetime tokens")
    }
    
    /// Reset session (but keep historical)
    func resetSession() {
        sessionStats = SessionStats(startTime: Date())
        recentInferences.removeAll()
        recentSwitches.removeAll()
        // Keep modelStats for historical comparison
    }
    
    /// Full reset
    func resetAll() {
        sessionStats = SessionStats(startTime: Date())
        modelStats.removeAll()
        recentInferences.removeAll()
        recentSwitches.removeAll()
        try? FileManager.default.removeItem(at: statsFileURL)
    }
}

// MARK: - Token Estimation Helpers

extension PerformanceTrackingService {
    /// Estimate tokens from character count (rough approximation)
    /// English text: ~4 chars per token, Code: ~3 chars per token
    static func estimateTokens(from text: String, isCode: Bool = false) -> Int {
        let charsPerToken = isCode ? 3.0 : 4.0
        return Int(ceil(Double(text.count) / charsPerToken))
    }
    
    /// Estimate tokens from messages array
    static func estimateTokens(from messages: [(String, String)]) -> Int {
        messages.reduce(0) { total, message in
            total + estimateTokens(from: message.0) + estimateTokens(from: message.1)
        }
    }
}

// MARK: - Formatted Output Helpers

extension PerformanceTrackingService {
    /// Format duration as human readable
    static func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else if seconds < 3600 {
            let mins = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(mins)m \(secs)s"
        } else {
            let hours = Int(seconds / 3600)
            let mins = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(mins)m"
        }
    }
    
    /// Format currency
    static func formatCurrency(_ amount: Double) -> String {
        String(format: "$%.2f", amount)
    }
    
    /// Format large numbers
    static func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    /// Format bytes
    static func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1_048_576 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else if bytes < 1_073_741_824 {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576)
        } else {
            return String(format: "%.2f GB", Double(bytes) / 1_073_741_824)
        }
    }
}
