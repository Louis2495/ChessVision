import SwiftUI

struct GameHistoryView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var saveError: String?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            NavigationLink("Saved games & folders") { SavedGamesView() }
            if let saveError { Text(saveError).foregroundStyle(.red) }
            if library.state.history.isEmpty {
                ContentUnavailableView("No completed games yet", systemImage: "clock.arrow.circlepath", description: Text("Finished computer games are saved here automatically."))
            }
            ForEach(library.state.history) { entry in
                NavigationLink { GameReviewView(id: entry.id) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Text(entry.resultTitle).font(.headline); Spacer(); Text(entry.game.mode.title).font(.caption).foregroundStyle(.secondary) }
                        Text("You: \(entry.game.human.title) · \(entry.game.opponentName ?? "Computer ≈ \(String(entry.game.targetRating))") · \(CountText.value(entry.moveCount, "move"))").font(.caption).foregroundStyle(.secondary)
                        Text(entry.finishedAt, style: .date).font(.caption2).foregroundStyle(.secondary)
                        if entry.review?.complete == true { Text("Review saved").font(.caption).foregroundStyle(.tint) }
                    }.padding(.vertical, 6)
                }.swipeActions(edge: .leading) {
                    Button("Save", systemImage: "folder.badge.plus") {
                        save(entry)
                    }.tint(.blue)
                }.listRowBackground(ThemeCardBackground())
            }
        }.modifier(AppSurface()).navigationTitle("Game history")
            .toolbar { Button("Done") { dismiss() } }
    }
    private func save(_ entry: CompletedGame) {
                        Task { @MainActor in
                            do {
                                if library.state.savedGames.contains(where: { $0.id == entry.id }) { return }
                                var frames = entry.positions
                                if frames.isEmpty {
                                    if let bughouse = entry.bughouse { frames = try await BughouseRules.replay(bughouse.events)[0] }
                                    else {
                                        try await EngineController.shared.prepareVariant(entry.game.variant)
                                        for ply in 0...entry.game.moves.count {
                                            frames.append(try VariantRules.snapshot(variant: entry.game.variant, history: Array(entry.game.moves.prefix(ply))).fen)
                                            if ply.isMultiple(of: 8) { await Task.yield() }
                                        }
                                    }
                                }
                                var saved = SavedBoardGame(title: entry.game.mode.title + " game", positions: frames, notation: entry.game.notation)
                                saved.id = entry.id
                                if !library.state.savedGames.contains(where: { $0.id == entry.id }) { library.state.savedGames.insert(saved, at: 0) }
                            } catch { saveError = error.localizedDescription }
                        }
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
                        Button("Resume review", systemImage: "play.fill") { model.start(id: id, library: library) }.buttonStyle(ThemeActionButtonStyle())
                    }
                    if let error = model.error { Text(error).font(.footnote).foregroundStyle(.red) }
                    if let review = model.review {
                        gameSummary(entry, review: review)
                        suggestions(review)
                    }
                    if let ungraded = model.review?.ungradedBughouseMoves, !ungraded.isEmpty {
                        Text("\(CountText.value(ungraded.count, "move")) awaiting partner material \(ungraded.count == 1 ? "was" : "were") left ungraded.").font(.caption).foregroundStyle(.secondary)
                    }
                    if entry.bughouse != nil { Text("Bughouse comparisons assess board A. Partner-board consequences are not fully evaluated by the engine.").font(.caption).foregroundStyle(.secondary) }

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
                BoardView(position: position.board, flipped: entry.game.human == .black, duckSquare: position.duckSquare, moveAssessment: model.review?.assessments?.first(where: { $0.ply == cursor - 1 }))
                if entry.bughouse != nil, let partner = model.position(at: cursor, partner: true) { BoardView(position: partner.board, flipped: entry.game.human == .white) }
            }
            if let assessment = model.review?.assessments?.first(where: { $0.ply == cursor - 1 }) {
                ReviewMoveRow(assessment: assessment)
            }
            HStack {
                Button("Previous", systemImage: "chevron.left") { cursor = max(0, cursor - 1) }.disabled(cursor == 0)
                Spacer(); Text("\(String(GameStatistics.moveCount(plies: cursor)))/\(String(GameStatistics.moveCount(plies: entry.game.moves.count)))").font(.caption.monospacedDigit()); Spacer()
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
    private func gameSummary(_ entry: CompletedGame, review: GameReview) -> some View {
        AppCard {
            HStack {
                Text("Game summary").font(.title2.bold())
                Spacer()
                if let change = entry.ratingChange { Text("\(change >= 0 ? "+" : "")\(String(change))").font(.headline.monospacedDigit()) }
            }
            ForEach(Side.allCases, id: \.rawValue) { side in
                let summary = ReviewSummary(review.assessments ?? [], side: side)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        RoundedRectangle(cornerRadius: 3).fill(side == .white ? Color.white : Color.black).frame(width: 18, height: 18).overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray, lineWidth: 1))
                        Text(side.title).font(.headline)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(summary.performanceEstimate.map { "≈" + String($0) } ?? "—").font(.title3.bold().monospacedDigit())
                            Text("Game estimate").font(.caption2).foregroundStyle(.secondary)
                        }.accessibilityLabel(side.title + " uncalibrated game rating estimate")
                    }
                    HStack(spacing: 12) {
                        ForEach([MoveQuality.best, .excellent, .good, .inaccuracy, .mistake, .blunder], id: \.self) { quality in
                            VStack(spacing: 4) {
                                Image(systemName: quality.symbol).foregroundStyle(quality.color)
                                Text(String(summary.count(quality))).font(.caption.monospacedDigit())
                            }.frame(maxWidth: .infinity).accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(quality.title): \(summary.count(quality))")
                        }
                    }
                }.padding(.vertical, 6)
            }
            DisclosureGroup("All assessed moves") {
                ForEach(review.assessments ?? []) { assessment in
                    Button { cursor = assessment.ply + 1 } label: {
                        ReviewMoveRow(assessment: assessment).padding(.vertical, 7)
                    }.buttonStyle(.plain)
                }
            }
        }
    }
    @ViewBuilder private func suggestions(_ review: GameReview) -> some View {
        if !review.suggestions.isEmpty {
            AppCard {
                Text("Move suggestions").font(.title2.bold())
                ForEach(review.suggestions) { item in
                    HStack {
                        Button { cursor = item.ply + 1 } label: {
                            HStack(spacing: 10) {
                                Image(systemName: item.source == .repertoire ? "book.closed.fill" : "arrow.triangle.branch").foregroundStyle(.tint)
                                Text(item.moveLabel).monospaced().foregroundStyle(.primary)
                                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                                Text(item.recommended.joined(separator: " / ")).fontWeight(.semibold).foregroundStyle(.green)
                                Spacer(minLength: 0)
                            }.frame(minHeight: 44)
                        }.buttonStyle(.plain).accessibilityLabel("\(item.moveLabel). Suggested: \(item.recommended.joined(separator: " or "))")
                        if let line = library.state.repertoire.first(where: { item.repertoireIDs.contains($0.id) }) {
                            NavigationLink { RepertoireTrainerView(preferred: line.id) } label: { Image(systemName: "graduationcap.fill") }
                                .accessibilityLabel("Train " + line.name)
                        }
                    }
                }
            }
        }
    }
}
