import Foundation
import Combine

private func receiveEngineLine(_ pointer: UnsafePointer<CChar>?) {
    guard let pointer else { return }
    let line = String(cString: pointer)
    DispatchQueue.main.async { EngineController.shared.receive(line) }
}

private func receiveModernEngineLine(_ pointer: UnsafePointer<CChar>?) {
    guard let pointer else { return }
    let line = String(cString: pointer)
    DispatchQueue.main.async { EngineController.shared.receive(line, modern: true) }
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
    @Published private(set) var searchEngine = ""
    private struct Request {
        enum Kind { case analysis, computer, prepare, review }
        var id: UUID
        var kind: Kind
        var variant: String
        var setup: String
        var side: Side
        var rating: Int?
        var position: Position?
        var duration: Int?
        var modern: Bool {
            // Official Stockfish's calibrated range begins at 1320. Retain the
            // weaker variant-engine opponent for lower requested playing ratings.
            variant == "chess" && kind != .prepare && (rating.map { $0 >= 1320 } ?? true)
        }
    }
    private var modernReady = false
    private var modernFailure: String?
    var analysisEngineName: String { "Stockfish 19 · NNUE" }
    var analysisCandidates: Int { 3 }
    private var reviewResults: [UUID: EngineLine] = [:]
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
        let network = Bundle.main.url(forResource: "nn-1a298aa575a0", withExtension: "nnue")
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("NovaChess/Resources/Engine/nn-1a298aa575a0.nnue")
        network.path.withCString { cv_modern_start(receiveModernEngineLine, $0) }
        sendModern("uci")
        handshake = Task {
            try? await Task.sleep(for: .seconds(15))
            if !Task.isCancelled && (!ready || !modernReady) { error = "The chess engine did not become ready. Restart the app." }
        }
    }
    private func send(_ command: String) { command.withCString { cv_engine_send($0) } }
    private func sendModern(_ command: String) { command.withCString { cv_modern_send($0) } }
    private func sendSearch(_ command: String) { if active?.modern == true { sendModern(command) } else { send(command) } }
    func analyze(_ position: Position) {
        guard position.problems.isEmpty else { stop(); clearResults(); error = position.problems.joined(separator: "\n"); return }
        submit(Request(id: UUID(), kind: .analysis, variant: "chess", setup: "position fen \(position.fen)", side: position.turn, position: position))
    }
    func prepareVariant(_ variant: String) async throws {
        guard ["chess", "3check", "kingofthehill", "horde", "crazyhouse", "duck", "atomic", "antichess", "cvfog", "cvpawns", "cvpawnrace", "bughouse"].contains(variant) || (variant.hasPrefix("cv960") && (0..<960).contains(Int(variant.dropFirst(5)) ?? -1)) else { throw ChessError.invalid("Unsupported game style.") }
        let request = Request(id: UUID(), kind: .prepare, variant: variant, setup: "", side: .white)
        _ = try await awaitRequest(request)
    }
    func computerMove(variant: String, history: [String], rating: Int, side: Side) async throws -> String {
        let request = Request(id: UUID(), kind: .computer, variant: variant, setup: "position startpos moves " + history.joined(separator: " "), side: side, rating: max(1, min(10000, rating)))
        return try await awaitRequest(request)
    }
    func reviewPosition(variant: String, history: [String], side: Side, milliseconds: Int = 3000) async throws -> EngineLine {
        let request = Request(id: UUID(), kind: .review, variant: variant, setup: "position startpos moves " + history.joined(separator: " "), side: side, duration: max(250, min(10000, milliseconds)))
        defer { reviewResults.removeValue(forKey: request.id) }
        _ = try await awaitRequest(request)
        try Task.checkCancellation()
        guard let result = reviewResults[request.id] else { throw ChessError.invalid("The engine did not return an evaluation. Resume the review to retry.") }
        return result
    }
    func computerMove(fen: String, rating: Int, side: Side, milliseconds: Int = 650) async throws -> String {
        let request = Request(id: UUID(), kind: .computer, variant: "bughouse", setup: "position fen " + fen, side: side, rating: max(1, min(10000, rating)), duration: max(100, min(1300, milliseconds)))
        return try await awaitRequest(request)
    }
    func reviewBughouse(fen: String, side: Side) async throws -> EngineLine {
        let request = Request(id: UUID(), kind: .review, variant: "bughouse", setup: "position fen " + fen, side: side, duration: 250)
        defer { reviewResults.removeValue(forKey: request.id) }
        _ = try await awaitRequest(request)
        try Task.checkCancellation()
        guard let result = reviewResults[request.id] else { throw ChessError.invalid("The engine did not return an evaluation.") }
        return result
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
        if running { if !stopping { stopping = true; sendSearch("stop") } }
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
            send("setoption name UCI_Chess960 value \(request.variant.hasPrefix("cv960") ? "true" : "false")")
            send("setoption name Use NNUE value false"); send("ucinewgame"); send("isready")
            return
        }
        if request.modern {
            if let failure = modernFailure { pending = nil; error = failure; complete(request.id, .failure(ChessError.invalid(failure))); return }
            guard modernReady else { return }
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
        searchEngine = request.modern ? "Stockfish 19 NNUE" : "Fairy-Stockfish"
        let search = request.modern ? sendModern : send
        search("setoption name MultiPV value \(request.kind == .analysis ? analysisCandidates : 1)")
        if let target = request.rating {
            let minimum = request.modern ? 1320 : 500
            let maximum = request.modern ? 3190 : 2850
            if target < minimum {
                search("setoption name UCI_LimitStrength value false")
                search("setoption name Skill Level value \(request.modern ? 0 : -20)")
            } else if target <= maximum {
                search("setoption name Skill Level value 20")
                search("setoption name UCI_LimitStrength value true")
                search("setoption name UCI_Elo value \(target)")
            } else { search("setoption name UCI_LimitStrength value false"); search("setoption name Skill Level value 20") }
        } else { search("setoption name UCI_LimitStrength value false"); search("setoption name Skill Level value 20") }
        search(request.setup)
        if request.kind == .analysis { search("go infinite") }
        else if request.kind == .review { search("go movetime \(request.duration ?? 3000)") }
        else { search("go movetime \(request.duration ?? ((request.rating ?? 1000) >= 2000 ? 1300 : 650))") }
    }

    private func cancel(_ id: UUID) {
        complete(id, .failure(CancellationError()))
        if pending?.id == id { pending = nil }
        if active?.id == id && running && !stopping { stopping = true; sendSearch("stop") }
    }
    func stopAnalysis() {
        if let request = pending, request.kind == .analysis { pending = nil; complete(request.id, .failure(CancellationError())) }
        if let request = active, request.kind == .analysis {
            publishTask?.cancel(); publishTask = nil
            if running && !stopping { stopping = true; sendSearch("stop") }
        }
    }
    func stop() {
        if let pending { complete(pending.id, .failure(CancellationError())) }
        if let active { complete(active.id, .failure(CancellationError())) }
        pending = nil; publishTask?.cancel(); publishTask = nil
        if running && !stopping { stopping = true; sendSearch("stop") }
    }
    private func publish() { lines = latest.values.sorted { $0.rank < $1.rank } }
    func receive(_ line: String, modern: Bool = false) {
        if modern {
            if line.hasPrefix("engineerror ") {
                let message = String(line.dropFirst(12)); modernFailure = message; modernReady = false; error = message; handshake?.cancel()
                if let active, active.modern { complete(active.id, .failure(ChessError.invalid(message))); self.active = nil; running = false; stopping = false }
                driveQueue(); return
            }
            if line == "uciok" {
                sendModern("setoption name Threads value \(max(1, min(2, ProcessInfo.processInfo.activeProcessorCount - 1)))")
                sendModern("setoption name Hash value 128"); sendModern("ucinewgame"); sendModern("isready"); return
            }
            if line == "readyok" { modernReady = true; if ready { handshake?.cancel() }; driveQueue(); return }
        }
        if !modern {
        if line == "uciok" {
            send("setoption name Threads value 1"); send("setoption name Hash value 32")
            send("setoption name Use NNUE value false"); send("ucinewgame"); send("isready")
        }
        if line == "readyok" {
            if let switchingVariant { selectedVariant = switchingVariant; self.switchingVariant = nil }
            ready = true; if modernReady { handshake?.cancel() }; driveQueue()
        }
        }
        guard active?.modern == modern else { return }
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
                if active.kind == .review { reviewResults[active.id] = latest[1] }
                bestMove = move; complete(active.id, .success(move))
            }
            running = false; stopping = false; active = nil; driveQueue()
        }
    }
}
