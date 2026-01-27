import Foundation
import SwiftUI

// MARK: - Mention Service
// Provides @mention support like Cursor/Windsurf
// Supports: @file, @folder, @codebase, @web, @bot, @context, @template, @symbol

@Observable
final class MentionService {
    
    // MARK: - Types
    
    enum MentionType: String, CaseIterable {
        case file = "file"           // @file:path/to/file.swift
        case folder = "folder"       // @folder:path/to/dir
        case codebase = "codebase"   // @codebase (full project context)
        case web = "web"             // @web:search query
        case bot = "bot"             // @bot:refactor
        case context = "context"     // @context:api-docs
        case template = "template"   // @template:component
        case symbol = "symbol"       // @symbol:functionName
        case selection = "selection" // @selection (current selection)
        case clipboard = "clipboard" // @clipboard (clipboard content)
        case git = "git"             // @git:diff, @git:log
        case terminal = "terminal"   // @terminal (last terminal output)
        case problems = "problems"   // @problems (linter errors)
        case image = "image"         // @image:path/to/image.png
        
        var icon: String {
            switch self {
            case .file: return "doc"
            case .folder: return "folder"
            case .codebase: return "tray.full"
            case .web: return "globe"
            case .bot: return "cpu"
            case .context: return "doc.text"
            case .template: return "doc.badge.gearshape"
            case .symbol: return "function"
            case .selection: return "selection.pin.in.out"
            case .clipboard: return "doc.on.clipboard"
            case .git: return "arrow.triangle.branch"
            case .terminal: return "terminal"
            case .problems: return "exclamationmark.triangle"
            case .image: return "photo"
            }
        }
        
        var description: String {
            switch self {
            case .file: return "Include file contents"
            case .folder: return "Include folder listing"
            case .codebase: return "Search entire codebase"
            case .web: return "Search the web"
            case .bot: return "Run an OBot"
            case .context: return "Include context snippet"
            case .template: return "Use code template"
            case .symbol: return "Include symbol definition"
            case .selection: return "Current text selection"
            case .clipboard: return "Clipboard contents"
            case .git: return "Git information"
            case .terminal: return "Last terminal output"
            case .problems: return "Current linter errors"
            case .image: return "Attach image for vision"
            }
        }
        
        var needsArgument: Bool {
            switch self {
            case .selection, .clipboard, .terminal, .problems, .codebase:
                return false
            default:
                return true
            }
        }
    }
    
    struct Mention: Identifiable, Equatable {
        let id = UUID()
        let type: MentionType
        let argument: String
        let range: Range<String.Index>
        
        var displayText: String {
            if argument.isEmpty {
                return "@\(type.rawValue)"
            }
            return "@\(type.rawValue):\(argument)"
        }
    }
    
    struct ResolvedMention {
        let mention: Mention
        let content: String
        let tokens: Int
        let error: String?
    }
    
    struct MentionSuggestion: Identifiable {
        let id = UUID()
        let type: MentionType
        let displayName: String
        let argument: String?
        let icon: String
        let subtitle: String?
        
        var fullText: String {
            if let arg = argument {
                return "@\(type.rawValue):\(arg)"
            }
            return "@\(type.rawValue)"
        }
    }
    
    // MARK: - State
    
    var suggestions: [MentionSuggestion] = []
    var isShowingSuggestions = false
    var suggestionFilter = ""
    
    // MARK: - Dependencies
    
    private let fileSystemService: FileSystemService
    private let obotService: OBotService
    private let gitService: GitService
    private let webSearchService: WebSearchService
    private let contextManager: ContextManager
    
    init(
        fileSystemService: FileSystemService,
        obotService: OBotService,
        gitService: GitService,
        webSearchService: WebSearchService,
        contextManager: ContextManager
    ) {
        self.fileSystemService = fileSystemService
        self.obotService = obotService
        self.gitService = gitService
        self.webSearchService = webSearchService
        self.contextManager = contextManager
    }
    
