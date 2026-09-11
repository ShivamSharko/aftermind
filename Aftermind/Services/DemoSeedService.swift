import Foundation
import SwiftData

enum DemoSeedService {
    @MainActor
    static func seed(into modelContext: ModelContext) async throws -> SessionModel {
        let existingDescriptor = FetchDescriptor<SessionModel>(
            predicate: #Predicate<SessionModel> { $0.transcript == "Demo session loaded for testing and demonstration." }
        )
        if let existing = try? modelContext.fetch(existingDescriptor), let first = existing.first {
            return first
        }
        let extracted = try await MockContextExtractionService().extract(from: "demo")
        let session = SessionModel(
            createdAt: Date(),
            summary: extracted.session_summary,
            transcript: "Demo session loaded for testing and demonstration.",
            topics: extracted.topics
        )
        modelContext.insert(session)
        for item in extracted.items {
            let text = "\(item.title) \(item.description) \(item.evidence)"
            let vec = EmbeddingService.shared.vector(for: text)
            let memoryItem = MemoryItemModel(
                type: item.type,
                title: item.title,
                detail: item.description,
                people: item.related_people,
                evidence: item.evidence,
                confidence: item.confidence,
                dueText: item.due_text,
                owner: item.owner,
                dueDate: DateParsing.isoDate(item.due_date),
                embedding: vec,
                tags: item.tags,
                status: item.status
            )
            memoryItem.session = session
            modelContext.insert(memoryItem)
            NotificationService.schedule(for: memoryItem)
        }
        try modelContext.save()
        return session
    }
}

