import Foundation

public struct ChessFact: Codable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var detail: String
    public var category: String
    public var metric: String?
    public var symbol: String
    public var source: String
    public var diagram: String?
}
public struct ChessMilestone: Codable, Identifiable, Sendable {
    public var id: String
    public var year: Int
    public var title: String
    public var detail: String
    public var symbol: String
    public var source: String
}
public struct ChessChampion: Codable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var start: Int
    public var end: Int?
    public var track: String
    public var elo: Int?
    public var ratingYear: Int?
    public var source: String
    public var highlight: String
    public var reign: String { end.map { "\(start)–\($0)" } ?? "Won \(start)" }
}
public struct ChessLearningContent: Codable, Sendable {
    public var coverageThrough: Int
    public var ratingNote: String
    public var facts: [ChessFact]
    public var milestones: [ChessMilestone]
    public var champions: [ChessChampion]
}

public enum LearningDiagram {
    /// Empty-board destinations from a central square, for educational illustrations only.
    public static func targets(for kind: String, origin: Int = 27) -> Set<Int> {
        guard (0..<64).contains(origin) else { return [] }
        let row = origin / 8, file = origin % 8
        var targets: Set<Int> = []
        if kind == "n" {
            for (dr, df) in [(-2,-1),(-2,1),(-1,-2),(-1,2),(1,-2),(1,2),(2,-1),(2,1)] {
                let r = row + dr, f = file + df
                if (0..<8).contains(r) && (0..<8).contains(f) { targets.insert(r * 8 + f) }
            }
        } else {
            let diagonal = [(-1,-1),(-1,1),(1,-1),(1,1)], straight = [(-1,0),(1,0),(0,-1),(0,1)]
            let directions = kind == "b" ? diagonal : kind == "r" ? straight : kind == "q" || kind == "k" ? diagonal + straight : []
            for (dr, df) in directions {
                for distance in 1...(kind == "k" ? 1 : 7) {
                    let r = row + distance * dr, f = file + distance * df
                    guard (0..<8).contains(r) && (0..<8).contains(f) else { break }
                    targets.insert(r * 8 + f)
                }
            }
        }
        return targets
    }
}
