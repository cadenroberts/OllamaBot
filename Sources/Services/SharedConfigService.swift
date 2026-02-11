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

    private(set) var config: UnifiedConfig = UnifiedConfig()
    private(set) var isLoaded: Bool = false
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
        loadConfig()
        watchForChanges()
    }

    deinit {
        stopWatching()
    }

    // MARK: - Load

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
            config = try decoder.decode(UnifiedConfig.self, from: yamlString)
            isLoaded = true
            lastError = nil
            print("SharedConfigService: Loaded config v\(config.version) from \(url.path)")
        } catch {
            lastError = error.localizedDescription
            print("SharedConfigService: Failed to load config.yaml: \(error)")
        }
    }

    // MARK: - Write Default Config

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

        let path = Self.configFileURL.path

        // Ensure the directory exists for watching
        let dir = Self.configDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // If file doesn't exist, watch the directory instead
        let watchPath: String
        if FileManager.default.fileExists(atPath: path) {
            watchPath = path
        } else {
            watchPath = dir.path
        }

        fileDescriptor = open(watchPath, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.loadConfig()
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

    private func stopWatching() {
        fileWatcherSource?.cancel()
        fileWatcherSource = nil
    }

    // MARK: - Migration

    /// Migrate relevant AI/orchestration settings from UserDefaults to shared config
    func migrateFromUserDefaults(_ configManager: ConfigurationManager) throws {
        var migrated = config

        // Migrate AI settings
        if configManager.contextWindow != 8192 {
            migrated.context.maxTokens = configManager.contextWindow
        }

        // Migrate theme preference
        migrated.platforms.ide.theme = configManager.theme
        migrated.platforms.ide.fontSize = Int(configManager.editorFontSize)

        config = migrated

        // Write to file
        let encoder = YAMLEncoder()
        let yamlString = try encoder.encode(migrated)
        try yamlString.write(to: Self.configFileURL, atomically: true, encoding: .utf8)

        print("SharedConfigService: Migrated settings from UserDefaults")
    }
}
