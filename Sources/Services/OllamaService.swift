import Foundation

// MARK: - Optimized Ollama Service

@Observable
class OllamaService {
    // Configuration
    var baseURL: String = "http://localhost:11434"
    
    // State
    var isConnected: Bool = false
    var availableModels: [String] = []
    var warmedUpModels: Set<String> = []
    
    // Connection pool
    private let sessionConfig: URLSessionConfiguration
    private let session: URLSession
    
    // Request cache
    private let responseCache = LRUCache<String, CachedResponse>(capacity: 50)
    
    // Performance tracking
    private let requestCounter = AtomicInt()
    private let totalLatency = AtomicInt()
    
    /// Performance tracker for benchmarks and cost savings
    var performanceTracker: PerformanceTrackingService?

    /// External model routing configuration
    var externalModelConfig: ExternalModelConfigurationService?
    var apiKeyStore: APIKeyStore?
    var pricingService: PricingService?
    
    // MARK: - Stream Cancellation
    private var currentStreamTask: Task<Void, Never>?
    private var streamContinuation: AsyncThrowingStream<String, Error>.Continuation?
    var isCancelled: Bool = false
    
    /// Cancel the current streaming generation
    func cancelStream() {
        isCancelled = true
        streamContinuation?.finish()
        streamContinuation = nil
        currentStreamTask?.cancel()
        currentStreamTask = nil
    }
    
    struct CachedResponse {
        let content: String
        let timestamp: Date
        let ttl: TimeInterval
        
        var isValid: Bool {
            Date().timeIntervalSince(timestamp) < ttl
        }
    }
    
    // MARK: - Per-Model Optimization Settings
    
    /// Task-specific inference parameters for better speed/quality balance
    enum TaskType {
        case coding      // Lower temperature, focused output
        case research    // Medium temperature, thorough output
        case writing     // Higher temperature, creative output
        case vision      // Low temperature, accurate description
        case orchestration // Low temperature, precise tool calls
        
        var temperature: Double {
            switch self {
            case .coding: return 0.3
            case .research: return 0.5
            case .writing: return 0.7
            case .vision: return 0.4
            case .orchestration: return 0.2
            }
        }
        
        var maxTokens: Int {
            switch self {
            case .coding: return 4096
            case .research: return 2048
            case .writing: return 4096
            case .vision: return 1024
            case .orchestration: return 2048
            }
        }
    }
    
    /// Per-model context window sizes (tuned for M1 32GB)
    static let modelContextWindows: [OllamaModel: Int] = [
        .qwen3: 8192,       // Orchestrator needs full context
        .commandR: 8192,    // Research benefits from large context
        .coder: 16384,      // Coder can handle larger context
        .vision: 4096       // Vision doesn't need large text context
    ]
    
    init() {
        // Optimized session configuration
        sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 120
        sessionConfig.timeoutIntervalForResource = 300
        sessionConfig.httpMaximumConnectionsPerHost = 4
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfig.urlCache = nil // We handle caching ourselves
        
        // Enable HTTP/2 and keep-alive for faster subsequent requests
        sessionConfig.httpAdditionalHeaders = [
            "Connection": "keep-alive",
            "Accept-Encoding": "gzip, deflate"
        ]
        
        // Delegate queue with high priority
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 4
        queue.qualityOfService = .userInitiated
        
        session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: queue)
        
