import SwiftUI

// MARK: - Cycle Agent View
// Visual interface for multi-agent orchestration
// Uses shared CycleAgentManager from AppState (SINGLE SOURCE OF TRUTH)

struct CycleAgentView: View {
    @Environment(AppState.self) private var appState
    @State private var taskInput: String = ""
    @State private var usePipelineMode: Bool = false  // false = Auto, true = Pipeline
    @State private var isExecuting: Bool = false
    @State private var results: [CycleAgentManager.TaskResult] = []
    @State private var showStatistics: Bool = false
    @State private var selectedAgentIds: Set<String> = []  // Empty = all agents
    @State private var showTemplateMenu: Bool = false
    
    // Use shared instance from AppState
    private var cycleManager: CycleAgentManager {
        appState.cycleAgentManager
    }
    
    var body: some View {
        // No internal header - tab bar shows "Agents", matches other panes like Composer
        GeometryReader { geometry in
            let taskPanelWidth = PanelState.minSecondarySidebarWidth * 0.5
            let agentsPanelWidth = max(geometry.size.width - taskPanelWidth, taskPanelWidth)
            HStack(spacing: 0) {
                // Left: Agent configuration + Task input + Strategy
                // Agents panel stretches, task panel stays fixed
                configurationPanel
                    .frame(width: agentsPanelWidth)
                
                // Vertical divider
                Rectangle()
                    .fill(DS.Colors.border)
                    .frame(width: 1)
                
                // Right: Multi-Agent Execution visual - expands to fill remaining space
                executionVisualPanel
                    .frame(width: taskPanelWidth)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .background(DS.Colors.secondaryBackground)
    }
    
    // MARK: - Configuration Panel (Left Side)
    
    private var configurationPanel: some View {
        VStack(spacing: 0) {
            // 1. Agents Section (multi-select)
            agentsSection
            
            DSDivider()
            
            // 2. Task Input (chat box)
            taskInputSection
            
            DSDivider()
            
            // 3. Execution Strategy Toggle
            strategyToggle
        }
        .background(DS.Colors.secondaryBackground)
    }
    
    private var agentsSection: some View {
        VStack(spacing: 0) {
            // Header with RAM status and selection info
            HStack(spacing: DS.Spacing.xs) {
                Text("AGENTS")
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(DS.Colors.secondaryText)
                
                // RAM indicator
                let stats = cycleManager.getStatistics()
                HStack(spacing: 2) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 8))
                    Text("\(stats.availableRAM)GB")
                        .font(DS.Typography.mono(8))
                }
                .foregroundStyle(stats.canRunParallel ? DS.Colors.success : DS.Colors.warning)
                
                Spacer()
                
                // Selection indicator
                Text(selectedAgentIds.isEmpty ? "All" : "\(selectedAgentIds.count)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            
            DSScrollView {
                VStack(spacing: DS.Spacing.xs) {
                    ForEach(cycleManager.agents) { agent in
                        SelectableAgentCard(
                            agent: agent,
                            isSelected: selectedAgentIds.contains(agent.id),
                            isWarm: cycleManager.getStatistics().warmAgent == agent.role.rawValue
                        ) {
                            toggleAgentSelection(agent.id)
                        }
                    }
                }
                .padding(DS.Spacing.sm)
            }
            .frame(maxHeight: 200)
            
            // Helper text
            Text(selectedAgentIds.isEmpty 
                 ? "Tap to select specific agents, or leave empty to use all"
                 : usePipelineMode 
                    ? "Selected agents will run sequentially in order"
                    : "Auto mode will intelligently use selected agents")
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.tertiaryText)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.sm)
        }
    }
    
    private func toggleAgentSelection(_ agentId: String) {
        if selectedAgentIds.contains(agentId) {
            selectedAgentIds.remove(agentId)
        } else {
            selectedAgentIds.insert(agentId)
        }
    }
    
    private var taskInputSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack {
                Text("Task")
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(DS.Colors.secondaryText)
                
                Spacer()
                
                // Quick task templates
                DSIconButton(icon: "text.badge.plus", size: 16) {
                    withAnimation(DS.Animation.fast) {
                        showTemplateMenu.toggle()
                    }
                }
            }
            
            if showTemplateMenu {
                VStack(spacing: 0) {
                    templateButton(title: "Code Review") {
                        taskInput = "Review this codebase for potential bugs, security issues, and performance improvements."
                    }
                    templateButton(title: "Research Task") {
                        taskInput = "Research best practices for [topic] and provide a comprehensive summary."
                    }
                    templateButton(title: "Multi-step Analysis") {
                        taskInput = "Analyze this project: 1) Review code, 2) Research alternatives, 3) Suggest improvements."
                    }
                }
                .background(DS.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(DS.Colors.border, lineWidth: 1)
                )
            }
            
            TextEditor(text: $taskInput)
                .font(DS.Typography.callout)
                .foregroundStyle(DS.Colors.text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60, maxHeight: 120)
                .padding(DS.Spacing.xs)
                .background(DS.Colors.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            
            HStack {
                // File context indicator
                if let file = appState.selectedFile {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "doc.fill")
                            .font(.caption2)
                        Text(file.name)
                            .font(DS.Typography.caption)
                    }
                    .foregroundStyle(DS.Colors.secondaryText)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(DS.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                }
                
                Spacer()
                
                // Send button
                Button {
                    Task { await executeCycle() }
                } label: {
                    Image(systemName: isExecuting ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle((!taskInput.isEmpty && !isExecuting) ? DS.Colors.accent : DS.Colors.secondaryText)
                }
                .buttonStyle(.plain)
                .disabled(taskInput.isEmpty && !isExecuting)
            }
        }
        .padding(DS.Spacing.sm)
    }
    
    private var strategyToggle: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Execution Mode")
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(DS.Colors.secondaryText)
            
            // Simple toggle between Auto and Pipeline
            HStack(spacing: DS.Spacing.sm) {
                // Auto button
                Button {
                    usePipelineMode = false
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                        Text("Auto")
                            .font(DS.Typography.caption)
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(!usePipelineMode ? DS.Colors.accent.opacity(0.2) : DS.Colors.tertiaryBackground)
                    .foregroundStyle(!usePipelineMode ? DS.Colors.accent : DS.Colors.secondaryText)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .stroke(!usePipelineMode ? DS.Colors.accent : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // Pipeline button
                Button {
                    usePipelineMode = true
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.right.arrow.right.circle")
                            .font(.caption)
                        Text("Pipeline")
                            .font(DS.Typography.caption)
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(usePipelineMode ? DS.Colors.accent.opacity(0.2) : DS.Colors.tertiaryBackground)
                    .foregroundStyle(usePipelineMode ? DS.Colors.accent : DS.Colors.secondaryText)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .stroke(usePipelineMode ? DS.Colors.accent : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            
            // Description
            Text(usePipelineMode 
                 ? "Tasks flow through agents sequentially, each building on previous results"
                 : "Automatically chooses the optimal execution strategy")
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.tertiaryText)
        }
        .padding(DS.Spacing.sm)
    }
    
    // MARK: - Execution Visual Panel (Right Side)
    
    private var executionVisualPanel: some View {
        // Single solid background - no headers or dividers
        DSScrollView {
            VStack(spacing: 0) {
                if isExecuting {
                    executionProgress
                } else if !results.isEmpty {
                    resultsSection
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.secondaryBackground)
    }
    
    private var executionProgress: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Animated agent visualization with selected agents - at top
            CycleVisualization(
                agents: getActiveAgents(),
                currentAgent: cycleManager.currentTask?.assignedAgent,
                progress: cycleManager.progress
            )
            .padding(.top, DS.Spacing.xl)
            
            // Status
            VStack(spacing: DS.Spacing.sm) {
                Text(cycleManager.statusMessage.isEmpty ? "Executing..." : cycleManager.statusMessage)
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.text)
                
                DSProgressBar(progress: cycleManager.progress, showPercentage: true, color: DS.Colors.accent, height: 6)
                    .frame(maxWidth: 300)
                
                // Show mode
                Text(usePipelineMode ? "Pipeline Mode" : "Auto Mode")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            
            Spacer() // Push content to top
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.md)
    }

    private func templateButton(title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            withAnimation(DS.Animation.fast) {
                showTemplateMenu = false
            }
        } label: {
            HStack {
                Text(title)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.text)
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
        }
        .buttonStyle(.plain)
    }
    
    private var resultsSection: some View {
        DSScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Summary header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Results")
                            .font(DS.Typography.headline)
                        Text(usePipelineMode ? "Pipeline execution" : "Auto execution")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                    
                    Spacer()
                    
                    // Clear results button
                    DSIconButton(icon: "xmark.circle", size: 14) {
                        results = []
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.md)
                
                // Result cards
                ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                    ResultCard(index: index, result: result)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Visual showing selected agents or all agents - at top with padding
            CycleVisualization(
                agents: getActiveAgents(),
                currentAgent: nil,
                progress: 0
            )
            .opacity(0.6)
            .padding(.top, DS.Spacing.xl)
            
            Text("Multi-Agent Execution")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.secondaryText)
            
            // Dynamic description based on selection
            Group {
                if selectedAgentIds.isEmpty {
                    Text("All agents available • Enter a task to begin")
                } else {
                    let count = selectedAgentIds.count
                    Text("\(count) agent\(count == 1 ? "" : "s") selected • \(usePipelineMode ? "Sequential" : "Auto") mode")
                }
            }
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Colors.tertiaryText)
            .multilineTextAlignment(.center)
            
            // Sent tasks will appear here
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.caption)
                Text("Tasks will appear here")
                    .font(DS.Typography.caption2)
            }
            .foregroundStyle(DS.Colors.tertiaryText)
            .padding(.top, DS.Spacing.md)
            
            Spacer() // Push content to top, fill remaining space
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.md)
    }
    
    // MARK: - Helper Methods
    
    /// Get agents to use based on selection
    private func getActiveAgents() -> [CycleAgentManager.AgentDefinition] {
        if selectedAgentIds.isEmpty {
            return cycleManager.agents
        } else {
            return cycleManager.agents.filter { selectedAgentIds.contains($0.id) }
        }
    }
    
    // MARK: - Statistics Popover
    
    private var statisticsPopover: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Cycle Statistics")
                .font(DS.Typography.headline)
            
            let stats = cycleManager.getStatistics()
            Grid(alignment: .leading, horizontalSpacing: DS.Spacing.lg, verticalSpacing: DS.Spacing.sm) {
                    GridRow {
                        Text("Available RAM")
                            .foregroundStyle(DS.Colors.secondaryText)
                        Text("\(stats.availableRAM)GB")
                            .font(DS.Typography.mono(12))
                    }
                    GridRow {
                        Text("Parallel Capable")
                            .foregroundStyle(DS.Colors.secondaryText)
                        Text(stats.canRunParallel ? "Yes" : "No (need 64GB+)")
                            .foregroundStyle(stats.canRunParallel ? DS.Colors.success : DS.Colors.warning)
                    }
                    GridRow {
                        Text("Model Switches")
                            .foregroundStyle(DS.Colors.secondaryText)
                        Text("\(stats.modelSwitchCount)")
                            .font(DS.Typography.mono(12))
                    }
                    GridRow {
                        Text("Switch Time (avg)")
                            .foregroundStyle(DS.Colors.secondaryText)
                        Text(String(format: "%.1fs", stats.averageSwitchTime))
                            .font(DS.Typography.mono(12))
                    }
                GridRow {
                    Text("Warm Model")
                        .foregroundStyle(DS.Colors.secondaryText)
                    Text(stats.warmAgent ?? "None")
                        .font(DS.Typography.mono(12))
                }
            }
            .font(DS.Typography.caption)
        }
        .padding(DS.Spacing.md)
        .frame(width: 250)
    }
    
    // MARK: - Execution
    
    private func executeCycle() async {
        isExecuting = true
        results = []
        
        // Build context from current file
        var context = CycleAgentManager.TaskContext()
        if let file = appState.selectedFile,
           let content = appState.fileSystemService.readFile(at: file.url) {
            context.files[file.name] = content
        }
        
        let manager = cycleManager
        context.workingDirectory = appState.rootFolder
        
        do {
            // If specific agents selected, use custom execution
            if !selectedAgentIds.isEmpty {
                let activeAgents = getActiveAgents()
                
                if usePipelineMode {
                    // Pipeline: run through selected agents sequentially
                    var allResults: [CycleAgentManager.TaskResult] = []
                    var previousOutput = ""
                    
                    for (index, agent) in activeAgents.enumerated() {
                        manager.statusMessage = "Running \(agent.role.rawValue) (\(index + 1)/\(activeAgents.count))..."
                        manager.progress = Double(index) / Double(activeAgents.count)
                        
                        let taskWithContext = previousOutput.isEmpty 
                            ? taskInput 
                            : "\(taskInput)\n\nPrevious result:\n\(previousOutput)"
                        
                        let result = try await manager.planAndExecute(task: taskWithContext, context: context)
                        
                        let taskResult = CycleAgentManager.TaskResult(
                            output: result,
                            agentId: agent.id,
                            executionTime: 0,
                            modelSwitchTime: 0,
                            tokensUsed: result.count / 4
                        )
                        allResults.append(taskResult)
                        previousOutput = result
                    }
                    
                    results = allResults
                } else {
                    // Auto mode with selected agents - let manager decide best approach
                    let result = try await manager.planAndExecute(task: taskInput, context: context)
                    
                    results = [CycleAgentManager.TaskResult(
                        output: result,
                        agentId: "auto",
                        executionTime: 0,
                        modelSwitchTime: 0,
                        tokensUsed: result.count / 4
                    )]
                }
            } else {
                // No agents selected - use all agents with plan-and-execute
                let result = try await manager.planAndExecute(task: taskInput, context: context)
                
                results = [CycleAgentManager.TaskResult(
                    output: result,
                    agentId: "synthesis",
                    executionTime: 0,
                    modelSwitchTime: 0,
                    tokensUsed: result.count / 4
                )]
            }
        } catch {
            appState.showError("Cycle execution failed: \(error.localizedDescription)")
        }
        
        isExecuting = false
        taskInput = ""  // Clear input after execution
    }
}

