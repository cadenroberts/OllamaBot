import Foundation
import SwiftUI

// MARK: - Git Service

@Observable
class GitService {
    var isGitRepo = false
    var currentBranch = ""
    var status: GitStatus?
    var branches: [String] = []
    var remotes: [String] = []
    var stashCount = 0
    
    var isLoading = false
    var lastError: String?
    
    private var workingDirectory: URL?
    private let queue = DispatchQueue(label: "com.ollamabot.git", qos: .userInitiated)
    
    // MARK: - Public API
    
    func setWorkingDirectory(_ url: URL?) {
        workingDirectory = url
        if url != nil {
            refresh()
        } else {
            reset()
        }
    }
    
    func refresh() {
        guard let dir = workingDirectory else { return }
        
        isLoading = true
        lastError = nil
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Check if git repo
            let isRepo = self.runGit(["rev-parse", "--is-inside-work-tree"], in: dir) == "true"
            
            DispatchQueue.main.async {
                self.isGitRepo = isRepo
            }
            
            guard isRepo else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            // Get current branch
            let branch = self.runGit(["branch", "--show-current"], in: dir)
            
            // Get status
            let statusOutput = self.runGit(["status", "--porcelain", "-b"], in: dir)
            let parsedStatus = self.parseStatus(statusOutput)
            
            // Get branches
            let branchOutput = self.runGit(["branch", "-a"], in: dir)
            let parsedBranches = self.parseBranches(branchOutput)
            
            // Get remotes
            let remoteOutput = self.runGit(["remote", "-v"], in: dir)
            let parsedRemotes = self.parseRemotes(remoteOutput)
            
            // Get stash count
            let stashOutput = self.runGit(["stash", "list"], in: dir)
            let stashLines = stashOutput.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            DispatchQueue.main.async {
                self.currentBranch = branch
                self.status = parsedStatus
                self.branches = parsedBranches
                self.remotes = parsedRemotes
                self.stashCount = stashLines.count
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Git Operations
    
    func stage(file: String) {
        guard let dir = workingDirectory else { return }
        _ = runGit(["add", file], in: dir)
        refresh()
    }
    
    func unstage(file: String) {
        guard let dir = workingDirectory else { return }
        _ = runGit(["reset", "HEAD", file], in: dir)
        refresh()
    }
    
    func stageAll() {
        guard let dir = workingDirectory else { return }
        _ = runGit(["add", "-A"], in: dir)
        refresh()
    }
    
    func unstageAll() {
        guard let dir = workingDirectory else { return }
        _ = runGit(["reset", "HEAD"], in: dir)
        refresh()
    }
    
    func commit(message: String) -> Bool {
        guard let dir = workingDirectory, !message.isEmpty else { return false }
        let result = runGit(["commit", "-m", message], in: dir)
        refresh()
        return !result.contains("error")
    }
    
    func checkout(branch: String) -> Bool {
        guard let dir = workingDirectory else { return false }
        let result = runGit(["checkout", branch], in: dir)
        refresh()
        return !result.contains("error")
    }
    
    func createBranch(name: String) -> Bool {
        guard let dir = workingDirectory, !name.isEmpty else { return false }
        let result = runGit(["checkout", "-b", name], in: dir)
        refresh()
        return !result.contains("error")
    }
    
    func pull() -> Bool {
        guard let dir = workingDirectory else { return false }
        let result = runGit(["pull"], in: dir)
        refresh()
        return !result.contains("error") && !result.contains("fatal")
    }
    
    func push() -> Bool {
        guard let dir = workingDirectory else { return false }
        let result = runGit(["push"], in: dir)
        refresh()
        return !result.contains("error") && !result.contains("fatal")
    }
    
    func discard(file: String) {
        guard let dir = workingDirectory else { return }
        _ = runGit(["checkout", "--", file], in: dir)
        refresh()
    }
    
    func getDiff(file: String, staged: Bool = false) -> String {
        guard let dir = workingDirectory else { return "" }
        let args = staged ? ["diff", "--cached", file] : ["diff", file]
        return runGit(args, in: dir)
    }
    
    func getFileDiff(file: String) -> FileDiff? {
        guard let dir = workingDirectory else { return nil }
        
        let diff = getDiff(file: file)
        guard !diff.isEmpty else { return nil }
        
        return parseDiff(diff, filename: file)
    }
    
    func getLog(count: Int = 20) -> [GitCommit] {
        guard let dir = workingDirectory else { return [] }
        
        let format = "%H|%h|%s|%an|%ae|%ad"
        let output = runGit(["log", "-\(count)", "--format=\(format)", "--date=short"], in: dir)
        
        return output.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .compactMap { line -> GitCommit? in
                let parts = line.components(separatedBy: "|")
                guard parts.count >= 6 else { return nil }
                return GitCommit(
                    hash: parts[0],
                    shortHash: parts[1],
                    message: parts[2],
                    author: parts[3],
                    email: parts[4],
                    date: parts[5]
                )
            }
    }
    
    // MARK: - Private Helpers
    
    private func runGit(_ args: [String], in directory: URL) -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = directory
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }
    
    private func parseStatus(_ output: String) -> GitStatus {
        var staged: [GitFileChange] = []
        var unstaged: [GitFileChange] = []
        var untracked: [String] = []
        var ahead = 0
        var behind = 0
        
        for line in output.components(separatedBy: .newlines) {
            guard line.count >= 2 else { continue }
            
            // Parse branch tracking info
            if line.hasPrefix("##") {
                if line.contains("[ahead ") {
                    if let match = line.range(of: #"ahead (\d+)"#, options: .regularExpression) {
                        ahead = Int(line[match].dropFirst(6)) ?? 0
                    }
                }
                if line.contains("behind ") {
                    if let match = line.range(of: #"behind (\d+)"#, options: .regularExpression) {
                        behind = Int(line[match].dropFirst(7)) ?? 0
                    }
                }
                continue
            }
            
            let indexStatus = line[line.startIndex]
            let workStatus = line[line.index(after: line.startIndex)]
            let filename = String(line.dropFirst(3))
            
            // Staged changes
            if indexStatus != " " && indexStatus != "?" {
                staged.append(GitFileChange(
                    filename: filename,
                    status: GitChangeStatus(rawValue: String(indexStatus)) ?? .modified
                ))
            }
            
            // Unstaged changes
            if workStatus != " " && workStatus != "?" {
                unstaged.append(GitFileChange(
                    filename: filename,
                    status: GitChangeStatus(rawValue: String(workStatus)) ?? .modified
                ))
            }
            
            // Untracked
            if indexStatus == "?" {
                untracked.append(filename)
            }
        }
        
        return GitStatus(
            staged: staged,
            unstaged: unstaged,
            untracked: untracked,
            ahead: ahead,
            behind: behind
        )
    }
    
    private func parseBranches(_ output: String) -> [String] {
        output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.hasPrefix("* ") ? String($0.dropFirst(2)) : $0 }
            .filter { !$0.isEmpty && !$0.contains("->") }
    }
    
