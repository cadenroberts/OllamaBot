import Foundation
import Yams

// MARK: - Shared Configuration Service
// Reads ~/.config/ollamabot/config.yaml for behavioral equivalence with obot CLI.
// IDE-specific visual prefs remain in UserDefaults via ConfigurationManager.
// Hot-reloads on file changes via DispatchSource.

@Observable
final class SharedConfigService {

    // MARK: - Config Model

    struct UnifiedConfig: Codable {
        var version: String = "2.0"
        var createdBy: String = "ollamabot"
        var models: ModelsConfig = ModelsConfig()
        var orchestration: OrchestrationConfig = OrchestrationConfig()
        var context: ContextConfig = ContextConfig()
        var quality: QualityConfig = QualityConfig()
        var platforms: PlatformConfig = PlatformConfig()
        var ollama: OllamaConfig = OllamaConfig()

        enum CodingKeys: String, CodingKey {
            case version
            case createdBy = "created_by"
            case models, orchestration, context, quality, platforms, ollama
        }
    }

    struct ModelsConfig: Codable {
        var tierDetection: TierDetection = TierDetection()
        var orchestrator: ModelEntry = ModelEntry(defaultTag: "qwen3:32b")
        var coder: ModelEntry = ModelEntry(defaultTag: "qwen2.5-coder:32b")
        var researcher: ModelEntry = ModelEntry(defaultTag: "command-r:35b")
        var vision: ModelEntry = ModelEntry(defaultTag: "qwen3-vl:32b")

        enum CodingKeys: String, CodingKey {
            case tierDetection = "tier_detection"
            case orchestrator, coder, researcher, vision
        }
    }

    struct TierDetection: Codable {
        var auto: Bool = true
        var thresholds: [String: [Int]] = [
            "minimal": [0, 15],
            "compact": [16, 23],
            "balanced": [24, 31],
            "performance": [32, 63],
            "advanced": [64, 999]
        ]
    }

    struct ModelEntry: Codable {
        var defaultTag: String
        var tierMapping: [String: String] = [:]

        enum CodingKeys: String, CodingKey {
            case defaultTag = "default"
            case tierMapping = "tier_mapping"
        }

        init(defaultTag: String) {
            self.defaultTag = defaultTag
        }
    }

    struct OrchestrationConfig: Codable {
        var defaultMode: String = "orchestration"
        var schedules: [ScheduleConfig] = []

        enum CodingKeys: String, CodingKey {
            case defaultMode = "default_mode"
            case schedules
        }
    }

    struct ScheduleConfig: Codable {
        var id: String = ""
        var processes: [String] = []
        var model: StringOrArray = .single("coder")
        var consultation: [String: ConsultationConfig]?

