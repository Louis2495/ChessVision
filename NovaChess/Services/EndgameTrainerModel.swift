import Foundation
import Combine

@MainActor final class EndgameTrainerModel: ObservableObject {
    @Published private(set) var session: EndgameSession?
    @Published private(set) var busy = false
    @Published private(set) var error: String?
    @Published private(set) var hint: String?
    private var task: Task<Void, Never>?
    private var generation = UUID()
    func start(_ exercise: EndgameExercise) {
        pause()
        do { session = try EndgameSession(exercise: exercise); error = nil; hint = nil; resume() }
        catch { self.error = error.localizedDescription }
    }
    func pause() { task?.cancel(); task = nil; generation = UUID(); busy = false }
    func play(_ move: ChessMove) {
        guard !busy, var current = session, current.board.turn == current.exercise.side else { return }
        do { try current.play(move.uci); session = current; hint = nil; error = nil; resume() }
        catch { self.error = error.localizedDescription }
    }
    func claimDraw() {
        guard var current = session, current.board.turn == current.exercise.side else { return }
        pause()
        do { try current.claimDraw(); session = current; error = nil }
        catch { self.error = error.localizedDescription }
    }
    func resume() {
        guard !busy, let current = session, current.outcome == .ongoing, current.board.turn != current.exercise.side else { return }
        search(forHint: false)
    }
    func showHint() {
        guard !busy, let current = session, current.outcome == .ongoing, current.board.turn == current.exercise.side else { return }
        search(forHint: true)
    }
    private func search(forHint: Bool) {
        guard let current = session else { return }
        pause(); let token = UUID(); generation = token; busy = true; error = nil
        task = Task {
            defer { if generation == token { busy = false } }
            do {
                let uci = try await EngineController.shared.endgameMove(initial: current.initial, history: current.moves)
                try Task.checkCancellation(); guard generation == token else { return }
                guard let move = current.board.legalMoves().first(where: { $0.uci == uci }) else { throw ChessError.invalid("The engine did not return a legal move. Try again.") }
                if forHint { hint = try current.board.san(for: move) }
                else { var updated = current; try updated.play(uci); session = updated }
            } catch is CancellationError {} catch { if generation == token { self.error = error.localizedDescription } }
        }
    }
}
