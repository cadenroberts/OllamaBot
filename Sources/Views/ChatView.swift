import SwiftUI
import UniformTypeIdentifiers

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @State private var inputText = ""
    @State private var attachedImages: [Data] = []
    @State private var isDragOver = false
    @State private var showFilePicker = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            DSDivider()
            messageList
            DSDivider()
            
            if !appState.mentionedFiles.isEmpty {
                mentionedFilesBar
            }
            
            if !attachedImages.isEmpty {
                attachedImagesBar
            }
            
            inputBar
        }
        .onDrop(of: [.image], isTargeted: $isDragOver) { providers in
            handleImageDrop(providers)
            return true
        }
        .sheet(isPresented: $showFilePicker) {
            FileMentionPicker(isPresented: $showFilePicker)
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
    
    // MARK: - Messages
    
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DS.Spacing.md) {
                    ForEach(appState.chatMessages) { message in
                        MessageRow(message: message)
                            .id(message.id)
                    }
                    
                    if appState.isGenerating {
                        generatingIndicator
                    }
                }
                .padding(DS.Spacing.md)
            }
            .onChange(of: appState.chatMessages.count) { _, _ in
                if let last = appState.chatMessages.last {
                    withAnimation(DS.Animation.fast) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
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
            
            // Text input
            TextEditor(text: $inputText)
                .font(DS.Typography.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 36, maxHeight: 100)
                .padding(DS.Spacing.sm)
                .background(DS.Colors.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .focused($isInputFocused)
            
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
        
        Task { await appState.sendMessage(message, images: images) }
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

struct MessageRow: View {
    @Environment(AppState.self) private var appState
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            if message.isUser { Spacer(minLength: 40) }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: DS.Spacing.xs) {
                // Header
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
                
                // Images
                if !message.images.isEmpty {
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
                
                // Content
                if message.isUser {
                    userBubble
                } else {
                    assistantContent
                }
            }
            
            if !message.isUser { Spacer(minLength: 40) }
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
    
    private var assistantContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(Array(parseContent().enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let content):
                    Text(parseMarkdown(content))
                        .textSelection(.enabled)
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    
                case .code(let lang, let code):
                    CodeBlock(language: lang, code: code)
                }
            }
        }
    }
    
    private enum ContentBlock {
        case text(String)
        case code(language: String, content: String)
    }
    
    private func parseContent() -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        var remaining = message.content
        
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
    
    private func parseMarkdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
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
