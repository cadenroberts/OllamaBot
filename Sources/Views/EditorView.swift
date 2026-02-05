import SwiftUI
import AppKit

struct EditorView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
        Group {
            if let file = appState.selectedFile {
                CodeEditorWithLineNumbers(file: file, content: $state.editorContent, goToLine: $state.goToLine)
            } else {
                WelcomeView()
            }
        }
    }
}

// MARK: - Code Editor with Line Numbers

struct CodeEditorWithLineNumbers: View {
    @Environment(AppState.self) private var appState
    let file: FileItem
    @Binding var content: String
    @Binding var goToLine: Int?
    
    private var lines: [String] {
        content.components(separatedBy: .newlines)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    // Line numbers gutter
                    if appState.config.showLineNumbers {
                        lineNumberGutter
                    }
                    
                    // Editor
                    CodeEditor(
                        file: file,
                        content: $content,
                        goToLine: $goToLine,
                        onRequestCompletion: { code, cursor, lang, path in
                            appState.inlineCompletionService.requestCompletion(
                                code: code,
                                cursorPosition: cursor,
                                language: lang,
                                filePath: path
                            )
                        }
                    )
                }
                
                // Inline completion overlay
                if let suggestion = appState.inlineCompletionService.currentSuggestion {
                    InlineCompletionOverlay(
                        suggestion: suggestion,
                        onAccept: {
                            if let text = appState.inlineCompletionService.acceptSuggestion() {
                                // Insert at cursor - simplified: just append
                                content.insert(contentsOf: text, at: content.index(content.startIndex, offsetBy: min(suggestion.range.lowerBound, content.count)))
                            }
                        },
                        onDismiss: {
                            appState.inlineCompletionService.dismissSuggestion()
                        },
                        onAcceptWord: {
                            if let word = appState.inlineCompletionService.acceptNextWord() {
                                content.insert(contentsOf: word, at: content.index(content.startIndex, offsetBy: min(suggestion.range.lowerBound, content.count)))
                            }
                        }
                    )
                    .offset(x: gutterWidth + 16, y: 60) // Position near cursor
                }
            }
        }
    }
    
    private var lineNumberGutter: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
                    Text("\(index + 1)")
                        .font(DS.Typography.mono(appState.config.editorFontSize))
                        .foregroundStyle(DS.Colors.lineNumbers)
                        .padding(.horizontal, DS.Spacing.sm)
                        .frame(height: lineHeight)
                }
            }
            .padding(.top, 8) // Match editor padding
        }
        .frame(width: gutterWidth)
        .background(DS.Colors.codeBackground.opacity(0.5))
    }
    
    private var gutterWidth: CGFloat {
        let digits = String(lines.count).count
        return CGFloat(digits * 10 + 24)
    }
    
    private var lineHeight: CGFloat {
        appState.config.editorFontSize * 1.4
    }
}

// MARK: - Code Editor

struct CodeEditor: NSViewRepresentable {
    @Environment(AppState.self) private var appState
    let file: FileItem
    @Binding var content: String
    @Binding var goToLine: Int?
    
    // Inline completion callback
    var onRequestCompletion: ((String, Int, String, String?) -> Void)?
    
    private let highlighter = SyntaxHighlighter(theme: .dark)
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        // Custom scrollbars to match DS styling
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.verticalScroller = DSScroller()
        scrollView.horizontalScroller = DSScroller()
        