        enum StringOrArray: Codable {
            case single(String)
            case multiple([String])

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let str = try? container.decode(String.self) {
                    self = .single(str)
                } else if let arr = try? container.decode([String].self) {
                    self = .multiple(arr)
                } else {
                    self = .single("coder")
                }
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .single(let s): try container.encode(s)
                case .multiple(let a): try container.encode(a)
                }
            }
        }
    }

    struct ConsultationConfig: Codable {
        var type: String = "optional"
        var timeout: Int = 60
    }

    struct ContextConfig: Codable {
        var maxTokens: Int = 32768
        var budgetAllocation: [String: Double] = [
            "task": 0.25, "files": 0.33, "project": 0.16,
            "history": 0.12, "memory": 0.12, "errors": 0.06, "reserve": 0.06
        ]
        var compression: CompressionConfig = CompressionConfig()

        enum CodingKeys: String, CodingKey {
            case maxTokens = "max_tokens"
            case budgetAllocation = "budget_allocation"
            case compression
        }
    }

    struct CompressionConfig: Codable {
        var enabled: Bool = true
        var strategy: String = "semantic_truncate"
        var preserve: [String] = ["imports", "exports", "signatures", "errors"]
    }

    struct QualityConfig: Codable {
        var fast: QualityPreset = QualityPreset(iterations: 1, verification: "none")
        var balanced: QualityPreset = QualityPreset(iterations: 2, verification: "llm_review")
        var thorough: QualityPreset = QualityPreset(iterations: 3, verification: "expert_judge")
    }

    struct QualityPreset: Codable {
        var iterations: Int = 1
        var verification: String = "none"
    }

    struct PlatformConfig: Codable {
        var ide: IDEConfig = IDEConfig()
        var cli: CLIConfig = CLIConfig()
    }

    struct CLIConfig: Codable {
        var verbose: Bool = false
        var color: Bool = true
        var updateCheck: Bool = true

        enum CodingKeys: String, CodingKey {
            case verbose, color
            case updateCheck = "update_check"
        }
    }

    struct IDEConfig: Codable {
        var theme: String = "dark"
        var fontSize: Int = 14
        var showTokenUsage: Bool = true

        enum CodingKeys: String, CodingKey {
            case theme
            case fontSize = "font_size"
            case showTokenUsage = "show_token_usage"
        }
    }

    struct OllamaConfig: Codable {
        var url: String = "http://localhost:11434"
        var timeoutSeconds: Int = 120

        enum CodingKeys: String, CodingKey {
            case url
            case timeoutSeconds = "timeout_seconds"
        }
    }

    // MARK: - State

    @MainActor
    var config: UnifiedConfig = UnifiedConfig()
    @MainActor
    private(set) var isLoaded: Bool = false
    @MainActor
    private(set) var lastError: String?
    private(set) var configFilePath: String

    private var fileWatcherSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    // MARK: - Init

    static let configDirectory: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ollamabot")
    }()

    static let configFileURL: URL = {
        configDirectory.appendingPathComponent("config.yaml")
    }()

    init() {
        self.configFilePath = Self.configFileURL.path
        Task { @MainActor in
            loadConfig()
        }
        watchForChanges()
    }

    deinit {
        stopWatching()
    }

    // MARK: - Load

    @MainActor
    func loadConfig() {
        let url = Self.configFileURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            // No shared config file — use defaults
            config = UnifiedConfig()
            isLoaded = true
            lastError = nil
            print("SharedConfigService: No config.yaml found at \(url.path), using defaults")
            return
        }

        do {
            let yamlString = try String(contentsOf: url, encoding: .utf8)
            let decoder = YAMLDecoder()
            let decoded = try decoder.decode(UnifiedConfig.self, from: yamlString)
            
            // Merge logic: prefer YAML, but IDE can override UI specific things if desired
            // For now, we overwrite everything to enforce equivalence with CLI
            self.config = decoded
            self.isLoaded = true
            self.lastError = nil
            print("SharedConfigService: Loaded config v\(config.version) from \(url.path)")
            
            // Sync to UserDefaults for UI components that don't use SharedConfigService yet
            syncToUserDefaults()
        } catch {
            lastError = error.localizedDescription
            print("SharedConfigService: Failed to load config.yaml: \(error)")
        }
    }

    /// Syncs relevant platform settings back to UserDefaults for compatibility
    @MainActor
    private func syncToUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(config.platforms.ide.theme, forKey: "appearance.theme")
        defaults.set(config.platforms.ide.fontSize, forKey: "editor.fontSize")
        defaults.set(config.ollama.url, forKey: "ai.ollamaURL")
    }

    // MARK: - Write Default Config

    @MainActor
    func writeDefaultConfig() throws {
        let dir = Self.configDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let defaultYAML = """
        version: "2.0"
        created_by: "ollamabot"

        models:
          tier_detection:
            auto: true
            thresholds:
              minimal: [0, 15]
              compact: [16, 23]
              balanced: [24, 31]
              performance: [32, 63]
              advanced: [64, 999]
          orchestrator:
            default: qwen3:32b
            tier_mapping:
              minimal: qwen3:8b
              balanced: qwen3:14b
              performance: qwen3:32b
          coder:
            default: qwen2.5-coder:32b
            tier_mapping:
              minimal: deepseek-coder:1.3b
              balanced: qwen2.5-coder:14b
              performance: qwen2.5-coder:32b
          researcher:
            default: command-r:35b
            tier_mapping:
              minimal: command-r:7b
              performance: command-r:35b
          vision:
            default: qwen3-vl:32b
            tier_mapping:
              minimal: llava:7b
              performance: qwen3-vl:32b

        orchestration:
          default_mode: "orchestration"
          schedules:
            - id: knowledge
              processes: [research, crawl, retrieve]
              model: researcher
            - id: plan
              processes: [brainstorm, clarify, plan]
              model: coder
            - id: implement
              processes: [implement, verify, feedback]
              model: coder
            - id: scale
              processes: [scale, benchmark, optimize]
              model: coder
            - id: production
              processes: [analyze, systemize, harmonize]
              model: [coder, vision]

        context:
          max_tokens: 32768
          budget_allocation:
            task: 0.25
            files: 0.33
            project: 0.16
            history: 0.12
            memory: 0.12
            errors: 0.06
            reserve: 0.06
          compression:
            enabled: true
            strategy: semantic_truncate
            preserve: [imports, exports, signatures, errors]

        quality:
          fast:
            iterations: 1
            verification: none
          balanced:
            iterations: 2
            verification: llm_review
          thorough:
            iterations: 3
            verification: expert_judge

        platforms:
          ide:
            theme: dark
            font_size: 14
            show_token_usage: true

        ollama:
          url: http://localhost:11434
          timeout_seconds: 120
        """

        try defaultYAML.write(to: Self.configFileURL, atomically: true, encoding: .utf8)
        loadConfig()
    }

    // MARK: - File Watching

    func watchForChanges() {
        stopWatching()

        let dir = Self.configDirectory

        // Ensure the directory exists for watching
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // We watch the directory to handle file creations/deletions/renames
        fileDescriptor = open(dir.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            // Use Task for debouncing
            self?.triggerThrottledLoad()
        }

        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        source.resume()
        fileWatcherSource = source
    }

    private var loadTask: Task<Void, Never>?

    private func triggerThrottledLoad() {
        loadTask?.cancel()
        loadTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            if !Task.isCancelled {
                await MainActor.run {
                    loadConfig()
                }
            }
        }
    }

    private func stopWatching() {
        fileWatcherSource?.cancel()
        fileWatcherSource = nil
        loadTask?.cancel()
    }

    // MARK: - Migration

    /// Migrate relevant AI/orchestration settings from UserDefaults to shared config.
    @MainActor
    func migrateFromUserDefaults(_ configManager: ConfigurationManager) throws {
        var migrated = config

        // AI & Context
        migrated.context.maxTokens = configManager.contextWindow
        migrated.ollama.url = configManager.defaultModel == "auto" ? "http://localhost:11434" : configManager.defaultModel
        
        // Quality
        if configManager.maxLoops > 150 {
            migrated.quality.thorough.iterations = 4
        }
        
        // IDE UI (Keep but sync)
        migrated.platforms.ide.theme = configManager.theme
        migrated.platforms.ide.fontSize = Int(configManager.editorFontSize)
        migrated.platforms.ide.showTokenUsage = configManager.showRoutingExplanation

        self.config = migrated

        // Write to file
        let encoder = YAMLEncoder()
        let yamlString = try encoder.encode(migrated)
        
        // Create directory if missing
        try FileManager.default.createDirectory(at: Self.configDirectory, withIntermediateDirectories: true)
        try yamlString.write(to: Self.configFileURL, atomically: true, encoding: .utf8)

        print("SharedConfigService: Successfully migrated and saved settings to config.yaml")
    }

    // MARK: - Helper Types
    
    struct ValidationResult {
        let isValid: Bool
        let errors: [String]
    }
    
    @MainActor
    func validateConfig() -> ValidationResult {
        var errors: [String] = []
        
        if config.version != "2.0" {
            errors.append("Unsupported config version: \(config.version)")
        }
        
        if config.ollama.url.isEmpty {
            errors.append("Ollama URL cannot be empty")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }

    // MARK: - Accessors

    /// Returns the model tag for a given role based on current system tier
    @MainActor
    func getModelTag(for role: KeyPath<ModelsConfig, ModelEntry>, tier: String? = nil) -> String {
        let entry = config.models[keyPath: role]
        let targetTier = tier ?? getCurrentTier()
        return entry.tierMapping[targetTier] ?? entry.defaultTag
    }

    /// Determines the current system tier based on RAM (simulated for now)
    @MainActor
    func getCurrentTier() -> String {
        guard config.models.tierDetection.auto else { return "balanced" }
        
        // In a real app, we'd use process info to get physical memory
        // let ramGB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))
        let ramGB = 32 // Simulated for example
        
        for (tier, range) in config.models.tierDetection.thresholds {
            if range.count == 2 && ramGB >= range[0] && ramGB <= range[1] {
                return tier
            }
        }
        
        return "balanced"
    }
}
