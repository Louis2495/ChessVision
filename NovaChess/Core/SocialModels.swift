import Foundation

public enum Usernames {
    public static func canonical(_ text: String) throws -> String {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard (3...20).contains(value.count), value.utf8.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 95 }),
              !["admin","administrator","support","novachess"].contains(value) else {
            throw ChessError.invalid("Use 3–20 letters, numbers or underscores. This username may be reserved.")
        }
        return value
    }
    public static func prefix(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return (2...20).contains(value.count) && value.utf8.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 95 }) ? value : nil
    }
}
public struct PlayerProfile: Identifiable, Sendable {
    public var username: String
    public var ownerID: String
    public var gameCenterID: String
    public var id: String { username }
}
public struct PlayerRequest: Identifiable, Sendable {
    public var id: String
    public var sender: PlayerProfile
    public var recipient: PlayerProfile
}
public struct PublicGame: Identifiable, Sendable {
    public var id: String
    public var gameID: String
    public var publisher: String
    public var white: String
    public var black: String
    public var mode: String
    public var fen: String
    public var notation: [String]
    public var updated: Date
    public var result: String?
    public func board() throws -> VariantSnapshot {
        guard fen.utf8.count <= 4096, notation.count <= 400 else { throw ChessError.invalid("This public board is too large.") }
        return try VariantSnapshot.parse("fen\t\(fen)\nstatus\tongoing")
    }
}
