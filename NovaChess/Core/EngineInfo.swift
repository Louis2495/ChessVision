import Foundation
public struct EngineLine: Equatable, Hashable, Sendable {
    public var depth: Int
    public var rank: Int
    public var centipawns: Int?
    public var mate: Int?
    public var moves: [String]
    public var evaluation: String {
        if let mate { return "M\(mate)" }
        return String(format: "%+.2f", Double(centipawns ?? 0)/100)
    }
    public static func parse(_ line: String, turn: Side) -> EngineLine? {
        let t = line.split(separator: " ").map(String.init)
        guard t.first == "info", let pv = t.firstIndex(of: "pv"), pv+1 < t.count, let score = t.firstIndex(of: "score"), score+2 < t.count, let value = Int(t[score+2]), !t.contains("lowerbound"), !t.contains("upperbound") else { return nil }
        func number(_ key: String) -> Int? { guard let i = t.firstIndex(of:key), i+1 < t.count else { return nil }; return Int(t[i+1]) }
        let sign = turn == .white ? 1 : -1
        return EngineLine(depth: number("depth") ?? 0, rank: number("multipv") ?? 1, centipawns: t[score+1] == "cp" ? value*sign : nil, mate: t[score+1] == "mate" ? value*sign : nil, moves: Array(t[(pv+1)...]))
    }
}

public enum EvaluationScale {
    /// Display balance, not a calibrated win probability. White grows upwards from the bottom.
    public static func whiteFraction(centipawns: Int?, mate: Int? = nil) -> Double {
        if let mate, mate != 0 { return mate > 0 ? 1 : 0 }
        let pawns = Double(max(-2000, min(2000, centipawns ?? 0))) / 100
        return 1 / (1 + exp(-pawns / 2))
    }
}