        Task { 
            await checkConnection()
            await warmupModels()
        }
    }
    
    // MARK: - Model Warmup (Critical for UX)
    
    /// Warmup progress callback for UI updates
    var warmupProgress: ((String, Double) -> Void)?
    
    /// Estimated model sizes in GB (for warmup ordering - smaller first)
    private static let modelSizes: [OllamaModel: Double] = [
        .qwen3: 4.7,      // qwen3:8b ~4.7GB
        .vision: 4.7,     // llava:7b ~4.7GB  
        .commandR: 20.0,  // command-r:35b ~20GB
        .coder: 9.0       // qwen2.5-coder:14b ~9GB
    ]
    
    /// Pre-load models on app launch using smart ordering strategy
    /// Strategy: Orchestrator first (most used), then by size (smallest→largest)
    @MainActor
    func warmupModels() async {
        guard isConnected else { return }
        
        let keepAlive = "30m"
        
        // 1. Always warm orchestrator first - it handles every request
        if let config = externalModelConfig {
            let role = resolveRole(for: .qwen3, taskType: nil, needsTools: false, hasImages: false)
            if config.config(for: role).provider == .local {
                print("🔥 [1/4] Warming up Qwen3 (orchestrator)...")
                warmupProgress?("Loading Qwen3 (orchestrator)...", 0.1)
                await warmupModelWithTiming(.qwen3, keepAlive: keepAlive)
            }
        } else {
            print("🔥 [1/4] Warming up Qwen3 (orchestrator)...")
            warmupProgress?("Loading Qwen3 (orchestrator)...", 0.1)
            await warmupModelWithTiming(.qwen3, keepAlive: keepAlive)
        }
        
        // 2. Warm remaining models in background, sorted by size (smallest first)
        // This ensures faster availability of more models
        Task.detached(priority: .background) { [self] in
            try? await Task.sleep(for: .seconds(2))
            
            // Sort remaining models by size
            let remainingModels = OllamaModel.allCases
                .filter { $0 != .qwen3 }
                .sorted { (Self.modelSizes[$0] ?? 10) < (Self.modelSizes[$1] ?? 10) }
            
            for (index, model) in remainingModels.enumerated() {
                if let config = externalModelConfig {
                    let role = resolveRole(for: model, taskType: nil, needsTools: false, hasImages: model == .vision)
                    if config.config(for: role).provider != .local {
                        continue
                    }
                }
                
                let completedCount = index + 2  // +2 because qwen3 was first
                let progress = Double(completedCount) / Double(OllamaModel.allCases.count)
                
                await MainActor.run {
                    print("🔥 [\(completedCount)/4] Warming up \(model.displayName)...")
                    warmupProgress?("Loading \(model.displayName)...", progress)
                }
                
                await warmupModelWithTiming(model, keepAlive: keepAlive)
                
                // Brief pause between models to avoid overwhelming the system
                try? await Task.sleep(for: .milliseconds(500))
            }
            
            await MainActor.run {
                print("✅ All models warmed up and ready!")
                warmupProgress?("All models ready", 1.0)
            }
        }
    }
    
    /// Warm up a model with timing information (like the article suggests)
    @MainActor
    private func warmupModelWithTiming(_ model: OllamaModel, keepAlive: String) async {
        guard !warmedUpModels.contains(model.rawValue) else {
            print("⏭️ \(model.displayName) already warm")
            return
        }
        
        let startTime = Date()
        await warmupModel(model, keepAlive: keepAlive)
        let elapsed = Date().timeIntervalSince(startTime)
        
        if warmedUpModels.contains(model.rawValue) {
            let sizeGB = Self.modelSizes[model] ?? 0
            print("✅ \(model.displayName) (~\(String(format: "%.1f", sizeGB))GB) loaded in \(String(format: "%.1f", elapsed))s")
        }
    }
    
    @MainActor
    private func warmupModel(_ model: OllamaModel, keepAlive: String = "30m") async {
        guard !warmedUpModels.contains(model.rawValue) else { return }
        
        // Send a minimal request to load model into memory with keep_alive
        guard let url = URL(string: "\(baseURL)/api/generate") else { return }
        
        let modelTag = getModelTag(for: model)
        let requestBody: [String: Any] = [
            "model": modelTag,
            "prompt": "Ready?",  // Minimal prompt like the article suggests
            "stream": false,
            "keep_alive": keepAlive,  // Keep model loaded in memory
            "options": ["num_predict": 1] // Generate only 1 token - fastest warmup
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 300  // 5 min timeout like the article (large models can be slow)
        
        do {
            let _ = try await session.data(for: request)
            warmedUpModels.insert(model.rawValue)
        } catch {
            print("⚠️ Failed to warm up \(model.displayName): \(error.localizedDescription)")
        }
    }
    
    /// Warm up a specific model - call this when switching models
    @MainActor
    func preloadModel(_ model: OllamaModel, keepAlive: String = "30m") async {
        if let config = externalModelConfig {
            let role = resolveRole(for: model, taskType: nil, needsTools: false, hasImages: model == .vision)
            if config.config(for: role).provider != .local {
                return
            }
        }
        
        if warmedUpModels.contains(model.rawValue) {
            print("⚡ \(model.displayName) already in memory")
            return
        }
        print("🔥 Preloading \(model.displayName)...")
        await warmupModelWithTiming(model, keepAlive: keepAlive)
    }
    
    /// Warm up all configured models (for setup wizard)
    /// Uses size-ordered loading: smallest models first for faster initial availability
    @MainActor
    func warmupAllModels(keepAlive: String = "30m", progress: ((String, Double) -> Void)? = nil) async {
        guard isConnected else { return }
        
        // Sort by size (smallest first) for faster initial availability
        let sortedModels = OllamaModel.allCases.sorted { 
            (Self.modelSizes[$0] ?? 10) < (Self.modelSizes[$1] ?? 10) 
        }
        
        print("🔥 Warming up all \(sortedModels.count) models (smallest first)...")
        
        for (index, model) in sortedModels.enumerated() {
            if let config = externalModelConfig {
                let role = resolveRole(for: model, taskType: nil, needsTools: false, hasImages: model == .vision)
                if config.config(for: role).provider != .local {
                    continue
                }
            }
            
            let progressValue = Double(index + 1) / Double(sortedModels.count)
            progress?("Loading \(model.displayName)...", progressValue)
            await warmupModelWithTiming(model, keepAlive: keepAlive)
        }
        
        progress?("All models ready!", 1.0)
        print("✅ All models warmed up!")
    }
    
    /// Check if a model is currently warm (in memory)
    func isModelWarm(_ model: OllamaModel) -> Bool {
        warmedUpModels.contains(model.rawValue)
    }
    
    /// Get warmup status for all models
    func getWarmupStatus() -> [(model: OllamaModel, isWarm: Bool, sizeGB: Double)] {
        OllamaModel.allCases.map { model in
            (model: model, 
             isWarm: warmedUpModels.contains(model.rawValue),
             sizeGB: Self.modelSizes[model] ?? 0)
        }
    }
    
    deinit {
        session.invalidateAndCancel()
    }
    
    // MARK: - Connection Management
    
    @MainActor
    func checkConnection() async {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            isConnected = false
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                isConnected = true
                await loadModels()
            } else {
                isConnected = false
            }
        } catch {
            isConnected = false
        }
    }
    
    @MainActor
    func loadModels() async {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return }
        
        do {
            let (data, _) = try await session.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                availableModels = models.compactMap { $0["name"] as? String }
            }
        } catch {
            print("Error loading models: \(error)")
        }
    }
    
    // MARK: - Chat with Streaming (Optimized)
    
    /// Optional model tag override for tier-aware model selection
    var modelTagOverrides: [OllamaModel: String] = [:]

    private struct ExternalRoute {
        let provider: ExternalModelConfigurationService.ProviderKind
        let providerName: String
        let modelId: String
        let baseURL: String
        let authHeader: String
        let authPrefix: String
        let apiKey: String
        let inputCostPer1K: Double
        let outputCostPer1K: Double
    }
    
    /// Get the actual Ollama model tag to use
    func getModelTag(for model: OllamaModel) -> String {
        modelTagOverrides[model] ?? model.defaultTag
    }
    
    /// Configure model tags from tier configuration
    func configureTier(_ tierManager: ModelTierManager) {
        modelTagOverrides = [
            .qwen3: tierManager.orchestrator.ollamaTag,
            .commandR: tierManager.researcher.ollamaTag,
            .coder: tierManager.coder.ollamaTag,
            .vision: tierManager.vision.ollamaTag
        ]
        print("🔧 OllamaService configured for \(tierManager.selectedTier.rawValue) tier")
    }

    private func resolveRole(
        for model: OllamaModel,
        taskType: TaskType?,
        needsTools: Bool,
        hasImages: Bool
    ) -> ExternalModelConfigurationService.Role {
        if needsTools || taskType == .orchestration {
            return .orchestrator
        }
        if hasImages {
            return .vision
        }
        switch model {
        case .qwen3:
            return .writing
        case .commandR:
            return .researcher
        case .coder:
            return .coder
        case .vision:
            return .vision
        }
    }

    private func resolveExternalRoute(
        role: ExternalModelConfigurationService.Role,
        needsTools: Bool,
        hasImages: Bool
    ) -> ExternalRoute? {
        guard let config = externalModelConfig,
              let apiKeyStore = apiKeyStore else {
            return nil
        }
        
        let roleConfig = config.config(for: role)
        if roleConfig.provider == .local {
            return nil
        }
        
        if needsTools && !config.providerSupportsTools(roleConfig.provider) {
            return nil
        }
        
        if hasImages && !config.providerSupportsVision(roleConfig.provider) {
            return nil
        }
        
        let modelId = roleConfig.modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelId.isEmpty else { return nil }
        
        guard let key = apiKeyStore.key(for: roleConfig.provider.keychainId) else {
            return nil
        }
        
        var inputCost = roleConfig.inputCostPer1K
        var outputCost = roleConfig.outputCostPer1K
        
        if inputCost == 0 && outputCost == 0 {
            let providerId = pricingProviderId(provider: roleConfig.provider, baseURL: config.providerBaseURL(roleConfig.provider))
            if let providerId,
               let pricing = pricingService?.rate(provider: providerId, modelId: modelId) {
                inputCost = pricing.inputPer1K
                outputCost = pricing.outputPer1K
            }
        }
        
        return ExternalRoute(
            provider: roleConfig.provider,
            providerName: config.providerDisplayName(roleConfig.provider),
            modelId: modelId,
            baseURL: config.providerBaseURL(roleConfig.provider),
            authHeader: config.providerAuthHeader(roleConfig.provider),
            authPrefix: config.providerAuthPrefix(roleConfig.provider),
            apiKey: key,
            inputCostPer1K: inputCost,
            outputCostPer1K: outputCost
        )
    }

    private func pricingProviderId(
        provider: ExternalModelConfigurationService.ProviderKind,
        baseURL: String
    ) -> String? {
        switch provider {
        case .openai: return "openai"
        case .anthropic: return "anthropic"
        case .gemini: return "gemini"
        case .cohere: return "cohere"
        case .openaiCompatible:
            return pricingService?.inferredProviderId(from: baseURL)
        case .local:
            return nil
        }
    }
    
    func chat(
        model: OllamaModel,
        messages: [(String, String)],
        context: String?,
        images: [Data] = [],
        taskType: TaskType? = nil
    ) -> AsyncThrowingStream<String, Error> {
        // Reset cancellation state
        isCancelled = false
        
        // Infer task type from model if not specified
        let task = taskType ?? inferTaskType(for: model)
        let role = resolveRole(for: model, taskType: task, needsTools: false, hasImages: !images.isEmpty)
        if let route = resolveExternalRoute(role: role, needsTools: false, hasImages: !images.isEmpty) {
            return externalChatStream(
                route: route,
                messages: messages,
                context: context,
                images: images,
                taskType: task
            )
        }
        
        return AsyncThrowingStream { continuation in
            // Store continuation for cancellation
            self.streamContinuation = continuation
            
            // Handle termination
            continuation.onTermination = { [weak self] _ in
                self?.streamContinuation = nil
                self?.currentStreamTask = nil
            }
            
            self.currentStreamTask = Task(priority: .userInitiated) { [weak self] in
                guard let self = self else { return }
                do {
                    try await self.streamChat(
                        model: model,
                        messages: messages,
                        context: context,
                        images: images,
                        taskType: task,
                        continuation: continuation
                    )
                } catch {
                    if !Task.isCancelled && !self.isCancelled {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }
    }
    
    private func inferTaskType(for model: OllamaModel) -> TaskType {
        switch model {
        case .qwen3: return .writing
        case .commandR: return .research
        case .coder: return .coding
        case .vision: return .vision
        }
    }

    private func externalChatStream(
        route: ExternalRoute,
        messages: [(String, String)],
        context: String?,
        images: [Data],
        taskType: TaskType
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            self.streamContinuation = continuation
            continuation.onTermination = { [weak self] _ in
                self?.streamContinuation = nil
                self?.currentStreamTask = nil
            }
            
            self.currentStreamTask = Task(priority: .userInitiated) { [weak self] in
                guard let self = self else { return }
                do {
                    var chatMessages: [[String: Any]] = []
                    if let context = context, !context.isEmpty {
                        let maxContextChars = 8192 * 3
                        let truncated = truncateContext(context, maxLength: maxContextChars)
                        chatMessages.append(["role": "system", "content": "Context:\n\(truncated)"])
                    }
                    for (role, content) in messages {
                        chatMessages.append(["role": role, "content": content])
                    }
                    
                    let inputEstimate = PerformanceTrackingService.estimateTokens(from: messages)
                        + PerformanceTrackingService.estimateTokens(from: context ?? "")
                    
                    let costRates: PerformanceTrackingService.ProviderCostRates? = {
                        let input = route.inputCostPer1K
                        let output = route.outputCostPer1K
                        if input > 0 || output > 0 {
                            return PerformanceTrackingService.ProviderCostRates(
                                inputPer1K: input,
                                outputPer1K: output
                            )
                        }
                        return nil
                    }()
                    
                    performanceTracker?.startInference(
                        model: "\(route.providerName):\(route.modelId)",
                        provider: route.providerName,
                        inputTokenEstimate: inputEstimate,
                        costRates: costRates,
                        isLocal: false
                    )
                    
                    let result = try await ExternalLLMService.chat(
                        provider: route.provider,
                        baseURL: route.baseURL,
                        apiKey: route.apiKey,
                        model: route.modelId,
                        messages: chatMessages,
                        tools: nil,
                        temperature: taskType.temperature,
                        maxTokens: taskType.maxTokens,
                        images: images,
                        authHeader: route.authHeader,
                        authPrefix: route.authPrefix
                    )
                    
                    if Task.isCancelled || self.isCancelled {
                        continuation.finish()
                        return
                    }
                    
                    if let content = result.content, !content.isEmpty {
                        continuation.yield(content)
                    }
                    
                    if let usage = result.usage {
                        performanceTracker?.endInference(
                            actualInputTokens: usage.inputTokens,
                            actualOutputTokens: usage.outputTokens
                        )
                    } else {
                        performanceTracker?.endInference()
                    }
                    
                    continuation.finish()
                } catch {
                    if !Task.isCancelled && !self.isCancelled {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }
    }
    
    private func streamChat(
        model: OllamaModel,
        messages: [(String, String)],
        context: String?,
        images: [Data],
        taskType: TaskType,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw OllamaError.invalidURL
        }
        
        // Build messages efficiently
        var chatMessages: [[String: Any]] = []
        chatMessages.reserveCapacity(messages.count + 1)
        
        // Smart context truncation - keep most recent context if too long
        if let context = context, !context.isEmpty {
            let contextWindow = Self.modelContextWindows[model] ?? 8192
            let maxContextChars = contextWindow * 3 // ~3 chars per token estimate
            let truncatedContext = truncateContext(context, maxLength: maxContextChars)
            chatMessages.append(["role": "system", "content": "Context:\n\(truncatedContext)"])
        }
        
        for (role, content) in messages {
            var msg: [String: Any] = ["role": role, "content": content]
            if role == "user" && !images.isEmpty {
                msg["images"] = images.map { $0.base64EncodedString() }
            }
            chatMessages.append(msg)
        }
        
        // Per-model and per-task optimized options
        let contextWindow = Self.modelContextWindows[model] ?? 8192
        
        let modelTag = getModelTag(for: model)
        
        let requestBody: [String: Any] = [
            "model": modelTag,
            "messages": chatMessages,
            "stream": true,
            "keep_alive": "30m",  // Keep model loaded for fast subsequent requests
            "options": [
                "num_ctx": contextWindow,
                "num_predict": taskType.maxTokens,
                "temperature": taskType.temperature,
                "num_thread": ProcessInfo.processInfo.activeProcessorCount,
                "num_gpu": 999 // Use all GPU layers available (M1 unified memory)
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Start performance tracking
        let inputTokenEstimate = PerformanceTrackingService.estimateTokens(from: messages)
        performanceTracker?.startInference(
            model: model.displayName,
            provider: "Ollama Local",
            inputTokenEstimate: inputTokenEstimate,
            costRates: nil,
            isLocal: true
        )
        
        let (bytes, response) = try await session.bytes(for: request)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OllamaError.badResponse
        }
        
        // Process stream with optimized buffering
        // Larger buffer = fewer UI updates = better performance
        // But too large = laggy feeling. 50 chars is a good balance.
        var buffer = ""
        buffer.reserveCapacity(256)
        
        var lastYieldTime = CFAbsoluteTimeGetCurrent()
        let minYieldInterval = 0.016 // ~60fps UI updates
        var isFirstToken = true
        var totalTokensGenerated = 0
        
        for try await line in bytes.lines {
            // Check for cancellation
            if Task.isCancelled || isCancelled {
                continuation.finish()
                return
            }
            
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let message = json["message"] as? [String: Any],
                  let content = message["content"] as? String else { continue }
            
            // Track first token for TTFT
            if isFirstToken && !content.isEmpty {
                performanceTracker?.recordFirstToken()
                isFirstToken = false
            }
            
            buffer.append(content)
            totalTokensGenerated += 1  // Rough estimate: each chunk ≈ 1 token
            
            let now = CFAbsoluteTimeGetCurrent()
            let isDone = json["done"] as? Bool == true
            
            // Yield when: buffer is large enough, enough time passed, or stream done
            if buffer.count >= 50 || (now - lastYieldTime) >= minYieldInterval || isDone {
                continuation.yield(buffer)
                
                // Track tokens (better estimate from character count)
                let chunkTokens = PerformanceTrackingService.estimateTokens(from: buffer)
                performanceTracker?.incrementTokens(chunkTokens)
                
                buffer.removeAll(keepingCapacity: true)
                lastYieldTime = now
            }
            
            if isDone { break }
        }
        
        if !buffer.isEmpty {
            continuation.yield(buffer)
            let chunkTokens = PerformanceTrackingService.estimateTokens(from: buffer)
            performanceTracker?.incrementTokens(chunkTokens)
        }
        
        // End performance tracking
        performanceTracker?.endInference()
        
        // Track performance
        requestCounter.increment()
        _ = totalLatency.increment()
        
        continuation.finish()
    }
    
    // MARK: - Chat with Tools (Optimized)
    
    struct ChatResponse {
        let content: String?
        let toolCalls: [ToolCall]?
    }
    
    func chatWithTools(
        model: OllamaModel,
        messages: [[String: Any]],
        tools: [[String: Any]]
    ) async throws -> ChatResponse {
        let role = resolveRole(for: model, taskType: .orchestration, needsTools: true, hasImages: false)
        if let route = resolveExternalRoute(role: role, needsTools: true, hasImages: false) {
            let inputEstimate = PerformanceTrackingService.estimateTokens(from: messages.compactMap {
                guard let role = $0["role"] as? String, let content = $0["content"] as? String else { return ("", "") }
                return (role, content)
            })
            
            let costRates: PerformanceTrackingService.ProviderCostRates? = {
                let input = route.inputCostPer1K
                let output = route.outputCostPer1K
                if input > 0 || output > 0 {
                    return PerformanceTrackingService.ProviderCostRates(
                        inputPer1K: input,
                        outputPer1K: output
                    )
                }
                return nil
            }()
            
            performanceTracker?.startInference(
                model: "\(route.providerName):\(route.modelId)",
                provider: route.providerName,
                inputTokenEstimate: inputEstimate,
                costRates: costRates,
                isLocal: false
            )
            
            let result = try await ExternalLLMService.chat(
                provider: route.provider,
                baseURL: route.baseURL,
                apiKey: route.apiKey,
                model: route.modelId,
                messages: messages,
                tools: tools,
                temperature: TaskType.orchestration.temperature,
                maxTokens: TaskType.orchestration.maxTokens,
                images: [],
                authHeader: route.authHeader,
                authPrefix: route.authPrefix
            )
            
            if let usage = result.usage {
                performanceTracker?.endInference(
                    actualInputTokens: usage.inputTokens,
                    actualOutputTokens: usage.outputTokens
                )
            } else {
                performanceTracker?.endInference()
            }
            
            return ChatResponse(content: result.content, toolCalls: result.toolCalls)
        }
        
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw OllamaError.invalidURL
        }
        
        // Tool calling requires precise, low-temperature responses
        let contextWindow = Self.modelContextWindows[model] ?? 8192
        let modelTag = getModelTag(for: model)

        let inputEstimate = PerformanceTrackingService.estimateTokens(from: messages.compactMap {
            guard let role = $0["role"] as? String, let content = $0["content"] as? String else { return ("", "") }
            return (role, content)
        })
        performanceTracker?.startInference(
            model: model.displayName,
            provider: "Ollama Local",
            inputTokenEstimate: inputEstimate,
            costRates: nil,
            isLocal: true
        )
        
        let requestBody: [String: Any] = [
            "model": modelTag,
            "messages": messages,
            "tools": tools,
            "stream": false,
            "keep_alive": "30m",  // Keep model loaded
            "options": [
                "num_ctx": contextWindow,
                "num_predict": TaskType.orchestration.maxTokens,
                "temperature": TaskType.orchestration.temperature,
                "num_thread": ProcessInfo.processInfo.activeProcessorCount,
                "num_gpu": 999
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 120
        
        let (data, response) = try await session.data(for: request)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OllamaError.badResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any] else {
            throw OllamaError.invalidResponse
        }
        
        let content = message["content"] as? String
        
        var toolCalls: [ToolCall]? = nil
        if let calls = message["tool_calls"] as? [[String: Any]] {
            toolCalls = calls.compactMap { ToolCall(from: $0) }
        }
        
        let outputEstimate = PerformanceTrackingService.estimateTokens(from: content ?? "")
        performanceTracker?.endInference(
            actualInputTokens: inputEstimate,
            actualOutputTokens: outputEstimate
        )
        
        return ChatResponse(content: content, toolCalls: toolCalls)
    }
    
    // MARK: - Generate (Non-streaming, Cached)
    
    func generate(prompt: String, model: OllamaModel, useCache: Bool = true, taskType: TaskType? = nil, keepAlive: String = "30m") async throws -> String {
        let modelTag = getModelTag(for: model)
        let cacheKey = "\(modelTag):\(prompt.hashValue)"
        
        // Check cache
        if useCache, let cached = responseCache.get(cacheKey), cached.isValid {
            return cached.content
        }
        
        let task = taskType ?? inferTaskType(for: model)
        let role = resolveRole(for: model, taskType: task, needsTools: false, hasImages: false)
        if let route = resolveExternalRoute(role: role, needsTools: false, hasImages: false) {
            let inputEstimate = PerformanceTrackingService.estimateTokens(from: prompt)
            let costRates: PerformanceTrackingService.ProviderCostRates? = {
                let input = route.inputCostPer1K
                let output = route.outputCostPer1K
                if input > 0 || output > 0 {
                    return PerformanceTrackingService.ProviderCostRates(
                        inputPer1K: input,
                        outputPer1K: output
                    )
                }
                return nil
            }()
            
            performanceTracker?.startInference(
                model: "\(route.providerName):\(route.modelId)",
                provider: route.providerName,
                inputTokenEstimate: inputEstimate,
                costRates: costRates,
                isLocal: false
            )
            
            let result = try await ExternalLLMService.chat(
                provider: route.provider,
                baseURL: route.baseURL,
                apiKey: route.apiKey,
                model: route.modelId,
                messages: [
                    ["role": "user", "content": prompt]
                ],
                tools: nil,
                temperature: task.temperature,
                maxTokens: task.maxTokens,
                images: [],
                authHeader: route.authHeader,
                authPrefix: route.authPrefix
            )
            
            if let usage = result.usage {
                performanceTracker?.endInference(
                    actualInputTokens: usage.inputTokens,
                    actualOutputTokens: usage.outputTokens
                )
            } else {
                performanceTracker?.endInference()
            }
            
            return result.content ?? ""
        }
        
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw OllamaError.invalidURL
        }
        
        let inputEstimate = PerformanceTrackingService.estimateTokens(from: prompt)
        performanceTracker?.startInference(
            model: model.displayName,
            provider: "Ollama Local",
            inputTokenEstimate: inputEstimate,
            costRates: nil,
            isLocal: true
        )
        
        let contextWindow = Self.modelContextWindows[model] ?? 8192
        
        let requestBody: [String: Any] = [
            "model": modelTag,
            "prompt": prompt,
            "stream": false,
            "keep_alive": keepAlive,  // Keep model loaded
            "options": [
                "num_ctx": contextWindow,
                "num_predict": task.maxTokens,
                "temperature": task.temperature,
                "num_thread": ProcessInfo.processInfo.activeProcessorCount,
                "num_gpu": 999
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 120
        
        let (data, response) = try await session.data(for: request)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OllamaError.badResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String else {
            throw OllamaError.invalidResponse
        }

        let outputEstimate = PerformanceTrackingService.estimateTokens(from: responseText)
        performanceTracker?.endInference(
            actualInputTokens: inputEstimate,
            actualOutputTokens: outputEstimate
        )
        
        // Cache the response
        if useCache {
            responseCache.set(cacheKey, CachedResponse(
                content: responseText,
                timestamp: Date(),
                ttl: 300 // 5 minutes
            ))
        }
        
        return responseText
    }
    
    // MARK: - Performance Stats
    
    var averageLatencyMs: Int {
        let count = requestCounter.current
        guard count > 0 else { return 0 }
        return totalLatency.current / count
    }
    
    // MARK: - Context Management
    
    /// Intelligently truncate context, keeping most relevant parts
    private func truncateContext(_ context: String, maxLength: Int) -> String {
        guard context.count > maxLength else { return context }
        
        // Strategy: Keep beginning (file info) and end (recent code)
        let keepFromStart = maxLength / 3
        let keepFromEnd = maxLength * 2 / 3
        
        let startPart = String(context.prefix(keepFromStart))
        let endPart = String(context.suffix(keepFromEnd))
        
        return "\(startPart)\n\n... [truncated \(context.count - maxLength) characters] ...\n\n\(endPart)"
    }
    
    /// Compress old conversation history to save tokens
    func compressHistory(_ messages: [(String, String)], keepRecent: Int = 4) -> [(String, String)] {
        guard messages.count > keepRecent + 2 else { return messages }
        
        // Keep system message (if any), compress middle, keep recent
        var result: [(String, String)] = []
        
        // Keep first message if it's a system message
        if let first = messages.first, first.0 == "system" {
            result.append(first)
        }
        
        // Summarize old messages
        let oldMessages = messages.dropFirst().dropLast(keepRecent)
        if !oldMessages.isEmpty {
            let summary = oldMessages.map { "\($0.0): \($0.1.prefix(100))..." }.joined(separator: "\n")
            result.append(("system", "[Previous conversation summary:\n\(summary)]"))
        }
        
        // Keep recent messages intact
        result.append(contentsOf: messages.suffix(keepRecent))
        
        return result
    }
}

// MARK: - Errors

enum OllamaError: LocalizedError {
    case invalidURL
    case badResponse
    case invalidResponse
    case modelNotAvailable(String)
    case connectionFailed
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Ollama server URL"
        case .badResponse: return "Bad response from Ollama server"
        case .invalidResponse: return "Could not parse response"
        case .modelNotAvailable(let m): return "Model '\(m)' not available"
        case .connectionFailed: return "Failed to connect to Ollama"
        case .timeout: return "Request timed out"
        }
    }
    
    /// User-friendly message for toast notifications
    var userMessage: String {
        switch self {
        case .invalidURL: 
            return "Check Ollama server URL in settings"
        case .badResponse, .invalidResponse: 
            return "Ollama returned an unexpected response"
        case .modelNotAvailable(let m): 
            return "Please install \(m) via 'ollama pull \(m)'"
        case .connectionFailed: 
            return "Is Ollama running? Start with 'ollama serve'"
        case .timeout: 
            return "Request took too long - try a shorter prompt"
        }
    }
}
