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
                    .foregroundStyle(DS.Colors.text)
                    .scrollContentBackground(.hidden)
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
        
        Task {
            do {
                // Build context about the project
                let projectContext = buildProjectContext()
                
                // Create the composer prompt
                let composerPrompt = """
                You are a code composer. The user wants to make changes across multiple files.
                
                PROJECT CONTEXT:
                \(projectContext)
                
                USER REQUEST:
                \(prompt)
                
                Analyze the codebase and propose specific file changes. For each file:
                1. Specify the file path
                2. Whether it's a new file, modification, or deletion
                3. The complete new content for the file
                
                Format your response as:
                
                FILE: path/to/file.swift
                ACTION: modify|create|delete
                CONTENT:
                ```swift
                // Full file content here
                ```
                
                ---
                
                Propose changes for all relevant files:
                """
                
                let messages: [(String, String)] = [
                    ("system", "You are an expert code composer that proposes multi-file changes."),
                    ("user", composerPrompt)
                ]
                
                var fullResponse = ""
                
                // Stream the response
                for try await chunk in appState.ollamaService.chat(
                    model: .qwen3,
                    messages: messages,
                    context: nil,
                    taskType: .coding
                ) {
                    fullResponse += chunk
                }
                
                // Parse the response into file changes
                let changes = parseComposerResponse(fullResponse)
                
                await MainActor.run {
                    composerState.changes = changes
                    composerState.selectedChange = changes.first
                    isGenerating = false
                }
                
            } catch {
                await MainActor.run {
                    isGenerating = false
                    appState.showError("Composer failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func buildProjectContext() -> String {
        guard let root = appState.rootFolder else {
            return "No project open"
        }
        
        var context = "Project: \(root.lastPathComponent)\n\n"
        
        // Add file structure
        let files = appState.fileSystemService.getAllFiles(in: root)
        let codeFiles = files.filter { isCodeFile($0.url) }
        
        context += "Files (\(codeFiles.count) code files):\n"
        for file in codeFiles.prefix(50) {
            let relativePath = file.url.path.replacingOccurrences(of: root.path + "/", with: "")
            context += "  \(relativePath)\n"
        }
        
        // Add current editor content if relevant
        if let currentFile = appState.selectedFile {
            let relativePath = currentFile.url.path.replacingOccurrences(of: root.path + "/", with: "")
            context += "\nCurrently open: \(relativePath)\n"
            if !appState.editorContent.isEmpty {
                context += "Content preview:\n\(appState.editorContent.prefix(1000))...\n"
            }
        }
        
        return context
    }
    
    private func isCodeFile(_ url: URL) -> Bool {
        let codeExtensions: Set<String> = [
            "swift", "ts", "tsx", "js", "jsx", "py", "rb", "go", "rs",
            "java", "kt", "cpp", "c", "h", "cs", "php", "vue", "svelte"
        ]
        return codeExtensions.contains(url.pathExtension.lowercased())
    }
    
    private func parseComposerResponse(_ response: String) -> [FileChange] {
        var changes: [FileChange] = []
        
        // Split by file markers
        let filePattern = #"FILE:\s*(.+)\nACTION:\s*(modify|create|delete)"#
        let contentPattern = #"```[\w]*\n([\s\S]*?)```"#
        
        guard let fileRegex = try? NSRegularExpression(pattern: filePattern, options: .caseInsensitive),
              let contentRegex = try? NSRegularExpression(pattern: contentPattern) else {
            return changes
        }
        
        let nsResponse = response as NSString
        let fileMatches = fileRegex.matches(in: response, range: NSRange(location: 0, length: nsResponse.length))
        
        for (index, match) in fileMatches.enumerated() {
            guard match.numberOfRanges >= 3 else { continue }
            
            let pathRange = match.range(at: 1)
            let actionRange = match.range(at: 2)
            
            let path = nsResponse.substring(with: pathRange).trimmingCharacters(in: .whitespaces)
            let actionStr = nsResponse.substring(with: actionRange).lowercased()
            
            // Find content for this file (between this match and next)
            let searchStart = match.range.upperBound
            let searchEnd = index + 1 < fileMatches.count ? fileMatches[index + 1].range.lowerBound : nsResponse.length
            let searchRange = NSRange(location: searchStart, length: searchEnd - searchStart)
            
            var proposedContent = ""
            if let contentMatch = contentRegex.firstMatch(in: response, range: searchRange),
               contentMatch.numberOfRanges >= 2 {
                proposedContent = nsResponse.substring(with: contentMatch.range(at: 1))
            }
            
            // Get original content if file exists
            var originalContent = ""
            if let root = appState.rootFolder {
                let fileURL = root.appendingPathComponent(path)
                originalContent = appState.fileSystemService.readFile(at: fileURL) ?? ""
            }
            
            // Generate diff hunks
            let hunks = generateDiffHunks(original: originalContent, proposed: proposedContent)
            
            let changeType: FileChange.ChangeType
            switch actionStr {
            case "create": changeType = .created
            case "delete": changeType = .deleted
            default: changeType = .modified
            }
            
            changes.append(FileChange(
                id: UUID(),
                path: path,
                changeType: changeType,
                originalContent: originalContent,
                proposedContent: proposedContent,
                hunks: hunks,
                status: .pending
            ))
        }
        
        return changes
    }
    
    private func generateDiffHunks(original: String, proposed: String) -> [ComposerDiffHunk] {
        let originalLines = original.components(separatedBy: .newlines)
        let proposedLines = proposed.components(separatedBy: .newlines)
        
        var lines: [ComposerDiffLine] = []
        
        // Simple diff: show removed then added (not optimal but functional)
        if !originalLines.isEmpty && originalLines != [""] {
            for line in originalLines.prefix(20) {
                lines.append(ComposerDiffLine(type: .removed, content: line))
            }
            if originalLines.count > 20 {
                lines.append(ComposerDiffLine(type: .context, content: "... (\(originalLines.count - 20) more lines)"))
            }
        }
        
        for line in proposedLines.prefix(50) {
            lines.append(ComposerDiffLine(type: .added, content: line))
        }
        if proposedLines.count > 50 {
            lines.append(ComposerDiffLine(type: .context, content: "... (\(proposedLines.count - 50) more lines)"))
        }
        
        return [ComposerDiffHunk(startLine: 1, lines: lines)]
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
