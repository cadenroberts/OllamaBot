import SwiftUI

// MARK: - Agent Edit Review View
// Review and merge agent-proposed changes with enhanced diff visualization

struct AgentEditReviewView: View {
    @Environment(\.dismiss) private var dismiss
    let changes: [ProposedChange]
    let onAcceptAll: () -> Void
    let onRejectAll: () -> Void
    let onAccept: (ProposedChange) -> Void
    let onReject: (ProposedChange) -> Void
    
    @State private var currentChangeIndex = 0
    @State private var acceptedChanges: Set<UUID> = []
    @State private var rejectedChanges: Set<UUID> = []
    @State private var showSideBySide = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            DSDivider()
            
            // Main content
            HSplitView {
                // File list
                fileList
                    .frame(width: 220)
                
                // Diff viewer
                diffViewer
            }
            
            DSDivider()
            
            // Footer
            footer
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(DS.Colors.background)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Review Agent Changes")
                    .font(DS.Typography.title2)
                    .foregroundStyle(DS.Colors.text)
                
                Text("\(changes.count) files modified • \(totalAdditions) additions • \(totalDeletions) deletions")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            
            Spacer()
            
            // View toggle
            HStack(spacing: DS.Spacing.sm) {
                DSIconButton(icon: "rectangle.split.2x1", size: 20, color: showSideBySide ? DS.Colors.accent : DS.Colors.tertiaryText) {
                    showSideBySide = true
                }
                .help("Side by side")
                
                DSIconButton(icon: "rectangle.arrowtriangle.2.inward", size: 20, color: !showSideBySide ? DS.Colors.accent : DS.Colors.tertiaryText) {
                    showSideBySide = false
                }
                .help("Unified diff")
            }
            
            DSIconButton(icon: "xmark", size: 20) {
                dismiss()
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
    }
    
    private var totalAdditions: Int {
        changes.reduce(0) { $0 + $1.additions }
    }
    
    private var totalDeletions: Int {
        changes.reduce(0) { $0 + $1.deletions }
    }
    
    // MARK: - File List
    
    private var fileList: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("FILES")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
                    .tracking(0.5)
                
                Spacer()
                
