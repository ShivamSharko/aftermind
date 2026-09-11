import Foundation
import SwiftData

enum DemoSeedService {
    @MainActor
    static func seed(into modelContext: ModelContext) async throws -> SessionModel {
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
                dueDate: parseISODate(item.due_date),
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

    private static func parseISODate(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: s)
    }
}

