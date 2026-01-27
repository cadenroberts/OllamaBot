import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    var content: String
    let timestamp: Date
    var model: OllamaModel?
    var images: [Data]
    
    enum Role: String {
        case user
        case assistant
        case system
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
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.model = model
        self.images = images
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}
