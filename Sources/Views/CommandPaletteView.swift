import SwiftUI

// MARK: - Command

struct Command: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String
    let shortcut: String?
    let category: Category
    let action: () -> Void
    
    enum Category: String, CaseIterable {
        case file = "File"
        case edit = "Edit"
        case view = "View"
        case go = "Go"
        case ai = "AI"
        case git = "Git"
        case settings = "Settings"
    }
    
    init(_ id: String, _ title: String, icon: String, shortcut: String? = nil, subtitle: String? = nil, category: Category, action: @escaping () -> Void) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.shortcut = shortcut
        self.category = category
        self.action = action
    }
}

// MARK: - Command Palette

struct CommandPaletteView: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    @State private var search = ""
    @State private var selected = 0
    @FocusState private var focused: Bool
    
    private var commands: [Command] { buildCommands() }
    
    private var filtered: [Command] {
        if search.isEmpty { return commands }
        let q = search.lowercased()
        return commands.filter {
            $0.title.lowercased().contains(q) ||
            $0.category.rawValue.lowercased().contains(q) ||
            ($0.subtitle?.lowercased().contains(q) ?? false)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DS.Colors.secondaryText)
                
                TextField("Type a command...", text: $search)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.title)
                    .focused($focused)
                    .onSubmit { execute() }
                
                if !search.isEmpty {
                    DSIconButton(icon: "xmark.circle.fill") { search = "" }
                }
                
                Text("ESC")
                    .font(DS.Typography.caption)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(DS.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.secondaryBackground)
            
            DSDivider()
            
            // List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.xxs) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, cmd in
                            CommandRow(command: cmd, isSelected: index == selected)
                                .id(index)
                                .onTapGesture {
                                    selected = index
                                    execute()
                                }
                        }
                    }
                    .padding(DS.Spacing.sm)
                }
                .onChange(of: selected) { _, idx in
                    withAnimation(DS.Animation.fast) { proxy.scrollTo(idx, anchor: .center) }
                }
            }
            
            // Footer
            HStack {
                Text("\(filtered.count) commands")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                Spacer()
                HStack(spacing: DS.Spacing.md) {
                    Label("Navigate", systemImage: "arrow.up.arrow.down")
                    Label("Select", systemImage: "return")
                }
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.secondaryBackground)
        }
        .frame(width: 560, height: 380)
        .background(DS.Colors.background)
        .dsOverlay()
        .onAppear { focused = true; selected = 0 }
        .onChange(of: search) { _, _ in selected = 0 }
        .onKeyPress(.upArrow) { if selected > 0 { selected -= 1 }; return .handled }
        .onKeyPress(.downArrow) { if selected < filtered.count - 1 { selected += 1 }; return .handled }
        .onKeyPress(.escape) { isPresented = false; return .handled }
        .onKeyPress(.return) { execute(); return .handled }
    }
    
    private func execute() {
        guard selected < filtered.count else { return }
        isPresented = false
        filtered[selected].action()
    }
    
    private func buildCommands() -> [Command] {
        var cmds: [Command] = []
        
        // File
        cmds.append(Command("file.open", "Open Folder", icon: "folder", shortcut: "⌘O", category: .file) { appState.openFolderPanel() })
        cmds.append(Command("file.new", "New File", icon: "doc.badge.plus", shortcut: "⌘N", category: .file) { appState.createNewFile() })
        cmds.append(Command("file.save", "Save File", icon: "square.and.arrow.down", shortcut: "⌘S", category: .file) { appState.saveCurrentFile() })
        
        // View
        cmds.append(Command("view.terminal", "Toggle Terminal", icon: "terminal", shortcut: "⌃`", category: .view) { appState.showTerminal.toggle() })
        cmds.append(Command("view.sidebar", "Toggle Sidebar", icon: "sidebar.left", shortcut: "⌘B", category: .view) { appState.showSidebar.toggle() })
        cmds.append(Command("view.chat", "Toggle Chat", icon: "bubble.right", category: .view) { appState.showChatPanel.toggle() })
        
        // Go
        cmds.append(Command("go.file", "Go to File", icon: "doc.text.magnifyingglass", shortcut: "⌘P", subtitle: "Quick open", category: .go) { appState.showQuickOpen = true })
        cmds.append(Command("go.line", "Go to Line", icon: "arrow.right.to.line", shortcut: "⌃G", category: .go) { appState.showGoToLine = true })
        
        // Edit
        cmds.append(Command("edit.find", "Find in File", icon: "magnifyingglass", shortcut: "⌘F", category: .edit) { appState.showFindInFile = true })
        cmds.append(Command("edit.replace", "Find and Replace", icon: "arrow.left.arrow.right", shortcut: "⌘⌥F", category: .edit) { appState.showFindReplace = true })
        cmds.append(Command("edit.search", "Search in Files", icon: "doc.text.magnifyingglass", shortcut: "⌘⇧F", subtitle: "Global search", category: .edit) { appState.showGlobalSearch = true })
        
        // AI
        cmds.append(Command("ai.infinite", "Toggle Infinite Mode", icon: "infinity", shortcut: "⌘⇧I", subtitle: "Autonomous agent", category: .ai) { appState.showInfiniteMode.toggle() })
        cmds.append(Command("ai.chat", "Focus Chat", icon: "bubble.right", category: .ai) { appState.focusChat = true })
        
        for model in OllamaModel.allCases {
            cmds.append(Command("ai.model.\(model.rawValue)", "Use \(model.displayName)", icon: model.icon, subtitle: model.purpose, category: .ai) { appState.selectedModel = model })
        }
        
        cmds.append(Command("ai.auto", "Auto-Select Model", icon: "sparkles", subtitle: "Smart routing", category: .ai) { appState.selectedModel = nil })
        
        // Settings
        cmds.append(Command("settings.open", "Open Settings", icon: "gear", shortcut: "⌘,", category: .settings) { appState.showSettings = true })
        cmds.append(Command("settings.theme", "Toggle Theme", icon: "moon", subtitle: "Light/Dark", category: .settings) { appState.toggleTheme() })
        cmds.append(Command("settings.font.up", "Increase Font", icon: "textformat.size.larger", shortcut: "⌘+", category: .settings) { appState.editorFontSize += 1 })
        cmds.append(Command("settings.font.down", "Decrease Font", icon: "textformat.size.smaller", shortcut: "⌘-", category: .settings) { appState.editorFontSize -= 1 })
        
        // Git
        cmds.append(Command("git.status", "Git Status", icon: "arrow.triangle.branch", category: .git) { appState.showGitStatus = true })
        
        return cmds
    }
}

