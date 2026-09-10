import SwiftUI
import SwiftData

struct MemoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SessionModel.createdAt, order: .reverse) private var sessions: [SessionModel]
    @State private var seedError = false

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView("No memories yet", systemImage: "brain.head.profile", description: Text("Record a conversation, or load a demo session from the toolbar."))
                } else {
                    List {
                        ForEach(sessions) { session in
                            NavigationLink {
                                SessionDetailView(session: session)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.summary)
                                        .font(.headline)
                                        .lineLimit(2)
                                    HStack {
                                        Text(session.createdAt, style: .date)
                                        Text("•")
                                        Text("\(session.items.count) items")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Memory")
            .toolbar {
                Button("Load demo session") { seedDemoSession() }
            }
            .alert("Could not load demo session", isPresented: $seedError) {
                Button("OK", role: .cancel) { }
            }
        }
    }

    private func seedDemoSession() {
        Task {
            do {
                let extracted = try await MockContextExtractionService().extract(from: "demo")
                let session = SessionModel(
                    createdAt: Date(),
                    summary: extracted.session_summary,
                    transcript: "Demo session loaded for testing and demonstration.",
                    topics: extracted.topics
                )
                modelContext.insert(session)
                for item in extracted.items {
                    let memoryItem = MemoryItemModel(
                        type: item.type,
                        title: item.title,
                        detail: item.description,
                        people: item.related_people,
                        evidence: item.evidence,
                        confidence: item.confidence,
                        dueText: item.due_text
                    )
                    memoryItem.session = session
                    modelContext.insert(memoryItem)
                }
                try modelContext.save()
            } catch {
                seedError = true
            }
        }
    }
}

struct SessionDetailView: View {
    let session: SessionModel

    var body: some View {
        List {
            Section("Summary") {
                Text(session.summary)
            }
            if !session.topics.isEmpty {
                Section("Topics") {
                    Text(session.topics.joined(separator: ", "))
                        .font(.callout)
                }
            }
            Section("Extracted Items (\(session.items.count))") {
                ForEach(session.items) { item in
                    NavigationLink {
                        MemoryItemDetailView(item: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.type.capitalized)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .clipShape(Capsule())
                                Spacer()
                                Text("\(Int(item.confidence * 100))%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(item.title)
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            Section("Raw Transcript") {
                Text(session.transcript)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Session Details")
    }
}

