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
    
    /// Pre-load the orchestrator model on app launch for instant first response
    @MainActor
    func warmupModels() async {
        guard isConnected else { return }
        
        // Warm up the orchestrator (Qwen3) first - it's used most often
        print("🔥 Warming up Qwen3 (orchestrator)...")
        await warmupModel(.qwen3)
        
        // Optionally warm up coder in background (most common delegation)
        Task.detached(priority: .background) { [self] in
            try? await Task.sleep(for: .seconds(5))
            print("🔥 Warming up Qwen-Coder...")
            await warmupModel(.coder)
        }
    }
    
    @MainActor
    private func warmupModel(_ model: OllamaModel) async {
        guard !warmedUpModels.contains(model.rawValue) else { return }
        
        // Send a minimal request to load model into memory
        guard let url = URL(string: "\(baseURL)/api/generate") else { return }
        
        let requestBody: [String: Any] = [
            "model": model.rawValue,
            "prompt": "Hello",
            "stream": false,
            "options": ["num_predict": 1] // Generate only 1 token
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60
        
        do {
            let _ = try await session.data(for: request)
            warmedUpModels.insert(model.rawValue)
            print("✓ \(model.displayName) warmed up")
        } catch {
            print("⚠ Failed to warm up \(model.displayName): \(error.localizedDescription)")
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
    
    func chat(
        model: OllamaModel,
        messages: [(String, String)],
        context: String?,
        images: [Data] = [],
        taskType: TaskType? = nil
    ) -> AsyncThrowingStream<String, Error> {
        // Infer task type from model if not specified
        let task = taskType ?? inferTaskType(for: model)
        
        return AsyncThrowingStream { continuation in
            Task(priority: .userInitiated) {
                do {
                    try await streamChat(
                        model: model,
                        messages: messages,
                        context: context,
                        images: images,
                        taskType: task,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
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
        
        let requestBody: [String: Any] = [
            "model": model.rawValue,
            "messages": chatMessages,
            "stream": true,
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
        
        for try await line in bytes.lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let message = json["message"] as? [String: Any],
                  let content = message["content"] as? String else { continue }
            
            buffer.append(content)
            
            let now = CFAbsoluteTimeGetCurrent()
            let isDone = json["done"] as? Bool == true
            
            // Yield when: buffer is large enough, enough time passed, or stream done
            if buffer.count >= 50 || (now - lastYieldTime) >= minYieldInterval || isDone {
                continuation.yield(buffer)
                buffer.removeAll(keepingCapacity: true)
                lastYieldTime = now
            }
            
            if isDone { break }
        }
        
        if !buffer.isEmpty {
            continuation.yield(buffer)
        }
        
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
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw OllamaError.invalidURL
        }
        
        // Tool calling requires precise, low-temperature responses
        let contextWindow = Self.modelContextWindows[model] ?? 8192
        
        let requestBody: [String: Any] = [
            "model": model.rawValue,
            "messages": messages,
            "tools": tools,
            "stream": false,
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
        
        return ChatResponse(content: content, toolCalls: toolCalls)
    }
    
    // MARK: - Generate (Non-streaming, Cached)
    
    func generate(prompt: String, model: OllamaModel, useCache: Bool = true, taskType: TaskType? = nil) async throws -> String {
        let cacheKey = "\(model.rawValue):\(prompt.hashValue)"
        
        // Check cache
        if useCache, let cached = responseCache.get(cacheKey), cached.isValid {
            return cached.content
        }
        
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw OllamaError.invalidURL
        }
        
        let task = taskType ?? inferTaskType(for: model)
        let contextWindow = Self.modelContextWindows[model] ?? 8192
        
        let requestBody: [String: Any] = [
            "model": model.rawValue,
            "prompt": prompt,
            "stream": false,
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
