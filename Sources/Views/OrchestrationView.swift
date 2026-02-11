import SwiftUI

// MARK: - Orchestration View
// UI for the 5-schedule x 3-process orchestration framework.
// Shows schedule pipeline, current process, flow code, and consultation prompts.

struct OrchestrationView: View {
    @Environment(AppState.self) private var appState
    @State private var taskInput: String = ""
    @State private var selectedMode: OrchestrationService.OrchestrationMode = .full

    private var orchestration: OrchestrationService {
        appState.orchestrationService
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            DSDivider()

            if orchestration.state.isActive {
                activeOrchestration
            } else {
                startPanel
            }
        }
        .background(DS.Colors.background)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Orchestration")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.text)
                Text("5-Schedule Framework")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }

            Spacer()

            if orchestration.state.isActive {
                DSButton("Stop", icon: "stop.fill", style: .destructive, size: .sm) {
                    orchestration.stop()
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
    }

    // MARK: - Start Panel

    private var startPanel: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()

            DSEmptyState(
                icon: "wand.and.stars",
                title: "Start Orchestration",
                message: "Enter a task to begin the 5-schedule workflow"
            )

            VStack(spacing: DS.Spacing.md) {
                DSTextField(
                    placeholder: "Describe your task...",
                    text: $taskInput,
                    icon: "text.bubble"
                )
                .frame(maxWidth: 400)

                Picker("Mode", selection: $selectedMode) {
                    Text("Full (5 Schedules)").tag(OrchestrationService.OrchestrationMode.full)
                    Text("Infinite Map").tag(OrchestrationService.OrchestrationMode.infiniteMap)
                    Text("Explore Map").tag(OrchestrationService.OrchestrationMode.exploreMap)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)

                DSButton("Start", icon: "play.fill", style: .accent, size: .lg) {
                    guard !taskInput.isEmpty else { return }
                    orchestration.startOrchestration(task: taskInput, mode: selectedMode)
                    taskInput = ""
                }
                .disabled(taskInput.isEmpty)
            }

            Spacer()
        }
        .padding(DS.Spacing.lg)
    }

    // MARK: - Active Orchestration

    private var activeOrchestration: some View {
        VStack(spacing: 0) {
            // Schedule pipeline
            schedulePipeline
                .padding(DS.Spacing.md)

            DSDivider()

            // Current state
            currentStatePanel
                .padding(DS.Spacing.md)

            DSDivider()

            // Flow code
            FlowCodeView(flowCode: orchestration.flowCode)
                .padding(DS.Spacing.md)

            Spacer()

            // Consultation modal (if pending)
            if orchestration.state.pendingConsultation != nil {
                consultationBanner
            }

            // Advance button
            HStack {
                Spacer()
                DSButton("Advance", icon: "arrow.right", style: .primary, size: .md) {
                    try? orchestration.advanceProcess()
                }
                Spacer()
            }
            .padding(DS.Spacing.md)
        }
    }

    // MARK: - Schedule Pipeline

    private var schedulePipeline: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(OrchestrationService.Schedule.allCases) { schedule in
                ScheduleNode(
                    schedule: schedule,
                    isCurrent: schedule == orchestration.state.currentSchedule,
                    isCompleted: orchestration.completedSchedules.contains(schedule),
                    canNavigate: orchestration.canNavigateTo(schedule)
                ) {
                    try? orchestration.navigateToSchedule(schedule)
                }

                if schedule != .production {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.Colors.tertiaryText)
                }
            }
        }
    }

    // MARK: - Current State

    private var currentStatePanel: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("Task:")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                Text(orchestration.state.task)
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.text)
                    .lineLimit(2)
            }

            HStack(spacing: DS.Spacing.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Schedule")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: orchestration.state.currentSchedule.icon)
                            .font(.system(size: DS.IconSize.sm))
                        Text(orchestration.state.currentSchedule.name)
                            .font(DS.Typography.headline)
                    }
                    .foregroundStyle(DS.Colors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Process")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    Text(orchestration.currentProcessName)
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.text)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Model")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    DSModelBadge(model: orchestration.state.currentSchedule.defaultModel, isActive: true)
                }
            }

            // Process progress
            HStack(spacing: DS.Spacing.sm) {
                ForEach(orchestration.state.currentSchedule.processes.indices, id: \.self) { idx in
                    let processNum = idx + 1
                    let isCurrent = processNum == orchestration.state.currentProcess.rawValue
                    let isCompleted = processNum < orchestration.state.currentProcess.rawValue

                    HStack(spacing: DS.Spacing.xs) {
                        Circle()
                            .fill(isCompleted ? DS.Colors.success : (isCurrent ? DS.Colors.accent : DS.Colors.tertiaryBackground))
                            .frame(width: 8, height: 8)
                        Text(orchestration.state.currentSchedule.processes[idx])
                            .font(DS.Typography.caption)
                            .foregroundStyle(isCurrent ? DS.Colors.text : DS.Colors.secondaryText)
                    }

                    if idx < orchestration.state.currentSchedule.processes.count - 1 {
                        Rectangle()
                            .fill(isCompleted ? DS.Colors.success : DS.Colors.tertiaryBackground)
                            .frame(height: 2)
                    }
                }
            }
        }
    }

    // MARK: - Consultation Banner

    private var consultationBanner: some View {
        VStack(spacing: DS.Spacing.sm) {
            if let consultation = orchestration.state.pendingConsultation {
                DSCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            Image(systemName: "person.wave.2")
                                .foregroundStyle(DS.Colors.warning)
                            Text("Consultation Required")
                                .font(DS.Typography.headline)
                            Spacer()
                            if !consultation.isMandatory {
                                DSButton("Skip", style: .ghost, size: .sm) {
                                    orchestration.skipConsultation()
                                }
                            }
                        }
                        Text(consultation.question)
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.secondaryText)
                        Text("Timeout: \(consultation.timeout)s")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.tertiaryText)
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
    }
}