// MARK: - Selectable Agent Card (for multi-select)

struct SelectableAgentCard: View {
    let agent: CycleAgentManager.AgentDefinition
    let isSelected: Bool
    let isWarm: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.sm) {
                // Selection indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? agentColor : agentColor.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: agentIcon)
                            .font(.system(size: 14))
                            .foregroundStyle(agentColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(agent.role.rawValue)
                            .font(DS.Typography.caption.weight(.medium))
                            .foregroundStyle(DS.Colors.text)
                        
                        if isWarm {
                            Circle()
                                .fill(DS.Colors.success)
                                .frame(width: 5, height: 5)
                        }
                    }
                    
                    Text(agent.model.displayName)
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                
                Spacer()
            }
            .padding(DS.Spacing.xs)
            .background(isSelected ? agentColor.opacity(0.15) : DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(isSelected ? agentColor : DS.Colors.border.opacity(0.5), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var agentColor: Color {
        switch agent.role {
        case .orchestrator: return DS.Colors.orchestrator
        case .coder: return DS.Colors.coder
        case .researcher: return DS.Colors.researcher
        case .vision: return DS.Colors.vision
        }
    }
    
    private var agentIcon: String {
        switch agent.role {
        case .orchestrator: return "brain"
        case .coder: return "chevron.left.forwardslash.chevron.right"
        case .researcher: return "magnifyingglass"
        case .vision: return "eye"
        }
    }
}

// MARK: - Agent Card (display only, used in visualization)

struct AgentCard: View {
    let agent: CycleAgentManager.AgentDefinition
    let isWarm: Bool
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Agent icon with role color
            ZStack {
                Circle()
                    .fill(agentColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: agentIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(agentColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(agent.role.rawValue)
                        .font(DS.Typography.callout.weight(.medium))
                    
                    if isWarm {
                        Circle()
                            .fill(DS.Colors.success)
                            .frame(width: 6, height: 6)
                    }
                }
                
                Text(agent.model.displayName)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            
            Spacer()
            
            // Capabilities
            HStack(spacing: 2) {
                ForEach(Array(agent.capabilities.prefix(3)), id: \.self) { cap in
                    Image(systemName: capabilityIcon(cap))
                        .font(.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                }
            }
        }
        .padding(DS.Spacing.sm)
        .background(isWarm ? agentColor.opacity(0.1) : DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .stroke(isWarm ? agentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    private var agentColor: Color {
        switch agent.role {
        case .orchestrator: return DS.Colors.orchestrator
        case .coder: return DS.Colors.coder
        case .researcher: return DS.Colors.researcher
        case .vision: return DS.Colors.vision
        }
    }
    
    private var agentIcon: String {
        switch agent.role {
        case .orchestrator: return "brain"
        case .coder: return "chevron.left.forwardslash.chevron.right"
        case .researcher: return "magnifyingglass"
        case .vision: return "eye"
        }
    }
    
    private func capabilityIcon(_ cap: CycleAgentManager.TaskCapability) -> String {
        switch cap {
        case .codeGeneration: return "curlybraces"
        case .codeReview: return "checkmark.circle"
        case .debugging: return "ant"
        case .research: return "book"
        case .documentation: return "doc.text"
        case .imageAnalysis: return "photo"
        case .planning: return "list.bullet"
        case .synthesis: return "arrow.triangle.merge"
        }
    }
}

// MARK: - Cycle Visualization

struct CycleVisualization: View {
    let agents: [CycleAgentManager.AgentDefinition]
    let currentAgent: CycleAgentManager.AgentDefinition?
    let progress: Double
    
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Connecting lines
            ForEach(0..<agents.count, id: \.self) { i in
                let startAngle = Double(i) * (360.0 / Double(agents.count))
                let endAngle = Double((i + 1) % agents.count) * (360.0 / Double(agents.count))
                
                Path { path in
                    let center = CGPoint(x: 100, y: 100)
                    let radius: CGFloat = 60
                    let start = pointOnCircle(center: center, radius: radius, angle: startAngle)
                    let end = pointOnCircle(center: center, radius: radius, angle: endAngle)
                    path.move(to: start)
                    path.addLine(to: end)
                }
                .stroke(DS.Colors.border, lineWidth: 1)
            }
            
            // Agent nodes
            ForEach(Array(agents.enumerated()), id: \.offset) { index, agent in
                let angle = Double(index) * (360.0 / Double(agents.count))
                let isActive = agent.id == currentAgent?.id
                
                AgentNode(agent: agent, isActive: isActive)
                    .offset(
                        x: 60 * cos((angle - 90) * .pi / 180),
                        y: 60 * sin((angle - 90) * .pi / 180)
                    )
            }
            
            // Center progress indicator
            ZStack {
                Circle()
                    .stroke(DS.Colors.border, lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(DS.Colors.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(progress * 100))%")
                    .font(DS.Typography.mono(10))
            }
        }
        .frame(width: 200, height: 200)
    }
    
    private func pointOnCircle(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos((angle - 90) * .pi / 180),
            y: center.y + radius * sin((angle - 90) * .pi / 180)
        )
    }
}

struct AgentNode: View {
    let agent: CycleAgentManager.AgentDefinition
    let isActive: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isActive ? agentColor : DS.Colors.surface)
                .frame(width: 40, height: 40)
            
            Circle()
                .stroke(agentColor, lineWidth: isActive ? 3 : 1)
                .frame(width: 40, height: 40)
            
            Image(systemName: agentIcon)
                .font(.system(size: 16))
                .foregroundStyle(isActive ? .white : agentColor)
        }
        .scaleEffect(isActive ? 1.2 : 1.0)
        .animation(.spring(response: 0.3), value: isActive)
    }
    
    private var agentColor: Color {
        switch agent.role {
        case .orchestrator: return DS.Colors.orchestrator
        case .coder: return DS.Colors.coder
        case .researcher: return DS.Colors.researcher
        case .vision: return DS.Colors.vision
        }
    }
    
    private var agentIcon: String {
        switch agent.role {
        case .orchestrator: return "brain"
        case .coder: return "chevron.left.forwardslash.chevron.right"
        case .researcher: return "magnifyingglass"
        case .vision: return "eye"
        }
    }
}

