import Foundation
import SwiftUI

// MARK: - Inline Completion Service (Cursor Tab / Copilot style)

@Observable
class InlineCompletionService {
    private let ollamaService: OllamaService
    
    // State
    var currentSuggestion: InlineSuggestion?
    var isLoading = false
    
    // Debouncing
    private var debounceTask: Task<Void, Never>?
    private let debounceDelay: UInt64 = 300_000_000 // 300ms
    
    // Cache for recent completions
    private let completionCache = LRUCache<String, String>(capacity: 50)
    
    init(ollamaService: OllamaService) {
        self.ollamaService = ollamaService
    }
    
    // MARK: - Public API
    
    /// Request completion for current cursor position
    func requestCompletion(
        code: String,
        cursorPosition: Int,
        language: String,
        filePath: String?
    ) {
        // Cancel previous request
        debounceTask?.cancel()
        
        // Create cache key
        let prefix = String(code.prefix(cursorPosition))
        let cacheKey = "\(language):\(prefix.suffix(100))"
        
        // Check cache first
        if let cached = completionCache.get(cacheKey) {
            self.currentSuggestion = InlineSuggestion(
                text: cached,
                range: cursorPosition..<cursorPosition,
                confidence: 0.9
            )
            return
        }
        
        // Debounce the request
        debounceTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                try await Task.sleep(nanoseconds: debounceDelay)
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run { self.isLoading = true }
                
                let suggestion = try await self.generateCompletion(
                    code: code,
                    cursorPosition: cursorPosition,
                    language: language,
                    filePath: filePath
                )
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.currentSuggestion = suggestion
                    self.isLoading = false
                    
                    // Cache the result
                    if let text = suggestion?.text {
                        self.completionCache.set(cacheKey, text)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Accept the current suggestion
    func acceptSuggestion() -> String? {
        defer { currentSuggestion = nil }
        return currentSuggestion?.text
    }
    
    /// Dismiss current suggestion
    func dismissSuggestion() {
        currentSuggestion = nil
        debounceTask?.cancel()
    }
    
    /// Accept partial suggestion (word by word)
    func acceptNextWord() -> String? {
        guard let suggestion = currentSuggestion else { return nil }
        
        // Find next word boundary
        let text = suggestion.text
        if let spaceIndex = text.firstIndex(of: " ") {
            let word = String(text[..<spaceIndex]) + " "
            
            // Update suggestion to remaining text
            let remaining = String(text[text.index(after: spaceIndex)...])
            if remaining.isEmpty {
                currentSuggestion = nil
            } else {
                currentSuggestion = InlineSuggestion(
                    text: remaining,
                    range: suggestion.range,
                    confidence: suggestion.confidence
                )
            }
            
            return word
        } else {
            // Accept entire remaining suggestion
            currentSuggestion = nil
            return text
        }
    }
    
    // MARK: - Private
    
    private func generateCompletion(
        code: String,
        cursorPosition: Int,
        language: String,
        filePath: String?
    ) async throws -> InlineSuggestion? {
        // Extract context around cursor
        let prefix = String(code.prefix(cursorPosition))
        let suffix = String(code.suffix(from: code.index(code.startIndex, offsetBy: min(cursorPosition, code.count))))
        
        // Get last N lines before cursor for context
        let prefixLines = prefix.components(separatedBy: .newlines).suffix(20)
        let contextBefore = prefixLines.joined(separator: "\n")
        
        // Get next few lines after cursor
        let suffixLines = suffix.components(separatedBy: .newlines).prefix(5)
        let contextAfter = suffixLines.joined(separator: "\n")
        
        // Build the prompt
        let prompt = """
        You are an expert code completion assistant. Complete the code at the cursor position marked with <CURSOR>.
        
        Language: \(language)
        File: \(filePath ?? "unknown")
        
        Context before cursor:
        ```\(language)
        \(contextBefore)<CURSOR>
        ```
        
        Context after cursor:
        ```\(language)
        \(contextAfter)
        ```
        
        Rules:
        1. Only output the completion text, nothing else
        2. Complete the current line or statement naturally
        3. Match the existing code style and indentation
        4. Be concise - usually 1-3 lines max
        5. If no completion makes sense, output nothing
        
        Completion:
        """
        
        // Use the coding model for completions
        let response = try await ollamaService.generate(
            prompt: prompt,
            model: .coder,
            useCache: true
        )
        
        let completion = response.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        // Validate the completion
        guard !completion.isEmpty,
              completion.count < 500, // Sanity check
              !completion.contains("```") // Filter out markdown artifacts
        else {
            return nil
        }
        
        return InlineSuggestion(
            text: completion,
            range: cursorPosition..<cursorPosition,
            confidence: 0.8
        )
    }
}

// MARK: - Inline Suggestion Model

struct InlineSuggestion: Equatable {
    let text: String
    let range: Range<Int>
    let confidence: Double
    
    var displayText: String {
        // Truncate for display
        if text.count > 100 {
            return String(text.prefix(100)) + "..."
        }
        return text
    }
}

// MARK: - Inline Completion Overlay View

struct InlineCompletionOverlay: View {
    let suggestion: InlineSuggestion?
    let onAccept: () -> Void
    let onDismiss: () -> Void
    let onAcceptWord: () -> Void
    
    var body: some View {
        if let suggestion = suggestion {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Ghost text preview
                Text(suggestion.displayText)
                    .font(DS.Typography.mono(12))
                    .foregroundStyle(DS.Colors.secondaryText.opacity(0.6))
                    .italic()
                
                // Keyboard hints
                HStack(spacing: DS.Spacing.md) {
                    KeyboardHint(key: "Tab", action: "Accept")
                    KeyboardHint(key: "⌥→", action: "Accept Word")
                    KeyboardHint(key: "Esc", action: "Dismiss")
                }
            }
            .padding(DS.Spacing.sm)
            .background(DS.Colors.surface.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .shadow(color: DS.Shadow.sm, radius: 4)
        }
    }
}

struct KeyboardHint: View {
    let key: String
    let action: String
    
    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            Text(key)
                .font(DS.Typography.mono(10))
                .padding(.horizontal, DS.Spacing.xs)
                .padding(.vertical, 2)
                .background(DS.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            
            Text(action)
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.tertiaryText)
        }
    }
}
