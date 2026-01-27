import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    @State private var sidebarWidth: CGFloat = 260
    @State private var chatWidth: CGFloat = 380
    @State private var terminalHeight: CGFloat = 200
    
    var body: some View {
        @Bindable var state = appState
        
        ZStack {
            // Base background
            DS.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
            HSplitView {
                // Sidebar
                if appState.showSidebar {
                    SidebarView()
                        .frame(minWidth: 200, idealWidth: sidebarWidth, maxWidth: 400)
                }
                
                // Main Editor Area
                VSplitView {
                    // Editor or Infinite Mode
                    VStack(spacing: 0) {
                        // Tab bar
                        TabBarView()
                        
                        // Breadcrumbs
                        if appState.config.showBreadcrumbs {
                            BreadcrumbsView()
                        }
                        
                        // Find bar
                        if appState.showFindInFile || appState.showFindReplace {
                            FindBarView(isPresented: $state.showFindInFile)
                        }
                        
                        // Main content
                        if appState.showInfiniteMode {
                            AgentView()
                        } else {
                            EditorView()
                        }
                    }
                    .frame(minWidth: 400)
                    
                    // Terminal
                    if appState.showTerminal {
                        TerminalView()
                            .frame(minHeight: 100, idealHeight: terminalHeight, maxHeight: 400)
                    }
                }
                
                // Chat Panel
                if appState.showChatPanel {
                    ChatView()
                        .frame(minWidth: 320, idealWidth: chatWidth, maxWidth: 600)
                }
            }
            
            // Status Bar
            if appState.config.showStatusBar {
                StatusBarView()
            }
            } // VStack
            .toolbar(content: {
                MainToolbarContent(appState: state)
            })
            .navigationTitle(appState.rootFolder?.lastPathComponent ?? "OllamaBot")
            .onAppear {
                sidebarWidth = appState.config.sidebarWidth
            }
            
            // Overlay Dialogs
            if appState.showCommandPalette {
                DialogOverlay {
                    CommandPaletteView(isPresented: $state.showCommandPalette)
                }
            }
            
            if appState.showQuickOpen {
                DialogOverlay {
                    QuickOpenView(isPresented: $state.showQuickOpen)
                }
            }
            
            if appState.showGlobalSearch {
                DialogOverlay {
                    GlobalSearchView(isPresented: $state.showGlobalSearch)
                }
            }
            
            if appState.showGoToLine {
                DialogOverlay {
                    GoToLineView(isPresented: $state.showGoToLine)
                }
            }
            
            if appState.showGitStatus {
                DialogOverlay {
                    GitStatusView(isPresented: $state.showGitStatus)
                }
            }
            
            if appState.showGoToLine {
                DialogOverlay {
                    GoToLineView(isPresented: $state.showGoToLine)
                }
            }
            
            // Toast notifications (production UX)
            VStack {
                DSToastContainer(toasts: $state.toasts)
                Spacer()
            }
        }
        .preferredColorScheme(colorScheme)
    }
    
    private var colorScheme: ColorScheme? {
        switch appState.config.theme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

// MARK: - Toolbar Content

struct MainToolbarContent: ToolbarContent {
    @Bindable var appState: AppState
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: { appState.showSidebar.toggle() }) {
                Image(systemName: "sidebar.left")
            }
            .help("Toggle Sidebar (⌘B)")
        }
        
        // Connection status indicator
        ToolbarItem(placement: .navigation) {
            DSConnectionStatus(
                isConnected: appState.ollamaService.isConnected,
                modelCount: appState.ollamaService.availableModels.count
            )
        }
        
        ToolbarItem(placement: .primaryAction) {
            Button(action: { appState.showCommandPalette = true }) {
                Image(systemName: "magnifyingglass")
            }
            .help("Command Palette (⌘⇧P)")
        }
        
        ToolbarItem(placement: .primaryAction) {
            Toggle(isOn: $appState.showInfiniteMode) {
                Label("Infinite Mode", systemImage: "infinity")
            }
            .toggleStyle(.button)
            .help("Toggle Infinite Mode (⌘⇧I)")
        }
        
        ToolbarItem(placement: .primaryAction) {
            Button(action: { appState.showTerminal.toggle() }) {
                Image(systemName: "terminal")
            }
            .help("Toggle Terminal (⌃`)")
        }
        
        ToolbarItem(placement: .primaryAction) {
            Button(action: { appState.showChatPanel.toggle() }) {
                Image(systemName: "bubble.right")
            }
            .help("Toggle Chat Panel")
        }
    }
}

