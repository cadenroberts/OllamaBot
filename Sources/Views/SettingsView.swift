import SwiftUI

// MARK: - Settings View
// Styled to match OllamaBot's design system

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: SettingsTab = .editor
    
    enum SettingsTab: String, CaseIterable, Identifiable {
        case editor = "Editor"
        case appearance = "Appearance"
        case ai = "AI Models"
        case agent = "Agent"
        case obot = "OBot"
        case files = "Files"
        case terminal = "Terminal"
        case git = "Git"
        case keyboard = "Keyboard"
        
        var id: String { rawValue }
        
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
        HStack(spacing: 0) {
            // Sidebar
            settingsSidebar
                .frame(width: 200)
            
            // Divider
            Rectangle()
                .fill(DS.Colors.border)
                .frame(width: 1)
            
            // Content
            settingsContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DS.Colors.background)
    }
    
    // MARK: - Sidebar
    
    private var settingsSidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(DS.Colors.accent)
                
                Text("Settings")
                    .font(DS.Typography.headline)
                
                Spacer()
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surface)
            
            DSDivider()
            
            // Tab list
            ScrollView {
                VStack(spacing: DS.Spacing.xs) {
                    ForEach(SettingsTab.allCases) { tab in
                        SettingsTabButton(
                            tab: tab,
                            isSelected: selectedTab == tab
                        ) {
                            selectedTab = tab
                        }
                    }
                }
                .padding(DS.Spacing.sm)
            }
        }
        .background(DS.Colors.secondaryBackground)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var settingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // Title
                Text(selectedTab.rawValue)
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.Colors.text)
                    .padding(.bottom, DS.Spacing.sm)
                
                // Content based on tab
                switch selectedTab {
                case .editor:
                    EditorSettingsContent()
                case .appearance:
                    AppearanceSettingsContent()
                case .ai:
                    AISettingsContent()
                case .agent:
                    AgentSettingsContent()
                case .obot:
                    OBotSettingsContent()
                case .files:
                    FilesSettingsContent()
                case .terminal:
                    TerminalSettingsContent()
                case .git:
                    GitSettingsContent()
                case .keyboard:
                    KeyboardSettingsContent()
                }
            }
            .padding(DS.Spacing.lg)
        }
        .background(DS.Colors.background)
    }
}

// MARK: - Settings Tab Button

struct SettingsTabButton: View {
    let tab: SettingsView.SettingsTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: tab.icon)
                    .font(.caption)
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.secondaryText)
                
                Text(tab.rawValue)
                    .font(DS.Typography.callout)
                    .foregroundStyle(isSelected ? DS.Colors.text : DS.Colors.secondaryText)
                
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.sm)
            .background(isSelected ? DS.Colors.accent.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(title.uppercased())
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(DS.Colors.secondaryText)
            
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                content
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
    }
}

// MARK: - Settings Row

struct SettingsRow<Content: View>: View {
    let label: String
    let content: Content
    
    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(DS.Typography.callout)
                .foregroundStyle(DS.Colors.text)
            
            Spacer()
            
            content
        }
    }
}

// MARK: - Settings Toggle

struct SettingsToggle: View {
    let label: String
    @Binding var isOn: Bool
    var help: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.text)
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .toggleStyle(.switch)
                    .tint(DS.Colors.accent)
            }
            
            if let help = help {
                Text(help)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
        }
    }
}

// MARK: - Editor Settings Content

