import Foundation

struct ExternalLLMService {
    struct Usage {
        let inputTokens: Int
        let outputTokens: Int
    }
    
    struct ChatResult {
        let content: String?
        let toolCalls: [ToolCall]?
        let usage: Usage?
    }
    
    enum ExternalError: Error {
        case invalidURL
        case badResponse
        case unsupported
        case invalidResponse
    }

    private static func parseArguments(_ value: Any?) -> [String: Any] {
        if let args = value as? [String: Any] {
            return args
        }
        if let argsString = value as? String,
           let data = argsString.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return parsed
        }
        return [:]
    }
    
    static func chat(
        provider: ExternalModelConfigurationService.ProviderKind,
        baseURL: String,
        apiKey: String,
        model: String,
        messages: [[String: Any]],
        tools: [[String: Any]]? = nil,
        temperature: Double,
        maxTokens: Int,
        images: [Data] = [],
        authHeader: String,
        authPrefix: String
    ) async throws -> ChatResult {
        switch provider {
        case .openai, .openaiCompatible:
            return try await chatOpenAICompatible(
                baseURL: baseURL,
                apiKey: apiKey,
                model: model,
                messages: messages,
                tools: tools,
                temperature: temperature,
                maxTokens: maxTokens,
                images: images,
                authHeader: authHeader,
                authPrefix: authPrefix
            )
        case .anthropic:
            return try await chatAnthropic(
                baseURL: baseURL,
                apiKey: apiKey,
                model: model,
                messages: messages,
                tools: tools,
                temperature: temperature,
                maxTokens: maxTokens,
                images: images
            )
        case .gemini:
            return try await chatGemini(
                baseURL: baseURL,
                apiKey: apiKey,
                model: model,
                messages: messages,
                tools: tools,
                temperature: temperature,
                maxTokens: maxTokens,
                images: images
            )
        case .cohere:
            return try await chatCohere(
                baseURL: baseURL,
                apiKey: apiKey,
                model: model,
                messages: messages,
                temperature: temperature,
                maxTokens: maxTokens,
                authHeader: authHeader,
                authPrefix: authPrefix
            )
        case .local:
            throw ExternalError.unsupported
        }
    }
    
    // MARK: - OpenAI Compatible
    
    private static func chatOpenAICompatible(
        baseURL: String,
        apiKey: String,
        model: String,
        messages: [[String: Any]],
        tools: [[String: Any]]?,
        temperature: Double,
        maxTokens: Int,
        images: [Data],
        authHeader: String,
        authPrefix: String
    ) async throws -> ChatResult {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw ExternalError.invalidURL
        }
        
        var openAIMessages = messages
        if !images.isEmpty {
            for idx in stride(from: openAIMessages.count - 1, through: 0, by: -1) {
                if let role = openAIMessages[idx]["role"] as? String, role == "user",
                   let content = openAIMessages[idx]["content"] as? String {
                    var parts: [[String: Any]] = [
                        ["type": "text", "text": content]
                    ]
                    parts.append(contentsOf: images.map { data in
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/png;base64,\(data.base64EncodedString())"
                            ]
                        ]
                    })
                    openAIMessages[idx]["content"] = parts
                    break
                }
            }
        }
        
        var body: [String: Any] = [
            "model": model,
            "messages": openAIMessages,
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": false
        ]
        if let tools, !tools.isEmpty {
            body["tools"] = tools
            body["tool_choice"] = "auto"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let authValue = authPrefix.isEmpty ? apiKey : "\(authPrefix) \(apiKey)"
        if !authHeader.isEmpty {
            request.setValue(authValue, forHTTPHeaderField: authHeader)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ExternalError.badResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any] else {
            throw ExternalError.invalidResponse
        }
        
        let content = message["content"] as? String
        let toolCalls = (message["tool_calls"] as? [[String: Any]])?.compactMap { ToolCall(from: $0) }
        
        var usage: Usage? = nil
        if let usageDict = json["usage"] as? [String: Any] {
            let inputTokens = usageDict["prompt_tokens"] as? Int ?? 0
            let outputTokens = usageDict["completion_tokens"] as? Int ?? 0
            usage = Usage(inputTokens: inputTokens, outputTokens: outputTokens)
        }
        
        return ChatResult(content: content, toolCalls: toolCalls, usage: usage)
    }
    
    // MARK: - Anthropic
    
    private static func chatAnthropic(
        baseURL: String,
        apiKey: String,
        model: String,
        messages: [[String: Any]],
        tools: [[String: Any]]?,
        temperature: Double,
        maxTokens: Int,
        images: [Data]
    ) async throws -> ChatResult {
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw ExternalError.invalidURL
        }
        
        let (systemPrompt, anthropicMessages) = buildAnthropicMessages(messages: messages, images: images)
        
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "temperature": temperature,
            "messages": anthropicMessages
        ]
        if !systemPrompt.isEmpty {
            body["system"] = systemPrompt
        }
        if let tools, !tools.isEmpty {
            body["tools"] = anthropicTools(from: tools)
            body["tool_choice"] = ["type": "auto"]
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ExternalError.badResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentBlocks = json["content"] as? [[String: Any]] else {
            throw ExternalError.invalidResponse
        }
        
        var contentText = ""
        var toolCalls: [ToolCall] = []
        for block in contentBlocks {
            if let type = block["type"] as? String, type == "text" {
                contentText += block["text"] as? String ?? ""
            } else if let type = block["type"] as? String, type == "tool_use" {
                let id = block["id"] as? String ?? UUID().uuidString
                let name = block["name"] as? String ?? "tool"
                let input = block["input"] as? [String: Any] ?? [:]
                let dict: [String: Any] = [
                    "id": id,
                    "function": [
                        "name": name,
                        "arguments": input
                    ]
                ]
                if let call = ToolCall(from: dict) {
                    toolCalls.append(call)
                }
            }
        }
        
        var usage: Usage? = nil
        if let usageDict = json["usage"] as? [String: Any] {
            let inputTokens = usageDict["input_tokens"] as? Int ?? 0
            let outputTokens = usageDict["output_tokens"] as? Int ?? 0
            usage = Usage(inputTokens: inputTokens, outputTokens: outputTokens)
        }
        
        return ChatResult(
            content: contentText.isEmpty ? nil : contentText,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls,
            usage: usage
        )
    }
    
    private static func buildAnthropicMessages(
        messages: [[String: Any]],
        images: [Data]
    ) -> (systemPrompt: String, messages: [[String: Any]]) {
        var systemParts: [String] = []
        var anthropicMessages: [[String: Any]] = []
        var toolNameById: [String: String] = [:]
        
        for message in messages {
            guard let role = message["role"] as? String else { continue }
            
            if role == "system" {
                if let content = message["content"] as? String, !content.isEmpty {
                    systemParts.append(content)
                }
                continue
            }
            
            if let toolCalls = message["tool_calls"] as? [[String: Any]] {
                var contentBlocks: [[String: Any]] = []
                for call in toolCalls {
                    let id = call["id"] as? String ?? UUID().uuidString
                    if let function = call["function"] as? [String: Any],
                       let name = function["name"] as? String {
                        toolNameById[id] = name
                        let input = parseArguments(function["arguments"])
                        contentBlocks.append([
                            "type": "tool_use",
                            "id": id,
                            "name": name,
                            "input": input
                        ])
                    }
                }
                anthropicMessages.append([
                    "role": "assistant",
                    "content": contentBlocks
                ])
                continue
            }
            
            if role == "tool" {
                let toolCallId = message["tool_call_id"] as? String ?? UUID().uuidString
                let output = message["content"] as? String ?? ""
                anthropicMessages.append([
                    "role": "user",
                    "content": [
                        [
                            "type": "tool_result",
                            "tool_use_id": toolCallId,
                            "content": output
                        ]
                    ]
                ])
                continue
            }
            
            let content = message["content"] as? String ?? ""
            var blocks: [[String: Any]] = [
                ["type": "text", "text": content]
            ]
            
            if role == "user", !images.isEmpty {
                blocks.append(contentsOf: images.map { data in
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/png",
                            "data": data.base64EncodedString()
                        ]
                    ]
                })
            }
            
            anthropicMessages.append([
                "role": role == "assistant" ? "assistant" : "user",
                "content": blocks
            ])
        }
        
        return (systemParts.joined(separator: "\n\n"), anthropicMessages)
    }
    
    private static func anthropicTools(from tools: [[String: Any]]) -> [[String: Any]] {
        tools.compactMap { tool in
            guard let function = tool["function"] as? [String: Any],
                  let name = function["name"] as? String else { return nil }
            let description = function["description"] as? String ?? ""
            let parameters = function["parameters"] as? [String: Any] ?? [:]
            return [
                "name": name,
                "description": description,
                "input_schema": parameters
            ]
        }
    }
    
    // MARK: - Gemini
    
    private static func chatGemini(
        baseURL: String,
        apiKey: String,
        model: String,
        messages: [[String: Any]],
        tools: [[String: Any]]?,
        temperature: Double,
        maxTokens: Int,
        images: [Data]
    ) async throws -> ChatResult {
        guard let url = URL(string: "\(baseURL)/models/\(model):generateContent?key=\(apiKey)") else {
            throw ExternalError.invalidURL
        }
        
        let (systemInstruction, contents) = buildGeminiMessages(messages: messages, images: images)
        
        var body: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "temperature": temperature,
                "maxOutputTokens": maxTokens
            ]
        ]
        if !systemInstruction.isEmpty {
            body["systemInstruction"] = [
                "parts": [["text": systemInstruction]]
            ]
        }
        if let tools, !tools.isEmpty {
            body["tools"] = [
                [
                    "functionDeclarations": geminiTools(from: tools)
                ]
            ]
            body["toolConfig"] = [
                "functionCallingConfig": ["mode": "AUTO"]
            ]
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ExternalError.badResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw ExternalError.invalidResponse
        }
        
        var contentText = ""
        var toolCalls: [ToolCall] = []
        for part in parts {
            if let text = part["text"] as? String {
                contentText += text
            } else if let functionCall = part["functionCall"] as? [String: Any] {
                let name = functionCall["name"] as? String ?? "tool"
                let args = functionCall["args"] as? [String: Any] ?? [:]
                let dict: [String: Any] = [
                    "id": UUID().uuidString,
                    "function": [
                        "name": name,
                        "arguments": args
                    ]
                ]
                if let call = ToolCall(from: dict) {
                    toolCalls.append(call)
                }
            }
        }
        
        var usage: Usage? = nil
        if let usageDict = json["usageMetadata"] as? [String: Any] {
            let inputTokens = usageDict["promptTokenCount"] as? Int ?? 0
            let outputTokens = usageDict["candidatesTokenCount"] as? Int ?? 0
            usage = Usage(inputTokens: inputTokens, outputTokens: outputTokens)
        }
        
        return ChatResult(
            content: contentText.isEmpty ? nil : contentText,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls,
            usage: usage
        )
    }
    
    private static func buildGeminiMessages(
        messages: [[String: Any]],
        images: [Data]
    ) -> (systemInstruction: String, contents: [[String: Any]]) {
        var systemParts: [String] = []
        var contents: [[String: Any]] = []
        var toolNameById: [String: String] = [:]
        
        for message in messages {
            guard let role = message["role"] as? String else { continue }
            
            if role == "system" {
                if let content = message["content"] as? String, !content.isEmpty {
                    systemParts.append(content)
                }
                continue
            }
            
            if let toolCalls = message["tool_calls"] as? [[String: Any]] {
                var parts: [[String: Any]] = []
                for call in toolCalls {
                    let id = call["id"] as? String ?? UUID().uuidString
                    if let function = call["function"] as? [String: Any],
                       let name = function["name"] as? String {
                        toolNameById[id] = name
                        let args = parseArguments(function["arguments"])
                        parts.append([
                            "functionCall": [
                                "name": name,
                                "args": args
                            ]
                        ])
                    }
                }
                contents.append([
                    "role": "model",
                    "parts": parts
                ])
                continue
            }
            
            if role == "tool" {
                let toolCallId = message["tool_call_id"] as? String ?? UUID().uuidString
                let toolName = toolNameById[toolCallId] ?? "tool"
                let output = message["content"] as? String ?? ""
                contents.append([
                    "role": "user",
                    "parts": [
                        [
                            "functionResponse": [
                                "name": toolName,
                                "response": [
                                    "content": output
                                ]
                            ]
                        ]
                    ]
                ])
                continue
            }
            
            let content = message["content"] as? String ?? ""
            var parts: [[String: Any]] = [["text": content]]
            
            if role == "user", !images.isEmpty {
                parts.append(contentsOf: images.map { data in
                    [
                        "inline_data": [
                            "mime_type": "image/png",
                            "data": data.base64EncodedString()
                        ]
                    ]
                })
            }
            
            contents.append([
                "role": role == "assistant" ? "model" : "user",
                "parts": parts
            ])
        }
        
        return (systemParts.joined(separator: "\n\n"), contents)
    }
    
    private static func geminiTools(from tools: [[String: Any]]) -> [[String: Any]] {
        tools.compactMap { tool in
            guard let function = tool["function"] as? [String: Any],
                  let name = function["name"] as? String else { return nil }
            let description = function["description"] as? String ?? ""
            let parameters = function["parameters"] as? [String: Any] ?? [:]
            return [
                "name": name,
                "description": description,
                "parameters": parameters
            ]
        }
    }
    
    // MARK: - Cohere
    
    private static func chatCohere(
        baseURL: String,
        apiKey: String,
        model: String,
        messages: [[String: Any]],
        temperature: Double,
        maxTokens: Int,
        authHeader: String,
        authPrefix: String
    ) async throws -> ChatResult {
        guard let url = URL(string: "\(baseURL)/chat") else {
            throw ExternalError.invalidURL
        }
        
        let history = cohereHistory(from: messages)
        let lastUser = history.last { $0["role"] as? String == "USER" }
        let message = lastUser?["message"] as? String ?? ""
        
        let body: [String: Any] = [
            "model": model,
            "message": message,
            "temperature": temperature,
            "max_tokens": maxTokens,
            "chat_history": Array(history.dropLast())
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let authValue = authPrefix.isEmpty ? apiKey : "\(authPrefix) \(apiKey)"
        if !authHeader.isEmpty {
            request.setValue(authValue, forHTTPHeaderField: authHeader)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ExternalError.badResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ExternalError.invalidResponse
        }
        
        let content = json["text"] as? String
        var usage: Usage? = nil
        if let meta = json["meta"] as? [String: Any],
           let tokens = meta["tokens"] as? [String: Any] {
            let inputTokens = tokens["input_tokens"] as? Int ?? 0
            let outputTokens = tokens["output_tokens"] as? Int ?? 0
            usage = Usage(inputTokens: inputTokens, outputTokens: outputTokens)
        }
        
        return ChatResult(content: content, toolCalls: nil, usage: usage)
    }
    
    private static func cohereHistory(from messages: [[String: Any]]) -> [[String: Any]] {
        var history: [[String: Any]] = []
        for message in messages {
            guard let role = message["role"] as? String else { continue }
            let content = message["content"] as? String ?? ""
            if role == "user" {
                history.append(["role": "USER", "message": content])
            } else if role == "assistant" {
                history.append(["role": "CHATBOT", "message": content])
            }
        }
        return history
    }
}