// MARK: - Dialog Overlay

struct DialogOverlay<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            content
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: SidebarTab = .files
    
    enum SidebarTab: String, CaseIterable {
        case files = "Files"
        case search = "Search"
        case git = "Git"
        
        var icon: String {
            switch self {
            case .files: return "doc.fill"
            case .search: return "magnifyingglass"
            case .git: return "arrow.triangle.branch"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Activity bar
            HStack(spacing: 0) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(DS.Colors.secondaryBackground)
            
            Divider()
            
            // Content
            switch selectedTab {
            case .files:
                FileTreeView()
            case .search:
                SearchSidebarView()
            case .git:
                GitSidebarView()
            }
        }
    }
}

// MARK: - File Tree View

struct FileTreeView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("EXPLORER")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(action: { appState.openFolderPanel() }) {
                    Image(systemName: "folder.badge.plus")
                }
                .buttonStyle(.plain)
                .help("Open Folder")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // File tree
            if let root = appState.rootFolder {
                ScrollView {
                    FileTreeNode(url: root, level: 0)
                        .padding(.vertical, 4)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No folder open")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button("Open Folder") {
                        appState.openFolderPanel()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
    }
}

struct FileTreeNode: View {
    @Environment(AppState.self) private var appState
    let url: URL
    let level: Int
    
    @State private var isExpanded: Bool = false
    @State private var children: [URL] = []
    
    private var isDirectory: Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }
    
    private var isSelected: Bool {
        appState.selectedFile?.url == url
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Node row
            HStack(spacing: 6) {
                if isDirectory {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                        .onTapGesture {
                            toggle()
                        }
                } else {
                    Spacer()
                        .frame(width: 12)
                }
                
                Image(systemName: iconFor(url))
                    .font(.caption)
                    .foregroundStyle(colorFor(url))
                
                Text(url.lastPathComponent)
                    .font(.callout)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.leading, CGFloat(level) * 16 + 8)
            .padding(.vertical, 4)
            .padding(.trailing, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                if isDirectory {
                    toggle()
                } else {
                    let file = FileItem(url: url, isDirectory: false)
                    appState.openFile(file)
                }
            }
            .contextMenu {
                fileContextMenu
            }
            
            // Children
            if isExpanded {
                ForEach(children, id: \.self) { childURL in
                    FileTreeNode(url: childURL, level: level + 1)
                }
            }
        }
        .onAppear {
            if level == 0 && isDirectory {
                isExpanded = true
                loadChildren()
            }
        }
    }
    
    @ViewBuilder
    private var fileContextMenu: some View {
        if !isDirectory {
            Button("Open") {
                let file = FileItem(url: url, isDirectory: false)
                appState.openFile(file)
            }
            
            Divider()
        }
        
        Button("Rename...") {
            // TODO: Implement rename
        }
        
        Button("Duplicate") {
            _ = appState.fileSystemService.duplicate(at: url)
        }
        
        Divider()
        
        Button("Delete", role: .destructive) {
            _ = appState.fileSystemService.delete(at: url)
        }
        
        Divider()
        
        Button("Reveal in Finder") {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        }
        
        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.path, forType: .string)
        }
    }
    
    private func toggle() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isExpanded.toggle()
        }
        if isExpanded && children.isEmpty {
            loadChildren()
        }
    }
    
    private func loadChildren() {
        guard isDirectory else { return }
        
        let excludePatterns = Set(["node_modules", ".git", "__pycache__", ".build", ".DS_Store", ".swiftpm", "DerivedData"])
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
            children = contents.filter { !excludePatterns.contains($0.lastPathComponent) }
                .sorted { url1, url2 in
                    let isDir1 = (try? url1.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    let isDir2 = (try? url2.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    if isDir1 == isDir2 {
                        return url1.lastPathComponent.localizedCaseInsensitiveCompare(url2.lastPathComponent) == .orderedAscending
                    }
                    return isDir1 && !isDir2
                }
        } catch {
            children = []
        }
    }
    
    private func iconFor(_ url: URL) -> String {
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        if isDir { return "folder.fill" }
        
        switch url.pathExtension.lowercased() {
        case "swift": return "swift"
        case "py": return "curlybraces.square.fill"
        case "js": return "text.page.badge.magnifyingglass"
        case "ts", "tsx": return "t.circle.fill"
        case "json": return "curlybraces"
        case "md": return "doc.text.fill"
        default: return "doc.fill"
        }
    }
    
    private func colorFor(_ url: URL) -> Color {
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        if isDir { return .blue }
        
        switch url.pathExtension.lowercased() {
        case "swift": return .orange
        case "py": return .green
        case "js": return .yellow
        case "ts", "tsx": return .blue
        case "json": return .purple
        case "md": return .cyan
        default: return .secondary
        }
    }
}

