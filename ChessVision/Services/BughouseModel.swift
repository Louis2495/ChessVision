import Foundation
import Combine

@MainActor final class BughouseModel: ObservableObject {
    @Published private(set) var match: BughouseMatch?
    @Published private(set) var states: [VariantSnapshot] = []
    @Published private(set) var clocks: [ChessClock] = []
    @Published private(set) var running = false
    @Published private(set) var loading = false
    @Published private(set) var thinkingBoard: Int?
    @Published var error: String?
    @Published var premoves = PremoveQueue()
    private weak var library: LibraryStore?
    private var task: Task<Void, Never>?
    private var ticker: Task<Void, Never>?
    private var generation = UUID()
    private var revisions = [0, 0]
    func attach(_ library: LibraryStore) {
        self.library = library
        if match == nil, let saved = library.state.bughouse { load(saved, start: false) }
    }
    func newMatch(_ config: BughouseConfig) {
        do { try config.validate(); load(BughouseMatch(config: config), start: true) }
        catch { self.error = error.localizedDescription }
    }
    private func load(_ saved: BughouseMatch, start: Bool) {
        pause(); let token = UUID(); generation = token; loading = true; error = nil
        task = Task {
            do {
                try saved.config.validate()
                guard saved.remaining.count == 4 else { throw ChessError.invalid("The saved clocks could not be read.") }
                try await EngineController.shared.prepareVariant("bughouse")
                let frames = try await BughouseRules.replay(saved.events)
                try Task.checkCancellation(); guard generation == token else { return }
                states = [try BughouseRules.snapshot(fen: frames[0].last!), try BughouseRules.snapshot(fen: frames[1].last!)]
                match = saved; revisions = [0,0]
                clocks = (0..<2).map { board in ChessClock(control: saved.config.control, white: saved.remaining[board * 2], black: saved.remaining[board * 2 + 1], active: states[board].board.turn) }
                loading = false
                if start && saved.winner == nil { resume() }
            } catch is CancellationError { }
            catch { if generation == token { self.error = error.localizedDescription; loading = false } }
        }
    }
    func pause() {
        premoves.clear()
        task?.cancel(); ticker?.cancel(); generation = UUID(); running = false; loading = false; thinkingBoard = nil
        let now = ProcessInfo.processInfo.systemUptime
        for index in clocks.indices { clocks[index].pause(at: now) }
        persist(at: now)
    }
    func resume() {
        guard !loading, !running, let match, match.winner == nil, states.count == 2, clocks.count == 2 else { return }
        let token = UUID(); generation = token; running = true
        let now = ProcessInfo.processInfo.systemUptime
        for index in clocks.indices { clocks[index].start(at: now) }
        ticker = Task {
            while !Task.isCancelled && running && generation == token {
                checkFlags(); try? await Task.sleep(for: .milliseconds(100))
            }
        }
        task = Task {
            var lastBoard = 1
            do {
                try await EngineController.shared.prepareVariant("bughouse")
                while running && generation == token {
                    try Task.checkCancellation(); checkFlags(); guard running else { break }
                    let eligible = [0,1].filter { $0 == 1 || states[0].board.turn != match.config.human }
                    guard let board = eligible.first(where: { $0 != lastBoard }) ?? eligible.first else { try await Task.sleep(for: .milliseconds(50)); continue }
                    let revision = revisions[board], state = states[board]
                    thinkingBoard = board
                    let rating = match.config.ratings[BughouseConfig.seat(board, state.board.turn)]
                    let remaining = clocks[board].remaining(for: state.board.turn, at: ProcessInfo.processInfo.systemUptime)
                    let budget = Int(min(rating >= 2000 ? 1300.0 : 650.0, max(100, remaining * 20 + Double(match.config.increment * 100))))
                    let uci = try await EngineController.shared.computerMove(fen: state.fen, rating: rating, side: state.board.turn, milliseconds: budget)
                    try Task.checkCancellation(); guard generation == token && running else { break }
                    checkFlags(); guard running else { break }
                    if revisions[board] == revision { try apply(uci, board: board); lastBoard = board }
                    else { lastBoard = 1 - board }
                    try await Task.sleep(for: .milliseconds(150))
                }
            } catch is CancellationError { }
            catch { if generation == token { self.error = error.localizedDescription; pause() } }
            if generation == token { thinkingBoard = nil }
        }
    }
    func flushPremoves() {
        guard MovePreferences.premoves else { premoves.clear(); return }
        guard running, states.count == 2, states[0].board.turn == match?.config.human else { return }
        checkFlags(); guard running else { return }
        if let next = premoves.take(legal: states[0].moves) {
            do { try apply(next.uci, board: 0) } catch { self.error = error.localizedDescription }
        }
    }
    func play(_ move: VariantMove) {
        guard running, states.count == 2, let match, states[0].board.turn == match.config.human else { return }
        checkFlags(); guard running else { return }
        do { try apply(move.uci, board: 0) } catch { self.error = error.localizedDescription }
    }
    private func apply(_ uci: String, board: Int) throws {
        guard var current = match, current.winner == nil, let move = states[board].moves.first(where: { $0.uci == uci }) else { throw ChessError.invalid("That move is no longer legal. Try again.") }
        let before = states[board].board, now = ProcessInfo.processInfo.systemUptime
        var updated = states
        try BughouseRules.play(uci, on: board, states: &updated)
        clocks[board].press(before.turn, at: now)
        current.events.append(BughouseEvent(board: board, side: before.turn, number: before.fullmove, uci: uci, san: move.san))
        states = updated; match = current; revisions[board] += 1
        if updated[board].transferred != nil { revisions[1 - board] += 1 }
        if updated[board].finished {
            let status = updated[board].status
            finish(team: status == "draw" ? 2 : BughouseConfig.team(board, status == "white" ? .white : .black), reason: "Board \(board == 0 ? "A" : "B") ended", at: now)
        } else {
            persist(at: now)
            if !MovePreferences.premoves { premoves.clear() }
            if states[0].board.turn == current.config.human,
               let next = premoves.take(legal: states[0].moves) { try apply(next.uci, board: 0) }
        }
    }
    private func checkFlags() {
        guard running, clocks.count == 2 else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let expired = clocks.indices.compactMap { board -> (Int, Double)? in
            guard let deadline = clocks[board].deadline, deadline <= now else { return nil }
            return (board, deadline)
        }.sorted { $0.1 < $1.1 }
        guard let first = expired.first else { return }
        let losingTeam = BughouseConfig.team(first.0, clocks[first.0].active)
        let simultaneous = expired.dropFirst().contains { abs($0.1 - first.1) < 0.001 && BughouseConfig.team($0.0, clocks[$0.0].active) != losingTeam }
        finish(team: simultaneous ? 2 : 1 - losingTeam, reason: "Flag on board \(first.0 == 0 ? "A" : "B")", at: first.1)
    }
    func resign() {
        guard let match, match.winner == nil else { return }
        finish(team: 1 - match.config.humanTeam, reason: "Your team resigned", at: ProcessInfo.processInfo.systemUptime)
    }
    private func finish(team: Int, reason: String, at now: Double) {
        guard match?.winner == nil else { return }
        premoves.clear()
        match?.winner = team; match?.reason = reason
        for index in clocks.indices { clocks[index].pause(at: now) }
        running = false; task?.cancel(); ticker?.cancel(); thinkingBoard = nil
        persist(at: now)
        if let match { library?.recordBughouse(match) }
    }
    private func persist(at now: Double) {
        guard var current = match else { return }
        if clocks.count == 2 { current.remaining = [clocks[0].remaining(for: .white, at: now), clocks[0].remaining(for: .black, at: now), clocks[1].remaining(for: .white, at: now), clocks[1].remaining(for: .black, at: now)] }
        match = current; library?.state.bughouse = current
    }
}
