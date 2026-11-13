import SwiftUI

@MainActor struct LearnOpeningsView: View {
    var body: some View {
        GeometryReader { geometry in
            let side = min(220, min(geometry.size.width - 40, max(128, (geometry.size.height - 74) / 4)))
            ScrollView {
                VStack(spacing: 18) {
                    NavigationLink { OpeningLessonsView() } label: { LearnSquare(title: "Openings", symbol: "books.vertical.fill", color: .green, side: side) }.accessibilityIdentifier("learn-openings")
                    NavigationLink { ChessFactsView() } label: { LearnSquare(title: "Fun facts", symbol: "lightbulb.fill", color: .orange, side: side) }.accessibilityIdentifier("learn-facts")
                    NavigationLink { ChessHistoryView() } label: { LearnSquare(title: "History", symbol: "clock.arrow.circlepath", color: .purple, side: side) }.accessibilityIdentifier("learn-history")
                    NavigationLink { EndgameLibraryView() } label: { LearnSquare(title: "Endgames", symbol: "flag.checkered", color: .blue, side: side) }.accessibilityIdentifier("learn-endgames")
                }.buttonStyle(.plain).padding(.vertical, 10).frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }.modifier(AppSurface()).navigationTitle("Learn").navigationBarTitleDisplayMode(.inline)
    }
}
private struct LearnSquare: View {
    var title: String
    var symbol: String
    var color: Color
    var side: CGFloat
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 42, weight: .medium)).foregroundStyle(color)
            Text(title).font(.title2.bold()).foregroundStyle(.primary)
        }.frame(width: side, height: side)
            .background { ThemeCardBackground().overlay(color.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius: 24)) }
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(color.opacity(0.45), lineWidth: 2))
            .contentShape(RoundedRectangle(cornerRadius: 24)).accessibilityElement(children: .ignore).accessibilityLabel(title)
    }
}


@MainActor struct OpeningLessonsView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var search = ""
    private var lessons: [OpeningLine] {
        if !search.isEmpty { return Array((library.openings + OpeningLessons.additional).filter { (16...40).contains($0.moves.count) && ($0.name.localizedCaseInsensitiveContains(search) || $0.eco.localizedCaseInsensitiveContains(search)) }.prefix(100)) }
        return OpeningLessons.curated(in: library.openings)
    }
    var body: some View {
        List(lessons) { line in
            NavigationLink { OpeningLessonView(opening: line) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) { Text(line.name).font(.headline); Text("\(line.eco) · \(CountText.value(GameStatistics.moveCount(plies: line.moves.count), "move"))").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    if library.state.learnedOpenings.contains(line.id) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                }
            }
        }.searchable(text: $search, prompt: "Find an opening").navigationTitle("Learn openings").modifier(AppSurface())
    }
}
@MainActor private struct OpeningLessonView: View {
    @EnvironmentObject private var library: LibraryStore
    let opening: OpeningLine
    @State private var board = Position.initial
    @State private var cursor = 0
    @State private var practice = false
    @State private var hint = false
    @State private var message: String?
    private var moves: [String] { opening.moves }
    private var expected: ChessMove? { guard moves.indices.contains(cursor) else { return nil }; return board.legalMoves().first { $0.uci == moves[cursor] } }
    private var san: String { expected.flatMap { try? board.san(for: $0) } ?? "" }
    private var explanation: String {
        guard let move = expected, let piece = board.squares[move.from] else { return "You have reached the end of this lesson." }
        if piece.kind == "k" && abs(move.to-move.from) == 2 { return "Castling brings the king toward safety and moves a rook toward the center." }
        if board.squares[move.to] != nil { return "This continuation captures material. Check what can recapture before continuing." }
        switch piece.kind {
        case "p": return "Notice how this pawn move changes the center and the lines available to the pieces."
        case "n", "b": return "Notice how this move changes the piece’s activity and influence on the center."
        case "q": return "Look for the queen's threats and check whether the opponent can gain time by attacking it."
        case "r": return "Compare the rook's file and activity before and after this move."
        default: return "Follow this named line, then compare the new position with the previous one."
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(opening.name).font(.title2.bold())
                Toggle("Practice moves", isOn: $practice)
                TurnBadge(side: board.turn)
                MoveBoard(position: board, enabled: practice && cursor < moves.count, onMove: attempt)
                if cursor == moves.count { Text("Lesson complete").font(.headline).foregroundStyle(.green) }
                else if !practice || hint { Text("Next: " + san).font(.headline); Text(explanation).foregroundStyle(.secondary) }
                else { Text("Play the next move in this line.").font(.headline) }
                if let message { Text(message).font(.callout).foregroundStyle(.secondary) }
                HStack {
                    Button("Back", systemImage: "chevron.left") { show(max(0, cursor-1)) }.disabled(cursor == 0)
                    Spacer()
                    if practice { Button("Hint", systemImage: "lightbulb") { hint = true }.disabled(cursor == moves.count) }
                    else { Button("Next", systemImage: "chevron.right") { show(min(moves.count, cursor+1)) }.disabled(cursor == moves.count) }
                }.buttonStyle(.bordered)
                Button("Start again") { show(0) }
            }.padding()
        }.navigationTitle("Learn").modifier(AppSurface())
    }
    private func attempt(_ move: ChessMove) {
        guard moves.indices.contains(cursor) else { return }
        guard move.uci == moves[cursor] else { message = "Try another move, or use Hint."; return }
        show(cursor+1)
    }
    private func show(_ target: Int) {
        do {
            var position = Position.initial
            for move in moves.prefix(target) { try position.apply(uci: move) }
            board = position; cursor = target; hint = false; message = nil
            if target == moves.count { library.state.learnedOpenings.insert(opening.id) }
        } catch { message = error.localizedDescription }
    }
}
