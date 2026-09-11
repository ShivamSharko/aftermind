import Foundation

protocol ChatAnswerServiceProtocol {
    func answer(question: String, context: String) async throws -> String
}

final class GroqChatAnswerService: ChatAnswerServiceProtocol {
    func answer(question: String, context: String) async throws -> String {
        let systemPrompt = """
        You are Aftermind, a personal memory assistant.
        Answer the user's question using ONLY the provided structured memories.
        If the answer is not present, say you don't have that memory instead of guessing.
        Be concise. Mention the memory title or evidence quote when it supports your answer.

        CONTEXT:
        \(context)
        """
        let response = try await LLMClient.shared.complete(systemPrompt: systemPrompt, userMessage: question, enableWebSearch: true)
        return response
    }
}

final class MockChatAnswerService: ChatAnswerServiceProtocol {
    func answer(question: String, context: String) async throws -> String {
        try await Task.sleep(nanoseconds: 600_000_000)
        guard !context.contains("No relevant memories") else {
            return "I don't have a memory about that yet. Try recording a conversation or loading a demo session."
        }
        let lines = context
            .split(separator: "\n")
            .map(String.init)
            .filter { $0.first?.isNumber == true && $0.contains(". [") }
        let top = Array(lines.prefix(3))
        guard !top.isEmpty else {
            return "I don't have a memory about that yet."
        }
        return "From your stored memories (mock mode):\n" + top.joined(separator: "\n")
    }
}

