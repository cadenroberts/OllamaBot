import Foundation
import SwiftUI

@Observable
class FileItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var isDirectory: Bool
    var children: [FileItem]?
    var isExpanded: Bool = false
    var isModified: Bool = false
    var gitStatus: GitFileStatus?
    
    // MARK: - Computed Properties
    
    var name: String {
        url.lastPathComponent
    }
    
    var fileExtension: String? {
        isDirectory ? nil : url.pathExtension
    }
    
    var icon: String {
        if isDirectory {
            return isExpanded ? "folder.fill" : "folder.fill"
        }
        
        switch fileExtension?.lowercased() {
        case "swift": return "swift"
        case "py": return "curlybraces.square.fill"
        case "js": return "text.page.badge.magnifyingglass"
        case "ts", "tsx": return "t.circle.fill"
        case "json": return "curlybraces"
        case "md", "markdown": return "doc.text.fill"
        case "txt": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "webp": return "photo.fill"
        case "html": return "globe"
        case "css", "scss", "sass": return "paintbrush"
        case "xml": return "chevron.left.forwardslash.chevron.right"
        case "yaml", "yml": return "list.bullet.indent"
        case "sh", "bash", "zsh": return "terminal.fill"
        case "rb": return "diamond.fill"
        case "rs": return "gearshape.fill"
        case "go": return "g.circle.fill"
        case "c", "cpp", "h", "hpp": return "c.circle.fill"
        case "java": return "cup.and.saucer.fill"
        default: return "doc.fill"
        }
    }
    
    var iconColor: SwiftUI.Color {
        if isDirectory {
            return .blue
        }
        
        switch fileExtension?.lowercased() {
        case "swift": return .orange
        case "py": return .green
        case "js": return .yellow
        case "ts", "tsx": return .blue
        case "json": return .purple
        case "md", "markdown": return .cyan
        case "html": return .red
        case "css", "scss", "sass": return .pink
        case "rb": return .red
        case "rs": return .orange
        case "go": return .cyan
        case "c", "cpp", "h", "hpp": return .blue
        case "java": return .red
        default: return .secondary
        }
    }
    
    // MARK: - Initialization
    
    init(url: URL, isDirectory: Bool, children: [FileItem]? = nil) {
        self.url = url
        self.isDirectory = isDirectory
        self.children = children
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.url == rhs.url
    }
    
    // MARK: - Methods
    
    func loadChildren(from fileManager: FileManager = .default) {
        guard isDirectory else { return }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
            children = contents.compactMap { url in
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                return FileItem(url: url, isDirectory: isDir)
            }.sorted { item1, item2 in
                if item1.isDirectory == item2.isDirectory {
                    return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
                }
                return item1.isDirectory && !item2.isDirectory
            }
        } catch {
            children = []
        }
    }
    
    func toggleExpansion() {
        if isDirectory {
            isExpanded.toggle()
            if isExpanded && children == nil {
                loadChildren()
            }
        }
    }
}

// MARK: - Git Status

enum GitFileStatus: String {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case untracked = "?"
    case staged = "S"
    case conflicted = "C"
    
    var color: SwiftUI.Color {
        switch self {
        case .modified: return .yellow
        case .added: return .green
        case .deleted: return .red
        case .untracked: return .gray
        case .staged: return .blue
        case .conflicted: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .modified: return "pencil"
        case .added: return "plus"
        case .deleted: return "minus"
        case .untracked: return "questionmark"
        case .staged: return "checkmark"
        case .conflicted: return "exclamationmark.triangle"
        }
    }
}
