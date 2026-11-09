import SwiftUI

struct RepertoireView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var adding = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { RepertoireTrainerView() } label: { Label("Train repertoire", systemImage: "brain.head.profile") }.disabled(library.state.repertoire.isEmpty)
                    Button { adding = true } label: { Label("Add a line", systemImage: "plus.circle") }
                }
                Section("Your lines") {
                    if library.state.repertoire.isEmpty { Text("Add your first opening line or paste a PGN main line.").foregroundStyle(.secondary) }
                    ForEach(library.state.repertoire) { line in
                        NavigationLink { RepertoireLineDetail(line: line) } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(line.name).font(.headline)
                                Text("\(line.side.title) repertoire · \(line.moves.count) half-moves · \(line.trained) training sessions").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }.onDelete { offsets in library.state.repertoire.remove(atOffsets: offsets) }
                }
            }.scrollDismissesKeyboard(.interactively).modifier(AppSurface()).navigationTitle("My Repertoire").toolbar { SettingsButton() }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { EditButton() } }
            .sheet(isPresented: $adding) { RepertoireLineEditor() }
        }
    }
}

private struct RepertoireLineEditor: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var side = Side.white
    @State private var pgn = ""
    @State private var board = Position.initial
    @State private var moves: [String] = []
    @State private var notation: [String] = []
    @State private var message: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Line name", text: $name).textFieldStyle(.roundedBorder)
                    Picker("I play", selection: $side) { Text("White").tag(Side.white); Text("Black").tag(Side.black) }.pickerStyle(.segmented)
                    MoveBoard(position: board) { move in
                        do { notation.append(try board.san(for: move)); moves.append(move.uci); board = try board.playing(move) }
                        catch { message = error.localizedDescription }
                    }
                    Text(notation.isEmpty ? "Play both sides to enter your line." : notation.joined(separator: " ")).font(.subheadline.monospaced())
                    HStack { Button("Undo") { undo() }.disabled(moves.isEmpty); Spacer(); Button("Clear board line") { board = .initial; moves = []; notation = [] } }
                    DisclosureGroup("Paste moves or a PGN main line") {
                        TextEditor(text: $pgn).frame(minHeight: 120).font(.body.monospaced()).overlay(RoundedRectangle(cornerRadius: 8).stroke(.gray.opacity(0.3)))
                        Text("For example: 1. e4 e5 2. Nf3 Nc6 3. Bb5. Comments and side variations are ignored; add separate lines for branches.").font(.caption).foregroundStyle(.secondary)
                        Button("Import main line") { importPGN() }
                    }
                    if let message { Text(message).foregroundStyle(.red).font(.footnote) }
                }.padding()
            }.scrollDismissesKeyboard(.interactively).navigationTitle("New repertoire line")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || moves.isEmpty) }
            }
        }
    }
    private func undo() {
        moves.removeLast(); board = .initial; notation = []
        for uci in moves { if let move = board.legalMoves().first(where: { $0.uci == uci }) { notation.append((try? board.san(for: move)) ?? ""); try? board.apply(uci: uci) } }
    }
    private func importPGN() {
        do {
            let game = try PGNGame.parse(pgn)
            guard game.tags["FEN"] == nil else { throw ChessError.invalid("This board-entry editor starts from the initial position. Import a main line without a custom FEN.") }
            guard !game.moves.isEmpty else { throw ChessError.invalid("No moves were found.") }
            board = .initial; moves = game.moves; notation = []
            for uci in moves { let move = try board.move(forSAN: uci); notation.append(try board.san(for: move)); try board.apply(uci: uci) }
            if name.isEmpty { name = game.tags["Opening"] ?? game.tags["Event"] ?? "Imported line" }
            message = nil
        } catch { message = error.localizedDescription }
    }
    private func save() {
        let line = RepertoireLine(name: name, side: side, moves: moves)
        do { _ = try line.validated(); library.state.repertoire.append(line); dismiss() }
        catch { message = error.localizedDescription }
    }
}

private struct RepertoireLineDetail: View {
    @EnvironmentObject private var library: LibraryStore
    var line: RepertoireLine
    @State private var board = Position.initial
    @State private var cursor = 0
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BoardView(position: board, flipped: line.side == .black)
                Text("You play \(line.side.title)").font(.headline)
                if let moves = try? line.validated() { Text(moves.map(\.san).joined(separator: " ")).font(.body.monospaced()) }
                HStack { Button("Previous") { show(cursor - 1) }.disabled(cursor == 0); Spacer(); Text("\(cursor)/\(line.moves.count)"); Spacer(); Button("Next") { show(cursor + 1) }.disabled(cursor == line.moves.count) }
                NavigationLink("Train this line") { RepertoireTrainerView(preferred: line.id) }.buttonStyle(.borderedProminent)
            }.padding()
        }.scrollDismissesKeyboard(.interactively).navigationTitle(line.name).onAppear { show(cursor) }
    }
    private func show(_ index: Int) {
        guard var position = try? Position(fen: line.startingFEN) else { return }
        for move in line.moves.prefix(max(0, index)) { try? position.apply(uci: move) }
        cursor = max(0, min(index, line.moves.count)); board = position
    }
}

