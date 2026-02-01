import SwiftUI

@main
struct OllamaBotApp: App {
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(appState)
                .frame(minWidth: 400, minHeight: 300)
                .foregroundStyle(DS.Colors.text)  // Default all text to light blue/white
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
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
                // Panel toggles
                Button("Toggle Primary Sidebar") {
                    PanelState.shared.togglePrimarySidebar()
                }
                .keyboardShortcut("b", modifiers: [.command])
                
                Button("Toggle Secondary Sidebar") {
                    PanelState.shared.toggleSecondarySidebar()
                }
                .keyboardShortcut("b", modifiers: [.command, .option])
                
                Button("Toggle Panel") {
                    PanelState.shared.toggleBottomPanel()
                }
                .keyboardShortcut("`", modifiers: [.control])
                
                Divider()
                
                // Panel tabs
                Menu("Show Panel") {
                    Button("Terminal") {
                        PanelState.shared.showTerminal()
                    }
                    .keyboardShortcut("`", modifiers: [.control, .shift])
                    
                    Button("Problems") {
                        PanelState.shared.showProblems()
                    }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                    
                    Button("Output") {
                        PanelState.shared.setBottomPanelTab(.output)
                    }
                }
                
                Divider()
                
                // Performance Dashboard
                Button("Performance Dashboard") {
                    appState.showPerformanceDashboard = true
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                
                Divider()
                
                // Editor layout
                Menu("Editor Layout") {
                    Button("Single") {
                        PanelState.shared.setEditorLayout(.single)
                    }
                    
                    Button("Split Vertical") {
                        PanelState.shared.setEditorLayout(.splitVertical)
                    }
                    .keyboardShortcut("\\", modifiers: [.command])
                    
                    Button("Split Horizontal") {
                        PanelState.shared.setEditorLayout(.splitHorizontal)
                    }
                    
                    Button("Grid (2x2)") {
                        PanelState.shared.setEditorLayout(.grid)
                    }
                }
                
                Divider()
                
                // Zen mode
                Button("Zen Mode") {
                    PanelState.shared.toggleZenMode()
                }
                .keyboardShortcut("k", modifiers: [.command])
                
                Divider()
                
                // Font size
                Button("Increase Font Size") {
                    appState.editorFontSize = min(32, appState.editorFontSize + 1)
                }
                .keyboardShortcut("+", modifiers: [.command])
                
                Button("Decrease Font Size") {
                    appState.editorFontSize = max(8, appState.editorFontSize - 1)
                }
                .keyboardShortcut("-", modifiers: [.command])
                
                Divider()
                
                // View options
                Toggle("Show Breadcrumbs", isOn: Binding(
                    get: { PanelState.shared.showBreadcrumbs },
                    set: { PanelState.shared.showBreadcrumbs = $0; PanelState.shared.saveState() }
                ))
                
                Toggle("Show Minimap", isOn: Binding(
                    get: { PanelState.shared.showMinimap },
                    set: { PanelState.shared.showMinimap = $0; PanelState.shared.saveState() }
                ))
                
                Toggle("Show Status Bar", isOn: Binding(
                    get: { PanelState.shared.showStatusBar },
                    set: { PanelState.shared.showStatusBar = $0; PanelState.shared.saveState() }
                ))
            }
            
