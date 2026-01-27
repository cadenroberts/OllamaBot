import SwiftUI

// MARK: - OBot Panel View
// Main interface for bots, context snippets, and templates

struct OBotPanelView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: OBotTab = .bots
    @State private var showingBotEditor = false
    @State private var editingBot: OBot?
    @State private var searchText = ""
    
    enum OBotTab: String, CaseIterable {
        case bots = "Bots"
        case context = "Context"
        case templates = "Templates"
        case rules = "Rules"
        
        var icon: String {
            switch self {
            case .bots: return "cpu"
            case .context: return "doc.text"
            case .templates: return "doc.badge.gearshape"
            case .rules: return "list.bullet.clipboard"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            DSDivider()
            
            // Tab bar
            tabBar
            
            DSDivider()
            
            // Content
            content
        }
        .background(DS.Colors.secondaryBackground)
        .sheet(isPresented: $showingBotEditor) {
            BotEditorView(bot: editingBot) { savedBot in
                Task {
                    try? await appState.obotService.createBot(savedBot)
                }
            }
            .frame(minWidth: 600, minHeight: 500)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("OBot")
                    .font(DS.Typography.headline)
                
                Text("Rules, Bots & Templates")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            
            Spacer()
            
            // Quick actions
            HStack(spacing: DS.Spacing.sm) {
                DSIconButton(icon: "plus", size: 14) {
                    editingBot = nil
                    showingBotEditor = true
                }
                .help("Create new bot")
                
                DSIconButton(icon: "folder.badge.plus", size: 14) {
                    Task {
                        if let root = appState.rootFolder {
                            try? await appState.obotService.scaffoldOBotDirectory(at: root)
                            appState.showSuccess("OBot scaffolding created!")
                        }
                    }
                }
                .help("Initialize .obot directory")
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(OBotTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(DS.Animation.fast) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: tab.icon)
                            .font(.caption)
                        Text(tab.rawValue)
                            .font(DS.Typography.caption)
                    }
                    .foregroundStyle(selectedTab == tab ? DS.Colors.accent : DS.Colors.secondaryText)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(selectedTab == tab ? DS.Colors.accent.opacity(0.1) : Color.clear)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .background(DS.Colors.surface)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .bots:
            botsContent
        case .context:
            contextContent
        case .templates:
            templatesContent
        case .rules:
            rulesContent
        }
    }
    
    // MARK: - Bots Content
    
    private var botsContent: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DS.Colors.tertiaryText)
                TextField("Search bots...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(DS.Spacing.sm)
            .background(DS.Colors.surface)
            
            DSDivider()
            
            if appState.obotService.bots.isEmpty {
                emptyBotsState
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.sm) {
                        ForEach(filteredBots) { bot in
                            BotCard(bot: bot) {
                                // Run bot
                                Task {
                                    let context = BotExecutionContext(
                                        selectedFile: appState.selectedFile,
                                        selectedText: appState.selectedText
                                    )
                                    _ = try? await appState.obotService.executeBot(
                                        bot,
                                        input: appState.selectedText.isEmpty ? appState.editorContent : appState.selectedText,
                                        context: context
                                    )
                                }
                            } onEdit: {
                                editingBot = bot
                                showingBotEditor = true
                            }
                        }
                    }
                    .padding(DS.Spacing.sm)
                }
            }
        }
    }
    
    private var filteredBots: [OBot] {
        if searchText.isEmpty {
            return appState.obotService.bots
        }
        return appState.obotService.bots.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var emptyBotsState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            
            Image(systemName: "cpu")
                .font(.system(size: 48))
                .foregroundStyle(DS.Colors.tertiaryText)
            
            Text("No Bots Yet")
                .font(DS.Typography.headline)
            
            Text("Create custom bots to automate tasks\nand enhance your workflow")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
                .multilineTextAlignment(.center)
            
            Button {
                editingBot = nil
                showingBotEditor = true
            } label: {
                Label("Create Bot", systemImage: "plus")
                    .font(DS.Typography.caption)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Context Content
    
    private var contextContent: some View {
        VStack(spacing: 0) {
            if appState.obotService.contextSnippets.isEmpty {
                emptyContextState
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.sm) {
                        ForEach(appState.obotService.contextSnippets) { snippet in
                            ContextSnippetCard(snippet: snippet)
                        }
                    }
                    .padding(DS.Spacing.sm)
                }
            }
        }
    }
    
    private var emptyContextState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(DS.Colors.tertiaryText)
            
            Text("No Context Snippets")
                .font(DS.Typography.headline)
            
            Text("Add .md files to .obot/context/\nto create reusable @mentionable context")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Templates Content
    
    private var templatesContent: some View {
        VStack(spacing: 0) {
            if appState.obotService.templates.isEmpty {
                emptyTemplatesState
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.sm) {
                        ForEach(appState.obotService.templates) { template in
                            TemplateCard(template: template)
                        }
                    }
                    .padding(DS.Spacing.sm)
                }
            }
        }
    }
    
    private var emptyTemplatesState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            
            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 48))
                .foregroundStyle(DS.Colors.tertiaryText)
            
            Text("No Templates")
                .font(DS.Typography.headline)
            
            Text("Add .tmpl files to .obot/templates/\nto create code generation templates")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Rules Content
    
    private var rulesContent: some View {
        VStack(spacing: 0) {
            if let rules = appState.obotService.projectRules {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        // Header
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DS.Colors.success)
                            Text(".obotrules loaded")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.success)
                            
                            Spacer()
                            
                            DSIconButton(icon: "pencil", size: 12) {
                                // Open rules file in editor
                                let file = FileItem(url: rules.source, isDirectory: false)
                                appState.openFile(file)
                            }
                        }
                        .padding(DS.Spacing.sm)
                        .background(DS.Colors.success.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                        
                        // Sections
                        ForEach(rules.sections, id: \.title) { section in
                            RulesSectionView(section: section)
                        }
                    }
                    .padding(DS.Spacing.md)
                }
            } else {
                emptyRulesState
            }
        }
    }
    
    private var emptyRulesState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(DS.Colors.tertiaryText)
            
            Text("No Project Rules")
                .font(DS.Typography.headline)
            
            Text("Create a .obotrules file in your project root\nto define AI behavior rules")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
                .multilineTextAlignment(.center)
            
            Button {
                Task {
                    if let root = appState.rootFolder {
                        try? await appState.obotService.scaffoldOBotDirectory(at: root)
                        appState.showSuccess("Project rules created!")
                    }
                }
            } label: {
                Label("Create .obotrules", systemImage: "plus")
                    .font(DS.Typography.caption)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Bot Card

struct BotCard: View {
    let bot: OBot
    let onRun: () -> Void
    let onEdit: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(DS.Colors.accent.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: bot.icon ?? "cpu")
                    .font(.system(size: 18))
                    .foregroundStyle(DS.Colors.accent)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(bot.name)
                    .font(DS.Typography.callout.weight(.medium))
                
                Text(bot.description)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .lineLimit(2)
                
                // Steps count
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.caption2)
                    Text("\(bot.steps.count) steps")
                        .font(DS.Typography.caption2)
                }
                .foregroundStyle(DS.Colors.tertiaryText)
            }
            
            Spacer()
            
            // Actions
            if isHovered {
                HStack(spacing: DS.Spacing.xs) {
                    DSIconButton(icon: "play.fill", size: 14) {
                        onRun()
                    }
                    .help("Run bot")
                    
                    DSIconButton(icon: "pencil", size: 14) {
                        onEdit()
                    }
                    .help("Edit bot")
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(isHovered ? DS.Colors.surface : DS.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.border, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Context Snippet Card

struct ContextSnippetCard: View {
    let snippet: ContextSnippet
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(DS.Colors.accent)
                
                Text(snippet.name)
                    .font(DS.Typography.callout.weight(.medium))
                
                Spacer()
                
                Text("@\(snippet.id)")
                    .font(DS.Typography.mono(11))
                    .foregroundStyle(DS.Colors.tertiaryText)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(DS.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                
                DSIconButton(icon: isExpanded ? "chevron.up" : "chevron.down", size: 12) {
                    withAnimation(DS.Animation.fast) {
                        isExpanded.toggle()
                    }
                }
            }
            
            if isExpanded {
                Text(snippet.content)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: CodeTemplate
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "doc.badge.gearshape")
                    .foregroundStyle(DS.Colors.orchestrator)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(DS.Typography.callout.weight(.medium))
                    
                    if !template.description.isEmpty {
                        Text(template.description)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                }
                
                Spacer()
                
                if !template.variables.isEmpty {
                    Text("\(template.variables.count) vars")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                }
                
                DSIconButton(icon: isExpanded ? "chevron.up" : "chevron.down", size: 12) {
                    withAnimation(DS.Animation.fast) {
                        isExpanded.toggle()
                    }
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    // Variables
                    if !template.variables.isEmpty {
                        Text("Variables:")
                            .font(DS.Typography.caption.weight(.semibold))
                            .foregroundStyle(DS.Colors.secondaryText)
                        
                        ForEach(template.variables, id: \.name) { variable in
                            HStack {
                                Text(variable.name)
                                    .font(DS.Typography.mono(11))
                                    .foregroundStyle(DS.Colors.accent)
                                
                                if let desc = variable.description {
                                    Text("- \(desc)")
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(DS.Colors.tertiaryText)
                                }
                            }
                        }
                    }
                    
                    // Preview
                    Text("Preview:")
                        .font(DS.Typography.caption.weight(.semibold))
                        .foregroundStyle(DS.Colors.secondaryText)
                        .padding(.top, DS.Spacing.xs)
                    
                    Text(template.content.prefix(200) + (template.content.count > 200 ? "..." : ""))
                        .font(DS.Typography.mono(10))
                        .foregroundStyle(DS.Colors.secondaryText)
                        .padding(DS.Spacing.sm)
                        .background(DS.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Rules Section View

struct RulesSectionView: View {
    let section: ProjectRules.RulesSection
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Button {
                withAnimation(DS.Animation.fast) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                    
                    Text(section.title)
                        .font(DS.Typography.callout.weight(.semibold))
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Text(section.content)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .padding(.leading, DS.Spacing.lg)
            }
        }
        .padding(DS.Spacing.sm)
        .background(DS.Colors.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}

// MARK: - Bot Editor View

struct BotEditorView: View {
    let bot: OBot?
    let onSave: (OBot) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var id: String = ""
    @State private var description: String = ""
    @State private var icon: String = "cpu"
    @State private var inputType: OBot.InputConfig.InputType = .selection
    @State private var steps: [OBot.Step] = []
    @State private var outputType: OBot.OutputConfig.OutputType = .replace
    
    init(bot: OBot?, onSave: @escaping (OBot) -> Void) {
        self.bot = bot
        self.onSave = onSave
        
        if let bot = bot {
            _name = State(initialValue: bot.name)
            _id = State(initialValue: bot.id)
            _description = State(initialValue: bot.description)
            _icon = State(initialValue: bot.icon ?? "cpu")
            _inputType = State(initialValue: bot.input.type)
            _steps = State(initialValue: bot.steps)
            _outputType = State(initialValue: bot.output.type)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(bot == nil ? "New Bot" : "Edit Bot")
                    .font(DS.Typography.headline)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    saveBot()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || id.isEmpty)
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surface)
            
            DSDivider()
            
            // Form
            Form {
                Section("Basic Info") {
                    TextField("Name", text: $name)
                    TextField("ID (for @mentions)", text: $id)
                        .onChange(of: name) { _, newValue in
                            if id.isEmpty || bot == nil {
                                id = newValue.lowercased().replacingOccurrences(of: " ", with: "-")
                            }
                        }
                    TextField("Description", text: $description)
                    TextField("Icon (SF Symbol)", text: $icon)
                }
                
                Section("Input") {
                    Picker("Input Type", selection: $inputType) {
                        Text("Selection").tag(OBot.InputConfig.InputType.selection)
                        Text("Text").tag(OBot.InputConfig.InputType.text)
                        Text("File").tag(OBot.InputConfig.InputType.file)
                        Text("Files").tag(OBot.InputConfig.InputType.files)
                    }
                }
                
                Section("Steps") {
                    if steps.isEmpty {
                        Text("No steps yet. Add steps to define the bot's workflow.")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                    } else {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            StepRow(step: step, index: index) {
                                steps.remove(at: index)
                            }
                        }
                    }
                    
                    Button {
                        steps.append(OBot.Step(
                            id: UUID().uuidString,
                            type: .prompt,
                            name: "Step \(steps.count + 1)",
                            content: ""
                        ))
                    } label: {
                        Label("Add Step", systemImage: "plus")
                    }
                }
                
                Section("Output") {
                    Picker("Output Type", selection: $outputType) {
                        Text("Replace Selection").tag(OBot.OutputConfig.OutputType.replace)
                        Text("Insert at Cursor").tag(OBot.OutputConfig.OutputType.insert)
                        Text("New File").tag(OBot.OutputConfig.OutputType.newFile)
                        Text("Panel").tag(OBot.OutputConfig.OutputType.panel)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .background(DS.Colors.background)
    }
    
    private func saveBot() {
        let newBot = OBot(
            id: id,
            name: name,
            description: description,
            icon: icon,
            input: OBot.InputConfig(type: inputType, required: true),
            steps: steps,
            output: OBot.OutputConfig(type: outputType),
            source: bot?.source
        )
        
        onSave(newBot)
        dismiss()
    }
}

// MARK: - Step Row

struct StepRow: View {
    let step: OBot.Step
    let index: Int
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Text("\(index + 1)")
                .font(DS.Typography.mono(12))
                .foregroundStyle(DS.Colors.tertiaryText)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(step.name)
                    .font(DS.Typography.callout)
                
                Text(step.type.rawValue.capitalized)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            
            Spacer()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
        }
    }
}
