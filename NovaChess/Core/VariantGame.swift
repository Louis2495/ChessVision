import Foundation

public struct VariantMove: Hashable, Identifiable, Sendable {
    public var uci: String
    public var san: String
    public var id: String { uci }
    public var drop: Character? { uci.contains("@") ? uci.first : nil }
    public var from: Int? { drop == nil ? Position.index(String(uci.prefix(2))) : nil }
    public var to: Int? { Position.index(drop == nil ? String(uci.dropFirst(2).prefix(2)) : String(uci.suffix(2))) }
    public var pieceMove: String { String(uci.split(separator: ",").first ?? "") }
    public var duckDestination: Int? { uci.contains(",") ? Position.index(String(uci.suffix(2))) : nil }
    public var promotion: Character? { drop == nil && pieceMove.count == 5 ? pieceMove.last : nil }
    /// Visual first half of a legal Duck move. The complete turn is still committed by the rules engine.
    public func piecePosition(from original: Position) -> Position {
        guard let from, let to, let piece = original.squares[from] else { return original }
        var board = original
        // Chess960 UCI encodes castling as king-to-own-rook, including stationary kings.
        if piece.kind == "k", let rook = board.squares[to], rook.kind == "r", rook.side == piece.side, from / 8 == to / 8 {
            let base = from / 8 * 8
            let kingTo = base + (to > from ? 6 : 2), rookTo = base + (to > from ? 5 : 3)
            board.squares[from] = nil; board.squares[to] = nil
            board.squares[kingTo] = piece; board.squares[rookTo] = rook
            return board
        }
        if piece.kind == "p", from % 8 != to % 8, board.squares[to] == nil, original.enPassant == Position.name(to) {
            let captured = to + (piece.side == .white ? 8 : -8)
            if board.squares.indices.contains(captured) { board.squares[captured] = nil }
        }
        if piece.kind == "k", abs(to - from) == 2, from / 8 == to / 8 {
            let rookFrom = to > from ? from + 3 : from - 4
            let rookTo = to > from ? from + 1 : from - 1
            if board.squares.indices.contains(rookFrom), board.squares[rookFrom]?.kind == "r" {
                board.squares[rookTo] = board.squares[rookFrom]; board.squares[rookFrom] = nil
            }
        }
        board.squares[to] = piece; board.squares[from] = nil
        if let promotion { board.squares[to] = Piece(piece.side == .white ? Character(promotion.uppercased()) : promotion) }
        return board
    }

}
public struct VariantSnapshot: Sendable {
    public var fen: String
    public var board: Position
    public var moves: [VariantMove]
    public var status: String
    public var inCheck: Bool
    public var pockets: [Piece]
    public var checksRemaining: String?
    public var duckSquare: Int?
    public var hidden: Set<Int> = []
    public var transferred: Character?
    public var finished: Bool { status != "ongoing" }
    public var result: String? {
        switch status { case "white": return "White wins"; case "black": return "Black wins"; case "draw": return "Draw"; default: return nil }
    }
    public static func parse(_ text: String) throws -> VariantSnapshot {
        var fields: [String: String] = [:], moves: [VariantMove] = []
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 2 else { continue }
            if parts[0] == "error" { throw ChessError.invalid(parts[1]) }
            if parts[0] == "move", parts.count == 3 { moves.append(VariantMove(uci: parts[1], san: parts[2])) }
            else { fields[parts[0]] = parts[1] }
        }
        guard let fen = fields["fen"], let status = fields["status"], ["ongoing", "white", "black", "draw"].contains(status) else { throw ChessError.invalid("The variant engine returned an invalid position.") }
        let parts = fen.split(separator: " ").map(String.init)
        guard parts.count >= 6, let turn = Side(rawValue: parts[1]) else { throw ChessError.invalid("Invalid variant FEN.") }
        var placement = parts[0], pockets: [Piece] = []
        if let open = placement.firstIndex(of: "["), let close = placement.firstIndex(of: "]") {
            pockets = placement[placement.index(after: open)..<close].filter { "KQRBNPkqrbnp".contains($0) }.map(Piece.init)
            placement = String(placement[..<open])
        }
        placement = placement.replacingOccurrences(of: "~", with: "")
        var cursor = 0, duckSquare: Int?
        for ch in placement {
            if ch == "/" { continue }
            if let count = ch.wholeNumberValue { cursor += count }
            else { if ch == "*" { duckSquare = cursor }; cursor += 1 }
        }
        placement = placement.replacingOccurrences(of: "*", with: "1")
        // The board view shares standard piece art, but variant legality always comes from Fairy-Stockfish.
        var board = try Position(fen: "\(placement) \(turn.rawValue) \(parts[2].allSatisfy { "KQkq-".contains($0) } ? parts[2] : "-") \(parts[3]) \(parts[parts.count-2]) \(parts[parts.count-1])")
        board.turn = turn
        let checks = parts.first { $0.range(of: #"^\d+\+\d+$"#, options: .regularExpression) != nil }
        var snapshot = VariantSnapshot(fen: fen, board: board, moves: moves, status: status, inCheck: fields["check"] == "1", pockets: pockets, checksRemaining: checks, duckSquare: duckSquare, hidden: Set((fields["hidden"] ?? "").split(separator: ",").compactMap { Position.index(String($0)) }))
        snapshot.transferred = fields["transfer"]?.first
        return snapshot
    }
    public func move(named text: String) throws -> VariantMove {
        func normalize(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "0", with: "O").replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "#", with: "").lowercased()
        }
        let key = normalize(text)
        let found = moves.filter { normalize($0.san) == key || $0.uci.lowercased() == key }
        guard found.count == 1, let move = found.first else { throw ChessError.invalid("That move is illegal or ambiguous. Use notation such as Nf3, exd5 or O-O.") }
        return move
    }
}

