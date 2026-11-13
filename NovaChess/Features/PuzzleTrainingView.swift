import SwiftUI

struct PuzzleTrainingView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.scenePhase) private var phase
    @State private var today = Date()
    @State private var activeDailyKey: String?
    @State private var puzzle: ChessPuzzle?
    @State private var board = Position.initial
    @State private var learner = Side.white
    @State private var cursor = 1
    @State private var graded = false
    @State private var finished = false
    @State private var message = ""
    @State private var played: [String] = []
    @State private var resultBorder: Color = .clear
    @State private var replyTask: Task<Void, Never>?
    @State private var generation = UUID()
    private var dayKey: String { DailyPuzzle.key(for: today) }
    var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AppCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Daily puzzle", systemImage: "calendar").font(.headline)
                                Text(today, style: .date).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(library.state.dailyPuzzles[dayKey]?.completed == true ? "Replay" : "Play") { startDaily() }
                                .buttonStyle(ThemeActionButtonStyle()).accessibilityIdentifier("daily-puzzle")
                            if library.state.dailyPuzzles[dayKey]?.completed == true { Image(systemName: "checkmark.seal.fill").foregroundStyle(.yellow) }
                        }
                    }
                    AppCard {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading) { Text("Your puzzle estimate").font(.caption).foregroundStyle(.secondary); Text(String(Int(library.state.puzzle.rating.rounded()))).font(.largeTitle.bold().monospacedDigit()) }
                        Spacer()
                        VStack(alignment: .trailing) { Text("\(library.state.puzzle.solved) solved").font(.headline); Text("\(library.puzzles.count.formatted()) offline puzzles").font(.caption).foregroundStyle(.secondary) }
                    }
                    }
                    if let puzzle {
                        HStack { Text("Lichess difficulty · \(String(puzzle.difficultyRating))").font(.headline); Spacer(); TurnBadge(side: board.turn) }
                        MoveBoard(position: board, enabled: !finished && board.turn == learner, flipped: learner == .black, premoveSide: finished ? nil : learner, onMove: attempt).id(generation)
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(resultBorder, lineWidth: 5).allowsHitTesting(false))
                            .accessibilityValue(resultBorder == .red ? "Incorrect attempt" : finished ? "Puzzle completed" : "Puzzle in progress")
                        Text(finished ? "Position completed" : board.turn == learner ? "\(learner.title) to move" : "Playing the reply…").font(.headline)
                        if !message.isEmpty { Text(message).foregroundStyle(finished ? Color.green : Color.secondary) }
                        if !played.isEmpty { Text(played.joined(separator: "  ")).font(.subheadline.monospaced()) }
                        HStack {
                            Button { hint() } label: { Label("Hint", systemImage: "lightbulb").foregroundStyle(Color.yellow).frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(.bordered).controlSize(.large).disabled(finished || board.turn != learner)
                            Button { if !finished { grade(false) }; nextPuzzle() } label: {
                                Label(finished ? "Next puzzle" : "Skip puzzle", systemImage: "arrow.right").frame(maxWidth: .infinity, minHeight: 44)
                            }.buttonStyle(.borderedProminent).tint(Color(red: 0.12, green: 0.36, blue: 0.24)).foregroundStyle(.white).controlSize(.large)
                        }
                    } else { ContentUnavailableView("Puzzle library unavailable", systemImage: "puzzlepiece", description: Text("Install the complete build to use the bundled puzzle library.")) }
                }.padding()
            }.modifier(AppSurface()).navigationTitle("Puzzles").navigationBarTitleDisplayMode(.inline).toolbar { SettingsButton() }
            .onAppear { today = Date(); if puzzle == nil { nextPuzzle() } else { replyIfNeeded() } }
            .onDisappear { replyTask?.cancel() }
            .onChange(of: phase) { _, value in if value == .active { today = Date() } }
    }
    private func startDaily() {
        guard let chosen = DailyPuzzle.choose(day: dayKey, puzzles: library.puzzles, saved: library.state.dailyPuzzles[dayKey]) else { return }
        load(chosen, daily: dayKey)
    }
    private func load(_ next: ChessPuzzle, daily: String? = nil) {
        replyTask?.cancel(); generation = UUID()
        do {
            board = try next.startingPosition(); learner = board.turn; puzzle = next; activeDailyKey = daily
            cursor = 1; graded = daily.map { library.state.dailyPuzzles[$0] != nil } ?? false
            finished = false; message = ""; played = []; resultBorder = .clear
        } catch { message = error.localizedDescription; puzzle = nil }
    }
    private func completeDaily() {
        guard let key = activeDailyKey else { return }
        library.state.completeDailyPuzzle(day: key)
    }
    private func nextPuzzle() {
        guard let next = library.state.puzzle.next(in: library.puzzles, excluding: puzzle?.id) else { return }
        load(next)
    }

    private func grade(_ correct: Bool) {
        guard !graded, let puzzle else { return }
        library.state.recordPuzzle(puzzle, correct: correct, daily: activeDailyKey); graded = true
    }
    private func attempt(_ move: ChessMove) {
        guard let puzzle, cursor < puzzle.moves.count else { return }
        guard puzzle.moves[cursor] == move.uci else {
            if let next = try? board.playing(move), next.isInCheck && next.legalMoves().isEmpty {
                played.append((try? board.san(for: move)) ?? "Mate")
                board = next; let assisted = graded; grade(true); finished = true; resultBorder = .yellow; completeDaily()
                message = activeDailyKey != nil ? "Daily puzzle complete" : assisted ? "Checkmate found. Your earlier hint or mistake is still reflected in the rating." : "Checkmate — solved!"
                return
            }
            resultBorder = .red; grade(false); message = "That is not the intended move. Try again or use a hint."; return
        }
        do {
            played.append(try board.san(for: move)); board = try board.playing(move); cursor += 1
            message = "Correct."; finishIfNeeded(); replyIfNeeded()
        } catch { message = error.localizedDescription }
    }
    private func finishIfNeeded() {
        if let puzzle, cursor >= puzzle.moves.count {
            let assisted = graded
            grade(true); finished = true; resultBorder = .yellow; completeDaily()
            message = activeDailyKey != nil ? "Daily puzzle complete" : assisted ? "Completed. Your next puzzle will reflect the earlier mistake or hint." : "Solved without help. Your difficulty has increased."
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
