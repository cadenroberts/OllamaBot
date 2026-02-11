import SwiftUI

// MARK: - Preview View (Dry-Run Mode)
// Shows proposed changes as diffs before applying.
// Users approve/reject individual changes. Matches CLI --dry-run / --diff modes.

struct PreviewView: View {
    @Environment(AppState.self) private var appState
    @State private var expandedChange: UUID?

    private var previewService: PreviewService {
        appState.previewService
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            DSDivider()

            if previewService.hasChanges {
                changeList
                DSDivider()
                actionBar
            } else {
                emptyState
            }
        }
        .background(DS.Colors.background)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DS.Spacing.sm) {
                    Text("Preview Mode")
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.text)
                    if previewService.isPreviewMode {
                        DSPulse(color: DS.Colors.warning, size: 8)
                    }
                }
                Text("Review changes before applying")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }

            Spacer()

            Toggle(isOn: Binding(
                get: { previewService.isPreviewMode },
                set: { newValue in
                    if newValue {
                        previewService.enablePreviewMode()
                    } else {
                        previewService.disablePreviewMode()
                    }
                }
            )) {
                Text("Dry Run")
                    .font(DS.Typography.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
    }

    // MARK: - Change List

    private var changeList: some View {
        ScrollView {
            LazyVStack(spacing: DS.Spacing.sm) {
                ForEach(previewService.proposedChanges) { change in
                    ProposedChangeCard(
                        change: change,
                        isExpanded: expandedChange == change.id,
                        onToggleExpand: {
                            withAnimation(DS.Animation.fast) {
                                expandedChange = expandedChange == change.id ? nil : change.id
                            }
                        },
                        onApprove: { previewService.approveChange(change) },
                        onReject: { previewService.rejectChange(change) }
                    )
                }
            }
            .padding(DS.Spacing.sm)
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack {
            Text("\(previewService.approvedCount)/\(previewService.totalCount) approved")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)

            Spacer()

            DSButton("Reject All", icon: "xmark", style: .ghost, size: .sm) {
                previewService.rejectAll()
            }

            DSButton("Approve All", icon: "checkmark", style: .secondary, size: .sm) {
                previewService.approveAll()
            }

            DSButton("Apply \(previewService.approvedCount) Changes", icon: "arrow.right.circle", style: .accent, size: .sm) {
                let applied = previewService.applyApproved(rootFolder: appState.rootFolder)
                appState.showSuccess("Applied \(applied) changes")
            }
            .disabled(previewService.approvedCount == 0)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            DSEmptyState(
                icon: "doc.text.magnifyingglass",
                title: "No Pending Changes",
                message: previewService.isPreviewMode
                    ? "Run an agent task — changes will appear here for review"
                    : "Enable dry-run mode to preview changes before applying"
            )
            Spacer()
        }
    }
}

// MARK: - Proposed Change Card

struct ProposedChangeCard: View {
    let change: PreviewService.ProposedChange
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button(action: onToggleExpand) {
                HStack(spacing: DS.Spacing.md) {
                    // Approval checkbox
                    Button(action: {
                        if change.approved { onReject() } else { onApprove() }
                    }) {
                        Image(systemName: change.approved ? "checkmark.square.fill" : "square")
                            .foregroundStyle(change.approved ? DS.Colors.accent : DS.Colors.secondaryText)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)

                    // Change type icon
                    Image(systemName: change.changeType.icon)
                        .foregroundStyle(changeColor)
                        .font(.system(size: 14))

                    // File path
                    Text(change.filePath)
                        .font(DS.Typography.mono(12))
                        .foregroundStyle(DS.Colors.text)
                        .lineLimit(1)

                    Spacer()

                    // Change type badge
                    DSBadge(text: change.changeType.rawValue, color: changeColor)

                    // Expand chevron
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.Colors.tertiaryText)
                }
                .padding(DS.Spacing.md)
            }
            .buttonStyle(.plain)

            // Diff content (expanded)
            if isExpanded {
                DSDivider()
                diffView
            }
        }
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(change.approved ? DS.Colors.accent.opacity(0.3) : DS.Colors.border, lineWidth: 1)
        )
    }

    private var changeColor: Color {
        switch change.changeType {
        case .create: return DS.Colors.success
        case .modify: return DS.Colors.warning
        case .delete: return DS.Colors.error
        }
    }

    private var diffView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(change.diff.components(separatedBy: .newlines), id: \.self) { line in
                    Text(line)
                        .font(DS.Typography.mono(11))
                        .foregroundStyle(diffLineColor(line))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, 1)
                        .background(diffLineBackground(line))
                }
            }
        }
        .frame(maxHeight: 300)
        .background(DS.Colors.codeBackground)
    }

    private func diffLineColor(_ line: String) -> Color {
        if line.hasPrefix("+ ") { return Color(hex: "73c0ff") }
        if line.hasPrefix("- ") { return Color(hex: "5a8fd4") }
        return DS.Colors.secondaryText
    }

    private func diffLineBackground(_ line: String) -> Color {
        if line.hasPrefix("+ ") { return Color(hex: "73c0ff").opacity(0.05) }
        if line.hasPrefix("- ") { return Color(hex: "5a8fd4").opacity(0.05) }
        return .clear
    }
}
