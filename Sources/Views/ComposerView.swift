import SwiftUI

// MARK: - Composer View
// Multi-file agent like Cursor's Composer
// Shows proposed changes across multiple files with accept/reject

struct ComposerView: View {
    @Environment(AppState.self) private var appState
    @State private var composerState = ComposerState()
    @State private var prompt = ""
    @State private var isGenerating = false
    @State private var showFullPreview = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            DSDivider()
            
            if composerState.changes.isEmpty && !isGenerating {
                // Input view
                inputView
            } else {
                // Changes preview
                changesView
            }
        }
        .background(DS.Colors.background)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "wand.and.stars")
                .font(.title2)
                .foregroundStyle(DS.Colors.accent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Composer")
                    .font(DS.Typography.headline)
                
                Text("Multi-file AI assistant")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            
            Spacer()
            
            if !composerState.changes.isEmpty {
                HStack(spacing: DS.Spacing.sm) {
                    Button("Accept All") {
                        acceptAllChanges()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Reject All") {
                        rejectAllChanges()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
    }
    
    // MARK: - Input View
    
    private var inputView: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(DS.Colors.accent.opacity(0.5))
            
            Text("What would you like to build?")
                .font(DS.Typography.title2)
            
            Text("Describe your changes and Composer will propose\nedits across multiple files.")
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.secondaryText)
                .multilineTextAlignment(.center)
            
            // Input field
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                TextEditor(text: $prompt)
                    .font(DS.Typography.body)
                    .frame(height: 120)
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .stroke(DS.Colors.border, lineWidth: 1)
                    )
                
                HStack {
                    // Context indicators
                    if let root = appState.rootFolder {
                        Label(root.lastPathComponent, systemImage: "folder")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                    
                    Spacer()
                    
                    Button {
                        generateChanges()
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            if isGenerating {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            Text(isGenerating ? "Generating..." : "Generate")
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(prompt.isEmpty || isGenerating)
                }
            }
            .frame(maxWidth: 600)
            .padding(.horizontal, DS.Spacing.xl)
            
            // Examples
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Examples")
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(DS.Colors.secondaryText)
                
                HStack(spacing: DS.Spacing.sm) {
                    ExampleChip(text: "Add error handling to all API calls") {
                        prompt = "Add error handling to all API calls"
                    }
                    
                    ExampleChip(text: "Create unit tests for the auth module") {
                        prompt = "Create unit tests for the auth module"
                    }
                    
                    ExampleChip(text: "Refactor to use async/await") {
                        prompt = "Refactor to use async/await"
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            
            Spacer()
        }
    }
    
    // MARK: - Changes View
    
    private var changesView: some View {
        HSplitView {
            // Files list
            VStack(spacing: 0) {
                HStack {
                    Text("Changed Files")
                        .font(DS.Typography.caption.weight(.semibold))
                    
                    Spacer()
                    
                    Text("\(composerState.acceptedCount)/\(composerState.changes.count)")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                .padding(DS.Spacing.md)
                .background(DS.Colors.surface)
                
                DSDivider()
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(composerState.changes) { change in
                            ComposerFileChangeRow(
                                change: change,
                                isSelected: composerState.selectedChange?.id == change.id
                            ) {
                                composerState.selectedChange = change
                            } onAccept: {
                                acceptChange(change)
                            } onReject: {
                                rejectChange(change)
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
            
            // Diff view
            if let change = composerState.selectedChange {
                DiffPreviewView(change: change)
            } else {
                VStack {
                    Spacer()
                    Text("Select a file to preview changes")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.secondaryText)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func generateChanges() {
        guard !prompt.isEmpty else { return }
        
        isGenerating = true
        
        // This would integrate with the agent to generate multi-file changes
        // For now, simulate with placeholder
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                // Placeholder changes
                composerState.changes = [
                    FileChange(
                        id: UUID(),
                        path: "Sources/Services/ExampleService.swift",
                        changeType: FileChange.ChangeType.modified,
                        originalContent: "// Original content",
                        proposedContent: "// Modified content with error handling",
                        hunks: [
                            ComposerDiffHunk(
                                startLine: 10,
                                lines: [
                                    ComposerDiffLine(type: .context, content: "func fetchData() {"),
                                    ComposerDiffLine(type: .removed, content: "    let data = api.get()"),
                                    ComposerDiffLine(type: .added, content: "    do {"),
                                    ComposerDiffLine(type: .added, content: "        let data = try api.get()"),
                                    ComposerDiffLine(type: .added, content: "    } catch {"),
                                    ComposerDiffLine(type: .added, content: "        print(\"Error: \\(error)\")"),
                                    ComposerDiffLine(type: .added, content: "    }"),
                                    ComposerDiffLine(type: .context, content: "}")
                                ]
                            )
                        ],
                        status: FileChange.Status.pending
                    )
                ]
                composerState.selectedChange = composerState.changes.first
                isGenerating = false
            }
        }
    }
    
    private func acceptChange(_ change: FileChange) {
        if let index = composerState.changes.firstIndex(where: { $0.id == change.id }) {
            composerState.changes[index].status = .accepted
        }
    }
    
    private func rejectChange(_ change: FileChange) {
        if let index = composerState.changes.firstIndex(where: { $0.id == change.id }) {
            composerState.changes[index].status = .rejected
        }
    }
    
    private func acceptAllChanges() {
        for i in composerState.changes.indices {
            composerState.changes[i].status = .accepted
        }
        applyAcceptedChanges()
    }
    
    private func rejectAllChanges() {
        composerState.changes = []
        composerState.selectedChange = nil
        prompt = ""
    }
    
    private func applyAcceptedChanges() {
        guard let root = appState.rootFolder else { return }
        
        // Create checkpoint before applying
        _ = try? appState.checkpointService.createAutoCheckpoint(reason: "Composer changes")
        
        for change in composerState.changes where change.status == .accepted {
            let fileURL = root.appendingPathComponent(change.path)
            appState.fileSystemService.writeFile(content: change.proposedContent, to: fileURL)
        }
        
        appState.showSuccess("Applied \(composerState.acceptedCount) changes")
        composerState.changes = []
        composerState.selectedChange = nil
        prompt = ""
    }
}

// MARK: - State

@Observable
class ComposerState {
    var changes: [FileChange] = []
    var selectedChange: FileChange?
    
    var acceptedCount: Int {
        changes.filter { $0.status == .accepted }.count
    }
}

// MARK: - Models

struct FileChange: Identifiable {
    let id: UUID
    let path: String
    let changeType: ChangeType
    let originalContent: String
    let proposedContent: String
    let hunks: [ComposerDiffHunk]
    var status: Status
    
    enum ChangeType {
        case created, modified, deleted
        
        var icon: String {
            switch self {
            case .created: return "plus.circle"
            case .modified: return "pencil.circle"
            case .deleted: return "minus.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .created: return DS.Colors.success
            case .modified: return DS.Colors.warning
            case .deleted: return DS.Colors.error
            }
        }
    }
    
    enum Status {
        case pending, accepted, rejected
    }
}

struct ComposerDiffHunk {
    let startLine: Int
    let lines: [ComposerDiffLine]
}

struct ComposerDiffLine {
    let type: LineType
    let content: String
    
    enum LineType {
        case context, added, removed
        
        var color: Color {
            switch self {
            case .context: return DS.Colors.text
            case .added: return DS.Colors.success
            case .removed: return DS.Colors.error
            }
        }
        
        var background: Color {
            switch self {
            case .context: return Color.clear
            case .added: return DS.Colors.success.opacity(0.1)
            case .removed: return DS.Colors.error.opacity(0.1)
            }
        }
        
        var prefix: String {
            switch self {
            case .context: return " "
            case .added: return "+"
            case .removed: return "-"
            }
        }
    }
}

// MARK: - Composer File Change Row

struct ComposerFileChangeRow: View {
    let change: FileChange
    let isSelected: Bool
    let onSelect: () -> Void
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DS.Spacing.sm) {
                // Status indicator
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .frame(width: 20)
                
                // File icon
                Image(systemName: change.changeType.icon)
                    .foregroundStyle(change.changeType.color)
                
                // Path
                Text(change.path.split(separator: "/").last.map(String.init) ?? change.path)
                    .font(DS.Typography.callout)
                    .lineLimit(1)
                
                Spacer()
                
                // Actions
                if change.status == .pending {
                    HStack(spacing: DS.Spacing.xs) {
                        Button(action: onAccept) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundStyle(DS.Colors.success)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: onReject) {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundStyle(DS.Colors.error)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(isSelected ? DS.Colors.accent.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }
    
    private var statusIcon: String {
        switch change.status {
        case .pending: return "circle"
        case .accepted: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch change.status {
        case .pending: return DS.Colors.secondaryText
        case .accepted: return DS.Colors.success
        case .rejected: return DS.Colors.error
        }
    }
}

// MARK: - Diff Preview View

struct DiffPreviewView: View {
    let change: FileChange
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: change.changeType.icon)
                    .foregroundStyle(change.changeType.color)
                
                Text(change.path)
                    .font(DS.Typography.mono(12))
                    .lineLimit(1)
                
                Spacer()
                
                // Line count
                let allLines = change.hunks.flatMap { $0.lines }
                let addedLines = allLines.filter { $0.type == .added }.count
                let removedLines = allLines.filter { $0.type == .removed }.count
                
                HStack(spacing: DS.Spacing.sm) {
                    Text("+\(addedLines)")
                        .foregroundStyle(DS.Colors.success)
                    Text("-\(removedLines)")
                        .foregroundStyle(DS.Colors.error)
                }
                .font(DS.Typography.mono(11))
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surface)
            
            DSDivider()
            
            // Diff content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(change.hunks.indices, id: \.self) { hunkIndex in
                        let hunk = change.hunks[hunkIndex]
                        
                        // Hunk header
                        Text("@@ -\(hunk.startLine) @@")
                            .font(DS.Typography.mono(11))
                            .foregroundStyle(DS.Colors.info)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DS.Colors.info.opacity(0.1))
                        
                        // Lines
                        ForEach(hunk.lines.indices, id: \.self) { lineIndex in
                            let line = hunk.lines[lineIndex]
                            
                            HStack(spacing: 0) {
                                Text(line.type.prefix)
                                    .font(DS.Typography.mono(12))
                                    .foregroundStyle(line.type.color)
                                    .frame(width: 20)
                                
                                Text(line.content)
                                    .font(DS.Typography.mono(12))
                                    .foregroundStyle(line.type.color)
                            }
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(line.type.background)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Example Chip

struct ExampleChip: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(DS.Colors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
