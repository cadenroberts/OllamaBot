import Foundation

// MARK: - Model Tier Manager
// Automatically selects optimal models based on system RAM
// 
// RAM Tiers:
// - 16GB: 8B models (fast, good quality)
// - 24GB: 14B models (better quality, still fast)
// - 32GB: 32B models (best quality, optimal)
// - 64GB+: 32B models with parallel execution

@Observable
final class ModelTierManager {
    
    // MARK: - Model Tiers
    
    enum ModelTier: String, CaseIterable, Comparable {
        case compact = "Compact (8B)"      // 16GB RAM
        case balanced = "Balanced (14B)"   // 24GB RAM
        case performance = "Performance (32B)" // 32GB RAM
        case parallel = "Parallel (32B×4)"    // 64GB+ RAM
        
        var minRAM: Int {
            switch self {
            case .compact: return 16
            case .balanced: return 24
            case .performance: return 32
            case .parallel: return 64
            }
        }
        
        var description: String {
            switch self {
            case .compact:
                return "Optimized for 16GB RAM. Uses 8B models for fast inference with good quality."
            case .balanced:
                return "Optimized for 24GB RAM. Uses 14B models for better quality while staying responsive."
            case .performance:
                return "Optimized for 32GB RAM. Uses full 32B models for best quality."
            case .parallel:
                return "Optimized for 64GB+ RAM. Can run multiple 32B models simultaneously."
            }
        }
        
        static func < (lhs: ModelTier, rhs: ModelTier) -> Bool {
            lhs.minRAM < rhs.minRAM
        }
    }
    
    // MARK: - Model Variants
    
    struct ModelVariant {
        let name: String
        let ollamaTag: String
        let sizeGB: Double
        let parameters: String
        let quality: Int // 1-10
        let speed: Int   // 1-10 (higher = faster)
    }
    
    // All available model variants by role
    static let orchestratorVariants: [ModelTier: ModelVariant] = [
        .compact: ModelVariant(
            name: "Qwen3 8B",
            ollamaTag: "qwen3:8b",
            sizeGB: 5.0,
            parameters: "8B",
            quality: 7,
            speed: 9
        ),
        .balanced: ModelVariant(
            name: "Qwen3 14B",
            ollamaTag: "qwen3:14b",
            sizeGB: 9.0,
            parameters: "14B",
            quality: 8,
            speed: 7
        ),
        .performance: ModelVariant(
            name: "Qwen3 32B",
            ollamaTag: "qwen3:32b",
            sizeGB: 20.0,
            parameters: "32B",
            quality: 10,
            speed: 5
        ),
        .parallel: ModelVariant(
            name: "Qwen3 32B",
            ollamaTag: "qwen3:32b",
            sizeGB: 20.0,
            parameters: "32B",
            quality: 10,
            speed: 5
        )
    ]
    
    static let coderVariants: [ModelTier: ModelVariant] = [
        .compact: ModelVariant(
            name: "Qwen2.5-Coder 7B",
            ollamaTag: "qwen2.5-coder:7b",
            sizeGB: 4.5,
            parameters: "7B",
            quality: 7,
            speed: 9
        ),
        .balanced: ModelVariant(
            name: "Qwen2.5-Coder 14B",
            ollamaTag: "qwen2.5-coder:14b",
            sizeGB: 9.0,
            parameters: "14B",
            quality: 8,
            speed: 7
        ),
        .performance: ModelVariant(
            name: "Qwen2.5-Coder 32B",
            ollamaTag: "qwen2.5-coder:32b",
            sizeGB: 20.0,
            parameters: "32B",
            quality: 10,
            speed: 5
        ),
        .parallel: ModelVariant(
            name: "Qwen2.5-Coder 32B",
            ollamaTag: "qwen2.5-coder:32b",
            sizeGB: 20.0,
            parameters: "32B",
            quality: 10,
            speed: 5
        )
    ]
    
    static let researcherVariants: [ModelTier: ModelVariant] = [
        .compact: ModelVariant(
            name: "Command-R 7B",
            ollamaTag: "command-r:7b",
            sizeGB: 4.5,
            parameters: "7B",
            quality: 7,
            speed: 9
        ),
        .balanced: ModelVariant(
            name: "Command-R 14B",
            ollamaTag: "command-r:14b",
            sizeGB: 9.0,
            parameters: "14B",
            quality: 8,
            speed: 7
        ),
        .performance: ModelVariant(
            name: "Command-R 35B",
            ollamaTag: "command-r:35b",
            sizeGB: 20.0,
            parameters: "35B",
            quality: 10,
            speed: 5
        ),
        .parallel: ModelVariant(
            name: "Command-R 35B",
            ollamaTag: "command-r:35b",
            sizeGB: 20.0,
            parameters: "35B",
            quality: 10,
            speed: 5
        )
    ]
    
