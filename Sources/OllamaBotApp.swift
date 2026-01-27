import SwiftUI

@main
struct OllamaBotApp: App {
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(appState)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder...") {
                    appState.openFolderPanel()
                }
                .keyboardShortcut("o", modifiers: [.command])
                
                Divider()
                
                Button("New File") {
                    appState.createNewFile()
                }
                .keyboardShortcut("n", modifiers: [.command])
                
                Button("Save") {
                    appState.saveCurrentFile()
                }
                .keyboardShortcut("s", modifiers: [.command])
            }
            
            CommandGroup(after: .textEditing) {
                Button("Find...") {
                    appState.showFindInFile = true
                }
                .keyboardShortcut("f", modifiers: [.command])
                
                Button("Find and Replace...") {
                    appState.showFindReplace = true
                }
                .keyboardShortcut("f", modifiers: [.command, .option])
                
                Button("Search in Files...") {
                    appState.showGlobalSearch = true
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
            
            CommandMenu("Go") {
                Button("Go to File...") {
                    appState.showQuickOpen = true
                }
                .keyboardShortcut("p", modifiers: [.command])
                
                Button("Go to Line...") {
                    appState.showGoToLine = true
                }
                .keyboardShortcut("g", modifiers: [.control])
                
                Button("Command Palette...") {
                    appState.showCommandPalette = true
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
            
            CommandMenu("View") {
                Button("Toggle Sidebar") {
                    appState.showSidebar.toggle()
                }
                .keyboardShortcut("b", modifiers: [.command])
                
                Button("Toggle Terminal") {
                    appState.showTerminal.toggle()
                }
                .keyboardShortcut("`", modifiers: [.control])
                
                Button("Toggle Chat Panel") {
                    appState.showChatPanel.toggle()
                }
                
                Divider()
                
                Button("Increase Font Size") {
                    appState.editorFontSize = min(32, appState.editorFontSize + 1)
                }
                .keyboardShortcut("+", modifiers: [.command])
                
                Button("Decrease Font Size") {
                    appState.editorFontSize = max(8, appState.editorFontSize - 1)
                }
                .keyboardShortcut("-", modifiers: [.command])
            }
            
            CommandMenu("AI") {
                Button("Toggle Infinite Mode") {
                    appState.showInfiniteMode.toggle()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                
                Divider()
                
                ForEach(OllamaModel.allCases) { model in
                    Button(model.displayName) {
                        appState.selectedModel = model
                    }
                    .keyboardShortcut(model.shortcut, modifiers: [.command, .shift])
                }
                
                Divider()
                
                Button("Auto-Route") {
                    appState.selectedModel = nil
                }
                .keyboardShortcut("0", modifiers: [.command, .shift])
            }
            
            #if DEBUG
            CommandMenu("Debug") {
                Button("Run Performance Benchmarks") {
                    Task {
                        await appState.runBenchmarks()
                    }
                }
                
                Button("Clear Caches") {
                    appState.clearAllCaches()
                }
                
                Divider()
                
                Button("Print Index Stats") {
                    Task {
                        let count = await appState.fileIndexer.indexedFileCount
                        print("📊 Indexed files: \(count)")
                    }
                }
            }
            #endif
        }
        
        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}

@Observable
class AppState {
    // MARK: - File System State
    var rootFolder: URL?
    var openFiles: [FileItem] = []
    var selectedFile: FileItem?
    var editorContent: String = ""
    var selectedText: String = ""
    var goToLine: Int? = nil
    
    // MARK: - Chat State
    var selectedModel: OllamaModel?
    var chatMessages: [ChatMessage] = []
    var isGenerating: Bool = false
    var mentionedFiles: [FileItem] = [] // For @file mentions
    
    // MARK: - UI State - Panels
    var showInfiniteMode: Bool = false
    var showSidebar: Bool = true
    var showChatPanel: Bool = true
    var showTerminal: Bool = false
    
    // MARK: - UI State - Dialogs
    var showCommandPalette: Bool = false
    var showQuickOpen: Bool = false
    var showGlobalSearch: Bool = false
    var showFindInFile: Bool = false
    var showFindReplace: Bool = false
    var showGoToLine: Bool = false
    var showSettings: Bool = false
    var showGitStatus: Bool = false
    var showGitCommit: Bool = false
    
    // MARK: - UI State - Focus
    var focusChat: Bool = false
    
    // MARK: - UI State - Toasts (Production UX)
    var toasts: [Toast] = []
    
    // MARK: - Editor Settings (Observable)
    var editorFontSize: CGFloat = 13
    
    // MARK: - Services
    let ollamaService: OllamaService
    let fileSystemService: FileSystemService
    let intentRouter: IntentRouter
    let contextBuilder: ContextBuilder
    let agentExecutor: AgentExecutor
    let fileIndexer = FileIndexer()
    let asyncFileIO = AsyncFileIO()
    let config = ConfigurationManager.shared
    
    // NEW: Integrated services
    let inlineCompletionService: InlineCompletionService
    let chatHistoryService = ChatHistoryService()
    let gitService = GitService()
    let webSearchService = WebSearchService()
    
    // Performance caches
    private let fileContentCache = LRUCache<URL, String>(capacity: 50_000_000) // ~50MB
    
    // Memory management
    private var memoryMonitor: MemoryPressureMonitor?
    
    init() {
        self.ollamaService = OllamaService()
        self.fileSystemService = FileSystemService()
        self.intentRouter = IntentRouter()
        self.contextBuilder = ContextBuilder()
        self.agentExecutor = AgentExecutor(ollamaService: ollamaService, fileSystemService: fileSystemService)
        self.inlineCompletionService = InlineCompletionService(ollamaService: ollamaService)
        
        // Monitor memory pressure and clear caches when needed
        self.memoryMonitor = MemoryPressureMonitor()
        self.memoryMonitor?.onHighPressure = { [weak self] in
            print("⚠️ High memory pressure detected - clearing caches")
            self?.clearAllCaches()
        }
    }
    
    // MARK: - File Operations
    
    func openFolder() {
        openFolderPanel()
    }
    
    func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            rootFolder = url
            
            // Start background indexing for fast search
            Task(priority: .background) {
                await fileIndexer.indexDirectory(url)
            }
        }
    }
    
    func createNewFile() {
        guard let root = rootFolder else { return }
        let newFile = FileItem(
            url: root.appendingPathComponent("untitled.txt"),
            isDirectory: false
        )
        openFiles.append(newFile)
        selectedFile = newFile
        editorContent = ""
    }
    
    func openFile(_ file: FileItem) {
        if !openFiles.contains(where: { $0.url == file.url }) {
            openFiles.append(file)
        }
        selectedFile = file
        
        // Check cache first
        if let cached = fileContentCache.get(file.url) {
            editorContent = cached
        } else if let content = fileSystemService.readFile(at: file.url) {
            editorContent = content
            // Cache file content (size = byte count)
            fileContentCache.set(file.url, content, size: content.utf8.count)
        } else {
            editorContent = ""
        }
    }
    
    func closeFile(_ file: FileItem) {
        openFiles.removeAll { $0.url == file.url }
        if selectedFile?.url == file.url {
            selectedFile = openFiles.first
            if let selected = selectedFile {
                editorContent = fileSystemService.readFile(at: selected.url) ?? ""
            } else {
                editorContent = ""
            }
        }
    }
    
    func saveCurrentFile() {
        guard let file = selectedFile else { return }
        fileSystemService.writeFile(content: editorContent, to: file.url)
        showToast(.success, "Saved \(file.name)")
    }
    
    // MARK: - Toast Notifications
    
    func showToast(_ type: ToastType, _ message: String) {
        withAnimation(DS.Animation.medium) {
            toasts.append(Toast(type: type, message: message))
        }
    }
    
    func showError(_ message: String) {
        showToast(.error, message)
    }
    
    func showSuccess(_ message: String) {
        showToast(.success, message)
    }
    
    // MARK: - Appearance
    
    func toggleTheme() {
        if config.theme == "dark" {
            config.theme = "light"
        } else {
            config.theme = "dark"
        }
    }
    
    // MARK: - Chat Operations
    
    @MainActor
    func sendMessage(_ content: String, images: [Data] = []) async {
        let userMessage = ChatMessage(role: .user, content: content, images: images)
        chatMessages.append(userMessage)
        
        // Determine which model to use
        let model: OllamaModel
        if let override = selectedModel {
            model = override
        } else {
            model = intentRouter.routeIntent(
                message: content,
                hasImages: !images.isEmpty,
                hasCodeContext: !editorContent.isEmpty
            )
        }
        
        // Build context including mentioned files
        var contextContent = editorContent
        for file in mentionedFiles {
            if let fileContent = fileSystemService.readFile(at: file.url) {
                contextContent += "\n\n// File: \(file.name)\n\(fileContent)"
            }
        }
        
        let context = contextBuilder.buildContext(
            message: content,
            editorContent: contextContent,
            selectedText: selectedText,
            openFiles: openFiles + mentionedFiles,
            fileSystemService: fileSystemService
        )
        
        // Clear mentioned files after use
        mentionedFiles.removeAll()
        
        // Create assistant message placeholder
        let assistantMessage = ChatMessage(role: .assistant, content: "", model: model)
        chatMessages.append(assistantMessage)
        let messageIndex = chatMessages.count - 1
        
        isGenerating = true
        
        // PERFORMANCE FIX: Batch streaming updates to ~30fps
        // Instead of updating state on every token, accumulate locally
        // and update at fixed intervals
        var buffer = ""
        buffer.reserveCapacity(8192)
        var lastUpdateTime = CACurrentMediaTime()
        let updateInterval: CFTimeInterval = 0.033 // ~30fps
        
        do {
            let stream = ollamaService.chat(
                model: model,
                messages: chatMessages.dropLast().map { ($0.role.rawValue, $0.content) },
                context: context,
                images: images
            )
            
            for try await chunk in stream {
                buffer.append(chunk)
                
                let now = CACurrentMediaTime()
                if now - lastUpdateTime >= updateInterval {
                    // Batch update: single state mutation per frame
                    chatMessages[messageIndex].content = buffer
                    lastUpdateTime = now
                }
            }
            
            // Final update with complete content
            chatMessages[messageIndex].content = buffer
            
        } catch let error as OllamaError {
            chatMessages[messageIndex].content = "Error: \(error.localizedDescription)"
            showError(error.userMessage)
        } catch {
            chatMessages[messageIndex].content = "Error: \(error.localizedDescription)"
            showError("Failed to get AI response")
        }
        
        isGenerating = false
    }
    
    // MARK: - Code Application
    
    func applyCodeToEditor(_ code: String, replace: Bool = false) {
        if replace || selectedText.isEmpty {
            // Replace entire file or insert at cursor
            editorContent = code
        } else {
            // Replace selection
            if let range = editorContent.range(of: selectedText) {
                editorContent.replaceSubrange(range, with: code)
            }
        }
    }
    
    func applyCodeToFile(_ code: String, filePath: String) {
        let url: URL
        if filePath.hasPrefix("/") {
            url = URL(fileURLWithPath: filePath)
        } else if let root = rootFolder {
            url = root.appendingPathComponent(filePath)
        } else {
            return
        }
        
        fileSystemService.writeFile(content: code, to: url)
        
        // Open the file if not already open
        let file = FileItem(url: url, isDirectory: false)
        openFile(file)
    }
    
    // MARK: - Performance & Debug
    
    func clearAllCaches() {
        fileContentCache.clear()
        showSuccess("Caches cleared")
    }
}