    private func parseRemotes(_ output: String) -> [String] {
        var remotes = Set<String>()
        for line in output.components(separatedBy: .newlines) {
            if let name = line.components(separatedBy: .whitespaces).first {
                remotes.insert(name)
            }
        }
        return Array(remotes).sorted()
    }
    
    private func parseDiff(_ diff: String, filename: String) -> FileDiff {
        var hunks: [DiffHunk] = []
        var currentHunk: DiffHunk?
        var lineNumber = 0
        
        for line in diff.components(separatedBy: .newlines) {
            if line.hasPrefix("@@") {
                // Save previous hunk
                if let hunk = currentHunk {
                    hunks.append(hunk)
                }
                
                // Parse hunk header
                // @@ -start,count +start,count @@
                currentHunk = DiffHunk(header: line, lines: [])
                lineNumber = 0
            } else if currentHunk != nil {
                let type: DiffLineType
                if line.hasPrefix("+") {
                    type = .added
                } else if line.hasPrefix("-") {
                    type = .removed
                } else {
                    type = .context
                }
                
                currentHunk?.lines.append(DiffLine(
                    content: String(line.dropFirst()),
                    type: type,
                    lineNumber: lineNumber
                ))
                lineNumber += 1
            }
        }
        
        // Save last hunk
        if let hunk = currentHunk {
            hunks.append(hunk)
        }
        
        return FileDiff(filename: filename, hunks: hunks)
    }
    