    // MARK: - Parsing
    
    /// Parse all @mentions from text
    func parseMentions(in text: String) -> [Mention] {
        var mentions: [Mention] = []
        let pattern = #"@(\w+)(?::([^\s@]+))?"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: nsRange)
        
        for match in matches {
            guard let typeRange = Range(match.range(at: 1), in: text) else { continue }
            let typeStr = String(text[typeRange])
            
            guard let type = MentionType(rawValue: typeStr) else { continue }
            
            var argument = ""
            if match.numberOfRanges > 2, let argRange = Range(match.range(at: 2), in: text) {
                argument = String(text[argRange])
            }
            
            if let fullRange = Range(match.range, in: text) {
                mentions.append(Mention(type: type, argument: argument, range: fullRange))
            }
        }
        
        return mentions
    }
    
    /// Resolve a single mention to its content
    func resolveMention(_ mention: Mention, projectRoot: URL?, selectedText: String?) async -> ResolvedMention {
        switch mention.type {
        case .file:
            return await resolveFileMention(mention, projectRoot: projectRoot)
        case .folder:
            return await resolveFolderMention(mention, projectRoot: projectRoot)
        case .codebase:
            return await resolveCodebaseMention(mention, projectRoot: projectRoot)
        case .web:
            return await resolveWebMention(mention)
        case .bot:
            return resolveBotMention(mention)
        case .context:
            return resolveContextMention(mention)
        case .template:
            return resolveTemplateMention(mention)
        case .symbol:
            return await resolveSymbolMention(mention, projectRoot: projectRoot)
        case .selection:
            return resolveSelectionMention(mention, selectedText: selectedText)
        case .clipboard:
            return resolveClipboardMention(mention)
        case .git:
            return await resolveGitMention(mention, projectRoot: projectRoot)
        case .terminal:
            return resolveTerminalMention(mention)
        case .problems:
            return resolveProblemsMention(mention)
        case .image:
            return resolveImageMention(mention, projectRoot: projectRoot)
        }
    }
    
    /// Resolve all mentions and return enhanced prompt
    func resolveAllMentions(
        in text: String,
        projectRoot: URL?,
        selectedText: String?
    ) async -> (cleanText: String, context: String, mentions: [ResolvedMention]) {
        let mentions = parseMentions(in: text)
        var resolvedMentions: [ResolvedMention] = []
        
        // Resolve all mentions in parallel
        await withTaskGroup(of: ResolvedMention.self) { group in
            for mention in mentions {
                group.addTask {
                    await self.resolveMention(mention, projectRoot: projectRoot, selectedText: selectedText)
                }
            }
            
            for await resolved in group {
                resolvedMentions.append(resolved)
            }
        }
        
        // Build context string
        var contextParts: [String] = []
        for resolved in resolvedMentions where resolved.error == nil {
            contextParts.append("[\(resolved.mention.type.rawValue): \(resolved.mention.argument)]")
            contextParts.append(resolved.content)
            contextParts.append("")
        }
        
        // Remove mentions from original text
        var cleanText = text
        for mention in mentions.reversed() {
            cleanText.removeSubrange(mention.range)
        }
        cleanText = cleanText.trimmingCharacters(in: .whitespaces)
        
        return (cleanText, contextParts.joined(separator: "\n"), resolvedMentions)
    }
    
    // MARK: - Individual Resolvers
    
    private func resolveFileMention(_ mention: Mention, projectRoot: URL?) async -> ResolvedMention {
        guard let root = projectRoot else {
            return ResolvedMention(mention: mention, content: "", tokens: 0, error: "No project open")
        }
        
        let filePath = root.appendingPathComponent(mention.argument)
        guard let content = fileSystemService.readFile(at: filePath) else {
            return ResolvedMention(mention: mention, content: "", tokens: 0, error: "File not found: \(mention.argument)")
        }
        
        let ext = filePath.pathExtension
        let lang = ContextManager.languageName(for: ext)
        let formatted = """
        File: \(mention.argument)
        ```\(lang)
        \(content)
        ```
        """
        
        return ResolvedMention(
            mention: mention,
            content: formatted,
            tokens: content.count / 4,
            error: nil
        )
    }
    
