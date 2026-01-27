import SwiftUI

// MARK: - Panel Layout Configuration
// Matches VS Code/Cursor/Windsurf panel system

/// Panel position options for primary sidebar
enum SidebarPosition: String, CaseIterable, Codable {
    case left
    case right
}

/// Panel position options for bottom panel
enum BottomPanelPosition: String, CaseIterable, Codable {
    case bottom      // Traditional bottom position
    case rightSplit  // Split with editor on right (Windsurf style)
}

/// Activity bar position
enum ActivityBarPosition: String, CaseIterable, Codable {
    case side       // Vertical on sidebar edge
    case top        // Horizontal at top of sidebar
    case hidden     // No activity bar
}

/// Editor layout options
enum EditorLayout: String, CaseIterable, Codable {
    case single         // One editor
    case splitVertical  // Two editors side by side
    case splitHorizontal // Two editors stacked
    case grid           // 2x2 grid
}

/// Bottom panel tabs (like VS Code)
enum BottomPanelTab: String, CaseIterable, Identifiable {
    case terminal = "Terminal"
    case problems = "Problems"
    case output = "Output"
    case debugConsole = "Debug Console"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .terminal: return "terminal"
        case .problems: return "exclamationmark.triangle"
        case .output: return "text.alignleft"
        case .debugConsole: return "ant"
        }
    }
    
    var shortcut: KeyEquivalent? {
        switch self {
        case .terminal: return "`"
        case .problems: return "m"
        case .output: return "u"
        case .debugConsole: return nil
        }
    }
}

/// Sidebar tabs
enum SidebarTab: String, CaseIterable, Identifiable {
    case explorer = "Explorer"
    case search = "Search"
    case sourceControl = "Source Control"
    case outline = "Outline"
    case extensions = "Extensions"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .explorer: return "doc.on.doc"
        case .search: return "magnifyingglass"
        case .sourceControl: return "arrow.triangle.branch"
        case .outline: return "list.bullet.indent"
        case .extensions: return "puzzlepiece.extension"
        }
    }
}

/// Secondary sidebar tabs (right side, like VS Code)
enum SecondarySidebarTab: String, CaseIterable, Identifiable {
    case chat = "AI Chat"
    case outline = "Outline"
    case timeline = "Timeline"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .chat: return "bubble.right"
        case .outline: return "list.bullet.indent"
        case .timeline: return "clock"
        }
    }
}

// MARK: - Panel State Manager

@Observable
final class PanelState {
    // MARK: - Singleton
    static let shared = PanelState()
    
    // MARK: - Primary Sidebar
    var showPrimarySidebar: Bool = true
    var primarySidebarPosition: SidebarPosition = .left
    var primarySidebarWidth: CGFloat = 260
    var primarySidebarTab: SidebarTab = .explorer
    var activityBarPosition: ActivityBarPosition = .side
    
    // MARK: - Secondary Sidebar (Right)
    var showSecondarySidebar: Bool = true
    var secondarySidebarWidth: CGFloat = 380
    var secondarySidebarTab: SecondarySidebarTab = .chat
    
    // MARK: - Bottom Panel
    var showBottomPanel: Bool = false
    var bottomPanelPosition: BottomPanelPosition = .bottom
    var bottomPanelHeight: CGFloat = 200
    var bottomPanelTab: BottomPanelTab = .terminal
    var bottomPanelMaximized: Bool = false
    
    // MARK: - Editor
    var editorLayout: EditorLayout = .single
    var showMinimap: Bool = true
    var showBreadcrumbs: Bool = true
    var showLineNumbers: Bool = true
    
    // MARK: - Zen Mode
    var zenMode: Bool = false
    private var preZenState: ZenModeState?
    
    // MARK: - Status Bar
    var showStatusBar: Bool = true
    
    // MARK: - Tab Bar
    var showTabBar: Bool = true
    var tabBarStyle: TabBarStyle = .standard
    
