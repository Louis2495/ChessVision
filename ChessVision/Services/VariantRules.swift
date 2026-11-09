import Foundation

@MainActor enum VariantRules {
    static func snapshot(variant: String, history: [String]) throws -> VariantSnapshot {
        guard history.count <= 2000 else { throw ChessError.invalid("This game has reached the supported move-history limit.") }
        let response = variant.withCString { name in history.joined(separator: " ").withCString { moves in cv_rules_query(name, moves) } }
        guard let response else { throw ChessError.invalid("The engine could not allocate a game position.") }
        defer { cv_rules_free(response) }
        return try VariantSnapshot.parse(String(cString: response))
    }
}
