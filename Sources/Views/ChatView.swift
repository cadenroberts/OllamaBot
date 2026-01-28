import SwiftUI
import UniformTypeIdentifiers

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @State private var inputText = ""
    @State private var attachedImages: [Data] = []
    @State private var isDragOver = false
    @State private var showFilePicker = false
    @State private var showMentionSuggestions = false
    @State private var mentionSuggestions: [MentionService.MentionSuggestion] = []
    @State private var parsedMentions: [MentionService.Mention] = []
    @State private var selectedSuggestionIndex = 0
    @State private var contextBreakdown: ContextBreakdown?
    @State private var showContextBreakdown = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            DSDivider()
            messageList
            DSDivider()
            
            // Context bar with mentions and token indicator
            contextBar
            
            if !appState.mentionedFiles.isEmpty {
                mentionedFilesBar
            }
            
            if !attachedImages.isEmpty {
                attachedImagesBar
            }
            
            // Input with mention autocomplete
            ZStack(alignment: .bottom) {
                inputBar
                
                // Mention autocomplete popup
                if showMentionSuggestions && !mentionSuggestions.isEmpty {
                    mentionAutocomplete
                        .offset(y: -60)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onDrop(of: [.image], isTargeted: $isDragOver) { providers in
            handleImageDrop(providers)
            return true
        }
        .sheet(isPresented: $showFilePicker) {
            FileMentionPicker(isPresented: $showFilePicker)
        }
        .onChange(of: inputText) { _, newValue in
            updateMentionSuggestions(newValue)
            updateParsedMentions(newValue)
            updateContextBreakdown()
        }
    }
    
    // MARK: - Header
    
    private var chatHeader: some View {
        HStack(spacing: DS.Spacing.md) {
            DSLogo(size: 24)
            
            Text("Chat")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.text)
            
            Spacer()
            
            ModelSelectorView()
            
            DSIconButton(icon: "trash", color: DS.Colors.tertiaryText) {
                appState.chatMessages.removeAll()
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
    }
    
    // MARK: - Messages (Optimized)
    
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DS.Spacing.md) {
                    // Use stable identity - MessageRow is Equatable for efficient diffing
                    ForEach(appState.chatMessages) { message in
                        MessageRow(message: message)
                            .id(message.id)
                    }
                    
                    if appState.isGenerating {
                        generatingIndicator
                            .transition(.opacity.animation(DS.Animation.fast))
                    }
                }
                .padding(DS.Spacing.md)
            }
            // Throttle scroll updates during generation
            .onChange(of: appState.chatMessages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: appState.chatMessages.last?.content.count ?? 0) { oldCount, newCount in
                // Only scroll on significant content changes (every ~200 chars)
                if newCount - oldCount > 200 || !appState.isGenerating {
                    scrollToBottom(proxy: proxy)
                }
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = appState.chatMessages.last {
            withAnimation(DS.Animation.fast) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
    
    private var generatingIndicator: some View {
        HStack(spacing: DS.Spacing.sm) {
            DSLoadingSpinner(size: 14)
            Text("Generating...")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.sm)
    }
    
    // MARK: - Context Bar
    
    private var contextBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Parsed @mentions
            if !parsedMentions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(parsedMentions) { mention in
                            MentionChipView(mention: mention) {
                                removeMention(mention)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Context token indicator
            if let breakdown = contextBreakdown {
                Button {
                    showContextBreakdown.toggle()
                } label: {
                    ContextBadge(
                        usedTokens: breakdown.totalTokens,
                        maxTokens: breakdown.maxTokens
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showContextBreakdown, arrowEdge: .top) {
                    ContextBreakdownView(breakdown: breakdown)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.secondaryBackground)
    }
    
    // MARK: - Mention Autocomplete
    
    private var mentionAutocomplete: some View {
        VStack(spacing: 0) {
            ForEach(Array(mentionSuggestions.prefix(8).enumerated()), id: \.element.id) { index, suggestion in
                Button {
                    insertMention(suggestion)
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: suggestion.icon)
                            .font(.caption)
                            .frame(width: 20)
                            .foregroundStyle(DS.Colors.accent)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.displayName)
                                .font(DS.Typography.callout)
                            
                            if let subtitle = suggestion.subtitle {
                                Text(subtitle)
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        Text(suggestion.fullText)
                            .font(DS.Typography.mono(10))
                            .foregroundStyle(DS.Colors.tertiaryText)
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(index == selectedSuggestionIndex ? DS.Colors.accent.opacity(0.1) : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 400)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.border, lineWidth: 1)
        )
        .shadow(color: DS.Colors.background.opacity(0.5), radius: 8, y: -4)
        .padding(.horizontal, DS.Spacing.md)
    }
    
    // MARK: - Mentioned Files
    
    private var mentionedFilesBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(appState.mentionedFiles) { file in
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: file.icon)
                        Text(file.name)
                        DSIconButton(icon: "xmark", size: 12) {
                            appState.mentionedFiles.removeAll { $0.id == file.id }
                        }
                    }
                    .font(DS.Typography.caption)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.info.opacity(0.15))
                    .foregroundStyle(DS.Colors.info)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
        .background(DS.Colors.secondaryBackground)
    }
    
    // MARK: - Attached Images
    
    private var attachedImagesBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(Array(attachedImages.enumerated()), id: \.offset) { index, data in
                    if let image = NSImage(data: data) {
                        ZStack(alignment: .topTrailing) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                            
                            Button(action: { attachedImages.remove(at: index) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white, .red)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .offset(x: 4, y: -4)
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
        .background(DS.Colors.secondaryBackground)
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
            // Attach buttons
            HStack(spacing: DS.Spacing.xs) {
                DSIconButton(icon: "photo.badge.plus", size: 24) {
                    attachImage()
                }
                
                DSIconButton(icon: "at", size: 24) {
                    showFilePicker = true
                }
            }
            
            // Text input with keyboard navigation for mentions
            TextEditor(text: $inputText)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 36, maxHeight: 100)
                .padding(DS.Spacing.sm)
                .background(DS.Colors.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .focused($isInputFocused)
                .onKeyPress(.upArrow) {
                    if showMentionSuggestions {
                        selectedSuggestionIndex = max(0, selectedSuggestionIndex - 1)
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.downArrow) {
                    if showMentionSuggestions {
                        selectedSuggestionIndex = min(mentionSuggestions.count - 1, selectedSuggestionIndex + 1)
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.tab) {
                    if showMentionSuggestions && !mentionSuggestions.isEmpty {
                        insertMention(mentionSuggestions[selectedSuggestionIndex])
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.return) {
                    if showMentionSuggestions && !mentionSuggestions.isEmpty {
                        insertMention(mentionSuggestions[selectedSuggestionIndex])
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.escape) {
                    if showMentionSuggestions {
                        showMentionSuggestions = false
                        mentionSuggestions = []
                        return .handled
                    }
                    return .ignored
                }
            
            // Send button
            Button(action: sendMessage) {
                Image(systemName: appState.isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(canSend ? DS.Colors.accent : DS.Colors.secondaryText)
            }
            .buttonStyle(.plain)
            .disabled(!canSend && !appState.isGenerating)
        }
        .padding(DS.Spacing.md)
    }
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !appState.isGenerating
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        guard canSend else { return }
        let message = inputText
        let images = attachedImages
        inputText = ""
        attachedImages = []
        parsedMentions = []
        showMentionSuggestions = false
        
        // Resolve mentions and send with enhanced context
        Task {
            let (cleanText, mentionContext, _) = await appState.mentionService.resolveAllMentions(
                in: message,
                projectRoot: appState.rootFolder,
                selectedText: appState.selectedText
            )
            
            // Combine user message with mention context
            let enhancedMessage = mentionContext.isEmpty ? cleanText : "\(cleanText)\n\n---\nContext:\n\(mentionContext)"
            
            await appState.sendMessage(enhancedMessage, images: images)
        }
    }
    
    // MARK: - Mention Handling
    
    private func updateMentionSuggestions(_ text: String) {
        // Check for @ trigger
        guard let lastAt = text.lastIndex(of: "@") else {
            showMentionSuggestions = false
            mentionSuggestions = []
            return
        }
        
        let afterAt = String(text[text.index(after: lastAt)...])
        
        // Don't show if there's a space after a complete mention
        if afterAt.contains(" ") && !afterAt.contains(":") {
            showMentionSuggestions = false
            mentionSuggestions = []
            return
        }
        
        // Update suggestions from MentionService
        appState.mentionService.updateSuggestions(
            for: text,
            cursorPosition: text.count,
            projectRoot: appState.rootFolder
        )
        
        mentionSuggestions = appState.mentionService.suggestions
        showMentionSuggestions = appState.mentionService.isShowingSuggestions
        selectedSuggestionIndex = 0
    }
    
    private func updateParsedMentions(_ text: String) {
        parsedMentions = appState.mentionService.parseMentions(in: text)
    }
    
    private func insertMention(_ suggestion: MentionService.MentionSuggestion) {
        // Find the @ position and replace with full mention
        if let lastAt = inputText.lastIndex(of: "@") {
            inputText = String(inputText[..<lastAt]) + suggestion.fullText + " "
        }
        
        showMentionSuggestions = false
        mentionSuggestions = []
    }
    
    private func removeMention(_ mention: MentionService.Mention) {
        // Remove the mention text from input
        inputText = inputText.replacingOccurrences(of: mention.displayText, with: "")
        updateParsedMentions(inputText)
    }
    
    private func updateContextBreakdown() {
        let memSettings = appState.modelTierManager.getMemorySettings()
        
        contextBreakdown = ContextBreakdown.calculate(
            systemPrompt: "System prompt placeholder", // Would get from ContextManager
            projectRules: appState.obotService.projectRules?.content,
            conversationHistory: appState.chatMessages,
            mentionContent: parsedMentions.isEmpty ? nil : "Mentions: \(parsedMentions.count)",
            userInput: inputText,
            maxTokens: memSettings.contextWindow
        )
    }
    
    private func attachImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let data = try? Data(contentsOf: url) {
                    attachedImages.append(data)
                }
            }
        }
    }
    
    private func handleImageDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                if let data = data {
                    DispatchQueue.main.async { attachedImages.append(data) }
                }
            }
        }
    }
}

