import Foundation
import SwiftUI

// MARK: - Problems Panel (Errors/Warnings View)

struct ProblemsPanel: View {
    @Environment(AppState.self) private var appState
    @State private var problems: [Problem] = []
    @State private var isLoading = false
    @State private var filter: ProblemFilter = .all
    @State private var searchText = ""
    
    var filteredProblems: [Problem] {
        var result = problems
        
        // Apply severity filter
        switch filter {
        case .all:
            break
        case .errors:
            result = result.filter { $0.severity == .error }
        case .warnings:
            result = result.filter { $0.severity == .warning }
        case .info:
            result = result.filter { $0.severity == .info }
        }
        
        // Apply search
        if !searchText.isEmpty {
            result = result.filter {
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.file.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var errorCount: Int { problems.filter { $0.severity == .error }.count }
    var warningCount: Int { problems.filter { $0.severity == .warning }.count }
    var infoCount: Int { problems.filter { $0.severity == .info }.count }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Filter Bar
            HStack(spacing: DS.Spacing.md) {
                // Filter Tabs
                HStack(spacing: 0) {
                    ForEach(ProblemFilter.allCases, id: \.self) { f in
                        Button {
                            filter = f
                        } label: {
                            Text(f.displayName)
                                .font(DS.Typography.caption.weight(filter == f ? .semibold : .regular))
                                .foregroundStyle(filter == f ? DS.Colors.accent : DS.Colors.secondaryText)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.sm)
                                .background(filter == f ? DS.Colors.accent.opacity(0.1) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(DS.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                
                Spacer()
                
                // Counts
                HStack(spacing: DS.Spacing.md) {
                    ProblemCountBadge(count: errorCount, severity: .error)
                    ProblemCountBadge(count: warningCount, severity: .warning)
                    ProblemCountBadge(count: infoCount, severity: .info)
                }
                
                DSIconButton(icon: "arrow.clockwise", size: 14) {
                    refreshProblems()
                }
            }
            .padding(DS.Spacing.sm)
            .background(DS.Colors.surface)
            
            DSDivider()
            
            // Search (if needed, or integrate into header)
            if filter == .all || !searchText.isEmpty {
                HStack {
                    DSTextField(placeholder: "Filter problems...", text: $searchText, icon: "magnifyingglass")
                }
                .padding(DS.Spacing.sm)
                .background(DS.Colors.background)
                
                DSDivider()
            }
            
            // Problems List
            if isLoading {
                Spacer()
                DSLoadingSpinner()
                Spacer()
            } else if filteredProblems.isEmpty {
                DSEmptyState(
                    icon: "checkmark.circle",
                    title: "No Problems",
                    message: filter == .all ? "Your code looks great!" : "No \(filter.displayName.lowercased()) found"
                )
            } else {
                DSScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredProblems) { problem in
                            ProblemRow(problem: problem) {
                                navigateToProblem(problem)
                            }
                        }
                    }
                }
                .background(DS.Colors.background) // Ensure dark background
            }
        }
        .background(DS.Colors.background)
        .onChange(of: appState.rootFolder) { _, _ in
            refreshProblems()
        }
        .onAppear {
            refreshProblems()
        }
    }
    
    private func refreshProblems() {
        guard let root = appState.rootFolder else {
            problems = []
            return
        }
        
        isLoading = true
        
        Task.detached(priority: .userInitiated) {
            let parsed = await ProblemsParser.parse(projectRoot: root)
            
            await MainActor.run {
                self.problems = parsed
                self.isLoading = false
            }
        }
    }
    
    private func navigateToProblem(_ problem: Problem) {
        // Open the file and go to the line
        if let root = appState.rootFolder {
            let fileURL = root.appendingPathComponent(problem.file)
            let file = FileItem(url: fileURL, isDirectory: false)
            appState.openFile(file)
            appState.goToLine = problem.line
        }
    }
}

// MARK: - Problem Row

struct ProblemRow: View {
    let problem: Problem
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.sm) {
                // Severity icon
                Image(systemName: problem.severity.icon)
                    .font(.caption)
                    .foregroundStyle(problem.severity.color)
                    .frame(width: 16)
                
                // Message
                VStack(alignment: .leading, spacing: 2) {
                    Text(problem.message)
                        .font(DS.Typography.callout)
                        .foregroundStyle(DS.Colors.text)
                        .lineLimit(2)
                    
                    HStack(spacing: DS.Spacing.sm) {
                        Text(problem.file)
                            .font(DS.Typography.caption2)
                            .foregroundStyle(DS.Colors.secondaryText)
                        
                        Text(":\(problem.line)")
                            .font(DS.Typography.mono(10))
                            .foregroundStyle(DS.Colors.tertiaryText)
                        
                        if let source = problem.source {
                            DSBadge(text: source, color: DS.Colors.secondaryText)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(DS.Spacing.sm)
            .background(isHovered ? DS.Colors.surface : .clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Problem Count Badge

struct ProblemCountBadge: View {
    let count: Int
    let severity: ProblemSeverity
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: severity.icon)
                .font(.caption2)
            
            Text("\(count)")
                .font(DS.Typography.caption2.monospacedDigit())
        }
        .foregroundStyle(count > 0 ? severity.color : DS.Colors.tertiaryText)
    }
}

// MARK: - Models

struct Problem: Identifiable {
    let id = UUID()
    let severity: ProblemSeverity
    let message: String
    let file: String
    let line: Int
    let column: Int?
    let source: String?
    let code: String?
}

enum ProblemSeverity: String, CaseIterable {
    case error
    case warning
    case info
    case hint
    
    var icon: String {
        switch self {
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .hint: return "lightbulb.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .error: return DS.Colors.error
        case .warning: return DS.Colors.warning
        case .info: return DS.Colors.info
        case .hint: return DS.Colors.accent
        }
    }
}

enum ProblemFilter: String, CaseIterable {
    case all
    case errors
    case warnings
    case info
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .errors: return "Errors"
        case .warnings: return "Warnings"
        case .info: return "Info"
        }
    }
}

// MARK: - Problems Parser

enum ProblemsParser {
    static func parse(projectRoot: URL) async -> [Problem] {
        var problems: [Problem] = []
        
        // Try Swift build for Swift projects
        if FileManager.default.fileExists(atPath: projectRoot.appendingPathComponent("Package.swift").path) {
            problems.append(contentsOf: parseSwiftBuild(at: projectRoot))
        }
        
        // Try npm/yarn for JS/TS projects
        if FileManager.default.fileExists(atPath: projectRoot.appendingPathComponent("package.json").path) {
            problems.append(contentsOf: parseTypeScriptErrors(at: projectRoot))
        }
        
        // Try Python for Python projects
        if FileManager.default.fileExists(atPath: projectRoot.appendingPathComponent("requirements.txt").path) ||
           FileManager.default.fileExists(atPath: projectRoot.appendingPathComponent("pyproject.toml").path) {
            problems.append(contentsOf: parsePythonErrors(at: projectRoot))
        }
        
        return problems
    }
    
    // MARK: - Swift Build Parser
    
    private static func parseSwiftBuild(at root: URL) -> [Problem] {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["build", "--quiet"]
        process.currentDirectoryURL = root
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return parseSwiftOutput(output, root: root)
        } catch {
            return []
        }
    }
    
    private static func parseSwiftOutput(_ output: String, root: URL) -> [Problem] {
        var problems: [Problem] = []
        
        // Swift compiler output format:
        // /path/to/file.swift:line:col: error: message
        // /path/to/file.swift:line:col: warning: message
        
        let pattern = #"([^:]+):(\d+):(\d+): (error|warning|note): (.+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        for line in output.components(separatedBy: .newlines) {
            let range = NSRange(line.startIndex..., in: line)
            
            if let match = regex.firstMatch(in: line, options: [], range: range) {
                let filePath = (line as NSString).substring(with: match.range(at: 1))
                let lineNum = Int((line as NSString).substring(with: match.range(at: 2))) ?? 0
                let colNum = Int((line as NSString).substring(with: match.range(at: 3))) ?? 0
                let severityStr = (line as NSString).substring(with: match.range(at: 4))
                let message = (line as NSString).substring(with: match.range(at: 5))
                
                // Make path relative to root
                let relativePath = filePath.replacingOccurrences(of: root.path + "/", with: "")
                
                let severity: ProblemSeverity
                switch severityStr {
                case "error": severity = .error
                case "warning": severity = .warning
                default: severity = .info
                }
                
                problems.append(Problem(
                    severity: severity,
                    message: message,
                    file: relativePath,
                    line: lineNum,
                    column: colNum,
                    source: "swiftc",
                    code: nil
                ))
            }
        }
        
        return problems
    }
    
