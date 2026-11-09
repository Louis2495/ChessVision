import Foundation

public enum PositionInsights {
    /// Conservative board observations, not engine-proven tactical verdicts.
    public static func observations(in board: Position) -> [String] {
        var notes: [String] = []
        for square in 0..<64 {
            guard let piece = board.squares[square], piece.kind != "k" else { continue }
            let name = "\(piece.side.title)'s \(piece.name.split(separator: " ").last ?? "piece") on \(Position.name(square))"
            if board.attacked(square, by: piece.side.opposite), !board.attacked(square, by: piece.side) {
                notes.append("\(name) is attacked and undefended. Check whether it can be captured safely.")
            }
            if piece.kind == "b" {
                let row = square / 8, col = square % 8
                let adjacent = [(-1,-1),(-1,1),(1,-1),(1,1)].compactMap { dr, dc -> Int? in
                    let r = row + dr, c = col + dc
                    return (0..<8).contains(r) && (0..<8).contains(c) ? r * 8 + c : nil
                }
                if !adjacent.isEmpty && adjacent.allSatisfy({ board.squares[$0] == Piece(piece.side == .white ? "P" : "p") }) {
                    notes.append("\(name) is boxed in by its own pawns on the same color squares.")
                }
            }
        }
        return Array(notes.prefix(4))
    }
}