struct CommandRow: View {
    let command: Command
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: command.icon)
                .frame(width: 20)
                .foregroundStyle(isSelected ? .white : DS.Colors.secondaryText)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(command.title)
                    .fontWeight(.medium)
                if let sub = command.subtitle {
                    Text(sub)
                        .font(DS.Typography.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : DS.Colors.secondaryText)
                }
            }
            
            Spacer()
            
            DSBadge(text: command.category.rawValue, color: isSelected ? .white : DS.Colors.secondaryText)
            
            if let shortcut = command.shortcut {
                Text(shortcut)
                    .font(DS.Typography.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : DS.Colors.tertiaryText)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(isSelected ? DS.Colors.accent : Color.clear)
        .foregroundStyle(isSelected ? .white : DS.Colors.text)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

// MARK: - Quick Open

struct QuickOpenView: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    @State private var search = ""
    @State private var selected = 0
    @State private var files: [FileItem] = []
    @FocusState private var focused: Bool
    
    private var filtered: [FileItem] {
        if search.isEmpty { return Array(files.prefix(50)) }
        let q = search.lowercased()
        return files.filter { $0.name.lowercased().contains(q) || $0.url.path.lowercased().contains(q) }.prefix(50).map { $0 }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(DS.Colors.secondaryText)
                
                TextField("Search files...", text: $search)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.title)
                    .focused($focused)
                    .onSubmit { open() }
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.secondaryBackground)
            
            DSDivider()
            
            if filtered.isEmpty {
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(DS.Colors.secondaryText)
                    Text("No files found")
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: DS.Spacing.xxs) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, file in
                                FileRow(file: file, isSelected: index == selected)
                                    .id(index)
                                    .onTapGesture { selected = index; open() }
                            }
                        }
                        .padding(DS.Spacing.sm)
                    }
                    .onChange(of: selected) { _, idx in
                        withAnimation(DS.Animation.fast) { proxy.scrollTo(idx, anchor: .center) }
                    }
                }
            }
        }
        .frame(width: 560, height: 380)
        .background(DS.Colors.background)
        .dsOverlay()
        .onAppear { focused = true; loadFiles() }
        .onChange(of: search) { _, _ in selected = 0 }
        .onKeyPress(.upArrow) { if selected > 0 { selected -= 1 }; return .handled }
        .onKeyPress(.downArrow) { if selected < filtered.count - 1 { selected += 1 }; return .handled }
        .onKeyPress(.escape) { isPresented = false; return .handled }
        .onKeyPress(.return) { open(); return .handled }
    }
    
    private func loadFiles() {
        guard let root = appState.rootFolder else { return }
        files = appState.fileSystemService.getAllFiles(in: root)
    }
    
    private func open() {
        guard selected < filtered.count else { return }
        isPresented = false
        appState.openFile(filtered[selected])
    }
}

