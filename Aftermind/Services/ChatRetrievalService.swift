import Foundation
import SwiftData

struct RetrievedMemory {
    let item: MemoryItemModel
    let score: Double
}

final class ChatRetrievalService {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Query understanding

    private struct QueryIntent {
        var itemType: String?
        var person: String?
        var startDate: Date?
        var keywords: [String]
    }

    private func parseIntent(from query: String, knownPeople: [String]) -> QueryIntent {
        let lowered = query.lowercased()
        var intent = QueryIntent(itemType: nil, person: nil, startDate: nil, keywords: [])

        if lowered.contains("promise") || lowered.contains("commit") || lowered.contains("owed") {
            intent.itemType = "commitment"
        } else if lowered.contains("task") || lowered.contains("to do") || lowered.contains("todo") || lowered.contains("follow up") {
            intent.itemType = "task"
        } else if lowered.contains("idea") {
            intent.itemType = "idea"
        } else if lowered.contains("decision") || lowered.contains("decide") {
            intent.itemType = "decision"
        } else if lowered.contains("prefer") || lowered.contains("dislike") {
            intent.itemType = "preference"
        } else if lowered.contains("fact") {
            intent.itemType = "fact"
        }

        intent.person = knownPeople.first { lowered.contains($0.lowercased()) }

        let now = Date()
        let calendar = Calendar.current
        if lowered.contains("today") {
            intent.startDate = calendar.startOfDay(for: now)
        } else if lowered.contains("yesterday") {
            intent.startDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
        } else if lowered.contains("last week") || lowered.contains("past week") || lowered.contains("this week") {
            intent.startDate = calendar.date(byAdding: .day, value: -7, to: now)
        } else if lowered.contains("last month") || lowered.contains("past month") {
            intent.startDate = calendar.date(byAdding: .day, value: -30, to: now)
        }

        let stopWords: Set<String> = ["what","did","i","me","my","the","a","an","to","with","about","last","when","were","was","say","says","said","do","does","have","has","we","you","our","us","of","in","on","for","and","or","is","are","it","its","this","that","there","their","they","he","she","him","her","who","which","could","would","should","can","will","shall","may","might","must","please","tell","show","list","give"]
        intent.keywords = lowered
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count > 2 && !stopWords.contains($0) }

        return intent
    }

    // MARK: - Retrieval with weighted scoring

    func retrieve(for query: String) -> [RetrievedMemory] {
        var descriptor = FetchDescriptor<MemoryItemModel>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 50
        guard let allItems = try? modelContext.fetch(descriptor), !allItems.isEmpty else { return [] }

        let knownPeople = Array(Set(allItems.flatMap { $0.people }))
        let intent = parseIntent(from: query, knownPeople: knownPeople)

        var candidates = allItems
        if let startDate = intent.startDate {
            let filtered = candidates.filter { $0.createdAt >= startDate }
            if !filtered.isEmpty { candidates = filtered }
        }

        let now = Date()
        let scored: [RetrievedMemory] = candidates.map { item in
            let keywordScore = self.keywordScore(keywords: intent.keywords, item: item)
            let personScore = (intent.person != nil && item.people.contains(where: { $0.lowercased() == intent.person?.lowercased() })) ? 1.0 : 0.0
            let typeScore = (intent.itemType != nil && item.type == intent.itemType) ? 1.0 : 0.0
            let ageDays = now.timeIntervalSince(item.createdAt) / 86400.0
            let recencyScore = exp(-ageDays / 14.0)
            let score = 0.35 * keywordScore
                      + 0.20 * personScore
                      + 0.20 * typeScore
                      + 0.15 * recencyScore
                      + 0.10 * item.confidence
            return RetrievedMemory(item: item, score: score)
        }

        let sorted = scored.sorted { $0.score > $1.score }
        let matching = sorted.filter { $0.score >= 0.25 }
        let result = matching.isEmpty ? Array(sorted.prefix(5)) : Array(matching.prefix(5))
        return result
    }

    private func keywordScore(keywords: [String], item: MemoryItemModel) -> Double {
        guard !keywords.isEmpty else { return 0.3 }
        let haystack = "\(item.title) \(item.detail) \(item.people.joined(separator: " ")) \(item.evidence) \(item.type)".lowercased()
        let hits = keywords.filter { haystack.contains($0) }.count
        return Double(hits) / Double(keywords.count)
    }

    func formatContext(_ memories: [RetrievedMemory]) -> String {
        guard !memories.isEmpty else { return "No relevant memories found." }
        var result = "Relevant memories (most relevant first):\n"
        for (index, memory) in memories.enumerated() {
            let item = memory.item
            result += "\(index + 1). [\(item.type)] \(item.title) (relevance \(Int(memory.score * 100))%)\n"
            result += "   Details: \(item.detail)\n"
            if !item.people.isEmpty { result += "   People: \(item.people.joined(separator: ", "))\n" }
            if let due = item.dueText { result += "   Due: \(due)\n" }
            result += "   Captured: \(item.createdAt.formatted(date: .abbreviated, time: .omitted))\n"
            result += "   Evidence: \"\(item.evidence)\"\n\n"
        }
        return result
    }
}
