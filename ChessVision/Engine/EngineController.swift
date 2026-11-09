import Foundation
import Combine

private func receiveEngineLine(_ pointer: UnsafePointer<CChar>?) {
    guard let pointer else { return }
    let line = String(cString: pointer)
    Task { @MainActor in EngineController.shared.receive(line) }
}
@MainActor final class EngineController: ObservableObject {
    static let shared = EngineController()
    @Published var lines: [EngineLine] = []
    @Published var running = false
    @Published var ready = false
    @Published var bestMove: String?
    @Published var error: String?
    private var turn: Side = .white
    private var pending: (Position, Int)?
    private var handshake: Task<Void, Never>?
    private init() {
        cv_engine_start(receiveEngineLine)
        send("uci")
        handshake = Task { try? await Task.sleep(for: .seconds(10)); if !Task.isCancelled && !ready { error = "Stockfish did not become ready. Restart the app." } }
    }
    private func send(_ command: String) { command.withCString { cv_engine_send($0) } }
    func analyze(_ position: Position, seconds: Int) {
        guard position.problems.isEmpty else { error = position.problems.joined(separator: "\n"); return }
        pending = (position, seconds)
        if running { send("stop") } else if ready { launchPending() }
    }
    private func launchPending() {
        guard let (position, seconds) = pending else { return }
        pending = nil; lines = []; bestMove = nil; error = nil; turn = position.turn; running = true
        send("ucinewgame"); send("position fen \(position.fen)"); send("go movetime \(max(1,min(seconds,30))*1000)")
    }
    func stop() { pending = nil; if running { send("stop") } }
    func receive(_ line: String) {
        if line == "uciok" { send("setoption name Threads value 1"); send("setoption name Hash value 32"); send("setoption name MultiPV value 3"); send("isready") }
        if line == "readyok" { ready = true; handshake?.cancel(); launchPending() }
        if let result = EngineLine.parse(line, turn: turn), running {
            lines.removeAll{$0.rank == result.rank}; lines.append(result); lines.sort{$0.rank < $1.rank}
        }
        if line.hasPrefix("bestmove ") {
            bestMove = line.split(separator:" ").dropFirst().first.map(String.init)
            running = false; launchPending()
        }
    }
}
