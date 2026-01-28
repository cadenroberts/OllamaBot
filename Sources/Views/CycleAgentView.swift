import SwiftUI

// MARK: - Cycle Agent View
// Visual interface for multi-agent orchestration
// Uses shared CycleAgentManager from AppState (SINGLE SOURCE OF TRUTH)

struct CycleAgentView: View {
    @Environment(AppState.self) private var appState
    @State private var taskInput: String = ""
    @State private var selectedStrategy: CycleAgentManager.CycleStrategy = .adaptive
    @State private var isExecuting: Bool = false
    @State private var results: [CycleAgentManager.TaskResult] = []
    @State private var showStatistics: Bool = false
    
    // Use shared instance from AppState
    private var cycleManager: CycleAgentManager {
        appState.cycleAgentManager
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with system info
            headerSection
            
            DSDivider()
            
            // Main content
            HSplitView {
                // Left: Agent configuration
                agentConfigPanel
                    .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
                
                // Right: Task execution
                executionPanel
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Title
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.title2)
                    .foregroundStyle(DS.Colors.accent)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cycle Agents")
                        .font(DS.Typography.headline)
                    Text("Multi-model orchestration")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            }
            
            Spacer()
            
            // System status
            systemStatusBadge(cycleManager)
            
            // Statistics button
            DSIconButton(icon: "chart.bar", size: 16) {
                showStatistics.toggle()
            }
            .popover(isPresented: $showStatistics) {
                statisticsPopover
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
    }
    
    private func systemStatusBadge(_ manager: CycleAgentManager) -> some View {
        let stats = manager.getStatistics()
        
        return HStack(spacing: DS.Spacing.md) {
            // RAM indicator
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "memorychip")
                    .font(.caption)
                Text("\(stats.availableRAM)GB")
                    .font(DS.Typography.mono(11))
            }
            .foregroundStyle(stats.canRunParallel ? DS.Colors.success : DS.Colors.warning)
            