struct FileRow: View {
    let file: FileItem
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: file.icon)
                .frame(width: 20)
                .foregroundStyle(isSelected ? .white : file.iconColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .fontWeight(.medium)
                Text(file.url.deletingLastPathComponent().path)
                    .font(DS.Typography.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : DS.Colors.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(isSelected ? DS.Colors.accent : Color.clear)
        .foregroundStyle(isSelected ? .white : DS.Colors.text)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

// MARK: - Global Search

struct GlobalSearchView: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    @State private var search = ""
    @State private var results: [(FileItem, [String])] = []
    @State private var isSearching = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DS.Colors.secondaryText)
                
                TextField("Search in files...", text: $search)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.title)
                    .onSubmit { performSearch() }
                
                if isSearching { DSLoadingSpinner(size: 16) }
                
                DSButton("Search", style: .primary) { performSearch() }
                    .disabled(search.isEmpty)
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.secondaryBackground)
            
            DSDivider()
            
            if results.isEmpty && !isSearching {
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(DS.Colors.secondaryText)
                    Text(search.isEmpty ? "Enter search term" : "No results")
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DS.Spacing.md) {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                            SearchResultCard(file: result.0, matches: result.1) { line in
                                isPresented = false
                                appState.openFile(result.0)
                            }
                        }
                    }
                    .padding(DS.Spacing.md)
                }
            }
            
            HStack {
                Text("\(results.flatMap { $0.1 }.count) results in \(results.count) files")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                Spacer()
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.secondaryBackground)
        }
        .frame(width: 640, height: 480)
        .background(DS.Colors.background)
        .dsOverlay()
        .onKeyPress(.escape) { isPresented = false; return .handled }
    }
    
    private func performSearch() {
        guard !search.isEmpty, let root = appState.rootFolder else { return }
        isSearching = true
        results = []
        
        Task {
            let searchResults = appState.fileSystemService.searchContent(in: root, matching: search, maxResults: 100)
            await MainActor.run {
                results = searchResults
                isSearching = false
            }
        }
    }
}

struct SearchResultCard: View {
    let file: FileItem
    let matches: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Image(systemName: file.icon)
                    .foregroundStyle(file.iconColor)
                Text(file.name)
                    .fontWeight(.semibold)
                Text(file.url.deletingLastPathComponent().path)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                Spacer()
                Text("\(matches.count)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            
            ForEach(matches.prefix(3), id: \.self) { match in
                Text(match)
                    .font(DS.Typography.mono(11))
                    .lineLimit(1)
                    .padding(.vertical, DS.Spacing.xxs)
                    .padding(.horizontal, DS.Spacing.sm)
                    .background(DS.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .onTapGesture { onSelect(match) }
            }
        }
        .dsCard()
    }
}
