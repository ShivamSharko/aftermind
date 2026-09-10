import SwiftUI
import SwiftData

struct MemoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SessionModel.createdAt, order: .reverse) private var sessions: [SessionModel]
    @State private var seedError = false

    private var totalItems: Int { sessions.reduce(0) { $0 + $1.items.count } }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Memory")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            Text("\(sessions.count) sessions • \(totalItems) memories")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        CircleIconButton(systemName: "sparkles", action: seedDemoSession)
                    }
                    .padding(.top, 12)

                    if sessions.isEmpty {
                        emptyCard
                    } else {
                        featuredCard(sessions[0])
                        SectionHeader(title: "Recent sessions")
                        VStack(spacing: 12) {
                            ForEach(sessions) { session in
                                NavigationLink {
                                    SessionDetailView(session: session)
                                } label: {
                                    sessionRow(session)
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 110)
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("Could not load demo session", isPresented: $seedError) {
                Button("OK", role: .cancel) { }
            }
        }
    }

    private var emptyCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(Theme.purpleLight)
            Text("No memories yet")
                .font(.headline)
                .foregroundColor(.white)
            Text("Record a conversation, or load a demo session to explore.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button(action: seedDemoSession) {
                Text("Load demo session")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 26))
    }

    private func featuredCard(_ session: SessionModel) -> some View {
        NavigationLink {
            SessionDetailView(session: session)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                Text("LATEST SESSION")
                    .font(.caption2.weight(.heavy))
                    .foregroundColor(.black.opacity(0.55))
                Text(session.summary)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.black)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.black.opacity(0.75)).frame(width: 42, height: 42)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("\(session.items.count) memories")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black.opacity(0.7))
                    Spacer()
                    Text(session.createdAt, style: .date)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.black.opacity(0.6))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Theme.purpleLight, Theme.purpleDeep], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 26)
            )
            .shadow(color: Theme.purpleDeep.opacity(0.5), radius: 20, y: 10)
        }
        .buttonStyle(PressableStyle())
    }

    private func sessionRow(_ session: SessionModel) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardSecondary)
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.color(for: session.items.first?.type ?? "fact"))
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(session.summary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(session.createdAt.formatted(date: .abbreviated, time: .shortened)) • \(session.items.count) items")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
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
    @Environment(\.modelContext) private var modelContext
    let session: SessionModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(session.createdAt.formatted(date: .complete, time: .shortened))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.black.opacity(0.55))
                    Text(session.summary)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.black)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(colors: [Theme.purpleLight, Theme.purpleDeep], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 26)
                )

                if !session.topics.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(session.topics, id: \.self) { topic in
                                PillChip(title: topic, isSelected: false)
                            }
                        }
                    }
                }

                SectionHeader(title: "Extracted items (\(session.items.count))")
                VStack(spacing: 12) {
                    ForEach(session.items) { item in
                        NavigationLink {
                            MemoryItemDetailView(item: item)
                        } label: {
                            itemCard(item)
                        }
                        .buttonStyle(PressableStyle())
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                item.isCompleted.toggle()
                                try? modelContext.save()
                            } label: {
                                Label(item.isCompleted ? "Reopen" : "Done", systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark")
                            }
                            .tint(item.isCompleted ? .orange : Theme.accent)
                        }
                    }
                }

                SectionHeader(title: "Raw transcript")
                Text(session.transcript)
                    .font(.callout)
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(AmbientBackground())
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func itemCard(_ item: MemoryItemModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TypeBadge(type: item.type)
                Spacer()
                Text("\(Int(item.confidence * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Theme.accent)
            }
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .opacity(item.isCompleted ? 0.5 : 1.0)
                .strikethrough(item.isCompleted)
            if !item.people.isEmpty {
                Text(item.people.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
    }
}
