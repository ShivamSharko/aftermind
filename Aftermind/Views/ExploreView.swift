import SwiftUI
import SwiftData

enum GroupingMode: String, CaseIterable {
    case people = "People"
    case topics = "Topics"
}

struct ExploreView: View {
    @Query private var items: [MemoryItemModel]
    @Query private var sessions: [SessionModel]
    @State private var mode: GroupingMode = .people

    private var peopleMap: [(String, [MemoryItemModel])] {
        var dict: [String: [MemoryItemModel]] = [:]
        for item in items {
            for person in item.people {
                dict[person, default: []].append(item)
            }
            if let owner = item.owner, owner != "user" {
                dict[owner, default: []].append(item)
            }
        }
        return dict.sorted { $0.key < $1.key }
    }

    private var topicsMap: [(String, [MemoryItemModel])] {
        var dict: [String: [MemoryItemModel]] = [:]
        for item in items {
            for tag in item.tags {
                dict[tag, default: []].append(item)
            }
        }
        for session in sessions {
            for topic in session.topics {
                for item in session.items {
                    if !item.tags.contains(topic) {
                        dict[topic, default: []].append(item)
                    }
                }
            }
        }
        return dict.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Group by", selection: $mode) {
                    ForEach(GroupingMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.top, 12)

                List {
                    let data = mode == .people ? peopleMap : topicsMap
                    if data.isEmpty {
                        Text("No \(mode.rawValue.lowercased()) found yet.")
                            .foregroundColor(Theme.textSecondary)
                            .listRowBackground(Theme.card)
                    } else {
                        ForEach(data, id: \.0) { key, group in
                            DisclosureGroup {
                                ForEach(group) { item in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            TypeBadge(type: item.type)
                                            Spacer()
                                            Text(item.createdAt, style: .date)
                                                .font(.caption2)
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                        Text(item.title)
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                    }
                                    .padding(.vertical, 4)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: mode == .people ? "person.fill" : "tag.fill")
                                        .foregroundColor(Theme.accent)
                                    Text(key)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(group.count)")
                                        .font(.caption.bold())
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            .listRowBackground(Theme.card)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
            .navigationTitle("Explore")
            .background(AmbientBackground())
        }
    }
}