public enum FogVisibility {
    /// Visibility belongs to the human, including while the computer is thinking.
    public static func hidden(in board: Position, for side: Side) -> Set<Int> {
        var visible: Set<Int> = []
        func reveal(_ row: Int, _ col: Int) -> Bool {
            guard (0..<8).contains(row), (0..<8).contains(col) else { return false }
            let square = row * 8 + col; visible.insert(square)
            return board.squares[square] == nil
        }
        for index in 0..<64 {
            guard let piece = board.squares[index], piece.side == side else { continue }
            visible.insert(index)
            let row = index / 8, col = index % 8
            switch piece.kind {
            case "p":
                let step = side == .white ? -1 : 1
                if (0..<8).contains(row + step) {
                    if board.squares[(row + step) * 8 + col] == nil {
                        _ = reveal(row + step, col)
                        if row == (side == .white ? 6 : 1), board.squares[(row + 2 * step) * 8 + col] == nil { _ = reveal(row + 2 * step, col) }
                    }
                    for delta in [-1, 1] where (0..<8).contains(col + delta) {
                        let target = (row + step) * 8 + col + delta
                        if board.squares[target]?.side == side.opposite || Position.name(target) == board.enPassant { visible.insert(target) }
                    }
                }
            case "n":
                for (dr, dc) in [(-2,-1),(-2,1),(-1,-2),(-1,2),(1,-2),(1,2),(2,-1),(2,1)] { _ = reveal(row + dr, col + dc) }
            default:
                let diagonals = [(-1,-1),(-1,1),(1,-1),(1,1)]
                let straight = [(-1,0),(1,0),(0,-1),(0,1)]
                let directions = piece.kind == "b" ? diagonals : piece.kind == "r" ? straight : diagonals + straight
                for (dr, dc) in directions {
                    for distance in 1...(piece.kind == "k" ? 1 : 7) { if !reveal(row + dr * distance, col + dc * distance) { break } }
                }
            }
        }
        return Set(0..<64).subtracting(visible)
    }
}
