import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif
@main struct BughouseWaitingChecks {
    @MainActor static func main() async {
        do {
            try await EngineController.shared.prepareVariant("bughouse")
            let diagonal = try BughouseRules.snapshot(fen: "1r4kb/8/8/8/8/8/P7/K7[] w - - 0 1")
            guard diagonal.inCheck, diagonal.moves.isEmpty, !diagonal.finished else { throw ChessError.invalid("Blockable bishop check was ended") }
            let black = try BughouseRules.snapshot(fen: "k6R/pp6/8/8/8/8/8/6K1[] b - - 0 1")
            guard black.inCheck, black.moves.isEmpty, !black.finished else { throw ChessError.invalid("Black could not wait for a block") }
            let blackSupplied = try BughouseRules.snapshot(fen: BughouseMatch.delivered("n", to: black.fen))
            guard blackSupplied.moves.contains(where: { $0.uci == "N@b8" || $0.uci == "n@b8" }) else { throw ChessError.invalid("Black delivery had the wrong color") }
            let waiting = try BughouseRules.snapshot(fen: "6k1/8/8/8/8/8/PP6/K6r[] w - - 0 1")
            let partner = try BughouseRules.snapshot(fen: "r3k3/N7/8/8/8/8/8/7K[] b - - 0 1")
            var linked = [waiting, partner]
            try BughouseRules.play("a8a7", on: 1, states: &linked)
            guard linked[0].pockets.contains(Piece("N")), linked[0].moves.contains(where: { $0.uci == "N@b1" }), !linked[0].finished else { throw ChessError.invalid("Actual partner capture did not unblock the waiting board") }
            try BughouseRules.play("N@b1", on: 0, states: &linked)
            guard !linked[0].inCheck, !linked[0].finished else { throw ChessError.invalid("Waiting board could not play after delivery") }
            // Reproduce a real game: Fool's Mate is blockable, then a partner capture supplies a knight.
            var match = BughouseMatch(config: BughouseConfig())
            var boards = [try BughouseRules.snapshot(), try BughouseRules.snapshot()]
            let sequence: [(Int, String)] = [(0,"f2f3"),(0,"e7e5"),(0,"g2g4"),(0,"d8h4"),
                (1,"e2e4"),(1,"b8c6"),(1,"b1c3"),(1,"c6d4"),(1,"c3b5"),(1,"d4b5"),(0,"N@f2")]
            for (index, uci) in sequence {
                let before = boards[index], move = try before.move(named: uci)
                try BughouseRules.play(uci, on: index, states: &boards)
                match.events.append(BughouseEvent(board: index, side: before.board.turn, number: before.board.fullmove, uci: uci, san: move.san))
                if match.events.count == 4 && move.san.hasSuffix("#") { throw ChessError.invalid("Blockable check was written as checkmate") }
                if match.events.count == 4 && (boards[0].finished || !boards[0].moves.isEmpty) { throw ChessError.invalid("Fool's Mate did not wait for partner material") }
            }
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let library = LibraryStore(directory: directory, puzzles: [], openings: [])
            match.winner = 1; match.reason = "Resigned"
            library.recordBughouse(match)
            let review = GameReviewModel(); review.start(id: match.id, library: library)
            for _ in 0..<600 { if !review.busy { break }; try await Task.sleep(for: .milliseconds(50)) }
            guard review.error == nil, review.review?.complete == true, review.review?.ungradedBughouseMoves == [3] else { throw ChessError.invalid("Review failed on a waiting check: \(review.error ?? "no error")") }
            try? FileManager.default.removeItem(at: directory)
            EngineController.shared.stop()
            print("PASS: bishop/rook checks wait for either color; actual partner capture and interposition resume the board.")
            fflush(stdout); _exit(0)
        } catch { print("FAIL: \(error)"); fflush(stdout); _exit(1) }
    }
}