            CommandMenu("AI") {
                Button("Toggle Infinite Mode") {
                    appState.showInfiniteMode.toggle()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                
                Button("Show Cycle Agents") {
                    PanelState.shared.setSecondarySidebarTab(.agents)
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                
                Divider()
                
                // Model selection (uses ModelTierManager tier-appropriate models)
                ForEach(OllamaModel.allCases) { model in
                    Button("\(model.displayName) (\(appState.modelTierManager.getVariant(for: model).parameters))") {
                        appState.selectAndPreloadModel(model)
                    }
                    .keyboardShortcut(model.shortcut, modifiers: [.command, .shift])
                }
                
                Divider()
                
                Button("Auto-Route") {
                    appState.selectAndPreloadModel(nil)
                }
                .keyboardShortcut("0", modifiers: [.command, .shift])
                
                Divider()
                
                // RAM tier info
                Text("Tier: \(appState.modelTierManager.selectedTier.rawValue)")
                Text("RAM: \(appState.modelTierManager.systemRAM)GB")
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
    var lastUsedModel: OllamaModel? // Track last model for UI display
    var chatMessages: [ChatMessage] = []
    var isGenerating: Bool = false
    var mentionedFiles: [FileItem] = [] // For @file mentions
    
    /// Select and preload a model for faster response times
    func selectAndPreloadModel(_ model: OllamaModel?) {
        selectedModel = model
        if let model = model {
            // Preload the model in background
            Task {
                let keepAlive = modelTierManager.getMemorySettings().keepAlive
                await ollamaService.preloadModel(model, keepAlive: keepAlive)
            }
        }
    }
    
    // MARK: - UI State - Panels (delegated to PanelState for persistence)
    var showInfiniteMode: Bool = false
    
    // Legacy compatibility - delegate to PanelState
    var showSidebar: Bool {
        get { PanelState.shared.showPrimarySidebar }
        set { PanelState.shared.showPrimarySidebar = newValue; PanelState.shared.saveState() }
    }
    var showChatPanel: Bool {
        get { PanelState.shared.showSecondarySidebar }
        set { PanelState.shared.showSecondarySidebar = newValue; PanelState.shared.saveState() }
    }
    var showTerminal: Bool {
        get { PanelState.shared.showBottomPanel && PanelState.shared.bottomPanelTab == .terminal }
        set { 
            if newValue {
                PanelState.shared.showTerminal()
            } else {
                PanelState.shared.showBottomPanel = false
            }
            PanelState.shared.saveState()
        }
    }
    
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
    var showPerformanceDashboard: Bool = false
    
    // MARK: - UI State - Focus
    var focusChat: Bool = false
    
    // MARK: - UI State - Toasts (Production UX)
    var toasts: [Toast] = []
    
    // MARK: - Editor Settings (Observable)
    var editorFontSize: CGFloat = 13
    
    // MARK: - Services (All services are wired and interconnected)
    let ollamaService: OllamaService
    let fileSystemService: FileSystemService
    let intentRouter: IntentRouter
    let contextManager: ContextManager          // Unified context (SINGLE SOURCE OF TRUTH)
    let agentExecutor: AgentExecutor            // Single-task agent (Infinite Mode)
    let exploreExecutor: ExploreAgentExecutor   // Explore Mode - autonomous improvement
    let cycleAgentManager: CycleAgentManager    // Multi-agent orchestration (Cycle Mode)
    let obotService: OBotService                // Rules, bots, context, templates
    let mentionService: MentionService          // @mention support for chat
    let checkpointService: CheckpointService    // Save/restore code states
    let fileIndexer = FileIndexer()
    let asyncFileIO = AsyncFileIO()
    let config = ConfigurationManager.shared
    let inlineCompletionService: InlineCompletionService
    let chatHistoryService: ChatHistoryService
    let gitService: GitService
    let webSearchService: WebSearchService
    
    // MARK: - System Services
    let systemMonitor: SystemMonitorService     // RAM & process monitoring
    let networkMonitor: NetworkMonitorService   // Network status & resilience
    let resilienceService: ResilienceService    // Power loss & crash recovery
    let performanceTracker: PerformanceTrackingService  // Benchmarks & cost savings
    
    // MARK: - Model Tier Management (RAM-aware model selection)
    let modelTierManager: ModelTierManager
    
    // Performance caches
    private let fileContentCache = LRUCache<URL, String>(capacity: 50_000_000) // ~50MB
    
    // Memory management
    private var memoryMonitor: MemoryPressureMonitor?
    
    init() {
        // Model tier management (RAM-aware model selection) - MUST BE FIRST
        self.modelTierManager = ModelTierManager()
        
        // Core services
        self.ollamaService = OllamaService()
        self.fileSystemService = FileSystemService()
        self.intentRouter = IntentRouter()
        self.contextManager = ContextManager()
        
        // Agents - ALL share the same ContextManager (SINGLE SOURCE OF TRUTH)
        self.agentExecutor = AgentExecutor(
            ollamaService: ollamaService,
            fileSystemService: fileSystemService,
            contextManager: contextManager
        )
        
        // Explore Mode executor - autonomous project improvement
        self.exploreExecutor = ExploreAgentExecutor(
            ollamaService: ollamaService,
            fileSystemService: fileSystemService,
            contextManager: contextManager
        )
        
        // Multi-agent orchestration (shares services + context)
        self.cycleAgentManager = CycleAgentManager(
            ollamaService: ollamaService,
            fileSystemService: fileSystemService,
            contextManager: contextManager,
            modelTierManager: modelTierManager
        )
        
        // OBot: Rules, bots, context snippets, templates
        self.obotService = OBotService(
            fileSystemService: fileSystemService,
            contextManager: contextManager
        )
        
        // Mention Service: @file, @bot, @context, @web, etc.
        self.mentionService = MentionService(
            fileSystemService: fileSystemService,
            obotService: obotService,
            gitService: GitService(),
            webSearchService: WebSearchService(),
            contextManager: contextManager
        )
        
        // Feature services
        self.inlineCompletionService = InlineCompletionService(ollamaService: ollamaService)
        self.chatHistoryService = ChatHistoryService()
        self.gitService = GitService()
        self.webSearchService = WebSearchService()
        
        // Checkpoint Service: Save/restore code states (like Windsurf)
        self.checkpointService = CheckpointService(
            fileSystemService: fileSystemService,
            gitService: gitService
        )
        
        // System services - monitoring and resilience
        self.systemMonitor = SystemMonitorService()
        self.networkMonitor = NetworkMonitorService()
        self.resilienceService = ResilienceService()
        self.performanceTracker = PerformanceTrackingService()
        
        // Wire performance tracker to OllamaService
        self.ollamaService.performanceTracker = performanceTracker
        
        // Wire up resilience service to agents
        self.resilienceService.agentExecutor = agentExecutor
        self.resilienceService.exploreExecutor = exploreExecutor
        
        // Monitor memory pressure and clear caches when needed
        self.memoryMonitor = MemoryPressureMonitor()
        self.memoryMonitor?.onHighPressure = { [weak self] in
            print("⚠️ High memory pressure detected - clearing caches")
            self?.clearAllCaches()
            // Also pause cycle agents if running
            self?.cycleAgentManager.pauseForMemoryPressure()
        }
        
        // Configure OllamaService with tier-appropriate model tags
        ollamaService.configureTier(modelTierManager)
        
        // Start system monitoring
        systemMonitor.startMonitoring()
        networkMonitor.startMonitoring()
        resilienceService.startAutosave()
        
        // Check for recovery data on launch
        Task { @MainActor in
            resilienceService.checkForRecoveryData()
            // Recovery alert will be shown by the view if data exists
        }
        
        // Log system configuration
        print("🚀 OllamaBot initialized")
        print("   RAM: \(modelTierManager.systemRAM)GB")
        print("   Tier: \(modelTierManager.selectedTier.rawValue)")
        print("   Parallel: \(modelTierManager.canRunParallel ? "Yes" : "No")")
        print("   Network: \(networkMonitor.status.isConnected ? "Connected" : "Offline")")
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
            
            // Update project context cache
            let files = fileSystemService.getAllFiles(in: url)
            contextManager.updateProjectCache(root: url, files: files)
            
            // Load OBot configuration (.obotrules, bots, context, templates)
            Task {
                await obotService.loadProject(url)
            }
            
            // Load checkpoints for project
            checkpointService.setProject(url)
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
    
    /// Initiate a rename operation for a file or folder
    func initiateRename(for url: URL) {
        let alert = NSAlert()
        alert.messageText = "Rename"
        alert.informativeText = "Enter a new name for '\(url.lastPathComponent)'"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = url.lastPathComponent
        alert.accessoryView = textField
        
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        
        alert.window.initialFirstResponder = textField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let newName = textField.stringValue
            if !newName.isEmpty && newName != url.lastPathComponent {
                let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
                do {
                    try FileManager.default.moveItem(at: url, to: newURL)
                    // Update open files if needed
                    if let index = openFiles.firstIndex(where: { $0.url == url }) {
                        openFiles[index] = FileItem(url: newURL, isDirectory: openFiles[index].isDirectory)
                        if selectedFile?.url == url {
                            selectedFile = openFiles[index]
                        }
                    }
                    showSuccess("Renamed to '\(newName)'")
                } catch {
                    showError("Failed to rename: \(error.localizedDescription)")
                }
            }
        }
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
        // 1. Create and store user message
        let userMessage = ChatMessage(role: .user, content: content, images: images)
        chatMessages.append(userMessage)
        chatHistoryService.addMessage(userMessage)
        
        // 2. Route to appropriate model
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
        
        // Track for UI display
        lastUsedModel = model
        
        // 3. Build context using unified ContextManager
        var editorContextContent = editorContent
        for file in mentionedFiles {
            if let fileContent = fileSystemService.readFile(at: file.url) {
                editorContextContent += "\n\n// File: \(file.name)\n\(fileContent)"
            }
        }
        
        let context = contextManager.buildChatContext(
            message: content,
            editorContent: editorContextContent,
            selectedText: selectedText,
            openFiles: openFiles + mentionedFiles,
            currentFile: selectedFile
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
                    // IMPORTANT: Replace entire element to trigger @Observable re-render
                    // Mutating .content directly doesn't notify SwiftUI of changes
                    var updatedMessage = chatMessages[messageIndex]
                    updatedMessage.content = buffer
                    chatMessages[messageIndex] = updatedMessage
                    lastUpdateTime = now
                }
            }
            
            // Final update with complete content - replace entire element
            var finalMessage = chatMessages[messageIndex]
            finalMessage.content = buffer
            chatMessages[messageIndex] = finalMessage
            
            // Save to persistent history
            chatHistoryService.addMessage(chatMessages[messageIndex])
            
        } catch let error as OllamaError {
            var errorMessage = chatMessages[messageIndex]
            errorMessage.content = "Error: \(error.localizedDescription)"
            chatMessages[messageIndex] = errorMessage
            showError(error.userMessage)
            contextManager.recordError(error.localizedDescription, context: content)
        } catch {
            var errorMessage = chatMessages[messageIndex]
            errorMessage.content = "Error: \(error.localizedDescription)"
            chatMessages[messageIndex] = errorMessage
            showError("Failed to get AI response")
            contextManager.recordError(error.localizedDescription, context: content)
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
    
    // runBenchmarks() is defined in Benchmarks.swift as an AppState extension
}
