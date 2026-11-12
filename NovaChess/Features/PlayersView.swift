import SwiftUI
import GameKit

@MainActor struct PlayersView: View {
    @StateObject private var store = SocialStore.shared
    @State private var username = ""
    @State private var search = ""
    var body: some View {
        List {
            Section {
                if let profile = store.profile {
                    Label("@" + profile.username, systemImage: "person.crop.circle.fill").font(.title2.bold())
                    Button("Refresh friends", systemImage: "arrow.clockwise") { Task { await store.refreshContacts() } }
                } else if store.accountReady {
                    TextField("Choose a username", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("3–20 letters, numbers or underscores. Your username is public.").font(.caption).foregroundStyle(.secondary)
                    Button("Create username") { Task { await store.register(username) } }.disabled(store.busy)
                } else {
                    Text("Find players, add friends and watch public boards with a NovaChess username.").foregroundStyle(.secondary)
                    Button("Connect with iCloud") { Task { await store.connect() } }
                }
                if store.busy { ProgressView() }
                if let error = store.error { Text(error).font(.caption).foregroundStyle(.red) }
            }.listRowBackground(ThemeCardBackground())
            if store.profile != nil {
                Section("Find players") {
                    HStack {
                        TextField("Search usernames", text: $search).textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search).onSubmit { Task { await store.search(search) } }
                        Button("Search") { Task { await store.search(search) } }.disabled(Usernames.prefix(search) == nil || store.busy)
                    }
                    ForEach(store.results) { profile in NavigationLink("@" + profile.username) { PlayerDetailView(player: profile) } }
                }.listRowBackground(ThemeCardBackground())
                Section("Friend requests") {
                    if store.requests.isEmpty { Text("No pending requests").foregroundStyle(.secondary) }
                    ForEach(store.requests) { request in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("@" + request.sender.username).font(.headline)
                            HStack {
                                Button("Accept") { Task { await store.respond(request, accept: true) } }.buttonStyle(.borderedProminent)
                                Button("Decline") { Task { await store.respond(request, accept: false) } }.buttonStyle(.bordered)
                            }.disabled(store.busy)
                        }.padding(.vertical, 4)
                    }
                }.listRowBackground(ThemeCardBackground())
                Section("Friends") {
                    if store.friends.isEmpty { Text("Search for a username and send a friend request.").foregroundStyle(.secondary) }
                    ForEach(store.friends) { profile in NavigationLink("@" + profile.username) { PlayerDetailView(player: profile) } }
                }.listRowBackground(ThemeCardBackground())
                Section {
                    NavigationLink { SpectatorFeedView() } label: { Label("Watch public games", systemImage: "eye") }
                }.listRowBackground(ThemeCardBackground())
            }
        }.modifier(AppSurface()).navigationTitle("Players")
        .task { if store.profile == nil { await store.connect() } else { await store.refreshContacts() } }
        .refreshable { await store.refreshContacts() }
    }
}

