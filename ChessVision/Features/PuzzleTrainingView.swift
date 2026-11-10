import SwiftUI

struct PuzzleTrainingView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var puzzle: ChessPuzzle?
    @State private var board = Position.initial
    @State private var learner = Side.white
    @State private var cursor = 1
    @State private var graded = false
    @State private var finished = false
    @State private var message = ""
    @State private var played: [String] = []
    @State private var replyTask: Task<Void, Never>?
    @State private var generation = UUID()
    var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading) { Text("Your training estimate").font(.caption).foregroundStyle(.secondary); Text(String(Int(library.state.puzzle.rating.rounded()))).font(.largeTitle.bold().monospacedDigit()) }
                        Spacer()
                        VStack(alignment: .trailing) { Text("\(library.state.puzzle.solved) solved").font(.headline); Text("\(library.puzzles.count.formatted()) offline puzzles").font(.caption).foregroundStyle(.secondary) }
                    }
                    if let puzzle {
                        HStack { Text("Difficulty ≈ \(puzzle.estimatedRating)").font(.headline); Spacer(); TurnBadge(side: board.turn) }
                        MoveBoard(position: board, enabled: !finished && board.turn == learner, flipped: learner == .black, onMove: attempt)
                        Text(finished ? "Position completed" : "\(learner.title) to move · find the best continuation").font(.headline)
                        if !message.isEmpty { Text(message).foregroundStyle(finished ? Color.green : Color.secondary) }
                        if !played.isEmpty { Text(played.joined(separator: "  ")).font(.subheadline.monospaced()) }
                        HStack {
                            Button { hint() } label: { Label("Hint", systemImage: "lightbulb").foregroundStyle(Color.yellow).frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(.bordered).controlSize(.large).disabled(finished || board.turn != learner)
                            Button { if !finished { grade(false) }; nextPuzzle() } label: {
                                Label(finished ? "Next puzzle" : "Skip puzzle", systemImage: "arrow.right").frame(maxWidth: .infinity, minHeight: 44)
                            }.buttonStyle(.borderedProminent).controlSize(.large)
                        }
                    } else { ContentUnavailableView("Puzzle library unavailable", systemImage: "puzzlepiece", description: Text("Install the complete build to use the bundled puzzle library.")) }
                }.padding()
            }.modifier(AppSurface()).navigationTitle("Puzzles").toolbar { SettingsButton() }
            .onAppear { if puzzle == nil { nextPuzzle() } else { replyIfNeeded() } }
            .onDisappear { replyTask?.cancel() }
    }
    private func nextPuzzle() {
        replyTask?.cancel(); generation = UUID()
        guard let next = library.state.puzzle.next(in: library.puzzles, excluding: puzzle?.id) else { return }
        do {
            board = try next.startingPosition(); learner = board.turn; puzzle = next
            cursor = 1; graded = false; finished = false; message = ""; played = []
        } catch { message = error.localizedDescription; puzzle = nil }
    }
    private func grade(_ correct: Bool) {
        guard !graded, let puzzle else { return }
        library.state.puzzle.record(puzzle, correct: correct); graded = true
    }
    private func attempt(_ move: ChessMove) {
        guard let puzzle, cursor < puzzle.moves.count else { return }
        guard puzzle.moves[cursor] == move.uci else {
            if let next = try? board.playing(move), next.isInCheck && next.legalMoves().isEmpty {
                played.append((try? board.san(for: move)) ?? "Mate")
                board = next; let assisted = graded; grade(true); finished = true
                message = assisted ? "Checkmate found. Your earlier hint or mistake is still reflected in the rating." : "Checkmate — solved!"
                return
            }
            grade(false); message = "That is not the intended move. Try again or use a hint."; return
        }
        do {
            played.append(try board.san(for: move)); board = try board.playing(move); cursor += 1
            message = "Correct."; finishIfNeeded(); replyIfNeeded()
        } catch { message = error.localizedDescription }
    }
    private func finishIfNeeded() {
        if let puzzle, cursor >= puzzle.moves.count {
            let assisted = graded
            grade(true); finished = true
            message = assisted ? "Completed. Your next puzzle will reflect the earlier mistake or hint." : "Solved without help. Your difficulty has increased."
        }
    }
    private func replyIfNeeded() {
        guard let puzzle, !finished, cursor < puzzle.moves.count, board.turn != learner else { return }
        replyTask?.cancel(); let token = generation
        replyTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(400))
                guard token == generation, let move = board.legalMoves().first(where: { $0.uci == puzzle.moves[cursor] }) else { return }
                played.append(try board.san(for: move)); board = try board.playing(move); cursor += 1
                finishIfNeeded()
            } catch is CancellationError {} catch { message = error.localizedDescription }
        }
    }
    private func hint() {
        guard let puzzle, cursor < puzzle.moves.count, let move = board.legalMoves().first(where: { $0.uci == puzzle.moves[cursor] }) else { return }
        grade(false); message = "Try \((try? board.san(for: move)) ?? "the highlighted tactic")."
    }
}
