import Foundation

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date
    var modelRaw: String?  // Store model as string for Codable
    var images: [Data]
    
    enum Role: String, Codable {
        case user
        case assistant
        case system
    }
    
    var model: OllamaModel? {
        get { modelRaw.flatMap { OllamaModel(rawValue: $0) } }
        set { modelRaw = newValue?.rawValue }
    }
    
    var isUser: Bool {
        role == .user
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    init(role: Role, content: String, model: OllamaModel? = nil, images: [Data] = []) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.modelRaw = model?.rawValue
        self.images = images
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
    
    // Codable conformance with custom keys
    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp, modelRaw, images
    }
}