    static let visionVariants: [ModelTier: ModelVariant] = [
        .compact: ModelVariant(
            name: "Qwen2-VL 7B",
            ollamaTag: "qwen2-vl:7b",
            sizeGB: 4.5,
            parameters: "7B",
            quality: 7,
            speed: 9
        ),
        .balanced: ModelVariant(
            name: "Qwen2-VL 14B",
            ollamaTag: "qwen2-vl:14b",
            sizeGB: 9.0,
            parameters: "14B",
            quality: 8,
            speed: 7
        ),
        .performance: ModelVariant(
            name: "Qwen3-VL 32B",
            ollamaTag: "qwen3-vl:32b",
            sizeGB: 20.0,
            parameters: "32B",
            quality: 10,
            speed: 5
        ),
        .parallel: ModelVariant(
            name: "Qwen3-VL 32B",
            ollamaTag: "qwen3-vl:32b",
            sizeGB: 20.0,
            parameters: "32B",
            quality: 10,
            speed: 5
        )
    ]
    
    // MARK: - State
    
    let systemRAM: Int
    let recommendedTier: ModelTier
    var selectedTier: ModelTier
    var forceSmallModels: Bool = false
    
    // MARK: - Computed Properties
    
    var orchestrator: ModelVariant {
        Self.orchestratorVariants[effectiveTier]!
    }
    
    var coder: ModelVariant {
        Self.coderVariants[effectiveTier]!
    }
    
    var researcher: ModelVariant {
        Self.researcherVariants[effectiveTier]!
    }
    
    var vision: ModelVariant {
        Self.visionVariants[effectiveTier]!
    }
    
    var effectiveTier: ModelTier {
        forceSmallModels ? .compact : selectedTier
    }
    
    var totalDiskRequired: Double {
        orchestrator.sizeGB + coder.sizeGB + researcher.sizeGB + vision.sizeGB
    }
    
    var maxConcurrentModels: Int {
        switch effectiveTier {
        case .compact: return 2  // Can run 2x 8B models
        case .balanced: return 1 // Single 14B at a time
        case .performance: return 1 // Single 32B at a time
        case .parallel: return 4 // All 32B models if needed
        }
    }
    
    var canRunParallel: Bool {
        effectiveTier == .parallel
    }
    
    // MARK: - Configuration File
    
    struct TierConfig: Codable {
        let tier: String
        let ramGb: Int
        let selectedAt: String
        let models: ModelTags
        
        struct ModelTags: Codable {
            let orchestrator: String
            let researcher: String
            let coder: String
            let vision: String
        }
        
        enum CodingKeys: String, CodingKey {
            case tier
            case ramGb = "ram_gb"
            case selectedAt = "selected_at"
            case models
        }
    }
    
    /// Configured model tags (from setup script)
    var configuredModels: TierConfig.ModelTags?
    
    // MARK: - Initialization
    
    init() {
        let ramBytes = ProcessInfo.processInfo.physicalMemory
        self.systemRAM = Int(ramBytes / 1_073_741_824)
        
        // Determine recommended tier
        if systemRAM >= 64 {
            self.recommendedTier = .parallel
        } else if systemRAM >= 32 {
            self.recommendedTier = .performance
        } else if systemRAM >= 24 {
            self.recommendedTier = .balanced
        } else {
            self.recommendedTier = .compact
        }
        
        // Try to load configuration from setup script
        self.selectedTier = recommendedTier
        loadSavedConfiguration()
        
        print("📊 ModelTierManager initialized")
        print("   System RAM: \(systemRAM)GB")
        print("   Selected tier: \(selectedTier.rawValue)")
        if let models = configuredModels {
            print("   Models: \(models.orchestrator), \(models.coder)")
        }
    }
    
    /// Load configuration saved by setup script
    private func loadSavedConfiguration() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ollamabot/tier.json")
        
        guard FileManager.default.fileExists(atPath: configPath.path),
              let data = try? Data(contentsOf: configPath),
              let config = try? JSONDecoder().decode(TierConfig.self, from: data) else {
            return
        }
        
        // Apply saved tier
        switch config.tier {
        case "compact":
            selectedTier = .compact
        case "balanced":
            selectedTier = .balanced
        case "performance":
            selectedTier = .performance
        default:
            break
        }
        