    private func resolveFolderMention(_ mention: Mention, projectRoot: URL?) async -> ResolvedMention {
        guard let root = projectRoot else {
            return ResolvedMention(mention: mention, content: "", tokens: 0, error: "No project open")
        }
        
        let folderPath = root.appendingPathComponent(mention.argument)
        let files = fileSystemService.listDirectory(folderPath)
        
        if files.isEmpty {
            return ResolvedMention(mention: mention, content: "", tokens: 0, error: "Folder not found or empty: \(mention.argument)")
        }
        
        var listing = "Folder: \(mention.argument)\n"
        for file in files {
            let icon = file.isDirectory ? "📁" : "📄"
            listing += "\(icon) \(file.name)\n"
        }
        
        return ResolvedMention(
            mention: mention,
            content: listing,
            tokens: listing.count / 4,
            error: nil
        )
    }
    
    private func resolveCodebaseMention(_ mention: Mention, projectRoot: URL?) async -> ResolvedMention {
        guard let root = projectRoot else {
            return ResolvedMention(mention: mention, content: "", tokens: 0, error: "No project open")
        }
        
        // Build a summary of the project structure
        var summary = ""
        let files = fileSystemService.getAllFiles(in: root)
        let filesByExtension = Dictionary(grouping: files, by: { $0.url.pathExtension })
        
        summary += "Files by type:\n"
        for (ext, extFiles) in filesByExtension.sorted(by: { $0.value.count > $1.value.count }).prefix(10) {
            let displayExt = ext.isEmpty ? "(no extension)" : ".\(ext)"
            summary += "  \(displayExt): \(extFiles.count) files\n"
        }
        
        let content = """
        Project Codebase Summary:
        Root: \(root.path)
        Total Files: \(files.count)
        
        \(summary)
        """
        
        return ResolvedMention(
            mention: mention,
            content: content,
            tokens: content.count / 4,
            error: nil
        )
    }
    
    private func resolveWebMention(_ mention: Mention) async -> ResolvedMention {
        guard !mention.argument.isEmpty else {
            return ResolvedMention(mention: mention, content: "", tokens: 0, error: "Web search requires a query")
        }
        
        do {
            let results = try await webSearchService.search(query: mention.argument)
            
            var content = "Web Search: \(mention.argument)\n\n"
            for result in results.prefix(5) {
                content += "• \(result.title)\n  \(result.snippet)\n  (\(result.url))\n\n"
            }
            
            return ResolvedMention(
                mention: mention,
                content: content,
                tokens: content.count / 4,
                error: results.isEmpty ? "No results found" : nil
            )
        } catch {
            return ResolvedMention(
                mention: mention,
                content: "",
                tokens: 0,
                error: "Web search failed: \(error.localizedDescription)"
            )
        }
    }
    
    private func resolveBotMention(_ mention: Mention) -> ResolvedMention {
        guard let bot = obotService.bots.first(where: { $0.id == mention.argument }) else {
            return ResolvedMention(mention: mention, content: "", tokens: 0, error: "Bot not found: \(mention.argument)")
        }
        
        let content = """
        Bot: \(bot.name)
        Description: \(bot.description)
        Steps: \(bot.steps.count)
        
        [Bot will be executed with the conversation context]
        """
        
        return ResolvedMention(
            mention: mention,
            content: content,
            tokens: content.count / 4,
            error: nil
        )
    }
    
    private func resolveContextMention(_ mention: Mention) -> ResolvedMention {
        guard let snippet = obotService.getContextSnippet(mention.argument) else {
            return ResolvedMention(mention: mention, content: "", tokens: 0, error: "Context snippet not found: \(mention.argument)")
        }
        
        let content = """
        Context: \(snippet.name)
        
        \(snippet.content)
        """
        
        return ResolvedMention(
            mention: mention,
            content: content,
            tokens: content.count / 4,
            error: nil
        )
    }
    
