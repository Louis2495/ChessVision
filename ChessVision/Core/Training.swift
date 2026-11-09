import Foundation

public struct ChessPuzzle: Codable, Identifiable, Sendable {
    public var id: String
    public var fen: String
    /// Lichess format: first ply is the opponent's setup move, followed by the solution.
    public var moves: [String]
    public var sourceRating: Int
    public var estimatedRating: Int
    public var themes: [String]
    public var gameURL: String
    public func startingPosition() throws -> Position {
        var board = try Position(fen: fen)
        guard let setup = moves.first, moves.count >= 2,
              let move = board.legalMoves().first(where: { $0.uci == setup }) else { throw ChessError.invalid("This puzzle has an invalid setup.") }
        board = try board.playing(move)
        return board
    }
}
public struct PuzzleProgress: Codable, Sendable {
    public var rating: Double = 1000
    public var attempts = 0
    public var solved = 0
    public var completed: [String] = []
    public init() {}
    public mutating func record(_ puzzle: ChessPuzzle, correct: Bool) {
        let expected = 1 / (1 + pow(10, Double(puzzle.estimatedRating - Int(rating)) / 400))
        rating = max(200, min(3500, rating + 40 * ((correct ? 1 : 0) - expected)))
        attempts += 1; if correct { solved += 1 }
        if !completed.contains(puzzle.id) { completed.append(puzzle.id) }
    }
    public func next(in puzzles: [ChessPuzzle], excluding current: String? = nil) -> ChessPuzzle? {
        let fresh = puzzles.filter { !completed.contains($0.id) && $0.id != current }
        let candidates = fresh.isEmpty ? puzzles.filter { $0.id != current } : fresh
        // Small deterministic diversity prevents returning the same tied puzzle every session.
        return candidates.min { a, b in
            let da = abs(Double(a.estimatedRating) - rating), db = abs(Double(b.estimatedRating) - rating)
            return da == db ? a.id < b.id : da < db
        }
    }
}

public struct RepertoireLine: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var name: String
    public var side: Side
    public var startingFEN: String
    public var moves: [String]
    public var created = Date()
    public var trained = 0
    public var successes = 0
    public var due = Date()
    public init(name: String, side: Side, startingFEN: String = Position.initial.fen, moves: [String]) {
        self.name = name; self.side = side; self.startingFEN = startingFEN; self.moves = moves
    }
    public mutating func record(correct: Bool, now: Date = Date()) {
        trained += 1; if correct { successes += 1 }
        let days = correct ? min(30, max(1, successes * 2)) : 0
        due = now.addingTimeInterval(Double(days) * 86400)
    }
    public func validated() throws -> [NotatedMove] {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !moves.isEmpty else { throw ChessError.invalid("Give the line a name and at least one move.") }
        let board = try Position(fen: startingFEN)
        guard board.problems.isEmpty else { throw ChessError.invalid(board.problems.joined(separator: "\n")) }
        let notation = try ChessNotation.variation(moves, from: board)
        guard notation.contains(where: { $0.side == side }) else { throw ChessError.invalid("Add at least one move for \(side.title) to train.") }
        return notation
    }
}
public struct RepertoireMatch: Sendable {
    public var line: RepertoireLine
    public var index: Int
    public var move: String
}
public enum RepertoireTraining {
    /// Accept any saved branch from this position, including transpositions.
    public static func choices(at position: Position, in lines: [RepertoireLine]) -> [RepertoireMatch] {
        var matches: [RepertoireMatch] = []
        for line in lines where line.side == position.turn {
            guard var board = try? Position(fen: line.startingFEN) else { continue }
            for (index, uci) in line.moves.enumerated() {
                if board.openingKey == position.openingKey { matches.append(RepertoireMatch(line: line, index: index, move: uci)) }
                guard let move = board.legalMoves().first(where: { $0.uci == uci }), let next = try? board.playing(move) else { break }
                board = next
            }
        }
        return matches
    }
}

public enum GameMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case normal, blindBoard, blindText, threeCheck, kingOfTheHill, horde, crazyhouse
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .normal: return "Normal"
        case .blindBoard: return "Blindfold · empty board"
        case .blindText: return "Blindfold · text only"
        case .threeCheck: return "3-Check"
        case .kingOfTheHill: return "King of the Hill"
        case .horde: return "Horde"
        case .crazyhouse: return "Crazyhouse"
        }
    }
    public var variant: String {
        switch self { case .threeCheck: return "3check"; case .kingOfTheHill: return "kingofthehill"; case .horde: return "horde"; case .crazyhouse: return "crazyhouse"; default: return "chess" }
    }
    public var explanation: String {
        switch self {
        case .normal: return "Standard chess. You can ask the computer to follow a named opening."
        case .blindBoard: return "The squares stay visible, but pieces and legal-move hints are hidden."
        case .blindText: return "No board or pieces. Enter moves such as Nf3, exd5 or O-O."
        case .threeCheck: return "Give check three times to win. Checkmate also wins."
        case .kingOfTheHill: return "Bring your king safely to d4, e4, d5 or e5 to win."
        case .horde: return "White has a pawn horde and no king. White wins by mating Black; Black wins by capturing the entire horde."
        case .crazyhouse: return "Captured pieces enter your pocket and can be dropped on later turns. Captured promoted pieces return as pawns."
        }
    }
}
public struct SavedComputerGame: Codable, Sendable {
    public var mode: GameMode
    public var human: Side
    public var targetRating: Int
    public var moves: [String]
    public var openingID: String?
    public var notation: [String] = []
    public var resigned: Side?
    public init(mode: GameMode, human: Side, targetRating: Int, moves: [String] = [], openingID: String? = nil) {
        self.mode = mode; self.human = human; self.targetRating = targetRating; self.moves = moves; self.openingID = openingID
    }
}
public struct LibraryState: Codable, Sendable {
    public var version = 1
    public var puzzle = PuzzleProgress()
    public var repertoire: [RepertoireLine] = []
    public var computer: SavedComputerGame?
    public init() {}
}