struct EditorSettingsContent: View {
    @ObservedObject private var config = ConfigurationManager.shared
    
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            SettingsSection("Font") {
                SettingsRow("Font Family") {
                    Picker("", selection: $config.editorFontFamily) {
                        ForEach(FontOption.monospaceFonts) { font in
                            Text(font.name).tag(font.family)
                        }
                    }
                    .frame(width: 180)
                    .pickerStyle(.menu)
                }
                
                DSDivider()
                
                SettingsRow("Font Size") {
                    HStack(spacing: DS.Spacing.sm) {
                        TextField("", value: $config.editorFontSize, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        
                        Stepper("", value: $config.editorFontSize, in: 8...32)
                            .labelsHidden()
                    }
                }
                
                DSDivider()
                
                // Preview
                Text("The quick brown fox jumps over the lazy dog")
                    .font(.custom(config.editorFontFamily, size: config.editorFontSize))
                    .foregroundStyle(DS.Colors.text)
                    .padding(DS.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Colors.codeBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            
            SettingsSection("Indentation") {
                SettingsRow("Tab Size") {
                    Picker("", selection: $config.tabSize) {
                        Text("2").tag(2)
                        Text("4").tag(4)
                        Text("8").tag(8)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                
                DSDivider()
                
                SettingsToggle(label: "Insert Spaces", isOn: $config.insertSpaces)
                
                DSDivider()
                
                SettingsToggle(label: "Auto Indent", isOn: $config.autoIndent)
            }
            
            SettingsSection("Display") {
                SettingsToggle(label: "Show Line Numbers", isOn: $config.showLineNumbers)
                DSDivider()
                SettingsToggle(label: "Show Minimap", isOn: $config.showMinimap)
                DSDivider()
                SettingsToggle(label: "Highlight Current Line", isOn: $config.highlightCurrentLine)
                DSDivider()
                SettingsToggle(label: "Word Wrap", isOn: $config.wordWrap)
            }
            
            SettingsSection("Behavior") {
                SettingsToggle(label: "Auto-close Brackets", isOn: $config.autoCloseBrackets)
                DSDivider()
                SettingsToggle(label: "Format on Save", isOn: $config.formatOnSave)
                DSDivider()
                SettingsToggle(label: "Trim Trailing Whitespace", isOn: $config.trimTrailingWhitespace)
            }
        }
    }
}

// MARK: - Appearance Settings Content

struct AppearanceSettingsContent: View {
    @ObservedObject private var config = ConfigurationManager.shared
    
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            SettingsSection("Theme") {
                SettingsRow("Color Theme") {
                    Picker("", selection: $config.theme) {
                        ForEach(ThemeOption.themes) { theme in
                            Text(theme.name).tag(theme.id)
                        }
                    }
                    .frame(width: 150)
                    .pickerStyle(.menu)
                }
                
                DSDivider()
                
                SettingsRow("Accent Color") {
                    Picker("", selection: $config.accentColor) {
                        Text("Blue").tag("blue")
                        Text("Purple").tag("purple")
                        Text("Pink").tag("pink")
                        Text("Red").tag("red")
                        Text("Orange").tag("orange")
                        Text("Green").tag("green")
                        Text("Teal").tag("teal")
                    }
                    .frame(width: 120)
                    .pickerStyle(.menu)
                }
            }
            
            SettingsSection("Layout") {
                SettingsRow("Sidebar Width") {
                    HStack(spacing: DS.Spacing.sm) {
                        Slider(value: $config.sidebarWidth, in: 180...400)
                            .frame(width: 150)
                        
                        Text("\(Int(config.sidebarWidth))px")
                            .font(DS.Typography.mono(11))
                            .foregroundStyle(DS.Colors.secondaryText)
                            .frame(width: 50)
                    }
                }
                
                DSDivider()
                
                SettingsToggle(label: "Show Status Bar", isOn: $config.showStatusBar)
                DSDivider()
                SettingsToggle(label: "Show Breadcrumbs", isOn: $config.showBreadcrumbs)
                DSDivider()
                SettingsToggle(label: "Compact Tabs", isOn: $config.compactTabs)
            }
        }
    }
}

// MARK: - AI Settings Content

struct AISettingsContent: View {
    @ObservedObject private var config = ConfigurationManager.shared
    
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            SettingsSection("Model Selection") {
                SettingsRow("Default Model") {
                    Picker("", selection: $config.defaultModel) {
                        Text("Auto (Intent-based)").tag("auto")
                        ForEach(OllamaModel.allCases) { model in
                            HStack {
                                Image(systemName: model.icon)
                                Text(model.displayName)
                            }
                            .tag(model.rawValue)
                        }
                    }
                    .frame(width: 180)
                    .pickerStyle(.menu)
                }
                
                DSDivider()
                
                SettingsToggle(label: "Show Routing Explanation", isOn: $config.showRoutingExplanation)
            }
            
            SettingsSection("Generation") {
                SettingsRow("Temperature") {
                    HStack(spacing: DS.Spacing.sm) {
                        Slider(value: $config.temperature, in: 0...2)
                            .frame(width: 150)
                        
                        Text(String(format: "%.1f", config.temperature))
                            .font(DS.Typography.mono(11))
                            .foregroundStyle(DS.Colors.secondaryText)
                            .frame(width: 40)
                    }
                }
                
                DSDivider()
                
                SettingsRow("Max Tokens") {
                    TextField("", value: $config.maxTokens, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                
                DSDivider()
                
                SettingsRow("Context Window") {
                    Picker("", selection: $config.contextWindow) {
                        Text("4K").tag(4096)
                        Text("8K").tag(8192)
                        Text("16K").tag(16384)
                        Text("32K").tag(32768)
                    }
                    .frame(width: 100)
                    .pickerStyle(.menu)
                }
                
                DSDivider()
                
                SettingsToggle(label: "Stream Responses", isOn: $config.streamResponses)
            }
            
            SettingsSection("Context") {
                SettingsToggle(label: "Include File Context", isOn: $config.includeFileContext)
                DSDivider()
                SettingsToggle(label: "Include Selected Text", isOn: $config.includeSelectedText)
            }
            
            SettingsSection("Available Models") {
                ForEach(OllamaModel.allCases) { model in
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: model.icon)
                            .foregroundStyle(model.color)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.displayName)
                                .font(DS.Typography.callout.weight(.medium))
                                .foregroundStyle(DS.Colors.text)
                            Text(model.purpose)
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.secondaryText)
                        }
                        
