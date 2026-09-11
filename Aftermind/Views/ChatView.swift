import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ChatHistoryService.self) private var chatHistory
    @State private var inputText = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chat")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    Text("Answers grounded in your memories, with sources.")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 8)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(chatHistory.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            if isLoading {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .tint(Theme.accent)
                                    Text("Searching your memory...")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .padding(.leading, 4)
                                .id("loading")
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: chatHistory.messages.count) { _, _ in
                        if let lastId = chatHistory.messages.last?.id {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { proxy.scrollTo(lastId, anchor: .bottom) }
                        }
                    }
                    .onChange(of: isLoading) { _, loading in
                        if loading {
                            withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
                        }
                    }
                }

                HStack(spacing: 10) {
                    TextField("Ask your memory...", text: $inputText)
                        .foregroundColor(.white)
                        .tint(Theme.accent)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Theme.card, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                        .onSubmit(sendMessage)

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 46, height: 46)
                            .background(inputText.isEmpty || isLoading ? Color.white.opacity(0.15) : Theme.accent)
                            .clipShape(Circle())
                    }
                    .disabled(inputText.isEmpty || isLoading)
                    .buttonStyle(PressableStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 92)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if chatHistory.messages.isEmpty {
                    chatHistory.append(ChatMessage(role: .assistant, content: "Hi! I'm Aftermind. Try: “What did I promise to do?” or “What did I discuss with Rahul last week?”"))
                }
            }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        chatHistory.append(ChatMessage(role: .user, content: text))
        inputText = ""
        isLoading = true

        Task {
            let retriever = ChatRetrievalService(modelContext: modelContext)
            let retrieved = retriever.retrieve(for: text)
            let contextString = retriever.formatContext(retrieved)
            let sourceTitles = retrieved.map { $0.item.title }

            do {
                let response = try await AppConfig.chatAnswerService.answer(question: text, context: contextString)
                chatHistory.append(ChatMessage(role: .assistant, content: response, sources: sourceTitles))
            } catch {
                chatHistory.append(ChatMessage(role: .assistant, content: "Sorry, I encountered an error: \(error.localizedDescription)"))
            }
            isLoading = false
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                Text(message.content)
                    .font(.callout)
                    .foregroundColor(message.role == .user ? .black : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(message.role == .user ? Theme.accent : Theme.card, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(message.role == .user ? Color.clear : Color.white.opacity(0.06), lineWidth: 1))

                if !message.sources.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SOURCES")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundColor(Theme.textSecondary)
                        ForEach(Array(message.sources.prefix(3)), id: \.self) { source in
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.system(size: 8, weight: .bold))
                                Text(source)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 6)
                }
            }

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}
