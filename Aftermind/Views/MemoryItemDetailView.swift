import SwiftUI
import SwiftData

struct MemoryItemDetailView: View {
    let item: MemoryItemModel
    
    var body: some View {
        List {
            Section("Type") {
                Text(item.type.capitalized)
            }
            Section("Title") {
                Text(item.title).font(.headline)
            }
            Section("Description") {
                Text(item.detail)
            }
            if !item.people.isEmpty {
                Section("People") {
                    ForEach(item.people, id: \.self) { person in
                        Label(person, systemImage: "person.fill")
                    }
                }
            }
            if let due = item.dueText {
                Section("Due") {
                    Text(due)
                }
            }
            Section("Evidence") {
                Text(item.evidence)
                    .font(.callout)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            Section("Confidence") {
                ProgressView(value: item.confidence) {
                    Text("\(Int(item.confidence * 100))% confident")
                }
            }
        }
        .navigationTitle(item.title)
    }
}

