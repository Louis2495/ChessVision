import Foundation

public struct SquareRecognition: Equatable, Sendable {
    public let label: String
    public let confidence: Float
    public let uncertain: Bool
}

public enum RecognitionFusion {
    public static let labels = ["B", "K", "N", "P", "Q", "R", "empty", "b", "k", "n", "p", "q", "r"]
    private static func ranked(_ probabilities: [String: Float]) -> [(String, Float)] {
        var values: [(String, Float)] = []
        for label in labels { values.append((label, probabilities[label] ?? 0)) }
        values.sort { a, b in
            if a.1 == b.1 { return a.0 < b.0 }
            return a.1 > b.1
        }
        return values
    }
    private static func lowConfidence(_ values: [(String, Float)]) -> Bool {
        values[0].1 < 0.85 || values[0].1 - values[1].1 < 0.25
    }
    private static func kingBishopAmbiguity(_ probabilities: [String: Float]) -> Bool {
        let white = min(probabilities["K"] ?? 0, probabilities["B"] ?? 0)
        let black = min(probabilities["k"] ?? 0, probabilities["b"] ?? 0)
        return white > 0.15 || black > 0.15
    }
    public static func needsVerification(_ primary: [String: Float]) -> Bool {
        let values = ranked(primary)
        // Empty predictions also get a second opinion: a missed piece can otherwise look certain.
        return ["empty", "K", "k", "B", "b"].contains(values[0].0) || lowConfidence(values) || kingBishopAmbiguity(primary)
    }
    public static func classify(primary: [String: Float], verifier: [String: Float]? = nil) -> SquareRecognition {
        var probabilities = primary
        var disagreement = false
        if let verifier {
            for label in labels { probabilities[label] = ((primary[label] ?? 0) + (verifier[label] ?? 0)) / 2 }
            disagreement = ranked(primary)[0].0 != ranked(verifier)[0].0
        }
        let values = ranked(probabilities)
        return SquareRecognition(label: values[0].0, confidence: values[0].1,
                                 uncertain: disagreement || lowConfidence(values) || kingBishopAmbiguity(probabilities))
    }
}
