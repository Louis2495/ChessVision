import Foundation

/// Local estimates using the published US Chess approximation, not official USCF ratings.
/// Each completed game is one event. Opponents are uncalibrated bots; no tournament bonus,
/// age adjustment, official historical floor or cross-rating-system conversion is inferred.
public enum RatingPolicy {
    public static let version = 1
    public static func expectedScore(rating: Double, opponent: Double) -> Double {
        1 / (1 + pow(10, (opponent - rating) / 400))
    }
    public static func effectiveGames(rating: Double, games: Int) -> Double {
        let limit = rating >= 2355 ? 50 : 50 / sqrt(0.662 + 0.00000739 * pow(2569 - rating, 2))
        return min(Double(max(0, games)), limit)
    }
    public static func standardEstimate(rating: Double, games: Int, score: Double, opponent: Int) -> Double {
        let updated: Double
        if games < 8 {
            // Published provisional approximation: prior performance plus opponent ±400 (draw: ±0).
            updated = (Double(games) * rating + Double(opponent) + 400 * (2 * score - 1)) / Double(games + 1)
        } else {
            let k = 800 / (effectiveGames(rating: rating, games: games) + 1)
            updated = rating + k * (score - expectedScore(rating: rating, opponent: Double(opponent)))
        }
        return max(100, updated)
    }
    /// Outside these UCI ranges, multiple requested ratings select the same minimum/full strength.
    public static func ratedBotRange(for mode: GameMode) -> ClosedRange<Int> {
        mode.variant == "chess" ? 500...3190 : 500...2850
    }
    public static func canRate(_ game: SavedComputerGame) -> Bool {
        game.rated == true && game.adaptive != true && game.source != "correspondence" &&
        ratedBotRange(for: game.mode).contains(game.targetRating)
    }
}

extension LibraryState {
    /// Rebuild only when the complete previously rated Standard history is available. Retain an
    /// incomplete legacy estimate as a seed, rather than fabricating missing game results.
    @discardableResult public mutating func updateStandardRatings() -> Bool {
        let key = GameMode.normal.rawValue
        guard let old = playProgress.ratings[key], old.standardFormulaVersion != RatingPolicy.version else { return false }
        let indices = history.indices.filter {
            history[$0].game.mode == .normal && history[$0].game.rated == true &&
            ["white", "black", "draw"].contains(history[$0].result)
        }.sorted {
            if history[$0].finishedAt == history[$1].finishedAt { return history[$0].id.uuidString < history[$1].id.uuidString }
            return history[$0].finishedAt < history[$1].finishedAt
        }
        guard Set(indices.map { history[$0].id }).count == indices.count, indices.count == old.games else {
            var retained = old
            retained.standardFormulaVersion = RatingPolicy.version; retained.legacySeed = true
            playProgress.ratings[key] = retained
            return true
        }
        var revised = PlayerRating()
        revised.standardFormulaVersion = RatingPolicy.version
        for index in indices {
            let entry = history[index]
            guard RatingPolicy.canRate(entry.game) else { history[index].ratingChange = nil; continue }
            let won = entry.result == (entry.game.human == .white ? "white" : "black")
            history[index].ratingChange = revised.record(score: entry.result == "draw" ? 0.5 : won ? 1 : 0,
                                                        opponent: entry.game.targetRating, standard: true)
        }
        playProgress.ratings[key] = revised
        return true
    }
}
