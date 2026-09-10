import Foundation

struct TranscriptionResult {
    let text: String
    let provider: String
}

enum TranscriptionError: LocalizedError {
    case missingAPIKey
    case badResponse
    case serverError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Groq API key is missing. Add it in AppConfig.swift or enable mock mode."
        case .badResponse:
            return "Unexpected response from the transcription service."
        case .serverError(let code, let body):
            return "Transcription failed (\(code)): \(body)"
        }
    }
}

protocol TranscriptionServiceProtocol {
    func transcribe(audioURL: URL) async throws -> TranscriptionResult
}

final class GroqTranscriptionService: TranscriptionServiceProtocol {

    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        let apiKey = AppConfig.groqAPIKey
        guard !apiKey.isEmpty, !apiKey.contains("PASTE") else {
            throw TranscriptionError.missingAPIKey
        }

        let audioData = try Data(contentsOf: audioURL)

        guard let url = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions") else {
            throw TranscriptionError.badResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(AppConfig.transcriptionModel)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)

        guard let http = response as? HTTPURLResponse else {
            throw TranscriptionError.badResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw TranscriptionError.serverError(statusCode: http.statusCode, body: bodyText)
        }

        struct TranscriptionResponse: Decodable {
            let text: String
        }
        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return TranscriptionResult(text: decoded.text, provider: AppConfig.transcriptionModel)
    }
}

final class MockTranscriptionService: TranscriptionServiceProtocol {

    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        // Simulate network latency so the UI processing state is visible.
        try await Task.sleep(nanoseconds: 1_200_000_000)
        let text = """
        Hey Rahul, thanks for meeting. I think we should focus on the startup idea first. \
        I'll send you the pitch deck tonight. Also, Sarah said she would send the contract \
        tomorrow. We still need to hire an iOS developer. I can follow up with Priya about \
        that. Let's decide by Friday whether we move forward.
        """
        return TranscriptionResult(text: text, provider: "mock")
    }
}