@MainActor private struct PlayerDetailView: View {
    let player: PlayerProfile
    @ObservedObject private var store = SocialStore.shared
    @State private var recipient: GKPlayer?
    @State private var inviting = false
    @State private var matchID: String?
    @State private var error: String?
    private var isFriend: Bool { store.friends.contains { $0.username == player.username } }
    var body: some View {
        List {
            Section {
                Text("@" + player.username).font(.title.bold())
                if store.profile?.username != player.username {
                    if isFriend { Label("Friends", systemImage: "person.2.fill") }
                    else if store.sent.contains(player.username) { Text("Friend request sent").foregroundStyle(.secondary) }
                    else { Button("Add friend", systemImage: "person.badge.plus") { Task { await store.sendRequest(to: player) } }.disabled(store.busy) }
                }
                if let error = error ?? store.error { Text(error).foregroundStyle(.red).font(.caption) }
            }.listRowBackground(ThemeCardBackground())
            Section {
                NavigationLink { SpectatorFeedView(publisher: player.username) } label: { Label("Watch their public games", systemImage: "eye") }
                if isFriend {
                    if !GKLocalPlayer.local.isAuthenticated {
                        NavigationLink("Connect Game Center to invite") { CorrespondenceView() }
                    } else if player.gameCenterID.isEmpty { Text("This player hasn't linked Game Center yet.").foregroundStyle(.secondary) }
                    else { Button("Invite to a game", systemImage: "paperplane") { invite() } }
                }
            }.listRowBackground(ThemeCardBackground())
        }.modifier(AppSurface()).navigationTitle("Player")
        .sheet(isPresented: $inviting) {
            if let recipient {
                CorrespondenceMatchmaker(found: { match in inviting = false; matchID = match.matchID }, cancel: { inviting = false }, failure: { failure in inviting = false; error = failure.localizedDescription }, recipients: [recipient])
            }
        }
        .navigationDestination(isPresented: Binding(get: { matchID != nil && !inviting }, set: { if !$0 { matchID = nil } })) {
            if let id = matchID { CorrespondenceBoardView(id: id) }
        }
    }
    private func invite() {
        GKPlayer.loadPlayers(forIdentifiers: [player.gameCenterID]) { players, failure in
            Task { @MainActor in
                if let failure { error = failure.localizedDescription }
                else if let found = players?.first { recipient = found; inviting = true }
                else { error = "This player is not available on Game Center." }
            }
        }
    }
}

@MainActor struct SpectatorFeedView: View {
    var publisher: String? = nil
    @ObservedObject private var store = SocialStore.shared
    var body: some View {
        List {
            Section {
                Text("Watch live games from NovaChess players.").font(.caption).foregroundStyle(.secondary)
                Button("Refresh games", systemImage: "arrow.clockwise") { Task { await store.browseGames(publisher: publisher) } }
                if store.busy { ProgressView() }
                if let error = store.error { Text(error).foregroundStyle(.red).font(.caption) }
            }.listRowBackground(ThemeCardBackground())
            if store.games.isEmpty { Text("No public boards right now.").foregroundStyle(.secondary) }
            ForEach(store.games) { game in
                NavigationLink { SpectatorBoardView(id: game.id) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(game.white + " · " + game.black).font(.headline)
                        Text(game.mode + (game.result == nil ? " · In progress" : " · Finished")).font(.caption).foregroundStyle(.secondary)
                        Text("Shared by @" + game.publisher).font(.caption2).foregroundStyle(.secondary)
                    }.padding(.vertical, 5)
                }.listRowBackground(ThemeCardBackground())
            }
        }.modifier(AppSurface()).navigationTitle(publisher.map { "@" + $0 } ?? "Watch games")
        .task { await store.browseGames(publisher: publisher) }
        .refreshable { await store.browseGames(publisher: publisher) }
    }
}

@MainActor private struct SpectatorBoardView: View {
    let id: String
    @State private var game: PublicGame?
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let game, let board = try? game.board() {
                    Text(game.white + " · " + game.black).font(.title2.bold())
                    BoardView(position: board.board, duckSquare: board.duckSquare)
                    TurnBadge(side: board.board.turn)
                    if let result = game.result { Text(result == "white" ? "White wins" : result == "black" ? "Black wins" : result == "draw" ? "Draw" : result).font(.headline) }
                    HStack { Text("Last synced"); Text(game.updated, style: .relative) }.font(.caption).foregroundStyle(.secondary)
                    DisclosureGroup("Moves") { Text(game.notation.joined(separator: " ")).font(.subheadline.monospaced()) }
                } else if error == nil { ProgressView("Loading public board…") }
                if let error { Text(error).foregroundStyle(.red) }
            }.padding()
        }.modifier(AppSurface()).navigationTitle("Spectating").navigationBarTitleDisplayMode(.inline)
        .task(id: id) {
            while !Task.isCancelled {
                do { game = try await SocialStore.shared.publicGame(id); error = nil }
                catch { self.error = error.localizedDescription; game = nil }
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
            }
        }
    }
}