                        Spacer()
                        
                        Text(model.id)
                            .font(DS.Typography.mono(10))
                            .foregroundStyle(DS.Colors.tertiaryText)
                    }
                    
                    if model != OllamaModel.allCases.last {
                        DSDivider()
                    }
                }
            }
        }
    }
}

// MARK: - Agent Settings Content

struct AgentSettingsContent: View {
    @ObservedObject private var config = ConfigurationManager.shared
    
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            SettingsSection("Loop Control") {
                SettingsRow("Max Loops") {
                    TextField("", value: $config.maxLoops, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                
                DSDivider()
                
                SettingsRow("Thinking Delay") {
                    HStack(spacing: DS.Spacing.sm) {
                        Slider(value: $config.thinkingDelay, in: 0...5)
                            .frame(width: 150)
                        
                        Text(String(format: "%.1fs", config.thinkingDelay))
                            .font(DS.Typography.mono(11))
                            .foregroundStyle(DS.Colors.secondaryText)
                            .frame(width: 40)
                    }
                }
            }
            
            SettingsSection("Permissions") {
                SettingsToggle(label: "Allow Terminal Commands", isOn: $config.allowTerminalCommands)
                DSDivider()
                SettingsToggle(label: "Allow File Writes", isOn: $config.allowFileWrites)
                DSDivider()
                SettingsToggle(label: "Confirm Destructive Actions", isOn: $config.confirmDestructiveActions)
            }
            
            SettingsSection("Agent Tools") {
                Text("The agent can use these tools to complete tasks:")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .padding(.bottom, DS.Spacing.xs)
                
                ToolInfoCard(name: "code", description: "Write/modify code files", icon: "chevron.left.forwardslash.chevron.right")
                DSDivider()
                ToolInfoCard(name: "research", description: "Query knowledge via Command-R", icon: "magnifyingglass")
                DSDivider()
                ToolInfoCard(name: "vision", description: "Analyze images with Qwen3-VL", icon: "eye")
                DSDivider()
                ToolInfoCard(name: "terminal", description: "Execute shell commands", icon: "terminal")
                DSDivider()
                ToolInfoCard(name: "userInput", description: "Request user clarification", icon: "person.fill.questionmark")
            }
        }
    }
}

struct ToolInfoCard: View {
    let name: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(DS.Colors.accent)
                .frame(width: 20)
            
            Text(name)
                .font(DS.Typography.mono(12))
                .foregroundStyle(DS.Colors.text)
                .frame(width: 80, alignment: .leading)
            
            Text(description)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
            
            Spacer()
        }
    }
}

// MARK: - OBot Settings Content

