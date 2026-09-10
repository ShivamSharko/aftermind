import Foundation
import SwiftData

@Model
final class SessionModel {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var summary: String = ""
    var transcript: String = ""
    var topics: [String] = []
    
    @Relationship(deleteRule: .cascade, inverse: \MemoryItemModel.session)
    var items: [MemoryItemModel] = []
    
    init(createdAt: Date, summary: String, transcript: String, topics: [String] = []) {
        self.createdAt = createdAt
        self.summary = summary
        self.transcript = transcript
        self.topics = topics
    }
}

@Model
final class MemoryItemModel {
    var id: UUID = UUID()
    var type: String = ""
    var title: String = ""
    var detail: String = ""
    var people: [String] = []
    var evidence: String = ""
    var confidence: Double = 0.0
    var dueText: String?
    var owner: String?
    var dueDate: Date?
    var embedding: [Double]?
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    
    var session: SessionModel?
    
    init(type: String, title: String, detail: String, people: [String], evidence: String, confidence: Double, dueText: String? = nil, isCompleted: Bool = false, owner: String? = nil, dueDate: Date? = nil) {
        self.type = type
        self.title = title
        self.detail = detail
        self.people = people
        self.evidence = evidence
        self.confidence = confidence
        self.dueText = dueText
        self.isCompleted = isCompleted
        self.owner = owner
        self.dueDate = dueDate
    }
}