    private func reset() {
        isGitRepo = false
        currentBranch = ""
        status = nil
        branches = []
        remotes = []
        stashCount = 0
    }
}

// MARK: - Git Models

struct GitStatus {
    let staged: [GitFileChange]
    let unstaged: [GitFileChange]
    let untracked: [String]
    let ahead: Int
    let behind: Int
    
    var hasChanges: Bool {
        !staged.isEmpty || !unstaged.isEmpty || !untracked.isEmpty
    }
    
    var stagedCount: Int { staged.count }
    var unstagedCount: Int { unstaged.count + untracked.count }
    var totalChanges: Int { staged.count + unstaged.count + untracked.count }
    
    // Convenience accessors for sidebar view (as filenames)
    var modified: [String] { unstaged.map(\.filename) }
}

struct GitFileChange: Identifiable {
    let id = UUID()
    let filename: String
    let status: GitChangeStatus
}

enum GitChangeStatus: String {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case untracked = "?"
    
    var icon: String {
        switch self {
        case .modified: return "pencil"
        case .added: return "plus"
        case .deleted: return "minus"
        case .renamed: return "arrow.right"
        case .copied: return "doc.on.doc"
        case .untracked: return "questionmark"
        }
    }
    
    var color: Color {
        switch self {
        case .modified: return DS.Colors.warning
        case .added: return DS.Colors.success
        case .deleted: return DS.Colors.error
        case .renamed: return DS.Colors.info
        case .copied: return DS.Colors.info
        case .untracked: return DS.Colors.secondaryText
        }
    }
}

struct GitCommit: Identifiable {
    let id = UUID()
    let hash: String
    let shortHash: String
    let message: String
    let author: String
    let email: String
    let date: String
}

struct FileDiff {
    let filename: String
    let hunks: [DiffHunk]
}

struct DiffHunk {
    let header: String
    var lines: [DiffLine]
}

struct DiffLine: Identifiable {
    let id = UUID()
    let content: String
    let type: DiffLineType
    let lineNumber: Int
}

enum DiffLineType {
    case added
    case removed
    case context
    
    var color: Color {
        switch self {
        case .added: return DS.Colors.success
        case .removed: return DS.Colors.error
        case .context: return DS.Colors.text
        }
    }
    
    var background: Color {
        switch self {
        case .added: return DS.Colors.success.opacity(0.1)
        case .removed: return DS.Colors.error.opacity(0.1)
        case .context: return .clear
        }
    }
}

// MARK: - Diff View

struct DiffView: View {
    let diff: FileDiff
    @State private var showSideBySide = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(DS.Colors.accent)
                
                Text(diff.filename)
                    .font(DS.Typography.headline)
                
                Spacer()
                
                Toggle("Side by Side", isOn: $showSideBySide)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.secondaryBackground)
            
            DSDivider()
            
            // Diff content
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(diff.hunks.indices, id: \.self) { hunkIndex in
                        let hunk = diff.hunks[hunkIndex]
                        
                        // Hunk header
                        Text(hunk.header)
                            .font(DS.Typography.mono(11))
                            .foregroundStyle(DS.Colors.info)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DS.Colors.info.opacity(0.1))
                        
                        // Lines
                        ForEach(hunk.lines) { line in
                            DiffLineView(line: line)
                        }
                    }
                }
            }
        }
        .background(DS.Colors.background)
    }
}

struct DiffLineView: View {
    let line: DiffLine
    
    var body: some View {
        HStack(spacing: 0) {
            // Line marker
            Text(marker)
                .font(DS.Typography.mono(11))
                .foregroundStyle(line.type.color)
                .frame(width: 20)
            
            // Content
            Text(line.content)
                .font(DS.Typography.mono(11))
                .foregroundStyle(line.type.color)
            
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, 1)
        .background(line.type.background)
    }
    
    private var marker: String {
        switch line.type {
        case .added: return "+"
        case .removed: return "-"
        case .context: return " "
        }
    }
}
