import Foundation

// These structs match the JSON schema we will force the LLM to output.
struct ExtractedSession: Codable {
    let session_summary: String
    let participants: [Participant]
    let topics: [String]
    let items: [ExtractedItem]
}

struct Participant: Codable {
    let name: String
    let role: String?
}

struct ExtractedItem: Codable {
    let type: String
    let title: String
    let description: String
    let related_people: [String]
    let due_text: String?
    let due_date: String?
    let confidence: Double
    let evidence: String
    let status: String?
    let tags: [String]
}

