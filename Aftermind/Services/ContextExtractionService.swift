import Foundation

protocol ContextExtractionServiceProtocol {
    func extract(from transcript: String) async throws -> ExtractedSession
}

final class GroqContextExtractionService: ContextExtractionServiceProtocol {
    
    private let llm = LLMClient.shared
    
    private var systemPrompt: String {
        let today = Date().formatted(date: .complete, time: .omitted)
        return """
        You are a context extraction engine for a personal memory app called Aftermind.
        Today's date is: \(today).
        Extract durable information and discard noise.
        Rules:
        1. Identify participants and topics.
        2. Extract commitments, tasks, decisions, facts, ideas.
        3. "owner": Who is responsible? Use "user" for the recorder, otherwise the person's name, or null.
        4. "due_date": Resolve relative time ("Friday", "tomorrow") into an absolute ISO date (yyyy-MM-dd). Keep original words in "due_text".
        5. Output ONLY valid JSON matching this schema:
        {
          "session_summary": "string",
          "participants": [{ "name": "string", "role": "string" }],
          "topics": ["string"],
          "items": [
            {
              "type": "commitment" | "task" | "decision" | "fact" | "idea" | "preference",
              "title": "string",
              "description": "string",
              "owner": "user" | "name" | null,
              "related_people": ["string"],
              "due_text": "string or null",
              "due_date": "yyyy-MM-dd or null",
              "confidence": 0.9,
              "evidence": "string",
              "status": "string or null",
              "tags": ["string"]
            }
          ]
        }
        """
    }
    
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
              "owner": "user",
              "related_people": ["Rahul"],
              "due_text": "tonight",
              "due_date": "2026-09-12",
              "confidence": 0.95,
              "evidence": "I'll send you the pitch deck tonight.",
              "status": "open",
              "tags": ["startup", "fundraising"]
            },
            {
              "type": "fact",
              "title": "Sarah will send the contract",
              "description": "Sarah said she would send the contract by email.",
              "owner": "Sarah",
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
              "owner": "user",
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
              "owner": "user",
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