    // MARK: - TypeScript Parser
    
    private static func parseTypeScriptErrors(at root: URL) -> [Problem] {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["npx", "tsc", "--noEmit", "--pretty", "false"]
        process.currentDirectoryURL = root
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return parseTypeScriptOutput(output)
        } catch {
            return []
        }
    }
    
    private static func parseTypeScriptOutput(_ output: String) -> [Problem] {
        var problems: [Problem] = []
        
        // TypeScript output format:
        // src/file.ts(line,col): error TS1234: message
        
        let pattern = #"(.+)\((\d+),(\d+)\): (error|warning) TS(\d+): (.+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        for line in output.components(separatedBy: .newlines) {
            let range = NSRange(line.startIndex..., in: line)
            
            if let match = regex.firstMatch(in: line, options: [], range: range) {
                let file = (line as NSString).substring(with: match.range(at: 1))
                let lineNum = Int((line as NSString).substring(with: match.range(at: 2))) ?? 0
                let colNum = Int((line as NSString).substring(with: match.range(at: 3))) ?? 0
                let severityStr = (line as NSString).substring(with: match.range(at: 4))
                let code = (line as NSString).substring(with: match.range(at: 5))
                let message = (line as NSString).substring(with: match.range(at: 6))
                
                let severity: ProblemSeverity = severityStr == "error" ? .error : .warning
                
                problems.append(Problem(
                    severity: severity,
                    message: message,
                    file: file,
                    line: lineNum,
                    column: colNum,
                    source: "tsc",
                    code: "TS\(code)"
                ))
            }
        }
        
        return problems
    }
    
    // MARK: - Python Parser
    
    private static func parsePythonErrors(at root: URL) -> [Problem] {
        // Try pyflakes/pylint/mypy
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", "-m", "py_compile"] // Basic syntax check
        process.currentDirectoryURL = root
        process.standardOutput = pipe
        process.standardError = pipe
        
        // For a full implementation, would run pyflakes or pylint
        return []
    }
}
