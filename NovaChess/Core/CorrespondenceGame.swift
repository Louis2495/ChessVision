import Foundation

/// Game Center transports this data; the receiver replays and validates every move.
public struct CorrespondenceGame: Codable, Sendable {
    public var version = 1
    public var whitePlayerID: String
    public var moves: [String] = []
    public var resigned: Side?
    public var spectatorConsents: [String]?
    public static let turnSeconds: TimeInterval = 3 * 24 * 60 * 60
    public static func archiveID(_ matchID: String) -> UUID {
        if let uuid = UUID(uuidString: matchID) { return uuid }
        var a: UInt64 = 14695981039346656037, b: UInt64 = 1099511628211
        for byte in matchID.utf8 { a = (a ^ UInt64(byte)) &* 1099511628211; b = (b ^ UInt64(byte)) &* 14695981039346656037 }
        let raw = String(format: "%016llx%016llx", a, b)
        let chars = Array(raw)
        let uuid = String(chars[0..<8]) + "-" + String(chars[8..<12]) + "-" + String(chars[12..<16]) + "-" + String(chars[16..<20]) + "-" + String(chars[20..<32])
        return UUID(uuidString: uuid)!
    }
    public init(whitePlayerID: String) { self.whitePlayerID = whitePlayerID }
    public func validated() throws -> (board: Position, notation: [String], result: String?) {
        guard version == 1, !whitePlayerID.isEmpty, moves.count <= 4000 else { throw ChessError.invalid("Unsupported correspondence game data.") }
        var board = Position.initial, notation: [String] = [], repetitions: [String: Int] = [board.openingKey: 1]
        for uci in moves {
            guard let move = board.legalMoves().first(where: { $0.uci == uci }) else { throw ChessError.invalid("An online move could not be validated.") }
            notation.append(try board.san(for: move)); board = try board.playing(move)
            repetitions[board.openingKey, default: 0] += 1
        }
        let result: String?
        if let resigned { result = resigned == .white ? "black" : "white" }
        else if board.legalMoves().isEmpty { result = board.isInCheck ? (board.turn == .white ? "black" : "white") : "draw" }
        else if board.halfmove >= 150 || repetitions[board.openingKey, default: 0] >= 5 || Self.deadMaterial(board) { result = "draw" }
        else { result = nil }
        return (board, notation, result)
    }
    public mutating func play(_ uci: String) throws {
        let state = try validated()
        guard state.result == nil, state.board.legalMoves().contains(where: { $0.uci == uci }) else { throw ChessError.invalid("That move is not legal in this game.") }
        moves.append(uci)
    }
    private static func deadMaterial(_ board: Position) -> Bool {
        let nonKings = board.squares.enumerated().compactMap { index, piece -> (Int, Piece)? in guard let piece, piece.kind != "k" else { return nil }; return (index, piece) }
        if nonKings.isEmpty { return true }
        if nonKings.count == 1 { return "bn".contains(nonKings[0].1.kind) }
        if nonKings.allSatisfy({ $0.1.kind == "b" }) { return Set(nonKings.map { ($0.0 / 8 + $0.0 % 8) % 2 }).count == 1 }
        return false
    }
}
