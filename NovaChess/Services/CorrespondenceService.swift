import SwiftUI
import GameKit

@MainActor final class CorrespondenceService: NSObject, ObservableObject, GKLocalPlayerListener {
    static let shared = CorrespondenceService()
    @Published private(set) var authenticated = false
    @Published private(set) var matches: [GKTurnBasedMatch] = []
    @Published private(set) var busy = false
    @Published var error: String?
    @Published var authenticationController: UIViewController?
    @Published var incomingMatchID: String?
    private var registered = false
    func connect() {
        error = nil
        if GKLocalPlayer.local.isAuthenticated { didConnect(); return }
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            Task { @MainActor in
                guard let self else { return }
                if let controller { self.authenticationController = controller }
                else if let error { self.error = error.localizedDescription }
                if GKLocalPlayer.local.isAuthenticated { self.authenticationController = nil; self.didConnect() }
            }
        }
    }
    private func didConnect() {
        authenticated = true
        if !registered { GKLocalPlayer.local.register(self); registered = true }
        refresh()
    }
    func refresh() {
        guard GKLocalPlayer.local.isAuthenticated else { authenticated = false; matches = []; return }
        busy = true
        GKTurnBasedMatch.loadMatches { [weak self] matches, error in
            Task { @MainActor in
                guard let self else { return }
                self.busy = false
                if let error { self.error = error.localizedDescription; return }
                self.matches = (matches ?? []).sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
            }
        }
    }
    func load(_ id: String) async throws -> GKTurnBasedMatch {
        try await withCheckedThrowingContinuation { continuation in
            GKTurnBasedMatch.load(withID: id) { match, error in
                if let error { continuation.resume(throwing: error) }
                else if let match { continuation.resume(returning: match) }
                else { continuation.resume(throwing: ChessError.invalid("This game is no longer available.")) }
            }
        }
    }
    func accept(_ match: GKTurnBasedMatch) async throws -> GKTurnBasedMatch {
        try await withCheckedThrowingContinuation { continuation in
            match.acceptInvite { accepted, error in
                if let error { continuation.resume(throwing: error) }
                else if let accepted { continuation.resume(returning: accepted) }
                else { continuation.resume(throwing: ChessError.invalid("The invitation could not be accepted.")) }
            }
        }
    }
    func data(for match: GKTurnBasedMatch) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            match.loadMatchData { data, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: data) }
            }
        }
    }
    func saveMetadata(_ game: CorrespondenceGame, match: GKTurnBasedMatch) async throws {
        guard match.currentParticipant?.player?.gamePlayerID == GKLocalPlayer.local.gamePlayerID else { throw ChessError.invalid("Spectator permission can be changed on your turn.") }
        let data = try JSONEncoder().encode(game)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            match.saveCurrentTurn(withMatch: data) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
        refresh()
    }
    func submit(_ game: CorrespondenceGame, match: GKTurnBasedMatch, result: String?) async throws {
        guard match.currentParticipant?.player?.gamePlayerID == GKLocalPlayer.local.gamePlayerID else { throw ChessError.invalid("It is not your turn. Refresh the game.") }
        if let deadline = match.currentParticipant?.timeoutDate, deadline <= Date() { throw ChessError.invalid("The turn deadline passed. Refresh to get the server's current result.") }
        let data = try JSONEncoder().encode(game)
        guard data.count <= match.matchDataMaximumSize else { throw ChessError.invalid("The game is too long to send.") }
        if let result {
            for participant in match.participants ?? [] {
                if result == "draw" { participant.matchOutcome = .tied }
                else {
                    let white = participant.player?.gamePlayerID == game.whitePlayerID
                    participant.matchOutcome = (result == "white") == white ? .won : .lost
                }
            }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                match.endMatchInTurn(withMatch: data) { error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
        } else {
            let others = (match.participants ?? []).filter { $0 !== match.currentParticipant && $0.status != .done }
            guard !others.isEmpty else { throw ChessError.invalid("The other player is no longer in this game.") }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                match.endTurn(withNextParticipants: others, turnTimeout: CorrespondenceGame.turnSeconds, match: data) { error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
        }
        refresh()
    }
    nonisolated func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {
        let id = match.matchID
        Task { @MainActor in if didBecomeActive { incomingMatchID = id }; refresh() }
    }
    nonisolated func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) { Task { @MainActor in refresh() } }
}

