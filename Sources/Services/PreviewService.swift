import Foundation

// MARK: - Preview Service (Dry-Run Mode)
// Captures proposed file changes as diffs before applying.
// Users approve/reject individual changes. Matches CLI --dry-run / --diff modes.

@Observable
final class PreviewService {

    // MARK: - Types

    struct ProposedChange: Identifiable {
        let id = UUID()
        let filePath: String
        let changeType: ChangeType
        let originalContent: String?
        let proposedContent: String
        var approved: Bool = false

        enum ChangeType: String {
            case create = "Create"
            case modify = "Modify"
            case delete = "Delete"

            var icon: String {
                switch self {
                case .create: return "plus.circle.fill"
                case .modify: return "pencil.circle.fill"
                case .delete: return "minus.circle.fill"
                }
            }
        }

        /// Unified diff between original and proposed content
        var diff: String {
            guard let original = originalContent else {
                return proposedContent.components(separatedBy: .newlines)
                    .map { "+ \($0)" }
                    .joined(separator: "\n")
            }

            return Self.generateDiff(original: original, proposed: proposedContent)
        }

        static func generateDiff(original: String, proposed: String) -> String {
            let oldLines = original.components(separatedBy: .newlines)
            let newLines = proposed.components(separatedBy: .newlines)

            var result: [String] = []
            let maxLines = max(oldLines.count, newLines.count)

            for i in 0..<maxLines {
                let oldLine = i < oldLines.count ? oldLines[i] : nil
                let newLine = i < newLines.count ? newLines[i] : nil

                if oldLine == newLine {
                    result.append("  \(oldLine ?? "")")
                } else {
                    if let old = oldLine {
                        result.append("- \(old)")
                    }
                    if let new = newLine {
                        result.append("+ \(new)")
                    }
                }
            }

            return result.joined(separator: "\n")
        }
    }

    // MARK: - State

    private(set) var isPreviewMode: Bool = false
    private(set) var proposedChanges: [ProposedChange] = []
    private let fileSystemService: FileSystemService

    var hasChanges: Bool { !proposedChanges.isEmpty }
    var approvedCount: Int { proposedChanges.filter(\.approved).count }
    var totalCount: Int { proposedChanges.count }

    init(fileSystemService: FileSystemService) {
        self.fileSystemService = fileSystemService
    }

    // MARK: - Mode Control

    func enablePreviewMode() {
        isPreviewMode = true
        proposedChanges = []
    }

    func disablePreviewMode() {
        isPreviewMode = false
        proposedChanges = []
    }

    // MARK: - Capture Changes

    /// Intercept a file write and capture it as a proposed change
    func captureWrite(filePath: String, content: String, rootFolder: URL?) -> Bool {
        guard isPreviewMode else { return false }

        let url: URL
        if filePath.hasPrefix("/") {
            url = URL(fileURLWithPath: filePath)
        } else if let root = rootFolder {
            url = root.appendingPathComponent(filePath)
        } else {
            url = URL(fileURLWithPath: filePath)
        }

        let existingContent = fileSystemService.readFile(at: url)
        let changeType: ProposedChange.ChangeType = existingContent != nil ? .modify : .create

        let change = ProposedChange(
            filePath: filePath,
            changeType: changeType,
            originalContent: existingContent,
            proposedContent: content
        )

        proposedChanges.append(change)
        return true // Signal that the write was captured, not executed
    }

    /// Capture a file deletion
    func captureDelete(filePath: String, rootFolder: URL?) -> Bool {
        guard isPreviewMode else { return false }

        let url: URL
        if filePath.hasPrefix("/") {
            url = URL(fileURLWithPath: filePath)
        } else if let root = rootFolder {
            url = root.appendingPathComponent(filePath)
        } else {
            url = URL(fileURLWithPath: filePath)
        }

        let existingContent = fileSystemService.readFile(at: url)

        let change = ProposedChange(
            filePath: filePath,
            changeType: .delete,
            originalContent: existingContent,
            proposedContent: ""
        )

        proposedChanges.append(change)
        return true
    }

    // MARK: - Approve / Reject

    func approveChange(_ change: ProposedChange) {
        if let idx = proposedChanges.firstIndex(where: { $0.id == change.id }) {
            proposedChanges[idx].approved = true
        }
    }

    func rejectChange(_ change: ProposedChange) {
        if let idx = proposedChanges.firstIndex(where: { $0.id == change.id }) {
            proposedChanges[idx].approved = false
        }
    }

    func approveAll() {
        for i in proposedChanges.indices {
            proposedChanges[i].approved = true
        }
    }

    func rejectAll() {
        for i in proposedChanges.indices {
            proposedChanges[i].approved = false
        }
    }

    // MARK: - Apply Approved

    /// Apply all approved changes to disk
    func applyApproved(rootFolder: URL?) -> Int {
        var applied = 0

        for change in proposedChanges where change.approved {
            let url: URL
            if change.filePath.hasPrefix("/") {
                url = URL(fileURLWithPath: change.filePath)
            } else if let root = rootFolder {
                url = root.appendingPathComponent(change.filePath)
            } else {
                continue
            }

            switch change.changeType {
            case .create, .modify:
                // Ensure parent directory exists
                let dir = url.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                fileSystemService.writeFile(content: change.proposedContent, to: url)
                applied += 1
            case .delete:
                try? FileManager.default.removeItem(at: url)
                applied += 1
            }
        }

        proposedChanges.removeAll()
        isPreviewMode = false
        return applied
    }

    /// Discard all proposed changes
    func discardAll() {
        proposedChanges.removeAll()
    }
}
