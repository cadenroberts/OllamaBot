import SwiftUI

// MARK: - Explore View
// UI for the Explore Mode - autonomous project improvement

struct ExploreView: View {
    @Environment(AppState.self) private var appState
    @State private var executor = ExploreAgentExecutor(
        ollamaService: OllamaService(),
        fileSystemService: FileSystemService(),
        contextManager: ContextManager()
    )
    @State private var goalInput = ""
    @State private var selectedTab: ExploreTab = .activity
    @State private var showStyleMenu = false
    @State private var activityScrollTrigger = 0
    
    enum ExploreTab: String, CaseIterable {
        case activity = "Activity"
        case expansions = "Expansions"
        case docs = "Documentation"
        
        var icon: String {
            switch self {
            case .activity: return "bolt.fill"
            case .expansions: return "arrow.triangle.branch"
            case .docs: return "doc.text.fill"
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
            tabContent
            
            DSDivider()
            
            // Control bar
            controlBar
        }
        .background(DS.Colors.background)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: DS.Spacing.md) {
            // Animated logo
            ZStack {
                Circle()
                    .strokeBorder(
                        DS.Colors.exploreGradient,
                        lineWidth: 3
                    )
                    .frame(width: 36, height: 36)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DS.Colors.exploreGradient)
                    .symbolEffect(.pulse, isActive: executor.isRunning)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DS.Spacing.sm) {
                    Text("Explore Mode")
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.text)
                    
                    if executor.isRunning {
                        DSBadge(text: "ACTIVE", color: DS.Colors.success, size: .sm)
                    } else if executor.isPaused {
                        DSBadge(text: "PAUSED", color: DS.Colors.warning, size: .sm)
                    }
                }
                
                if executor.isRunning {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: executor.currentPhase.icon)
                            .font(.caption)
                        Text(executor.currentPhase.rawValue)
                            .font(DS.Typography.caption)
                    }
                    .foregroundStyle(DS.Colors.secondaryText)
                } else {
                    Text("Autonomous project improvement")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            }
            
            Spacer()
            
            // Stats
            if executor.isRunning || executor.totalChanges > 0 {
                HStack(spacing: DS.Spacing.lg) {
                    statView(value: "\(executor.cycleCount)", label: "Cycles")
                    statView(value: "\(executor.totalChanges)", label: "Changes")
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.secondaryBackground)
    }
    
    private func statView(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DS.Typography.headline.monospacedDigit())
                .foregroundStyle(DS.Colors.accent)
            Text(label)
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.tertiaryText)
        }
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(ExploreTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(DS.Animation.fast) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: tab.icon)
                            .font(.caption)
                        Text(tab.rawValue)
                            .font(DS.Typography.caption.weight(.medium))
                    }
                    .foregroundStyle(selectedTab == tab ? DS.Colors.text : DS.Colors.secondaryText)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(selectedTab == tab ? DS.Colors.accent.opacity(0.2) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Style selector
            Button {
                showStyleMenu.toggle()
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Text(executor.explorationStyle.rawValue)
                        .font(DS.Typography.caption)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(DS.Colors.accent)
            }
            .disabled(executor.isRunning)
            .buttonStyle(.plain)
            .popover(isPresented: $showStyleMenu, arrowEdge: .trailing) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    ForEach(ExploreAgentExecutor.ExplorationStyle.allCases, id: \.self) { style in
                        ExploreStyleRow(
                            title: style.rawValue,
                            isSelected: executor.explorationStyle == style
                        ) {
                            executor.explorationStyle = style
                            showStyleMenu = false
                        }
                    }
                }
                .padding(DS.Spacing.sm)
                .background(DS.Colors.surface)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.surface)
    }
    
    // MARK: - Tab Content
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .activity:
            activityContent
        case .expansions:
            expansionsContent
        case .docs:
            docsContent
        }
    }
    
    // MARK: - Activity Tab
    
    private var activityContent: some View {
        DSAutoScrollView(scrollTrigger: $activityScrollTrigger) {
            if executor.steps.isEmpty && !executor.isRunning {
                emptyState
            } else {
                LazyVStack(alignment: .leading, spacing: DS.Spacing.md) {
                    // Goal display
                    if !executor.originalGoal.isEmpty {
                        goalCard
                    }
                    
                    // Steps
                    ForEach(executor.steps) { step in
                        ExploreStepCard(step: step)
                    }
                }
                .padding(DS.Spacing.md)
            }
        }
        .onChange(of: executor.steps.count) { _, _ in
            activityScrollTrigger += 1
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: DS.Spacing.xl) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(DS.Colors.secondaryText.opacity(0.4))
            
            VStack(spacing: DS.Spacing.sm) {
                Text("Explore Mode")
                    .font(DS.Typography.title)
                
                Text("Autonomous AI that continuously improves your project")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            // Phases
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Exploration Phases")
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(DS.Colors.secondaryText)
                
                ForEach(ExploreAgentExecutor.ExplorePhase.allCases, id: \.self) { phase in
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: phase.icon)
                            .foregroundStyle(DS.Colors.accent)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(phase.rawValue)
                                .font(DS.Typography.caption.weight(.medium))
                            Text(phase.description)
                                .font(DS.Typography.caption2)
                                .foregroundStyle(DS.Colors.tertiaryText)
                        }
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxl)
    }
    
    private var goalCard: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "target")
                .font(.title3)
                .foregroundStyle(DS.Colors.accent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Ground Truth Goal")
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(DS.Colors.secondaryText)
                
                Text(executor.originalGoal)
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.text)
            }
            
            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    // MARK: - Expansions Tab
    
    private var expansionsContent: some View {
        DSScrollView {
            if executor.expansionTree.isEmpty {
                VStack(spacing: DS.Spacing.lg) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.largeTitle)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    
                    Text("No expansions yet")
                        .font(DS.Typography.callout)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.xxl)
            } else {
                LazyVStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    ForEach(executor.expansionTree) { node in
                        ExpansionNodeView(node: node)
                    }
                }
                .padding(DS.Spacing.md)
            }
        }
    }
    
    // MARK: - Docs Tab
    
    private var docsContent: some View {
        DSScrollView {
            if executor.generatedDocs.isEmpty {
                VStack(spacing: DS.Spacing.lg) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    
                    Text("Documentation will be generated automatically")
                        .font(DS.Typography.callout)
                        .foregroundStyle(DS.Colors.secondaryText)
                    
                    Text("Every \(executor.changesBeforeDocumentation) changes")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.tertiaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.xxl)
            } else {
                LazyVStack(spacing: DS.Spacing.md) {
                    ForEach(executor.generatedDocs) { doc in
                        GeneratedDocCard(doc: doc)
                    }
                }
                .padding(DS.Spacing.md)
            }
        }
    }
    
    // MARK: - Control Bar
    
    private var controlBar: some View {
        HStack(spacing: DS.Spacing.md) {
            if executor.isRunning {
                // Running controls
                if executor.isPaused {
                    DSButton("Resume", icon: "play.fill", style: .primary) {
                        executor.resume()
                    }
                } else {
                    DSButton("Pause", icon: "pause.fill", style: .secondary) {
                        executor.pause()
                    }
                }
                
                DSButton("Stop", icon: "stop.fill", style: .destructive) {
                    executor.stop()
                }
                
                Spacer()
                
                // Redirect focus
                HStack(spacing: DS.Spacing.sm) {
                    Text("Focus:")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    
                    Text(executor.currentFocus.prefix(30) + (executor.currentFocus.count > 30 ? "..." : ""))
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            } else {
                // Input for new exploration
                DSTextField(
                    placeholder: "Enter a goal... (e.g., 'build a sandwich app')",
                    text: $goalInput,
                    icon: "sparkles"
                ) {
                    startExploration()
                }
                
                DSButton("Explore", icon: "sparkles", style: .accent) {
                    startExploration()
                }
                .disabled(goalInput.trimmingCharacters(in: .whitespaces).isEmpty)
                
                if !executor.steps.isEmpty {
                    DSIconButton(icon: "trash") {
                        executor.steps.removeAll()
                        executor.expansionTree.removeAll()
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.secondaryBackground)
    }
    
    private func startExploration() {
        let goal = goalInput.trimmingCharacters(in: .whitespaces)
        guard !goal.isEmpty else { return }
        
        executor.start(goal: goal, workingDirectory: appState.rootFolder)
        goalInput = ""
    }
}

// MARK: - Explore Step Card

struct ExploreStepCard: View {
    let step: ExploreAgentExecutor.ExploreStep
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: step.phase.icon)
                    .foregroundStyle(DS.Colors.accent)
                    .frame(width: 18)
                
                Text(step.phase.rawValue.uppercased())
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(DS.Colors.accent)
                
                if step.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(DS.Colors.success)
                }
                
                Spacer()
                
                Text(step.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
                
                if !step.subSteps.isEmpty {
                    DSIconButton(icon: isExpanded ? "chevron.up" : "chevron.down", size: 14) {
                        withAnimation(DS.Animation.fast) { isExpanded.toggle() }
                    }
                }
            }
            
            // Content
            Text(step.content)
                .font(DS.Typography.callout)
                .foregroundStyle(DS.Colors.secondaryText)
            
            // Sub-steps (expandable)
            if isExpanded {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    ForEach(step.subSteps) { subStep in
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: subStep.success ? "checkmark.circle" : "xmark.circle")
                                .font(.caption2)
                                .foregroundStyle(subStep.success ? DS.Colors.success : DS.Colors.error)
                            
                            Text(subStep.description)
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.secondaryText)
                        }
                    }
                }
                .padding(.leading, DS.Spacing.lg)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

