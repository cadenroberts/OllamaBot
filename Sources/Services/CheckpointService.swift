import Foundation
import SwiftUI

// MARK: - Checkpoint Service
// Windsurf-style checkpoint system for saving and restoring code states
// Allows users to create snapshots before AI changes and restore if needed

@Observable
final class CheckpointService {
    
    // MARK: - Types
    
    struct Checkpoint: Identifiable, Codable {
        let id: UUID
        let name: String
        let description: String
        let timestamp: Date
        let files: [SavedFile]
        let gitBranch: String?
        let gitCommit: String?
        let isAutomatic: Bool
        
        struct SavedFile: Codable {
            let relativePath: String
            let content: String
            let originalSize: Int
        }
        
        var displayDate: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: timestamp)
        }
        
        var fileCount: Int { files.count }
        var totalSize: Int { files.reduce(0) { $0 + $1.originalSize } }
    }
    
    enum CheckpointError: LocalizedError {
        case noProjectRoot
        case checkpointNotFound
        case saveFailed(String)
        case restoreFailed(String)
        case maxCheckpointsReached
        
        var errorDescription: String? {
            switch self {
            case .noProjectRoot: return "No project open"
            case .checkpointNotFound: return "Checkpoint not found"
            case .saveFailed(let msg): return "Failed to save checkpoint: \(msg)"
            case .restoreFailed(let msg): return "Failed to restore checkpoint: \(msg)"
            case .maxCheckpointsReached: return "Maximum checkpoints reached (50). Delete old checkpoints."
            }
        }
    }
    
    // MARK: - State
    
    private(set) var checkpoints: [Checkpoint] = []
    private(set) var isLoading = false
    private(set) var lastError: String?
    
    private var projectRoot: URL?
    private let maxCheckpoints = 50
    
    // MARK: - Dependencies
    
    private let fileSystemService: FileSystemService
    private let gitService: GitService
    
    init(fileSystemService: FileSystemService, gitService: GitService) {
        self.fileSystemService = fileSystemService
        self.gitService = gitService
    }
    
    // MARK: - Project Management
    
    func setProject(_ root: URL) {
        self.projectRoot = root
        loadCheckpoints()
        gitService.setWorkingDirectory(root)
    }
    
    // MARK: - Checkpoint Creation
    
    /// Create a checkpoint of all modified files
    func createCheckpoint(
        name: String,
        description: String = "",
        files: [URL]? = nil,
        isAutomatic: Bool = false
    ) throws -> Checkpoint {
        guard let root = projectRoot else {
            throw CheckpointError.noProjectRoot
        }
        
        if checkpoints.count >= maxCheckpoints {
            throw CheckpointError.maxCheckpointsReached
        }
        
        // Determine files to save
        let filesToSave: [URL]
        if let specified = files {
            filesToSave = specified
        } else {
            // Save all code files in the project
            filesToSave = fileSystemService.getAllFiles(in: root)
                .filter { isCodeFile($0.url) }
                .map { $0.url }
        }
        
        // Read file contents
        var savedFiles: [Checkpoint.SavedFile] = []
        for fileURL in filesToSave {
            if let content = fileSystemService.readFile(at: fileURL) {
                let relativePath = fileURL.path.replacingOccurrences(of: root.path + "/", with: "")
                savedFiles.append(Checkpoint.SavedFile(
                    relativePath: relativePath,
                    content: content,
                    originalSize: content.count
                ))
            }
        }
        
        // Get git info
        gitService.refresh()
        
        let checkpoint = Checkpoint(
            id: UUID(),
            name: name,
            description: description,
            timestamp: Date(),
            files: savedFiles,
            gitBranch: gitService.currentBranch.isEmpty ? nil : gitService.currentBranch,
            gitCommit: nil, // Would need to get current commit hash
            isAutomatic: isAutomatic
        )
        
        checkpoints.insert(checkpoint, at: 0)
        saveCheckpoints()
        
        return checkpoint
    }
    
    /// Create an automatic checkpoint before AI changes
    func createAutoCheckpoint(reason: String) throws -> Checkpoint {
        return try createCheckpoint(
            name: "Auto: \(reason)",
            description: "Automatic checkpoint before AI changes",
            isAutomatic: true
        )
    }
    
    // MARK: - Checkpoint Restoration
    
    /// Restore files from a checkpoint
    func restoreCheckpoint(_ checkpoint: Checkpoint, selectedFiles: Set<String>? = nil) throws {
        guard let root = projectRoot else {
            throw CheckpointError.noProjectRoot
        }
        
        let filesToRestore = selectedFiles ?? Set(checkpoint.files.map { $0.relativePath })
        
        for savedFile in checkpoint.files {
            guard filesToRestore.contains(savedFile.relativePath) else { continue }
            
            let fileURL = root.appendingPathComponent(savedFile.relativePath)
            
            // Create directory if needed
            let directory = fileURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            
            // Write content
            fileSystemService.writeFile(content: savedFile.content, to: fileURL)
        }
    }
    
    /// Preview changes that would happen on restore
    func previewRestore(_ checkpoint: Checkpoint) -> [FileChange] {
        guard let root = projectRoot else { return [] }
        
        var changes: [FileChange] = []
        
        for savedFile in checkpoint.files {
            let fileURL = root.appendingPathComponent(savedFile.relativePath)
            let currentContent = fileSystemService.readFile(at: fileURL)
            
            let changeType: FileChange.ChangeType
            if currentContent == nil {
                changeType = .created
            } else if currentContent == savedFile.content {
                changeType = .unchanged
            } else {
                changeType = .modified
            }
            
            changes.append(FileChange(
                relativePath: savedFile.relativePath,
                changeType: changeType,
                currentContent: currentContent,
                checkpointContent: savedFile.content
            ))
        }
        
        return changes
    }
    
    struct FileChange {
        let relativePath: String
        let changeType: ChangeType
        let currentContent: String?
        let checkpointContent: String
        
        enum ChangeType {
            case created, modified, deleted, unchanged
            
            var icon: String {
                switch self {
                case .created: return "plus.circle"
                case .modified: return "pencil.circle"
                case .deleted: return "minus.circle"
                case .unchanged: return "checkmark.circle"
                }
            }
            
            var color: Color {
                switch self {
                case .created: return DS.Colors.success
                case .modified: return DS.Colors.warning
                case .deleted: return DS.Colors.error
                case .unchanged: return DS.Colors.secondaryText
                }
            }
        }
    }
    
    // MARK: - Checkpoint Management
    
    /// Delete a checkpoint
    func deleteCheckpoint(_ checkpoint: Checkpoint) {
        checkpoints.removeAll { $0.id == checkpoint.id }
        saveCheckpoints()
    }
    
    /// Delete old automatic checkpoints (keep last 10)
    func pruneAutoCheckpoints() {
        let autoCheckpoints = checkpoints.filter { $0.isAutomatic }
        if autoCheckpoints.count > 10 {
            let toDelete = autoCheckpoints.suffix(autoCheckpoints.count - 10)
            for cp in toDelete {
                deleteCheckpoint(cp)
            }
        }
    }
    
    /// Rename a checkpoint
    func renameCheckpoint(_ checkpoint: Checkpoint, newName: String) {
        if let index = checkpoints.firstIndex(where: { $0.id == checkpoint.id }) {
            let updated = Checkpoint(
                id: checkpoint.id,
                name: newName,
                description: checkpoint.description,
                timestamp: checkpoint.timestamp,
                files: checkpoint.files,
                gitBranch: checkpoint.gitBranch,
                gitCommit: checkpoint.gitCommit,
                isAutomatic: false // Manual rename makes it not automatic
            )
            checkpoints[index] = updated
            saveCheckpoints()
        }
    }
    
    // MARK: - Persistence
    
    private var checkpointsDirectory: URL? {
        projectRoot?.appendingPathComponent(".obot/checkpoints")
    }
    
    private func loadCheckpoints() {
        guard let dir = checkpointsDirectory else { return }
        
        let indexFile = dir.appendingPathComponent("index.json")
        
        guard let data = try? Data(contentsOf: indexFile),
              let decoded = try? JSONDecoder().decode([Checkpoint].self, from: data) else {
            checkpoints = []
            return
        }
        
        checkpoints = decoded.sorted { $0.timestamp > $1.timestamp }
    }
    
    private func saveCheckpoints() {
        guard let dir = checkpointsDirectory else { return }
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        
        let indexFile = dir.appendingPathComponent("index.json")
        
        if let data = try? JSONEncoder().encode(checkpoints) {
            try? data.write(to: indexFile)
        }
    }
    
    // MARK: - Utilities
    
    private func isCodeFile(_ url: URL) -> Bool {
        let codeExtensions: Set<String> = [
            "swift", "ts", "tsx", "js", "jsx", "py", "rb", "go", "rs",
            "java", "kt", "cpp", "c", "h", "hpp", "cs", "php", "vue",
            "svelte", "html", "css", "scss", "less", "json", "yaml",
            "yml", "toml", "xml", "md", "txt", "sh", "bash", "zsh"
        ]
        return codeExtensions.contains(url.pathExtension.lowercased())
    }
}