    private func resolveTemplateMention(_ mention: Mention) -> ResolvedMention {
        guard let template = obotService.templates.first(where: { $0.id == mention.argument }) else {
            return ResolvedMention(mention: mention, content: "", tokens: 0, error: "Template not found: \(mention.argument)")
        }
        
        let content = """
        Template: \(template.name)
        Variables: \(template.variables.map { $0.name }.joined(separator: ", "))
        
        ```
        \(template.content)
        ```
        """
        
        return ResolvedMention(
            mention: mention,
            content: content,
            tokens: content.count / 4,
            error: nil
        )
    }
    
    private func resolveSymbolMention(_ mention: Mention, projectRoot: URL?) async -> ResolvedMention {
        // Would integrate with FileIndexer to find symbol definitions
        let content = """
        Symbol: \(mention.argument)
        [Symbol lookup would search the codebase for \(mention.argument)]
        """
        
        return ResolvedMention(
            mention: mention,
            content: content,
            tokens: content.count / 4,
            error: nil
        )
    }
    
    private func resolveSelectionMention(_ mention: Mention, selectedText: String?) -> ResolvedMention {
        guard let selection = selectedText, !selection.isEmpty else {
            return ResolvedMention(mention: mention, content: "", tokens: 0, error: "No text selected")
        }
        
        let content = """
        Selected Text:
        ```
        \(selection)
        ```
        """
        
        return ResolvedMention(
            mention: mention,
            content: content,
            tokens: selection.count / 4,
            error: nil
        )
    }
    
    private func resolveClipboardMention(_ mention: Mention) -> ResolvedMention {
        guard let clipboard = NSPasteboard.general.string(forType: .string), !clipboard.isEmpty else {
            return ResolvedMention(mention: mention, content: "", tokens: 0, error: "Clipboard is empty")
        }
        
        let content = """
        Clipboard Contents:
        ```
        \(clipboard)
        ```
        """
        
        return ResolvedMention(
            mention: mention,
            content: content,
            tokens: clipboard.count / 4,
            error: nil
        )
    }
    
    private func resolveGitMention(_ mention: Mention, projectRoot: URL?) async -> ResolvedMention {
        guard let root = projectRoot else {
            return ResolvedMention(mention: mention, content: "", tokens: 0, error: "No project open")
        }
        
        gitService.setWorkingDirectory(root)
        gitService.refresh()
        
        var content = ""
        
        guard let status = gitService.status else {
            return ResolvedMention(mention: mention, content: "", tokens: 0, error: "Git status not available")
        }
        
        switch mention.argument.lowercased() {
        case "diff", "":
            // Get combined diff from modified files
            var diffs: [String] = []
            
            // Staged files
            for change in status.staged {
                let diff = gitService.getDiff(file: change.filename, staged: true)
                if !diff.isEmpty {
                    diffs.append(diff)
                }
            }
            
            // Unstaged files
            for change in status.unstaged {
                let diff = gitService.getDiff(file: change.filename, staged: false)
                if !diff.isEmpty {
                    diffs.append(diff)
                }
            }
            
            if diffs.isEmpty {
                content = "No uncommitted changes"
            } else {
                content = "Git Diff:\n```diff\n\(diffs.joined(separator: "\n"))\n```"
            }
        case "log":
            let commits = gitService.getLog(count: 10)
            if commits.isEmpty {
                content = "No commits yet"
            } else {
                content = "Recent Commits:\n" + commits.map { "• \($0.hash.prefix(7)) - \($0.message) (\($0.author))" }.joined(separator: "\n")
            }
        case "status":
            var statusLines: [String] = []
            statusLines.append("Branch: \(gitService.currentBranch)")
            if !status.staged.isEmpty {
                statusLines.append("Staged (\(status.staged.count)):")
                statusLines.append(contentsOf: status.staged.map { "  + \($0.filename)" })
            }
            if !status.unstaged.isEmpty {
                statusLines.append("Modified (\(status.unstaged.count)):")
                statusLines.append(contentsOf: status.unstaged.map { "  M \($0.filename)" })
            }
            if !status.untracked.isEmpty {
                statusLines.append("Untracked (\(status.untracked.count)):")
                statusLines.append(contentsOf: status.untracked.map { "  ? \($0)" })
            }
            content = "Git Status:\n" + statusLines.joined(separator: "\n")
        case "branch":
            content = "Current Branch: \(gitService.currentBranch)"
        default:
            content = "Unknown git command: \(mention.argument). Use: diff, log, status, branch"
        }
        
        return ResolvedMention(
            mention: mention,
            content: content,
            tokens: content.count / 4,
            error: content.isEmpty ? "Git command failed" : nil
        )
    }
    
