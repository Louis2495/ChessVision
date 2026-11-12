import Foundation

public struct ChessPuzzle: Codable, Identifiable, Sendable {
    public var id: String
    public var fen: String
    /// Lichess format: first ply is the opponent's setup move, followed by the solution.
    public var moves: [String]
    public var sourceRating: Int
    public var difficultyRating: Int { sourceRating }
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
    public var placementAttempts = 0
    public var scaleVersion = 1
    public init() {}
    private enum CodingKeys: CodingKey { case rating, attempts, solved, completed, placementAttempts, scaleVersion }
    public init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        rating = try fields.decode(Double.self, forKey: .rating)
        attempts = try fields.decode(Int.self, forKey: .attempts)
        solved = try fields.decode(Int.self, forKey: .solved)
        completed = try fields.decode([String].self, forKey: .completed)
        placementAttempts = try fields.decodeIfPresent(Int.self, forKey: .placementAttempts) ?? 0
        if try fields.decodeIfPresent(Int.self, forKey: .scaleVersion) != 1 {
            // Undo the former 0.8 multiplier; retain solved history and re-place quickly.
            rating = max(200, min(3500, rating / 0.8)); placementAttempts = 0
        }
    }
    public mutating func record(_ puzzle: ChessPuzzle, correct: Bool) {
        let expected = 1 / (1 + pow(10, Double(puzzle.difficultyRating - Int(rating)) / 400))
        rating = max(200, min(3500, rating + (placementAttempts < 10 ? 400.0 : placementAttempts < 25 ? 120.0 : 40.0) * ((correct ? 1 : 0) - expected)))
        placementAttempts += 1
        attempts += 1; if correct { solved += 1 }
        if !completed.contains(puzzle.id) { completed.append(puzzle.id) }
    }
    public func next(in puzzles: [ChessPuzzle], excluding current: String? = nil) -> ChessPuzzle? {
        let fresh = puzzles.filter { !completed.contains($0.id) && $0.id != current }
        let candidates = fresh.isEmpty ? puzzles.filter { $0.id != current } : fresh
        // Small deterministic diversity prevents returning the same tied puzzle every session.
        return candidates.min { a, b in
            let da = abs(Double(a.difficultyRating) - rating), db = abs(Double(b.difficultyRating) - rating)
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
    case normal, crazyhouse, fogOfWar, chess960, threeCheck, kingOfTheHill, atomic, duck, horde, pawnWars, antichess, bughouse, blindBoard, blindText
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .chess960: return "Chess960"
        case .bughouse: return "Bughouse"
        case .normal: return "Standard"
        case .blindBoard: return "Blindfold · empty board"
        case .blindText: return "Blindfold · text only"
        case .threeCheck: return "3-Check"
        case .kingOfTheHill: return "King of the Hill"
        case .horde: return "Horde"
        case .crazyhouse: return "Crazyhouse"
        case .duck: return "Duck chess"
        case .atomic: return "Atomic chess"
        case .fogOfWar: return "Fog of War"
        case .pawnWars: return "Pawn Wars"
        case .antichess: return "Antichess"
        }
    }
    public var variant: String {
        switch self { case .chess960: return "cv9600"; case .threeCheck: return "3check"; case .kingOfTheHill: return "kingofthehill"; case .horde: return "horde"; case .crazyhouse: return "crazyhouse"; case .bughouse: return "bughouse"; case .duck: return "duck"; case .atomic: return "atomic"; case .fogOfWar: return "cvfog"; case .pawnWars: return "cvpawns"; case .antichess: return "antichess"; default: return "chess" }
    }
    public var explanation: String {
        switch self {
        case .bughouse: return "Two boards, four players. Captures go to your teammate on the other board. Play in landscape."
        case .chess960: return "A randomized back rank, with bishops on opposite colors and the king between the rooks. To castle, move your king onto its rook."
        case .duck: return "Move a piece, then place the duck on an empty square. The duck blocks movement. Capture the king to win."
        case .atomic: return "Captures explode the capturing piece and adjacent non-pawns. Explode the enemy king to win."
        case .fogOfWar: return "Only your pieces and squares they can move to are visible. Capture the enemy king to win."
        case .pawnWars: return "With kings: pawn-and-king chess, with promotions and checkmate. Without kings: race a pawn to the last rank or capture every enemy pawn."
        case .antichess: return "Captures are mandatory. Lose all your pieces, or have no legal move, to win."
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
    public var id: UUID? = UUID()
    public var mode: GameMode
    public var human: Side
    public var targetRating: Int
    public var moves: [String]
    public var openingID: String?
    public var notation: [String] = []
    public var resigned: Side?
    public var agreedDraw: Bool?
    public var chess960Index: Int?
    public var pawnWarsKings: Bool?
    public var reviewEvaluationVersion: String?
    public var prefetchedEvaluations: [Int: EngineLine]?
    public var developerBot: Bool?
    public var opponentCountry: String?
    public var opponentGameCenterID: String?
    public var source: String?
    public var timeControlSeconds: Int?
    public var timeControlIncrement: Int?
    public var opponentName: String?
    public var rated: Bool?
    public var adaptive: Bool?
    public var adaptiveRating: Int?
    public var lastAdaptedPly: Int?
    public var variant: String { if mode == .chess960 { return "cv960\(chess960Index ?? 0)" }; return mode == .pawnWars && pawnWarsKings == false ? "cvpawnrace" : mode.variant }
    public init(mode: GameMode, human: Side, targetRating: Int, moves: [String] = [], openingID: String? = nil) {
        self.mode = mode; self.human = human; self.targetRating = targetRating; self.moves = moves; self.openingID = openingID
    }
}
public struct LibraryState: Codable, Sendable {
    public var savedGames: [SavedBoardGame] = []
    public var folders: [GameFolder] = []
    public var visitedCountries: Set<String> = []
    public var learnedOpenings: Set<String> = []
    public var version = 1
    public var puzzle = PuzzleProgress()
    public var repertoire: [RepertoireLine] = []
    public var computer: SavedComputerGame?
    public var history: [CompletedGame] = []
    public var playProgress = PlayProgress()
    public var bughouse: BughouseMatch?
    public init() {}
    private enum CodingKeys: String, CodingKey { case learnedOpenings, visitedCountries, savedGames, folders, version, puzzle, repertoire, computer, history, bughouse, playProgress }
    public init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        learnedOpenings = try fields.decodeIfPresent(Set<String>.self, forKey: .learnedOpenings) ?? []
        visitedCountries = try fields.decodeIfPresent(Set<String>.self, forKey: .visitedCountries) ?? []
        savedGames = try fields.decodeIfPresent([SavedBoardGame].self, forKey: .savedGames) ?? []
        folders = try fields.decodeIfPresent([GameFolder].self, forKey: .folders) ?? []
        version = try fields.decode(Int.self, forKey: .version)
        puzzle = try fields.decode(PuzzleProgress.self, forKey: .puzzle)
        repertoire = try fields.decode([RepertoireLine].self, forKey: .repertoire)
        computer = try fields.decodeIfPresent(SavedComputerGame.self, forKey: .computer)
        bughouse = try fields.decodeIfPresent(BughouseMatch.self, forKey: .bughouse)
        playProgress = try fields.decodeIfPresent(PlayProgress.self, forKey: .playProgress) ?? PlayProgress()
        history = try fields.decodeIfPresent([CompletedGame].self, forKey: .history) ?? []
    }
}
