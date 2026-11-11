import SwiftUI
import GameKit

@MainActor struct CorrespondenceView: View {
    @StateObject private var service = CorrespondenceService.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var inviting = false
    @State private var selectedID: String?
    var body: some View {
        List {
            Section {
                Text("Play friends through Game Center. Keep several games going, with three days for each reply.").font(.subheadline).foregroundStyle(.secondary)
                if service.authenticated {
                    Button("Invite a player", systemImage: "person.badge.plus") { inviting = true }
                    Button("Refresh games", systemImage: "arrow.clockwise") { service.refresh() }.disabled(service.busy)
                } else {
                    Button("Connect to Game Center", systemImage: "person.crop.circle") { service.connect() }
                    Text("Use your Apple Game Center account. Game Center must be enabled for this app's Apple developer ID.").font(.caption).foregroundStyle(.secondary)
                }
                if service.busy { ProgressView("Loading games…") }
                if let error = service.error { Text(error).font(.caption).foregroundStyle(.red) }
            }.listRowBackground(ThemeCardBackground())
            Section("Your games") {
                if service.matches.isEmpty { Text(service.authenticated ? "Send an invitation to start your first game." : "Connect to see invitations and ongoing games.").foregroundStyle(.secondary) }
                ForEach(service.matches.filter { $0.matchID != nil }, id: \.matchID) { match in
                    Button { selectedID = match.matchID } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(opponent(match)).font(.headline).foregroundStyle(.primary)
                            Text(status(match)).font(.caption).foregroundStyle(.secondary)
                            if match.status != .ended, let deadline = match.currentParticipant?.timeoutDate { Text(deadline, style: .relative).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                        }.padding(.vertical, 6)
                    }
                }
            }.listRowBackground(ThemeCardBackground())
        }.modifier(AppSurface()).navigationTitle("Correspondence")
        .onAppear { if GKLocalPlayer.local.isAuthenticated { service.connect() } else { service.refresh() } }
        .onChange(of: service.incomingMatchID) { _, id in
            if let id { inviting = false; selectedID = id; service.incomingMatchID = nil }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active && service.authenticated { service.refresh() } }
        .sheet(isPresented: Binding(get: { service.authenticationController != nil }, set: { if !$0 { service.authenticationController = nil } })) {
            if let controller = service.authenticationController { GameCenterControllerHost(controller: controller).ignoresSafeArea() }
        }
        .sheet(isPresented: $inviting) {
            CorrespondenceMatchmaker { match in inviting = false; service.refresh(); selectedID = match.matchID } cancel: { inviting = false } failure: { error in inviting = false; service.error = error.localizedDescription }
        }
        .navigationDestination(isPresented: Binding(get: { selectedID != nil && !inviting }, set: { if !$0 { selectedID = nil } })) {
            if let id = selectedID { CorrespondenceBoardView(id: id).id(id) }
        }
    }
    private func opponent(_ match: GKTurnBasedMatch) -> String {
        (match.participants ?? []).compactMap(\.player).first { $0.gamePlayerID != GKLocalPlayer.local.gamePlayerID }?.displayName ?? "Invitation pending"
    }
    private func status(_ match: GKTurnBasedMatch) -> String {
        if (match.participants ?? []).contains(where: { $0.player?.gamePlayerID == GKLocalPlayer.local.gamePlayerID && $0.status == .invited }) { return "Invitation · tap to accept" }
        if match.status == .ended { return "Completed" }
        if match.status == .matching { return "Waiting for another player" }
        return match.currentParticipant?.player?.gamePlayerID == GKLocalPlayer.local.gamePlayerID ? "Your turn · 3 days per move" : "Their turn · 3 days per move"
    }
}

