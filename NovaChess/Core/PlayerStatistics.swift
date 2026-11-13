import Foundation

public enum TimeCategory: String, CaseIterable, Sendable {
    case bullet = "Bullet", blitz = "Blitz", rapid = "Rapid", classical = "Classical", correspondence = "Correspondence", untimed = "Untimed"
    public static func classify(seconds: Int?, increment: Int = 0, correspondence: Bool = false) -> Self {
        if correspondence { return .correspondence }
        guard let seconds else { return .untimed }
        let estimate = max(0, seconds) + 40 * max(0, increment)
        return estimate < 180 ? .bullet : estimate < 600 ? .blitz : estimate < 1800 ? .rapid : .classical
    }
}
public enum Countries {
    public static let codes: [String] = Array(Set(Locale.Region.isoRegions.map(\.identifier).filter { $0.utf8.count == 2 && $0.utf8.allSatisfy { (65...90).contains($0) } } + ["XK"])).sorted()
    public static func valid(_ code: String?) -> String? { guard let code, codes.contains(code.uppercased()) else { return nil }; return code.uppercased() }
    public static func name(_ code: String) -> String { Locale.current.localizedString(forRegionCode: code) ?? code }
}
public struct GameStatistics: Sendable {
    public var total = 0, white = 0, black = 0, wins = 0, draws = 0, losses = 0
    public var categories: [TimeCategory: Int] = [:]
    public var categoryWhite: [TimeCategory: Int] = [:]
    public var categoryBlack: [TimeCategory: Int] = [:]
    public var countries: Set<String> = []
    public init(history: [CompletedGame]) {
        var seen: Set<UUID> = []
        for entry in history where seen.insert(entry.id).inserted {
            total += 1
            if entry.game.human == .white { white += 1 } else { black += 1 }
            if entry.result == "draw" { draws += 1 }
            else if entry.result == entry.game.human.title.lowercased() { wins += 1 } else { losses += 1 }
            let category = TimeCategory.classify(seconds: entry.bughouse?.config.seconds ?? entry.game.timeControlSeconds,
                increment: entry.bughouse?.config.increment ?? entry.game.timeControlIncrement ?? 0,
                correspondence: entry.game.source == "correspondence" || (entry.game.source == nil && entry.game.opponentName != nil && entry.game.developerBot != true && entry.bughouse == nil))
            categories[category, default: 0] += 1
            if entry.game.human == .white { categoryWhite[category, default: 0] += 1 } else { categoryBlack[category, default: 0] += 1 }
            if let country = Countries.valid(entry.game.opponentCountry) { countries.insert(country) }
        }
    }
    public static func moveCount(plies: Int) -> Int { (max(0, plies) + 1) / 2 }
}
