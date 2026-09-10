import SwiftUI
import SwiftData

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    var sources: [String] = []

    enum Role {
        case user, assistant
    }
}

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var inputText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            if isLoading {
                                HStack {
                                    ProgressView()
                                    Text("Aftermind is searching your memory...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading)
                                .id("loading")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastId = messages.last?.id {
                            withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                        }
                    }
                    .onChange(of: isLoading) { _, loading in
                        if loading {
                            withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
                        }
                    }
                }

                Divider()

                HStack {
                    TextField("Ask about your memories...", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { sendMessage() }

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundStyle(inputText.isEmpty || isLoading ? .gray : .blue)
                    }
                    .disabled(inputText.isEmpty || isLoading)
                }
                .padding()
            }
            .navigationTitle("Chat")
            .onAppear {
                if messages.isEmpty {
                    messages.append(ChatMessage(role: .assistant, content: "Hi! I'm Aftermind. Try: \"What did I promise to do?\" or \"What did I discuss with Rahul last week?\""))
                }
            }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(role: .user, content: text))
        inputText = ""
        isLoading = true

        Task {
            let retriever = ChatRetrievalService(modelContext: modelContext)
            let retrieved = retriever.retrieve(for: text)
            let contextString = retriever.formatContext(retrieved)
            let sourceTitles = retrieved.map { $0.item.title }

            let systemPrompt = """
            You are Aftermind, a personal memory assistant.
            Answer the user's question using ONLY the provided structured memories.
            If the answer is not present, say you don't have that memory instead of guessing.
            Be concise. Mention the memory title or evidence quote when it supports your answer.

            CONTEXT:
            \(contextString)
            """

            do {
                let response = try await LLMClient.shared.complete(systemPrompt: systemPrompt, userMessage: text)
                messages.append(ChatMessage(role: .assistant, content: response, sources: sourceTitles))
            } catch {
                messages.append(ChatMessage(role: .assistant, content: "Sorry, I encountered an error: \(error.localizedDescription)"))
            }
            isLoading = false
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                Text(message.content)
                    .padding(12)
                    .background(message.role == .user ? Color.blue : Color(.systemGray6))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)

                if !message.sources.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sources:")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        ForEach(Array(message.sources.prefix(3)), id: \.self) { source in
                            Label(source, systemImage: "link")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            if message.role == .assistant { Spacer() }
        }
    }
}
