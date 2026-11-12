import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif
@main struct ReviewCacheChecks {
    @MainActor static func main() async {
        do {
            guard CommandLine.arguments.count >= 4 else { throw ChessError.invalid("Expected root, phase and cache directory") }
            let phase = CommandLine.arguments[2], directory = URL(fileURLWithPath: CommandLine.arguments[3])
            let library = LibraryStore(directory: directory, puzzles: [], openings: [])
            if phase == "prefetch" {
                let model = ComputerGameModel(); model.activate(library)
                guard model.start() else { throw ChessError.invalid("Idle prefetch setup failed") }
                try await wait { !model.busy && model.game?.prefetchedEvaluations?[0] != nil }
                guard model.game?.moves.isEmpty == true && model.snapshot?.board.turn == .white else { throw ChessError.invalid("Idle review altered gameplay") }
                model.play(try model.snapshot!.move(named: "e2e4"))
                try await wait { !model.busy && model.game?.moves.count == 2 && model.game?.prefetchedEvaluations?[2] != nil }
                model.pause()
                var trial = model.game!; trial.id = UUID(); trial.resigned = .white
                library.recordCompleted(trial, result: "black")
                let beforeSearches = EngineController.shared.reviewSearchCount
                let firstReview = GameReviewModel(); firstReview.start(id: trial.id!, library: library)
                try await wait { !firstReview.busy }
                guard firstReview.error == nil, firstReview.review?.complete == true,
                      EngineController.shared.reviewSearchCount - beforeSearches == 1 else { throw ChessError.invalid("First review did not reuse both prefetched positions") }
                model.activate(library); try await wait { !model.busy }
                model.undo(); try await wait { !model.busy }
                guard model.game?.prefetchedEvaluations?.keys.allSatisfy({ $0 <= 0 }) == true else { throw ChessError.invalid("Takeback retained future-branch evaluations") }
                model.resign()
                guard library.state.history.first?.engineEvaluations?[0] != nil else { throw ChessError.invalid("Game end dropped prefetched work") }
                guard let score = library.state.history[0].engineEvaluations?[0] else { throw ChessError.invalid("Missing archived prefetch") }
                library.state.history = (0..<66).map { _ in
                    var entry = CompletedGame(game: SavedComputerGame(mode: .normal, human: .white, targetRating: 1000), result: "draw")
                    entry.engineEvaluations = [0: score]; entry.evaluationSignature = GameReviewLogic.evaluationSignature(for: entry)
                    var completed = GameReview(signature: "fixture"); completed.complete = true; entry.review = completed
                    return entry
                }
                let stored = LibraryStore(directory: directory, puzzles: [], openings: [])
                guard stored.state.history.count == 66, stored.state.history.filter({ $0.review?.complete == true }).count == 66,
                      stored.state.history.filter({ $0.engineEvaluations != nil }).count == 64 else { throw ChessError.invalid("Cache retention removed reviews or exceeded its bound") }
                model.pause(); EngineController.shared.stop()
                print("PASS: idle prefetch preserves play, yields to moves, prunes takebacks and transfers into review.")
                fflush(stdout); _exit(0)
            }
            if phase == "cold" {
                var game = SavedComputerGame(mode: .normal, human: .white, targetRating: 1000, moves: ["e2e4","e7e5","g1f3","b8c6"])
                game.notation = ["e4","e5","Nf3","Nc6"]; game.resigned = .white
                library.recordCompleted(game, result: "black")
            }
            guard let id = library.state.history.first?.id else { throw ChessError.invalid("Missing cache fixture") }
            let expected = library.state.history.first?.review?.assessments
            if phase == "warm" { library.state.history[0].review = nil }
            let started = ProcessInfo.processInfo.systemUptime
            let review = GameReviewModel(); review.start(id: id, library: library)
            try await wait { !review.busy }
            let elapsed = ProcessInfo.processInfo.systemUptime - started
            guard review.error == nil, review.review?.complete == true, let cache = library.state.history[0].engineEvaluations, cache.count == 5 else { throw ChessError.invalid("Review cache failed: \(review.error ?? "missing checkpoints")") }
            if phase == "warm" {
                guard EngineController.shared.reviewSearchCount == 0 else { throw ChessError.invalid("Warm review launched fresh engine searches") }
                let actual = review.review?.assessments
                guard actual?.map(\.quality) == expected?.map(\.quality), actual?.map(\.loss) == expected?.map(\.loss), actual?.map(\.depth) == expected?.map(\.depth) else { throw ChessError.invalid("Checkpoint reuse changed move grades") }
            } else { guard EngineController.shared.reviewSearchCount > 0 else { throw ChessError.invalid("Cold fixture did not search") } }
            print("PASS: \(phase) review \(String(format: "%.3f", elapsed))s; \(EngineController.shared.reviewSearchCount) engine searches; identical grades on fresh-process rebuild.")
            EngineController.shared.stop(); fflush(stdout); _exit(0)
        } catch { print("FAIL: \(error)"); fflush(stdout); _exit(1) }
    }
    @MainActor static func wait(_ done: () -> Bool) async throws {
        for _ in 0..<1200 { if done() { return }; try await Task.sleep(for: .milliseconds(50)) }
        throw ChessError.invalid("Review cache workflow timed out")
    }
}
