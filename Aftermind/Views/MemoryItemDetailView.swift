import SwiftUI
import SwiftData

struct MemoryItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var reminderAdded = false
    let item: MemoryItemModel

    private var isActionable: Bool { item.type == "commitment" || item.type == "task" }

    private var draftText: String {
        let person = (item.owner == "user") ? (item.people.first ?? "there") : (item.owner ?? "there")
        return "Hi \(person) - following up on this: \(item.title). Context: \"\(item.evidence)\" (sent via Aftermind)"
    }

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

                if !item.tags.isEmpty {
                    SectionHeader(title: "Tags")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(item.tags, id: \.self) { tag in
                                PillChip(title: tag, isSelected: false)
                            }
                        }
                    }
                }

                if let status = item.status {
                    SectionHeader(title: "Status")
                    Label(status.capitalized, systemImage: item.isCompleted ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(item.status == "disputed" ? Color(red: 1.0, green: 0.45, blue: 0.50) : (item.isCompleted ? Theme.accent : Theme.textSecondary))
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                }

                if isActionable {
                    SectionHeader(title: "Actions")
                    VStack(spacing: 10) {
                        Button {
                            Task {
                                let granted = await ReminderBridge.requestAccess()
                                if granted {
                                    reminderAdded = ReminderBridge.add(title: item.title, due: item.dueDate)
                                }
                            }
                        } label: {
                            Label(reminderAdded ? "Added to Apple Reminders" : "Add to Apple Reminders", systemImage: reminderAdded ? "checkmark.circle.fill" : "bell.badge.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.black)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(Theme.accent)
                                .clipShape(Capsule())
                        }
                        .disabled(reminderAdded)
                        .buttonStyle(PressableStyle())

                        ShareLink(item: draftText) {
                            Label("Draft follow-up message", systemImage: "paperplane.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(Theme.purpleDeep)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PressableStyle())
                    }
                }

                Button(role: .destructive) {
                    item.status = "disputed"
                    item.confidence = max(0.1, item.confidence * 0.5)
                    try? modelContext.save()
                } label: {
                    Label(item.status == "disputed" ? "Marked as inaccurate - tap evidence to review" : "Mark as inaccurate", systemImage: "exclamationmark.triangle")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.50))
                }
                .buttonStyle(PressableStyle())
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
