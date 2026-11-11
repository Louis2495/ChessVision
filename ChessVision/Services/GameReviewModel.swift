import Foundation
import Combine

@MainActor final class GameReviewModel: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var progress = ""
    @Published private(set) var error: String?
    @Published private(set) var review: GameReview?
    @Published private(set) var positions: [String] = []
    @Published private(set) var partnerPositions: [String] = []
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
        if let match = entry.bughouse, match.events.count != entry.game.moves.count { error = "The saved Bughouse events could not be read."; return }
        let repertoire = library.state.repertoire
        let signature = GameReviewLogic.signature(repertoire)
        var result = entry.review?.repertoireSignature == signature ? entry.review! : GameReview(signature: signature)
        result.nextPly = max(0, min(entry.game.moves.count, result.nextPly))
        review = result; positions = entry.positions; partnerPositions = entry.partnerPositions ?? []; error = nil
        if result.complete && entry.positions.count == entry.game.moves.count + 1 && (entry.bughouse == nil || partnerPositions.count == entry.positions.count) { return }
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
                if let bughouse = entry.bughouse, positions.count != game.moves.count + 1 || partnerPositions.count != game.moves.count + 1 {
                    let frames = try await BughouseRules.replay(bughouse.events)
                    try Task.checkCancellation()
                    positions = frames[0]; partnerPositions = frames[1]
                    if let index = library.state.history.firstIndex(where: { $0.id == id }) {
                        library.state.history[index].positions = frames[0]; library.state.history[index].partnerPositions = frames[1]
                    }
                } else if entry.bughouse == nil && positions.count != game.moves.count + 1 {
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
                var evaluationCache: [Int: EngineLine] = [:]
                for ply in result.nextPly..<game.moves.count {
                    try Task.checkCancellation()
                    let prefix = Array(game.moves.prefix(ply))
                    if let bughouse = entry.bughouse, bughouse.events[ply].board != 0 {
                        result.nextPly = ply + 1; continue
                    }
                    let before = try entry.bughouse == nil ? VariantRules.snapshot(variant: game.variant, history: prefix) : BughouseRules.snapshot(fen: positions[ply])
                    guard let played = before.moves.first(where: { $0.uci == game.moves[ply] }) else { throw ChessError.invalid("A saved move could not be replayed.") }
                    progress = "Reviewing move \(before.board.fullmove) · \(ply + 1)/\(game.moves.count) plies"
                    let match = standard && before.board.turn == game.human ? GameReviewLogic.repertoireSuggestion(at: before.board, played: played.uci, san: played.san, ply: ply, choices: book.positions[before.board.openingKey] ?? []) : (matched: false, suggestion: nil as GameSuggestion?)
                    let baseline: EngineLine
                    if let cached = evaluationCache[ply] { baseline = cached }
                    else if entry.bughouse != nil { baseline = try await EngineController.shared.reviewBughouse(fen: positions[ply], side: before.board.turn) }
                    else { baseline = try await EngineController.shared.reviewPosition(variant: game.variant, history: prefix, side: before.board.turn) }
                    try Task.checkCancellation()
                    let afterHistory = prefix + [played.uci]
                    let after = try entry.bughouse == nil ? VariantRules.snapshot(variant: game.variant, history: afterHistory) : BughouseRules.snapshot(fen: positions[ply + 1])
                    let outcome: EngineLine?
                    if after.finished { outcome = nil }
                    else if entry.bughouse != nil { outcome = try await EngineController.shared.reviewBughouse(fen: positions[ply + 1], side: after.board.turn) }
                    else { outcome = try await EngineController.shared.reviewPosition(variant: game.variant, history: afterHistory, side: after.board.turn) }
                    try Task.checkCancellation()
                    // The next ordinary ply starts at this exact position, so reuse its search.
                    if entry.bughouse == nil { evaluationCache = [:]; evaluationCache[ply + 1] = outcome }
                    let assessment = MoveAssessment.make(ply: ply, move: played, before: before, after: after, baseline: baseline, outcome: outcome, inBook: match.matched && match.suggestion == nil)
                    if result.assessments == nil { result.assessments = [] }
                    result.assessments?.append(assessment)
                    if before.board.turn == game.human {
                        if match.matched {
                            result.repertoireMatches += 1
                            if let suggestion = match.suggestion { result.suggestions.append(suggestion) }
                        } else if let suggestion = GameReviewLogic.engineSuggestion(ply: ply, side: game.human, number: before.board.fullmove, played: played, before: before, after: after, baseline: baseline, outcome: outcome, standard: ordinaryMate, variant: game.variant) { result.suggestions.append(suggestion) }
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
    func position(at index: Int, partner: Bool = false) -> VariantSnapshot? {
        let frames = partner ? partnerPositions : positions
        guard frames.indices.contains(index) else { return nil }
        return try? VariantSnapshot.parse("fen\t\(frames[index])\nstatus\tongoing")
    }
}
