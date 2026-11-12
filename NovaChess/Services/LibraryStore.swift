import Foundation
import Combine

@MainActor final class LibraryStore: ObservableObject {
    @Published var state: LibraryState { didSet { save() } }
    @Published var notice: String?
    let puzzles: [ChessPuzzle]
    let openings: [OpeningLine]
    private let file: URL
    private var maySave = true
    private var openingNames: [String: String] = [:]
    init(directory override: URL? = nil, puzzles injectedPuzzles: [ChessPuzzle]? = nil, openings injectedOpenings: [OpeningLine]? = nil) {
        let directory = override ?? ApplicationStorage.directory()
        file = directory.appendingPathComponent("library.json")
        var warning: String?
        var unsafeToSave = false
        var loaded = LibraryState()
        if FileManager.default.fileExists(atPath: file.path) {
            do { loaded = try JSONDecoder().decode(LibraryState.self, from: Data(contentsOf: file)); guard loaded.version == 1 else { throw ChessError.invalid("Unsupported library version.") } }
            catch {
                loaded = LibraryState()
                let backup = directory.appendingPathComponent("library-backup-\(UUID().uuidString).json")
                do { try FileManager.default.copyItem(at: file, to: backup); warning = "Your library could not be read. A backup was preserved before starting a new library." }
                catch { unsafeToSave = true; warning = "Your library could not be read. Changes will not be saved until the original file can be backed up." }
            }
        }
        let updatedRatings = loaded.updateStandardRatings()
        let priorAchievements = loaded.playProgress.achievements
        loaded.playProgress.refreshMilestones()
        let addedMilestones = priorAchievements != loaded.playProgress.achievements
        state = loaded
        let assets: ([ChessPuzzle], [OpeningLine])
        do {
            let p: [ChessPuzzle]; if let injectedPuzzles { p = injectedPuzzles } else { p = try TrainingAssets.puzzles() }
            let o: [OpeningLine]; if let injectedOpenings { o = injectedOpenings } else { o = try TrainingAssets.openings() }
            assets = (p, o)
        }
        catch { assets = ([], []); warning = error.localizedDescription }
        puzzles = assets.0; openings = assets.1; notice = warning; maySave = !unsafeToSave
        for line in openings where openingNames[line.key] == nil { openingNames[line.key] = line.name }
        if addedMilestones || updatedRatings { save() }
    }
    private func save() {
        guard maySave else { return }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            var snapshot = state
            var retainedEvaluationCaches = 0
            for i in snapshot.history.indices where snapshot.history[i].engineEvaluations?.isEmpty == false {
                retainedEvaluationCaches += 1
                if retainedEvaluationCaches > 64 {
                    snapshot.history[i].engineEvaluations = nil; snapshot.history[i].evaluationSignature = nil
                }
            }
            let data = try JSONEncoder().encode(snapshot)
            #if os(iOS)
            try data.write(to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
            #else
            try data.write(to: file, options: [.atomic])
            #endif
        } catch { notice = "Your progress could not be saved: \(error.localizedDescription)" }
    }
    @discardableResult func recordCompleted(_ game: SavedComputerGame, result: String) -> UUID? {
        guard ["white", "black", "draw"].contains(result), let id = game.id else { return nil }
        if !state.history.contains(where: { $0.id == id }) {
            var entry = CompletedGame(game: game, result: result)
            var progress = state.playProgress
            entry.ratingChange = progress.finish(game, result: result)
            state.playProgress = progress
            state.history.insert(entry, at: 0)
        }
        return id
    }
    func recordBughouse(_ match: BughouseMatch) {
        guard let winner = match.winner, !state.history.contains(where: { $0.id == match.id }) else { return }
        var proxy = SavedComputerGame(mode: .bughouse, human: match.config.human, targetRating: match.config.ratings[BughouseConfig.seat(0, match.config.human.opposite)], moves: match.events.map(\.uci))
        proxy.id = match.id; proxy.notation = match.events.map { "\($0.board == 0 ? "A" : "B"): \($0.san)" }
        var entry = CompletedGame(game: proxy, result: winner == 2 ? "draw" : winner == 0 ? "white" : "black")
        entry.bughouse = match
        var progress = state.playProgress; _ = progress.finish(proxy, result: entry.result)
        state.playProgress = progress; state.history.insert(entry, at: 0)
    }
    func openingName(at position: Position) -> String? { openingNames[position.openingKey] }
}
