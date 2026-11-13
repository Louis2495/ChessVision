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
    @AppStorage("premoves") private var premovesEnabled = true
    @AppStorage("autoQueen") private var autoQueen = false
    @State private var composer = PremoveComposer()
    @State private var queuePromotion = false
    @State private var selected: Int?
    @State private var drop: Character?
    @State private var promotions: [VariantMove] = []
    @State private var resigning = false
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if geometry.size.width <= geometry.size.height || !sideways {
                    ContentUnavailableView("Turn your device sideways", systemImage: "rotate.right")
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
                    if let move = promotions.first(where: { $0.promotion == kind }) {
                        if queuePromotion { composer.complete(move.uci, duck: false, queue: &model.premoves); model.flushPremoves(); queuePromotion = false }
                        else { model.play(move) }
                    }; promotions = []
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
            .onChange(of: premovesEnabled) { _, enabled in if !enabled { model.premoves.clear(); composer = PremoveComposer() } }
            .onChange(of: model.match?.id) { _, _ in composer = PremoveComposer() }
            .onChange(of: model.running) { _, running in UIApplication.shared.isIdleTimerDisabled = running && sideways }
            .onChange(of: scenePhase) { _, phase in if phase != .active { reviewTask?.cancel(); model.pause() } else { scheduleReview() } }
            .onChange(of: model.states.first?.board.fen) { _, _ in positionChanged() }
            .onChange(of: model.match?.winner) { _, _ in scheduleReview() }
        }
    }
    private func positionChanged() {
        if let square = selected, model.states.first?.board.squares[square]?.side != model.match?.config.human { selected = nil }
        if let square = composer.selected, let state = model.states.first, let human = model.match?.config.human, model.premoves.projected(state.board, side: human).squares[square]?.side != human { composer.selected = nil }
        drop = nil
        if !queuePromotion { promotions = [] }
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
            // Put clocks and pockets beside the squares so neither board loses vertical space.
            let side = max(1, min((size.width - 8) / 2 - 72, size.height))
            HStack(alignment: .center, spacing: 8) {
                board(0, side: side)
                board(1, side: side)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                if let match = model.match, match.winner != nil {
                    Button(match.resultTitle + " · Review match") { reviewing = true }.font(.headline).buttonStyle(ThemeActionButtonStyle())
                } else if let error = model.error {
                    Text(error).font(.caption).foregroundStyle(.red).padding(6).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    private func board(_ index: Int, side: CGFloat) -> some View {
        let state = model.states[index]
        let human = model.match?.config.human ?? .white
        let bottom = index == 0 ? human : human.opposite
        return HStack(spacing: 4) {
            BoardView(position: index == 0 && isPremoving ? model.premoves.projected(state.board, side: human) : state.board,
                      selected: index == 0 ? (isPremoving ? composer.selected : selected) : nil,
                      premoveSquares: index == 0 ? Set(model.premoves.moves.flatMap { move -> [Int] in let m = VariantMove(uci: move, san: ""); return [m.from, m.to].compactMap { $0 } }) : [], flipped: bottom == .black, onDropPiece: { kind, target in
                          guard index == 0, model.states[0].pockets.contains(where: { $0.side == human && $0.kind == Character(kind.lowercased()) }) else { return }
                          if isPremoving { composer.selected = nil; composer.drop = kind } else { selected = nil; drop = kind }
                          tap(target)
                      }, onDragMove: { source, target in
                          guard index == 0, model.states[0].board.squares[source]?.side == human else { return }
                          if isPremoving { composer.selected = source; composer.drop = nil } else { selected = source; drop = nil }
                          tap(target)
                      }) { square in if index == 0 { tap(square) } }
                .frame(width: side, height: side)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(index == 0 ? "bughouse-board-A" : "bughouse-board-B")
            VStack(spacing: 2) {
                clockRow(index, side: bottom.opposite)
                pocket(index, side: bottom.opposite)
                Spacer(minLength: 0)
                Text(state.inCheck && state.moves.isEmpty && !state.finished ? "Waiting for a piece" : index == 0 ? "Your board" : "Partner").font(.caption2.bold()).multilineTextAlignment(.center)
                if index == 0 && !model.premoves.moves.isEmpty { Text("\(model.premoves.moves.count) premoves").font(.caption2) }
                if model.thinkingBoard == index { ProgressView().controlSize(.mini).accessibilityLabel("Computer thinking") }
                Spacer(minLength: 0)
                pocket(index, side: bottom)
                clockRow(index, side: bottom)
            }.frame(width: 68, height: side)
        }.frame(width: side + 72)
    }
    private func pocket(_ index: Int, side: Side) -> some View {
        let state = model.states[index]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)], spacing: 0) {
            ForEach(Array("PNBRQ").filter { kind in state.pockets.contains { $0.symbol == (side == .white ? kind : Character(kind.lowercased())) } }, id: \.self) { kind in
                let symbol = side == .white ? kind : Character(kind.lowercased())
                let count = state.pockets.filter { $0.symbol == symbol }.count
                if count > 0 {
                    Button {
                        if isPremoving { composer.selected = nil; composer.drop = kind }
                        else { selected = nil; drop = kind }
                    } label: {
                        HStack(spacing: 2) {
                            PieceView(piece: Piece(symbol)).frame(width: 22, height: 22)
                            if count > 1 { Text("\(count)").font(.system(size: 9).monospacedDigit()) }
                        }.frame(maxWidth: .infinity, minHeight: 24)
                        .background((drop == kind || composer.drop == kind) && index == 0 && side == model.match?.config.human ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                    }.buttonStyle(.plain)
                    .onDrag { index == 0 && side == model.match?.config.human && model.running ? NSItemProvider(object: ("novachess-pocket:" + String(kind)) as NSString) : NSItemProvider() }
                    .accessibilityLabel("\(count) \(Piece(symbol).name) in hand")
                    .disabled(index != 0 || side != model.match?.config.human || (!premovesEnabled && state.board.turn != side) || !model.running)
                }
            }
        }
    }
    private func clockRow(_ board: Int, side: Side) -> some View {
        let rating = model.match?.config.ratings[BughouseConfig.seat(board, side)] ?? 1000
        let seconds = model.clocks.indices.contains(board) ? model.clocks[board].remaining(for: side, at: ProcessInfo.processInfo.systemUptime) : 0
        let rounded = Int(ceil(seconds))
        return VStack(spacing: 0) {
            Text("\(side.title) \(String(rating))").font(.system(size: 9)).lineLimit(1).minimumScaleFactor(0.7)
            Text(String(format: "%d:%02d", rounded / 60, rounded % 60)).font(.caption.bold().monospacedDigit())
        }.foregroundStyle(BughouseConfig.team(board, side) == model.match?.config.humanTeam ? Color.accentColor : Color.primary)
    }
    private var isPremoving: Bool { premovesEnabled && (model.states.first?.board.turn != model.match?.config.human || !model.premoves.moves.isEmpty || composer.selected != nil || composer.drop != nil) }
    private func tap(_ square: Int) {
        guard model.running, let human = model.match?.config.human else { return }
        if isPremoving {
            composer.tap(square, board: model.premoves.projected(model.states[0].board, side: human), side: human, duck: false, queue: &model.premoves)
            model.flushPremoves()
            if !composer.promotions.isEmpty { queuePromotion = true; promotions = composer.promotions }
            return
        }
        guard model.states[0].board.turn == human else { selected = model.states[0].board.squares[square]?.side == human ? square : nil; return }
        let state = model.states[0]
        let choices = state.moves.filter { $0.to == square && (drop != nil ? $0.drop == drop : selected != nil && $0.from == selected) }
        if choices.count > 1 {
            if autoQueen, let queen = choices.first(where: { $0.promotion == "q" }) { model.play(queen) }
            else { queuePromotion = false; promotions = choices }; return
        }
        if let move = choices.first { selected = nil; model.play(move); return }
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
            Section("Players") {
                Picker("Your color on board A", selection: $human) { Text("White").tag(Side.white); Text("Black").tag(Side.black) }.pickerStyle(.segmented)
                ForEach(0..<4, id: \.self) { seat in
                    let color: Side = seat.isMultiple(of: 2) ? .white : .black
                    let role = seat == BughouseConfig.seat(0, human) ? "You" : BughouseConfig.team(seat / 2, color) == (human == .white ? 0 : 1) ? "Partner" : "Opponent"
                    HStack { Text("\(seat < 2 ? "A" : "B") \(color.title) · \(role)").font(.caption); Spacer(); TextField("Strength", text: $ratings[seat]).keyboardType(.numberPad).frame(width: 75).textFieldStyle(.roundedBorder) }
                }
            }.listRowBackground(ThemeCardBackground())
            Section("Time control") {
                Toggle("Custom", isOn: $custom)
                if custom {
                    Stepper("Minutes: \(minutes)", value: $minutes, in: 0...180)
                    Stepper("Seconds: \(seconds)", value: $seconds, in: 0...59)
                    Stepper("Increment: \(increment) \(increment == 1 ? "second" : "seconds")", value: $increment, in: 0...60)
                } else { Picker("Preset", selection: $preset) { ForEach(Array(ClockTimeControl.presets.enumerated()), id: \.offset) { index, control in Text(control.title).tag(index) } } }
            }.listRowBackground(ThemeCardBackground())
            Section {
                Button("Start Bughouse") {
                    let values = ratings.compactMap(Int.init)
                    let control = custom ? ClockTimeControl(seconds: minutes * 60 + seconds, increment: increment) : ClockTimeControl.presets[preset]
                    let config = BughouseConfig(human: human, ratings: values, seconds: control.seconds, increment: control.increment)
                    do { try config.validate(); error = nil; start(config) } catch { self.error = error.localizedDescription }
                }.buttonStyle(ThemeActionButtonStyle()).disabled(custom && minutes * 60 + seconds == 0)
                if let error { Text(error).font(.caption).foregroundStyle(.red) }
            }.listRowBackground(ThemeCardBackground())
        }.scrollDismissesKeyboard(.interactively).modifier(AppSurface())
    }
}
