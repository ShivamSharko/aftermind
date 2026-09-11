import Foundation
import NaturalLanguage

final class EmbeddingService {
    static let shared = EmbeddingService()
    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)

    func vector(for text: String) -> [Double]? {
        embedding?.vector(for: text)
    }

    func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in 0..<a.count {
            dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i]
        }
        guard na > 0, nb > 0 else { return 0 }
        return dot / (sqrt(na) * sqrt(nb))
    }
}
