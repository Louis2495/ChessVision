import SwiftUI

@MainActor final class ComputerGameModel: ObservableObject {
    @Published var mode = GameMode.normal
    @Published var human = Side.white
    @Published var pawnWarsKings = true
    @Published var ratingText = "1000"
    @Published var requestedOpening: OpeningLine?
    @Published private(set) var game: SavedComputerGame?
    @Published private(set) var snapshot: VariantSnapshot?
    @Published private(set) var busy = false
    @Published private(set) var computerPiecePreview: Position?
    @Published var error: String?
    private weak var library: LibraryStore?
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var visible = false
    var opening: OpeningLine? { game?.openingID.flatMap { id in library?.openings.first { $0.id == id } } }
    var bookMatches: Bool {
        guard let game, let opening else { return false }
        return game.moves.count <= opening.moves.count && Array(opening.moves.prefix(game.moves.count)) == game.moves
    }
    func activate(_ library: LibraryStore) {
        self.library = library; visible = true
        if game == nil { game = library.state.computer }
        if game != nil && game?.id == nil { game?.id = UUID(); library.state.computer = game }
        if game != nil { run() }
    }
    func pause() { computerPiecePreview = nil; visible = false; task?.cancel(); generation = UUID(); busy = false }
    func start() -> Bool {
        guard mode != .bughouse else { error = "Open Bughouse setup to start a two-board match."; return false }
        guard let target = Int(ratingText), (1...10000).contains(target) else { error = "Enter a target rating from 1 to 10000. Ratings above the supported range use full strength."; return false }
        game = SavedComputerGame(mode: mode, human: human, targetRating: target, openingID: mode == .normal ? requestedOpening?.id : nil)
        game?.pawnWarsKings = pawnWarsKings
        if mode == .chess960 { game?.chess960Index = Int.random(in: 0..<960) }
        computerPiecePreview = nil; snapshot = nil; error = nil; library?.state.computer = game
        run(); return true
    }
    private func run() {
        guard visible, let game else { return }
        task?.cancel(); generation = UUID(); let token = generation
        computerPiecePreview = nil; busy = true; error = nil
        task = Task {
            do {
                try await EngineController.shared.prepareVariant(game.variant)
                try Task.checkCancellation(); guard token == generation else { return }
                var state = try VariantRules.snapshot(variant: game.variant, history: game.moves)
                if let resigned = game.resigned { state.status = resigned == .white ? "black" : "white" }
                snapshot = state
                archiveIfFinished()
                if !state.finished && state.board.turn != game.human {
                    let move: String
                    if let opening, bookMatches, game.moves.count < opening.moves.count { move = opening.moves[game.moves.count] }
                    else { move = try await EngineController.shared.computerMove(variant: game.variant, history: game.moves, rating: game.targetRating, side: state.board.turn) }
                    try Task.checkCancellation(); guard token == generation else { return }
                    if game.mode == .duck, let legal = state.moves.first(where: { $0.uci == move }), legal.duckDestination != nil {
                        computerPiecePreview = legal.piecePosition(from: state.board)
                        try await Task.sleep(for: .milliseconds(500))
                        try Task.checkCancellation(); guard token == generation else { return }
                    }
                    try apply(move)
                }
            } catch is CancellationError {} catch { if token == generation { self.error = error.localizedDescription } }
            if token == generation { computerPiecePreview = nil; busy = false }
        }
    }
    func play(_ move: VariantMove) {
        guard !busy, let game, let snapshot, !snapshot.finished, snapshot.board.turn == game.human else { return }
        do { try apply(move.uci); run() } catch { self.error = error.localizedDescription }
    }
    @discardableResult func enter(_ text: String) -> Bool {
        guard !busy, let snapshot, let game, !snapshot.finished, snapshot.board.turn == game.human else { return false }
        do { let move = try snapshot.move(named: text); play(move); return true }
        catch { self.error = error.localizedDescription; return false }
    }
    private func apply(_ uci: String) throws {
        guard var current = game, let move = snapshot?.moves.first(where: { $0.uci == uci }) else { throw ChessError.invalid("The engine returned a move that is not legal in this position.") }
        current.moves.append(uci); current.notation.append(move.san)
        let next = try VariantRules.snapshot(variant: current.variant, history: current.moves)
        game = current; snapshot = next; library?.state.computer = current
        archiveIfFinished()
    }
    func undo() {
        guard var game, game.moves.count >= 2 else { return }
        if snapshot?.finished == true { game.id = UUID() }
        task?.cancel(); game.moves.removeLast(2)
        game.notation = Array(game.notation.prefix(game.moves.count)); game.resigned = nil
        self.game = game; library?.state.computer = game; run()
    }
    func resign() {
        guard var game, snapshot?.finished == false else { return }
        task?.cancel(); generation = UUID(); computerPiecePreview = nil; busy = false
        game.resigned = game.human; self.game = game; library?.state.computer = game
        snapshot?.status = game.human == .white ? "black" : "white"
        archiveIfFinished()
    }
    private func archiveIfFinished() {
        guard let game, let snapshot, snapshot.finished else { return }
        library?.recordCompleted(game, result: snapshot.status)
    }

}

