import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: SettingsTab = .editor
    
    enum SettingsTab: String, CaseIterable {
        case editor = "Editor"
        case appearance = "Appearance"
        case ai = "AI Models"
        case agent = "Agent"
        case obot = "OBot"
        case files = "Files"
        case terminal = "Terminal"
        case git = "Git"
        case keyboard = "Keyboard"
        
        var icon: String {
            switch self {
            case .editor: return "curlybraces"
            case .appearance: return "paintbrush"
            case .ai: return "cpu"
            case .agent: return "infinity"
            case .obot: return "cpu"
            case .files: return "folder"
            case .terminal: return "terminal"
            case .git: return "arrow.triangle.branch"
            case .keyboard: return "keyboard"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
            }
            .navigationSplitViewColumnWidth(180)
        } detail: {
            settingsContent
                .frame(minWidth: 500, minHeight: 400)
        }
        .frame(width: 700, height: 500)
    }
    
    @ViewBuilder
    private var settingsContent: some View {
        switch selectedTab {
        case .editor:
            EditorSettingsView()
        case .appearance:
            AppearanceSettingsView()
        case .ai:
            AISettingsView()
        case .agent:
            AgentSettingsView()
        case .obot:
            OBotSettingsView()
        case .files:
            FilesSettingsView()
        case .terminal:
            TerminalSettingsView()
        case .git:
            GitSettingsView()
        case .keyboard:
            KeyboardSettingsView()
        }
    }
}

// MARK: - Editor Settings

struct EditorSettingsView: View {
    @ObservedObject private var config = ConfigurationManager.shared
    
