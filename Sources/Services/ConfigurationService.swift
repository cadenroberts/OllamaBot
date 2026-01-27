import Foundation
import SwiftUI

// MARK: - Configuration Manager

class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    
    private enum Keys {
        static let editorFontSize = "editor.fontSize"
        static let editorFontFamily = "editor.fontFamily"
        static let tabSize = "editor.tabSize"
        static let insertSpaces = "editor.insertSpaces"
        static let wordWrap = "editor.wordWrap"
        static let showLineNumbers = "editor.showLineNumbers"
        static let showMinimap = "editor.showMinimap"
        static let highlightCurrentLine = "editor.highlightCurrentLine"
        static let autoCloseBrackets = "editor.autoCloseBrackets"
        static let autoIndent = "editor.autoIndent"
        static let formatOnSave = "editor.formatOnSave"
        static let trimTrailingWhitespace = "editor.trimTrailingWhitespace"
        
        static let theme = "appearance.theme"
        static let accentColor = "appearance.accentColor"
        static let sidebarWidth = "appearance.sidebarWidth"
        static let showStatusBar = "appearance.showStatusBar"
        static let showBreadcrumbs = "appearance.showBreadcrumbs"
        static let compactTabs = "appearance.compactTabs"
        
        static let defaultModel = "ai.defaultModel"
        static let temperature = "ai.temperature"
        static let maxTokens = "ai.maxTokens"
        static let contextWindow = "ai.contextWindow"
        static let includeFileContext = "ai.includeFileContext"
        static let includeSelectedText = "ai.includeSelectedText"
        static let showRoutingExplanation = "ai.showRoutingExplanation"
        static let streamResponses = "ai.streamResponses"
        
        static let maxLoops = "agent.maxLoops"
        static let thinkingDelay = "agent.thinkingDelay"
        static let allowTerminalCommands = "agent.allowTerminalCommands"
        static let allowFileWrites = "agent.allowFileWrites"
        static let confirmDestructiveActions = "agent.confirmDestructiveActions"
        
        static let autoSave = "files.autoSave"
        static let autoSaveDelay = "files.autoSaveDelay"
        static let confirmDelete = "files.confirmDelete"
        static let showHiddenFiles = "files.showHiddenFiles"
        static let excludePatterns = "files.excludePatterns"
        static let watchForExternalChanges = "files.watchForExternalChanges"
        
        static let terminalFontSize = "terminal.fontSize"
        static let terminalFontFamily = "terminal.fontFamily"
        static let terminalShell = "terminal.shell"
        static let terminalScrollback = "terminal.scrollback"
        
        static let gitEnabled = "git.enabled"
        static let showGitStatusInSidebar = "git.showStatusInSidebar"
        static let gitAutoFetch = "git.autoFetch"
        static let gitAutoFetchInterval = "git.autoFetchInterval"
    }
    
    // MARK: - Editor Settings
    
    @Published var editorFontSize: Double {
        didSet { defaults.set(editorFontSize, forKey: Keys.editorFontSize) }
    }
    
    @Published var editorFontFamily: String {
        didSet { defaults.set(editorFontFamily, forKey: Keys.editorFontFamily) }
    }
    
    @Published var tabSize: Int {
        didSet { defaults.set(tabSize, forKey: Keys.tabSize) }
    }
    
    @Published var insertSpaces: Bool {
        didSet { defaults.set(insertSpaces, forKey: Keys.insertSpaces) }
    }
    
    @Published var wordWrap: Bool {
        didSet { defaults.set(wordWrap, forKey: Keys.wordWrap) }
    }
    
    @Published var showLineNumbers: Bool {
        didSet { defaults.set(showLineNumbers, forKey: Keys.showLineNumbers) }
    }
    
    @Published var showMinimap: Bool {
        didSet { defaults.set(showMinimap, forKey: Keys.showMinimap) }
    }
    
    @Published var highlightCurrentLine: Bool {
        didSet { defaults.set(highlightCurrentLine, forKey: Keys.highlightCurrentLine) }
    }
    
    @Published var autoCloseBrackets: Bool {
        didSet { defaults.set(autoCloseBrackets, forKey: Keys.autoCloseBrackets) }
    }
    
    @Published var autoIndent: Bool {
        didSet { defaults.set(autoIndent, forKey: Keys.autoIndent) }
    }
    
    @Published var formatOnSave: Bool {
        didSet { defaults.set(formatOnSave, forKey: Keys.formatOnSave) }
    }
    
    @Published var trimTrailingWhitespace: Bool {
        didSet { defaults.set(trimTrailingWhitespace, forKey: Keys.trimTrailingWhitespace) }
    }
    
    // MARK: - Appearance Settings
    
    @Published var theme: String {
        didSet { defaults.set(theme, forKey: Keys.theme) }
    }
    
    @Published var accentColor: String {
        didSet { defaults.set(accentColor, forKey: Keys.accentColor) }
    }
    
    @Published var sidebarWidth: Double {
        didSet { defaults.set(sidebarWidth, forKey: Keys.sidebarWidth) }
    }
    
    @Published var showStatusBar: Bool {
        didSet { defaults.set(showStatusBar, forKey: Keys.showStatusBar) }
    }
    
    @Published var showBreadcrumbs: Bool {
        didSet { defaults.set(showBreadcrumbs, forKey: Keys.showBreadcrumbs) }
    }
    
    @Published var compactTabs: Bool {
        didSet { defaults.set(compactTabs, forKey: Keys.compactTabs) }
    }
    
    // MARK: - AI Settings
    
    @Published var defaultModel: String {
        didSet { defaults.set(defaultModel, forKey: Keys.defaultModel) }
    }
    
    @Published var temperature: Double {
        didSet { defaults.set(temperature, forKey: Keys.temperature) }
    }
    
    @Published var maxTokens: Int {
        didSet { defaults.set(maxTokens, forKey: Keys.maxTokens) }
    }
    
    @Published var contextWindow: Int {
        didSet { defaults.set(contextWindow, forKey: Keys.contextWindow) }
    }
    
    @Published var includeFileContext: Bool {
        didSet { defaults.set(includeFileContext, forKey: Keys.includeFileContext) }
    }
    
    @Published var includeSelectedText: Bool {
        didSet { defaults.set(includeSelectedText, forKey: Keys.includeSelectedText) }
    }
    
    @Published var showRoutingExplanation: Bool {
        didSet { defaults.set(showRoutingExplanation, forKey: Keys.showRoutingExplanation) }
    }
    
    @Published var streamResponses: Bool {
        didSet { defaults.set(streamResponses, forKey: Keys.streamResponses) }
    }
    
    // MARK: - Agent Settings
    
    @Published var maxLoops: Int {
        didSet { defaults.set(maxLoops, forKey: Keys.maxLoops) }
    }
    
    @Published var thinkingDelay: Double {
        didSet { defaults.set(thinkingDelay, forKey: Keys.thinkingDelay) }
    }
    
    @Published var allowTerminalCommands: Bool {
        didSet { defaults.set(allowTerminalCommands, forKey: Keys.allowTerminalCommands) }
    }
    
    @Published var allowFileWrites: Bool {
        didSet { defaults.set(allowFileWrites, forKey: Keys.allowFileWrites) }
    }
    
    @Published var confirmDestructiveActions: Bool {
        didSet { defaults.set(confirmDestructiveActions, forKey: Keys.confirmDestructiveActions) }
    }
    
    // MARK: - File Settings
    
    @Published var autoSave: Bool {
        didSet { defaults.set(autoSave, forKey: Keys.autoSave) }
    }
    
    @Published var autoSaveDelay: Double {
        didSet { defaults.set(autoSaveDelay, forKey: Keys.autoSaveDelay) }
    }
    
    @Published var confirmDelete: Bool {
        didSet { defaults.set(confirmDelete, forKey: Keys.confirmDelete) }
    }
    
    @Published var showHiddenFiles: Bool {
        didSet { defaults.set(showHiddenFiles, forKey: Keys.showHiddenFiles) }
    }
    
    @Published var excludePatterns: [String] {
        didSet {
            if let data = try? JSONEncoder().encode(excludePatterns) {
                defaults.set(data, forKey: Keys.excludePatterns)
            }
        }
    }
    
    @Published var watchForExternalChanges: Bool {
        didSet { defaults.set(watchForExternalChanges, forKey: Keys.watchForExternalChanges) }
    }
    
    // MARK: - Terminal Settings
    
    @Published var terminalFontSize: Double {
        didSet { defaults.set(terminalFontSize, forKey: Keys.terminalFontSize) }
    }
    
    @Published var terminalFontFamily: String {
        didSet { defaults.set(terminalFontFamily, forKey: Keys.terminalFontFamily) }
    }
    
    @Published var terminalShell: String {
        didSet { defaults.set(terminalShell, forKey: Keys.terminalShell) }
    }
    
    @Published var terminalScrollback: Int {
        didSet { defaults.set(terminalScrollback, forKey: Keys.terminalScrollback) }
    }
    
    // MARK: - Git Settings
    
    @Published var gitEnabled: Bool {
        didSet { defaults.set(gitEnabled, forKey: Keys.gitEnabled) }
    }
    
    @Published var showGitStatusInSidebar: Bool {
        didSet { defaults.set(showGitStatusInSidebar, forKey: Keys.showGitStatusInSidebar) }
    }
    
    @Published var gitAutoFetch: Bool {
        didSet { defaults.set(gitAutoFetch, forKey: Keys.gitAutoFetch) }
    }
    
    @Published var gitAutoFetchInterval: Int {
        didSet { defaults.set(gitAutoFetchInterval, forKey: Keys.gitAutoFetchInterval) }
    }
    
    // MARK: - Computed Properties
    
    var editorFont: NSFont {
        NSFont(name: editorFontFamily, size: editorFontSize) ?? .monospacedSystemFont(ofSize: editorFontSize, weight: .regular)
    }
    
    var terminalFont: NSFont {
        NSFont(name: terminalFontFamily, size: terminalFontSize) ?? .monospacedSystemFont(ofSize: terminalFontSize, weight: .regular)
    }
    
    // MARK: - Initialization
    
    private init() {
        // Editor
        editorFontSize = defaults.double(forKey: Keys.editorFontSize) != 0 ? defaults.double(forKey: Keys.editorFontSize) : 13
        editorFontFamily = defaults.string(forKey: Keys.editorFontFamily) ?? "SF Mono"
        tabSize = defaults.integer(forKey: Keys.tabSize) != 0 ? defaults.integer(forKey: Keys.tabSize) : 4
        insertSpaces = defaults.object(forKey: Keys.insertSpaces) != nil ? defaults.bool(forKey: Keys.insertSpaces) : true
        wordWrap = defaults.bool(forKey: Keys.wordWrap)
        showLineNumbers = defaults.object(forKey: Keys.showLineNumbers) != nil ? defaults.bool(forKey: Keys.showLineNumbers) : true
        showMinimap = defaults.object(forKey: Keys.showMinimap) != nil ? defaults.bool(forKey: Keys.showMinimap) : true
        highlightCurrentLine = defaults.object(forKey: Keys.highlightCurrentLine) != nil ? defaults.bool(forKey: Keys.highlightCurrentLine) : true
        autoCloseBrackets = defaults.object(forKey: Keys.autoCloseBrackets) != nil ? defaults.bool(forKey: Keys.autoCloseBrackets) : true
        autoIndent = defaults.object(forKey: Keys.autoIndent) != nil ? defaults.bool(forKey: Keys.autoIndent) : true
        formatOnSave = defaults.bool(forKey: Keys.formatOnSave)
        trimTrailingWhitespace = defaults.object(forKey: Keys.trimTrailingWhitespace) != nil ? defaults.bool(forKey: Keys.trimTrailingWhitespace) : true
        
        // Appearance
        theme = defaults.string(forKey: Keys.theme) ?? "system"
        accentColor = defaults.string(forKey: Keys.accentColor) ?? "blue"
        sidebarWidth = defaults.double(forKey: Keys.sidebarWidth) != 0 ? defaults.double(forKey: Keys.sidebarWidth) : 260
        showStatusBar = defaults.object(forKey: Keys.showStatusBar) != nil ? defaults.bool(forKey: Keys.showStatusBar) : true
        showBreadcrumbs = defaults.object(forKey: Keys.showBreadcrumbs) != nil ? defaults.bool(forKey: Keys.showBreadcrumbs) : true
        compactTabs = defaults.bool(forKey: Keys.compactTabs)
        
        // AI
        defaultModel = defaults.string(forKey: Keys.defaultModel) ?? "auto"
        temperature = defaults.double(forKey: Keys.temperature) != 0 ? defaults.double(forKey: Keys.temperature) : 0.7
        maxTokens = defaults.integer(forKey: Keys.maxTokens) != 0 ? defaults.integer(forKey: Keys.maxTokens) : 4096
        contextWindow = defaults.integer(forKey: Keys.contextWindow) != 0 ? defaults.integer(forKey: Keys.contextWindow) : 8192
        includeFileContext = defaults.object(forKey: Keys.includeFileContext) != nil ? defaults.bool(forKey: Keys.includeFileContext) : true
        includeSelectedText = defaults.object(forKey: Keys.includeSelectedText) != nil ? defaults.bool(forKey: Keys.includeSelectedText) : true
        showRoutingExplanation = defaults.bool(forKey: Keys.showRoutingExplanation)
        streamResponses = defaults.object(forKey: Keys.streamResponses) != nil ? defaults.bool(forKey: Keys.streamResponses) : true
        
        // Agent
        maxLoops = defaults.integer(forKey: Keys.maxLoops) != 0 ? defaults.integer(forKey: Keys.maxLoops) : 100
        thinkingDelay = defaults.double(forKey: Keys.thinkingDelay) != 0 ? defaults.double(forKey: Keys.thinkingDelay) : 0.5
        allowTerminalCommands = defaults.object(forKey: Keys.allowTerminalCommands) != nil ? defaults.bool(forKey: Keys.allowTerminalCommands) : true
        allowFileWrites = defaults.object(forKey: Keys.allowFileWrites) != nil ? defaults.bool(forKey: Keys.allowFileWrites) : true
        confirmDestructiveActions = defaults.object(forKey: Keys.confirmDestructiveActions) != nil ? defaults.bool(forKey: Keys.confirmDestructiveActions) : true
        
        // Files
        autoSave = defaults.object(forKey: Keys.autoSave) != nil ? defaults.bool(forKey: Keys.autoSave) : true
        autoSaveDelay = defaults.double(forKey: Keys.autoSaveDelay) != 0 ? defaults.double(forKey: Keys.autoSaveDelay) : 1.0
        confirmDelete = defaults.object(forKey: Keys.confirmDelete) != nil ? defaults.bool(forKey: Keys.confirmDelete) : true
        showHiddenFiles = defaults.bool(forKey: Keys.showHiddenFiles)
        
        if let data = defaults.data(forKey: Keys.excludePatterns),
           let patterns = try? JSONDecoder().decode([String].self, from: data) {
            excludePatterns = patterns
        } else {
            excludePatterns = ["node_modules", ".git", "__pycache__", ".build"]
        }
        
        watchForExternalChanges = defaults.object(forKey: Keys.watchForExternalChanges) != nil ? defaults.bool(forKey: Keys.watchForExternalChanges) : true
        
        // Terminal
        terminalFontSize = defaults.double(forKey: Keys.terminalFontSize) != 0 ? defaults.double(forKey: Keys.terminalFontSize) : 12
        terminalFontFamily = defaults.string(forKey: Keys.terminalFontFamily) ?? "SF Mono"
        terminalShell = defaults.string(forKey: Keys.terminalShell) ?? "/bin/zsh"
        terminalScrollback = defaults.integer(forKey: Keys.terminalScrollback) != 0 ? defaults.integer(forKey: Keys.terminalScrollback) : 10000
        
        // Git
        gitEnabled = defaults.object(forKey: Keys.gitEnabled) != nil ? defaults.bool(forKey: Keys.gitEnabled) : true
        showGitStatusInSidebar = defaults.object(forKey: Keys.showGitStatusInSidebar) != nil ? defaults.bool(forKey: Keys.showGitStatusInSidebar) : true
        gitAutoFetch = defaults.bool(forKey: Keys.gitAutoFetch)
        gitAutoFetchInterval = defaults.integer(forKey: Keys.gitAutoFetchInterval) != 0 ? defaults.integer(forKey: Keys.gitAutoFetchInterval) : 300
    }
    
    // MARK: - Methods
    
    func resetToDefaults() {
        editorFontSize = 13
        editorFontFamily = "SF Mono"
        tabSize = 4
        insertSpaces = true
        wordWrap = false
        showLineNumbers = true
        theme = "system"
        temperature = 0.7
        maxLoops = 100
    }
}

