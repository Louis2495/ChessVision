import Foundation

public struct ChessMove: Hashable, Sendable {
    public let from: Int
    public let to: Int
    public let promotion: Character?
    public init(from: Int, to: Int, promotion: Character? = nil) {
        self.from = from; self.to = to; self.promotion = promotion
    }
    public var uci: String { Position.name(from) + Position.name(to) + (promotion.map(String.init) ?? "") }
}

extension Position {
    public var isInCheck: Bool {
        guard let king = squares.firstIndex(where: { $0?.kind == "k" && $0?.side == turn }) else { return false }
        return attacked(king, by: turn.opposite)
    }

    /// Legal moves are shared by SAN disambiguation, checkmate detection and board interaction.
    /// In particular, pinned pieces must not introduce spurious SAN disambiguation.
    public func legalMoves() -> [ChessMove] {
        guard squares.count == 64 else { return [] }
        var candidates: [ChessMove] = []
        func add(_ from: Int, _ to: Int) {
            guard squares[to]?.side != turn, squares[to]?.kind != "k" else { return }
            if squares[from]?.kind == "p", to / 8 == 0 || to / 8 == 7 {
                for promotion: Character in ["q", "r", "b", "n"] { candidates.append(ChessMove(from: from, to: to, promotion: promotion)) }
            } else { candidates.append(ChessMove(from: from, to: to)) }
        }
        for from in 0..<64 {
            guard let piece = squares[from], piece.side == turn else { continue }
            let row = from / 8, col = from % 8
            switch piece.kind {
            case "p":
                let step = turn == .white ? -1 : 1
                let nextRow = row + step
                guard (0..<8).contains(nextRow) else { continue }
                let forward = nextRow * 8 + col
                if squares[forward] == nil {
                    add(from, forward)
                    if row == (turn == .white ? 6 : 1), squares[(row + 2 * step) * 8 + col] == nil { add(from, (row + 2 * step) * 8 + col) }
                }
                for dc in [-1, 1] where (0..<8).contains(col + dc) {
                    let to = nextRow * 8 + col + dc
                    let epPawn = to - step * 8
                    let enPassantCapture = to == Self.index(enPassant) && squares[to] == nil && squares[epPawn] == Piece(turn == .white ? "p" : "P")
                    if squares[to]?.side == turn.opposite || enPassantCapture { add(from, to) }
                }
            case "n", "k":
                let offsets = piece.kind == "n" ? [(-2,-1),(-2,1),(-1,-2),(-1,2),(1,-2),(1,2),(2,-1),(2,1)] : [(-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)]
                for (dr, dc) in offsets where (0..<8).contains(row + dr) && (0..<8).contains(col + dc) { add(from, (row + dr) * 8 + col + dc) }
                if piece.kind == "k", from == (turn == .white ? 60 : 4), !isInCheck {
                    for kingside in [true, false] {
                        let right: Character = turn == .white ? (kingside ? "K" : "Q") : (kingside ? "k" : "q")
                        let rook = from + (kingside ? 3 : -4), direction = kingside ? 1 : -1
                        let emptyOffsets = kingside ? [1, 2] : [-1, -2, -3]
                        if castling.contains(right), squares[rook] == Piece(turn == .white ? "R" : "r"), emptyOffsets.allSatisfy({ squares[from + $0] == nil }), !attacked(from + direction, by: turn.opposite), !attacked(from + 2 * direction, by: turn.opposite) { add(from, from + 2 * direction) }
                    }
                }
            default:
                var directions: [(Int, Int)] = []
                if "bq".contains(piece.kind) { directions += [(-1,-1),(-1,1),(1,-1),(1,1)] }
                if "rq".contains(piece.kind) { directions += [(-1,0),(1,0),(0,-1),(0,1)] }
                for (dr, dc) in directions {
                    var r = row + dr, c = col + dc
                    while (0..<8).contains(r) && (0..<8).contains(c) {
                        let to = r * 8 + c
                        add(from, to)
                        if squares[to] != nil { break }
                        r += dr; c += dc
                    }
                }
            }
        }
        return candidates.filter { move in
            var next = self
            guard (try? next.apply(uci: move.uci)) != nil,
                  let king = next.squares.firstIndex(where: { $0?.kind == "k" && $0?.side == turn }) else { return false }
            return !next.attacked(king, by: turn.opposite)
        }
    }

    public func playing(_ move: ChessMove) throws -> Position {
        guard legalMoves().contains(move) else { throw ChessError.invalid("That move is not legal in this position.") }
        var next = self; try next.apply(uci: move.uci); return next
    }

    public func san(for move: ChessMove) throws -> String {
        let legal = legalMoves()
        guard legal.contains(move), let piece = squares[move.from] else { throw ChessError.invalid("Cannot notate an illegal move.") }
        var text = ""
        if piece.kind == "k", abs(move.to - move.from) == 2 {
            text = move.to > move.from ? "O-O" : "O-O-O"
        } else {
            let capture = squares[move.to] != nil || (piece.kind == "p" && move.from % 8 != move.to % 8)
            if piece.kind != "p" {
                text = String(piece.kind).uppercased()
                let rivals = legal.filter { $0.from != move.from && $0.to == move.to && squares[$0.from]?.kind == piece.kind }
                if !rivals.isEmpty {
                    if rivals.allSatisfy({ $0.from % 8 != move.from % 8 }) { text += String(Self.name(move.from).prefix(1)) }
                    else if rivals.allSatisfy({ $0.from / 8 != move.from / 8 }) { text += String(Self.name(move.from).suffix(1)) }
                    else { text += Self.name(move.from) }
                }
            } else if capture { text += String(Self.name(move.from).prefix(1)) }
            if capture { text += "x" }
            text += Self.name(move.to)
            if let promotion = move.promotion { text += "=" + String(promotion).uppercased() }
        }
        var next = self; try next.apply(uci: move.uci)
        if next.isInCheck { text += next.legalMoves().isEmpty ? "#" : "+" }
        return text
    }
}

public struct NotatedMove: Equatable, Sendable, Identifiable {
    public let id: Int
    public let number: Int
    public let side: Side
    public let san: String
    public let move: ChessMove
}
public enum ChessNotation {
    public static func variation(_ moves: [String], from start: Position) throws -> [NotatedMove] {
        var board = start
        var result: [NotatedMove] = []
        for uci in moves {
            try Task.checkCancellation()
            guard let move = board.legalMoves().first(where: { $0.uci == uci }) else { throw ChessError.invalid("Stockfish returned a move that does not match this position.") }
            result.append(NotatedMove(id: result.count, number: board.fullmove, side: board.turn, san: try board.san(for: move), move: move))
            try board.apply(uci: uci)
        }
        return result
    }
}
