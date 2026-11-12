import SwiftUI

@MainActor struct LearnOpeningsView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var search = ""
    private var lessons: [OpeningLine] {
        if !search.isEmpty { return Array(library.openings.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.eco.localizedCaseInsensitiveContains(search) }.prefix(100)) }
        let names = ["Italian", "Ruy Lopez", "Queen's Gambit", "London", "Caro-Kann", "Sicilian", "French", "Scandinavian"]
        return names.compactMap { name in library.openings.filter { $0.name.localizedCaseInsensitiveContains(name) && $0.moves.count >= 4 }.min { $0.moves.count < $1.moves.count } }
    }
    var body: some View {
        List(lessons) { line in
            NavigationLink { OpeningLessonView(opening: line) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) { Text(line.name).font(.headline); Text(line.eco).font(.caption).foregroundStyle(.secondary) }
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
