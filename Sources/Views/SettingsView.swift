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
            DSScrollView {
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
        DSScrollView {
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
                
                // Custom Switch
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? DS.Colors.accent : DS.Colors.tertiaryBackground)
                        .frame(width: 36, height: 20)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .padding(.horizontal, 2)
                        .shadow(radius: 1)
                }
                .animation(DS.Animation.fast, value: isOn)
                .onTapGesture {
                    isOn.toggle()
                }
            }
            
            if let help = help {
                Text(help)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
        }
    }
}

// MARK: - Custom Settings Components

struct DSSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DS.Colors.tertiaryBackground)
                    .frame(height: 4)
                
                Capsule()
                    .fill(DS.Colors.accent)
                    .frame(width: width(for: geometry.size.width), height: 4)
                
                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .shadow(radius: 1)
                    .offset(x: width(for: geometry.size.width) - 8)
                    .gesture(
                        DragGesture()
                            .onChanged { v in
                                let percent = min(max(0, v.location.x / geometry.size.width), 1)
                                value = range.lowerBound + (range.upperBound - range.lowerBound) * percent
                            }
                    )
            }
        }
        .frame(height: 16)
    }
    
    private func width(for totalWidth: CGFloat) -> CGFloat {
        let percent = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return totalWidth * CGFloat(percent)
    }
}

struct DSDropdown<T: Hashable, Label: View, Row: View>: View {
    @Binding var selection: T
    let options: [T]
    let label: (T) -> Label
    let row: (T) -> Row
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(DS.Animation.fast) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    label(selection)
                        .font(DS.Typography.callout)
                        .foregroundStyle(DS.Colors.text)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 6)
                .background(DS.Colors.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            selection = option
                            withAnimation(DS.Animation.fast) {
                                isExpanded = false
                            }
                        } label: {
                            HStack {
                                if selection == option {
                                    Image(systemName: "checkmark")
                                        .font(.caption2)
                                        .foregroundStyle(DS.Colors.accent)
                                } else {
                                    Color.clear.frame(width: 12, height: 12)
                                }
                                
                                row(option)
                                    .font(DS.Typography.callout)
                                    .foregroundStyle(DS.Colors.text)
                                
                                Spacer()
                            }
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(selection == option ? DS.Colors.accent.opacity(0.1) : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, DS.Spacing.xs)
                .background(DS.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(DS.Colors.border, lineWidth: 1)
                )
            }
        }
    }
}

struct DSIntStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    
    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            DSIconButton(icon: "minus", size: 18) {
                let newValue = value - step
                value = max(newValue, range.lowerBound)
            }
            
            DSIconButton(icon: "plus", size: 18) {
                let newValue = value + step
                value = min(newValue, range.upperBound)
            }
        }
    }
}