// MARK: - Message Row

// MARK: - Optimized Message Row
// Performance: Parse content only when message.content changes

struct MessageRow: View, Equatable {
    let message: ChatMessage
    
    // Equatable: Only re-render when content actually changes
    static func == (lhs: MessageRow, rhs: MessageRow) -> Bool {
        lhs.message.id == rhs.message.id &&
        lhs.message.content == rhs.message.content
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            if message.isUser { Spacer(minLength: 40) }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: DS.Spacing.xs) {
                // Header (lightweight, static)
                messageHeader
                
                // Images (only if present)
                if !message.images.isEmpty {
                    imageGrid
                }
                
                // Content
                if message.isUser {
                    userBubble
                } else {
                    assistantBubble
                }
            }
            
            if !message.isUser { Spacer(minLength: 40) }
        }
    }
    
    private var assistantBubble: some View {
        AssistantContentView(content: message.content)
            .padding(DS.Spacing.sm)
            .background(DS.Colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(DS.Colors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }
    
    private var messageHeader: some View {
        HStack(spacing: DS.Spacing.xs) {
            if !message.isUser, let model = message.model {
                Image(systemName: model.icon)
                    .foregroundStyle(model.color)
                Text(model.displayName)
                    .foregroundStyle(DS.Colors.secondaryText)
            } else if message.isUser {
                Text("You")
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            
            Text(message.formattedTime)
                .foregroundStyle(DS.Colors.tertiaryText)
        }
        .font(DS.Typography.caption2)
    }
    
    private var imageGrid: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(Array(message.images.enumerated()), id: \.offset) { _, data in
                if let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 120)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
            }
        }
    }
    
    private var userBubble: some View {
        Text(message.content)
            .textSelection(.enabled)
            .padding(DS.Spacing.md)
            .background(DS.Colors.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }
}

