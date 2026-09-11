import SwiftUI
import SwiftData

struct PeopleView: View {
    @Query private var items: [MemoryItemModel]
    @State private var selectedPerson: String?
    
    private var people: [String: [MemoryItemModel]] {
        var dict: [String: [MemoryItemModel]] = [:]
        for item in items {
            for person in item.people {
                dict[person, default: []].append(item)
            }
        }
        return dict
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(people.keys).sorted(), id: \.self) { person in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { selectedPerson == person },
                            set: { selectedPerson = $0 ? person : nil }
                        )
                    ) {
                        ForEach(people[person] ?? []) { item in
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
                            Image(systemName: "person.fill")
                                .foregroundColor(Theme.accent)
                            Text(person)
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(people[person]?.count ?? 0)")
                                .font(.caption.bold())
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .navigationTitle("People")
            .background(AmbientBackground())
        }
    }
}

