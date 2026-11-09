import Foundation
import Combine

private func receiveEngineLine(_ pointer: UnsafePointer<CChar>?) {
    guard let pointer else { return }
    let line = String(cString: pointer)
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
    @Published private(set) var selectedVariant = "chess"
    private struct Request {
        enum Kind { case analysis, computer, prepare }
        var id: UUID
        var kind: Kind
        var variant: String
        var setup: String
        var side: Side
        var rating: Int?
        var position: Position?
    }
    private var pending: Request?
    private var active: Request?
    private var continuations: [UUID: CheckedContinuation<String, Error>] = [:]
    private var switchingVariant: String?
    private var stopping = false
    private var latest: [Int: EngineLine] = [:]
    private var publishTask: Task<Void, Never>?
    private var handshake: Task<Void, Never>?

    private init() {
        cv_engine_start(receiveEngineLine); send("uci")
        handshake = Task {
            try? await Task.sleep(for: .seconds(15))
            if !Task.isCancelled && !ready { error = "The chess engine did not become ready. Restart the app." }
        }
    }
    private func send(_ command: String) { command.withCString { cv_engine_send($0) } }
    func analyze(_ position: Position) {
        guard position.problems.isEmpty else { stop(); clearResults(); error = position.problems.joined(separator: "\n"); return }
        submit(Request(id: UUID(), kind: .analysis, variant: "chess", setup: "position fen \(position.fen)", side: position.turn, position: position))
    }
    func prepareVariant(_ variant: String) async throws {
        guard ["chess", "3check", "kingofthehill", "horde", "crazyhouse"].contains(variant) else { throw ChessError.invalid("Unsupported game style.") }
        let request = Request(id: UUID(), kind: .prepare, variant: variant, setup: "", side: .white)
        _ = try await awaitRequest(request)
    }
    func computerMove(variant: String, history: [String], rating: Int, side: Side) async throws -> String {
        let request = Request(id: UUID(), kind: .computer, variant: variant, setup: "position startpos moves " + history.joined(separator: " "), side: side, rating: max(1, min(10000, rating)))
        return try await awaitRequest(request)
    }
    private func awaitRequest(_ request: Request) async throws -> String {
        try Task.checkCancellation()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                continuations[request.id] = continuation
                submit(request)
            }
        }, onCancel: { Task { @MainActor in self.cancel(request.id) } })
    }
    private func complete(_ id: UUID, _ result: Result<String, Error>) { continuations.removeValue(forKey: id)?.resume(with: result) }
    private func submit(_ request: Request) {
        if let old = pending { complete(old.id, .failure(CancellationError())) }
        if let old = active { complete(old.id, .failure(CancellationError())) }
        pending = request; clearResults()
        if running { if !stopping { stopping = true; send("stop") } }
        else { driveQueue() }
    }
    private func clearResults() {
        publishTask?.cancel(); publishTask = nil; latest = [:]
        lines = []; bestMove = nil; error = nil; terminal = nil; analyzedFEN = nil
    }
    private func driveQueue() {
        guard ready, !running, let request = pending else { return }
        if selectedVariant != request.variant {
            ready = false; switchingVariant = request.variant
            send("setoption name UCI_Variant value \(request.variant)")
            send("setoption name Use NNUE value false"); send("isready")
            return
        }
        pending = nil; stopping = false
        if request.kind == .prepare { complete(request.id, .success("ready")); return }
        if let position = request.position {
            analyzedFEN = position.fen
            if position.legalMoves().isEmpty {
                terminal = position.isInCheck ? "Checkmate — \(position.turn.opposite.title) wins" : "Stalemate — draw"
                bestMove = "(none)"; complete(request.id, .success("(none)")); return
            }
        }
        active = request; running = true
        send("setoption name MultiPV value \(request.kind == .analysis ? 3 : 1)")
        if let target = request.rating, target <= 2850 {
            send("setoption name UCI_LimitStrength value \(target >= 500 ? "true" : "false")")
            if target >= 500 { send("setoption name UCI_Elo value \(target)") }
            else { send("setoption name Skill Level value -20") }
        } else { send("setoption name UCI_LimitStrength value false"); send("setoption name Skill Level value 20") }
        send(request.setup)
        send(request.kind == .analysis ? "go infinite" : "go movetime \((request.rating ?? 1000) >= 2000 ? 1300 : 650)")
    }
    private func cancel(_ id: UUID) {
        complete(id, .failure(CancellationError()))
        if pending?.id == id { pending = nil }
        if active?.id == id && running && !stopping { stopping = true; send("stop") }
    }
    func stopAnalysis() {
        if let request = pending, request.kind == .analysis { pending = nil; complete(request.id, .failure(CancellationError())) }
        if let request = active, request.kind == .analysis {
            publishTask?.cancel(); publishTask = nil
            if running && !stopping { stopping = true; send("stop") }
        }
    }
    func stop() {
        if let pending { complete(pending.id, .failure(CancellationError())) }
        if let active { complete(active.id, .failure(CancellationError())) }
        pending = nil; publishTask?.cancel(); publishTask = nil
        if running && !stopping { stopping = true; send("stop") }
    }
    private func publish() { lines = latest.values.sorted { $0.rank < $1.rank } }
    func receive(_ line: String) {
        if line == "uciok" {
            send("setoption name Threads value 1"); send("setoption name Hash value 32")
            send("setoption name Use NNUE value false"); send("ucinewgame"); send("isready")
        }
        if line == "readyok" {
            if let switchingVariant { selectedVariant = switchingVariant; self.switchingVariant = nil }
            ready = true; handshake?.cancel(); driveQueue()
        }
        if running && !stopping, let active, let result = EngineLine.parse(line, turn: active.side) {
            latest[result.rank] = result
            if publishTask == nil {
                publishTask = Task {
                    do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
                    publishTask = nil
                    if running && !stopping { publish() }
                }
            }
        }
        if line.hasPrefix("bestmove ") {
            if !stopping, let active {
                publishTask?.cancel(); publishTask = nil; publish()
                let move = line.split(separator: " ").dropFirst().first.map(String.init) ?? "(none)"
                bestMove = move; complete(active.id, .success(move))
            }
            running = false; stopping = false; active = nil; driveQueue()
        }
    }
}
