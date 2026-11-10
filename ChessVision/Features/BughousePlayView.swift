import SwiftUI

@MainActor struct BughousePlayView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = BughouseModel()
    @State private var sideways = UIDevice.current.orientation.isLandscape
    @State private var setup = false
    @State private var reviewing = false
    @State private var reviewedID: UUID?
    @State private var reviewTask: Task<Void, Never>?
    @State private var selected: Int?
    @State private var drop: Character?
    @State private var promotions: [VariantMove] = []
    @State private var resigning = false
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if geometry.size.width <= geometry.size.height || !sideways {
                    ContentUnavailableView("Turn your device sideways", systemImage: "rotate.right", description: Text("Bughouse uses two boards. Rotate to landscape to set up or resume the match."))
                } else if model.loading { ProgressView("Preparing Bughouse…").frame(maxWidth: .infinity, maxHeight: .infinity) }
                else if model.match == nil || model.states.count != 2 { BughouseSetupView { model.newMatch($0) } }
                else { table(size: geometry.size) }
            }.modifier(AppSurface()).navigationTitle("Bughouse").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { reviewTask?.cancel(); model.pause(); dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        if model.match != nil { Button("New") { reviewTask?.cancel(); model.pause(); setup = true } }
                        if model.match?.winner == nil && model.states.count == 2 {
                            Button(model.running ? "Pause" : "Resume") { if model.running { model.pause() } else if sideways { model.resume() } }
                            Button("Resign", role: .destructive) { resigning = true }
                        }
                    }
                }
            }
            .sheet(isPresented: $setup) { NavigationStack { BughouseSetupView { model.newMatch($0); setup = false }.toolbar { Button("Cancel") { setup = false } } } }
            .sheet(isPresented: $reviewing) { if let id = model.match?.id { NavigationStack { GameReviewView(id: id).toolbar { Button("Done") { reviewing = false } } } } }
            .sheet(isPresented: Binding(get: { !promotions.isEmpty }, set: { if !$0 { promotions = [] } })) {
                PromotionPicker(side: model.match?.config.human ?? .white, kinds: promotions.compactMap(\.promotion)) { kind in
                    if let move = promotions.first(where: { $0.promotion == kind }) { model.play(move) }; promotions = []
                }
            }
            .confirmationDialog("Resign your team's match?", isPresented: $resigning) { Button("Resign", role: .destructive) { model.resign() } }
            .onAppear {
                UIDevice.current.beginGeneratingDeviceOrientationNotifications(); OrientationPolicy.set(.landscape)
                model.attach(library)
            }
            .onDisappear { reviewTask?.cancel(); model.pause(); UIApplication.shared.isIdleTimerDisabled = false; OrientationPolicy.set(.portrait); UIDevice.current.endGeneratingDeviceOrientationNotifications() }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                let orientation = UIDevice.current.orientation
                if orientation.isLandscape { sideways = true }
                else if orientation.isPortrait { sideways = false; model.pause() }
            }
            .onChange(of: model.running) { _, running in UIApplication.shared.isIdleTimerDisabled = running && sideways }
            .onChange(of: scenePhase) { _, phase in if phase != .active { reviewTask?.cancel(); model.pause() } else { scheduleReview() } }
            .onChange(of: model.states.first?.board.fen) { _, _ in selected = nil; drop = nil; promotions = [] }
            .onChange(of: model.match?.winner) { _, _ in scheduleReview() }
        }
    }
    private func scheduleReview() {
        reviewTask?.cancel()
        guard let match = model.match, match.winner != nil, reviewedID != match.id else { return }
        let id = match.id
        reviewTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            if model.match?.id == id && !setup && !model.loading && scenePhase == .active {
                reviewedID = id; reviewing = true
            }
        }
    }
    private func table(size: CGSize) -> some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            let side = max(80, min((size.width - 36) / 2, size.height - (model.match?.winner == nil ? 125 : 160)))
            VStack(spacing: 4) {
                if let match = model.match, match.winner != nil {
                    Button(match.resultTitle + " · Review match") { reviewing = true }.font(.headline).buttonStyle(.borderedProminent)
                } else if let error = model.error { Text(error).font(.caption).foregroundStyle(.red) }
                HStack(alignment: .top, spacing: 20) {
                    board(0, side: side)
                    board(1, side: side)
                }.frame(maxWidth: .infinity)
            }.frame(maxHeight: .infinity)
        }
    }
    private func board(_ index: Int, side: CGFloat) -> some View {
        let state = model.states[index]
        let human = model.match?.config.human ?? .white
        let bottom = index == 0 ? human : human.opposite
        return VStack(spacing: 4) {
            HStack {
                Text(index == 0 ? "A · Your board" : "B · Partner board").font(.caption.bold())
                Spacer()
                if model.thinkingBoard == index { ProgressView().controlSize(.mini) }
            }
            clockRow(index, side: bottom.opposite)
            BoardView(position: state.board, selected: index == 0 ? selected : nil, legalTargets: index == 0 ? targets() : [], flipped: bottom == .black) { square in if index == 0 { tap(square) } }.frame(width: side, height: side).accessibilityElement(children: .contain).accessibilityIdentifier(index == 0 ? "bughouse-board-A" : "bughouse-board-B")
            clockRow(index, side: bottom)
            HStack(spacing: 4) {
                ForEach(Array("PNBRQ"), id: \.self) { kind in
                    let symbol = bottom == .white ? kind : Character(kind.lowercased())
                    let count = state.pockets.filter { $0.symbol == symbol }.count
                    Button { selected = nil; drop = kind } label: {
                        HStack(spacing: 0) { PieceView(piece: Piece(symbol)).frame(width: 22, height: 22); Text("\(count)").font(.caption2) }
                    }.disabled(index != 0 || count == 0 || state.board.turn != human || !model.running)
                }
            }
        }.frame(width: side)
    }
    private func clockRow(_ board: Int, side: Side) -> some View {
        let rating = model.match?.config.ratings[BughouseConfig.seat(board, side)] ?? 1000
        let seconds = model.clocks.indices.contains(board) ? model.clocks[board].remaining(for: side, at: ProcessInfo.processInfo.systemUptime) : 0
        let rounded = Int(ceil(seconds))
        return HStack {
            Text("\(side.title) ≈\(rating)").font(.caption2)
            Spacer()
            Text(String(format: "%d:%02d", rounded / 60, rounded % 60)).font(.caption.bold().monospacedDigit())
        }.foregroundStyle(BughouseConfig.team(board, side) == model.match?.config.humanTeam ? Color.accentColor : Color.primary)
    }
    private func targets() -> Set<Int> {
        guard model.states.count == 2 else { return [] }
        return Set(model.states[0].moves.filter { drop != nil ? $0.drop == drop : $0.from == selected }.compactMap(\.to))
    }
    private func tap(_ square: Int) {
        guard model.running, let human = model.match?.config.human, model.states[0].board.turn == human else { return }
        let state = model.states[0]
        let choices = state.moves.filter { $0.to == square && (drop != nil ? $0.drop == drop : selected != nil && $0.from == selected) }
        if choices.count > 1 { promotions = choices; return }
        if let move = choices.first { model.play(move); return }
        drop = nil; selected = state.board.squares[square]?.side == human ? square : nil
    }
}