        // Configure text view
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        
        // Appearance
        textView.backgroundColor = NSColor(DS.Colors.codeBackground)
        textView.insertionPointColor = .white
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.white.withAlphaComponent(0.2)
        ]
        
        // Font
        let fontSize = appState.config.editorFontSize
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.typingAttributes = [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: NSColor.white
        ]
        
        context.coordinator.textView = textView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        // Only update if content changed externally
        if textView.string != content {
            let selectedRange = textView.selectedRange()
            let language = file.url.pathExtension
            let attributed = highlighter.highlight(content, language: language)
            textView.textStorage?.setAttributedString(attributed)
            
            if selectedRange.location <= content.count {
                textView.setSelectedRange(selectedRange)
            }
        }
        
        // Handle go to line
        if let line = goToLine {
            scrollToLine(line, in: textView)
            DispatchQueue.main.async { goToLine = nil }
        }
        
        // Update font if changed
        let fontSize = appState.config.editorFontSize
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }
    
    private func scrollToLine(_ line: Int, in textView: NSTextView) {
        let lines = content.components(separatedBy: .newlines)
        guard line > 0 && line <= lines.count else { return }
        
        var charIndex = 0
        for i in 0..<(line - 1) {
            charIndex += lines[i].count + 1 // +1 for newline
        }
        
        let range = NSRange(location: charIndex, length: lines[line - 1].count)
        textView.scrollRangeToVisible(range)
        textView.setSelectedRange(NSRange(location: charIndex, length: 0))
        textView.window?.makeFirstResponder(textView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: CodeEditor
        weak var textView: NSTextView?
        private var debounceTask: Task<Void, Never>?
        
        init(_ parent: CodeEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Update content binding
            parent.content = textView.string
            parent.file.isModified = true
            
            // Debounce syntax highlighting
            debounceTask?.cancel()
            debounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                
                let language = parent.file.url.pathExtension
                let attributed = parent.highlighter.highlight(textView.string, language: language)
                
                let selection = textView.selectedRange()
                textView.textStorage?.setAttributedString(attributed)
                textView.setSelectedRange(selection)
                
                // Trigger inline completion request
                parent.onRequestCompletion?(
                    textView.string,
                    selection.location,
                    language,
                    parent.file.url.path
                )
            }
        }
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            // Logo
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "cpu")
                    .font(.system(size: 64))
                    .foregroundStyle(DS.Colors.accent)
                
                Text("OllamaBot")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                
                Text("Local AI-Powered IDE")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            
            // Quick Actions & Models - same width container
            VStack(spacing: DS.Spacing.lg) {
                // Quick Actions
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Quick Start")
                        .font(DS.Typography.caption.weight(.semibold))
                        .foregroundStyle(DS.Colors.secondaryText)
                    
                    quickAction(icon: "folder", title: "Open Folder", shortcut: "⌘O") {
                        appState.openFolder()
                    }
                    
                    quickAction(icon: "infinity", title: "Infinite Mode", shortcut: "⌘⇧I") {
                        appState.showInfiniteMode = true
                    }
                    
                    quickAction(icon: "magnifyingglass", title: "Quick Open", shortcut: "⌘P") {
                        appState.showQuickOpen = true
                    }
                    
                    quickAction(icon: "terminal", title: "Toggle Terminal", shortcut: "⌃`") {
                        appState.showTerminal.toggle()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.lg)
                .background(DS.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                
                // Models
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Available Models")
                        .font(DS.Typography.caption.weight(.semibold))
                        .foregroundStyle(DS.Colors.secondaryText)
                    
                    HStack(spacing: DS.Spacing.sm) {
                        modelBadge("Qwen3", DS.Colors.orchestrator, "Writing/Thinking")
                        modelBadge("Command-R", DS.Colors.researcher, "Research/RAG")
                        modelBadge("Qwen-Coder", DS.Colors.coder, "Coding")
                        modelBadge("Qwen-VL", DS.Colors.vision, "Vision")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.lg)
                .background(DS.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            }
            .fixedSize(horizontal: true, vertical: false)
            .background(GeometryReader { proxy in
                Color.clear.preference(key: MinEditorWidthKey.self, value: proxy.size.width)
            })
            
            // Connection Status
            HStack(spacing: DS.Spacing.sm) {
                Circle()
                    .fill(appState.ollamaService.isConnected ? DS.Colors.success : DS.Colors.error)
                    .frame(width: 8, height: 8)
                
                Text(appState.ollamaService.isConnected ? "Connected to Ollama" : "Ollama not detected")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.background)
    }
    
    private func quickAction(icon: String, title: String, shortcut: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundStyle(DS.Colors.accent)
                
                Text(title)
                    .font(DS.Typography.body)
                
                Spacer()
                
                Text(shortcut)
                    .font(DS.Typography.mono(11))
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
            .padding(.vertical, DS.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func modelBadge(_ name: String, _ color: Color, _ role: String) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(name)
                .font(DS.Typography.caption.weight(.medium))
                .foregroundStyle(color)
            
            Text(role)
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.tertiaryText)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}

// MARK: - Layout Preferences

struct MinEditorWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 520  // Matches Quick Start/Available Models bubble width
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
