import SwiftUI

@MainActor final class OpeningExplorerModel: ObservableObject {
    enum Filter: String, CaseIterable, Sendable { case white = "White", black = "Black" }
    @Published var site: PublicChessSite = .chesscom
    @Published var username = ""
    @Published var limit = 1000
    @Published var filter = Filter.white
    @Published var tree = OpeningTree()
    @Published var status = ""
    @Published var error: String?
    @Published var busy = false
    @Published private(set) var profileLabel = ""
    private var games: [OpeningGame] = []
    private var importedUsername = ""
    private var task: Task<Void, Never>?
    func load() {
        task?.cancel(); busy = true; error = nil
        let site = site, user = username.trimmingCharacters(in: .whitespacesAndNewlines), limit = limit
        task = Task {
            do {
                let imported = try await PublicGameService().load(site: site, username: user, limit: limit) { text in
                    Task { @MainActor in self.status = text }
                }
                try Task.checkCancellation()
                let built = try await buildTree(games: imported.games, username: user)
                games = imported.games; importedUsername = user; tree = built; profileLabel = "\(user) · \(site.title)"
                status = "\(tree.gameCount) games in this color filter · \(imported.fetched) fetched · \(imported.skipped) skipped"
            } catch is CancellationError { status = "Import canceled." }
            catch { self.error = Self.importMessage(error); status = tree.gameCount == 0 ? "Could not load this profile." : "Import did not finish. Previous results are retained." }
            busy = false
        }
    }
    func refilter() {
        guard !games.isEmpty else { return }
        task?.cancel(); busy = true
        task = Task {
            do { tree = try await buildTree(); status = "\(tree.gameCount) games in this color filter" }
            catch is CancellationError {} catch { self.error = error.localizedDescription }
            busy = false
        }
    }
    private func buildTree(games incoming: [OpeningGame]? = nil, username: String? = nil) async throws -> OpeningTree {
        let games = incoming ?? self.games, filter = self.filter, user = (username ?? self.importedUsername).lowercased()
        status = "Building the opening tree…"
        let worker = Task.detached(priority: .userInitiated) { () throws -> OpeningTree in
            var tree = OpeningTree()
            for game in games {
                try Task.checkCancellation()
                if filter == .white && game.white.lowercased() != user { continue }
                if filter == .black && game.black.lowercased() != user { continue }
                do { try tree.add(game) } catch is CancellationError { throw CancellationError() } catch { continue }
            }
            return tree
        }
        let result = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
        try Task.checkCancellation(); return result
    }
    private static func importMessage(_ error: Error) -> String {
        if case DecodingError.keyNotFound(let key, _) = error { return "The site returned an incomplete response (missing \(key.stringValue)). Please retry in a moment." }
        if error is DecodingError { return "The site returned an unexpected game export. Please retry in a moment." }
        return error.localizedDescription
    }
    func cancel() { task?.cancel() }
}

struct OpeningExplorerView: View {
    @EnvironmentObject private var library: LibraryStore
    @StateObject private var model = OpeningExplorerModel()
    @State private var history = [Position.initial]
    @State private var notation: [String] = []
    private var position: Position { history.last ?? .initial }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Explore a player's public games.").font(.subheadline).foregroundStyle(.secondary)
                    Picker("Site", selection: $model.site) { ForEach(PublicChessSite.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                    TextField("Public username", text: $model.username).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                    Button { history = [.initial]; notation = []; model.load() } label: { Label("Load opening tree", systemImage: "arrow.down.circle").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).disabled(model.busy || !PublicGames.validUsername(model.username))
                    if model.busy { HStack { ProgressView(); Text(model.status).font(.caption); Spacer(); Button("Cancel") { model.cancel() } } }
                    else if !model.status.isEmpty { Text(model.status).font(.caption).foregroundStyle(.secondary) }
                    if let error = model.error { Text(error).foregroundStyle(.red).font(.footnote) }
                    Picker("Player color", selection: $model.filter) { ForEach(OpeningExplorerModel.Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).disabled(model.busy)
                    if !model.profileLabel.isEmpty { Text(model.profileLabel).font(.headline) }
                    MoveBoard(position: position, enabled: !model.busy, onMove: play)
                    if let name = library.openingName(at: position) { Text(name).font(.headline) }
                    if !notation.isEmpty { Text(notation.joined(separator: " ")).font(.footnote.monospaced()) }
                    HStack { Button("Back", systemImage: "chevron.left") { history.removeLast(); notation.removeLast() }.disabled(history.count == 1); Spacer(); Button("Starting position") { history = [.initial]; notation = [] } }
                    let branches = model.tree.branches(at: position)
                    if branches.isEmpty { ContentUnavailableView(model.profileLabel.isEmpty ? "Load a profile to begin" : "No imported games here", systemImage: "tree", description: Text("Standard public games only. The tree covers the first 40 half-moves of the requested recent-game sample.")) }
                    ForEach(branches) { branch in
                        Button { if let move = position.legalMoves().first(where: { $0.uci == branch.uci }) { play(move) } } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                HStack { Text(branch.san).font(.headline.monospaced()); Spacer(); Text("\(branch.counts.games) games").foregroundStyle(.secondary) }
                                OpeningResultBar(counts: branch.counts)
                            }.padding(.vertical, 8).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Divider()
                    }
                }.padding()
            }.scrollDismissesKeyboard(.interactively).modifier(AppSurface()).navigationTitle("Opening explorer").toolbar { SettingsButton() }
            .onChange(of: model.filter) { _, _ in history = [.initial]; notation = []; model.refilter() }
        }
    }
    private func play(_ move: ChessMove) {
        guard let san = try? position.san(for: move), let next = try? position.playing(move) else { return }
        notation.append(san); history.append(next)
    }
}

private struct OpeningResultBar: View {
    var counts: OpeningCounts
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let total = Double(max(1, counts.games))
                HStack(spacing: 0) {
                    Color(white: 0.94).frame(width: geometry.size.width * Double(counts.whiteWins) / total)
                    Color.gray.frame(width: geometry.size.width * Double(counts.draws) / total)
                    Color(white: 0.15)
                }.clipShape(Capsule()).overlay(Capsule().stroke(.gray.opacity(0.4), lineWidth: 0.5))
            }.frame(height: 10)
            HStack { Text("White \(counts.whiteWins)"); Spacer(); Text("Draw \(counts.draws)"); Spacer(); Text("Black \(counts.blackWins)") }.font(.caption2).foregroundStyle(.secondary)
        }
    }
}