// MARK: - Tab Bar View

struct TabBarView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(appState.openFiles) { file in
                    TabItemView(file: file)
                }
                
                Spacer()
            }
        }
        .frame(height: 35)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct TabItemView: View {
    @Environment(AppState.self) private var appState
    let file: FileItem
    
    @State private var isHovered: Bool = false
    
    private var isSelected: Bool {
        appState.selectedFile?.url == file.url
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: file.icon)
                .font(.caption)
                .foregroundStyle(file.iconColor)
            
            Text(file.name)
                .font(.callout)
            
            if file.isModified {
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 6, height: 6)
            }
            
            if isHovered || isSelected {
                Button(action: { appState.closeFile(file) }) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color(nsColor: .windowBackgroundColor) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.openFile(file)
        }
        .onHover { isHovered = $0 }
    }
}

// MARK: - Breadcrumbs View

struct BreadcrumbsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                if let file = appState.selectedFile, let root = appState.rootFolder {
                    let components = file.url.pathComponents.drop { component in
                        !root.pathComponents.contains(component) || component == root.lastPathComponent
                    }
                    
                    ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Text(component)
                            .font(.caption)
                            .foregroundStyle(index == components.count - 1 ? .primary : .secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

// MARK: - Search Sidebar View

struct SearchSidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SEARCH")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            TextField("Search files...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding()
            
            Spacer()
            
            if searchText.isEmpty {
                VStack {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Search in files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Git Sidebar View (Uses GitService)

struct GitSidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var commitMessage = ""
    
    private var git: GitService { appState.gitService }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            DSSectionHeader(title: "SOURCE CONTROL") {
                if git.isLoading {
                    DSLoadingSpinner(size: 12)
                } else {
                    DSIconButton(icon: "arrow.clockwise", size: 14) {
                        git.refresh()
                    }
                }
            }
            
            DSDivider()
            
            if !git.isGitRepo {
                // Not a git repo
                DSEmptyState(
                    icon: "arrow.triangle.branch",
                    title: "Not a Git Repository",
                    message: "Open a folder with git initialized"
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        // Branch info
                        branchSection
                        
                        // Changes
                        if let status = git.status {
                            changesSection(status)
                        }
                        
                        // Commit input
                        commitSection
                    }
                    .padding(DS.Spacing.sm)
                }
            }
        }
        .onAppear {
            git.setWorkingDirectory(appState.rootFolder)
        }
        .onChange(of: appState.rootFolder) { _, newValue in
            git.setWorkingDirectory(newValue)
        }
    }
    