@MainActor private struct CorrespondenceBoardView: View {
    let id: String
    @EnvironmentObject private var library: LibraryStore
    @StateObject private var model = CorrespondenceBoardModel()
    @ObservedObject private var service = CorrespondenceService.shared
    @State private var resigning = false
    @Environment(\.scenePhase) private var phase
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack { Text(model.myTurn ? "Your turn" : "Waiting for your opponent").font(.headline); Spacer(); TurnBadge(side: model.board.turn) }
                MoveBoard(position: model.board, enabled: model.myTurn && !model.busy, flipped: model.human == .black, onMove: model.play)
                if let result = model.result { Text(result == "white" ? "White wins" : result == "black" ? "Black wins" : result == "draw" ? "Draw" : result).font(.title2.bold()) }
                if let deadline = model.match?.currentParticipant?.timeoutDate, model.result == nil {
                    HStack { Text("Turn deadline"); Spacer(); Text(deadline, style: .date); Text(deadline, style: .time) }.font(.caption).foregroundStyle(.secondary)
                }
                if library.state.history.contains(where: { $0.id == CorrespondenceGame.archiveID(id) }) {
                    NavigationLink("Review game & summary") { GameReviewView(id: CorrespondenceGame.archiveID(id)) }
                }
                if model.busy { ProgressView("Syncing with Game Center…") }
                if let error = model.error { Text(error).foregroundStyle(.red).font(.caption) }
                AppCard { DisclosureGroup("Game moves") { Text(model.notation.joined(separator: " ")).font(.subheadline.monospaced()) } }
                HStack {
                    Button("Refresh", systemImage: "arrow.clockwise") { model.refresh(id) }.disabled(model.busy)
                    Spacer()
                    Button("Resign", role: .destructive) { resigning = true }.disabled(!model.myTurn || model.busy)
                }.buttonStyle(.bordered)
            }.padding()
        }.modifier(AppSurface()).navigationTitle("Correspondence game").navigationBarTitleDisplayMode(.inline)
        .onAppear { model.attach(library); model.refresh(id) }
        .onReceive(service.$matches.dropFirst()) { _ in model.refresh(id) }
        .onChange(of: phase) { _, phase in if phase == .active { model.refresh(id) } }
        .confirmationDialog("Resign this game?", isPresented: $resigning) { Button("Resign", role: .destructive) { model.resign() } }
    }
}

private struct GameCenterControllerHost: UIViewControllerRepresentable {
    let controller: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { controller }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

@MainActor private struct CorrespondenceMatchmaker: UIViewControllerRepresentable {
    let found: (GKTurnBasedMatch) -> Void
    let cancel: () -> Void
    let failure: (Error) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> GKTurnBasedMatchmakerViewController {
        let request = GKMatchRequest(); request.minPlayers = 2; request.maxPlayers = 2; request.defaultNumberOfPlayers = 2
        let controller = GKTurnBasedMatchmakerViewController(matchRequest: request)
        controller.turnBasedMatchmakerDelegate = context.coordinator
        controller.showExistingMatches = false
        return controller
    }
    func updateUIViewController(_ uiViewController: GKTurnBasedMatchmakerViewController, context: Context) {}
    final class Coordinator: NSObject, GKTurnBasedMatchmakerViewControllerDelegate {
        let parent: CorrespondenceMatchmaker
        init(parent: CorrespondenceMatchmaker) { self.parent = parent }
        func turnBasedMatchmakerViewControllerWasCancelled(_ viewController: GKTurnBasedMatchmakerViewController) { Task { @MainActor in parent.cancel() } }
        func turnBasedMatchmakerViewController(_ viewController: GKTurnBasedMatchmakerViewController, didFailWithError error: Error) { Task { @MainActor in parent.failure(error) } }
        func turnBasedMatchmakerViewController(_ viewController: GKTurnBasedMatchmakerViewController, didFind match: GKTurnBasedMatch) { Task { @MainActor in parent.found(match) } }
        func turnBasedMatchmakerViewController(_ viewController: GKTurnBasedMatchmakerViewController, playerQuitFor match: GKTurnBasedMatch) { Task { @MainActor in parent.cancel() } }
    }
}