// MARK: - Schedule Node

struct ScheduleNode: View {
    let schedule: OrchestrationService.Schedule
    let isCurrent: Bool
    let isCompleted: Bool
    let canNavigate: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DS.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(fillColor)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .strokeBorder(borderColor, lineWidth: isCurrent ? 2 : 1)
                        )

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DS.Colors.success)
                    } else {
                        Image(systemName: schedule.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(isCurrent ? DS.Colors.accent : DS.Colors.secondaryText)
                    }
                }

                Text("S\(schedule.rawValue)")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(isCurrent ? DS.Colors.accent : DS.Colors.tertiaryText)
            }
            .opacity(canNavigate ? 1 : 0.4)
            .scaleEffect(isHovered && canNavigate ? 1.05 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!canNavigate)
        .onHover { isHovered = $0 }
    }

    private var fillColor: Color {
        if isCurrent { return DS.Colors.accent.opacity(0.15) }
        if isCompleted { return DS.Colors.success.opacity(0.1) }
        return DS.Colors.surface
    }

    private var borderColor: Color {
        if isCurrent { return DS.Colors.accent }
        if isCompleted { return DS.Colors.success.opacity(0.5) }
        return DS.Colors.border
    }
}

// MARK: - Flow Code View

struct FlowCodeView: View {
    let flowCode: String

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: DS.IconSize.sm))
                .foregroundStyle(DS.Colors.tertiaryText)

            Text("Flow:")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)

            Text(flowCode)
                .font(DS.Typography.monoBold(12))
                .foregroundStyle(DS.Colors.accent)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xxs)
                .background(DS.Colors.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))

            Spacer()
        }
    }
}

// MARK: - Hashable Conformances for Picker

extension OrchestrationService.OrchestrationMode: Hashable {}
