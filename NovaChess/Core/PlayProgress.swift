import Foundation

public struct PlayerRating: Codable, Sendable {
    public var value = 1000.0
    public var games = 0
    public init() {}
    @discardableResult public mutating func record(score: Double, opponent: Int) -> Int {
        let old = Int(value.rounded())
        let expected = 1 / (1 + pow(10, (Double(opponent) - value) / 400))
        value = min(4000, max(100, value + (games < 10 ? 64 : 32) * (score - expected)))
        games += 1
        return Int(value.rounded()) - old
    }
}
public enum Achievement: String, Codable, CaseIterable, Sendable {
    case firstGame, firstWin, tenGames, fiftyGames, pawnMate, knightMate, promotion, castling, explorer
    public var title: String {
        switch self {
        case .firstGame: return "First game"
        case .firstWin: return "First victory"
        case .tenGames: return "Getting into rhythm"
        case .fiftyGames: return "Regular player"
        case .pawnMate: return "Small but mighty"
        case .knightMate: return "Knight finish"
        case .promotion: return "A new beginning"
        case .castling: return "King tucked away"
        case .explorer: return "Variant explorer"
        }
    }
    public var detail: String {
        switch self {
        case .firstGame: return "Finish your first game."
        case .firstWin: return "Win a game against the computer."
        case .tenGames: return "Finish 10 games."
        case .fiftyGames: return "Finish 50 games."
        case .pawnMate: return "Deliver checkmate with a pawn, without promoting."
        case .knightMate: return "Deliver checkmate with a knight."
        case .promotion: return "Promote one of your pawns."
        case .castling: return "Castle in a game."
        case .explorer: return "Complete games in three different variants."
        }
    }
}
public struct PlayProgress: Codable, Sendable {
    public var ratings: [String: PlayerRating] = [:]
    public var settled: Set<UUID> = []
    public var completed = 0
    public var wins = 0
    public var variants: Set<String> = []
    public var achievements: [String: Date] = [:]
    public init() {}
    public static func matingAchievement(before: Position, uci: String) -> Achievement? {
        guard let move = before.legalMoves().first(where: { $0.uci == uci }), let after = try? before.playing(move), after.isInCheck, after.legalMoves().isEmpty else { return nil }
        if before.squares[move.from]?.kind == "p" && move.promotion == nil { return .pawnMate }
        if before.squares[move.from]?.kind == "n" { return .knightMate }
        return nil
    }
    public func rating(for mode: GameMode) -> PlayerRating { ratings[mode.rawValue] ?? PlayerRating() }
    @discardableResult public mutating func finish(_ game: SavedComputerGame, result: String, now: Date = Date()) -> Int? {
        guard let id = game.id, ["white","black","draw"].contains(result), settled.insert(id).inserted else { return nil }
        completed += 1; variants.insert(game.mode.rawValue)
        let win = result == (game.human == .white ? "white" : "black")
        if win { wins += 1 }
        func unlock(_ achievement: Achievement) { if achievements[achievement.rawValue] == nil { achievements[achievement.rawValue] = now } }
        unlock(.firstGame)
        if win { unlock(.firstWin) }
        if completed >= 10 { unlock(.tenGames) }
        if completed >= 50 { unlock(.fiftyGames) }
        if variants.count >= 3 { unlock(.explorer) }
        for (ply, text) in game.moves.enumerated() where game.mode != .bughouse && (ply.isMultiple(of: 2) ? Side.white : .black) == game.human {
            let move = VariantMove(uci: text, san: "")
            if move.promotion != nil { unlock(.promotion) }
            if game.notation.indices.contains(ply), game.notation[ply].hasPrefix("O-O") { unlock(.castling) }
        }
        if win && game.variant == "chess", let last = game.moves.last {
            var board = Position.initial
            for move in game.moves.dropLast() { if (try? board.apply(uci: move)) == nil { break } }
            if board.turn == game.human, let achievement = Self.matingAchievement(before: board, uci: last) { unlock(achievement) }
        }
        guard game.rated == true else { return nil }
        var rating = self.rating(for: game.mode)
        let change = rating.record(score: result == "draw" ? 0.5 : win ? 1 : 0, opponent: game.targetRating)
        ratings[game.mode.rawValue] = rating
        return change
    }
}
public enum AdaptiveStrength {
    public static func adjusted(_ rating: Int, loss: Int) -> Int {
        let delta = loss >= 250 ? -120 : loss >= 100 ? -60 : loss <= 25 ? 75 : 0
        return min(3500, max(100, rating + delta))
    }
}
