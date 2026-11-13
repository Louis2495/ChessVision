import SwiftUI

struct OpeningTrainingView: View {
    @EnvironmentObject private var library: LibraryStore
    @StateObject private var model = ComputerGameModel()
    @State private var choosing = false
    @State private var active = false
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if active, let state = model.snapshot {
                    PlayerBoardLabel(name: "Computer", rating: model.game?.targetRating ?? 1000, active: !state.finished && state.board.turn != model.game?.human)
                    MoveBoard(position: state.board, enabled: !model.busy && state.board.turn == model.game?.human && !state.finished,
                              flipped: model.game?.human == .black, premoveSide: model.game?.human) { move in
                        if let legal = model.snapshot?.moves.first(where: { $0.uci == move.uci }) { model.play(legal) }
                    }.padding(.vertical, 10)
                    PlayerBoardLabel(name: SocialStore.shared.profile?.username ?? "You", rating: Int(library.state.playProgress.rating(for: .normal).value.rounded()), active: !state.finished && state.board.turn == model.game?.human)
                    Text(model.requestedOpening?.name ?? "Opening training").font(.subheadline).foregroundStyle(.secondary)
                    if model.busy { ProgressView() }
                    if !model.bookMatches { Text("You have left the chosen line. Continue playing or start again.").font(.callout).foregroundStyle(.secondary) }
                    else if let line = model.requestedOpening, (model.game?.moves.count ?? 0) >= line.moves.count { Text("Opening complete. Continue playing or choose another opening.").foregroundStyle(.secondary) }
                    if let result = state.result { Text(result).font(.title2.bold()) }
                    Button("New training game") { model.pause(); active = false }
                } else {
                    Button { choosing = true } label: { Label(model.requestedOpening?.name ?? "Choose an opening", systemImage: "books.vertical") }.buttonStyle(.bordered)
                    Picker("Your color", selection: $model.human) { Text("White").tag(Side.white); Text("Black").tag(Side.black) }.pickerStyle(.segmented)
                    TextField("Engine strength estimate", text: $model.ratingText).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                    Button("Train", systemImage: "play.fill") { active = model.start(); if active { model.activate(library) } }.buttonStyle(ThemeActionButtonStyle()).disabled(model.requestedOpening == nil || (model.game?.rated == true && model.snapshot == nil))
                }
                if let error = model.error { Text(error).foregroundStyle(.red) }
            }.padding()
        }.navigationTitle("Train an opening").modifier(AppSurface())
        .sheet(isPresented: $choosing) { OpeningPicker { model.requestedOpening = $0 } }
        .onAppear { if active { model.activate(library) } else { model.prepare(library) } }
        .onDisappear { model.pause() }
    }
}