// Separate view for assistant content - isolates expensive parsing
struct AssistantContentView: View, Equatable {
    let content: String
    
    // Cache parsed blocks to avoid re-parsing on every render
    @State private var parsedBlocks: [ContentBlock] = []
    @State private var lastParsedContent: String = ""
    
    static func == (lhs: AssistantContentView, rhs: AssistantContentView) -> Bool {
        lhs.content == rhs.content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(Array(parsedBlocks.enumerated()), id: \.offset) { index, block in
                switch block {
                case .text(let text):
                    TextBlockView(text: text)
                    
                case .code(let lang, let code):
                    CodeBlock(language: lang, code: code)
                        .id("code-\(index)")
                }
            }
        }
        .onChange(of: content, initial: true) { _, newContent in
            // Only re-parse if content actually changed
            if newContent != lastParsedContent {
                parsedBlocks = Self.parseContent(newContent)
                lastParsedContent = newContent
            }
        }
    }
    
    // Static parsing function (no self reference = can be optimized by compiler)
    private static func parseContent(_ text: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        var remaining = text
        
        while true {
            guard let start = remaining.range(of: "```") else {
                if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(.text(remaining))
                }
                break
            }
            
            let textBefore = String(remaining[..<start.lowerBound])
            if !textBefore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(.text(textBefore))
            }
            
            let afterStart = remaining[start.upperBound...]
            guard let end = afterStart.range(of: "```") else {
                blocks.append(.text(String(remaining[start.lowerBound...])))
                break
            }
            
            let codeSection = String(afterStart[..<end.lowerBound])
            let lines = codeSection.components(separatedBy: .newlines)
            let lang = lines.first?.trimmingCharacters(in: .whitespaces) ?? ""
            let code = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            
            blocks.append(.code(language: lang, content: code))
            remaining = String(afterStart[end.upperBound...])
        }
        
        return blocks
    }
}