// MARK: - Result Card

struct ResultCard: View {
    let index: Int
    let result: CycleAgentManager.TaskResult
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            HStack {
                Label("Task \(index + 1)", systemImage: "checkmark.circle.fill")
                    .font(DS.Typography.callout.weight(.medium))
                    .foregroundStyle(DS.Colors.success)
                
                Spacer()
                
                HStack(spacing: DS.Spacing.sm) {
                    Text(result.agentId.capitalized)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                    
                    Text(String(format: "%.1fs", result.executionTime))
                        .font(DS.Typography.mono(10))
                        .foregroundStyle(DS.Colors.tertiaryText)
                }
                
                DSIconButton(icon: isExpanded ? "chevron.up" : "chevron.down", size: 12) {
                    withAnimation(DS.Animation.fast) {
                        isExpanded.toggle()
                    }
                }
            }
            
            // Content
            if isExpanded {
                Text(result.output)
                    .font(DS.Typography.mono(11))
                    .foregroundStyle(DS.Colors.text)
                    .textSelection(.enabled)
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.codeBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            } else {
                Text(result.output.prefix(200) + (result.output.count > 200 ? "..." : ""))
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .lineLimit(3)
            }
        }
        .padding(DS.Spacing.sm)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .padding(.horizontal, DS.Spacing.md)
    }
}

// Colors are defined in DesignSystem.swift (DS.Colors.orchestrator, etc.)
