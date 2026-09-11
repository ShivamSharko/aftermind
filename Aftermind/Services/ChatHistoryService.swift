import Foundation
import Observation

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    var sources: [String] = []

    enum Role {
        case user, assistant
    }
}

@Observable
final class ChatHistoryService {
    var messages: [ChatMessage] = []
    
    func append(_ message: ChatMessage) {
        messages.append(message)
    }
}

