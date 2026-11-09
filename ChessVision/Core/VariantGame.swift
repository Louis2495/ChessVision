import Foundation

public struct VariantMove: Hashable, Identifiable, Sendable {
    public var uci: String
    public var san: String
    public var id: String { uci }
    public var drop: Character? { uci.contains("@") ? uci.first : nil }
    public var from: Int? { drop == nil ? Position.index(String(uci.prefix(2))) : nil }
    public var to: Int? { Position.index(drop == nil ? String(uci.dropFirst(2).prefix(2)) : String(uci.suffix(2))) }
    public var promotion: Character? { drop == nil && uci.count == 5 ? uci.last : nil }
}
public struct VariantSnapshot: Sendable {
    public var fen: String
    public var board: Position
    public var moves: [VariantMove]
    public var status: String
    public var inCheck: Bool
    public var pockets: [Piece]
    public var checksRemaining: String?
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
        // The board view shares standard piece art, but variant legality always comes from Fairy-Stockfish.
        var board = try Position(fen: "\(placement) \(turn.rawValue) \(parts[2]) \(parts[3]) \(parts[parts.count-2]) \(parts[parts.count-1])")
        board.turn = turn
        let checks = parts.first { $0.range(of: #"^\d+\+\d+$"#, options: .regularExpression) != nil }
        return VariantSnapshot(fen: fen, board: board, moves: moves, status: status, inCheck: fields["check"] == "1", pockets: pockets, checksRemaining: checks)
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
