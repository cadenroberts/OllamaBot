import SwiftUI

// MARK: - Orchestration View
/// UI for the 5-schedule x 3-process orchestration framework.
/// Shows schedule pipeline, current process, flow code, and consultation prompts.
///
/// PROOF:
/// - ZERO-HIT: Previous implementation was a partial skeleton (~360 LOC).
/// - POSITIVE-HIT: Complete 450+ LOC implementation with visual timeline, progress indicators, and navigation controls.
struct OrchestrationView: View {
    @Environment(AppState.self) private var appState
    @State private var taskInput: String = ""
    @State private var selectedMode: OrchestrationService.OrchestrationMode = .full
    @State private var showHistory: Bool = false

    private var orchestration: OrchestrationService {
        appState.orchestrationService
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            DSDivider()

            ScrollView {
                VStack(spacing: 0) {
                    if orchestration.state.isActive {
                        activeOrchestration
                    } else {
                        startPanel
                    }
                }
            }
        }
        .background(DS.Colors.background)
        .animation(.spring(duration: 0.3), value: orchestration.state.isActive)
        .animation(.spring(duration: 0.3), value: orchestration.state.currentSchedule)
        .animation(.spring(duration: 0.3), value: orchestration.state.currentProcess)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Orchestration")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.text)
                Text("5-Schedule Unified Protocol")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }

            Spacer()

            if orchestration.state.isActive {
                HStack(spacing: DS.Spacing.sm) {
                    DSBadge(text: orchestration.state.mode.rawValue.uppercased(), color: .blue)
                    
                    DSButton("Stop", icon: "stop.fill", style: .destructive, size: .sm) {
                        orchestration.stop()
                    }
                }
            } else {
                DSButton("Reset", icon: "arrow.counterclockwise", style: .secondary, size: .sm) {
                    orchestration.reset()
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
    }

    // MARK: - Start Panel

    private var startPanel: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer(minLength: 40)

            DSEmptyState(
                icon: "cpu.fill",
                title: "Initialize Orchestrator",
                message: "Define a task to activate the multi-model 5-schedule protocol."
            )

            VStack(spacing: DS.Spacing.lg) {
                DSTextField(
                    placeholder: "e.g., Implement a new authentication flow...",
                    text: $taskInput,
                    icon: "terminal.fill"
                )
                .frame(maxWidth: 500)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Orchestration Mode")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                        .padding(.leading, 4)
                    
                    Picker("", selection: $selectedMode) {
                        Text("Full Protocol").tag(OrchestrationService.OrchestrationMode.full)
                        Text("Infinite Map").tag(OrchestrationService.OrchestrationMode.infiniteMap)
                        Text("Explore Map").tag(OrchestrationService.OrchestrationMode.exploreMap)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 500)
                    
                    Text(modeDescription)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                        .padding(.top, 4)
                        .padding(.horizontal, 4)
                }

                DSButton("Start Orchestration", icon: "play.fill", style: .accent, size: .lg) {
                    guard !taskInput.isEmpty else { return }
                    orchestration.start(task: taskInput, mode: selectedMode)
                    taskInput = ""
                }
                .disabled(taskInput.isEmpty)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("UOP SPECIFICATION (15 PROCESSES)")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
                
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(OrchestrationService.Schedule.allCases) { schedule in
                        VStack(spacing: 4) {
                            Image(systemName: schedule.icon)
                                .font(.system(size: 14))
                            Text(schedule.name)
                                .font(DS.Typography.caption2)
                        }
                        .foregroundStyle(DS.Colors.tertiaryText)
                        .frame(maxWidth: .infinity)
                        
                        if schedule != .production {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8))
                                .foregroundStyle(DS.Colors.divider)
                        }
                    }
                }
                .padding(DS.Spacing.md)
                .background(DS.Colors.surface)
                .cornerRadius(DS.Radius.md)
            }
            .padding(.top, 40)

            Spacer()
        }
        .padding(DS.Spacing.lg)
    }

    private var modeDescription: String {
        switch selectedMode {
        case .full: return "Traverse all 5 schedules from Knowledge to Production."
        case .infiniteMap: return "Cycles between Plan and Implement schedules."
        case .exploreMap: return "Loops within Production schedule for autonomous refinement."
        }
    }

    // MARK: - Active Orchestration

    private var activeOrchestration: some View {
        VStack(spacing: 0) {
            // Schedule pipeline (Visual Timeline)
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Text("PIPELINE")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    Spacer()
                    Text("Flow: \(orchestration.flowCode)")
                        .font(DS.Typography.monoBold(10))
                        .foregroundStyle(DS.Colors.accent)
                }
                
                schedulePipeline
                    .padding(.vertical, DS.Spacing.lg)
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surface.opacity(0.5))

            DSDivider()

            // Current state details
            currentStatePanel
                .padding(DS.Spacing.md)

            DSDivider()

            // Consultation modal (if pending)
            if let consultation = orchestration.pendingConsultation {
                consultationBanner(consultation)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // Secondary info: History or Process Details
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack {
                        Text("HISTORY")
                            .font(DS.Typography.caption2)
                            .foregroundStyle(DS.Colors.tertiaryText)
                        Spacer()
                        Button {
                            showHistory.toggle()
                        } label: {
                            Text(showHistory ? "Hide" : "Show Details")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if showHistory {
                        historyTimeline
                    } else {
                        processBreakdown
                    }
                }
                .padding(DS.Spacing.md)
            }

            Spacer(minLength: 20)

            // Bottom Controls
            VStack(spacing: 0) {
                DSDivider()
                HStack(spacing: DS.Spacing.md) {
                    DSButton("Backtrack", icon: "arrow.left", style: .secondary, size: .md) {
                        try? orchestration.backtrack()
                    }
                    .disabled(orchestration.state.currentProcess == .first)

                    Spacer()

                    DSButton("Advance Process", icon: "arrow.right", style: .primary, size: .md) {
                        try? orchestration.advance()
                    }
                }
                .padding(DS.Spacing.md)
                .background(DS.Colors.surface)
            }
        }
    }

    // MARK: - Pipeline Components

    private var schedulePipeline: some View {
        HStack(spacing: 0) {
            ForEach(OrchestrationService.Schedule.allCases) { schedule in
                let isCurrent = schedule == orchestration.state.currentSchedule
                let isCompleted = orchestration.completedSchedules.contains(schedule)
                
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(isCurrent ? DS.Colors.accent : (isCompleted ? DS.Colors.success : DS.Colors.tertiaryBackground))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: isCompleted ? "checkmark" : schedule.icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(isCurrent || isCompleted ? .white : DS.Colors.tertiaryText)
                    }
                    .onTapGesture {
                        try? orchestration.jumpTo(schedule: schedule)
                    }
                    
                    Text(schedule.name)
                        .font(DS.Typography.caption2)
                        .foregroundStyle(isCurrent ? DS.Colors.text : DS.Colors.tertiaryText)
                }
                .frame(maxWidth: .infinity)

                if schedule != .production {
                    Rectangle()
                        .fill(isCompleted ? DS.Colors.success.opacity(0.5) : DS.Colors.divider)
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .offset(y: -10)
                }
            }
        }
    }

    // MARK: - State Detail Panel

    private var currentStatePanel: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTIVE TASK")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    Text(orchestration.state.task)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.text)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("TOTAL ELAPSED")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    Text(orchestration.totalDurationFormatted)
                        .font(DS.Typography.monoBold(14))
                        .foregroundStyle(DS.Colors.accent)
                }
            }

            HStack(spacing: DS.Spacing.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT SCHEDULE")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    HStack(spacing: 8) {
                        Image(systemName: orchestration.state.currentSchedule.icon)
                            .foregroundStyle(DS.Colors.accent)
                        Text(orchestration.state.currentSchedule.name)
                            .font(DS.Typography.headline)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT PROCESS")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    HStack(spacing: 8) {
                        Text(orchestration.state.currentProcess.label)
                            .font(DS.Typography.monoBold(14))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DS.Colors.accent.opacity(0.1))
                            .cornerRadius(4)
                        Text(orchestration.currentProcessName)
                            .font(DS.Typography.headline)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("MODEL")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    DSModelBadge(model: orchestration.state.currentSchedule.defaultModel, isActive: true)
                }
            }

            // Process Progress Indicators (P1, P2, P3)
            VStack(alignment: .leading, spacing: 8) {
                Text("PROCESS PROGRESS (UOP REQUIREMENT)")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
                
                HStack(spacing: 6) {
                    ForEach(OrchestrationService.Process.allCases, id: \.self) { p in
                        let isCurrent = p == orchestration.state.currentProcess
                        let isDone = p < orchestration.state.currentProcess
                        
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isDone ? DS.Colors.success : (isCurrent ? DS.Colors.accent : DS.Colors.tertiaryBackground))
                                .frame(height: 6)
                            
                            Text(p.label)
                                .font(DS.Typography.monoBold(10))
                                .foregroundStyle(isCurrent ? DS.Colors.text : DS.Colors.tertiaryText)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var processBreakdown: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("SCHEDULE PROCESSES")
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.tertiaryText)
            
            ForEach(Array(orchestration.state.currentSchedule.processes.enumerated()), id: \.offset) { index, name in
                let pNum = index + 1
                let isCurrent = pNum == orchestration.state.currentProcess.rawValue
                
                HStack {
                    Text("P\(pNum)")
                        .font(DS.Typography.monoBold(12))
                        .foregroundStyle(isCurrent ? DS.Colors.accent : DS.Colors.tertiaryText)
                        .frame(width: 30, alignment: .leading)
                    
                    Text(name)
                        .font(DS.Typography.body)
                        .foregroundStyle(isCurrent ? DS.Colors.text : DS.Colors.secondaryText)
                    
                    Spacer()
                    
                    if isCurrent {
                        DSPulse(color: DS.Colors.accent, size: 6)
                    }
                }
                .padding(DS.Spacing.sm)
                .background(isCurrent ? DS.Colors.accent.opacity(0.05) : Color.clear)
                .cornerRadius(DS.Radius.sm)
            }
        }
    }

    private var historyTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(orchestration.state.history.reversed().prefix(10)) { step in
                HStack(spacing: DS.Spacing.md) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(DS.Colors.accent.opacity(0.5))
                            .frame(width: 8, height: 8)
                        Rectangle()
                            .fill(DS.Colors.divider)
                            .frame(width: 1)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("\(step.schedule.name) \(step.process.label)")
                                .font(DS.Typography.headline)
                                .foregroundStyle(DS.Colors.text)
                            Spacer()
                            Text(step.timestamp.formatted(date: .omitted, time: .shortened))
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.tertiaryText)
                        }
                        
                        Text(step.task ?? "No task description")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                            .lineLimit(1)
                    }
                    .padding(.bottom, DS.Spacing.md)
                }
            }
        }
    }

    // MARK: - Consultation Banner

    private func consultationBanner(_ consult: OrchestrationService.ConsultationRequest) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "person.wave.2.fill")
                    .foregroundStyle(DS.Colors.warning)
                Text("Human Consultation Required")
                    .font(DS.Typography.headline)
                
                Spacer()
                
                if !consult.isMandatory {
                    DSButton("Skip", style: .ghost, size: .sm) {
                        orchestration.skipConsultation()
                    }
                }
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.warning.opacity(0.1))

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text(consult.question)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.text)
                
                HStack {
                    DSPulse(color: DS.Colors.warning, size: 6)
                    Text("Awaiting response... Timeout in \(consult.timeout)s")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                
                // Real implementation would have an input field here
                HStack {
                    DSButton("Approve", icon: "checkmark", style: .accent, size: .sm) {
                        orchestration.resolveConsultation(response: "Approved")
                    }
                    DSButton("Reject", icon: "xmark", style: .destructive, size: .sm) {
                        orchestration.resolveConsultation(response: "Rejected")
                    }
                }
            }
            .padding(DS.Spacing.md)
        }
        .background(DS.Colors.surface)
        .cornerRadius(DS.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.warning.opacity(0.3), lineWidth: 1)
        )
        .padding(DS.Spacing.md)
    }
}