private struct CompletedReviewRoute: Identifiable { let id: UUID }

struct ComputerPlayView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = ComputerGameModel()
    @State private var settingUp = false
    @State private var historyPresented = false
    @State private var reviewRoute: CompletedReviewRoute?
    @State private var lastReviewedGame: UUID?
    @State private var reviewPresentationTask: Task<Void, Never>?
    @State private var visible = false
    @State private var textMove = ""
    @State private var selected: Int?
    @State private var selectedDrop: Character?
    @State private var promotions: [VariantMove] = []
    @State private var resigning = false
    @State private var duckChoices: [VariantMove] = []
    var body: some View {
        NavigationStack {
            playContent
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { reviewPresentationTask?.cancel(); if model.snapshot?.finished == true { lastReviewedGame = model.game?.id }; model.pause(); historyPresented = true } label: { Image(systemName: "clock.arrow.circlepath") }.accessibilityLabel("Game history")
                }
                ToolbarItem(placement: .topBarTrailing) { if model.game != nil { Button("New game") { settingUp = true } } }
            }
            .sheet(isPresented: $historyPresented, onDismiss: {
                if visible && scenePhase == .active { model.activate(library) }
            }) { NavigationStack { GameHistoryView() } }
            .sheet(item: $reviewRoute) { route in
                NavigationStack {
                    GameReviewView(id: route.id).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { reviewRoute = nil } } }
                }
            }
            .onChange(of: model.snapshot?.result) { _, _ in scheduleReview() }
            .onChange(of: settingUp) { _, showing in if !showing { scheduleReview() } }
            .sheet(isPresented: $settingUp) {
                NavigationStack { ScrollView { GameSetupForm(model: model) { if model.start() { settingUp = false } }.padding() }.scrollDismissesKeyboard(.interactively).modifier(AppSurface()).navigationTitle("New game").toolbar { Button("Cancel") { settingUp = false } } }
            }
            .confirmationDialog("Resign this game?", isPresented: $resigning, titleVisibility: .visible) { Button("Resign", role: .destructive) { model.resign() } }
            .sheet(isPresented: Binding(get: { !promotions.isEmpty }, set: { if !$0 { promotions = [] } })) {
                PromotionPicker(side: model.snapshot?.board.turn ?? .white, kinds: promotions.compactMap(\.promotion)) { kind in
                    if let move = promotions.first(where: { $0.promotion == kind }) { choose(move) }
                    promotions = []; selected = nil
                }
            }
            .onAppear { visible = true; model.activate(library); scheduleReview() }
            .onDisappear { visible = false; reviewPresentationTask?.cancel(); model.pause() }
            .onChange(of: scenePhase) { _, phase in
                guard visible else { return }
                if phase == .active && !historyPresented && reviewRoute == nil { model.activate(library); scheduleReview() }
                else { reviewPresentationTask?.cancel(); model.pause() }
            }
            .onChange(of: model.snapshot?.fen) { _, _ in selected = nil; selectedDrop = nil; promotions = []; duckChoices = [] }
        }
    }
    private var playContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let game = model.game, let snapshot = model.snapshot {
                    HStack { Text(game.mode.title).font(.headline); Spacer(); Text("Target ≈ \(game.targetRating)").font(.subheadline).foregroundStyle(.secondary) }
                    HStack { Text("You play \(game.human.title)"); Spacer(); TurnBadge(side: snapshot.board.turn) }
                    gameBoard(snapshot, game: game)
                    if game.mode == .crazyhouse { pockets(snapshot, human: game.human) }
                    if let checks = snapshot.checksRemaining {
                        let values = checks.split(separator: "+")
                        Text("Checks remaining · White \(values.first ?? "") · Black \(values.last ?? "")").font(.caption.monospaced())
                    }
                    if let result = snapshot.result, game.mode == .blindText { resultButton(result) }
                    else if model.busy { ProgressView(model.computerPiecePreview == nil ? "Computer is thinking…" : "Placing the duck…") }
                    else if !snapshot.finished { Text(!duckChoices.isEmpty ? "Place the duck" : snapshot.inCheck ? "Your king is in check." : "Your move").font(.headline) }
                    if !duckChoices.isEmpty { Button("Cancel piece move") { duckChoices = [] } }
                    if !snapshot.finished && (game.mode == .blindBoard || game.mode == .blindText) {
                        HStack {
                            TextField(game.mode == .crazyhouse ? "Move, e.g. Nf3 or N@f7" : "Move, e.g. Nf3", text: $textMove).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder).onSubmit(enter)
                            Button("Play", action: enter).buttonStyle(.borderedProminent).disabled(model.busy || snapshot.board.turn != game.human || textMove.isEmpty)
                        }
                    }
                    if let opening = model.opening { Text("Requested: \(opening.name)\(model.bookMatches ? "" : " · game has left this line")").font(.caption).foregroundStyle(.secondary) }
                    if snapshot.finished, let id = game.id {
                        Button("Review game", systemImage: "list.bullet.clipboard") { lastReviewedGame = id; reviewRoute = CompletedReviewRoute(id: id) }.buttonStyle(.borderedProminent)
                    }
                    if let error = model.error { Text(error).foregroundStyle(.red).font(.footnote) }
                    if game.mode == .blindBoard || game.mode == .blindText {
                        if snapshot.board.turn == game.human, let last = game.notation.last { Text("Computer: \(last)").font(.headline.monospaced()) }
                    } else if game.mode != .fogOfWar { GameMoveTable(moves: game.notation) }
                    HStack { Button("Take back two plies") { model.undo() }.disabled(game.moves.count < 2); Spacer(); Button("Resign", role: .destructive) { resigning = true }.disabled(snapshot.finished) }
                } else if model.busy { ProgressView("Preparing the game…").frame(maxWidth: .infinity).padding(.vertical, 40) }
                else { GameSetupForm(model: model, onStart: { _ = model.start() }) }
            }.padding()
        }.scrollDismissesKeyboard(.interactively).modifier(AppSurface()).navigationTitle("Play computer").toolbar { SettingsButton() }
    }
    private func scheduleReview() {
        reviewPresentationTask?.cancel()
        guard model.snapshot?.finished == true else { return }
        reviewPresentationTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
            guard !Task.isCancelled else { return }
            presentReviewIfNeeded()
        }
    }
    private func presentReviewIfNeeded() {
        guard visible, scenePhase == .active, !settingUp, !historyPresented, promotions.isEmpty, reviewRoute == nil,
              model.snapshot?.finished == true, let id = model.game?.id,
              lastReviewedGame != id, library.state.history.contains(where: { $0.id == id }) else { return }
        lastReviewedGame = id; reviewRoute = CompletedReviewRoute(id: id)
    }
    @ViewBuilder private func gameBoard(_ snapshot: VariantSnapshot, game: SavedComputerGame) -> some View {
        if game.mode != .blindText {
            let hidden = game.mode == .blindBoard
            BoardView(position: displayedBoard(snapshot, game: game), selected: hidden ? nil : selected,
                      legalTargets: hidden ? [] : targets(snapshot), flipped: game.human == .black, hidePieces: hidden, obscured: game.mode == .fogOfWar && !snapshot.finished ? FogVisibility.hidden(in: snapshot.board, for: game.human) : [], duckSquare: snapshot.duckSquare, onTap: tap)
                .accessibilityHidden(snapshot.finished)
                .overlay {
                    if let result = snapshot.result {
                        ZStack {
                            Color.black.opacity(0.18).clipShape(RoundedRectangle(cornerRadius: 10))
                            resultButton(result).padding(24)
                        }
                    }
                }
        } else if !snapshot.finished {
            Text("Enter your move").font(.title2.bold()).padding(.vertical, 24)
        }
    }
    private func choose(_ move: VariantMove) {
        guard move.duckDestination != nil, let snapshot = model.snapshot else { model.play(move); return }
        duckChoices = snapshot.moves.filter { $0.pieceMove == move.pieceMove }; selected = nil
    }
    private func displayedBoard(_ snapshot: VariantSnapshot, game: SavedComputerGame) -> Position {
        if let preview = model.computerPiecePreview { return preview }
        if let move = duckChoices.first { return move.piecePosition(from: snapshot.board) }
        return snapshot.board
    }
    private func resultButton(_ result: String) -> some View {
        Button { settingUp = true } label: {
            Text(result).font(.largeTitle.bold()).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 88).padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain).accessibilityHint("Start a new game")
            .accessibilityIdentifier("game-result")
    }

    private func enter() { if model.enter(textMove) { textMove = "" } }
    private func targets(_ snapshot: VariantSnapshot) -> Set<Int> {
        if !duckChoices.isEmpty { return Set(duckChoices.compactMap(\.duckDestination)) }
        guard selectedDrop != nil || selected != nil else { return [] }
        let moves = snapshot.moves.filter { move in selectedDrop != nil ? move.drop == selectedDrop : move.from == selected }
        return Set(moves.compactMap(\.to))
    }
    private func tap(_ index: Int) {
        guard let snapshot = model.snapshot, let game = model.game, !model.busy, !snapshot.finished, snapshot.board.turn == game.human else { return }
        if !duckChoices.isEmpty { if let move = duckChoices.first(where: { $0.duckDestination == index }) { duckChoices = []; model.play(move) }; return }
        if selected == index { selected = nil; selectedDrop = nil; return }
        let choices = snapshot.moves.filter { move in move.to == index && (selectedDrop != nil ? move.drop == selectedDrop : selected != nil && move.from == selected) }
        let distinct = Dictionary(grouping: choices, by: \.pieceMove).values.compactMap(\.first)
        if distinct.count > 1 { promotions = distinct; return }
        if let move = choices.first { choose(move); return }
        selectedDrop = nil
        selected = snapshot.board.squares[index]?.side == game.human ? index : nil
    }
    @ViewBuilder private func pockets(_ snapshot: VariantSnapshot, human: Side) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Side.allCases, id: \.self) { side in
                HStack {
                    Text("\(side.title) pocket").font(.caption).frame(width: 80, alignment: .leading)
                    ForEach(Array("PNBRQ"), id: \.self) { kind in
                        let symbol = side == .white ? kind : Character(kind.lowercased())
                        let count = snapshot.pockets.filter { $0.symbol == symbol }.count
                        if count > 0 {
                            Button { selected = nil; selectedDrop = kind } label: {
                                VStack(spacing: 1) { PieceView(piece: Piece(symbol)).frame(width: 31, height: 31); Text(String(count)).font(.caption2) }
                                    .padding(3).background(selectedDrop == kind && side == human ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                            }.buttonStyle(.plain).disabled(side != human || snapshot.board.turn != human || model.busy || snapshot.finished)
                        }
                    }
                    Spacer()
                }
            }
        }
    }
}