    // MARK: - Panel Constraints
    static let minSidebarWidth: CGFloat = 180
    static let maxSidebarWidth: CGFloat = 500
    static let minPanelHeight: CGFloat = 100
    static let maxPanelHeight: CGFloat = 600
    
    // MARK: - Persistence Keys
    private enum Keys {
        static let prefix = "panel."
        static let showPrimarySidebar = prefix + "showPrimarySidebar"
        static let primarySidebarPosition = prefix + "primarySidebarPosition"
        static let primarySidebarWidth = prefix + "primarySidebarWidth"
        static let primarySidebarTab = prefix + "primarySidebarTab"
        static let activityBarPosition = prefix + "activityBarPosition"
        static let showSecondarySidebar = prefix + "showSecondarySidebar"
        static let secondarySidebarWidth = prefix + "secondarySidebarWidth"
        static let secondarySidebarTab = prefix + "secondarySidebarTab"
        static let showBottomPanel = prefix + "showBottomPanel"
        static let bottomPanelPosition = prefix + "bottomPanelPosition"
        static let bottomPanelHeight = prefix + "bottomPanelHeight"
        static let bottomPanelTab = prefix + "bottomPanelTab"
        static let editorLayout = prefix + "editorLayout"
        static let showMinimap = prefix + "showMinimap"
        static let showBreadcrumbs = prefix + "showBreadcrumbs"
        static let showStatusBar = prefix + "showStatusBar"
        static let showTabBar = prefix + "showTabBar"
    }
    
    // MARK: - Initialization
    
    private init() {
        loadState()
    }
    
    // MARK: - State Persistence
    
    private func loadState() {
        let defaults = UserDefaults.standard
        
        showPrimarySidebar = defaults.object(forKey: Keys.showPrimarySidebar) as? Bool ?? true
        if let pos = defaults.string(forKey: Keys.primarySidebarPosition),
           let position = SidebarPosition(rawValue: pos) {
            primarySidebarPosition = position
        }
        primarySidebarWidth = defaults.double(forKey: Keys.primarySidebarWidth).nonZeroOr(260)
        if let tab = defaults.string(forKey: Keys.primarySidebarTab),
           let sidebarTab = SidebarTab(rawValue: tab) {
            primarySidebarTab = sidebarTab
        }
        if let pos = defaults.string(forKey: Keys.activityBarPosition),
           let position = ActivityBarPosition(rawValue: pos) {
            activityBarPosition = position
        }
        
        showSecondarySidebar = defaults.object(forKey: Keys.showSecondarySidebar) as? Bool ?? true
        secondarySidebarWidth = defaults.double(forKey: Keys.secondarySidebarWidth).nonZeroOr(380)
        if let tab = defaults.string(forKey: Keys.secondarySidebarTab),
           let secTab = SecondarySidebarTab(rawValue: tab) {
            secondarySidebarTab = secTab
        }
        
        showBottomPanel = defaults.bool(forKey: Keys.showBottomPanel)
        if let pos = defaults.string(forKey: Keys.bottomPanelPosition),
           let position = BottomPanelPosition(rawValue: pos) {
            bottomPanelPosition = position
        }
        bottomPanelHeight = defaults.double(forKey: Keys.bottomPanelHeight).nonZeroOr(200)
        if let tab = defaults.string(forKey: Keys.bottomPanelTab),
           let bottomTab = BottomPanelTab(rawValue: tab) {
            bottomPanelTab = bottomTab
        }
        
        if let layout = defaults.string(forKey: Keys.editorLayout),
           let edLayout = EditorLayout(rawValue: layout) {
            editorLayout = edLayout
        }
        showMinimap = defaults.object(forKey: Keys.showMinimap) as? Bool ?? true
        showBreadcrumbs = defaults.object(forKey: Keys.showBreadcrumbs) as? Bool ?? true
        showStatusBar = defaults.object(forKey: Keys.showStatusBar) as? Bool ?? true
        showTabBar = defaults.object(forKey: Keys.showTabBar) as? Bool ?? true
    }
    