// MARK: - Available Fonts

struct FontOption: Identifiable {
    let id: String
    let name: String
    let family: String
    
    static let monospaceFonts: [FontOption] = [
        FontOption(id: "sf-mono", name: "SF Mono", family: "SF Mono"),
        FontOption(id: "menlo", name: "Menlo", family: "Menlo"),
        FontOption(id: "monaco", name: "Monaco", family: "Monaco"),
        FontOption(id: "courier-new", name: "Courier New", family: "Courier New"),
        FontOption(id: "jetbrains-mono", name: "JetBrains Mono", family: "JetBrains Mono"),
        FontOption(id: "fira-code", name: "Fira Code", family: "Fira Code"),
        FontOption(id: "source-code-pro", name: "Source Code Pro", family: "Source Code Pro"),
        FontOption(id: "cascadia-code", name: "Cascadia Code", family: "Cascadia Code")
    ]
}

// MARK: - Theme Options

struct ThemeOption: Identifiable {
    let id: String
    let name: String
    let isDark: Bool
    
    static let themes: [ThemeOption] = [
        ThemeOption(id: "system", name: "System", isDark: false),
        ThemeOption(id: "light", name: "Light", isDark: false),
        ThemeOption(id: "dark", name: "Dark", isDark: true),
        ThemeOption(id: "high-contrast-dark", name: "High Contrast Dark", isDark: true),
        ThemeOption(id: "solarized-light", name: "Solarized Light", isDark: false),
        ThemeOption(id: "solarized-dark", name: "Solarized Dark", isDark: true)
    ]
}