    private var branchSection: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(DS.Colors.accent)
            Text(git.currentBranch.isEmpty ? "HEAD" : git.currentBranch)
                .font(DS.Typography.callout.weight(.medium))
            Spacer()
        }
        .padding(DS.Spacing.sm)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
    
    @ViewBuilder
    private func changesSection(_ status: GitStatus) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // Staged changes
            if !status.staged.isEmpty {
                changeGroup(title: "Staged Changes", changes: status.staged, staged: true)
            }
            
            // Unstaged changes
            if !status.unstaged.isEmpty {
                changeGroup(title: "Changes", changes: status.unstaged, staged: false)
            }
            
            // Untracked
            if !status.untracked.isEmpty {
                untrackedGroup(title: "Untracked", files: status.untracked)
            }
        }
    }
    
    private func changeGroup(title: String, changes: [GitFileChange], staged: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Text(title)
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(DS.Colors.secondaryText)
                Spacer()
                Text("\(changes.count)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
            
            ForEach(changes) { change in
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: change.status.icon)
                        .font(.caption2)
                        .foregroundStyle(change.status.color)
                    
                    Text(change.filename.split(separator: "/").last.map(String.init) ?? change.filename)
                        .font(DS.Typography.caption)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Stage/unstage button
                    DSIconButton(icon: staged ? "minus" : "plus", size: 12) {
                        if staged {
                            git.unstage(file: change.filename)
                        } else {
                            git.stage(file: change.filename)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    private func untrackedGroup(title: String, files: [String]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Text(title)
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(DS.Colors.secondaryText)
                Spacer()
                Text("\(files.count)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
            
            ForEach(files, id: \.self) { file in
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "questionmark.circle")
                        .font(.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    
                    Text(file.split(separator: "/").last.map(String.init) ?? file)
                        .font(DS.Typography.caption)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    DSIconButton(icon: "plus", size: 12) {
                        git.stage(file: file)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    private var commitSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            TextField("Commit message...", text: $commitMessage, axis: .vertical)
                .font(DS.Typography.caption)
                .textFieldStyle(.plain)
                .padding(DS.Spacing.sm)
                .background(DS.Colors.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .lineLimit(3...5)
            
            HStack {
                DSButton("Stage All", style: .secondary, size: .sm) {
                    git.stageAll()
                }
                
                DSButton("Commit", style: .primary, size: .sm) {
                    guard !commitMessage.isEmpty else { return }
                    _ = git.commit(message: commitMessage)
                    commitMessage = ""
                }
                .disabled(commitMessage.isEmpty || git.status?.staged.isEmpty == true)
            }
        }
    }
}

// MARK: - Git Status View (Dialog)

struct GitStatusView: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    @State private var diffContent = ""
    
    private var git: GitService { appState.gitService }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(DS.Colors.accent)
                    Text(git.currentBranch)
                        .font(DS.Typography.headline)
                }
                
                Spacer()
                
                DSIconButton(icon: "xmark", size: 16) {
                    isPresented = false
                }
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surface)
            
            DSDivider()
            
            // Content
            HStack(spacing: 0) {
                // File list
                VStack(alignment: .leading, spacing: 0) {
                    if let status = git.status {
                        List {
                            Section("Staged (\(status.staged.count))") {
                                ForEach(status.staged) { change in
                                    fileRow(change.filename, status: change.status, staged: true)
                                }
                            }
                            
                            Section("Modified (\(status.unstaged.count))") {
                                ForEach(status.unstaged) { change in
                                    fileRow(change.filename, status: change.status, staged: false)
                                }
                            }
                            
                            Section("Untracked (\(status.untracked.count))") {
                                ForEach(status.untracked, id: \.self) { file in
                                    fileRow(file, status: .untracked, staged: false)
                                }
                            }
                        }
                        .listStyle(.sidebar)
                    }
                }
                .frame(width: 200)
                
                DSDivider()
                
                // Diff view
                ScrollView {
                    Text(diffContent.isEmpty ? "Select a file to view diff" : diffContent)
                        .font(DS.Typography.mono(11))
                        .foregroundStyle(diffContent.isEmpty ? DS.Colors.tertiaryText : DS.Colors.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Spacing.md)
                }
                .background(DS.Colors.codeBackground)
            }
        }
        .frame(width: 700, height: 500)
        .background(DS.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .shadow(color: DS.Shadow.lg, radius: 20)
    }
    
    private func fileRow(_ file: String, status: GitChangeStatus, staged: Bool) -> some View {
        HStack {
            Image(systemName: status.icon)
                .font(.caption2)
                .foregroundStyle(status.color)
            
            Text(file.split(separator: "/").last.map(String.init) ?? file)
                .font(DS.Typography.caption)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            loadDiff(for: file)
        }
    }
    
    private func loadDiff(for file: String) {
        diffContent = git.getDiff(file: file)
    }
}
