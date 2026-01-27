import SwiftUI

struct AgentView: View {
    @Environment(AppState.self) private var appState
    @State private var taskInput = ""
    @State private var userResponse = ""
    @State private var selectedMode: AgentMode = .infinite
    
    private var executor: AgentExecutor { appState.agentExecutor }
    
    enum AgentMode: String, CaseIterable {
        case infinite = "Infinite Mode"
        case cycle = "Cycle Agents"
        
        var icon: String {
            switch self {
            case .infinite: return "infinity"
            case .cycle: return "circle.hexagongrid.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Mode selector
            modePicker
            
            DSDivider()
            
            // Content based on mode
            switch selectedMode {
            case .infinite:
                infiniteModeContent
            case .cycle:
                CycleAgentView()
            }
        }
        .background(DS.Colors.background)
    }
    
    // MARK: - Mode Picker
    
    private var modePicker: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(AgentMode.allCases, id: \.self) { mode in
                Button(action: { 
                    withAnimation(DS.Animation.fast) {
                        selectedMode = mode 
                    }
                }) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: mode.icon)
                            .font(.caption)
                        Text(mode.rawValue)
                            .font(DS.Typography.caption.weight(.medium))
                    }
                    .foregroundStyle(selectedMode == mode ? DS.Colors.text : DS.Colors.secondaryText)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(selectedMode == mode ? DS.Colors.accent.opacity(0.2) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Help button
            DSIconButton(icon: "questionmark.circle", size: 14) {
                // Show help
            }
            .help(selectedMode == .infinite 
                ? "Single agent loop until task complete" 
                : "Multi-model orchestration with specialists")
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.surface)
    }
    
    // MARK: - Infinite Mode Content
    
    private var infiniteModeContent: some View {
        VStack(spacing: 0) {
            header
            DSDivider()
            stepsList
            DSDivider()
            
            if executor.waitingForUser {
                userInputBar
            }
            
            controlBar
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: DS.Spacing.md) {
            // Logo with status
            ZStack {
                DSLogo(size: 32, animated: executor.isRunning)
                
                if executor.isRunning {
                    Circle()
                        .fill(DS.Colors.success)
                        .frame(width: 10, height: 10)
                        .offset(x: 12, y: -12)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Infinite Mode")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.text)
                
                if executor.isRunning {
                    Text(executor.currentTask)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                        .lineLimit(1)
                } else {
                    Text("AI-powered coding assistant")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            }
            
            Spacer()
            
            if executor.isRunning {
                HStack(spacing: DS.Spacing.sm) {
                    Text("\(executor.steps.count)")
                        .font(DS.Typography.headline.monospacedDigit())
                    Text("steps")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.secondaryBackground)
    }
    
    // MARK: - Steps List
    
    private var stepsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if executor.steps.isEmpty && !executor.isRunning {
                    emptyState
                } else {
                    LazyVStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        ForEach(executor.steps) { step in
                            StepCard(step: step)
                                .id(step.id)
                        }
                    }
                    .padding(DS.Spacing.md)
                }
            }
            .onChange(of: executor.steps.count) { _, _ in
                if let last = executor.steps.last {
                    withAnimation(DS.Animation.fast) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: DS.Spacing.xl) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 56))
                .foregroundStyle(DS.Colors.secondaryText.opacity(0.4))
            
            VStack(spacing: DS.Spacing.sm) {
                Text("Multi-Model AI Agent")
                    .font(DS.Typography.title)
                
                Text("Qwen3 orchestrates specialized AI models to complete complex tasks")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            // Model Capabilities
            HStack(spacing: DS.Spacing.md) {
                modelCard(
                    name: "Qwen3",
                    role: "Orchestrator",
                    icon: "brain",
                    color: DS.Colors.orchestrator
                )
                modelCard(
                    name: "Qwen-Coder",
                    role: "Code Expert",
                    icon: "chevron.left.forwardslash.chevron.right",
                    color: DS.Colors.coder
                )
                modelCard(
                    name: "Command-R",
                    role: "Research",
                    icon: "magnifyingglass.circle",
                    color: DS.Colors.researcher
                )
                modelCard(
                    name: "Qwen-VL",
                    role: "Vision",
                    icon: "eye",
                    color: DS.Colors.vision
                )
            }
            
            // Tool Capabilities
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Available Tools")
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(DS.Colors.secondaryText)
                
                capabilityRow(icon: "doc.text", text: "Read and write files")
                capabilityRow(icon: "pencil", text: "Edit code with search/replace")
                capabilityRow(icon: "terminal", text: "Run shell commands")
                capabilityRow(icon: "magnifyingglass", text: "Search across your codebase")
                capabilityRow(icon: "camera", text: "Take screenshots for analysis")
                capabilityRow(icon: "arrow.triangle.branch", text: "Delegate to specialized models")
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxl)
    }
    
    private func modelCard(name: String, role: String, icon: String, color: Color) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            Text(name)
                .font(DS.Typography.caption.weight(.medium))
            
            Text(role)
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.tertiaryText)
        }
        .frame(width: 80)
        .padding(DS.Spacing.sm)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    private func capabilityRow(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(DS.Colors.accent)
                .frame(width: 20)
            Text(text)
                .font(DS.Typography.caption)
        }
    }
    
    // MARK: - User Input Bar
    
    private var userInputBar: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(executor.userPrompt)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.warning)
            
            HStack(spacing: DS.Spacing.md) {
                DSTextField(placeholder: "Your response...", text: $userResponse) {
                    submitUserResponse()
                }
                
                DSButton("Send", icon: "arrow.up", style: .primary) {
                    submitUserResponse()
                }
                .disabled(userResponse.isEmpty)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.warning.opacity(0.1))
    }
    
    private func submitUserResponse() {
        guard !userResponse.isEmpty else { return }
        executor.provideUserInput(userResponse)
        userResponse = ""
    }
    
    // MARK: - Control Bar
    
    private var controlBar: some View {
        HStack(spacing: DS.Spacing.md) {
            if executor.isRunning {
                DSButton("Stop", icon: "stop.fill", style: .destructive) {
                    executor.stop()
                }
            } else {
                DSTextField(
                    placeholder: "What would you like me to do?",
                    text: $taskInput,
                    icon: "sparkles"
                ) {
                    startTask()
                }
                
                DSButton("Start", icon: "play.fill", style: .primary) {
                    startTask()
                }
                .disabled(taskInput.trimmingCharacters(in: .whitespaces).isEmpty)
                
                if !executor.steps.isEmpty {
                    DSIconButton(icon: "trash") {
                        executor.steps.removeAll()
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.secondaryBackground)
    }
    
    private func startTask() {
        let task = taskInput.trimmingCharacters(in: .whitespaces)
        guard !task.isEmpty else { return }
        executor.start(task: task, workingDirectory: appState.rootFolder)
        taskInput = ""
    }
}

// MARK: - Step Card

struct StepCard: View {
    let step: AgentStep
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: step.type.icon)
                    .foregroundStyle(step.type.color)
                    .frame(width: 18)
                
                Text(title)
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(step.type.color)
                
                Spacer()
                
                Text(step.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
                
                if hasExpandableContent {
                    DSIconButton(icon: isExpanded ? "chevron.up" : "chevron.down", size: 14) {
                        withAnimation(DS.Animation.fast) { isExpanded.toggle() }
                    }
                }
            }
            
            // Content
            content
        }
        .padding(DS.Spacing.md)
        .background(step.type.color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    private var title: String {
        switch step.type {
        case .system: return "SYSTEM"
        case .thinking: return "THINKING"
        case .tool(let name, _, _):
            // Friendly names for delegation tools
            switch name {
            case "delegate_to_coder": return "→ QWEN-CODER"
            case "delegate_to_researcher": return "→ COMMAND-R"
            case "delegate_to_vision": return "→ QWEN-VL"
            case "take_screenshot": return "📷 SCREENSHOT"
            default: return name.uppercased().replacingOccurrences(of: "_", with: " ")
            }
        case .userInput: return "USER INPUT"
        case .error: return "ERROR"
        case .complete: return "COMPLETE"
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch step.type {
        case .system(let msg):
            Text(msg)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
            
        case .thinking(let thought):
            Text(isExpanded ? thought : String(thought.prefix(100)) + (thought.count > 100 ? "..." : ""))
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
            
        case .tool(_, let input, let output):
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.xs) {
                    Text("→")
                        .foregroundStyle(DS.Colors.tertiaryText)
                    Text(input)
                        .lineLimit(isExpanded ? nil : 1)
                }
                .font(DS.Typography.mono(11))
                
                if isExpanded && !output.isEmpty {
                    Text(output)
                        .font(DS.Typography.mono(11))
                        .foregroundStyle(DS.Colors.secondaryText)
                        .padding(DS.Spacing.sm)
                        .background(DS.Colors.codeBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
            }
            
        case .userInput(let prompt):
            Text(prompt)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.warning)
            
        case .error(let msg):
            Text(msg)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.error)
            
        case .complete(let summary):
            Text(summary)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.success)
        }
    }
    
    private var hasExpandableContent: Bool {
        switch step.type {
        case .thinking(let t): return t.count > 100
        case .tool: return true
        default: return false
        }
    }
}