struct RepertoireTrainerView: View {
    @ObservedObject private var engine = EngineController.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    private var principal: EngineLine? { engine.analyzedFEN == board.fen ? engine.lines.first { $0.rank == 1 } : nil }
    @EnvironmentObject private var library: LibraryStore
    var preferred: UUID? = nil
    @State private var line: RepertoireLine?
    @State private var board = Position.initial
    @State private var cursor = 0
    @State private var message = ""
    @State private var failed = false
    @State private var finished = false
    @State private var replyTask: Task<Void, Never>?
    @State private var generation = UUID()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let line {
                    Text(line.name).font(.title2.bold())
                    BoardEvaluationLayout {
                        MoveBoard(position: board, enabled: !finished && board.turn == line.side, flipped: line.side == .black, onMove: attempt)
                        EvaluationBar(whiteFraction: EvaluationScale.whiteFraction(centipawns: principal?.centipawns, mate: principal?.mate))
                    }
                    Text(principal?.evaluation ?? "—").font(.title2.bold().monospacedDigit()).accessibilityLabel("Evaluation: \(principal?.evaluation ?? "pending")")
                    Text(finished ? "Line completed" : board.turn == line.side ? "Your move: follow your repertoire" : "Playing the opponent's reply…").font(.headline)
                    if !message.isEmpty { Text(message).foregroundStyle(.secondary) }
                    HStack { Button("Show move") { hint() }.disabled(finished || board.turn != line.side); Spacer(); Button(preferred == nil ? "Next line" : "Restart line") { start() }.buttonStyle(.borderedProminent) }
                } else { ContentUnavailableView("Add a repertoire line first", systemImage: "books.vertical") }
            }.padding()
        }.scrollDismissesKeyboard(.interactively).navigationTitle("Train repertoire")
        .onAppear { visible = true; if line == nil { start() } else { reply() }; if scenePhase == .active { engine.analyze(board) } }
        .onChange(of: board.fen) { _, _ in if visible && scenePhase == .active { engine.analyze(board) } }
        .onChange(of: scenePhase) { _, phase in if visible && phase == .active { engine.analyze(board) } else if visible { engine.stopAnalysis() } }
        .onDisappear { visible = false; replyTask?.cancel(); engine.stopAnalysis() }
    }
    private func start() {
        replyTask?.cancel(); generation = UUID()
        let lines = library.state.repertoire.sorted { $0.due < $1.due }
        let selected = preferred.flatMap { id in lines.first { $0.id == id } } ?? lines.first(where: { $0.id != line?.id }) ?? lines.first
        guard let selected, let position = try? Position(fen: selected.startingFEN) else { line = nil; return }
        line = selected; board = position; cursor = 0; message = ""; failed = false; finished = false; reply()
    }
    private func attempt(_ move: ChessMove) {
        let matches = RepertoireTraining.choices(at: board, in: library.state.repertoire).filter { $0.move == move.uci }
        guard let match = matches.first(where: { $0.line.id == line?.id && $0.index == cursor }) ?? matches.first else { failed = true; message = "That move is not in your saved repertoire here. Try again."; return }
        do {
            board = try board.playing(move); line = match.line; cursor = match.index + 1; message = "Correct."; finish(); reply()
        } catch { message = error.localizedDescription }
    }
    private func finish() {
        guard let line, cursor >= line.moves.count, !finished else { return }
        finished = true; message = failed ? "Completed with help. This line stays due for review." : "Well played. This line will return for spaced review."
        if let index = library.state.repertoire.firstIndex(where: { $0.id == line.id }) { library.state.repertoire[index].record(correct: !failed) }
    }
    private func reply() {
        guard let line, !finished, cursor < line.moves.count, board.turn != line.side else { finish(); return }
        replyTask?.cancel(); let token = generation
        replyTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(400))
                guard generation == token, let move = board.legalMoves().first(where: { $0.uci == line.moves[cursor] }) else { return }
                board = try board.playing(move); cursor += 1; finish()
            } catch is CancellationError {} catch { message = error.localizedDescription }
        }
    }
    private func hint() {
        let choices = RepertoireTraining.choices(at: board, in: library.state.repertoire)
        failed = true
        message = "Try " + choices.compactMap { choice in board.legalMoves().first(where: { $0.uci == choice.move }).flatMap { try? board.san(for: $0) } }.joined(separator: " or ")
    }
}
