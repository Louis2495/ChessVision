import Foundation
import GameKit

// GameKit nullability imports differ between Apple SDK versions. Give the app
// one explicit contract; optional promotion works with either SDK declaration.
extension GKTurnBasedMatch {
    var novaMatchID: String? {
        let value: String? = matchID
        return value
    }
    var novaParticipants: [GKTurnBasedParticipant] {
        let value: [GKTurnBasedParticipant]? = participants
        return value ?? []
    }
    var novaCreationDate: Date {
        let value: Date? = creationDate
        return value ?? .distantPast
    }
}
