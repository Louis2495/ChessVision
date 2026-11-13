import Foundation

public struct DailyPuzzleRecord: Codable, Sendable {
    public var puzzleID: String
    public var correct: Bool
    public var completed: Bool
    public init(puzzleID: String, correct: Bool, completed: Bool = false) {
        self.puzzleID = puzzleID; self.correct = correct; self.completed = completed
    }
}
public enum DailyPuzzle {
    public static func key(for date: Date, calendar: Calendar = .current) -> String {
        var gregorian = Calendar(identifier: .gregorian); gregorian.timeZone = calendar.timeZone
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 2000, parts.month ?? 1, parts.day ?? 1)
    }
    public static func choose(day: String, puzzles: [ChessPuzzle], saved: DailyPuzzleRecord? = nil) -> ChessPuzzle? {
        if let saved, let original = puzzles.first(where: { $0.id == saved.puzzleID }) { return original }
        let moderate = puzzles.filter { (1000...2200).contains($0.sourceRating) }
        let choices = (moderate.isEmpty ? puzzles : moderate).sorted { $0.id < $1.id }
        guard !choices.isEmpty else { return nil }
        var hash: UInt64 = 14695981039346656037
        for byte in day.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return choices[Int(hash % UInt64(choices.count))]
    }
}
public enum OpeningLessons {
    public static let additional: [OpeningLine] = {
        let lines = [
            ("lesson-london", "D02", "London System: Main development", "1. d4 d5 2. Nf3 Nf6 3. Bf4 e6 4. e3 Bd6 5. Bg3 O-O 6. Bd3 c5 7. c3 Nc6 8. Nbd2 b6 9. O-O Bb7 10. Ne5"),
            ("lesson-scandinavian", "B01", "Scandinavian Defense: Classical development", "1. e4 d5 2. exd5 Qxd5 3. Nc3 Qa5 4. d4 Nf6 5. Nf3 c6 6. Bc4 Bf5 7. O-O e6 8. Bd2 Qc7 9. Re1 Nbd7 10. Ne5 Bd6"),
            ("lesson-modern", "B06", "Modern Defense: Queenside expansion", "1. e4 g6 2. d4 Bg7 3. Nc3 d6 4. Nf3 a6 5. Be2 b5 6. O-O Bb7 7. a3 Nd7 8. Be3 e6 9. Qd2 Ne7 10. Bh6 O-O")
        ]
        return lines.compactMap { id, eco, name, pgn in
            guard let game = try? PGNGame.parse(pgn) else { return nil }
            var board = Position.initial
            for uci in game.moves { guard (try? board.apply(uci: uci)) != nil else { return nil } }
            return OpeningLine(id: id, eco: eco, name: name, moves: game.moves, key: board.openingKey)
        }
    }()

    public static func curated(in openings: [OpeningLine]) -> [OpeningLine] {
        let families = ["Italian", "Ruy Lopez", "Queen's Gambit Declined", "Queen's Gambit Accepted", "Sicilian Defense: Najdorf", "Sicilian Defense: Dragon", "Sicilian Defense: Classical", "Caro-Kann", "French Defense: Winawer", "French Defense: Tarrasch", "Nimzo-Indian", "King's Indian", "Grünfeld", "Catalan", "Semi-Slav", "Slav Defense", "Dutch", "Pirc", "Alekhine", "Petrov", "Scotch", "Vienna", "Four Knights", "English", "Réti", "King's Gambit", "Queen's Indian", "Bogo-Indian", "Benoni", "Benko", "Budapest", "Bird", "Philidor", "Ponziani", "Evans Gambit", "Trompowsky", "Colle", "Stonewall", "Nimzowitsch Defense"]
        var selected: Set<String> = []
        let curated: [OpeningLine] = families.flatMap { family in
            let candidates = openings.filter { $0.name.localizedCaseInsensitiveContains(family) && (16...40).contains($0.moves.count) && !selected.contains($0.id) }
            let ordered = candidates.sorted {
                let a = abs($0.moves.count - 24), b = abs($1.moves.count - 24)
                return a == b ? $0.id < $1.id : a < b
            }
            var branches: Set<String> = []
            var choices: [OpeningLine] = []
            for line in ordered where choices.count < 2 {
                guard branches.insert(line.moves.prefix(12).joined(separator: " ")).inserted else { continue }
                selected.insert(line.id); choices.append(line)
            }
            return choices
        }
        return curated + additional
    }
}
public struct ImprovementStatistics: Sendable {
    public var counts: [ImprovementConcept: Int] = [:]
    public var reviewedGames = 0
    public var ordered: [ImprovementConcept] {
        counts.keys.sorted { counts[$0, default: 0] == counts[$1, default: 0] ? $0.rawValue < $1.rawValue : counts[$0, default: 0] > counts[$1, default: 0] }
    }
    public init(history: [CompletedGame]) {
        var seen: Set<UUID> = []
        for entry in history where seen.insert(entry.id).inserted {
            guard let review = entry.review else { continue }
            reviewedGames += 1
            var plies: Set<Int> = []
            for suggestion in review.suggestions where suggestion.side == entry.game.human && plies.insert(suggestion.ply).inserted {
                counts[suggestion.concept, default: 0] += 1
            }
        }
    }
}

extension LibraryState {
    /// Daily replays never change the puzzle rating twice, even after app restart.
    @discardableResult public mutating func recordPuzzle(_ puzzle: ChessPuzzle, correct: Bool, daily day: String? = nil) -> Bool {
        if let day {
            guard dailyPuzzles[day] == nil else { return false }
            dailyPuzzles[day] = DailyPuzzleRecord(puzzleID: puzzle.id, correct: correct)
        }
        self.puzzle.record(puzzle, correct: correct)
        return true
    }
    public mutating func completeDailyPuzzle(day: String) {
        guard dailyPuzzles[day] != nil else { return }
        dailyPuzzles[day]?.completed = true
    }
}
