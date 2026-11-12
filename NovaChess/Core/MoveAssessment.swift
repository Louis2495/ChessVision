import Foundation

public enum MoveQuality: String, Codable, CaseIterable, Sendable {
    case best, excellent, good, inaccuracy, mistake, blunder, book
    public var title: String { rawValue.capitalized }
    public var symbol: String {
        switch self {
        case .best: return "star.fill"
        case .excellent: return "checkmark.seal.fill"
        case .good: return "checkmark.circle.fill"
        case .inaccuracy: return "questionmark.circle.fill"
        case .mistake: return "exclamationmark.circle.fill"
        case .blunder: return "xmark.octagon.fill"
        case .book: return "book.closed.fill"
        }
    }
}
public struct MoveAssessment: Codable, Identifiable, Sendable {
    public var ply: Int
    public var side: Side
    public var uci: String
    public var san: String
    public var quality: MoveQuality
    public var loss: Int
    public var depth: Int
    public var id: Int { ply }
    public var destination: Int? { VariantMove(uci: uci, san: san).to }
    public static func make(ply: Int, move: VariantMove, before: VariantSnapshot, after: VariantSnapshot, baseline: EngineLine, outcome: EngineLine?, inBook: Bool = false) -> MoveAssessment {
        let sign = before.board.turn == .white ? 1 : -1
        func value(_ line: EngineLine) -> Int { if let mate = line.mate { return mate >= 0 ? 10000 : -10000 }; return line.centipawns ?? 0 }
        let beforeValue = value(baseline) * sign
        let afterValue: Int
        if after.finished { afterValue = after.status == "draw" ? 0 : after.status == (before.board.turn == .white ? "white" : "black") ? 10000 : -10000 }
        else { afterValue = outcome.map { value($0) * sign } ?? beforeValue }
        let loss = max(0, beforeValue - afterValue)
        let quality: MoveQuality
        if after.finished && afterValue == 10000 { quality = .best }
        else if loss >= 250 { quality = .blunder }
        else if loss >= 100 { quality = .mistake }
        else if loss >= 50 { quality = .inaccuracy }
        else if inBook { quality = .book }
        else if baseline.moves.first == move.uci { quality = .best }
        else if loss <= 20 { quality = .excellent }
        else { quality = .good }
        return MoveAssessment(ply: ply, side: before.board.turn, uci: move.uci, san: move.san, quality: quality, loss: loss, depth: min(baseline.depth, outcome?.depth ?? baseline.depth))
    }
}
public struct ReviewSummary: Sendable {
    public var moves: [MoveAssessment]
    public init(_ moves: [MoveAssessment], side: Side) { self.moves = moves.filter { $0.side == side } }
    public func count(_ quality: MoveQuality) -> Int { moves.filter { $0.quality == quality }.count }
    /// A rough single-game move-quality estimate; not a calibrated platform Elo.
    public var estimatedRating: Int? {
        let assessed = moves.filter { $0.quality != .book }
        guard assessed.count >= 8 else { return nil }
        let loss = Double(assessed.reduce(0) { $0 + min(500, $1.loss) }) / Double(assessed.count)
        return Int(min(2800, max(400, 2800 - loss * 8)).rounded() / 50) * 50
    }
}