struct DSDoubleStepper: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    
    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            DSIconButton(icon: "minus", size: 18) {
                let newValue = value - step
                value = max(newValue, range.lowerBound)
            }
            
            DSIconButton(icon: "plus", size: 18) {
                let newValue = value + step
                value = min(newValue, range.upperBound)
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
                    DSDropdown(
                        selection: $config.editorFontFamily,
                        options: FontOption.monospaceFonts.map { $0.family },
                        label: { family in
                            Text(FontOption.monospaceFonts.first(where: { $0.family == family })?.name ?? family)
                        },
                        row: { family in
                            Text(FontOption.monospaceFonts.first(where: { $0.family == family })?.name ?? family)
                        }
                    )
                    .frame(width: 180)
                }
                
                DSDivider()
                
                SettingsRow("Font Size") {
                    HStack(spacing: DS.Spacing.sm) {
                        TextField("", value: $config.editorFontSize, format: .number)
                            .textFieldStyle(.plain)
                            .padding(4)
                            .background(DS.Colors.tertiaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                            .frame(width: 60)
                            .foregroundStyle(DS.Colors.text)
                        
                        DSDoubleStepper(value: $config.editorFontSize, range: 8...32, step: 1)
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
                    HStack(spacing: 0) {
                        ForEach([2, 4, 8], id: \.self) { size in
                            Button {
                                config.tabSize = size
                            } label: {
                                Text("\(size)")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(config.tabSize == size ? DS.Colors.accent : DS.Colors.secondaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(config.tabSize == size ? DS.Colors.accent.opacity(0.1) : Color.clear)
                            }
                            .buttonStyle(.plain)
                            
                            if size != 8 {
                                Rectangle()
                                    .fill(DS.Colors.divider)
                                    .frame(width: 1, height: 16)
                            }
                        }
                    }
                    .background(DS.Colors.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
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
                    DSDropdown(
                        selection: $config.theme,
                        options: ThemeOption.themes.map { $0.id },
                        label: { themeId in
                            Text(ThemeOption.themes.first(where: { $0.id == themeId })?.name ?? themeId)
                        },
                        row: { themeId in
                            Text(ThemeOption.themes.first(where: { $0.id == themeId })?.name ?? themeId)
                        }
                    )
                    .frame(width: 150)
                }
                
                DSDivider()
                
                SettingsRow("Accent Color") {
                    let colors = ["blue", "purple", "pink", "red", "orange", "green", "teal"]
                    DSDropdown(
                        selection: $config.accentColor,
                        options: colors,
                        label: { color in Text(color.capitalized) },
                        row: { color in Text(color.capitalized) }
                    )
                    .frame(width: 120)
                }
            }
            
            SettingsSection("Layout") {
                SettingsRow("Sidebar Width") {
                    HStack(spacing: DS.Spacing.sm) {
                        DSSlider(value: $config.sidebarWidth, range: 180...400)
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
                    let modelOptions = ["auto"] + OllamaModel.allCases.map { $0.rawValue }
                    DSDropdown(
                        selection: $config.defaultModel,
                        options: modelOptions,
                        label: { id in
                            if id == "auto" {
                                return AnyView(Text("Auto (Intent-based)"))
                            } else if let model = OllamaModel(rawValue: id) {
                                return AnyView(HStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: model.icon)
                                    Text(model.displayName)
                                })
                            } else {
                                return AnyView(Text(id))
                            }
                        },
                        row: { id in
                            if id == "auto" {
                                return AnyView(Text("Auto (Intent-based)"))
                            } else if let model = OllamaModel(rawValue: id) {
                                return AnyView(HStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: model.icon)
                                    Text(model.displayName)
                                })
                            } else {
                                return AnyView(Text(id))
                            }
                        }
                    )
                    .frame(width: 180)
                }
                
                DSDivider()
                
                SettingsToggle(label: "Show Routing Explanation", isOn: $config.showRoutingExplanation)
            }
            
            SettingsSection("Generation") {
                SettingsRow("Temperature") {
                    HStack(spacing: DS.Spacing.sm) {
                        DSSlider(value: $config.temperature, range: 0...2)
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
                        .textFieldStyle(.plain)
                        .padding(4)
                        .background(DS.Colors.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                        .frame(width: 100)
                        .foregroundStyle(DS.Colors.text)
                }
                
                DSDivider()
                
                SettingsRow("Context Window") {
                    let options = [4096, 8192, 16384, 32768]
                    DSDropdown(
                        selection: $config.contextWindow,
                        options: options,
                        label: { size in Text("\(size/1024)K") },
                        row: { size in Text("\(size/1024)K") }
                    )
                    .frame(width: 100)
                }
                
                DSDivider()
                
                SettingsToggle(label: "Stream Responses", isOn: $config.streamResponses)
            }
            
            SettingsSection("Context") {
                SettingsToggle(label: "Include File Context", isOn: $config.includeFileContext)
                DSDivider()
                SettingsToggle(label: "Include Selected Text", isOn: $config.includeSelectedText)
            }

            RAMTierSettingsContent()
            
            ExternalModelsSettingsContent()
            
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

// MARK: - RAM Tier Settings Content

struct RAMTierSettingsContent: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTier: ModelTierManager.ModelTier = .performance
    @State private var isInstalling = false
    @State private var installProgress: Double = 0
    @State private var installStatus: String = ""
    @State private var cronEnabled = false
    @State private var installComplete = false
    
    var body: some View {
        SettingsSection("RAM Optimization") {
            Text("Select a tier based on your available RAM. Lower tiers use smaller models that require less memory.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
                .padding(.bottom, DS.Spacing.xs)
            
            // Tier cards
            VStack(spacing: DS.Spacing.sm) {
                ForEach(ModelTierManager.ModelTier.allCases, id: \.self) { tier in
                    RAMTierCard(
                        tier: tier,
                        isSelected: selectedTier == tier,
                        isRecommended: tier == appState.modelTierManager.recommendedTier,
                        systemRAM: appState.modelTierManager.systemRAM
                    ) {
                        withAnimation(DS.Animation.fast) {
                            selectedTier = tier
                            installComplete = false
                        }
                    }
                }
            }
            
            DSDivider()
            
            // Current vs selected comparison
            if selectedTier != appState.modelTierManager.selectedTier {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(DS.Colors.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Switch from \(appState.modelTierManager.selectedTier.rawValue) to \(selectedTier.rawValue)")
                            .font(DS.Typography.callout.weight(.medium))
                            .foregroundStyle(DS.Colors.text)
                        Text(selectedTier.description)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                    Spacer()
                }
                .padding(DS.Spacing.sm)
                .background(DS.Colors.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                
                DSDivider()
                
                // Install controls
                if isInstalling {
                    VStack(spacing: DS.Spacing.sm) {
                        HStack {
                            DSLoadingSpinner(size: 14)
                            Text(installStatus)
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.secondaryText)
                            Spacer()
                        }
                        
                        DSProgressBar(
                            progress: installProgress,
                            showPercentage: true,
                            color: DS.Colors.accent,
                            height: 6
                        )
                    }
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                } else if installComplete {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DS.Colors.success)
                        Text("Tier switched to \(selectedTier.rawValue)")
                            .font(DS.Typography.callout)
                            .foregroundStyle(DS.Colors.text)
                        Spacer()
                    }
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.success.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                } else {
                    HStack(spacing: DS.Spacing.md) {
                        DSButton("Apply & Pull Models", icon: "arrow.down.circle", style: .primary, size: .sm) {
                            startInstall()
                        }
                        
                        DSButton("Apply Only", icon: "checkmark", style: .secondary, size: .sm) {
                            applyTierOnly()
                        }
                    }
                }
            }
            
            DSDivider()
            
            // Cron auto-install toggle
            SettingsToggle(
                label: "Background Auto-Install",
                isOn: $cronEnabled,
                help: "Schedule model downloads to run in the background when idle. Models are pulled via launchd so you don't have to wait."
            )
            .onChange(of: cronEnabled) { _, enabled in
                if enabled {
                    scheduleCronInstall()
                } else {
                    removeCronInstall()
                }
            }
        }
        .onAppear {
            selectedTier = appState.modelTierManager.selectedTier
            cronEnabled = checkCronExists()
        }
    }
    
    private func applyTierOnly() {
        appState.modelTierManager.selectedTier = selectedTier
        appState.modelTierManager.saveConfiguration()
        installComplete = true
        appState.showSuccess("Switched to \(selectedTier.rawValue) tier")
    }
    
    private func startInstall() {
        isInstalling = true
        installProgress = 0
        installStatus = "Preparing..."
        
        Task {
            appState.modelTierManager.selectedTier = selectedTier
            let models = appState.modelTierManager.getModelsToDownload()
            let totalModels = Double(models.count)
            
            for (index, model) in models.enumerated() {
                await MainActor.run {
                    installStatus = "Pulling \(model.role): \(model.variant.name)..."
                    installProgress = Double(index) / totalModels
                }
                
                // Run ollama pull in background
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ollama")
                process.arguments = ["pull", model.variant.ollamaTag]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                
                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    // Try alternative path
                    let altProcess = Process()
                    altProcess.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ollama")
                    altProcess.arguments = ["pull", model.variant.ollamaTag]
                    altProcess.standardOutput = FileHandle.nullDevice
                    altProcess.standardError = FileHandle.nullDevice
                    try? altProcess.run()
                    altProcess.waitUntilExit()
                }
                
                await MainActor.run {
                    installProgress = Double(index + 1) / totalModels
                }
            }
            
            appState.modelTierManager.saveConfiguration()
            
            await MainActor.run {
                isInstalling = false
                installComplete = true
                installProgress = 1.0
                installStatus = ""
                appState.showSuccess("All models for \(selectedTier.rawValue) tier installed")
            }
        }
    }
    
    private func scheduleCronInstall() {
        let models = appState.modelTierManager.getOllamaTags()
        let pullCommands = models.map { "ollama pull \($0)" }.joined(separator: " && ")
        
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.ollamabot.model-pull</string>
            <key>ProgramArguments</key>
            <array>
                <string>/bin/sh</string>
                <string>-c</string>
                <string>\(pullCommands)</string>
            </array>
            <key>StartInterval</key>
            <integer>86400</integer>
            <key>RunAtLoad</key>
            <false/>
        </dict>
        </plist>
        """
        
        let launchAgentsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        try? FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
        
        let plistPath = launchAgentsDir.appendingPathComponent("com.ollamabot.model-pull.plist")
        try? plistContent.write(to: plistPath, atomically: true, encoding: .utf8)
        
        // Load the agent
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", plistPath.path]
        try? process.run()
        process.waitUntilExit()
    }
    
    private func removeCronInstall() {
        let plistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.ollamabot.model-pull.plist")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", plistPath.path]
        try? process.run()
        process.waitUntilExit()
        
        try? FileManager.default.removeItem(at: plistPath)
    }
    
    private func checkCronExists() -> Bool {
        let plistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.ollamabot.model-pull.plist")
        return FileManager.default.fileExists(atPath: plistPath.path)
    }
}

struct RAMTierCard: View {
    let tier: ModelTierManager.ModelTier
    let isSelected: Bool
    let isRecommended: Bool
    let systemRAM: Int
    let action: () -> Void
    
    private var isAvailable: Bool { systemRAM >= tier.minRAM }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                // Indicator
                Circle()
                    .fill(isSelected ? DS.Colors.accent : DS.Colors.tertiaryBackground)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .fill(isSelected ? .white : Color.clear)
                            .frame(width: 6, height: 6)
                    )
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(tier.rawValue)
                            .font(DS.Typography.callout.weight(.medium))
                            .foregroundStyle(isAvailable ? DS.Colors.text : DS.Colors.tertiaryText)
                        
                        if isRecommended {
                            DSBadge(text: "Recommended", color: DS.Colors.accent, size: .sm)
                        }
                        
                        if !isAvailable {
                            DSBadge(text: "Needs \(tier.minRAM)GB", color: DS.Colors.tertiaryText, size: .sm)
                        }
                    }
                    
                    Text("\(tier.minRAM)GB+ RAM")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                
                Spacer()
                
                // Warning indicator
                switch tier.warningLevel {
                case .critical:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(DS.Colors.error)
                case .warning:
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(DS.Colors.warning)
                case .caution:
                    Image(systemName: "info.circle")
                        .foregroundStyle(DS.Colors.secondaryText)
                case .none:
                    EmptyView()
                }
            }
            .padding(DS.Spacing.sm)
            .background(
                isSelected
                    ? DS.Colors.accent.opacity(0.15)
                    : DS.Colors.tertiaryBackground
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .strokeBorder(isSelected ? DS.Colors.accent : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.5)
    }
}

// MARK: - External Models Settings

struct ExternalModelsSettingsContent: View {
    @Environment(AppState.self) private var appState
    @State private var keyInputs: [ExternalModelConfigurationService.ProviderKind: String] = [:]
    @State private var revealKeys: Bool = false
    @State private var isUpdatingPricing: Bool = false
    
    var body: some View {
        @Bindable var externalConfig = appState.externalModelConfig
        let providers = ExternalModelConfigurationService.ProviderKind.allCases.filter { $0 != .local }
        let roles = ExternalModelConfigurationService.Role.allCases
        
        return VStack(spacing: DS.Spacing.lg) {
            SettingsSection("External Provider Keys") {
                SettingsToggle(label: "Reveal Keys", isOn: $revealKeys)
                DSDivider()
                
                ForEach(providers, id: \.self) { provider in
                    keyRow(provider: provider, externalConfig: externalConfig)
                    if provider != providers.last {
                        DSDivider()
                    }
                }
                
                Text("Keys are stored in macOS Keychain.")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
            
            SettingsSection("External Routing by Role") {
                ForEach(roles, id: \.self) { role in
                    RoleRoutingRow(
                        role: role,
                        config: Binding(
                            get: { externalConfig.config(for: role) },
                            set: { externalConfig.updateRole(role, config: $0) }
                        ),
                        providerOptions: ExternalModelConfigurationService.ProviderKind.allCases,
                        providerLabel: { externalConfig.providerDisplayName($0) }
                    )
                    
                    if role != roles.last {
                        DSDivider()
                    }
                }

                Text("Pricing auto-fills from ~/.config/ollamabot/pricing.json when costs are 0.")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }

            SettingsSection("Pricing Catalog") {
                HStack(spacing: DS.Spacing.sm) {
                    let updatedAt = appState.pricingService.catalog?.updatedAt ?? "Not loaded"
                    Text("Last updated: \(updatedAt)")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                    
                    Spacer()
                    
                    Button(isUpdatingPricing ? "Updating..." : "Update Pricing Now") {
                        guard !isUpdatingPricing else { return }
                        isUpdatingPricing = true
                        Task {
                            do {
                                try await appState.pricingService.updateCatalog()
                                appState.showSuccess("Pricing updated")
                            } catch {
                                appState.showError("Pricing update failed: \(error.localizedDescription)")
                            }
                            isUpdatingPricing = false
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DS.Colors.accent)
                }
                
                Text("Updates only run when you click this button. No background cron jobs.")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
            
            SettingsSection("OpenAI-Compatible Endpoint") {
                Text("Use for OpenRouter, Together, Groq, Mistral, Perplexity, Fireworks, etc.")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
                    .padding(.bottom, DS.Spacing.xs)
                
                SettingsRow("Display Name") {
                    TextField("OpenAI-Compatible", text: $externalConfig.openAICompatible.displayName)
                        .textFieldStyle(.plain)
                        .padding(4)
                        .background(DS.Colors.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                        .frame(width: 200)
                        .foregroundStyle(DS.Colors.text)
                }
                
                DSDivider()
                
                SettingsRow("Base URL") {
                    TextField("https://api.openai.com/v1", text: $externalConfig.openAICompatible.baseURL)
                        .textFieldStyle(.plain)
                        .padding(4)
                        .background(DS.Colors.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                        .frame(width: 260)
                        .foregroundStyle(DS.Colors.text)
                }
                
                DSDivider()
                
                SettingsRow("Auth Header") {
                    TextField("Authorization", text: $externalConfig.openAICompatible.authHeader)
                        .textFieldStyle(.plain)
                        .padding(4)
                        .background(DS.Colors.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                        .frame(width: 200)
                        .foregroundStyle(DS.Colors.text)
                }
                
                DSDivider()
                
                SettingsRow("Auth Prefix") {
                    TextField("Bearer", text: $externalConfig.openAICompatible.authPrefix)
                        .textFieldStyle(.plain)
                        .padding(4)
                        .background(DS.Colors.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                        .frame(width: 200)
                        .foregroundStyle(DS.Colors.text)
                }
            }
        }
    }
    
    private func keyRow(
        provider: ExternalModelConfigurationService.ProviderKind,
        externalConfig: ExternalModelConfigurationService
    ) -> some View {
        let keyStore = appState.apiKeyStore
        let binding = Binding<String>(
            get: { keyInputs[provider] ?? "" },
            set: { keyInputs[provider] = $0 }
        )
        let hasKey = keyStore.hasKey(for: provider.keychainId)
        
        return SettingsRow(externalConfig.providerDisplayName(provider)) {
            HStack(spacing: DS.Spacing.sm) {
                if revealKeys {
                    TextField("API Key", text: binding)
                        .textFieldStyle(.plain)
                        .padding(4)
                        .background(DS.Colors.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                        .frame(width: 220)
                        .foregroundStyle(DS.Colors.text)
                } else {
                    SecureField("API Key", text: binding)
                        .textFieldStyle(.plain)
                        .padding(4)
                        .background(DS.Colors.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                        .frame(width: 220)
                        .foregroundStyle(DS.Colors.text)
                }
                
                Text(hasKey ? "Stored" : "Missing")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(hasKey ? DS.Colors.success : DS.Colors.tertiaryText)
                
                Button("Save") {
                    _ = keyStore.setKey(binding.wrappedValue, for: provider.keychainId)
                    keyInputs[provider] = ""
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Colors.accent)
                
                Button("Clear") {
                    _ = keyStore.setKey(nil, for: provider.keychainId)
                    keyInputs[provider] = ""
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Colors.tertiaryText)
            }
        }
    }
}

private struct RoleRoutingRow: View {
    let role: ExternalModelConfigurationService.Role
    @Binding var config: ExternalModelConfigurationService.RoleConfig
    let providerOptions: [ExternalModelConfigurationService.ProviderKind]
    let providerLabel: (ExternalModelConfigurationService.ProviderKind) -> String
    
    var body: some View {
        let isLocal = config.provider == .local
        
        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(role.displayName)
                .font(DS.Typography.callout.weight(.semibold))
                .foregroundStyle(DS.Colors.text)
            
            HStack(spacing: DS.Spacing.sm) {
                DSDropdown(
                    selection: $config.provider,
                    options: providerOptions,
                    label: { Text(providerLabel($0)) },
                    row: { Text(providerLabel($0)) }
                )
                .frame(width: 180)
                
                TextField("Model ID", text: $config.modelId)
                    .textFieldStyle(.plain)
                    .padding(4)
                    .background(DS.Colors.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                    .frame(width: 180)
                    .foregroundStyle(DS.Colors.text)
                    .disabled(isLocal)
            }
            
            HStack(spacing: DS.Spacing.sm) {
                HStack(spacing: 4) {
                    Text("Input $/1K")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    TextField("", value: $config.inputCostPer1K, format: .number)
                        .textFieldStyle(.plain)
                        .padding(4)
                        .background(DS.Colors.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                        .frame(width: 80)
                        .foregroundStyle(DS.Colors.text)
                        .disabled(isLocal)
                }
                
                HStack(spacing: 4) {
                    Text("Output $/1K")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    TextField("", value: $config.outputCostPer1K, format: .number)
                        .textFieldStyle(.plain)
                        .padding(4)
                        .background(DS.Colors.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                        .frame(width: 80)
                        .foregroundStyle(DS.Colors.text)
                        .disabled(isLocal)
                }
            }
        }
        .opacity(isLocal ? 0.85 : 1)
        .padding(.vertical, 2)
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
                        .textFieldStyle(.plain)
                        .padding(4)
                        .background(DS.Colors.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                        .frame(width: 80)
                        .foregroundStyle(DS.Colors.text)
                }
                
                DSDivider()
                
                SettingsRow("Thinking Delay") {
                    HStack(spacing: DS.Spacing.sm) {
                        DSSlider(value: $config.thinkingDelay, range: 0...5)
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
        VStack(spacing: DS.Spacing.md) {
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
                        .textFieldStyle(.plain)
                        .padding(4)
                        .background(DS.Colors.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                        .frame(width: 60)
                        .foregroundStyle(DS.Colors.text)
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
                            DSSlider(value: $config.autoSaveDelay, range: 0.5...10)
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
                        .textFieldStyle(.plain)
                        .padding(4)
                        .background(DS.Colors.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                        .font(DS.Typography.mono(12))
                        .foregroundStyle(DS.Colors.text)
                    
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
                    DSDropdown(
                        selection: $config.terminalFontFamily,
                        options: FontOption.monospaceFonts.map { $0.family },
                        label: { family in
                            Text(FontOption.monospaceFonts.first(where: { $0.family == family })?.name ?? family)
                        },
                        row: { family in
                            Text(FontOption.monospaceFonts.first(where: { $0.family == family })?.name ?? family)
                        }
                    )
                    .frame(width: 180)
                }
                
                DSDivider()
                
                SettingsRow("Font Size") {
                    HStack(spacing: DS.Spacing.sm) {
                        TextField("", value: $config.terminalFontSize, format: .number)
                            .textFieldStyle(.plain)
                            .padding(4)
                            .background(DS.Colors.tertiaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                            .frame(width: 60)
                            .foregroundStyle(DS.Colors.text)
                        
                        DSDoubleStepper(value: $config.terminalFontSize, range: 8...24, step: 1)
                    }
                }
            }
            
            SettingsSection("Shell") {
                SettingsRow("Default Shell") {
                    let shells = ["/bin/zsh", "/bin/bash", "/bin/sh"]
                    DSDropdown(
                        selection: $config.terminalShell,
                        options: shells,
                        label: { shell in Text(shell) },
                        row: { shell in Text(shell) }
                    )
                    .frame(width: 150)
                }
                
                DSDivider()
                
                SettingsRow("Scrollback Lines") {
                    TextField("", value: $config.terminalScrollback, format: .number)
                        .textFieldStyle(.plain)
                        .padding(4)
                        .background(DS.Colors.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                        .frame(width: 100)
                        .foregroundStyle(DS.Colors.text)
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
                        let intervals = [60, 300, 900, 1800]
                        DSDropdown(
                            selection: Binding(
                                get: { config.gitAutoFetchInterval },
                                set: { config.gitAutoFetchInterval = $0 }
                            ),
                            options: intervals,
                            label: { interval in Text("\(interval/60) min") },
                            row: { interval in Text("\(interval/60) min") }
                        )
                        .frame(width: 100)
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