    var body: some View {
        Form {
            Section("Font") {
                Picker("Font Family", selection: $config.editorFontFamily) {
                    ForEach(FontOption.monospaceFonts) { font in
                        Text(font.name).tag(font.family)
                    }
                }
                
                HStack {
                    Text("Font Size")
                    Spacer()
                    TextField("", value: $config.editorFontSize, format: .number)
                        .frame(width: 60)
                    Stepper("", value: $config.editorFontSize, in: 8...32)
                }
                
                // Preview
                Text("The quick brown fox jumps over the lazy dog")
                    .font(.custom(config.editorFontFamily, size: config.editorFontSize))
                    .padding()
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
            }
            
            Section("Indentation") {
                Picker("Tab Size", selection: $config.tabSize) {
                    Text("2").tag(2)
                    Text("4").tag(4)
                    Text("8").tag(8)
                }
                
                Toggle("Insert Spaces", isOn: $config.insertSpaces)
                Toggle("Auto Indent", isOn: $config.autoIndent)
            }
            
            Section("Display") {
                Toggle("Show Line Numbers", isOn: $config.showLineNumbers)
                Toggle("Show Minimap", isOn: $config.showMinimap)
                Toggle("Highlight Current Line", isOn: $config.highlightCurrentLine)
                Toggle("Word Wrap", isOn: $config.wordWrap)
            }
            
            Section("Behavior") {
                Toggle("Auto-close Brackets", isOn: $config.autoCloseBrackets)
                Toggle("Format on Save", isOn: $config.formatOnSave)
                Toggle("Trim Trailing Whitespace", isOn: $config.trimTrailingWhitespace)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Editor")
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @ObservedObject private var config = ConfigurationManager.shared
    
    var body: some View {
        Form {
            Section("Theme") {
                Picker("Color Theme", selection: $config.theme) {
                    ForEach(ThemeOption.themes) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
                
                Picker("Accent Color", selection: $config.accentColor) {
                    Text("Blue").tag("blue")
                    Text("Purple").tag("purple")
                    Text("Pink").tag("pink")
                    Text("Red").tag("red")
                    Text("Orange").tag("orange")
                    Text("Yellow").tag("yellow")
                    Text("Green").tag("green")
                    Text("Teal").tag("teal")
                }
            }
            
            Section("Layout") {
                HStack {
                    Text("Sidebar Width")
                    Slider(value: $config.sidebarWidth, in: 180...400)
                    Text("\(Int(config.sidebarWidth))px")
                        .frame(width: 50)
                }
                
                Toggle("Show Status Bar", isOn: $config.showStatusBar)
                Toggle("Show Breadcrumbs", isOn: $config.showBreadcrumbs)
                Toggle("Compact Tabs", isOn: $config.compactTabs)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Appearance")
    }
}

// MARK: - AI Settings

struct AISettingsView: View {
    @ObservedObject private var config = ConfigurationManager.shared
    
    var body: some View {
        Form {
            Section("Model Selection") {
                Picker("Default Model", selection: $config.defaultModel) {
                    Text("Auto (Intent-based)").tag("auto")
                    ForEach(OllamaModel.allCases) { model in
                        HStack {
                            Image(systemName: model.icon)
                            Text(model.displayName)
                        }
                        .tag(model.rawValue)
                    }
                }
                
                Toggle("Show Routing Explanation", isOn: $config.showRoutingExplanation)
            }
            
            Section("Generation") {
                HStack {
                    Text("Temperature")
                    Slider(value: $config.temperature, in: 0...2)
                    Text(String(format: "%.1f", config.temperature))
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Max Tokens")
                    Spacer()
                    TextField("", value: $config.maxTokens, format: .number)
                        .frame(width: 80)
                }
                
                HStack {
                    Text("Context Window")
                    Spacer()
                    Picker("", selection: $config.contextWindow) {
                        Text("4K").tag(4096)
                        Text("8K").tag(8192)
                        Text("16K").tag(16384)
                        Text("32K").tag(32768)
                    }
                    .frame(width: 80)
                }
                
                Toggle("Stream Responses", isOn: $config.streamResponses)
            }
            
            Section("Context") {
                Toggle("Include File Context", isOn: $config.includeFileContext)
                Toggle("Include Selected Text", isOn: $config.includeSelectedText)
            }
            
            Section("Models") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(OllamaModel.allCases) { model in
                        HStack {
                            Image(systemName: model.icon)
                                .foregroundStyle(model.color)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading) {
                                Text(model.displayName)
                                    .fontWeight(.medium)
                                Text(model.purpose)
                                    .font(.caption)
                                    .foregroundStyle(DS.Colors.secondaryText)
                            }
                            
                            Spacer()
                            
                            Text(model.id)
                                .font(.caption)
                                .foregroundStyle(DS.Colors.tertiaryText)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("AI Models")
    }
}

// MARK: - Agent Settings

struct AgentSettingsView: View {
    @ObservedObject private var config = ConfigurationManager.shared
    
    var body: some View {
        Form {
            Section("Loop Control") {
                HStack {
                    Text("Max Loops")
                    Spacer()
                    TextField("", value: $config.maxLoops, format: .number)
                        .frame(width: 80)
                }
                .help("Maximum number of agent iterations before auto-stop")
                
                HStack {
                    Text("Thinking Delay")
                    Slider(value: $config.thinkingDelay, in: 0...5)
                    Text(String(format: "%.1fs", config.thinkingDelay))
                        .frame(width: 40)
                }
            }
            
            Section("Permissions") {
                Toggle("Allow Terminal Commands", isOn: $config.allowTerminalCommands)
                Toggle("Allow File Writes", isOn: $config.allowFileWrites)
                Toggle("Confirm Destructive Actions", isOn: $config.confirmDestructiveActions)
            }
            
            Section("Agent Tools") {
                Text("The agent can use these tools to complete tasks:")
                    .font(.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                
                VStack(alignment: .leading, spacing: 8) {
                    ToolInfoRow(name: "code", description: "Write/modify code files")
                    ToolInfoRow(name: "research", description: "Query knowledge via Command-R")
                    ToolInfoRow(name: "vision", description: "Analyze images with Qwen3-VL")
                    ToolInfoRow(name: "terminal", description: "Execute shell commands")
                    ToolInfoRow(name: "userInput", description: "Request user clarification")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Agent")
    }
}

// MARK: - OBot Settings

struct OBotSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var autoCheckpoint = true
    @State private var maxCheckpoints = 50
    @State private var showRulesInContext = true
    
    var body: some View {
        Form {
            Section("Project Rules (.obotrules)") {
                Toggle("Include rules in AI context", isOn: $showRulesInContext)
                    .help("Automatically include .obotrules content in every AI conversation")
                
                if let rules = appState.obotService.projectRules {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DS.Colors.success)
                        Text("Rules loaded: \(rules.sections.count) sections")
                            .font(.caption)
                    }
                } else {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(DS.Colors.secondaryText)
                        Text("No .obotrules file found in project")
                            .font(.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                }
            }
            
            Section("Bots") {
                HStack {
                    Text("Loaded Bots")
                    Spacer()
                    Text("\(appState.obotService.bots.count)")
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                
                if !appState.obotService.bots.isEmpty {
                    ForEach(appState.obotService.bots) { bot in
                        HStack {
                            Image(systemName: bot.icon ?? "cpu")
                                .frame(width: 20)
                            Text(bot.name)
                            Spacer()
                            Text("\(bot.steps.count) steps")
                                .font(.caption)
                                .foregroundStyle(DS.Colors.secondaryText)
                        }
                    }
                }
            }
            
            Section("Context Snippets") {
                HStack {
                    Text("Loaded Snippets")
                    Spacer()
                    Text("\(appState.obotService.contextSnippets.count)")
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                
                if !appState.obotService.contextSnippets.isEmpty {
                    ForEach(appState.obotService.contextSnippets) { snippet in
                        HStack {
                            Image(systemName: "doc.text")
                                .frame(width: 20)
                            Text(snippet.name)
                            Spacer()
                            Text("@\(snippet.id)")
                                .font(.caption)
                                .foregroundStyle(DS.Colors.secondaryText)
                        }
                    }
                }
            }
            
            Section("Checkpoints") {
                Toggle("Auto-checkpoint before AI changes", isOn: $autoCheckpoint)
                    .help("Automatically create a checkpoint before the agent modifies files")
                
                HStack {
                    Text("Maximum Checkpoints")
                    Spacer()
                    TextField("", value: $maxCheckpoints, format: .number)
                        .frame(width: 60)
                }
                
                HStack {
                    Text("Current Checkpoints")
                    Spacer()
                    Text("\(appState.checkpointService.checkpoints.count)")
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                
                Button("Prune Old Checkpoints") {
                    appState.checkpointService.pruneAutoCheckpoints()
                    appState.showSuccess("Auto-checkpoints pruned")
                }
                .disabled(appState.checkpointService.checkpoints.filter { $0.isAutomatic }.count <= 10)
            }
            
            Section("Templates") {
                HStack {
                    Text("Loaded Templates")
                    Spacer()
                    Text("\(appState.obotService.templates.count)")
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            }
            
            Section("Actions") {
                Button("Initialize OBot Directory") {
                    Task {
                        if let root = appState.rootFolder {
                            try? await appState.obotService.scaffoldOBotDirectory(at: root)
                            appState.showSuccess("OBot directory created!")
                        }
                    }
                }
                .disabled(appState.rootFolder == nil)
                
                Button("Reload OBot Configuration") {
                    Task {
                        if let root = appState.rootFolder {
                            await appState.obotService.loadProject(root)
                            appState.showSuccess("OBot reloaded!")
                        }
                    }
                }
                .disabled(appState.rootFolder == nil)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("OBot")
    }
}

struct ToolInfoRow: View {
    let name: String
    let description: String
    
    var body: some View {
        HStack {
            Text(name)
                .fontWeight(.medium)
                .font(.system(.body, design: .monospaced))
            Spacer()
            Text(description)
                .font(.caption)
                .foregroundStyle(DS.Colors.secondaryText)
        }
    }
}

// MARK: - Files Settings

struct FilesSettingsView: View {
    @ObservedObject private var config = ConfigurationManager.shared
    @State private var newExcludePattern: String = ""
    
    var body: some View {
        Form {
            Section("Auto Save") {
                Toggle("Enable Auto Save", isOn: $config.autoSave)
                
                if config.autoSave {
                    HStack {
                        Text("Auto Save Delay")
                        Slider(value: $config.autoSaveDelay, in: 0.5...10)
                        Text(String(format: "%.1fs", config.autoSaveDelay))
                            .frame(width: 40)
                    }
                }
            }
            
            Section("Display") {
                Toggle("Show Hidden Files", isOn: $config.showHiddenFiles)
                Toggle("Watch for External Changes", isOn: $config.watchForExternalChanges)
                Toggle("Confirm Delete", isOn: $config.confirmDelete)
            }
            
            Section("Exclude Patterns") {
                Text("Files and folders matching these patterns will be hidden from the file tree and search results.")
                    .font(.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                
                ForEach(config.excludePatterns, id: \.self) { pattern in
                    HStack {
                        Text(pattern)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button(action: {
                            config.excludePatterns.removeAll { $0 == pattern }
                        }) {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                HStack {
                    TextField("Add pattern...", text: $newExcludePattern)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Add") {
                        if !newExcludePattern.isEmpty {
                            var patterns = config.excludePatterns
                            patterns.append(newExcludePattern)
                            config.excludePatterns = patterns
                            newExcludePattern = ""
                        }
                    }
                    .disabled(newExcludePattern.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Files")
    }
}

// MARK: - Terminal Settings

struct TerminalSettingsView: View {
    @ObservedObject private var config = ConfigurationManager.shared
    
    var body: some View {
        Form {
            Section("Font") {
                Picker("Font Family", selection: $config.terminalFontFamily) {
                    ForEach(FontOption.monospaceFonts) { font in
                        Text(font.name).tag(font.family)
                    }
                }
                
                HStack {
                    Text("Font Size")
                    Spacer()
                    TextField("", value: $config.terminalFontSize, format: .number)
                        .frame(width: 60)
                    Stepper("", value: $config.terminalFontSize, in: 8...24)
                }
            }
            
            Section("Shell") {
                Picker("Default Shell", selection: $config.terminalShell) {
                    Text("/bin/zsh").tag("/bin/zsh")
                    Text("/bin/bash").tag("/bin/bash")
                    Text("/bin/sh").tag("/bin/sh")
                }
                
                HStack {
                    Text("Scrollback Lines")
                    Spacer()
                    TextField("", value: $config.terminalScrollback, format: .number)
                        .frame(width: 80)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Terminal")
    }
}

// MARK: - Git Settings

struct GitSettingsView: View {
    @ObservedObject private var config = ConfigurationManager.shared
    
    var body: some View {
        Form {
            Section("Git Integration") {
                Toggle("Enable Git", isOn: $config.gitEnabled)
                Toggle("Show Status in Sidebar", isOn: $config.showGitStatusInSidebar)
            }
            
            Section("Auto Fetch") {
                Toggle("Auto Fetch", isOn: $config.gitAutoFetch)
                
                if config.gitAutoFetch {
                    HStack {
                        Text("Fetch Interval")
                        Spacer()
                        Picker("", selection: $config.gitAutoFetchInterval) {
                            Text("1 min").tag(60)
                            Text("5 min").tag(300)
                            Text("15 min").tag(900)
                            Text("30 min").tag(1800)
                        }
                        .frame(width: 100)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Git")
    }
}

// MARK: - Keyboard Settings

struct KeyboardSettingsView: View {
    var body: some View {
        Form {
            Section("Command Palette") {
                KeyboardShortcutRow(command: "Command Palette", shortcut: "⌘⇧P")
                KeyboardShortcutRow(command: "Quick Open", shortcut: "⌘P")
                KeyboardShortcutRow(command: "Search in Files", shortcut: "⌘⇧F")
            }
            
            Section("Editor") {
                KeyboardShortcutRow(command: "Find", shortcut: "⌘F")
                KeyboardShortcutRow(command: "Find and Replace", shortcut: "⌘⌥F")
                KeyboardShortcutRow(command: "Go to Line", shortcut: "⌃G")
                KeyboardShortcutRow(command: "Save", shortcut: "⌘S")
            }
            
            Section("View") {
                KeyboardShortcutRow(command: "Toggle Sidebar", shortcut: "⌘B")
                KeyboardShortcutRow(command: "Toggle Terminal", shortcut: "⌃`")
                KeyboardShortcutRow(command: "Increase Font Size", shortcut: "⌘+")
                KeyboardShortcutRow(command: "Decrease Font Size", shortcut: "⌘-")
            }
            
            Section("AI") {
                KeyboardShortcutRow(command: "Toggle Infinite Mode", shortcut: "⌘⇧I")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Keyboard Shortcuts")
    }
}

struct KeyboardShortcutRow: View {
    let command: String
    let shortcut: String
    
    var body: some View {
        HStack {
            Text(command)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(4)
        }
    }
}