            // Parallel capability
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: stats.canRunParallel ? "bolt.fill" : "bolt.slash")
                    .font(.caption)
                Text(stats.canRunParallel ? "Parallel" : "Sequential")
                    .font(DS.Typography.caption)
            }
            .foregroundStyle(stats.canRunParallel ? DS.Colors.success : DS.Colors.secondaryText)
            
            // Warm model indicator
            if let warm = stats.warmAgent {
                HStack(spacing: DS.Spacing.xs) {
                    Circle()
                        .fill(DS.Colors.success)
                        .frame(width: 6, height: 6)
                    Text(warm)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Colors.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
    
    // MARK: - Agent Config Panel
    
    private var agentConfigPanel: some View {
        VStack(spacing: 0) {
            DSSectionHeader(title: "AGENTS")
            
            DSDivider()
            
            ScrollView {
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(cycleManager.agents) { agent in
                        AgentCard(agent: agent, isWarm: cycleManager.getStatistics().warmAgent == agent.role.rawValue)
                    }
                }
                .padding(DS.Spacing.sm)
            }
            
            DSDivider()
            
            // Strategy selector
            strategySelector
        }
        .background(DS.Colors.secondaryBackground)
    }
    
    private var strategySelector: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Execution Strategy")
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(DS.Colors.secondaryText)
            
            Picker("Strategy", selection: $selectedStrategy) {
                Text("Adaptive (Recommended)").tag(CycleAgentManager.CycleStrategy.adaptive)
                Text("Specialist (Batched)").tag(CycleAgentManager.CycleStrategy.specialist)
                Text("Pipeline (Sequential)").tag(CycleAgentManager.CycleStrategy.pipeline)
                Text("Round Robin").tag(CycleAgentManager.CycleStrategy.roundRobin)
                if cycleManager.getStatistics().canRunParallel {
                    Text("Parallel (64GB+ RAM)").tag(CycleAgentManager.CycleStrategy.parallel)
                }
            }
            .pickerStyle(.menu)
            
            Text(strategyDescription)
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.tertiaryText)
        }
        .padding(DS.Spacing.sm)
    }
    
    private var strategyDescription: String {
        switch selectedStrategy {
        case .adaptive:
            return "Automatically chooses the best strategy based on task analysis"
        case .specialist:
            return "Groups tasks by agent to minimize model switches"
        case .pipeline:
            return "Tasks flow through agents, each building on previous results"
        case .roundRobin:
            return "Agents take turns handling tasks in sequence"
        case .parallel:
            return "Executes compatible tasks simultaneously (requires 64GB+ RAM)"
        }
    }
    
    // MARK: - Execution Panel
    
    private var executionPanel: some View {
        VStack(spacing: 0) {
            // Task input
            taskInputSection
            
            DSDivider()
            
            // Results
            if isExecuting {
                executionProgress
            } else if !results.isEmpty {
                resultsSection
            } else {
                emptyState
            }
        }
        .background(DS.Colors.background)
    }
    
    private var taskInputSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack {
                Text("Task")
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(DS.Colors.secondaryText)
                
                Spacer()
                
                // Quick task buttons
                Menu {
                    Button("Code Review Task") {
                        taskInput = "Review this codebase for potential bugs, security issues, and performance improvements. Provide specific recommendations with code examples."
                    }
                    Button("Research Task") {
                        taskInput = "Research best practices for [topic] and provide a comprehensive summary with examples and recommendations."
                    }
                    Button("Multi-step Analysis") {
                        taskInput = "Analyze this project: 1) Review code quality, 2) Research similar implementations, 3) Suggest improvements with implementation plan."
                    }
                } label: {
                    Label("Templates", systemImage: "text.badge.plus")
                        .font(DS.Typography.caption)
                }
            }
            
            TextEditor(text: $taskInput)
                .font(DS.Typography.callout)
                .foregroundStyle(DS.Colors.text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80, maxHeight: 150)
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
                
                DSButton("Execute Cycle", style: .primary, size: .md) {
                    Task {
                        await executeCycle()
                    }
                }
                .disabled(taskInput.isEmpty || isExecuting)
            }
        }
        .padding(DS.Spacing.md)
    }
    
    private var executionProgress: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            
            // Animated agent visualization
            CycleVisualization(
                agents: cycleManager.agents,
                currentAgent: cycleManager.currentTask?.assignedAgent,
                progress: cycleManager.progress
            )
            
            // Status
            VStack(spacing: DS.Spacing.sm) {
                Text(cycleManager.statusMessage.isEmpty ? "Executing..." : cycleManager.statusMessage)
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.text)
                
                ProgressView(value: cycleManager.progress)
                    .tint(DS.Colors.accent)
                    .frame(maxWidth: 300)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var resultsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Summary
                HStack {
                    Text("Results")
                        .font(DS.Typography.headline)
                    
                    Spacer()
                    
                    Text("\(results.count) tasks completed")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
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
            Spacer()
            
            Image(systemName: "circle.hexagongrid")
                .font(.system(size: 48))
                .foregroundStyle(DS.Colors.tertiaryText)
            
            Text("Multi-Agent Execution")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.secondaryText)
            
            Text("Enter a complex task and let multiple specialized\nagents collaborate to solve it")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.tertiaryText)
                .multilineTextAlignment(.center)
            
            // Performance note
            VStack(spacing: DS.Spacing.xs) {
                let stats = cycleManager.getStatistics()
                if stats.canRunParallel {
                    Label("Parallel execution enabled (64GB+ RAM)", systemImage: "bolt.fill")
                        .foregroundStyle(DS.Colors.success)
                } else {
                    Label("Smart sequential mode (optimized for \(stats.availableRAM)GB RAM)", systemImage: "bolt")
                        .foregroundStyle(DS.Colors.warning)
                }
            }
            .font(DS.Typography.caption)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            // Use plan-and-execute for complex tasks
            let result = try await manager.planAndExecute(task: taskInput, context: context)
            
            // Convert to result format
            results = [CycleAgentManager.TaskResult(
                output: result,
                agentId: "synthesis",
                executionTime: 0,
                modelSwitchTime: 0,
                tokensUsed: result.count / 4
            )]
        } catch {
            appState.showError("Cycle execution failed: \(error.localizedDescription)")
        }
        
        isExecuting = false
    }
}

// MARK: - Agent Card

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