                Text("\(changes.count)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            .padding(DS.Spacing.md)
            
            DSDivider()
            
            // File list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(changes.enumerated()), id: \.element.id) { index, change in
                        FileChangeRow(
                            change: change,
                            isSelected: index == currentChangeIndex,
                            status: statusForChange(change)
                        ) {
                            currentChangeIndex = index
                        }
                    }
                }
            }
        }
        .background(DS.Colors.secondaryBackground)
    }
    
    private func statusForChange(_ change: ProposedChange) -> ChangeStatus {
        if acceptedChanges.contains(change.id) {
            return .accepted
        } else if rejectedChanges.contains(change.id) {
            return .rejected
        }
        return .pending
    }
    
    enum ChangeStatus {
        case pending, accepted, rejected
    }
    
    // MARK: - Diff Viewer
    
    private var diffViewer: some View {
        VStack(spacing: 0) {
            if changes.isEmpty {
                emptyState
            } else {
                let change = changes[currentChangeIndex]
                
                // File header
                HStack {
                    Image(systemName: change.changeType.icon)
                        .foregroundStyle(change.changeType.color)
                    
                    Text(change.filename)
                        .font(DS.Typography.headline)
                    
                    Spacer()
                    
                    // Change stats
                    HStack(spacing: DS.Spacing.sm) {
                        Text("+\(change.additions)")
                            .font(DS.Typography.mono(11))
                            .foregroundStyle(DS.Colors.success)
                        
                        Text("-\(change.deletions)")
                            .font(DS.Typography.mono(11))
                            .foregroundStyle(DS.Colors.error)
                    }
                }
                .padding(DS.Spacing.md)
                .background(DS.Colors.surface)
                
                DSDivider()
                
                // Diff content
                if showSideBySide {
                    sideBySideDiff(change: change)
                } else {
                    unifiedDiff(change: change)
                }
                
                DSDivider()
                
                // Per-file actions
                HStack {
                    if statusForChange(change) == .pending {
                        DSButton("Reject This File", icon: "xmark", style: .secondary) {
                            rejectedChanges.insert(change.id)
                            acceptedChanges.remove(change.id)
                            navigateToNextPending()
                        }
                        
                        DSButton("Accept This File", icon: "checkmark", style: .primary) {
                            acceptedChanges.insert(change.id)
                            rejectedChanges.remove(change.id)
                            navigateToNextPending()
                        }
                    } else {
                        DSButton("Undo Decision", style: .ghost) {
                            acceptedChanges.remove(change.id)
                            rejectedChanges.remove(change.id)
                        }
                        
                        Text(statusForChange(change) == .accepted ? "Accepted" : "Rejected")
                            .font(DS.Typography.caption)
                            .foregroundStyle(statusForChange(change) == .accepted ? DS.Colors.success : DS.Colors.error)
                    }
                    
                    Spacer()
                    
                    // Navigation
                    HStack(spacing: DS.Spacing.sm) {
                        DSIconButton(icon: "chevron.up", size: 24) {
                            navigateToPrevious()
                        }
                        .disabled(currentChangeIndex == 0)
                        
                        Text("\(currentChangeIndex + 1) of \(changes.count)")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                        
                        DSIconButton(icon: "chevron.down", size: 24) {
                            navigateToNext()
                        }
                        .disabled(currentChangeIndex >= changes.count - 1)
                    }
                }
                .padding(DS.Spacing.md)
                .background(DS.Colors.surface)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(DS.Colors.success)
            
            Text("No changes to review")
                .font(DS.Typography.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Side by Side Diff
    
    private func sideBySideDiff(change: ProposedChange) -> some View {
        HStack(spacing: 0) {
            // Original
            VStack(spacing: 0) {
                HStack {
                    Text("ORIGINAL")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.surface)
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(change.originalLines.enumerated()), id: \.offset) { index, line in
                            HStack(spacing: 0) {
                                // Line number
                                Text("\(index + 1)")
                                    .font(DS.Typography.mono(10))
                                    .foregroundStyle(DS.Colors.tertiaryText)
                                    .frame(width: 40, alignment: .trailing)
                                    .padding(.trailing, DS.Spacing.sm)
                                
                                // Content
                                Text(line)
                                    .font(DS.Typography.mono(11))
                                    .foregroundStyle(DS.Colors.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, 1)
                            .background(lineBackground(line: line, isOriginal: true))
                        }
                    }
                    .padding(.vertical, DS.Spacing.sm)
                }
                .background(DS.Colors.codeBackground)
            }
            
            DSDivider(vertical: true)
            
            // Modified
            VStack(spacing: 0) {
                HStack {
                    Text("MODIFIED")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.surface)
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(change.modifiedLines.enumerated()), id: \.offset) { index, line in
                            HStack(spacing: 0) {
                                // Line number
                                Text("\(index + 1)")
                                    .font(DS.Typography.mono(10))
                                    .foregroundStyle(DS.Colors.tertiaryText)
                                    .frame(width: 40, alignment: .trailing)
                                    .padding(.trailing, DS.Spacing.sm)
                                
                                // Content
                                Text(line)
                                    .font(DS.Typography.mono(11))
                                    .foregroundStyle(DS.Colors.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, 1)
                            .background(lineBackground(line: line, isOriginal: false))
                        }
                    }
                    .padding(.vertical, DS.Spacing.sm)
                }
                .background(DS.Colors.codeBackground)
            }
        }
    }
    
    // MARK: - Unified Diff
    
    private func unifiedDiff(change: ProposedChange) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(change.unifiedDiff) { line in
                    HStack(spacing: 0) {
                        // Change indicator
                        Text(line.type.indicator)
                            .font(DS.Typography.mono(11))
                            .foregroundStyle(line.type.color)
                            .frame(width: 20)
                        
                        // Line number
                        if let lineNum = line.lineNumber {
                            Text("\(lineNum)")
                                .font(DS.Typography.mono(10))
                                .foregroundStyle(DS.Colors.tertiaryText)
                                .frame(width: 40, alignment: .trailing)
                                .padding(.trailing, DS.Spacing.sm)
                        } else {
                            Color.clear.frame(width: 48)
                        }
                        
                        // Content
                        Text(line.content)
                            .font(DS.Typography.mono(11))
                            .foregroundStyle(DS.Colors.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 1)
                    .background(line.type.background)
                }
            }
            .padding(.vertical, DS.Spacing.sm)
        }
        .background(DS.Colors.codeBackground)
    }
    
    private func lineBackground(line: String, isOriginal: Bool) -> Color {
        // Simplified - would need proper diff algorithm for real highlighting
        .clear
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            // Progress
            let accepted = acceptedChanges.count
            let rejected = rejectedChanges.count
            let pending = changes.count - accepted - rejected
            
            HStack(spacing: DS.Spacing.lg) {
                statLabel(value: accepted, label: "Accepted", color: DS.Colors.success)
                statLabel(value: rejected, label: "Rejected", color: DS.Colors.error)
                statLabel(value: pending, label: "Pending", color: DS.Colors.accent)
            }
            
            Spacer()
            
            DSButton("Reject All", icon: "xmark.circle", style: .secondary) {
                onRejectAll()
                dismiss()
            }
            
            DSButton("Accept All", icon: "checkmark.circle", style: .primary) {
                onAcceptAll()
                dismiss()
            }
            
            DSButton("Apply Selection", icon: "checkmark", style: .accent) {
                for change in changes {
                    if acceptedChanges.contains(change.id) {
                        onAccept(change)
                    } else if rejectedChanges.contains(change.id) {
                        onReject(change)
                    }
                }
                dismiss()
            }
            .disabled(acceptedChanges.isEmpty && rejectedChanges.isEmpty)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
    }
    
    private func statLabel(value: Int, label: String, color: Color) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Text("\(value)")
                .font(DS.Typography.headline)
                .foregroundStyle(color)
            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
        }
    }
    
    // MARK: - Navigation
    
    private func navigateToNext() {
        if currentChangeIndex < changes.count - 1 {
            currentChangeIndex += 1
        }
    }
    
    private func navigateToPrevious() {
        if currentChangeIndex > 0 {
            currentChangeIndex -= 1
        }
    }
    
    private func navigateToNextPending() {
        // Find next pending change
        for i in (currentChangeIndex + 1)..<changes.count {
            if statusForChange(changes[i]) == .pending {
                currentChangeIndex = i
                return
            }
        }
        // Wrap around
        for i in 0..<currentChangeIndex {
            if statusForChange(changes[i]) == .pending {
                currentChangeIndex = i
                return
            }
        }
    }
}

