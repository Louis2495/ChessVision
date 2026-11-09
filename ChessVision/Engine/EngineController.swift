import Foundation
import Combine

private func receiveEngineLine(_ pointer: UnsafePointer<CChar>?) {
    guard let pointer else { return }
    let line = String(cString: pointer)
    // Stockfish serializes output. Dispatch preserves that order across search replacements.
    DispatchQueue.main.async { EngineController.shared.receive(line) }
}

@MainActor final class EngineController: ObservableObject {
    static let shared = EngineController()
    @Published private(set) var lines: [EngineLine] = []
    @Published private(set) var running = false
    @Published private(set) var ready = false
    @Published private(set) var bestMove: String?
    @Published private(set) var analyzedFEN: String?
    @Published private(set) var terminal: String?
    @Published private(set) var error: String?
    private var turn: Side = .white
    private var pending: Position?
    private var stopping = false
    private var latest: [Int: EngineLine] = [:]
    private var publishTask: Task<Void, Never>?
    private var handshake: Task<Void, Never>?

    private init() {
        cv_engine_start(receiveEngineLine)
        send("uci")
        handshake = Task {
            try? await Task.sleep(for: .seconds(10))
            if !Task.isCancelled && !ready { error = "Stockfish did not become ready. Restart the app." }
        }
    }
    private func send(_ command: String) { command.withCString { cv_engine_send($0) } }

    /// Infinite UCI search deepens until the board changes or this screen leaves the foreground.
    func analyze(_ position: Position) {
        pending = nil; clearResults()
        guard position.problems.isEmpty else {
            stop(); error = position.problems.joined(separator: "\n"); return
        }
        pending = position
        if running {
            if !stopping { stopping = true; send("stop") }
        } else if ready { launchPending() }
    }
    private func clearResults() {
        publishTask?.cancel(); publishTask = nil; latest = [:]
        lines = []; bestMove = nil; error = nil; terminal = nil; analyzedFEN = nil
    }
    private func launchPending() {
        guard let position = pending else { return }
        pending = nil; stopping = false; turn = position.turn; analyzedFEN = position.fen
        if position.legalMoves().isEmpty {
            terminal = position.isInCheck ? "Checkmate — \(position.turn.opposite.title) wins" : "Stalemate — draw"
            bestMove = "(none)"; running = false; return
        }
        running = true
        send("position fen \(position.fen)")
        send("go infinite")
    }
    func stop() {
        pending = nil
        publishTask?.cancel(); publishTask = nil
        if running && !stopping { stopping = true; send("stop") }
    }
    private func publish() {
        lines = latest.values.sorted { $0.rank < $1.rank }
    }
    func receive(_ line: String) {
        if line == "uciok" {
            send("setoption name Threads value 1")
            send("setoption name Hash value 32")
            send("setoption name MultiPV value 3")
            send("ucinewgame"); send("isready")
        }
        if line == "readyok" { ready = true; handshake?.cancel(); launchPending() }
        if running && !stopping, let result = EngineLine.parse(line, turn: turn) {
            latest[result.rank] = result
            // Keep streaming analysis responsive without recomputing three SAN tables per engine line.
            if publishTask == nil {
                publishTask = Task {
                    do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
                    publishTask = nil
                    if running && !stopping { publish() }
                }
            }
        }
        if line.hasPrefix("bestmove ") {
            if !stopping {
                publishTask?.cancel(); publishTask = nil; publish()
                bestMove = line.split(separator: " ").dropFirst().first.map(String.init)
            }
            running = false; stopping = false
            // A replacement search starts only after the old search's bestmove barrier.
            launchPending()
        }
    }
}
