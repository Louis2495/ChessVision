import Foundation
import Combine

@MainActor final class GameReviewModel: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var progress = ""
    @Published private(set) var error: String?
    @Published private(set) var review: GameReview?
    @Published private(set) var positions: [String] = []
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var checkpoint: (@MainActor () -> Void)?
    func cancel() {
        checkpoint?(); checkpoint = nil
        task?.cancel(); task = nil; generation = UUID()
        if busy { progress = "Review paused. Resume when you're ready." }
        busy = false
    }
    func start(id: UUID, library: LibraryStore) {
        cancel()
        guard let entry = library.state.history.first(where: { $0.id == id }) else { return }
        let repertoire = library.state.repertoire
        let signature = GameReviewLogic.signature(repertoire)
        var result = entry.review?.repertoireSignature == signature ? entry.review! : GameReview(signature: signature)
        result.nextPly = max(0, min(entry.game.moves.count, result.nextPly))
        review = result; positions = entry.positions; error = nil
        if result.complete && entry.positions.count == entry.game.moves.count + 1 { return }
        let token = UUID(); generation = token; busy = true
        task = Task {
            guard generation == token, !Task.isCancelled else { return }
            @MainActor func save() {
                guard let index = library.state.history.firstIndex(where: { $0.id == id }) else { return }
                library.state.history[index].review = result
            }
            checkpoint = save
            do {
                let game = entry.game
                progress = "Preparing game positions…"
                try await EngineController.shared.prepareVariant(game.variant)
                try Task.checkCancellation()
                if positions.count != game.moves.count + 1 {
                    var frames: [String] = []
                    for ply in 0...game.moves.count {
                        try Task.checkCancellation()
                        let state = try VariantRules.snapshot(variant: game.variant, history: Array(game.moves.prefix(ply)))
                        frames.append(state.fen)
                        if ply.isMultiple(of: 8) { await Task.yield() }
                    }
                    try Task.checkCancellation()
                    positions = frames
                    if let index = library.state.history.firstIndex(where: { $0.id == id }) { library.state.history[index].positions = frames }
                }
                let standard = game.variant == "chess"
                let ordinaryMate = standard || game.mode == .chess960 || (game.mode == .pawnWars && game.pawnWarsKings != false)
                let worker = Task.detached(priority: .userInitiated) { try ReviewRepertoireIndex(lines: standard ? repertoire : []) }
                let book = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
                try Task.checkCancellation()
                for ply in result.nextPly..<game.moves.count {
                    try Task.checkCancellation()
                    let prefix = Array(game.moves.prefix(ply))
                    let before = try VariantRules.snapshot(variant: game.variant, history: prefix)
                    guard let played = before.moves.first(where: { $0.uci == game.moves[ply] }) else { throw ChessError.invalid("A saved move could not be replayed.") }
                    if before.board.turn == game.human {
                        progress = "Reviewing your move \(before.board.fullmove) · \(ply + 1)/\(game.moves.count) plies"
                        let match = standard ? GameReviewLogic.repertoireSuggestion(at: before.board, played: played.uci, san: played.san, ply: ply, choices: book.positions[before.board.openingKey] ?? []) : (matched: false, suggestion: nil as GameSuggestion?)
                        if match.matched {
                            result.repertoireMatches += 1
                            if let suggestion = match.suggestion { result.suggestions.append(suggestion) }
                        } else {
                            let baseline = try await EngineController.shared.reviewPosition(variant: game.variant, history: prefix, side: before.board.turn)
                            try Task.checkCancellation()
                            let afterHistory = prefix + [played.uci]
                            let after = try VariantRules.snapshot(variant: game.variant, history: afterHistory)
                            let outcome = after.finished ? nil : try await EngineController.shared.reviewPosition(variant: game.variant, history: afterHistory, side: after.board.turn)
                            try Task.checkCancellation()
                            if let suggestion = GameReviewLogic.engineSuggestion(ply: ply, side: game.human, number: before.board.fullmove, played: played, before: before, after: after, baseline: baseline, outcome: outcome, standard: ordinaryMate, variant: game.variant) { result.suggestions.append(suggestion) }
                        }
                        result.assessedMoves += 1
                    }
                    result.nextPly = ply + 1; review = result
                    if before.board.turn == game.human && result.assessedMoves.isMultiple(of: 5) { save() }
                }
                result.complete = true; result.reviewedAt = Date(); review = result
                progress = "Review complete"
            } catch is CancellationError { if generation == token { progress = "Review paused. Resume when you're ready." } }
            catch { if generation == token { self.error = error.localizedDescription } }
            if generation == token { save(); checkpoint = nil; busy = false }
        }
    }
    func position(at index: Int) -> VariantSnapshot? {
        guard positions.indices.contains(index) else { return nil }
        return try? VariantSnapshot.parse("fen\t\(positions[index])\nstatus\tongoing")
    }
}