struct OBotSettingsContent: View {
    @Environment(AppState.self) private var appState
    @State private var autoCheckpoint = true
    @State private var maxCheckpoints = 50
    @State private var showRulesInContext = true
    
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            SettingsSection("Project Rules (.obotrules)") {
                SettingsToggle(
                    label: "Include rules in AI context",
                    isOn: $showRulesInContext,
                    help: "Automatically include .obotrules content in every AI conversation"
                )
                
                DSDivider()
                
                HStack(spacing: DS.Spacing.sm) {
                    if appState.obotService.projectRules != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DS.Colors.success)
                        Text("Rules loaded: \(appState.obotService.projectRules?.sections.count ?? 0) sections")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                    } else {
                        Image(systemName: "info.circle")
                            .foregroundStyle(DS.Colors.secondaryText)
                        Text("No .obotrules file found in project")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.tertiaryText)
                    }
                    Spacer()
                }
            }
            
            SettingsSection("Bots") {
                SettingsRow("Loaded Bots") {
                    Text("\(appState.obotService.bots.count)")
                        .font(DS.Typography.mono(12))
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                
                if !appState.obotService.bots.isEmpty {
                    DSDivider()
                    
                    ForEach(appState.obotService.bots) { bot in
                        HStack {
                            Image(systemName: bot.icon ?? "cpu")
                                .foregroundStyle(DS.Colors.accent)
                                .frame(width: 20)
                            
                            Text(bot.name)
                                .font(DS.Typography.callout)
                                .foregroundStyle(DS.Colors.text)
                            
                            Spacer()
                            
                            Text("\(bot.steps.count) steps")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.tertiaryText)
                        }
                        
                        if bot.id != appState.obotService.bots.last?.id {
                            DSDivider()
                        }
                    }
                }
            }
            
            SettingsSection("Checkpoints") {
                SettingsToggle(
                    label: "Auto-checkpoint before AI changes",
                    isOn: $autoCheckpoint,
                    help: "Automatically create a checkpoint before the agent modifies files"
                )
                
                DSDivider()
                
                SettingsRow("Maximum Checkpoints") {
                    TextField("", value: $maxCheckpoints, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                }
                
                DSDivider()
                
                SettingsRow("Current Checkpoints") {
                    Text("\(appState.checkpointService.checkpoints.count)")
                        .font(DS.Typography.mono(12))
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                
                DSDivider()
                
                Button {
                    appState.checkpointService.pruneAutoCheckpoints()
                    appState.showSuccess("Auto-checkpoints pruned")
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Prune Old Checkpoints")
                    }
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.warning)
                }
                .buttonStyle(.plain)
                .disabled(appState.checkpointService.checkpoints.filter { $0.isAutomatic }.count <= 10)
            }
            
            SettingsSection("Actions") {
                HStack(spacing: DS.Spacing.md) {
                    Button {
                        Task {
                            if let root = appState.rootFolder {
                                try? await appState.obotService.scaffoldOBotDirectory(at: root)
                                appState.showSuccess("OBot directory created!")
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                            Text("Initialize OBot Directory")
                        }
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.accent)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Colors.accent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.plain)
                    .disabled(appState.rootFolder == nil)
                    
                    Button {
                        Task {
                            if let root = appState.rootFolder {
                                await appState.obotService.loadProject(root)
                                appState.showSuccess("OBot reloaded!")
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Reload Configuration")
                        }
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Colors.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.plain)
                    .disabled(appState.rootFolder == nil)
                    
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Files Settings Content

struct FilesSettingsContent: View {
    @ObservedObject private var config = ConfigurationManager.shared
    @State private var newExcludePattern: String = ""
    
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            SettingsSection("Auto Save") {
                SettingsToggle(label: "Enable Auto Save", isOn: $config.autoSave)
                
                if config.autoSave {
                    DSDivider()
                    
                    SettingsRow("Auto Save Delay") {
                        HStack(spacing: DS.Spacing.sm) {
                            Slider(value: $config.autoSaveDelay, in: 0.5...10)
                                .frame(width: 150)
                            
                            Text(String(format: "%.1fs", config.autoSaveDelay))
                                .font(DS.Typography.mono(11))
                                .foregroundStyle(DS.Colors.secondaryText)
                                .frame(width: 40)
                        }
                    }
                }
            }
            
            SettingsSection("Display") {
                SettingsToggle(label: "Show Hidden Files", isOn: $config.showHiddenFiles)
                DSDivider()
                SettingsToggle(label: "Watch for External Changes", isOn: $config.watchForExternalChanges)
                DSDivider()
                SettingsToggle(label: "Confirm Delete", isOn: $config.confirmDelete)
            }
            
            SettingsSection("Exclude Patterns") {
                Text("Files and folders matching these patterns will be hidden.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.tertiaryText)
                    .padding(.bottom, DS.Spacing.xs)
                
                ForEach(config.excludePatterns, id: \.self) { pattern in
                    HStack {
                        Text(pattern)
                            .font(DS.Typography.mono(12))
                            .foregroundStyle(DS.Colors.text)
                        
                        Spacer()
                        
                        Button {
                            config.excludePatterns.removeAll { $0 == pattern }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(DS.Colors.error)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    DSDivider()
                }
                
                HStack(spacing: DS.Spacing.sm) {
                    TextField("Add pattern...", text: $newExcludePattern)
                        .textFieldStyle(.roundedBorder)
                        .font(DS.Typography.mono(12))
                    
                    Button {
                        if !newExcludePattern.isEmpty {
                            var patterns = config.excludePatterns
                            patterns.append(newExcludePattern)
                            config.excludePatterns = patterns
                            newExcludePattern = ""
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(DS.Colors.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(newExcludePattern.isEmpty)
                }
            }
        }
    }
}

// MARK: - Terminal Settings Content

struct TerminalSettingsContent: View {
    @ObservedObject private var config = ConfigurationManager.shared
    
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            SettingsSection("Font") {
                SettingsRow("Font Family") {
                    Picker("", selection: $config.terminalFontFamily) {
                        ForEach(FontOption.monospaceFonts) { font in
                            Text(font.name).tag(font.family)
                        }
                    }
                    .frame(width: 180)
                    .pickerStyle(.menu)
                }
                
                DSDivider()
                
                SettingsRow("Font Size") {
                    HStack(spacing: DS.Spacing.sm) {
                        TextField("", value: $config.terminalFontSize, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        
                        Stepper("", value: $config.terminalFontSize, in: 8...24)
                            .labelsHidden()
                    }
                }
            }
            
            SettingsSection("Shell") {
                SettingsRow("Default Shell") {
                    Picker("", selection: $config.terminalShell) {
                        Text("/bin/zsh").tag("/bin/zsh")
                        Text("/bin/bash").tag("/bin/bash")
                        Text("/bin/sh").tag("/bin/sh")
                    }
                    .frame(width: 150)
                    .pickerStyle(.menu)
                }
                
                DSDivider()
                
                SettingsRow("Scrollback Lines") {
                    TextField("", value: $config.terminalScrollback, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
            }
        }
    }
}

// MARK: - Git Settings Content

struct GitSettingsContent: View {
    @ObservedObject private var config = ConfigurationManager.shared
    
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            SettingsSection("Git Integration") {
                SettingsToggle(label: "Enable Git", isOn: $config.gitEnabled)
                DSDivider()
                SettingsToggle(label: "Show Status in Sidebar", isOn: $config.showGitStatusInSidebar)
            }
            
            SettingsSection("Auto Fetch") {
                SettingsToggle(label: "Auto Fetch", isOn: $config.gitAutoFetch)
                
                if config.gitAutoFetch {
                    DSDivider()
                    
                    SettingsRow("Fetch Interval") {
                        Picker("", selection: $config.gitAutoFetchInterval) {
                            Text("1 min").tag(60)
                            Text("5 min").tag(300)
                            Text("15 min").tag(900)
                            Text("30 min").tag(1800)
                        }
                        .frame(width: 100)
                        .pickerStyle(.menu)
                    }
                }
            }
        }
    }
}

// MARK: - Keyboard Settings Content

struct KeyboardSettingsContent: View {
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            SettingsSection("Command Palette") {
                KeyboardShortcutCard(command: "Command Palette", shortcut: "⌘⇧P")
                DSDivider()
                KeyboardShortcutCard(command: "Quick Open", shortcut: "⌘P")
                DSDivider()
                KeyboardShortcutCard(command: "Search in Files", shortcut: "⌘⇧F")
            }
            
            SettingsSection("Editor") {
                KeyboardShortcutCard(command: "Find", shortcut: "⌘F")
                DSDivider()
                KeyboardShortcutCard(command: "Find and Replace", shortcut: "⌘⌥F")
                DSDivider()
                KeyboardShortcutCard(command: "Go to Line", shortcut: "⌃G")
                DSDivider()
                KeyboardShortcutCard(command: "Save", shortcut: "⌘S")
            }
            
            SettingsSection("View") {
                KeyboardShortcutCard(command: "Toggle Sidebar", shortcut: "⌘B")
                DSDivider()
                KeyboardShortcutCard(command: "Toggle Terminal", shortcut: "⌃`")
                DSDivider()
                KeyboardShortcutCard(command: "Increase Font Size", shortcut: "⌘+")
                DSDivider()
                KeyboardShortcutCard(command: "Decrease Font Size", shortcut: "⌘-")
            }
            
            SettingsSection("AI") {
                KeyboardShortcutCard(command: "Toggle Infinite Mode", shortcut: "⌘⇧I")
                DSDivider()
                KeyboardShortcutCard(command: "Performance Dashboard", shortcut: "⌘⇧D")
            }
        }
    }
}

struct KeyboardShortcutCard: View {
    let command: String
    let shortcut: String
    
    var body: some View {
        HStack {
            Text(command)
                .font(DS.Typography.callout)
                .foregroundStyle(DS.Colors.text)
            
            Spacer()
            
            Text(shortcut)
                .font(DS.Typography.mono(12))
                .foregroundStyle(DS.Colors.accent)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(DS.Colors.accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
        }
    }
}

// MARK: - Preview compatibility types (removed old structs)
// EditorSettingsView, AppearanceSettingsView, etc. are now renamed to *Content