        configuredModels = config.models
        print("   Loaded configuration from \(configPath.path)")
    }
    
    /// Save current configuration
    func saveConfiguration() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ollamabot")
        
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        
        let config = TierConfig(
            tier: selectedTier.rawValue.lowercased().components(separatedBy: " ").first ?? "performance",
            ramGb: systemRAM,
            selectedAt: ISO8601DateFormatter().string(from: Date()),
            models: TierConfig.ModelTags(
                orchestrator: orchestrator.ollamaTag,
                researcher: researcher.ollamaTag,
                coder: coder.ollamaTag,
                vision: vision.ollamaTag
            )
        )
        
        let configPath = configDir.appendingPathComponent("tier.json")
        try? JSONEncoder().encode(config).write(to: configPath)
    }
    
    // MARK: - Model Selection
    
    /// Get all models to download for the current tier
    func getModelsToDownload() -> [(role: String, variant: ModelVariant)] {
        [
            ("Orchestrator", orchestrator),
            ("Coder", coder),
            ("Researcher", researcher),
            ("Vision", vision)
        ]
    }
    
    /// Get Ollama tags for current tier
    func getOllamaTags() -> [String] {
        [orchestrator.ollamaTag, coder.ollamaTag, researcher.ollamaTag, vision.ollamaTag]
    }
    
    /// Check if all required models are available
    func checkModelsAvailable(installed: [String]) -> [(String, Bool)] {
        getOllamaTags().map { tag in
            (tag, installed.contains(tag))
        }
    }
    
    // MARK: - Memory Optimization Settings
    
    struct MemorySettings {
        let contextWindow: Int
        let maxTokens: Int
        let keepAlive: String
        let numGPU: Int
        let numThread: Int
    }
    
    /// Get optimized memory settings for current tier
    func getMemorySettings() -> MemorySettings {
        switch effectiveTier {
        case .compact:
            return MemorySettings(
                contextWindow: 4096,
                maxTokens: 2048,
                keepAlive: "5m",  // Unload quickly to free RAM
                numGPU: 99,      // Use all GPU layers
                numThread: 8
            )
        case .balanced:
            return MemorySettings(
                contextWindow: 8192,
                maxTokens: 4096,
                keepAlive: "10m",
                numGPU: 99,
                numThread: 8
            )
        case .performance:
            return MemorySettings(
                contextWindow: 16384,
                maxTokens: 8192,
                keepAlive: "30m",
                numGPU: 99,
                numThread: 8
            )
        case .parallel:
            return MemorySettings(
                contextWindow: 32768,
                maxTokens: 16384,
                keepAlive: "60m",
                numGPU: 99,
                numThread: 16
            )
        }
    }
    
    // MARK: - Strategy Recommendations
    
    /// Get recommended execution strategy for cycle agents
    func getRecommendedStrategy() -> String {
        switch effectiveTier {
        case .compact:
            return "specialist" // Minimize switches, batch by agent
        case .balanced:
            return "specialist"
        case .performance:
            return "adaptive"
        case .parallel:
            return "parallel"
        }
    }
    
    /// Get performance expectations
    func getPerformanceExpectations() -> PerformanceExpectations {
        switch effectiveTier {
        case .compact:
            return PerformanceExpectations(
                tokensPerSecond: "25-35",
                modelSwitchTime: "10-15s",
                quality: "Good (suitable for most tasks)",
                recommendation: "Great for quick iterations and everyday coding"
            )
        case .balanced:
            return PerformanceExpectations(
                tokensPerSecond: "15-25",
                modelSwitchTime: "15-20s",
                quality: "Very Good (handles complex tasks well)",
                recommendation: "Good balance of speed and capability"
            )
        case .performance:
            return PerformanceExpectations(
                tokensPerSecond: "8-15",
                modelSwitchTime: "30-60s",
                quality: "Excellent (best reasoning capability)",
                recommendation: "Best for complex, nuanced tasks"
            )
        case .parallel:
            return PerformanceExpectations(
                tokensPerSecond: "8-15 per model",
                modelSwitchTime: "30-60s (but can overlap)",
                quality: "Excellent with parallelism",
                recommendation: "Maximum throughput for heavy workloads"
            )
        }
    }
    
    struct PerformanceExpectations {
        let tokensPerSecond: String
        let modelSwitchTime: String
        let quality: String
        let recommendation: String
    }
}

// MARK: - Tier Comparison View Data

extension ModelTierManager {
    struct TierComparison {
        let tier: ModelTier
        let ram: String
        let models: String
        let quality: Int
        let speed: Int
        let diskSpace: String
        let isRecommended: Bool
        let isAvailable: Bool
    }
    
    func getAllTierComparisons() -> [TierComparison] {
        ModelTier.allCases.map { tier in
            createComparison(for: tier)
        }
    }
    
    private func createComparison(for tier: ModelTier) -> TierComparison {
        let orchestratorVar = Self.orchestratorVariants[tier]!
        
        // Calculate disk space separately to simplify expression
        let orchSize = Self.orchestratorVariants[tier]?.sizeGB ?? 0
        let coderSize = Self.coderVariants[tier]?.sizeGB ?? 0
        let researcherSize = Self.researcherVariants[tier]?.sizeGB ?? 0
        let visionSize = Self.visionVariants[tier]?.sizeGB ?? 0
        let totalDisk = orchSize + coderSize + researcherSize + visionSize
        
        return TierComparison(
            tier: tier,
            ram: "\(tier.minRAM)GB+",
            models: orchestratorVar.parameters,
            quality: orchestratorVar.quality,
            speed: orchestratorVar.speed,
            diskSpace: String(format: "~%.0fGB", totalDisk),
            isRecommended: tier == recommendedTier,
            isAvailable: systemRAM >= tier.minRAM
        )
    }
}