// MARK: - Supporting Types

struct ProposedChange: Identifiable {
    let id = UUID()
    let filename: String
    let changeType: ChangeType
    let additions: Int
    let deletions: Int
    let originalLines: [String]
    let modifiedLines: [String]
    let unifiedDiff: [AgentDiffLine]
    
    enum ChangeType {
        case added, modified, deleted
        
        var icon: String {
            switch self {
            case .added: return "plus.circle"
            case .modified: return "pencil.circle"
            case .deleted: return "minus.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .added: return DS.Colors.success
            case .modified: return DS.Colors.accent
            case .deleted: return DS.Colors.error
            }
        }
    }
}

struct AgentDiffLine: Identifiable {
    let id = UUID()
    let type: LineType
    let lineNumber: Int?
    let content: String
    
    enum LineType {
        case context, addition, deletion, hunk
        
        var indicator: String {
            switch self {
            case .context: return " "
            case .addition: return "+"
            case .deletion: return "-"
            case .hunk: return "@"
            }
        }
        
        var color: Color {
            switch self {
            case .context: return DS.Colors.secondaryText
            case .addition: return DS.Colors.success
            case .deletion: return DS.Colors.error
            case .hunk: return DS.Colors.accent
            }
        }
        
        var background: Color {
            switch self {
            case .context: return .clear
            case .addition: return DS.Colors.success.opacity(0.1)
            case .deletion: return DS.Colors.error.opacity(0.1)
            case .hunk: return DS.Colors.accent.opacity(0.1)
            }
        }
    }
}

// MARK: - File Change Row

struct FileChangeRow: View {
    let change: ProposedChange
    let isSelected: Bool
    let status: AgentEditReviewView.ChangeStatus
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DS.Spacing.sm) {
                // Status indicator
                Image(systemName: statusIcon)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                    .frame(width: 16)
                
                // Change type indicator
                Image(systemName: change.changeType.icon)
                    .font(.caption2)
                    .foregroundStyle(change.changeType.color)
                
                // Filename
                Text(change.filename.components(separatedBy: "/").last ?? change.filename)
                    .font(DS.Typography.caption)
                    .lineLimit(1)
                
                Spacer()
                
                // Stats
                HStack(spacing: 2) {
                    Text("+\(change.additions)")
                        .foregroundStyle(DS.Colors.success)
                    Text("-\(change.deletions)")
                        .foregroundStyle(DS.Colors.error)
                }
                .font(DS.Typography.mono(9))
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(isSelected ? DS.Colors.accent.opacity(0.2) : Color.clear)
        }
        .buttonStyle(.plain)
    }
    
    private var statusIcon: String {
        switch status {
        case .pending: return "circle"
        case .accepted: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .pending: return DS.Colors.tertiaryText
        case .accepted: return DS.Colors.success
        case .rejected: return DS.Colors.error
        }
    }
}

// Preview removed - use Xcode previews instead
