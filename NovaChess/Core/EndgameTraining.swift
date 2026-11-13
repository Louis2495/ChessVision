import Foundation

public enum EndgameGoal: String, Sendable { case mate, promote, draw
    public var title: String { switch self { case .mate: return "Checkmate"; case .promote: return "Promote a pawn"; case .draw: return "Hold the draw" } }
}
public struct EndgameExercise: Identifiable, Sendable {
    public var id: String
    public var title: String
    public var category: String
    public var fen: String
    public var side: Side = .white
    public var goal: EndgameGoal
    public var tip: String
    public func position() throws -> Position {
        let board = try Position(fen: fen)
        guard board.problems.isEmpty, board.turn == side, !board.legalMoves().isEmpty else { throw ChessError.invalid("This endgame position could not be loaded.") }
        return board
    }
    public static let all: [Self] = [
        .init(id: "queen-finish", title: "Queen: finish the net", category: "Checkmates", fen: "7k/5Q2/5K2/8/8/8/8/8 w - - 0 1", goal: .mate, tip: "Keep the queen protected and remove every escape square."),
        .init(id: "rook-finish", title: "Rook: the last rank", category: "Checkmates", fen: "6k1/R7/6K1/8/8/8/8/8 w - - 0 1", goal: .mate, tip: "Your king covers the seventh rank. Use the rook on the eighth."),
        .init(id: "queen-king", title: "Queen and king", category: "Checkmates", fen: "8/4k3/8/8/3Q4/4K3/8/8 w - - 0 1", goal: .mate, tip: "Shrink the king’s box, then bring your king closer. Watch for stalemate."),
        .init(id: "rook-king", title: "Cut off the king", category: "Checkmates", fen: "4k3/R7/8/4K3/8/8/8/8 w - - 0 1", goal: .mate, tip: "Keep the rook cutting off a rank while your king approaches."),
        .init(id: "two-bishops", title: "Two bishops", category: "Checkmates", fen: "4k3/8/8/8/8/4K3/8/2B2B2 w - - 0 1", goal: .mate, tip: "Use both diagonals to push the king toward an edge."),
        .init(id: "bishop-knight", title: "Bishop and knight", category: "Checkmates", fen: "4k3/8/8/8/8/4K3/8/1NB5 w - - 0 1", goal: .mate, tip: "Drive the king toward a corner matching your bishop’s color."),
        .init(id: "promotion", title: "The final pawn step", category: "Pawns", fen: "k7/5P2/5K2/8/8/8/8/8 w - - 0 1", goal: .promote, tip: "Promote on the eighth rank. You may choose any promotion piece."),
        .init(id: "opposition", title: "King in front", category: "Pawns", fen: "4k3/8/8/4K3/4P3/8/8/8 w - - 0 1", goal: .promote, tip: "Use your king and spare pawn tempi to make progress."),
        .init(id: "outside-passer", title: "The outside passer", category: "Pawns", fen: "8/8/P7/5k2/8/2K5/8/8 w - - 0 1", goal: .promote, tip: "Count how many king steps the opponent needs to catch your pawn."),
        .init(id: "connected-passers", title: "Connected passers", category: "Pawns", fen: "8/6k1/8/3K1PP1/8/8/8/8 w - - 0 1", goal: .promote, tip: "Keep the pawns protecting each other instead of advancing blindly."),
        .init(id: "pawn-race", title: "The pawn race", category: "Pawns", fen: "8/8/P6k/8/8/2K4p/8/8 w - - 0 1", goal: .promote, tip: "Calculate which pawn reaches its promotion square first."),
        .init(id: "lucena", title: "Build a bridge", category: "Rooks", fen: "2K5/k1P5/8/8/8/8/4R3/7r w - - 0 1", goal: .promote, tip: "Use your rook as shelter against checks before moving the king."),
        .init(id: "philidor", title: "Third-rank defense", category: "Rooks", fen: "4k3/8/7r/4K3/4P3/8/8/R7 b - - 0 1", side: .black, goal: .draw, tip: "Keep the attacking king away, then switch to checks from behind."),
        .init(id: "bishop-pawn", title: "Bishop stops the pawn", category: "Defense", fen: "7k/5p2/8/5K2/8/1B6/8/8 w - - 0 1", goal: .draw, tip: "Capture the last pawn to reach insufficient mating material."),
        .init(id: "knight-pawn", title: "Knight stops the pawn", category: "Defense", fen: "7k/8/1N6/5K2/p7/8/8/8 w - - 0 1", goal: .draw, tip: "Find the knight capture that removes the last pawn."),
        .init(id: "rook-pawn-defense", title: "Bishop and rook pawn", category: "Defense", fen: "k7/P7/8/1K6/5B2/8/8/8 b - - 0 1", side: .black, goal: .draw, tip: "Find a safe way to remove the last pawn."),
        .init(id: "queen-rook", title: "Queen against rook", category: "Checkmates", fen: "6kr/8/6K1/5Q2/8/8/8/8 w - - 0 1", goal: .mate, tip: "Coordinate king and queen; watch for forks and rook stalemate tricks.")
    ]
}
public struct EndgameSession: Sendable {
    public enum Outcome: String, Sendable { case ongoing, success, failure }
    public let exercise: EndgameExercise
    public let initial: Position
    public private(set) var board: Position
    public private(set) var moves: [String] = []
    public private(set) var outcome = Outcome.ongoing
    public private(set) var result: String?
    private var repetitions: [String: Int]
    public init(exercise: EndgameExercise) throws {
        let board = try exercise.position()
        self.exercise = exercise; self.initial = board; self.board = board
        self.repetitions = [board.openingKey: 1]
    }
    public var canClaimDraw: Bool { outcome == .ongoing && (board.halfmove >= 100 || repetitions[board.openingKey, default: 0] >= 3) }
    public mutating func claimDraw() throws {
        guard canClaimDraw else { throw ChessError.invalid("A draw cannot be claimed in this position.") }
        finish(winner: nil)
    }
    public mutating func play(_ uci: String) throws {
        guard outcome == .ongoing, let move = board.legalMoves().first(where: { $0.uci == uci }) else { throw ChessError.invalid("That move is not legal in this exercise.") }
        let moving = board.turn
        board = try board.playing(move); moves.append(uci); repetitions[board.openingKey, default: 0] += 1
        if exercise.goal == .promote && moving == exercise.side && move.promotion != nil {
            outcome = .success; result = "Promotion"; return
        }
        if board.legalMoves().isEmpty { finish(winner: board.isInCheck ? board.turn.opposite : nil) }
        else if board.halfmove >= 150 || repetitions[board.openingKey, default: 0] >= 5 || CorrespondenceGame.deadMaterial(board) { finish(winner: nil) }
    }
    private mutating func finish(winner: Side?) {
        result = winner == nil ? "Draw" : "Checkmate"
        let achieved = winner == exercise.side || (winner == nil && exercise.goal == .draw)
        outcome = achieved ? .success : .failure
    }
}