    func saveState() {
        let defaults = UserDefaults.standard
        
        defaults.set(showPrimarySidebar, forKey: Keys.showPrimarySidebar)
        defaults.set(primarySidebarPosition.rawValue, forKey: Keys.primarySidebarPosition)
        defaults.set(primarySidebarWidth, forKey: Keys.primarySidebarWidth)
        defaults.set(primarySidebarTab.rawValue, forKey: Keys.primarySidebarTab)
        defaults.set(activityBarPosition.rawValue, forKey: Keys.activityBarPosition)
        
        defaults.set(showSecondarySidebar, forKey: Keys.showSecondarySidebar)
        defaults.set(secondarySidebarWidth, forKey: Keys.secondarySidebarWidth)
        defaults.set(secondarySidebarTab.rawValue, forKey: Keys.secondarySidebarTab)
        
        defaults.set(showBottomPanel, forKey: Keys.showBottomPanel)
        defaults.set(bottomPanelPosition.rawValue, forKey: Keys.bottomPanelPosition)
        defaults.set(bottomPanelHeight, forKey: Keys.bottomPanelHeight)
        defaults.set(bottomPanelTab.rawValue, forKey: Keys.bottomPanelTab)
        
        defaults.set(editorLayout.rawValue, forKey: Keys.editorLayout)
        defaults.set(showMinimap, forKey: Keys.showMinimap)
        defaults.set(showBreadcrumbs, forKey: Keys.showBreadcrumbs)
        defaults.set(showStatusBar, forKey: Keys.showStatusBar)
        defaults.set(showTabBar, forKey: Keys.showTabBar)
    }
    
    // MARK: - Panel Actions
    
    func togglePrimarySidebar() {
        withAnimation(DS.Animation.fast) {
            showPrimarySidebar.toggle()
        }
        saveState()
    }
    
    func toggleSecondarySidebar() {
        withAnimation(DS.Animation.fast) {
            showSecondarySidebar.toggle()
        }
        saveState()
    }
    
    func toggleBottomPanel() {
        withAnimation(DS.Animation.fast) {
            showBottomPanel.toggle()
        }
        saveState()
    }
    
    func showTerminal() {
        bottomPanelTab = .terminal
        if !showBottomPanel {
            withAnimation(DS.Animation.fast) {
                showBottomPanel = true
            }
        }
        saveState()
    }
    
    func showProblems() {
        bottomPanelTab = .problems
        if !showBottomPanel {
            withAnimation(DS.Animation.fast) {
                showBottomPanel = true
            }
        }
        saveState()
    }
    
    func toggleMaximizeBottomPanel() {
        withAnimation(DS.Animation.medium) {
            bottomPanelMaximized.toggle()
        }
    }
    
    func setPrimarySidebarTab(_ tab: SidebarTab) {
        if primarySidebarTab == tab && showPrimarySidebar {
            // Toggle off if clicking same tab
            showPrimarySidebar = false
        } else {
            primarySidebarTab = tab
            showPrimarySidebar = true
        }
        saveState()
    }
    
    func setSecondarySidebarTab(_ tab: SecondarySidebarTab) {
        if secondarySidebarTab == tab && showSecondarySidebar {
            showSecondarySidebar = false
        } else {
            secondarySidebarTab = tab
            showSecondarySidebar = true
        }
        saveState()
    }
    
    func setBottomPanelTab(_ tab: BottomPanelTab) {
        if bottomPanelTab == tab && showBottomPanel {
            showBottomPanel = false
        } else {
            bottomPanelTab = tab
            showBottomPanel = true
        }
        saveState()
    }
    
    // MARK: - Editor Layout
    
    func setEditorLayout(_ layout: EditorLayout) {
        withAnimation(DS.Animation.medium) {
            editorLayout = layout
        }
        saveState()
    }
    
    func toggleSplitEditor() {
        withAnimation(DS.Animation.medium) {
            editorLayout = editorLayout == .single ? .splitVertical : .single
        }
        saveState()
    }
    
