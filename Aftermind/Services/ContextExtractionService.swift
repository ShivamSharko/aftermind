import Foundation

protocol ContextExtractionServiceProtocol {
    func extract(from transcript: String) async throws -> ExtractedSession
}

final class GroqContextExtractionService: ContextExtractionServiceProtocol {
    
    private let llm = LLMClient.shared
    
    private let systemPrompt = """
    You are a context extraction engine for a personal memory app called Aftermind.
    You will receive a raw conversation transcript.
    Your job is to extract only durable, useful information and discard noise.
    
    Rules:
    1. Identify participants and topics.
    2. Extract meaningful items (commitments, decisions, tasks, deadlines, preferences, facts, ideas).
    3. Ignore filler, repeated phrases, and low-value small talk.
    4. Include evidence snippets from the transcript for each item.
    5. Assign a confidence score from 0.0 to 1.0.
    
    You MUST output ONLY valid JSON matching this exact schema:
    {
      "session_summary": "string",
      "participants": [{ "name": "string", "role": "string" }],
      "topics": ["string"],
      "items": [
        {
          "type": "commitment" | "task" | "decision" | "fact" | "idea" | "preference",
          "title": "string",
          "description": "string",
          "related_people": ["string"],
          "due_text": "string or null",
          "due_date": "string or null",
          "confidence": 0.9,
          "evidence": "string from transcript",
          "status": "string or null",
          "tags": ["string"]
        }
      ]
    }
    """
    
    func extract(from transcript: String) async throws -> ExtractedSession {
        let rawJSON = try await llm.complete(systemPrompt: systemPrompt, userMessage: transcript)
        
        guard let jsonData = rawJSON.data(using: .utf8) else {
            throw LLMError.badResponse
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ExtractedSession.self, from: jsonData)
    }
}

final class MockContextExtractionService: ContextExtractionServiceProtocol {
    func extract(from transcript: String) async throws -> ExtractedSession {
        try await Task.sleep(nanoseconds: 800_000_000)
        
        let jsonString = """
        {
          "session_summary": "User discussed startup hiring with Rahul and promised to send the pitch deck. Sarah will send the contract.",
          "participants": [
            { "name": "Rahul", "role": "co-founder / friend" },
            { "name": "Sarah", "role": "legal / admin" },
            { "name": "Priya", "role": "recruiter / contact" }
          ],
          "topics": ["startup", "hiring", "fundraising"],
          "items": [
            {
              "type": "commitment",
              "title": "Send pitch deck to Rahul",
              "description": "User promised to send the latest pitch deck.",
              "related_people": ["Rahul"],
              "due_text": "tonight",
              "due_date": null,
              "confidence": 0.95,
              "evidence": "I'll send you the pitch deck tonight.",
              "status": "open",
              "tags": ["startup", "fundraising"]
            },
            {
              "type": "fact",
              "title": "Sarah will send the contract",
              "description": "Sarah said she would send the contract by email.",
              "related_people": ["Sarah"],
              "due_text": "tomorrow",
              "due_date": null,
              "confidence": 0.90,
              "evidence": "Sarah said she would send the contract tomorrow.",
              "status": "pending",
              "tags": ["legal"]
            },
            {
              "type": "task",
              "title": "Follow up with Priya about iOS developer",
              "description": "User needs to contact Priya to hire an iOS developer.",
              "related_people": ["Priya"],
              "due_text": null,
              "due_date": null,
              "confidence": 0.85,
              "evidence": "I can follow up with Priya about that.",
              "status": "open",
              "tags": ["hiring"]
            },
            {
              "type": "decision",
              "title": "Decide on startup direction by Friday",
              "description": "Team needs to make a final go/no-go decision.",
              "related_people": ["Rahul"],
              "due_text": "Friday",
              "due_date": null,
              "confidence": 0.88,
              "evidence": "Let's decide by Friday whether we move forward.",
              "status": "pending",
              "tags": ["startup"]
            }
          ]
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        return try JSONDecoder().decode(ExtractedSession.self, from: data)
    }
}

enum ContextExtractor {
    static let service: ContextExtractionServiceProtocol = AppConfig.useMockTranscription 
        ? MockContextExtractionService() 
        : GroqContextExtractionService()
}