// Lightweight text block with cached markdown parsing
struct TextBlockView: View {
    let text: String
    
    var body: some View {
        Text(parsedMarkdown)
            .textSelection(.enabled)
            .foregroundStyle(DS.Colors.text)
            .padding(DS.Spacing.sm)
    }
    
    private var parsedMarkdown: AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}

enum ContentBlock {
    case text(String)
    case code(language: String, content: String)
}

// MARK: - Code Block

struct CodeBlock: View {
    @Environment(AppState.self) private var appState
    let language: String
    let code: String
    
    @State private var isHovered = false
    @State private var showCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                if !language.isEmpty {
                    Text(language)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                
                Spacer()
                
                if isHovered {
                    HStack(spacing: DS.Spacing.sm) {
                        Button(action: copyCode) {
                            HStack(spacing: DS.Spacing.xxs) {
                                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                Text(showCopied ? "Copied" : "Copy")
                            }
                            .font(DS.Typography.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Menu {
                            Button("Replace Selection") { appState.applyCodeToEditor(code, replace: false) }
                            Button("Replace File") { appState.applyCodeToEditor(code, replace: true) }
                            Divider()
                            Button("Create New File") {
                                appState.createNewFile()
                                appState.editorContent = code
                            }
                        } label: {
                            HStack(spacing: DS.Spacing.xxs) {
                                Image(systemName: "square.and.arrow.down")
                                Text("Apply")
                            }
                            .font(DS.Typography.caption)
                        }
                        .menuStyle(.borderlessButton)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.codeBorder)
            
            // Code
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(DS.Typography.mono(12))
                    .textSelection(.enabled)
                    .padding(DS.Spacing.md)
            }
        }
        .background(DS.Colors.codeBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .onHover { isHovered = $0 }
    }
    
    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showCopied = false }
    }
}

// MARK: - File Mention Picker

struct FileMentionPicker: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var files: [FileItem] = []
    
    private var filtered: [FileItem] {
        if searchText.isEmpty { return Array(files.prefix(50)) }
        return files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }.prefix(50).map { $0 }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Include files in context")
                    .font(DS.Typography.headline)
                Spacer()
                DSButton("Done", style: .primary) { isPresented = false }
            }
            .padding(DS.Spacing.md)
            
            DSTextField(placeholder: "Search...", text: $searchText, icon: "magnifyingglass")
                .padding(.horizontal, DS.Spacing.md)
            
            List(filtered) { file in
                HStack {
                    Image(systemName: file.icon)
                        .foregroundStyle(file.iconColor)
                    Text(file.name)
                    Spacer()
                    if appState.mentionedFiles.contains(where: { $0.id == file.id }) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(DS.Colors.accent)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { toggleFile(file) }
            }
        }
        .frame(width: 400, height: 450)
        .onAppear { loadFiles() }
    }
    
    private func loadFiles() {
        guard let root = appState.rootFolder else { return }
        files = appState.fileSystemService.getAllFiles(in: root)
    }
    
    private func toggleFile(_ file: FileItem) {
        if let idx = appState.mentionedFiles.firstIndex(where: { $0.id == file.id }) {
            appState.mentionedFiles.remove(at: idx)
        } else {
            appState.mentionedFiles.append(file)
        }
    }
}