    // MARK: - Zen Mode
    
    func toggleZenMode() {
        withAnimation(DS.Animation.medium) {
            if zenMode {
                // Restore previous state
                if let state = preZenState {
                    showPrimarySidebar = state.showPrimarySidebar
                    showSecondarySidebar = state.showSecondarySidebar
                    showBottomPanel = state.showBottomPanel
                    showStatusBar = state.showStatusBar
                    showTabBar = state.showTabBar
                }
                zenMode = false
            } else {
                // Save current state and enter zen mode
                preZenState = ZenModeState(
                    showPrimarySidebar: showPrimarySidebar,
                    showSecondarySidebar: showSecondarySidebar,
                    showBottomPanel: showBottomPanel,
                    showStatusBar: showStatusBar,
                    showTabBar: showTabBar
                )
                showPrimarySidebar = false
                showSecondarySidebar = false
                showBottomPanel = false
                showStatusBar = false
                showTabBar = false
                zenMode = true
            }
        }
    }
    
    // MARK: - Reset
    
    func resetToDefaults() {
        showPrimarySidebar = true
        primarySidebarPosition = .left
        primarySidebarWidth = 260
        primarySidebarTab = .explorer
        activityBarPosition = .side
        
        showSecondarySidebar = true
        secondarySidebarWidth = 380
        secondarySidebarTab = .chat
        
        showBottomPanel = false
        bottomPanelPosition = .bottom
        bottomPanelHeight = 200
        bottomPanelTab = .terminal
        
        editorLayout = .single
        showMinimap = true
        showBreadcrumbs = true
        showStatusBar = true
        showTabBar = true
        
        zenMode = false
        
        saveState()
    }
}

// MARK: - Zen Mode State

private struct ZenModeState {
    let showPrimarySidebar: Bool
    let showSecondarySidebar: Bool
    let showBottomPanel: Bool
    let showStatusBar: Bool
    let showTabBar: Bool
}

// MARK: - Tab Bar Style

enum TabBarStyle: String, CaseIterable, Codable {
    case standard   // Normal tabs
    case compact    // Smaller, icon-only tabs
    case wrapped    // Multi-line if needed
}

// MARK: - Helper Extension

private extension Double {
    func nonZeroOr(_ defaultValue: Double) -> Double {
        self != 0 ? self : defaultValue
    }
}

// MARK: - Panel Resizer View

struct PanelResizer: View {
    let axis: Axis
    @Binding var size: CGFloat
    let minSize: CGFloat
    let maxSize: CGFloat
    var onResizeEnd: (() -> Void)?
    
    @State private var isDragging = false
    
    var body: some View {
        Rectangle()
            .fill(isDragging ? DS.Colors.accent.opacity(0.5) : Color.clear)
            .frame(
                width: axis == .vertical ? 6 : nil,
                height: axis == .horizontal ? 6 : nil
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        isDragging = true
                        let delta = axis == .vertical ? value.translation.width : value.translation.height
                        let newSize = size + delta
                        size = min(max(newSize, minSize), maxSize)
                    }
                    .onEnded { _ in
                        isDragging = false
                        onResizeEnd?()
                    }
            )
    }
}

// MARK: - Activity Bar View

struct ActivityBarView: View {
    @Environment(AppState.self) private var appState
    let panels: PanelState
    
    var body: some View {
        Group {
            if panels.activityBarPosition == .side {
                VStack(spacing: 0) {
                    activityButtons
                    Spacer()
                    bottomButtons
                }
                .frame(width: 48)
                .background(DS.Colors.surface)
            } else if panels.activityBarPosition == .top {
                HStack(spacing: 0) {
                    activityButtons
                    Spacer()
                    bottomButtons
                }
                .frame(height: 36)
                .background(DS.Colors.surface)
            }
        }
    }
    
