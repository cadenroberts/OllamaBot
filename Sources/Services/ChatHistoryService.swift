import Foundation
import SwiftUI

// MARK: - Chat History Service

@Observable
class ChatHistoryService {
    var conversations: [ChatConversation] = []
    var currentConversationId: UUID?
    
    private let storageDirectory: URL
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init() {
        // Store in Application Support
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDirectory = appSupport.appendingPathComponent("OllamaBot/ChatHistory")
        
        // Create directory if needed
        try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        
        // Configure encoder/decoder
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        // Load existing conversations
        loadConversations()
    }
    
    // MARK: - Public API
    
    /// Create a new conversation
    func newConversation(title: String? = nil) -> ChatConversation {
        let conversation = ChatConversation(
            title: title ?? "New Chat",
            messages: [],
            model: nil,
            projectPath: nil
        )
        
        conversations.insert(conversation, at: 0)
        currentConversationId = conversation.id
        saveConversation(conversation)
        
        return conversation
    }
    
    /// Get current conversation
    var currentConversation: ChatConversation? {
        guard let id = currentConversationId else { return nil }
        return conversations.first { $0.id == id }
    }
    
    /// Add message to current conversation
    func addMessage(_ message: ChatMessage) {
        guard let id = currentConversationId,
              let index = conversations.firstIndex(where: { $0.id == id }) else {
            // Create new conversation if none exists
            var conv = newConversation()
            conv.messages.append(message)
            conv.updatedAt = Date()
            
            if let idx = conversations.firstIndex(where: { $0.id == conv.id }) {
                conversations[idx] = conv
            }
            saveConversation(conv)
            return
        }
        
        var conversation = conversations[index]
        conversation.messages.append(message)
        conversation.updatedAt = Date()
        
        // Auto-generate title from first message if untitled
        if conversation.title == "New Chat" && conversation.messages.count == 1 {
            conversation.title = generateTitle(from: message.content)
        }
        
        conversations[index] = conversation
        saveConversation(conversation)
    }
    
    /// Update conversation
    func updateConversation(_ conversation: ChatConversation) {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else {
            return
        }
        
        var updated = conversation
        updated.updatedAt = Date()
        conversations[index] = updated
        saveConversation(updated)
    }
    
    /// Delete conversation
    func deleteConversation(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        
        // Delete file
        let fileURL = storageDirectory.appendingPathComponent("\(id.uuidString).json")
        try? fileManager.removeItem(at: fileURL)
        
        // Clear current if deleted
        if currentConversationId == id {
            currentConversationId = conversations.first?.id
        }
    }
    
    /// Select conversation
    func selectConversation(_ id: UUID) {
        currentConversationId = id
    }
    
    /// Search conversations
    func search(query: String) -> [ChatConversation] {
        guard !query.isEmpty else { return conversations }
        
        let lowercased = query.lowercased()
        return conversations.filter { conversation in
            conversation.title.lowercased().contains(lowercased) ||
            conversation.messages.contains { $0.content.lowercased().contains(lowercased) }
        }
    }
    
    /// Export conversation
    func exportConversation(_ id: UUID) -> String? {
        guard let conversation = conversations.first(where: { $0.id == id }) else {
            return nil
        }
        
        var export = "# \(conversation.title)\n\n"
        export += "Date: \(conversation.createdAt.formatted())\n\n"
        export += "---\n\n"
        
        for message in conversation.messages {
            let role = message.role == .user ? "**User**" : "**Assistant**"
            export += "\(role):\n\n\(message.content)\n\n---\n\n"
        }
        
        return export
    }
    
    // MARK: - Private Helpers
    
    private func loadConversations() {
        do {
            let files = try fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            
            var loaded: [ChatConversation] = []
            
            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file),
                   let conversation = try? decoder.decode(ChatConversation.self, from: data) {
                    loaded.append(conversation)
                }
            }
            
            // Sort by updated date
            conversations = loaded.sorted { $0.updatedAt > $1.updatedAt }
            
            // Set current to most recent
            currentConversationId = conversations.first?.id
            
        } catch {
            print("Failed to load chat history: \(error)")
        }
    }
    
    private func saveConversation(_ conversation: ChatConversation) {
        let fileURL = storageDirectory.appendingPathComponent("\(conversation.id.uuidString).json")
        
        do {
            let data = try encoder.encode(conversation)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save conversation: \(error)")
        }
    }
    
    private func generateTitle(from content: String) -> String {
        // Take first 50 chars or first sentence
        var title = content.prefix(50)
        
        // Try to end at a word boundary
        if let lastSpace = title.lastIndex(of: " ") {
            title = title[..<lastSpace]
        }
        
        return String(title) + (content.count > 50 ? "..." : "")
    }
}

// MARK: - Chat Conversation Model

struct ChatConversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var model: String?
    var projectPath: String?
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]
    
    init(
        id: UUID = UUID(),
        title: String,
        messages: [ChatMessage],
        model: String?,
        projectPath: String?
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.model = model
        self.projectPath = projectPath
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tags = []
    }
}

// MARK: - Chat History Sidebar View

struct ChatHistorySidebar: View {
    @Environment(AppState.self) private var appState
    let historyService: ChatHistoryService
    
    @State private var searchText = ""
    @State private var showingDeleteAlert = false
    @State private var conversationToDelete: UUID?
    
    var filteredConversations: [ChatConversation] {
        historyService.search(query: searchText)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Chat History")
                    .font(DS.Typography.headline)
                
                Spacer()
                
                DSIconButton(icon: "plus") {
                    _ = historyService.newConversation()
                }
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.secondaryBackground)
            
            DSDivider()
            
            // Search
            DSTextField(placeholder: "Search chats...", text: $searchText, icon: "magnifyingglass")
                .padding(DS.Spacing.sm)
            
            // Conversation List
            ScrollView {
                LazyVStack(spacing: DS.Spacing.xs) {
                    ForEach(filteredConversations) { conversation in
                        ConversationRow(
                            conversation: conversation,
                            isSelected: conversation.id == historyService.currentConversationId,
                            onSelect: { historyService.selectConversation(conversation.id) },
                            onDelete: {
                                conversationToDelete = conversation.id
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
                .padding(DS.Spacing.sm)
            }
        }
        .background(DS.Colors.background)
        .alert("Delete Conversation", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let id = conversationToDelete {
                    historyService.deleteConversation(id)
                }
            }
        } message: {
            Text("Are you sure you want to delete this conversation? This cannot be undone.")
        }
    }
}

struct ConversationRow: View {
    let conversation: ChatConversation
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.caption)
                .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.secondaryText)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.title)
                    .font(DS.Typography.callout)
                    .lineLimit(1)
                    .foregroundStyle(DS.Colors.text)
                
                Text(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
            
            Spacer()
            
            if isHovered {
                DSIconButton(icon: "trash", size: 14, color: DS.Colors.error) {
                    onDelete()
                }
            }
        }
        .padding(DS.Spacing.sm)
        .background(isSelected ? DS.Colors.accent.opacity(0.15) : (isHovered ? DS.Colors.surface : .clear))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
    }
}
