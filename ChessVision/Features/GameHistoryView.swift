import SwiftUI

struct GameHistoryView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            if library.state.history.isEmpty {
                ContentUnavailableView("No completed games yet", systemImage: "clock.arrow.circlepath", description: Text("Finished computer games are saved here automatically."))
            }
            ForEach(library.state.history) { entry in
                NavigationLink { GameReviewView(id: entry.id) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Text(entry.resultTitle).font(.headline); Spacer(); Text(entry.game.mode.title).font(.caption).foregroundStyle(.secondary) }
                        Text("You: \(entry.game.human.title) · Computer ≈ \(entry.game.targetRating) · \(entry.game.moves.count) plies").font(.caption).foregroundStyle(.secondary)
                        Text(entry.finishedAt, style: .date).font(.caption2).foregroundStyle(.secondary)
                        if entry.review?.complete == true { Text("Review saved").font(.caption).foregroundStyle(.tint) }
                    }.padding(.vertical, 6)
                }.listRowBackground(ThemeCardBackground())
            }
        }.modifier(AppSurface()).navigationTitle("Game history")
            .toolbar { Button("Done") { dismiss() } }
    }
}

struct GameReviewView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = GameReviewModel()
    @State private var cursor = 0
    @State private var visible = false
    @State private var initialized = false
    let id: UUID
    private var entry: CompletedGame? { library.state.history.first { $0.id == id } }
    var body: some View {
        ScrollView {
            if let entry {
                VStack(alignment: .leading, spacing: 22) {
                    Text(entry.resultTitle).font(.largeTitle.bold())
                    Text("\(entry.game.mode.title) · You played \(entry.game.human.title)").foregroundStyle(.secondary)
                    if let resigned = entry.game.resigned { Text("\(resigned.title) resigned").font(.caption).foregroundStyle(.secondary) }
                    if let reason = entry.bughouse?.reason { Text(reason).font(.caption).foregroundStyle(.secondary) }
                    replay(entry)
                    if model.busy {
                        HStack { ProgressView(); Text(model.progress).font(.caption); Spacer(); Button("Pause") { model.cancel() } }
                    } else if model.review?.complete != true {
                        Button("Resume review", systemImage: "play.fill") { model.start(id: id, library: library) }.buttonStyle(.borderedProminent)
                    }
                    if let error = model.error { Text(error).font(.footnote).foregroundStyle(.red) }
                    if let review = model.review {
                        Text("\(review.assessedMoves)/\(entry.humanMoveCount) of your moves reviewed · \(review.repertoireMatches) repertoire positions").font(.caption).foregroundStyle(.secondary)
                        improvementAreas(review)
                        suggestions(review)
                    }
                    if entry.bughouse != nil { Text("Bughouse comparisons assess board A. Partner-board consequences are not fully evaluated by the engine.").font(.caption).foregroundStyle(.secondary) }
                    Text("Repertoire suggestions reflect your saved choices. Other suggestions use quick full-strength engine comparisons; classifications can change with deeper analysis. Variants use their own engine rules.").font(.caption).foregroundStyle(.secondary)
                }.padding()
            }
        }.modifier(AppSurface()).navigationTitle("Game review").navigationBarTitleDisplayMode(.inline)
        .onAppear { visible = true; if !initialized { cursor = entry?.game.moves.count ?? 0; initialized = true }; model.start(id: id, library: library) }
        .onDisappear { visible = false; model.cancel() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.cancel() }
            else if visible { model.start(id: id, library: library) }
        }
    }
    @ViewBuilder private func replay(_ entry: CompletedGame) -> some View {
        if let position = model.position(at: cursor) {
            HStack {
                BoardView(position: position.board, flipped: entry.game.human == .black, duckSquare: position.duckSquare)
                if entry.bughouse != nil, let partner = model.position(at: cursor, partner: true) { BoardView(position: partner.board, flipped: entry.game.human == .white) }
            }
            HStack {
                Button("Previous", systemImage: "chevron.left") { cursor = max(0, cursor - 1) }.disabled(cursor == 0)
                Spacer(); Text("\(cursor)/\(entry.game.moves.count)").font(.caption.monospacedDigit()); Spacer()
                Button("Next", systemImage: "chevron.right") { cursor = min(entry.game.moves.count, cursor + 1) }.disabled(cursor >= entry.game.moves.count)
            }
            if let bughouse = entry.bughouse, cursor > 0, bughouse.events.indices.contains(cursor - 1) {
                let event = bughouse.events[cursor - 1]
                Text("Board \(event.board == 0 ? "A" : "B") · \(event.number)\(event.side == .white ? "." : "…") \(event.san)").font(.headline.monospaced())
            } else if cursor > 0, entry.game.notation.indices.contains(cursor - 1) { Text("\((cursor - 1) / 2 + 1)\(cursor % 2 == 1 ? "." : "…") \(entry.game.notation[cursor - 1])").font(.headline.monospaced()) }
            if entry.game.variant == "chess" {
                if let opening = library.openingName(at: position.board) { Text(opening).font(.subheadline).foregroundStyle(.secondary) }
                NavigationLink("Analyze this position") { AnalysisView(original: position.board) }
            }
        } else { ProgressView("Preparing replay…").frame(maxWidth: .infinity, minHeight: 180) }
    }
    @ViewBuilder private func improvementAreas(_ review: GameReview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Areas for improvement").font(.title2.bold())
            if review.areas.isEmpty { Text(review.complete ? (review.assessedMoves == 0 ? "There were no moves by you to assess." : "No clear mistake pattern was found in this quick review.") : "Areas will appear as your moves are reviewed.").foregroundStyle(.secondary) }
            ForEach(review.areas, id: \.rawValue) { concept in
                let moves = review.suggestions.filter { $0.concept == concept }.map { String($0.number) }
                VStack(alignment: .leading, spacing: 6) {
                    Text(concept.title).font(.headline)
                    Text(concept.practice).font(.subheadline)
                    Text("Move\(moves.count == 1 ? "" : "s"): \(moves.joined(separator: ", "))").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding()
                    .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
    @ViewBuilder private func suggestions(_ review: GameReview) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Move suggestions").font(.title2.bold())
            if review.suggestions.isEmpty && review.complete { Text("No clear move corrections at this search budget. You can still replay and analyze any position.").foregroundStyle(.secondary) }
            ForEach(review.suggestions) { item in
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text(item.moveLabel).font(.headline.monospaced()); Spacer(); Text(item.label).font(.caption).foregroundStyle(.secondary) }
                    Text("Instead of \(item.played), consider \(item.recommended.joined(separator: " or ")).").font(.headline)
                    Text(item.explanation).font(.subheadline)
                    if let depth = item.depth { Text("Engine comparison depth: \(depth)").font(.caption).foregroundStyle(.secondary) }
                    Button("View this position") { cursor = item.ply }
                    if let line = library.state.repertoire.first(where: { item.repertoireIDs.contains($0.id) }) {
                        NavigationLink("Train \(line.name)") { RepertoireTrainerView(preferred: line.id) }
                    }
                }.padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(ThemeCardBackground(), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}
