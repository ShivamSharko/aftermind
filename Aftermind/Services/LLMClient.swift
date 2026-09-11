import Foundation

enum LLMError: LocalizedError {
    case missingKey
    case invalidURL
    case badResponse
    case serverError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .missingKey: return "Groq API key missing."
        case .invalidURL: return "Invalid URL."
        case .badResponse: return "Could not parse LLM response."
        case .serverError(let code, let msg): return "LLM Error \(code): \(msg)"
        }
    }
}

final class LLMClient {
    static let shared = LLMClient()
    
    private init() {}
    
    func complete(systemPrompt: String, userMessage: String, jsonMode: Bool = false, enableWebSearch: Bool = false) async throws -> String {
        let apiKey = AppConfig.groqAPIKey
        guard !apiKey.isEmpty, !apiKey.contains("PASTE") else { throw LLMError.missingKey }
        
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            throw LLMError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Force JSON output from Groq
        var requestBody: [String: Any] = [
            "model": enableWebSearch ? AppConfig.chatModel : AppConfig.llmModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ],
            "temperature": 0.2
        ]
        
        if jsonMode {
            requestBody["response_format"] = ["type": "json_object"]
        }
        

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else { throw LLMError.badResponse }
        guard (200...299).contains(http.statusCode) else {
            let err = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.serverError(http.statusCode, err)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.badResponse
        }
        
        return content
    }
}