private struct BughouseSetupView: View {
    @State private var human = Side.white
    @State private var ratings = ["1000", "1000", "1000", "1000"]
    @State private var preset = 4
    @State private var custom = false
    @State private var minutes = 5
    @State private var seconds = 0
    @State private var increment = 2
    @State private var error: String?
    let start: (BughouseConfig) -> Void
    var body: some View {
        Form {
            Section("Seats and ratings") {
                Picker("Your color on board A", selection: $human) { Text("White").tag(Side.white); Text("Black").tag(Side.black) }.pickerStyle(.segmented)
                ForEach(0..<4, id: \.self) { seat in
                    let color: Side = seat.isMultiple(of: 2) ? .white : .black
                    let role = seat == BughouseConfig.seat(0, human) ? "You (display rating)" : BughouseConfig.team(seat / 2, color) == (human == .white ? 0 : 1) ? "Partner computer" : "Opponent computer"
                    HStack { Text("\(seat < 2 ? "A" : "B") \(color.title) · \(role)").font(.caption); Spacer(); TextField("Rating", text: $ratings[seat]).keyboardType(.numberPad).frame(width: 75).textFieldStyle(.roundedBorder) }
                }
            }.listRowBackground(ThemeCardBackground())
            Section("Both boards · time control") {
                Toggle("Custom", isOn: $custom)
                if custom {
                    Stepper("Minutes: \(minutes)", value: $minutes, in: 0...180)
                    Stepper("Seconds: \(seconds)", value: $seconds, in: 0...59)
                    Stepper("Increment: \(increment) seconds", value: $increment, in: 0...60)
                } else { Picker("Preset", selection: $preset) { ForEach(Array(ClockTimeControl.presets.enumerated()), id: \.offset) { index, control in Text(control.title).tag(index) } } }
            }.listRowBackground(ThemeCardBackground())
            Section {
                Button("Start Bughouse") {
                    let values = ratings.compactMap(Int.init)
                    let control = custom ? ClockTimeControl(seconds: minutes * 60 + seconds, increment: increment) : ClockTimeControl.presets[preset]
                    let config = BughouseConfig(human: human, ratings: values, seconds: control.seconds, increment: control.increment)
                    do { try config.validate(); error = nil; start(config) } catch { self.error = error.localizedDescription }
                }.buttonStyle(.borderedProminent).disabled(custom && minutes * 60 + seconds == 0)
                if let error { Text(error).font(.caption).foregroundStyle(.red) }
            }.listRowBackground(ThemeCardBackground())
        }.scrollDismissesKeyboard(.interactively).modifier(AppSurface())
    }
}
