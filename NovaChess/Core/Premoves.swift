import Foundation

public enum MovePreferences {
    public static var premoves: Bool { UserDefaults.standard.object(forKey: "premoves") as? Bool ?? true }
    public static var autoQueen: Bool { UserDefaults.standard.bool(forKey: "autoQueen") }
}

/// Intent only: the native variant rules validate every move when its turn arrives.
public struct PremoveQueue: Sendable {
    public private(set) var moves: [String] = []
    public init() {}
    public mutating func append(_ uci: String) { moves.append(uci) }
    public mutating func cancelLast() { if !moves.isEmpty { moves.removeLast() } }
    public mutating func clear() { moves = [] }
    public mutating func take(legal: [VariantMove]) -> VariantMove? {
        guard !moves.isEmpty else { return nil }
        let first = moves.removeFirst()
        guard let move = legal.first(where: { $0.uci == first }) else { clear(); return nil }
        return move
    }
    public func projected(_ original: Position, side: Side) -> Position {
        var board = original
        for uci in moves {
            let move = VariantMove(uci: uci, san: uci)
            if let drop = move.drop, let to = move.to {
                board.squares[to] = Piece(side == .white ? Character(drop.uppercased()) : Character(drop.lowercased()))
            } else { board = move.piecePosition(from: board) }
        }
        return board
    }
    public static func canPlan(from: Int, to: Int, on board: Position) -> Bool {
        guard let piece = board.squares[from], from != to else { return false }
        let row = to / 8 - from / 8, column = to % 8 - from % 8
        if board.squares[to]?.side == piece.side {
            return piece.kind == "k" && board.squares[to]?.kind == "r" && row == 0
        }
        switch piece.kind {
        case "p":
            let step = piece.side == .white ? -1 : 1
            return (row == step && abs(column) <= 1) || (row == 2 * step && column == 0)
        case "n": return abs(row) * abs(column) == 2
        case "b": return abs(row) == abs(column)
        case "r": return row == 0 || column == 0
        case "q": return row == 0 || column == 0 || abs(row) == abs(column)
        case "k": return max(abs(row), abs(column)) == 1 || (row == 0 && abs(column) == 2)
        default: return false
        }
    }
    public static func coordinateIntent(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.range(of: #"^([a-h][1-8][a-h][1-8][qrbnk]?|[PNBRQpnbrq]@[a-h][1-8])(,[a-h][1-8][a-h][1-8])?$"#, options: .regularExpression) != nil else { return nil }
        if value.contains("@") { return String(value.prefix(1)).uppercased() + value.dropFirst() }
        return value.lowercased()
    }
}

/// Shared tap behavior for every computer variant, including Duck and pocket drops.
public struct PremoveComposer {
    public var selected: Int?
    public var drop: Character?
    public var promotions: [VariantMove] = []
    public var duckPiece: String?
    public init() {}
    public mutating func tap(_ square: Int, board: Position, side: Side, duck: Bool, promotionKinds: String = "qrbn", queue: inout PremoveQueue) {
        if let piece = duckPiece {
            if board.squares[square] == nil { queue.append(piece + "," + String(piece.dropFirst(2).prefix(2)) + Position.name(square)); duckPiece = nil }
            else { duckPiece = nil; queue.cancelLast() }
            return
        }
        if let drop {
            queue.append(String(drop).uppercased() + "@" + Position.name(square)); self.drop = nil; selected = nil; return
        }
        if let from = selected, from != square {
            guard PremoveQueue.canPlan(from: from, to: square, on: board) else { selected = nil; queue.cancelLast(); return }
            let base = Position.name(from) + Position.name(square)
            selected = nil
            if board.squares[from]?.kind == "p" && (square / 8 == 0 || square / 8 == 7) {
                if MovePreferences.autoQueen { complete(base + "q", duck: duck, queue: &queue) }
                else { promotions = Array(promotionKinds).map { VariantMove(uci: base + String($0), san: "") } }
            } else { complete(base, duck: duck, queue: &queue) }
        } else if board.squares[square]?.side == side && selected != square { selected = square }
        else { selected = nil; drop = nil; queue.cancelLast() }
    }
    public mutating func complete(_ uci: String, duck: Bool, queue: inout PremoveQueue) {
        promotions = []
        if duck { duckPiece = uci } else { queue.append(uci) }
    }
}
