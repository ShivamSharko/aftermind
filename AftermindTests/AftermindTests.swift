import XCTest
@testable import Aftermind

final class AftermindTests: XCTestCase {

    // Test 1: ContextExtractionService JSON parsing (Context Understanding)
    func testExtractedSessionDecoding() throws {
        let jsonString = """
        {
          "session_summary": "Test summary",
          "participants": [{"name": "Rahul", "role": "friend"}],
          "topics": ["startup"],
          "items": [
            {
              "type": "commitment",
              "title": "Send deck",
              "description": "Send the pitch deck",
              "owner": "user",
              "related_people": ["Rahul"],
              "due_text": "tonight",
              "due_date": "2026-09-12",
              "confidence": 0.95,
              "evidence": "I'll send it tonight",
              "status": "open",
              "tags": ["fundraising"]
            }
          ]
        }
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let session = try decoder.decode(ExtractedSession.self, from: data)
        
        XCTAssertEqual(session.session_summary, "Test summary")
        XCTAssertEqual(session.participants.count, 1)
        XCTAssertEqual(session.participants.first?.name, "Rahul")
        XCTAssertEqual(session.items.count, 1)
        
        let item = session.items.first!
        XCTAssertEqual(item.type, "commitment")
        XCTAssertEqual(item.title, "Send deck")
        XCTAssertEqual(item.owner, "user")
        XCTAssertEqual(item.confidence, 0.95)
        XCTAssertEqual(item.tags, ["fundraising"])
    }

    // Test 2: Scoring Math - Cosine Similarity (Technical Strength)
    func testCosineSimilarityMath() {
        let service = EmbeddingService.shared
        
        // Identical vectors should have similarity 1.0
        let v1 = [1.0, 0.0, 0.0]
        let v2 = [1.0, 0.0, 0.0]
        XCTAssertEqual(service.cosine(v1, v2), 1.0, accuracy: 0.001)
        
        // Orthogonal vectors should have similarity 0.0
        let v3 = [0.0, 1.0, 0.0]
        XCTAssertEqual(service.cosine(v1, v3), 0.0, accuracy: 0.001)
        
        // Opposite vectors should have similarity -1.0
        let v4 = [-1.0, 0.0, 0.0]
        XCTAssertEqual(service.cosine(v1, v4), -1.0, accuracy: 0.001)
    }
    
    // Test 3: Date Parsing (Temporal Normalization)
    func testDateParsing() {
        let date = DateParsing.isoDate("2026-09-12")
        XCTAssertNotNil(date)
        
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 9)
        XCTAssertEqual(components.day, 12)
        
        XCTAssertNil(DateParsing.isoDate(nil))
        XCTAssertNil(DateParsing.isoDate("invalid"))
    }
}

