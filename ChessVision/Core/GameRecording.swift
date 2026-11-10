import Foundation

public struct GameRecording: Sendable {
    public var moves: [NotatedMove] = []
    public var startIndex = 0
    public init() {}
    /// Reconstruct only real legal moves. A manual position/turn edit begins a new recording segment.
    public static func build(from positions: [Position]) throws -> GameRecording {
        var result = GameRecording()
        guard positions.count > 1 else { return result }
        for index in 1..<positions.count {
            try Task.checkCancellation()
            let before = positions[index - 1], after = positions[index]
            guard let move = before.legalMoves().first(where: { (try? before.playing($0)) == after }) else {
                result.moves = []; result.startIndex = index; continue
            }
            result.moves.append(NotatedMove(id: result.moves.count, number: before.fullmove, side: before.turn, san: try before.san(for: move), move: move))
        }
        return result
    }
}