    private func resolveTerminalMention(_ mention: Mention) -> ResolvedMention {
        // Would get last terminal output from TerminalView state
        let content = """
        Terminal Output:
        [Last terminal output would be included here]
        """
        
        return ResolvedMention(
            mention: mention,
            content: content,
            tokens: content.count / 4,
            error: nil
        )
    }
    
    private func resolveProblemsMention(_ mention: Mention) -> ResolvedMention {
        // Would get current linter errors from ProblemsPanel state
        let content = """
        Current Problems:
        [Linter errors and warnings would be listed here]
        """
        
        return ResolvedMention(
            mention: mention,
            content: content,
            tokens: content.count / 4,
            error: nil
        )
    }
    
    private func resolveImageMention(_ mention: Mention, projectRoot: URL?) -> ResolvedMention {
        guard let root = projectRoot else {
            return ResolvedMention(mention: mention, content: "", tokens: 0, error: "No project open")
        }
        
        let imagePath = root.appendingPathComponent(mention.argument)
        
        guard FileManager.default.fileExists(atPath: imagePath.path) else {
            return ResolvedMention(mention: mention, content: "", tokens: 0, error: "Image not found: \(mention.argument)")
        }
        
        let content = """
        [Image attached: \(mention.argument)]
        [Will be processed by vision model]
        """
        
        return ResolvedMention(
            mention: mention,
            content: content,
            tokens: 100, // Placeholder for image tokens
            error: nil
        )
    }
    
    // MARK: - Suggestions
    
