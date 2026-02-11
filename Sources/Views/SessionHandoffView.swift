import SwiftUI

// MARK: - Session Handoff View
// Export IDE sessions in USF JSON format.
// Import CLI-created sessions.
// Full session handoff between platforms.

struct SessionHandoffView: View {
    @Environment(AppState.self) private var appState
    @State private var showExportSuccess = false
    @State private var showImportPanel = false

    private var sessionService: UnifiedSessionService {
        appState.unifiedSessionService
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            DSDivider()

            if sessionService.currentSession != nil {
                currentSessionPanel
                DSDivider()
            }

            savedSessionsList

            Spacer()
        }
        .background(DS.Colors.background)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sessions")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.text)
                Text("Export & import cross-platform sessions")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }

            Spacer()

            DSButton("Import", icon: "square.and.arrow.down", style: .secondary, size: .sm) {
                showImportPanel = true
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .fileImporter(
            isPresented: $showImportPanel,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                if let imported = sessionService.importSession(from: url) {
                    appState.showSuccess("Imported session: \(imported.task.original.prefix(40))")
                } else {
                    appState.showError("Failed to import session")
                }
            }
        }
    }

    // MARK: - Current Session

    private var currentSessionPanel: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    DSPulse(color: DS.Colors.success, size: 8)
                    Text("Active Session")
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.text)
                    Spacer()
                    DSButton("End", icon: "stop.fill", style: .ghost, size: .sm) {
                        sessionService.endSession()
                    }
                }

                if let session = sessionService.currentSession {
                    Text(session.task.original)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.secondaryText)
                        .lineLimit(2)

                    HStack(spacing: DS.Spacing.lg) {
                        Label("\(session.steps.count) steps", systemImage: "arrow.right.circle")
                        Label("\(session.stats.totalTokens) tokens", systemImage: "number")
                        Label("\(session.stats.filesModified) files", systemImage: "doc")
                    }
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.tertiaryText)

                    if let orch = session.orchestration {
                        FlowCodeView(
                            flowCode: orch.flowCode,
                            currentSchedule: OrchestrationService.Schedule(rawValue: orch.currentSchedule) ?? .knowledge,
                            currentProcess: OrchestrationService.Process(rawValue: orch.currentProcess) ?? .first
                        )
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
    }

    // MARK: - Saved Sessions

    private var savedSessionsList: some View {
        Group {
            if sessionService.savedSessions.isEmpty {
                VStack(spacing: DS.Spacing.lg) {
                    Spacer()
                    DSEmptyState(
                        icon: "tray",
                        title: "No Saved Sessions",
                        message: "Sessions will appear here when exported or imported"
                    )
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.sm) {
                        ForEach(sessionService.savedSessions) { session in
                            SessionCard(
                                session: session,
                                onResume: {
                                    sessionService.resumeSession(session)
                                    appState.showSuccess("Resumed session")
                                },
                                onExport: {
                                    exportSession(session)
                                },
                                onDelete: {
                                    sessionService.deleteSession(id: session.sessionId)
                                }
                            )
                        }
                    }
                    .padding(DS.Spacing.sm)
                }
            }
        }
    }

    private func exportSession(_ session: UnifiedSessionService.UnifiedSession) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(session.sessionId).json"
        panel.allowedContentTypes = [.json]

        if panel.runModal() == .OK, let url = panel.url {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(session) {
                try? data.write(to: url)
                appState.showSuccess("Session exported")
            }
        }
    }
}

// MARK: - Session Card

struct SessionCard: View {
    let session: UnifiedSessionService.UnifiedSession
    let onResume: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Platform icon
            ZStack {
                Circle()
                    .fill(platformColor.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: session.platformOrigin == "ide" ? "desktopcomputer" : "terminal")
                    .font(.system(size: 14))
                    .foregroundStyle(platformColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(session.task.original.prefix(60))
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.text)
                    .lineLimit(1)

                HStack(spacing: DS.Spacing.sm) {
                    DSBadge(text: session.task.status, color: statusColor)
                    DSBadge(text: session.platformOrigin.uppercased(), color: platformColor)
                    Text(session.createdAt.prefix(16))
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.tertiaryText)
                }

                HStack(spacing: DS.Spacing.sm) {
                    Label("\(session.steps.count) steps", systemImage: "arrow.right.circle")
                    Label("\(session.stats.totalTokens) tokens", systemImage: "number")
                }
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.tertiaryText)
            }

            Spacer()

            // Actions
            if isHovered {
                HStack(spacing: DS.Spacing.xs) {
                    DSIconButton(icon: "play.fill", size: 14) { onResume() }
                        .help("Resume session")
                    DSIconButton(icon: "square.and.arrow.up", size: 14) { onExport() }
                        .help("Export session")
                    DSIconButton(icon: "trash", size: 14) { onDelete() }
                        .help("Delete session")
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(isHovered ? DS.Colors.surface : DS.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(DS.Colors.border, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }

    private var platformColor: Color {
        session.platformOrigin == "ide" ? DS.Colors.orchestrator : DS.Colors.coder
    }

    private var statusColor: Color {
        switch session.task.status {
        case "completed": return DS.Colors.success
        case "in_progress": return DS.Colors.accent
        case "cancelled": return DS.Colors.error
        default: return DS.Colors.tertiaryText
        }
    }
}