@MainActor final class CorrespondenceBoardModel: ObservableObject {
    @Published private(set) var match: GKTurnBasedMatch?
    @Published private(set) var game: CorrespondenceGame?
    @Published private(set) var board = Position.initial
    @Published private(set) var notation: [String] = []
    @Published private(set) var result: String?
    @Published private(set) var busy = false
    @Published var error: String?
    private var generation = UUID()
    private weak var library: LibraryStore?
    func attach(_ library: LibraryStore) { self.library = library }
    var human: Side { game?.whitePlayerID == GKLocalPlayer.local.gamePlayerID ? .white : .black }
    var myTurn: Bool { match?.currentParticipant?.player?.gamePlayerID == GKLocalPlayer.local.gamePlayerID && board.turn == human && result == nil && match?.status != .ended }
    func refresh(_ id: String) {
        guard !busy else { return }
        let token = UUID(); generation = token; busy = true; error = nil
        Task {
            defer { if generation == token { busy = false } }
            do {
                var fresh = try await CorrespondenceService.shared.load(id)
                if (fresh.participants ?? []).contains(where: { $0.player?.gamePlayerID == GKLocalPlayer.local.gamePlayerID && $0.status == .invited }) {
                    fresh = try await CorrespondenceService.shared.accept(fresh)
                }
                let data = try await CorrespondenceService.shared.data(for: fresh)
                try Task.checkCancellation(); guard generation == token else { return }
                let payload: CorrespondenceGame
                if let data, !data.isEmpty { payload = try JSONDecoder().decode(CorrespondenceGame.self, from: data) }
                else {
                    guard let white = fresh.currentParticipant?.player?.gamePlayerID else { throw ChessError.invalid("Waiting for the invitation to be accepted.") }
                    payload = CorrespondenceGame(whitePlayerID: white)
                }
                let state = try await Task.detached(priority: .userInitiated) { try payload.validated() }.value
                guard generation == token else { return }
                match = fresh; game = payload; board = state.board; notation = state.notation; result = state.result
                if fresh.status == .ended && result == nil {
                    let local = (fresh.participants ?? []).first { $0.player?.gamePlayerID == GKLocalPlayer.local.gamePlayerID }
                    switch local?.matchOutcome {
                    case .won: result = human == .white ? "white" : "black"
                    case .lost, .quit, .timeExpired: result = human == .white ? "black" : "white"
                    case .tied: result = "draw"
                    default: result = "Game ended"
                    }
                }
                archiveIfFinished()
                await publishIfAllowed()
            } catch { if generation == token { self.error = error.localizedDescription } }
        }
    }
    func play(_ move: ChessMove) {
        guard !busy, myTurn, var updated = game, let match else { return }
        busy = true; error = nil
        Task {
            do {
                try updated.play(move.uci)
                let state = try updated.validated()
                try await CorrespondenceService.shared.submit(updated, match: match, result: state.result)
                game = updated; board = state.board; notation = state.notation; result = state.result; archiveIfFinished()
                busy = false; if let id = match.matchID { refresh(id) }
            } catch { self.error = error.localizedDescription; busy = false }
        }
    }
    func allowSpectators(_ allowed: Bool) {
        guard !busy, myTurn, var updated = game, let match, let matchID = match.matchID else { return }
        busy = true; error = nil
        Task {
            defer { busy = false }
            do {
                let id = CorrespondenceGame.archiveID(matchID).uuidString
                guard await SocialStore.shared.profile != nil else { throw ChessError.invalid("Create a NovaChess username in Players first.") }
                try await SocialStore.shared.consent(gameID: id, allowed: allowed)
                var ids = Set(updated.spectatorConsents ?? [])
                if allowed { ids.insert(GKLocalPlayer.local.gamePlayerID) } else { ids.remove(GKLocalPlayer.local.gamePlayerID) }
                updated.spectatorConsents = Array(ids)
                try await CorrespondenceService.shared.saveMetadata(updated, match: match)
                game = updated; await publishIfAllowed()
            } catch { self.error = error.localizedDescription }
        }
    }
    private func publishIfAllowed() async {
        guard let game, let match, let matchID = match.matchID, await SocialStore.shared.profile != nil else { return }
        let id = CorrespondenceGame.archiveID(matchID).uuidString
        let players = (match.participants ?? []).compactMap { $0.player?.gamePlayerID }
        do {
            guard players.count == 2, Set(game.spectatorConsents ?? []).isSuperset(of: players) else { try await SocialStore.shared.unpublish(gameID: id); return }
            let profiles = try await SocialStore.shared.profiles(forGameCenterIDs: players)
            let white = profiles.first { $0.gameCenterID == game.whitePlayerID }?.username ?? "White"
            let black = profiles.first { $0.gameCenterID != game.whitePlayerID }?.username ?? "Black"
            try await SocialStore.shared.publish(gameID: id, fen: board.fen, notation: notation, mode: "Correspondence", white: "@" + white, black: "@" + black, result: result, consentUsers: profiles.map(\.username))
        } catch { self.error = error.localizedDescription }
    }
    func resign() {
        guard !busy, myTurn, var updated = game, let match else { return }
        updated.resigned = human; busy = true
        Task {
            do {
                let state = try updated.validated()
                try await CorrespondenceService.shared.submit(updated, match: match, result: state.result)
                game = updated; result = state.result; archiveIfFinished(); busy = false; if let id = match.matchID { refresh(id) }
            } catch { self.error = error.localizedDescription; busy = false }
        }
    }
    private func archiveIfFinished() {
        guard let result, ["white", "black", "draw"].contains(result), let game, let id = match?.matchID else { return }
        var saved = SavedComputerGame(mode: .normal, human: human, targetRating: 1000, moves: game.moves)
        saved.id = CorrespondenceGame.archiveID(id); saved.notation = notation; saved.resigned = game.resigned
        saved.opponentName = (match?.participants ?? []).compactMap(\.player).first { $0.gamePlayerID != GKLocalPlayer.local.gamePlayerID }?.displayName ?? "Game Center player"
        library?.recordCompleted(saved, result: result)
    }

}
