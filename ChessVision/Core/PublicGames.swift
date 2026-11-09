import Foundation

public enum PublicChessSite: String, CaseIterable, Identifiable, Sendable { case chesscom, lichess
    public var id: String { rawValue }
    public var title: String { self == .chesscom ? "Chess.com" : "Lichess" }
}
public enum PublicGames {
    public static func validUsername(_ input: String) -> Bool { input.range(of: #"^[A-Za-z0-9_-]{2,30}$"#, options: .regularExpression) != nil }
    public struct ChessComArchive: Decodable { public var archives: [String] }
    public struct ChessComMonth: Decodable {
        public struct Game: Decodable { public var pgn: String; public var rules: String? }
        public var games: [Game]
    }
    public struct LichessGame: Decodable {
        public struct Player: Decodable { public struct User: Decodable { public var name: String }; public var user: User? }
        public struct Players: Decodable { public var white: Player; public var black: Player }
        public var players: Players
        public var variant: String?
        public var status: String?
        public var winner: String?
        public var moves: String?
        public func openingGame(maxPlies: Int = 40) throws -> OpeningGame? {
            guard variant == nil || variant == "standard", let status, ["mate", "resign", "stalemate", "timeout", "draw", "outoftime", "cheat", "variantEnd"].contains(status), let moves else { return nil }
            let parsed = try PGNGame.parse(moves, maxPlies: maxPlies)
            return OpeningGame(white: players.white.user?.name ?? "Anonymous", black: players.black.user?.name ?? "Anonymous", result: winner == "white" ? .white : winner == "black" ? .black : .draw, moves: parsed.moves)
        }
    }
    public static func chessComGame(_ game: ChessComMonth.Game, maxPlies: Int = 40) throws -> OpeningGame? {
        guard game.rules == nil || game.rules == "chess" else { return nil }
        let parsed = try PGNGame.parse(game.pgn, maxPlies: maxPlies)
        guard parsed.tags["SetUp"] != "1", parsed.tags["FEN"] == nil else { return nil }
        return OpeningGame(white: parsed.tags["White"] ?? "Unknown", black: parsed.tags["Black"] ?? "Unknown", result: GameResult(rawValue: parsed.tags["Result"] ?? "*") ?? .unknown, moves: parsed.moves)
    }
}
