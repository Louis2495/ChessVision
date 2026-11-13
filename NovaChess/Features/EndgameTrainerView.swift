import SwiftUI

@MainActor struct EndgameLibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    var body: some View {
        List {
            ForEach(["Checkmates", "Pawns", "Rooks", "Defense"], id: \.self) { category in
                Section(category) {
                    ForEach(EndgameExercise.all.filter { $0.category == category }) { exercise in
                        NavigationLink { EndgameTrainerView(exercise: exercise) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(exercise.title).font(.headline)
                                    Text(exercise.goal.title).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if library.state.completedEndgames.contains(exercise.id) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                            }.padding(.vertical, 5)
                        }.accessibilityLabel(exercise.title).accessibilityIdentifier("endgame-" + exercise.id)
                    }
                }
            }
        }.modifier(AppSurface()).navigationTitle("Endgames")
    }
}
@MainActor struct EndgameTrainerView: View {
    let exercise: EndgameExercise
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.scenePhase) private var phase
    @StateObject private var model = EndgameTrainerModel()
    @State private var visible = false
    @State private var showTip = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(exercise.title).font(.title2.bold())
                Label(exercise.goal.title, systemImage: exercise.goal == .mate ? "crown.fill" : exercise.goal == .promote ? "arrow.up" : "equal.circle").font(.headline).foregroundStyle(.tint)
                if let session = model.session {
                    MoveBoard(position: session.board, enabled: !model.busy && session.outcome == .ongoing && session.board.turn == exercise.side,
                              flipped: exercise.side == .black, premoveSide: session.outcome == .ongoing && session.board.turn != exercise.side ? exercise.side : nil, onMove: model.play)
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(session.outcome == .success ? Color.yellow : session.outcome == .failure ? Color.red : Color.clear, lineWidth: 5).allowsHitTesting(false))
                    if session.outcome != .ongoing {
                        Label(session.outcome == .success ? "Complete" : (session.result ?? "Try again"), systemImage: session.outcome == .success ? "checkmark.seal.fill" : "arrow.counterclockwise").font(.title3.bold())
                    } else if model.busy { ProgressView() }
                    else { TurnBadge(side: session.board.turn) }
                    if let hint = model.hint { Label(hint, systemImage: "lightbulb.fill").foregroundStyle(.yellow).font(.headline.monospaced()) }
                    if let error = model.error {
                        Text(error).foregroundStyle(.red)
                        if session.board.turn != exercise.side { Button("Retry") { model.resume() } }
                    }
                    HStack {
                        Button("Hint", systemImage: "lightbulb") { model.showHint() }.disabled(model.busy || session.outcome != .ongoing || session.board.turn != exercise.side)
                        Spacer()
                        Button("Restart", systemImage: "arrow.counterclockwise") { model.start(exercise) }
                    }.buttonStyle(.bordered)
                    if session.canClaimDraw && session.board.turn == exercise.side { Button("Claim draw") { model.claimDraw() }.buttonStyle(ThemeActionButtonStyle()) }
                } else if let error = model.error { Text(error).foregroundStyle(.red) }
                Button { showTip.toggle() } label: {
                    HStack { Text("Technique"); Spacer(); Image(systemName: showTip ? "chevron.up" : "chevron.down") }
                }.buttonStyle(.plain).frame(minHeight: 44)
                if showTip { Text(exercise.tip).font(.subheadline).foregroundStyle(.secondary) }
            }.padding()
        }.modifier(AppSurface()).navigationTitle("Endgame trainer").navigationBarTitleDisplayMode(.inline)
            .onAppear { visible = true; if model.session == nil { model.start(exercise) } else { model.resume() } }
            .onDisappear { visible = false; model.pause() }
            .onChange(of: phase) { _, value in if value == .active && visible { model.resume() } else { model.pause() } }
            .onChange(of: model.session?.outcome) { _, result in if result == .success { library.state.completedEndgames.insert(exercise.id) } }
    }
}