    @ViewBuilder
    private var activityButtons: some View {
        ForEach(SidebarTab.allCases) { tab in
            ActivityBarButton(
                icon: tab.icon,
                isSelected: panels.primarySidebarTab == tab && panels.showPrimarySidebar,
                badge: badgeCount(for: tab)
            ) {
                panels.setPrimarySidebarTab(tab)
            }
        }
    }
    
    @ViewBuilder
    private var bottomButtons: some View {
        ActivityBarButton(
            icon: "gearshape",
            isSelected: false
        ) {
            appState.showSettings = true
        }
    }
    
    private func badgeCount(for tab: SidebarTab) -> Int? {
        switch tab {
        case .sourceControl:
            return appState.gitService.status?.totalChanges
        default:
            return nil
        }
    }
}

struct ActivityBarButton: View {
    let icon: String
    let isSelected: Bool
    var badge: Int? = nil
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.secondaryText)
                    .frame(width: 48, height: 48)
                    .background(
                        isSelected
                            ? DS.Colors.accent.opacity(0.15)
                            : (isHovered ? DS.Colors.surface.opacity(0.8) : Color.clear)
                    )
                    .overlay(alignment: .leading) {
                        if isSelected {
                            Rectangle()
                                .fill(DS.Colors.accent)
                                .frame(width: 2)
                        }
                    }
                
                if let count = badge, count > 0 {
                    Text("\(min(count, 99))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(DS.Colors.accent)
                        .clipShape(Capsule())
                        .offset(x: -6, y: 6)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Bottom Panel Tab Bar

struct BottomPanelTabBar: View {
    @Binding var selectedTab: BottomPanelTab
    let isMaximized: Bool
    let onMaximize: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Tab buttons
            ForEach(BottomPanelTab.allCases) { tab in
                BottomPanelTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    selectedTab = tab
                }
            }
            
            Spacer()
            
            // Panel actions
            HStack(spacing: DS.Spacing.xs) {
                DSIconButton(
                    icon: isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                    size: 12
                ) {
                    onMaximize()
                }
                .help(isMaximized ? "Restore Panel" : "Maximize Panel")
                
                DSIconButton(icon: "xmark", size: 12) {
                    onClose()
                }
                .help("Close Panel")
            }
            .padding(.horizontal, DS.Spacing.sm)
        }
        .frame(height: 32)
        .background(DS.Colors.surface)
    }
}

struct BottomPanelTabButton: View {
    let tab: BottomPanelTab
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: tab.icon)
                    .font(.caption)
                Text(tab.rawValue)
                    .font(DS.Typography.caption)
            }
            .foregroundStyle(isSelected ? DS.Colors.text : DS.Colors.secondaryText)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                isSelected
                    ? DS.Colors.background
                    : (isHovered ? DS.Colors.surface.opacity(0.8) : Color.clear)
            )
            .overlay(alignment: .bottom) {
                if isSelected {
                    Rectangle()
                        .fill(DS.Colors.accent)
                        .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Problems View (uses ProblemsPanel types)
// ProblemsView is defined in ProblemsPanel.swift

// MARK: - Output View

struct OutputView: View {
    @State private var outputText: String = ""
    @State private var selectedChannel: String = "OllamaBot"
    
    private let channels = ["OllamaBot", "Git", "Extensions", "Tasks"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Channel selector
            HStack {
                Picker("Output", selection: $selectedChannel) {
                    ForEach(channels, id: \.self) { channel in
                        Text(channel).tag(channel)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                
                Spacer()
                
                DSIconButton(icon: "trash", size: 12) {
                    outputText = ""
                }
                .help("Clear Output")
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(DS.Colors.surface)
            
            DSDivider()
            
            // Output content
            ScrollView {
                Text(outputText.isEmpty ? "No output" : outputText)
                    .font(DS.Typography.mono(11))
                    .foregroundStyle(outputText.isEmpty ? DS.Colors.tertiaryText : DS.Colors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DS.Spacing.sm)
            }
            .background(DS.Colors.codeBackground)
        }
    }
}
