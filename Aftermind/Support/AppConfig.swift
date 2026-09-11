import Foundation

enum AppConfig {
    /// Groq API key (free tier). Get one at https://console.groq.com/keys
    /// WARNING: never commit your real key to GitHub.
    private static let keychainKey = "groq_api_key"
    static var groqAPIKey: String {
        get { KeychainHelper.load(key: keychainKey) ?? "PASTE_YOUR_GROQ_API_KEY_HERE" }
        set { KeychainHelper.save(key: keychainKey, value: newValue) }
    }
    
    static func setup() { NotificationService.requestPermission() }

    /// Models hosted for free on Groq
    static let transcriptionModel = "whisper-large-v3"
    static let llmModel = "openai/gpt-oss-120b"

    /// true  = demo mode, no API key needed (returns a sample conversation)
    /// false = real mode, calls Groq Whisper with the recorded audio
    static let useMockTranscription = true

    static var transcriptionService: TranscriptionServiceProtocol {
        useMockTranscription ? MockTranscriptionService() : GroqTranscriptionService()
    }
}
