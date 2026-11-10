import Foundation

public struct BughouseConfig: Codable, Sendable {
    public var human: Side
    public var ratings: [Int]
    public var seconds: Int
    public var increment: Int
    public init(human: Side = .white, ratings: [Int] = [1000,1000,1000,1000], seconds: Int = 300, increment: Int = 2) {
        self.human = human; self.ratings = ratings; self.seconds = seconds; self.increment = increment
    }
    public var control: ClockTimeControl { ClockTimeControl(seconds: seconds, increment: increment) }
    public var humanTeam: Int { human == .white ? 0 : 1 }
    public static func seat(_ board: Int, _ side: Side) -> Int { board * 2 + (side == .white ? 0 : 1) }
    public static func team(_ board: Int, _ side: Side) -> Int { (board == 0 ? side == .white : side == .black) ? 0 : 1 }
    public func validate() throws {
        guard ratings.count == 4, ratings.allSatisfy({ (1...10000).contains($0) }), (1...10800).contains(seconds), (0...60).contains(increment) else { throw ChessError.invalid("Enter four ratings from 1–10000 and a valid time control.") }
    }
}
public struct BughouseEvent: Codable, Sendable {
    public var board: Int
    public var side: Side
    public var number: Int
    public var uci: String
    public var san: String
}
public struct BughouseMatch: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var config: BughouseConfig
    public var events: [BughouseEvent] = []
    public var remaining: [Double]
    /// 0/1: team; 2: draw. Nil while in progress.
    public var winner: Int?
    public var reason: String?
    public init(config: BughouseConfig) {
        self.config = config; remaining = Array(repeating: Double(config.seconds), count: 4)
    }
    public var resultTitle: String {
        guard let winner else { return "Match in progress" }
        return winner == 2 ? "Draw" : winner == config.humanTeam ? "Your team wins" : "Other team wins"
    }
    public static func delivered(_ symbol: Character, to fen: String) throws -> String {
        guard "PNBRQpnbrq".contains(symbol) else { throw ChessError.invalid("Invalid pocket delivery.") }
        var fields = fen.split(separator: " ").map(String.init)
        guard fields.count == 6 else { throw ChessError.invalid("Invalid bughouse position.") }
        if let close = fields[0].firstIndex(of: "]") { fields[0].insert(symbol, at: close) }
        else { fields[0] += "[\(symbol)]" }
        return fields.joined(separator: " ")
    }
}
