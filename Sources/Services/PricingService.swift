import Foundation

@Observable
final class PricingService {
    static let defaultSourceURL = URL(string: "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json")!
    
    struct PricingCatalog: Codable {
        let version: Int
        let updatedAt: String
        let sources: [PricingSource]
        let providers: [String: [String: ModelPricing]]
    }
    
    struct PricingSource: Codable {
        let name: String
        let url: String
        let fetchedAt: String
    }
    
    struct ModelPricing: Codable {
        let inputPer1K: Double
        let outputPer1K: Double
        let currency: String
        let source: String
    }
    
    private let pricingURL: URL
    private var lastModified: Date?
    
    private(set) var catalog: PricingCatalog?
    
    init() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ollamabot")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        pricingURL = configDir.appendingPathComponent("pricing.json")
        
        loadPricing()
    }
    
    func loadPricing() {
        guard FileManager.default.fileExists(atPath: pricingURL.path),
              let data = try? Data(contentsOf: pricingURL),
              let decoded = try? JSONDecoder().decode(PricingCatalog.self, from: data) else {
            catalog = nil
            return
        }
        catalog = decoded
        lastModified = fileModifiedDate()
    }
    
    func refreshIfNeeded() {
        guard let modified = fileModifiedDate() else { return }
        if let lastModified, modified <= lastModified {
            return
        }
        loadPricing()
    }

    @MainActor
    func updateCatalog(from url: URL = PricingService.defaultSourceURL) async throws {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        guard let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        
        let providers = buildCatalog(from: raw, sourceName: "litellm", sourceURL: url.absoluteString)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        let catalog = PricingCatalog(
            version: 1,
            updatedAt: timestamp,
            sources: [
                PricingSource(name: "litellm", url: url.absoluteString, fetchedAt: timestamp)
            ],
            providers: providers
        )
        
        let dataOut = try JSONEncoder().encode(catalog)
        try dataOut.write(to: pricingURL)
        self.catalog = catalog
        self.lastModified = fileModifiedDate()
    }
    
    func rate(
        provider: String,
        modelId: String,
        aliases: [String] = []
    ) -> PerformanceTrackingService.ProviderCostRates? {
        refreshIfNeeded()
        
        guard let catalog else { return nil }
        let providerKey = normalize(provider)
        let providerCandidates = [providerKey] + (providerAliases[providerKey] ?? [])
        
        for key in providerCandidates {
            if let modelPricing = lookupModel(
                in: catalog.providers[key],
                modelId: modelId,
                aliases: aliases
            ) {
                return PerformanceTrackingService.ProviderCostRates(
                    inputPer1K: modelPricing.inputPer1K,
                    outputPer1K: modelPricing.outputPer1K
                )
            }
        }
        
        return nil
    }
    
    func inferredProviderId(from baseURL: String) -> String? {
        guard let url = URL(string: baseURL), let host = url.host?.lowercased() else { return nil }
        if host.contains("openrouter") { return "openrouter" }
        if host.contains("together") { return "together" }
        if host.contains("groq") { return "groq" }
        if host.contains("mistral") { return "mistral" }
        if host.contains("perplexity") { return "perplexity" }
        if host.contains("fireworks") { return "fireworks" }
        if host.contains("openai") { return "openai" }
        if host.contains("anthropic") { return "anthropic" }
        if host.contains("cohere") { return "cohere" }
        if host.contains("google") || host.contains("gemini") { return "gemini" }
        return nil
    }
    
    // MARK: - Private
    
    private func lookupModel(
        in providerModels: [String: ModelPricing]?,
        modelId: String,
        aliases: [String]
    ) -> ModelPricing? {
        guard let providerModels else { return nil }
        let candidates = [modelId] + aliases
        for candidate in candidates {
            let key = normalize(candidate)
            if let exact = providerModels[key] {
                return exact
            }
        }
        
        for candidate in candidates {
            let key = normalize(candidate)
            if let match = providerModels.first(where: { $0.key.contains(key) || key.contains($0.key) }) {
                return match.value
            }
        }
        
        return nil
    }
    
    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    private func fileModifiedDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: pricingURL.path)[.modificationDate]) as? Date
    }
    
    private let providerAliases: [String: [String]] = [
        "gemini": ["google", "googleai", "vertex"],
        "openai": ["openai"],
        "anthropic": ["anthropic"],
        "cohere": ["cohere"]
    ]

    private func buildCatalog(
        from raw: [String: Any],
        sourceName: String,
        sourceURL: String
    ) -> [String: [String: ModelPricing]] {
        var providers: [String: [String: ModelPricing]] = [:]
        
        for (modelName, infoAny) in raw {
            guard let info = infoAny as? [String: Any] else { continue }
            let inputCost = doubleValue(info["input_cost_per_token"])
            let outputCost = doubleValue(info["output_cost_per_token"])
            if inputCost == nil && outputCost == nil { continue }
            
            let (provider, model) = splitProvider(modelName)
            let pricing = ModelPricing(
                inputPer1K: round((inputCost ?? 0) * 1000 * 1_000_000) / 1_000_000,
                outputPer1K: round((outputCost ?? 0) * 1000 * 1_000_000) / 1_000_000,
                currency: "USD",
                source: sourceName
            )
            providers[provider, default: [:]][model] = pricing
        }
        
        return providers
    }
    
    private func splitProvider(_ modelName: String) -> (String, String) {
        if let slashIndex = modelName.firstIndex(of: "/") {
            let provider = String(modelName[..<slashIndex])
            let model = String(modelName[modelName.index(after: slashIndex)...])
            return (normalize(provider), normalize(model))
        }
        
        let lower = normalize(modelName)
        if lower.contains("claude") { return ("anthropic", lower) }
        if lower.hasPrefix("gpt-") || lower.hasPrefix("o1-") || lower.contains("gpt") { return ("openai", lower) }
        if lower.contains("gemini") { return ("gemini", lower) }
        if lower.contains("command-r") || lower.contains("cohere") { return ("cohere", lower) }
        if lower.contains("mistral") { return ("mistral", lower) }
        if lower.contains("groq") { return ("groq", lower) }
        if lower.contains("perplexity") || lower.hasPrefix("pplx") { return ("perplexity", lower) }
        if lower.contains("together") { return ("together", lower) }
        if lower.contains("fireworks") { return ("fireworks", lower) }
        return ("unknown", lower)
    }
    
    private func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let str = value as? String {
            return Double(str)
        }
        return nil
    }
}