// MARK: - Checkpoint View

struct CheckpointListView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedCheckpoint: CheckpointService.Checkpoint?
    @State private var showingPreview = false
    @State private var showingCreateSheet = false
    @State private var newCheckpointName = ""
    @State private var newCheckpointDescription = ""
    
    var checkpointService: CheckpointService {
        appState.checkpointService
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Checkpoints")
                        .font(DS.Typography.headline)
                    Text("Save & restore code states")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                
                Spacer()
                
                DSIconButton(icon: "plus", size: 14) {
                    showingCreateSheet = true
                }
                .help("Create checkpoint")
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surface)
            
            DSDivider()
            
            if checkpointService.checkpoints.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.sm) {
                        ForEach(checkpointService.checkpoints) { checkpoint in
                            CheckpointCard(
                                checkpoint: checkpoint,
                                onRestore: {
                                    selectedCheckpoint = checkpoint
                                    showingPreview = true
                                },
                                onDelete: {
                                    checkpointService.deleteCheckpoint(checkpoint)
                                }
                            )
                        }
                    }
                    .padding(DS.Spacing.sm)
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateCheckpointSheet(
                name: $newCheckpointName,
                description: $newCheckpointDescription
            ) {
                if let _ = try? checkpointService.createCheckpoint(
                    name: newCheckpointName.isEmpty ? "Checkpoint" : newCheckpointName,
                    description: newCheckpointDescription
                ) {
                    newCheckpointName = ""
                    newCheckpointDescription = ""
                    appState.showSuccess("Checkpoint created!")
                }
            }
        }
        .sheet(item: $selectedCheckpoint) { checkpoint in
            CheckpointPreviewSheet(
                checkpoint: checkpoint,
                changes: checkpointService.previewRestore(checkpoint)
            ) { selectedFiles in
                try? checkpointService.restoreCheckpoint(checkpoint, selectedFiles: selectedFiles)
                appState.showSuccess("Checkpoint restored!")
                selectedCheckpoint = nil
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(DS.Colors.tertiaryText)
            
            Text("No Checkpoints")
                .font(DS.Typography.headline)
            
            Text("Create checkpoints to save your code state\nbefore making changes")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
                .multilineTextAlignment(.center)
            
            Button {
                showingCreateSheet = true
            } label: {
                Label("Create Checkpoint", systemImage: "plus")
                    .font(DS.Typography.caption)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
    }
}

// MARK: - Checkpoint Card

struct CheckpointCard: View {
    let checkpoint: CheckpointService.Checkpoint
    let onRestore: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(checkpoint.isAutomatic ? DS.Colors.warning.opacity(0.1) : DS.Colors.accent.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: checkpoint.isAutomatic ? "clock" : "checkmark.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(checkpoint.isAutomatic ? DS.Colors.warning : DS.Colors.accent)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(checkpoint.name)
                    .font(DS.Typography.callout.weight(.medium))
                
                Text(checkpoint.displayDate)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                
                HStack(spacing: DS.Spacing.sm) {
                    Label("\(checkpoint.fileCount) files", systemImage: "doc")
                    if let branch = checkpoint.gitBranch {
                        Label(branch, systemImage: "arrow.triangle.branch")
                    }
                }
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.tertiaryText)
            }
            
            Spacer()
            
            // Actions
            if isHovered {
                HStack(spacing: DS.Spacing.xs) {
                    DSIconButton(icon: "arrow.uturn.backward", size: 14) {
                        onRestore()
                    }
                    .help("Restore checkpoint")
                    
                    DSIconButton(icon: "trash", size: 14) {
                        onDelete()
                    }
                    .help("Delete checkpoint")
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(isHovered ? DS.Colors.surface : DS.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.border, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Create Checkpoint Sheet

struct CreateCheckpointSheet: View {
    @Binding var name: String
    @Binding var description: String
    let onCreate: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Create Checkpoint")
                    .font(DS.Typography.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surface)
            
            DSDivider()
            
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Name")
                        .font(DS.Typography.caption.weight(.semibold))
                    TextField("Checkpoint name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Description (optional)")
                        .font(DS.Typography.caption.weight(.semibold))
                    TextField("What changes are you about to make?", text: $description)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Spacer()
                    Button("Create") {
                        onCreate()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(DS.Spacing.md)
        }
        .frame(width: 400)
    }
}

// MARK: - Checkpoint Preview Sheet

struct CheckpointPreviewSheet: View {
    let checkpoint: CheckpointService.Checkpoint
    let changes: [CheckpointService.FileChange]
    let onRestore: (Set<String>?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFiles: Set<String> = []
    @State private var selectAll = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Restore Checkpoint")
                        .font(DS.Typography.headline)
                    Text(checkpoint.name)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surface)
            
            DSDivider()
            
            // File list
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Toggle("Select All", isOn: $selectAll)
                    .onChange(of: selectAll) { _, newValue in
                        if newValue {
                            selectedFiles = Set(changes.map { $0.relativePath })
                        } else {
                            selectedFiles.removeAll()
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(changes, id: \.relativePath) { change in
                            FileChangeRow(
                                change: change,
                                isSelected: selectedFiles.contains(change.relativePath)
                            ) {
                                if selectedFiles.contains(change.relativePath) {
                                    selectedFiles.remove(change.relativePath)
                                } else {
                                    selectedFiles.insert(change.relativePath)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, DS.Spacing.sm)
            
            DSDivider()
            
            // Actions
            HStack {
                Text("\(selectedFiles.count) files selected")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                
                Spacer()
                
                Button("Restore Selected") {
                    onRestore(selectedFiles.isEmpty ? nil : selectedFiles)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedFiles.isEmpty)
            }
            .padding(DS.Spacing.md)
        }
        .frame(width: 500, height: 400)
        .onAppear {
            selectedFiles = Set(changes.map { $0.relativePath })
        }
    }
}

struct FileChangeRow: View {
    let change: CheckpointService.FileChange
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.secondaryText)
                
                Image(systemName: change.changeType.icon)
                    .foregroundStyle(change.changeType.color)
                
                Text(change.relativePath)
                    .font(DS.Typography.mono(12))
                    .lineLimit(1)
                
                Spacer()
                
                Text(change.changeType == .unchanged ? "No changes" : "Will be restored")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(isSelected ? DS.Colors.accent.opacity(0.05) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
