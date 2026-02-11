import SwiftUI

// MARK: - Main View
// Professional IDE layout matching VS Code/Cursor/Windsurf

struct MainView: View {
    @Environment(AppState.self) private var appState
    @State private var panels = PanelState.shared
    @State private var contentMinEditorWidth: CGFloat = 520  // Updated via preference from content
    
    // Minimum width per pane - MUST match Quick Start/Available Models bubble (~520px)
    private let minPaneWidth: CGFloat = 520
    
    // Calculate effective minimum editor width based on layout
    private var minEditorWidth: CGFloat {
        switch panels.editorLayout {
        case .single:
            return max(contentMinEditorWidth, 520)
        case .splitVertical:
            // Two panes side by side + divider - each pane gets Quick Start width
            return (minPaneWidth * 2) + 1
        case .splitHorizontal:
            // Panes stacked vertically, width is single pane width
            return minPaneWidth
        case .grid:
            // 2x2 needs room for two columns + divider
            return (minPaneWidth * 2) + 1
        }
    }
    
    var body: some View {
        @Bindable var state = appState
        
        ZStack {
            // Base background
            DS.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Main content area
                mainContentArea
                
                // Status Bar
                if panels.showStatusBar && !panels.zenMode {
                    StatusBarView()
                }
            }
            .toolbar { MainToolbarContent(appState: state, panels: panels) }
            .navigationTitle(appState.rootFolder?.lastPathComponent ?? "OllamaBot")
            
            // Overlay Dialogs
            overlayDialogs
            
            // Toast notifications
            VStack {
                DSToastContainer(toasts: $state.toasts)
                Spacer()
            }
        }
        .preferredColorScheme(colorScheme)
        .onKeyPress(.escape) {
            // Dismiss overlays in priority order
            if appState.showCommandPalette { appState.showCommandPalette = false; return .handled }
            if appState.showQuickOpen { appState.showQuickOpen = false; return .handled }
            if appState.showGlobalSearch { appState.showGlobalSearch = false; return .handled }
            if appState.showGoToLine { appState.showGoToLine = false; return .handled }
            if appState.showGitStatus { appState.showGitStatus = false; return .handled }
            if appState.showSettings { appState.showSettings = false; return .handled }
            if appState.showPerformanceDashboard { appState.showPerformanceDashboard = false; return .handled }
            if appState.showOrchestration { appState.showOrchestration = false; return .handled }
            if appState.showCostDashboard { appState.showCostDashboard = false; return .handled }
            if appState.showSessions { appState.showSessions = false; return .handled }
            if appState.showPreview { appState.showPreview = false; return .handled }
            if appState.showFindInFile { appState.showFindInFile = false; return .handled }
            if appState.showFindReplace { appState.showFindReplace = false; return .handled }
            // Dismiss bottom panel last
            if panels.showBottomPanel { panels.toggleBottomPanel(); return .handled }
            return .ignored
        }
        .onDisappear {
            panels.saveState()
        }
    }
    
    // MARK: - Main Content Area
    
    @ViewBuilder
    private var mainContentArea: some View {
        GeometryReader { geometry in
            // 1. Calculate the fixed widths of side panels
            let leftPanelWidth = calculateLeftPanelWidth()
            
            // 2. Calculate max available width for secondary sidebar
            let maxSecondaryWidth = max(
                PanelState.minSecondarySidebarWidth,
                geometry.size.width - leftPanelWidth - minEditorWidth - 6
            )
            
            // 3. Clamp secondary sidebar width
            let clampedSecondaryWidth = min(panels.secondarySidebarWidth, maxSecondaryWidth)
            
            // 4. Calculate right panel width
            let rightPanelWidth = calculateRightPanelWidth(clampedSecondaryWidth: clampedSecondaryWidth)
            
            // 5. Calculate minimum total width
            let minTotalWidth = leftPanelWidth + minEditorWidth + rightPanelWidth
            
            // 6. Calculate content width
            let contentWidth = max(geometry.size.width, minTotalWidth)
            
            // 7. Calculate editor width
            let currentEditorWidth = contentWidth - leftPanelWidth - rightPanelWidth
            
            ZStack(alignment: .bottomLeading) {
                HStack(spacing: 0) {
                    // LEFT PANEL
                    HStack(spacing: 0) {
                        if panels.primarySidebarPosition == .left && panels.activityBarPosition == .side && !panels.zenMode {
                            ActivityBarView(panels: panels)
                                .environment(appState)
                        }
                        
                        if panels.showPrimarySidebar && panels.primarySidebarPosition == .left && !panels.zenMode {
                            primarySidebar
                                .frame(width: panels.primarySidebarWidth)
                            PanelResizer(
                                axis: .vertical,
                                size: $panels.primarySidebarWidth,
                                minSize: PanelState.minSidebarWidth,
                                maxSize: PanelState.maxSidebarWidth
                            ) {
                                panels.saveState()
                            }
                        }
                    }
                    .frame(width: leftPanelWidth)
                    
                    // MIDDLE PANEL
                    editorArea
                        .frame(width: currentEditorWidth)
                        .clipped()
                        .onPreferenceChange(MinEditorWidthKey.self) { width in
                            if abs(contentMinEditorWidth - width) > 1 && width > 0 {
                                contentMinEditorWidth = max(520, width)
                            }
                        }
                    
                    // RIGHT PANELS
                    HStack(spacing: 0) {
                        if panels.showPrimarySidebar && panels.primarySidebarPosition == .right && !panels.zenMode {
                            PanelResizer(
                                axis: .vertical,
                                size: $panels.primarySidebarWidth,
                                minSize: PanelState.minSidebarWidth,
                                maxSize: PanelState.maxSidebarWidth,
                                isRightSide: true
                            ) {
                                panels.saveState()
                            }
                            primarySidebar
                                .frame(width: panels.primarySidebarWidth)
                        }
                        
                        if panels.showSecondarySidebar && !panels.zenMode {
                            PanelResizer(
                                axis: .vertical,
                                size: $panels.secondarySidebarWidth,
                                minSize: PanelState.minSecondarySidebarWidth,
                                maxSize: maxSecondaryWidth,
                                isRightSide: true
                            ) {
                                panels.saveState()
                            }
                            secondarySidebar
                                .frame(width: clampedSecondaryWidth)
                        }
                        
                        if panels.primarySidebarPosition == .right && panels.activityBarPosition == .side && !panels.zenMode {
                            ActivityBarView(panels: panels)
                                .environment(appState)
                        }
                    }
                    .frame(width: rightPanelWidth, alignment: .leading)
                    .zIndex(1)
                }
                .frame(width: contentWidth, height: geometry.size.height, alignment: .leading)
                
                // Bottom Panel Overlay - Confined to editor region
                if panels.showBottomPanel && !panels.zenMode {
                    VStack(spacing: 0) {
                        // Horizontal resizer
                        PanelResizer(
                            axis: .horizontal,
                            size: $panels.bottomPanelHeight,
                            minSize: PanelState.minPanelHeight,
                            maxSize: geometry.size.height,
                            isRightSide: true
                        ) {
                            panels.saveState()
                        }
                        
                        bottomPanel
                    }
                    .frame(height: panels.bottomPanelMaximized 
                        ? geometry.size.height 
                        : min(panels.bottomPanelHeight, geometry.size.height))
                    .frame(width: currentEditorWidth)
                    .offset(x: leftPanelWidth)
                    .background(DS.Colors.background)
                    .transition(.move(edge: .bottom))
                    .zIndex(100) // Ensure it's on top
                }
            }
        }
        .clipped()
    }
    
    // Calculate total width of left panel components
    private func calculateLeftPanelWidth() -> CGFloat {
        var width: CGFloat = 0
        if panels.primarySidebarPosition == .left && panels.activityBarPosition == .side && !panels.zenMode {
            width += 48 // ActivityBar
        }
        if panels.showPrimarySidebar && panels.primarySidebarPosition == .left && !panels.zenMode {
            width += panels.primarySidebarWidth + 6 // Sidebar + Resizer (6px)
        }
        return width
    }
    
    // Calculate total width of right panel components
    private func calculateRightPanelWidth(clampedSecondaryWidth: CGFloat? = nil) -> CGFloat {
        var width: CGFloat = 0
        if panels.showPrimarySidebar && panels.primarySidebarPosition == .right && !panels.zenMode {
            width += panels.primarySidebarWidth + 6 // Sidebar + Resizer (6px)
        }
        if panels.showSecondarySidebar && !panels.zenMode {
            // Use clamped width if provided, otherwise use stored value
            let secondaryWidth = clampedSecondaryWidth ?? panels.secondarySidebarWidth
            width += secondaryWidth + 6 // Sidebar + Resizer (6px)
        }
        if panels.primarySidebarPosition == .right && panels.activityBarPosition == .side && !panels.zenMode {
            width += 48 // ActivityBar
        }
        return width
    }
    
    private var primarySidebar: some View {
        VStack(spacing: 0) {
            // Activity bar at top (if configured)
            if panels.activityBarPosition == .top {
                activityBarTop
            }
            
            // Sidebar content
            Group {
                switch panels.primarySidebarTab {
                case .explorer:
                    FileTreeView()
                case .search:
                    SearchSidebarView()
                case .sourceControl:
                    GitSidebarView()
                case .obot:
                    OBotPanelView()
                case .checkpoints:
                    CheckpointListView()
                case .outline:
                    OutlineView()
                case .extensions:
                    ExtensionsSidebarView()
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: panels.primarySidebarWidth)
        .background(DS.Colors.secondaryBackground)
    }
    
    private var activityBarTop: some View {
        HStack(spacing: 0) {
            ForEach(SidebarTab.allCases) { tab in
                Button(action: { panels.setPrimarySidebarTab(tab) }) {
                    Image(systemName: tab.icon)
                        .font(.caption)
                        .foregroundStyle(
                            panels.primarySidebarTab == tab
                                ? DS.Colors.accent
                                : DS.Colors.secondaryText
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            panels.primarySidebarTab == tab
                                ? DS.Colors.accent.opacity(0.15)
                                : Color.clear
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(DS.Colors.surface)
    }
    
    // MARK: - Secondary Sidebar (Chat/Outline)
    
    private var secondarySidebar: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(SecondarySidebarTab.allCases) { tab in
                    Button(action: { panels.setSecondarySidebarTab(tab) }) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: tab.icon)
                                .font(.caption)
                            Text(tab.rawValue)
                                .font(DS.Typography.caption)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .foregroundStyle(
                            panels.secondarySidebarTab == tab
                                ? DS.Colors.text
                                : DS.Colors.secondaryText
                        )
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            panels.secondarySidebarTab == tab
                                ? DS.Colors.background
                                : Color.clear
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: DS.Spacing.xs)
                
                DSIconButton(icon: "xmark", size: 12) {
                    panels.toggleSecondarySidebar()
                }
                .padding(.trailing, DS.Spacing.sm)
            }
            .background(DS.Colors.surface)
            
            DSDivider()
            
            // Content
            Group {
                switch panels.secondarySidebarTab {
                case .chat:
                    ChatView()
                case .composer:
                    ComposerView()
                case .agents:
                    CycleAgentView()
                        .environment(appState.cycleAgentManager)
                        .environment(appState.modelTierManager)
                case .outline:
                    OutlineView()
                case .timeline:
                    TimelineView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        // Width is set externally where secondarySidebar is used
        .background(DS.Colors.secondaryBackground)
    }
    
    // MARK: - Editor Area
    
    private var editorArea: some View {
        VStack(spacing: 0) {
            // Tab bar
            if panels.showTabBar && !panels.zenMode {
                TabBarView()
            }
            
            // Breadcrumbs
            if panels.showBreadcrumbs && !panels.zenMode {
                BreadcrumbsView()
            }
            
            // Find bar
            if appState.showFindInFile || appState.showFindReplace {
                @Bindable var state = appState
                FindBarView(isPresented: $state.showFindInFile)
            }
            
            // Editor content - always present, never resizes
            editorContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DS.Colors.background)
    }
    
    @ViewBuilder
    private var editorContent: some View {
        if appState.showInfiniteMode {
            AgentView()
        } else {
            switch panels.editorLayout {
            case .single:
                EditorView()
            case .splitVertical:
                // Two editors side by side with proper sizing
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        EditorView()
                            .frame(minWidth: 200)
                            .frame(width: geometry.size.width / 2)
                        
                        // Divider - Transparent/Removed
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 1)
                        
                        EditorView()
                            .frame(minWidth: 200)
                    }
                }
            case .splitHorizontal:
                // Two editors stacked vertically
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        EditorView()
                            .frame(minHeight: 100)
                            .frame(height: geometry.size.height / 2)
                        
                        // Divider - Transparent/Removed
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 1)
                        
                        EditorView()
                            .frame(minHeight: 100)
                    }
                }
            case .grid:
                // 2x2 grid layout
                GeometryReader { geometry in
                    let halfWidth = geometry.size.width / 2
                    let halfHeight = geometry.size.height / 2
                    
                    VStack(spacing: 0) {
                        // Top row
                        HStack(spacing: 0) {
                            EditorView()
                                .frame(width: halfWidth, height: halfHeight)
                            
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 1)
                            
                            EditorView()
                                .frame(height: halfHeight)
                        }
                        
                        // Horizontal divider
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 1)
                        
                        // Bottom row
                        HStack(spacing: 0) {
                            EditorView()
                                .frame(width: halfWidth)
                            
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 1)
                            
                            EditorView()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Bottom Panel
    
    private var bottomPanel: some View {
        VStack(spacing: 0) {
            // Tab bar
            BottomPanelTabBar(
                selectedTab: $panels.bottomPanelTab,
                isMaximized: panels.bottomPanelMaximized,
                onMaximize: { panels.toggleMaximizeBottomPanel() },
                onClose: { panels.toggleBottomPanel() }
            )
            
            DSDivider()
            
            // Content - fills all remaining space
            Group {
                switch panels.bottomPanelTab {
                case .terminal:
                    TerminalView()
                case .problems:
                    ProblemsPanel()
                case .output:
                    OutputView()
                case .debugConsole:
                    DebugConsoleView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(DS.Colors.background)
    }
    
    // MARK: - Overlay Dialogs
    
    @ViewBuilder
    private var overlayDialogs: some View {
        @Bindable var state = appState
        
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
        
        if appState.showSettings {
            DialogOverlay {
                SettingsView()
                    .environment(appState)
                    .frame(width: 750, height: 550)
                    .background(DS.Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .overlay(
                        // Close button
                        Button(action: { appState.showSettings = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(DS.Colors.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .padding(DS.Spacing.md),
                        alignment: .topTrailing
                    )
            }
        }
        
        if appState.showPerformanceDashboard {
            DialogOverlay {
                PerformanceDashboardView()
                    .environment(appState)
                    .frame(width: 800, height: 600)
                    .background(DS.Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .overlay(
                        // Close button
                        Button(action: { appState.showPerformanceDashboard = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(DS.Colors.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .padding(DS.Spacing.md),
                        alignment: .topTrailing
                    )
            }
        }
        
        if appState.showOrchestration {
            DialogOverlay {
                OrchestrationView()
                    .environment(appState)
                    .frame(width: 800, height: 600)
                    .background(DS.Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .overlay(
                        Button(action: { appState.showOrchestration = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(DS.Colors.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .padding(DS.Spacing.md),
                        alignment: .topTrailing
                    )
            }
        }
        
        if appState.showCostDashboard {
            DialogOverlay {
                CostDashboardView()
                    .environment(appState)
                    .frame(width: 800, height: 600)
                    .background(DS.Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .overlay(
                        Button(action: { appState.showCostDashboard = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(DS.Colors.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .padding(DS.Spacing.md),
                        alignment: .topTrailing
                    )
            }
        }
        
        if appState.showSessions {
            DialogOverlay {
                SessionHandoffView()
                    .environment(appState)
                    .frame(width: 800, height: 600)
                    .background(DS.Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .overlay(
                        Button(action: { appState.showSessions = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(DS.Colors.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .padding(DS.Spacing.md),
                        alignment: .topTrailing
                    )
            }
        }
        
        if appState.showPreview {
            DialogOverlay {
                PreviewView()
                    .environment(appState)
                    .frame(width: 800, height: 600)
                    .background(DS.Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .overlay(
                        Button(action: { appState.showPreview = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(DS.Colors.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .padding(DS.Spacing.md),
                        alignment: .topTrailing
                    )
            }
        }
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
    var panels: PanelState
    @State private var showLayoutMenu = false
    
    var body: some ToolbarContent {
        // Left side - sidebar toggles
        ToolbarItem(placement: .navigation) {
            Button(action: { panels.togglePrimarySidebar() }) {
                Image(systemName: panels.primarySidebarPosition == .left ? "sidebar.left" : "sidebar.right")
            }
            .help("Toggle Sidebar (⌘B)")
        }
        
        // Connection status
        ToolbarItem(placement: .navigation) {
            DSConnectionStatus(
                isConnected: appState.ollamaService.isConnected,
                modelCount: appState.ollamaService.availableModels.count
            )
        }
        
        // Quality Preset
        ToolbarItem(placement: .navigation) {
            QualityPresetSelector(service: appState.orchestrationService)
        }
        
        // Center - editor layout controls
        ToolbarItem(placement: .principal) {
            Button {
                showLayoutMenu.toggle()
            } label: {
                Image(systemName: layoutIcon)
            }
            .buttonStyle(.plain)
            .help("Editor Layout")
            .popover(isPresented: $showLayoutMenu, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    LayoutMenuRow(title: "Single Editor") {
                        showLayoutMenu = false
                        panels.setEditorLayout(.single)
                    }
                    LayoutMenuRow(title: "Split Vertical") {
                        showLayoutMenu = false
                        panels.setEditorLayout(.splitVertical)
                    }
                    LayoutMenuRow(title: "Split Horizontal") {
                        showLayoutMenu = false
                        panels.setEditorLayout(.splitHorizontal)
                    }
                    LayoutMenuRow(title: "Grid (2x2)") {
                        showLayoutMenu = false
                        panels.setEditorLayout(.grid)
                    }
                    DSDivider()
                    LayoutMenuRow(title: "Zen Mode (⌘K Z)") {
                        showLayoutMenu = false
                        panels.toggleZenMode()
                    }
                }
                .padding(DS.Spacing.sm)
                .background(DS.Colors.surface)
            }
        }
        
        // Right side - actions
        ToolbarItem(placement: .primaryAction) {
            Button(action: { appState.showCommandPalette.toggle() }) {
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
            Button(action: { panels.toggleBottomPanel() }) {
                Image(systemName: "rectangle.bottomthird.inset.filled")
            }
            .help("Toggle Panel (⌃`)")
        }
        
        ToolbarItem(placement: .primaryAction) {
            Button(action: { panels.toggleSecondarySidebar() }) {
                Image(systemName: "sidebar.right")
            }
            .help("Toggle Secondary Sidebar")
        }
    }
    
    private var layoutIcon: String {
        switch panels.editorLayout {
        case .single: return "rectangle"
        case .splitVertical: return "rectangle.split.2x1"
        case .splitHorizontal: return "rectangle.split.1x2"
        case .grid: return "rectangle.split.2x2"
        }
    }
}

private struct LayoutMenuRow: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.text)
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(isHovered ? DS.Colors.tertiaryBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Dialog Overlay

struct QualityPresetSelector: View {
    var service: OrchestrationService
    @State private var presetService = QualityPresetService.shared
    @State private var showPresets = false
    
    var body: some View {
        Button {
            showPresets.toggle()
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: presetService.currentPreset.icon)
                    .font(.caption)
                Text(presetService.currentPreset.rawValue.capitalized)
                    .font(DS.Typography.caption)
            }
            .foregroundStyle(DS.Colors.secondaryText)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 4)
            .background(DS.Colors.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(DS.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("Quality Preset")
        .onChange(of: presetService.currentPreset) { _, newValue in
            service.qualityPreset = newValue
        }
        .popover(isPresented: $showPresets, arrowEdge: .top) {
            VStack(spacing: 0) {
                QualityPresetView()
                    .frame(width: 320)
            }
            .padding(DS.Spacing.sm)
            .background(DS.Colors.surface)
        }
    }
}

struct DialogOverlay<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        ZStack {
            DS.Colors.background.opacity(0.85)
                .ignoresSafeArea()
            
            content
        }
    }
}

// MARK: - Sidebar Views

struct FileTreeView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            DSSectionHeader(title: "EXPLORER") {
                DSIconButton(icon: "folder.badge.plus", size: 14) {
                    appState.openFolderPanel()
                }
            }
            
            DSDivider()
            
            // File tree
            if let root = appState.rootFolder {
                DSScrollView {
                    FileTreeNode(url: root, level: 0)
                        .padding(.vertical, DS.Spacing.xs)
                }
            } else {
                VStack(spacing: DS.Spacing.lg) {
                    Image(systemName: "folder")
                        .font(.system(size: 40))
                        .foregroundStyle(DS.Colors.tertiaryText)
                    
                    Text("No Folder Open")
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.secondaryText)
                    
                    Text("Open a folder to get started")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    
                    DSButton("Open Folder", style: .primary, size: .sm) {
                        appState.openFolderPanel()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    @State private var isHovered: Bool = false
    
    private var isDirectory: Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }
    
    private var isSelected: Bool {
        appState.selectedFile?.url == url
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Node row
            HStack(spacing: DS.Spacing.xs) {
                if isDirectory {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                        .frame(width: 12)
                        .onTapGesture { toggle() }
                } else {
                    Spacer().frame(width: 12)
                }
                
                Image(systemName: iconFor(url))
                    .font(.caption)
                    .foregroundStyle(colorFor(url))
                
                Text(url.lastPathComponent)
                    .font(DS.Typography.callout)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.leading, CGFloat(level) * 16 + DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .padding(.trailing, DS.Spacing.sm)
            .background(
                isSelected
                    ? DS.Colors.accent.opacity(0.2)
                    : (isHovered ? DS.Colors.surface : Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if isDirectory {
                    toggle()
                } else {
                    let file = FileItem(url: url, isDirectory: false)
                    appState.openFile(file)
                }
            }
            .onHover { isHovered = $0 }
            .contextMenu { fileContextMenu }
            
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
            appState.initiateRename(for: url)
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
        withAnimation(DS.Animation.fast) {
            isExpanded.toggle()
        }
        if isExpanded && children.isEmpty {
            loadChildren()
        }
    }
    
    private func loadChildren() {
        guard isDirectory else { return }
        let target = url
        
        Task.detached {
            let excludePatterns = Set([
                "node_modules", ".git", "__pycache__", ".build",
                ".DS_Store", ".swiftpm", "DerivedData", ".next"
            ])
            
            let result: [URL]
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: target,
                    includingPropertiesForKeys: [.isDirectoryKey]
                )
                result = contents.filter { !excludePatterns.contains($0.lastPathComponent) }
                    .sorted { url1, url2 in
                        let isDir1 = (try? url1.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                        let isDir2 = (try? url2.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                        if isDir1 == isDir2 {
                            return url1.lastPathComponent.localizedCaseInsensitiveCompare(url2.lastPathComponent) == .orderedAscending
                        }
                        return isDir1 && !isDir2
                    }
            } catch {
                result = []
            }
            
            await MainActor.run {
                children = result
            }
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
        case "html": return "chevron.left.forwardslash.chevron.right"
        case "css", "scss": return "paintbrush.fill"
        case "sh", "bash": return "terminal.fill"
        default: return "doc.fill"
        }
    }
    
    private func colorFor(_ url: URL) -> Color {
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        if isDir { return DS.Colors.info }
        
        // All file type colors use blue spectrum for consistency
        switch url.pathExtension.lowercased() {
        case "swift": return DS.Colors.accent           // Cyan blue
        case "py": return DS.Colors.accentAlt           // Teal blue
        case "js": return DS.Colors.accentLight         // Light blue
        case "ts", "tsx": return DS.Colors.info         // Royal blue
        case "json": return DS.Colors.accentDark        // Dark blue
        case "md": return DS.Colors.accent              // Cyan blue
        case "html": return DS.Colors.researcher        // Teal blue
        case "css", "scss": return DS.Colors.info       // Royal blue
        default: return DS.Colors.secondaryText
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
        .background(DS.Colors.surface)
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
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: file.icon)
                .font(.caption)
                .foregroundStyle(file.iconColor)
            
            Text(file.name)
                .font(DS.Typography.callout)
                .lineLimit(1)
            
            if file.isModified {
                Circle()
                    .fill(DS.Colors.warning)
                    .frame(width: 6, height: 6)
            }
            
            if isHovered || isSelected {
                Button(action: { appState.closeFile(file) }) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(isSelected ? DS.Colors.background : Color.clear)
        .overlay(alignment: .bottom) {
            if isSelected {
                Rectangle()
                    .fill(DS.Colors.accent)
                    .frame(height: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { appState.openFile(file) }
        .onHover { isHovered = $0 }
    }
}

// MARK: - Breadcrumbs View

struct BreadcrumbsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.xs) {
                if let file = appState.selectedFile, let root = appState.rootFolder {
                    let components = file.url.pathComponents.drop { component in
                        !root.pathComponents.contains(component) || component == root.lastPathComponent
                    }
                    
                    ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(DS.Colors.tertiaryText)
                        }
                        
                        Text(component)
                            .font(DS.Typography.caption)
                            .foregroundStyle(index == components.count - 1 ? DS.Colors.text : DS.Colors.secondaryText)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
        }
        .frame(height: 24)
        .background(DS.Colors.surface.opacity(0.5))
    }
}

// MARK: - Search Sidebar View

struct SearchSidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false
    @State private var useRegex = false
    @State private var matchCase = false
    @State private var selectedResultIndex: Int = -1
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            DSSectionHeader(title: "SEARCH")
            
            DSDivider()
            
            // Search input
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DS.Colors.tertiaryText)
                
                ZStack(alignment: .leading) {
                    if searchText.isEmpty {
                        Text("Search in files...")
                            .font(DS.Typography.callout)
                            .foregroundStyle(DS.Colors.tertiaryText)
                    }
                    TextField("", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(DS.Typography.callout)
                        .foregroundStyle(DS.Colors.text)
                        .focused($isSearchFieldFocused)
                        .onSubmit {
                            if !searchResults.isEmpty && selectedResultIndex >= 0 && selectedResultIndex < searchResults.count {
                                openResult(searchResults[selectedResultIndex])
                            } else {
                                performSearch()
                            }
                        }
                }
                
                if isSearching {
                    DSLoadingSpinner(size: 12)
                }
            }
            .padding(DS.Spacing.sm)
            
            // Search options
            HStack(spacing: DS.Spacing.sm) {
                Toggle(isOn: $useRegex) {
                    Image(systemName: "asterisk")
                        .font(.caption2)
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
                .padding(4)
                .background(useRegex ? DS.Colors.accent.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                .help("Use Regular Expression")
                
                Toggle(isOn: $matchCase) {
                    Text("Aa")
                        .font(.caption2.weight(.medium))
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
                .padding(4)
                .background(matchCase ? DS.Colors.accent.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                .help("Match Case")
                
                Spacer()
            }
            .foregroundStyle(DS.Colors.secondaryText)
            .padding(.horizontal, DS.Spacing.sm)
            .background(DS.Colors.tertiaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .padding(DS.Spacing.sm)
            
            DSDivider()
            
            // Results
            if searchResults.isEmpty && !searchText.isEmpty && !isSearching {
                VStack {
                    DSEmptyState(
                        icon: "magnifyingglass",
                        title: "No Results",
                        message: "No matches found for '\(searchText)'"
                    )
                    Spacer()
                }
            } else if searchResults.isEmpty {
                VStack {
                    DSEmptyState(
                        icon: "magnifyingglass",
                        title: "Search",
                        message: "Search across all files"
                    )
                    Spacer()
                }
            } else {
                DSScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, result in
                            SearchResultRow(result: result, isSelected: index == selectedResultIndex)
                                .onTapGesture {
                                    selectedResultIndex = index
                                    openResult(result)
                                }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onKeyPress(.upArrow) {
            if !searchResults.isEmpty {
                selectedResultIndex = max(0, selectedResultIndex - 1)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.downArrow) {
            if !searchResults.isEmpty {
                selectedResultIndex = min(searchResults.count - 1, selectedResultIndex + 1)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            if !searchResults.isEmpty {
                searchResults = []
                searchText = ""
                selectedResultIndex = -1
                return .handled
            }
            return .ignored
        }
        .onChange(of: searchResults) { _, newResults in
            selectedResultIndex = newResults.isEmpty ? -1 : 0
        }
    }
    
    private func openResult(_ result: SearchResult) {
        let file = FileItem(url: result.file, isDirectory: false)
        appState.openFile(file)
        if let line = result.lineNumber {
            appState.goToLine = line
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        Task {
            let results: [SearchResult]
            
            if useRegex {
                // Regex search
                results = await performRegexSearch(searchText, matchCase: matchCase)
            } else {
                // Standard search
                let searchResults = await appState.fileIndexer.searchContent(searchText, maxResults: 100)
                results = searchResults.map { (url, _) in
                    SearchResult(file: url, match: searchText, lineNumber: nil, lineContent: nil)
                }
            }
            
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        }
    }
    
    private func performRegexSearch(_ pattern: String, matchCase: Bool) async -> [SearchResult] {
        guard let root = appState.rootFolder else { return [] }
        
        var results: [SearchResult] = []
        let options: NSRegularExpression.Options = matchCase ? [] : [.caseInsensitive]
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return []
        }
        
        // Get all files
        let fileItems = appState.fileSystemService.getAllFiles(in: root)
        
        for fileItem in fileItems.prefix(500) { // Limit to prevent hanging
            guard !fileItem.isDirectory,
                  let content = appState.fileSystemService.readFile(at: fileItem.url) else { continue }
            
            let lines = content.components(separatedBy: CharacterSet.newlines)
            for (index, line) in lines.enumerated() {
                let range = NSRange(line.startIndex..., in: line)
                if regex.firstMatch(in: line, range: range) != nil {
                    results.append(SearchResult(
                        file: fileItem.url,
                        match: pattern,
                        lineNumber: index + 1,
                        lineContent: String(line.prefix(100))
                    ))
                    
                    if results.count >= 100 { return results }
                }
            }
        }
        
        return results
    }
}

struct SearchResult: Identifiable, Equatable {
    let id = UUID()
    let file: URL
    let match: String
    var lineNumber: Int?
    var lineContent: String?
    
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

struct SearchResultRow: View {
    @Environment(AppState.self) private var appState
    let result: SearchResult
    var isSelected: Bool = false
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                
                Text(result.file.lastPathComponent)
                    .font(DS.Typography.caption)
                    .lineLimit(1)
                
                if let lineNum = result.lineNumber {
                    Text(":\(lineNum)")
                        .font(DS.Typography.mono(10))
                        .foregroundStyle(DS.Colors.accent)
                }
                
                Spacer()
            }
            
            if let lineContent = result.lineContent {
                Text(lineContent)
                    .font(DS.Typography.mono(10))
                    .foregroundStyle(DS.Colors.tertiaryText)
                    .lineLimit(1)
                    .padding(.leading, DS.Spacing.lg + DS.Spacing.sm)
            } else {
                Text(result.file.deletingLastPathComponent().lastPathComponent)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
                    .padding(.leading, DS.Spacing.lg + DS.Spacing.sm)
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(isSelected ? DS.Colors.accent.opacity(0.2) : (isHovered ? DS.Colors.surface : Color.clear))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

// MARK: - Git Sidebar View

struct GitSidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var commitMessage = ""
    
    private var git: GitService { appState.gitService }
    
    var body: some View {
        VStack(spacing: 0) {
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
                VStack {
                    DSEmptyState(
                        icon: "arrow.triangle.branch",
                        title: "Not a Git Repository",
                        message: "Open a folder with git initialized"
                    )
                    Spacer()
                }
            } else {
                DSScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        branchSection
                        
                        if let status = git.status {
                            changesSection(status)
                        }
                        
                        commitSection
                    }
                    .padding(DS.Spacing.sm)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            if !status.staged.isEmpty {
                changeGroup(title: "Staged Changes", changes: status.staged, staged: true)
            }
            if !status.unstaged.isEmpty {
                changeGroup(title: "Changes", changes: status.unstaged, staged: false)
            }
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
            ZStack(alignment: .topLeading) {
                if commitMessage.isEmpty {
                    Text("Commit message...")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.tertiaryText)
                        .padding(DS.Spacing.sm)
                }
                TextField("", text: $commitMessage, axis: .vertical)
                    .font(DS.Typography.caption)
                    .textFieldStyle(.plain)
                    .foregroundStyle(DS.Colors.text)
                    .padding(DS.Spacing.sm)
                    .lineLimit(3...5)
            }
            .background(DS.Colors.tertiaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            
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

// MARK: - Extensions Sidebar View

struct ExtensionsSidebarView: View {
    var body: some View {
        VStack(spacing: 0) {
            DSSectionHeader(title: "EXTENSIONS")
            
            DSDivider()
            
            VStack {
                DSEmptyState(
                    icon: "puzzlepiece.extension",
                    title: "Extensions",
                    message: "Extension support coming soon"
                )
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Timeline View

struct TimelineView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: TimelineTab = .checkpoints
    
    enum TimelineTab: String, CaseIterable {
        case checkpoints = "Checkpoints"
        case git = "Git"
        
        var icon: String {
            switch self {
            case .checkpoints: return "clock.arrow.circlepath"
            case .git: return "arrow.triangle.branch"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack(spacing: 0) {
                ForEach(TimelineTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: tab.icon)
                                .font(.caption)
                            Text(tab.rawValue)
                                .font(DS.Typography.caption)
                        }
                        .foregroundStyle(selectedTab == tab ? DS.Colors.text : DS.Colors.secondaryText)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(selectedTab == tab ? DS.Colors.accent.opacity(0.1) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .background(DS.Colors.surface)
            
            DSDivider()
            
            // Content
            switch selectedTab {
            case .checkpoints:
                CheckpointListView()
            case .git:
                GitTimelineView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct GitTimelineView: View {
    @Environment(AppState.self) private var appState
    @State private var commits: [GitCommit] = []
    @State private var isLoading = false
    
    var body: some View {
        if appState.selectedFile == nil {
            VStack {
                DSEmptyState(
                    icon: "clock",
                    title: "Git History",
                    message: "Select a file to view its history"
                )
                Spacer()
            }
        } else {
            DSScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Git history for \(appState.selectedFile?.name ?? "")")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                        .padding(DS.Spacing.sm)
                    
                    if isLoading {
                        HStack {
                            Spacer()
                            DSLoadingSpinner(size: 16)
                            Text("Loading history...")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.tertiaryText)
                            Spacer()
                        }
                        .padding(DS.Spacing.md)
                    } else if commits.isEmpty {
                        DSEmptyState(
                            icon: "clock",
                            title: "No History",
                            message: "No commits found"
                        )
                    } else {
                        ForEach(commits) { commit in
                            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                                Circle()
                                    .fill(DS.Colors.accent)
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 6)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(commit.message)
                                        .font(DS.Typography.callout)
                                        .lineLimit(2)
                                    
                                    HStack(spacing: DS.Spacing.sm) {
                                        Text(commit.shortHash)
                                            .font(DS.Typography.mono(10))
                                            .foregroundStyle(DS.Colors.accent)
                                        
                                        Text(commit.author)
                                            .font(DS.Typography.caption)
                                            .foregroundStyle(DS.Colors.secondaryText)
                                        
                                        Text(commit.date)
                                            .font(DS.Typography.caption)
                                            .foregroundStyle(DS.Colors.tertiaryText)
                                    }
                                }
                            }
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.sm)
                        }
                    }
                }
            }
            .onAppear { loadCommits() }
            .onChange(of: appState.selectedFile?.url) { _, _ in loadCommits() }
        }
    }
    
    private func loadCommits() {
        isLoading = true
        let gitService = appState.gitService
        Task.detached {
            let result = gitService.getLog(count: 20)
            await MainActor.run {
                commits = result
                isLoading = false
            }
        }
    }
}

// MARK: - Debug Console View

struct DebugConsoleView: View {
    @State private var debugOutput: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            DSScrollView {
                Text(debugOutput.isEmpty ? "Debug console - no output" : debugOutput)
                    .font(DS.Typography.mono(11))
                    .foregroundStyle(debugOutput.isEmpty ? DS.Colors.tertiaryText : DS.Colors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DS.Spacing.sm)
            }
            .background(DS.Colors.codeBackground)
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
                        DSScrollView {
                            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                fileSection(title: "Staged (\(status.staged.count))", changes: status.staged)
                                fileSection(title: "Modified (\(status.unstaged.count))", changes: status.unstaged)
                                fileSection(title: "Untracked (\(status.untracked.count))", files: status.untracked, status: .untracked)
                            }
                            .padding(DS.Spacing.sm)
                        }
                    }
                }
                .frame(width: 200)
                
                DSDivider()
                
                // Diff view
                DSScrollView {
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
    
    private func fileRow(_ file: String, status: GitChangeStatus) -> some View {
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
            diffContent = git.getDiff(file: file)
        }
    }
    
    @ViewBuilder
    private func fileSection(title: String, changes: [GitFileChange]) -> some View {
        if !changes.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
                
                ForEach(changes) { change in
                    fileRow(change.filename, status: change.status)
                }
            }
            .padding(DS.Spacing.sm)
            .background(DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
    }
    
    @ViewBuilder
    private func fileSection(title: String, files: [String], status: GitChangeStatus) -> some View {
        if !files.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
                
                ForEach(files, id: \.self) { file in
                    fileRow(file, status: status)
                }
            }
            .padding(DS.Spacing.sm)
            .background(DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
    }
}