private struct GameSetupForm: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var bughousePresented = false
    @ObservedObject var model: ComputerGameModel
    var onStart: () -> Void
    @State private var choosingOpening = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Choose your challenge").font(.title2.bold())
            Picker("Game style", selection: $model.mode) { ForEach(GameMode.allCases) { Text($0.title).tag($0) } }.accessibilityIdentifier("game-style")
            if model.mode != .blindBoard && model.mode != .blindText { Text(model.mode.explanation).font(.subheadline).foregroundStyle(.secondary) }
            if model.mode == .bughouse {
                Button("Set up Bughouse", systemImage: "rectangle.split.2x1") { model.pause(); bughousePresented = true }.buttonStyle(.borderedProminent)
            } else {
            if model.mode == .pawnWars { Toggle("Include kings", isOn: $model.pawnWarsKings) }
            Picker("Your color", selection: $model.human) { Text("White").tag(Side.white); Text("Black").tag(Side.black) }.pickerStyle(.segmented)
            Text("Computer strength · estimated Elo").font(.caption).foregroundStyle(.secondary)
            TextField("Requested rating", text: $model.ratingText).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
            Slider(value: Binding(get: { min(3500, max(100, Double(model.ratingText) ?? 1000)) }, set: { model.ratingText = String(Int($0)) }), in: 100...3500, step: 50)
                .accessibilityLabel("Computer rating")
            if model.mode == .normal {
                Button { choosingOpening = true } label: { Label(model.requestedOpening?.name ?? "Request an opening", systemImage: "books.vertical") }
                if model.requestedOpening != nil { Button("No opening request") { model.requestedOpening = nil } }
                Text("The computer follows the requested line while your moves match it. You are free to deviate.").font(.caption).foregroundStyle(.secondary)
            }
            Button(action: onStart) { Label("Start game", systemImage: "play.fill").frame(maxWidth: .infinity).padding(7) }.buttonStyle(.borderedProminent)
            }
            if let error = model.error { Text(error).foregroundStyle(.red) }
        }
        .fullScreenCover(isPresented: $bughousePresented, onDismiss: { model.activate(library) }) { BughousePlayView() }
        .sheet(isPresented: $choosingOpening) { OpeningPicker { model.requestedOpening = $0 } }
    }
}
private struct OpeningPicker: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    var onSelect: (OpeningLine) -> Void
    @State private var search = ""
    private var matches: [OpeningLine] { Array(library.openings.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.eco.localizedCaseInsensitiveContains(search) }.prefix(150)) }
    var body: some View {
        NavigationStack {
            List(matches) { opening in
                Button { onSelect(opening); dismiss() } label: { VStack(alignment: .leading) { Text(opening.name); Text(opening.eco).font(.caption).foregroundStyle(.secondary) } }
            }.searchable(text: $search, prompt: "Sicilian, London, C42…").modifier(AppSurface()).navigationTitle("Request an opening").toolbar { Button("Cancel") { dismiss() } }
        }
    }
}
private struct GameMoveTable: View {
    var moves: [String]
    var body: some View {
        VStack(spacing: 8) {
            HStack { Text("#").frame(width: 25); Text("White").frame(maxWidth: .infinity, alignment: .leading); Text("Black").frame(maxWidth: .infinity, alignment: .leading) }.font(.caption.bold()).foregroundStyle(.secondary)
            ForEach(Array(stride(from: 0, to: moves.count, by: 2)), id: \.self) { index in
                HStack { Text(String(index / 2 + 1)).frame(width: 25); Text(moves[index]).frame(maxWidth: .infinity, alignment: .leading); Text(index + 1 < moves.count ? moves[index + 1] : "—").frame(maxWidth: .infinity, alignment: .leading) }.font(.subheadline.monospaced())
            }
        }
    }
}
