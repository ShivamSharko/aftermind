import SwiftUI
import SwiftData

struct MemoryItemDetailView: View {
    let item: MemoryItemModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    TypeBadge(type: item.type)
                    Spacer()
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                
                if let owner = item.owner {
                    Label(owner == "user" ? "You own this" : "\(owner) owns this", systemImage: "person.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(owner == "user" ? Theme.accent : Theme.purpleLight)
                }
                if let dueDate = item.dueDate {
                    Label(dueDate.formatted(date: .complete, time: .omitted), systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.accent)
                }

                Text(item.title)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)

                Text(item.detail)
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))

                if !item.people.isEmpty {
                    SectionHeader(title: "People")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(item.people, id: \.self) { person in
                                PillChip(title: person, isSelected: false)
                            }
                        }
                    }
                }

                if let due = item.dueText {
                    SectionHeader(title: "Due")
                    Label(due, systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.accent)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                }

                SectionHeader(title: "Evidence")
                Text("“\(item.evidence)”")
                    .font(.callout.italic())
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))

                SectionHeader(title: "Confidence")
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: item.confidence)
                        .tint(Theme.accent)
                    Text("\(Int(item.confidence * 100))% confident")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(AmbientBackground())
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
