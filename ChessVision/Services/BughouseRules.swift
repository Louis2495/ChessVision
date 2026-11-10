import Foundation

@MainActor enum BughouseRules {
    static func snapshot(fen: String = "", move: String = "") throws -> VariantSnapshot {
        let response = fen.withCString { start in move.withCString { cv_bughouse_query(start, $0) } }
        guard let response else { throw ChessError.invalid("The bughouse engine could not allocate a position.") }
        defer { cv_rules_free(response) }
        return try VariantSnapshot.parse(String(cString: response))
    }
    static func play(_ uci: String, on board: Int, states: inout [VariantSnapshot]) throws {
        guard (0..<2).contains(board), states.count == 2 else { throw ChessError.invalid("Invalid bughouse board.") }
        let next = try snapshot(fen: states[board].fen, move: uci)
        var partner = states[1 - board]
        if let transfer = next.transferred { partner = try snapshot(fen: BughouseMatch.delivered(transfer, to: partner.fen)) }
        states[board] = next; states[1 - board] = partner
    }
    static func replay(_ events: [BughouseEvent]) async throws -> [[String]] {
        var states = [try snapshot(), try snapshot()]
        var frames = [[states[0].fen], [states[1].fen]]
        for event in events {
            try Task.checkCancellation()
            try play(event.uci, on: event.board, states: &states)
            frames[0].append(states[0].fen); frames[1].append(states[1].fen)
            await Task.yield()
        }
        return frames
    }
}