// MARK: - Expansion Node View

struct ExpansionNodeView: View {
    let node: ExploreAgentExecutor.ExpansionNode
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Depth indicator
            ForEach(0..<node.depth, id: \.self) { _ in
                Rectangle()
                    .fill(DS.Colors.border)
                    .frame(width: 2)
            }
            
            // Node content
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: node.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(node.isComplete ? DS.Colors.success : DS.Colors.tertiaryText)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.description)
                        .font(DS.Typography.callout)
                    
                    if !node.filesAffected.isEmpty {
                        Text(node.filesAffected.joined(separator: ", "))
                            .font(DS.Typography.caption2)
                            .foregroundStyle(DS.Colors.tertiaryText)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}

private struct ExploreStyleRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.text)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(DS.Colors.accent)
                        .font(.caption)
                }
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

// MARK: - Generated Doc Card

struct GeneratedDocCard: View {
    let doc: ExploreAgentExecutor.GeneratedDoc
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(DS.Colors.accent)
                
                Text(doc.title)
                    .font(DS.Typography.callout.weight(.medium))
                
                Spacer()
                
                Text(doc.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
                
                DSIconButton(icon: isExpanded ? "chevron.up" : "chevron.down", size: 14) {
                    withAnimation(DS.Animation.fast) { isExpanded.toggle() }
                }
            }
            
            if isExpanded {
                // Content
                Text(doc.content)
                    .font(DS.Typography.mono(11))
                    .foregroundStyle(DS.Colors.secondaryText)
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.codeBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                
                // Related files
                if !doc.relatedFiles.isEmpty {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("Files:")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.tertiaryText)
                        
                        Text(doc.relatedFiles.joined(separator: ", "))
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

// Preview removed - use Xcode previews instead
