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
        case minimal = "Minimal (1.5B)"       // 8GB RAM - EMERGENCY ONLY
        case compact = "Compact (7B)"         // 16GB RAM
        case balanced = "Balanced (14B)"      // 24GB RAM
        case performance = "Performance (32B)" // 32GB RAM
        case advanced = "Advanced (70B)"      // 64GB RAM
        case maximum = "Maximum (70B+)"       // 128GB RAM
        
        var minRAM: Int {
            switch self {
            case .minimal: return 8
            case .compact: return 16
            case .balanced: return 24
            case .performance: return 32
            case .advanced: return 64
            case .maximum: return 128
            }
        }
        
        var description: String {
            switch self {
            case .minimal:
                return "⚠️ EMERGENCY ONLY: 1.5B models with severely limited capability."
            case .compact:
                return "Limited: 7B models. Functional for simpler tasks."
            case .balanced:
                return "Good: 14B models for better quality while staying responsive."
            case .performance:
                return "Recommended: Full 32B models for excellent quality."
            case .advanced:
                return "Professional: 70B models for state-of-the-art capability."
            case .maximum:
                return "Ultimate: Multiple 70B models + largest available."
            }
        }
        
        var isRecommended: Bool {
            self == .performance || self == .advanced || self == .maximum
        }
        
        var warningLevel: WarningLevel {
            switch self {
            case .minimal: return .critical
            case .compact: return .warning
            case .balanced: return .caution
            case .performance, .advanced, .maximum: return .none
            }
        }
        
        enum WarningLevel {
            case none
            case caution
            case warning
            case critical
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
    // RESEARCHED: These models actually fit and run well at each RAM tier
    static let orchestratorVariants: [ModelTier: ModelVariant] = [
        .minimal: ModelVariant(
            name: "Qwen2.5 1.5B",
            ollamaTag: "qwen2.5:1.5b",
            sizeGB: 1.0,
            parameters: "1.5B",
            quality: 4,  // Limited but functional
            speed: 10
        ),
        .compact: ModelVariant(
            name: "Qwen2.5 7B",
            ollamaTag: "qwen2.5:7b",
            sizeGB: 5.0,
            parameters: "7B",
            quality: 7,
            speed: 8
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
            quality: 8,
            speed: 5
        ),
        .advanced: ModelVariant(
            name: "Llama 3.1 70B",
            ollamaTag: "llama3.1:70b",
            sizeGB: 40.0,  // VERIFIED from ollama.com
            parameters: "70B",
            quality: 10,
            speed: 3
        ),
        .maximum: ModelVariant(
            name: "Qwen2.5 72B",
            ollamaTag: "qwen2.5:72b",
            sizeGB: 42.0,  // VERIFIED from ollama.com
            parameters: "72B",
            quality: 10,
            speed: 3
        )
    ]
    
    static let coderVariants: [ModelTier: ModelVariant] = [
        .minimal: ModelVariant(
            name: "DeepSeek-Coder 1.3B",
            ollamaTag: "deepseek-coder:1.3b",
            sizeGB: 1.0,
            parameters: "1.3B",
            quality: 5,  // Surprisingly capable for its size!
            speed: 10
        ),
        .compact: ModelVariant(
            name: "DeepSeek-Coder 6.7B",
            ollamaTag: "deepseek-coder:6.7b",
            sizeGB: 4.0,
            parameters: "6.7B",
            quality: 8,  // Excellent small coder
            speed: 8
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
            quality: 9,
            speed: 5
        ),
        .advanced: ModelVariant(
            name: "DeepSeek-Coder 33B",
            ollamaTag: "deepseek-coder:33b",
            sizeGB: 20.0,  // VERIFIED from ollama.com
            parameters: "33B",
            quality: 10,
            speed: 4
        ),
        .maximum: ModelVariant(
            name: "DeepSeek-Coder 33B",
            ollamaTag: "deepseek-coder:33b",
            sizeGB: 20.0,  // VERIFIED - best coding model available
            parameters: "33B",
            quality: 10,
            speed: 4
        )
    ]
    
    static let researcherVariants: [ModelTier: ModelVariant] = [
        .minimal: ModelVariant(
            name: "Phi-3 Mini",
            ollamaTag: "phi3:mini",
            sizeGB: 2.0,
            parameters: "3.8B",
            quality: 5,  // Good reasoning for size (Microsoft's efficient model)
            speed: 9
        ),
        .compact: ModelVariant(
            name: "Mistral 7B",
            ollamaTag: "mistral:7b",
            sizeGB: 4.0,
            parameters: "7B",
            quality: 7,  // Strong reasoning
            speed: 8
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
            quality: 8,
            speed: 5
        ),
        .advanced: ModelVariant(
            name: "Command-R 35B",
            ollamaTag: "command-r:35b",
            sizeGB: 19.0,  // VERIFIED from ollama.com
            parameters: "35B",
            quality: 9,  // Great for research/RAG
            speed: 4
        ),
        .maximum: ModelVariant(
            name: "Command-R Plus 104B",
            ollamaTag: "command-r-plus:104b",
            sizeGB: 59.0,  // VERIFIED from ollama.com
            parameters: "104B",
            quality: 10,  // Cohere's flagship
            speed: 2
        )
    ]
    
    static let visionVariants: [ModelTier: ModelVariant] = [
        .minimal: ModelVariant(
            name: "Moondream 1.8B",
            ollamaTag: "moondream:1.8b",
            sizeGB: 1.0,
            parameters: "1.8B",
            quality: 5,  // Best tiny vision model
            speed: 10
        ),
        .compact: ModelVariant(
            name: "LLaVA 7B",
            ollamaTag: "llava:7b",
            sizeGB: 5.0,
            parameters: "7B",
            quality: 6,
            speed: 8
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
            quality: 9,
            speed: 5
        ),
        .advanced: ModelVariant(
            name: "Llama 3.2 Vision 11B",
            ollamaTag: "llama3.2-vision:11b",
            sizeGB: 8.0,   // VERIFIED from ollama.com
            parameters: "11B",
            quality: 8,
            speed: 6
        ),
        .maximum: ModelVariant(
            name: "Llama 3.2 Vision 90B",
            ollamaTag: "llama3.2-vision:90b",
            sizeGB: 55.0,  // VERIFIED from ollama.com - BEST VISION MODEL
            parameters: "90B",
            quality: 10,
            speed: 2
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
    
    /// Get the tier-specific variant for a base model
    func getVariant(for model: OllamaModel) -> ModelVariant {
        switch model {
        case .qwen3: return orchestrator
        case .coder: return coder
        case .commandR: return researcher
        case .vision: return vision
        }
    }
    
    var effectiveTier: ModelTier {
        forceSmallModels ? .compact : selectedTier
    }
    
    var totalDiskRequired: Double {
        orchestrator.sizeGB + coder.sizeGB + researcher.sizeGB + vision.sizeGB
    }
    
    var maxConcurrentModels: Int {
        switch effectiveTier {
        case .minimal: return 1    // Single 1.5B model only
        case .compact: return 2    // Can run 2x 7B models
        case .balanced: return 1   // Single 14B at a time
        case .performance: return 1 // Single 32B at a time
        case .advanced: return 2   // Can run 2x 32B or 1x 70B
        case .maximum: return 4    // Multiple 70B models
        }
    }
    
    var canRunParallel: Bool {
        effectiveTier == .advanced || effectiveTier == .maximum
    }
    
    // MARK: - Configuration File
    
    struct TierConfig: Codable {
        let tier: String
        let ramGb: Int
        let selectedAt: String
        let models: ModelTags
        let enabled: EnabledModels?
        
        struct ModelTags: Codable {
            let orchestrator: String?
            let researcher: String?
            let coder: String?
            let vision: String?
        }
        
        struct EnabledModels: Codable {
            let orchestrator: Bool
            let researcher: Bool
            let coder: Bool
            let vision: Bool
        }
        
        enum CodingKeys: String, CodingKey {
            case tier
            case ramGb = "ram_gb"
            case selectedAt = "selected_at"
            case models
            case enabled
        }
    }
    
    /// Configured model tags (from setup script)
    var configuredModels: TierConfig.ModelTags?
    
    /// Which models are enabled (installed)
    var enabledModels: TierConfig.EnabledModels?
    
    /// Check if a specific model role is available
    func isModelEnabled(_ model: OllamaModel) -> Bool {
        guard let enabled = enabledModels else { return true } // Default to all enabled
        
        switch model {
        case .qwen3: return enabled.orchestrator
        case .commandR: return enabled.researcher
        case .coder: return enabled.coder
        case .vision: return enabled.vision
        }
    }
    
    /// Get list of available (enabled) models
    var availableModels: [OllamaModel] {
        OllamaModel.allCases.filter { isModelEnabled($0) }
    }
    
    // MARK: - Initialization
    
    init() {
        let ramBytes = ProcessInfo.processInfo.physicalMemory
        self.systemRAM = Int(ramBytes / 1_073_741_824)
        
        // Determine recommended tier based on RAM
        if systemRAM >= 128 {
            self.recommendedTier = .maximum
        } else if systemRAM >= 64 {
            self.recommendedTier = .advanced
        } else if systemRAM >= 32 {
            self.recommendedTier = .performance
        } else if systemRAM >= 24 {
            self.recommendedTier = .balanced
        } else if systemRAM >= 16 {
            self.recommendedTier = .compact
        } else {
            self.recommendedTier = .minimal
            print("⚠️ WARNING: System has only \(systemRAM)GB RAM")
            print("   OllamaBot requires 32GB+ for optimal performance")
            print("   Running in MINIMAL mode with severely limited capability")
        }
        
        // Try to load configuration from setup script
        self.selectedTier = recommendedTier
        loadSavedConfiguration()
        
        print("📊 ModelTierManager initialized")
        print("   System RAM: \(systemRAM)GB")
        print("   Selected tier: \(selectedTier.rawValue)")
        if let models = configuredModels {
            print("   Models: \(models.orchestrator ?? "none"), \(models.coder ?? "none")")
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
        case "minimal":
            selectedTier = .minimal
        case "compact":
            selectedTier = .compact
        case "balanced":
            selectedTier = .balanced
        case "performance":
            selectedTier = .performance
        case "advanced":
            selectedTier = .advanced
        case "maximum":
            selectedTier = .maximum
        default:
            break
        }
        
        configuredModels = config.models
        enabledModels = config.enabled
        
        print("   Loaded configuration from \(configPath.path)")
        
        // Log enabled models
        if let enabled = enabledModels {
            var enabledList: [String] = []
            if enabled.orchestrator { enabledList.append("Orchestrator") }
            if enabled.researcher { enabledList.append("Researcher") }
            if enabled.coder { enabledList.append("Coder") }
            if enabled.vision { enabledList.append("Vision") }
            print("   Enabled models: \(enabledList.joined(separator: ", "))")
        }
    }
    
    /// Save current configuration
    func saveConfiguration() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ollamabot")
        
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        
        // Use existing enabled state or default to all enabled
        let enabled = enabledModels ?? TierConfig.EnabledModels(
            orchestrator: true,
            researcher: true,
            coder: true,
            vision: true
        )
        
        let config = TierConfig(
            tier: selectedTier.rawValue.lowercased().components(separatedBy: " ").first ?? "performance",
            ramGb: systemRAM,
            selectedAt: ISO8601DateFormatter().string(from: Date()),
            models: TierConfig.ModelTags(
                orchestrator: enabled.orchestrator ? orchestrator.ollamaTag : nil,
                researcher: enabled.researcher ? researcher.ollamaTag : nil,
                coder: enabled.coder ? coder.ollamaTag : nil,
                vision: enabled.vision ? vision.ollamaTag : nil
            ),
            enabled: enabled
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
        case .minimal:
            return MemorySettings(
                contextWindow: 2048,  // Very small context
                maxTokens: 1024,
                keepAlive: "2m",  // Unload very quickly
                numGPU: 99,
                numThread: 4
            )
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
        case .advanced:
            return MemorySettings(
                contextWindow: 32768,
                maxTokens: 16384,
                keepAlive: "60m",  // Keep 70B models warm
                numGPU: 99,
                numThread: 12
            )
        case .maximum:
            return MemorySettings(
                contextWindow: 65536,  // Maximum context for largest models
                maxTokens: 32768,
                keepAlive: "120m",  // Keep models warm for extended sessions
                numGPU: 99,
                numThread: 16
            )
        }
    }
    
    // MARK: - Strategy Recommendations
    
    /// Get recommended execution strategy for cycle agents
    func getRecommendedStrategy() -> String {
        switch effectiveTier {
        case .minimal:
            return "specialist" // Single model only, no orchestration
        case .compact:
            return "specialist" // Minimize switches, batch by agent
        case .balanced:
            return "specialist"
        case .performance:
            return "adaptive"
        case .advanced:
            return "parallel"   // Can run multiple models
        case .maximum:
            return "parallel"   // Full parallel capability
        }
    }
    
    /// Get performance expectations
    func getPerformanceExpectations() -> PerformanceExpectations {
        switch effectiveTier {
        case .minimal:
            return PerformanceExpectations(
                tokensPerSecond: "40-60",
                modelSwitchTime: "3-5s",
                quality: "⚠️ SEVERELY LIMITED - Not for production use",
                recommendation: "Testing/demo only. Upgrade to 32GB+ Mac for real development."
            )
        case .compact:
            return PerformanceExpectations(
                tokensPerSecond: "25-40",
                modelSwitchTime: "8-12s",
                quality: "Limited (suitable for simpler tasks)",
                recommendation: "Consider upgrading for better capability"
            )
        case .balanced:
            return PerformanceExpectations(
                tokensPerSecond: "15-25",
                modelSwitchTime: "15-20s",
                quality: "Good (handles most tasks well)",
                recommendation: "Good balance of speed and capability"
            )
        case .performance:
            return PerformanceExpectations(
                tokensPerSecond: "8-15",
                modelSwitchTime: "30-60s",
                quality: "Excellent (professional-grade)",
                recommendation: "Recommended for serious development work"
            )
        case .advanced:
            return PerformanceExpectations(
                tokensPerSecond: "5-10",
                modelSwitchTime: "60-90s",
                quality: "State-of-the-art (70B models)",
                recommendation: "Professional-grade for complex tasks"
            )
        case .maximum:
            return PerformanceExpectations(
                tokensPerSecond: "3-8 (but parallel)",
                modelSwitchTime: "60-120s (but can overlap)",
                quality: "Ultimate (largest models + parallel)",
                recommendation: "Maximum capability for demanding workloads"
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
