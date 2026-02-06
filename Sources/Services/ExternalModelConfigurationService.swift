import Foundation

@Observable
final class ExternalModelConfigurationService {
    enum Role: String, CaseIterable, Codable {
        case writing
        case orchestrator
        case researcher
        case coder
        case vision
        
        var displayName: String {
            switch self {
            case .writing: return "Writing"
            case .orchestrator: return "Orchestrator"
            case .researcher: return "Researcher"
            case .coder: return "Coder"
            case .vision: return "Vision"
            }
        }
    }
    
    enum ProviderKind: String, CaseIterable, Codable, Hashable {
        case local
        case openai
        case openaiCompatible
        case anthropic
        case gemini
        case cohere
        
        var keychainId: String {
            rawValue
        }
    }
    
    struct RoleConfig: Codable, Hashable {
        var provider: ProviderKind
        var modelId: String
        var inputCostPer1K: Double
        var outputCostPer1K: Double
    }
    
    struct OpenAICompatibleConfig: Codable, Hashable {
        var displayName: String
        var baseURL: String
        var authHeader: String
        var authPrefix: String
    }
    
    private struct StoredConfig: Codable {
        var roleConfigs: [Role: RoleConfig]
        var openAICompatible: OpenAICompatibleConfig
    }
    
    private let configURL: URL
    
    var roleConfigs: [Role: RoleConfig] {
        didSet { save() }
    }
    
    var openAICompatible: OpenAICompatibleConfig {
        didSet { save() }
    }
    
    init() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ollamabot")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        configURL = configDir.appendingPathComponent("external_models.json")
        
        let defaults = Self.defaultRoleConfigs()
        let openAICompatibleDefault = Self.defaultOpenAICompatibleConfig()
        
        if let data = try? Data(contentsOf: configURL),
           let stored = try? JSONDecoder().decode(StoredConfig.self, from: data) {
            roleConfigs = stored.roleConfigs.merging(defaults) { current, _ in current }
            openAICompatible = stored.openAICompatible
        } else {
            roleConfigs = defaults
            openAICompatible = openAICompatibleDefault
        }
    }
    
    func config(for role: Role) -> RoleConfig {
        roleConfigs[role] ?? Self.defaultRoleConfigs()[role]!
    }
    
    func updateRole(_ role: Role, config: RoleConfig) {
        roleConfigs[role] = config
    }
    
    func providerDisplayName(_ provider: ProviderKind) -> String {
        switch provider {
        case .local: return "Ollama (Local)"
        case .openai: return "OpenAI"
        case .openaiCompatible: return openAICompatible.displayName
        case .anthropic: return "Anthropic"
        case .gemini: return "Google Gemini"
        case .cohere: return "Cohere"
        }
    }
    
    func providerBaseURL(_ provider: ProviderKind) -> String {
        switch provider {
        case .local: return "http://localhost:11434"
        case .openai: return "https://api.openai.com/v1"
        case .openaiCompatible: return openAICompatible.baseURL
        case .anthropic: return "https://api.anthropic.com/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
        case .cohere: return "https://api.cohere.ai/v1"
        }
    }
    
    func providerAuthHeader(_ provider: ProviderKind) -> String {
        switch provider {
        case .local: return ""
        case .openai: return "Authorization"
        case .openaiCompatible: return openAICompatible.authHeader
        case .anthropic: return "x-api-key"
        case .gemini: return ""
        case .cohere: return "Authorization"
        }
    }
    
    func providerAuthPrefix(_ provider: ProviderKind) -> String {
        switch provider {
        case .local: return ""
        case .openai: return "Bearer"
        case .openaiCompatible: return openAICompatible.authPrefix
        case .anthropic: return ""
        case .gemini: return ""
        case .cohere: return "Bearer"
        }
    }
    
    func providerSupportsTools(_ provider: ProviderKind) -> Bool {
        switch provider {
        case .openai, .openaiCompatible, .anthropic, .gemini:
            return true
        default:
            return false
        }
    }
    
    func providerSupportsVision(_ provider: ProviderKind) -> Bool {
        switch provider {
        case .openai, .openaiCompatible, .anthropic, .gemini:
            return true
        default:
            return false
        }
    }
    
    private func save() {
        let stored = StoredConfig(roleConfigs: roleConfigs, openAICompatible: openAICompatible)
        if let data = try? JSONEncoder().encode(stored) {
            try? data.write(to: configURL)
        }
    }
    
    private static func defaultRoleConfigs() -> [Role: RoleConfig] {
        Role.allCases.reduce(into: [:]) { result, role in
            result[role] = RoleConfig(
                provider: .local,
                modelId: "",
                inputCostPer1K: 0,
                outputCostPer1K: 0
            )
        }
    }
    
    private static func defaultOpenAICompatibleConfig() -> OpenAICompatibleConfig {
        OpenAICompatibleConfig(
            displayName: "OpenAI-Compatible",
            baseURL: "https://api.openai.com/v1",
            authHeader: "Authorization",
            authPrefix: "Bearer"
        )
    }
}