    /// Update suggestions based on current input
    func updateSuggestions(for text: String, cursorPosition: Int, projectRoot: URL?) {
        // Check if we're in a mention context (after @)
        let textUpToCursor = String(text.prefix(cursorPosition))
        
        guard let atIndex = textUpToCursor.lastIndex(of: "@") else {
            suggestions = []
            isShowingSuggestions = false
            return
        }
        
        let afterAt = String(textUpToCursor[textUpToCursor.index(after: atIndex)...])
        
        // Check if there's a space after @ (not in mention anymore)
        if afterAt.contains(" ") && !afterAt.contains(":") {
            suggestions = []
            isShowingSuggestions = false
            return
        }
        
        suggestionFilter = afterAt
        isShowingSuggestions = true
        
        // Parse what we have
        let parts = afterAt.split(separator: ":", maxSplits: 1)
        let typeFilter = String(parts.first ?? "")
        let argFilter = parts.count > 1 ? String(parts[1]) : nil
        
        // Generate suggestions
        var newSuggestions: [MentionSuggestion] = []
        
        // If no colon yet, suggest types
        if argFilter == nil {
            for type in MentionType.allCases {
                if typeFilter.isEmpty || type.rawValue.hasPrefix(typeFilter.lowercased()) {
                    newSuggestions.append(MentionSuggestion(
                        type: type,
                        displayName: "@\(type.rawValue)",
                        argument: nil,
                        icon: type.icon,
                        subtitle: type.description
                    ))
                }
            }
        }
        // Otherwise, suggest arguments for the type
        else if let typeStr = parts.first,
                let type = MentionType(rawValue: String(typeStr).lowercased()) {
            
            let filter = argFilter?.lowercased() ?? ""
            
            switch type {
            case .file:
                // Suggest files
                if let root = projectRoot {
                    let files = fileSystemService.getAllFiles(in: root)
                    for file in files.prefix(20) {
                        let relativePath = file.url.path.replacingOccurrences(of: root.path + "/", with: "")
                        if filter.isEmpty || relativePath.lowercased().contains(filter) {
                            newSuggestions.append(MentionSuggestion(
                                type: .file,
                                displayName: file.name,
                                argument: relativePath,
                                icon: "doc",
                                subtitle: relativePath
                            ))
                        }
                    }
                }
                
            case .bot:
                for bot in obotService.bots {
                    if filter.isEmpty || bot.id.lowercased().contains(filter) || bot.name.lowercased().contains(filter) {
                        newSuggestions.append(MentionSuggestion(
                            type: .bot,
                            displayName: bot.name,
                            argument: bot.id,
                            icon: bot.icon ?? "cpu",
                            subtitle: bot.description
                        ))
                    }
                }
                
            case .context:
                for snippet in obotService.contextSnippets {
                    if filter.isEmpty || snippet.id.lowercased().contains(filter) || snippet.name.lowercased().contains(filter) {
                        newSuggestions.append(MentionSuggestion(
                            type: .context,
                            displayName: snippet.name,
                            argument: snippet.id,
                            icon: "doc.text",
                            subtitle: nil
                        ))
                    }
                }
                
            case .template:
                for template in obotService.templates {
                    if filter.isEmpty || template.id.lowercased().contains(filter) || template.name.lowercased().contains(filter) {
                        newSuggestions.append(MentionSuggestion(
                            type: .template,
                            displayName: template.name,
                            argument: template.id,
                            icon: "doc.badge.gearshape",
                            subtitle: template.description
                        ))
                    }
                }
                
            case .git:
                let gitCommands = ["diff", "log", "status", "branch"]
                for cmd in gitCommands {
                    if filter.isEmpty || cmd.contains(filter) {
                        newSuggestions.append(MentionSuggestion(
                            type: .git,
                            displayName: cmd,
                            argument: cmd,
                            icon: "arrow.triangle.branch",
                            subtitle: "Git \(cmd)"
                        ))
                    }
                }
                
            default:
                break
            }
        }
        
        suggestions = newSuggestions
    }
    
    /// Clear suggestions
    func clearSuggestions() {
        suggestions = []
        isShowingSuggestions = false
        suggestionFilter = ""
    }
}

// MARK: - Mention Chip View

struct MentionChipView: View {
    let mention: MentionService.Mention
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: mention.type.icon)
                .font(.caption2)
            
            Text(mention.displayText)
                .font(DS.Typography.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, 4)
        .background(DS.Colors.accent.opacity(0.15))
        .foregroundStyle(DS.Colors.accent)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}

// MARK: - Mention Suggestion View

struct MentionSuggestionView: View {
    let suggestions: [MentionService.MentionSuggestion]
    let onSelect: (MentionService.MentionSuggestion) -> Void
    
    @State private var selectedIndex = 0
    
    var body: some View {
        if suggestions.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: suggestion.icon)
                                .font(.caption)
                                .frame(width: 20)
                                .foregroundStyle(DS.Colors.accent)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.displayName)
                                    .font(DS.Typography.callout)
                                
                                if let subtitle = suggestion.subtitle {
                                    Text(subtitle)
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(DS.Colors.secondaryText)
                                }
                            }
                            
                            Spacer()
                            
                            Text(suggestion.fullText)
                                .font(DS.Typography.mono(10))
                                .foregroundStyle(DS.Colors.tertiaryText)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(index == selectedIndex ? DS.Colors.accent.opacity(0.1) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(DS.Colors.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
    }
}
