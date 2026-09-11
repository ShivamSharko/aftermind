import Foundation

enum AppConfig {
    /// Groq API key (free tier). Get one at https://console.groq.com/keys
    /// WARNING: never commit your real key to GitHub.
    private static let keychainKey = "groq_api_key"

    /// Real-mode keys are read from the iOS Keychain (injected on a developer machine).
    /// The placeholder keeps zero-key demo mode working; no secrets ship in the repo.
    static var groqAPIKey: String {
        KeychainHelper.load(key: keychainKey) ?? "PASTE_YOUR_GROQ_API_KEY_HERE"
    }
    
    static func setup() { NotificationService.requestPermission() }

    /// Models hosted for free on Groq
    static let transcriptionModel = "whisper-large-v3"
    static let llmModel = "groq/compound-mini" // Compound system with integrated reasoning for structured extraction
    static let chatModel = "groq/compound" // Compound system with integrated reasoning and web search for enriched answers

    /// true  = demo mode, no API key needed (returns a sample conversation)
    /// false = real mode, calls Groq Whisper with the recorded audio
    static let useMockTranscription = true

    static var transcriptionService: TranscriptionServiceProtocol {
        useMockTranscription ? MockTranscriptionService() : GroqTranscriptionService()
    }
    
    static var chatAnswerService: ChatAnswerServiceProtocol {
        useMockTranscription ? MockChatAnswerService() : GroqChatAnswerService()
    }
}
