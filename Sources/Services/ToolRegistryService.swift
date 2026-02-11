import Foundation

// MARK: - Tool Registry Service
// Validates tool calls against the Unified Tool Registry (UTR).
// Provides alias resolution for backward compatibility with legacy tool names.

@Observable
final class ToolRegistryService {

    // MARK: - Types

    struct ToolDefinition: Identifiable, Codable {
        let id: String
        let category: String
        let description: String
        let aliases: [String]
        let parameters: [ToolParameter]
        let isNew: Bool

        struct ToolParameter: Codable {
            let name: String
            let type: String
            let required: Bool
            let description: String
        }
    }

    // MARK: - State

    private(set) var tools: [ToolDefinition] = []
    private(set) var aliasMap: [String: String] = [:]

    init() {
        registerBuiltinTools()
    }

    // MARK: - Lookup

    /// Resolve a tool name (or alias) to the canonical tool ID
    func resolve(_ nameOrAlias: String) -> String? {
        if tools.contains(where: { $0.id == nameOrAlias }) {
            return nameOrAlias
        }
        return aliasMap[nameOrAlias]
    }

    /// Get tool definition by ID or alias
    func tool(for nameOrAlias: String) -> ToolDefinition? {
        guard let id = resolve(nameOrAlias) else { return nil }
        return tools.first { $0.id == id }
    }

    /// Validate that a tool call is valid
    func validate(toolName: String) -> Bool {
        resolve(toolName) != nil
    }

    /// All tools in a specific category
    func tools(in category: String) -> [ToolDefinition] {
        tools.filter { $0.category == category }
    }

    /// All category names
    var categories: [String] {
        Array(Set(tools.map { $0.category })).sorted()
    }

    // MARK: - Registry

    private func registerBuiltinTools() {
        let registry: [(id: String, category: String, desc: String, aliases: [String], isNew: Bool)] = [
            ("think",                "core",       "Internal reasoning step",                      [],                          false),
            ("complete",             "core",       "Mark task as complete",                         [],                          false),
            ("ask_user",             "core",       "Request human input",                           [],                          true),
            ("file.read",            "file",       "Read file contents",                            ["read_file"],               false),
            ("file.write",           "file",       "Write file contents",                           ["write_file"],              false),
            ("file.edit",            "file",       "Edit file with search/replace",                 ["edit_file"],               false),
            ("file.edit_range",      "file",       "Edit specific line range",                      [],                          true),
            ("file.delete",          "file",       "Delete a file",                                 ["delete_file"],             false),
            ("file.search",          "file",       "Search files by content",                       ["search_files"],            false),
            ("file.list",            "file",       "List directory contents",                       ["list_directory"],           false),
            ("system.run",           "system",     "Execute shell command",                         ["run_command"],             false),
            ("ai.delegate.coder",    "delegation", "Delegate to coder model",                       ["delegate_to_coder"],       false),
            ("ai.delegate.researcher","delegation","Delegate to researcher model",                  ["delegate_to_researcher"],  false),
            ("ai.delegate.vision",   "delegation", "Delegate to vision model",                      ["delegate_to_vision"],      false),
            ("web.search",           "web",        "Search the web",                                ["web_search"],              false),
            ("web.fetch",            "web",        "Fetch URL contents",                            ["fetch_url"],               true),
            ("git.status",           "git",        "Show git status",                               [],                          false),
            ("git.diff",             "git",        "Show git diff",                                 [],                          false),
            ("git.commit",           "git",        "Create git commit",                             [],                          false),
            ("checkpoint.save",      "session",    "Save checkpoint",                               [],                          false),
            ("checkpoint.restore",   "session",    "Restore checkpoint",                            [],                          false),
        ]

        tools = registry.map { entry in
            ToolDefinition(
                id: entry.id,
                category: entry.category,
                description: entry.desc,
                aliases: entry.aliases,
                parameters: [],
                isNew: entry.isNew
            )
        }

        // Build alias map
        aliasMap = [:]
        for tool in tools {
            for alias in tool.aliases {
                aliasMap[alias] = tool.id
            }
        }

        print("ToolRegistryService: Registered \(tools.count) tools with \(aliasMap.count) aliases")
    }
}
