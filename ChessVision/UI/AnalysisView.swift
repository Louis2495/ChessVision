import SwiftUI

private struct NotationRequest: Hashable {
    var fen: String
    var lines: [EngineLine]
}

struct AnalysisView: View {
    let original: Position
    let showsSettings: Bool
    @ObservedObject private var engine = EngineController.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var history: [Position]
    @State private var cursor = 0
    @State private var rank = 1
    @AppStorage("positionInsights") private var insights = false
    @State private var visible = false
    @State private var selected: Int?
    @State private var promotions: [ChessMove] = []
    @State private var notation: [Int: [NotatedMove]] = [:]
    @State private var notationFEN: String?
    @State private var message: String?

    init(original: Position, showsSettings: Bool = true) {
        self.showsSettings = showsSettings
        self.original = original
        _history = State(initialValue: [original])
    }
    private var position: Position { history[cursor] }
    private var liveLines: [EngineLine] { engine.analyzedFEN == position.fen ? engine.lines : [] }
    private var principal: EngineLine? { liveLines.first { $0.rank == 1 } }
    private var moves: [NotatedMove] { notationFEN == position.fen ? notation[rank] ?? [] : [] }
    private var legalTargets: Set<Int> {
        guard let selected else { return [] }
        return Set(position.legalMoves().filter { $0.from == selected }.map(\.to))
    }
    private var whiteFraction: Double {
        if position.legalMoves().isEmpty {
            return position.isInCheck ? (position.turn == .white ? 0 : 1) : 0.5
        }
        return EvaluationScale.whiteFraction(centipawns: principal?.centipawns, mate: principal?.mate)
    }
    private var evaluation: String {
        if position.legalMoves().isEmpty { return position.isInCheck ? (position.turn == .white ? "−M0" : "+M0") : "0.00" }
        return principal?.evaluation ?? "—"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                EvaluatedBoard(position: position, whiteFraction: whiteFraction, selected: selected, legalTargets: legalTargets, onTap: tapSquare)
                HistorySwipeBar(current: cursor, total: history.count - 1, canAdvance: cursor + 1 < history.count || !moves.isEmpty,
                                back: { if cursor > 0 { cursor -= 1 } }, forward: advance)
                HStack(alignment: .firstTextBaseline) {
                    Text(evaluation).font(.largeTitle.bold().monospacedDigit()).accessibilityIdentifier("analysis-evaluation")
                    Spacer()
                    Button(action: flipTurn) { TurnBadge(side: position.turn) }
                        .buttonStyle(.plain)
                        .accessibilityHint("Double tap to change whose turn it is")
                }
                if let terminal = engine.terminal, engine.analyzedFEN == position.fen {
                    Text(terminal).font(.headline)
                } else {
                    HStack(spacing: 6) {
                        if engine.running { Circle().fill(.green).frame(width: 6, height: 6) }
                        Text(engine.running ? "Analyzing continuously · Depth \(principal?.depth ?? 0)" : "Preparing analysis…")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let error = engine.error { Text(error).foregroundStyle(.red) }
                Toggle("Position insights", isOn: $insights)
                if insights {
                    let observations = PositionInsights.observations(in: position)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("On the board").font(.headline)
                        if observations.isEmpty { Text("No clear undefended pieces or pawn-blocked bishops found.").foregroundStyle(.secondary) }
                        ForEach(observations, id: \.self) { Text($0).font(.subheadline) }
                    }.padding().background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                }
                DisclosureGroup("Candidate lines") {
                if let move = moves.first {
                    Text("\(rank == 1 ? "Best move" : "Candidate move"): \(move.san)").font(.headline)
                }
                Picker("Variation", selection: $rank) {
                    ForEach(1...3, id: \.self) { number in
                        Text("\(number) · \(liveLines.first { $0.rank == number }?.evaluation ?? "—")").tag(number)
                    }
                }.pickerStyle(.segmented)
                VariationTable(moves: moves, rootFEN: position.fen, onSelect: playThrough)
                }
                Button("Return to original position") { history = [original]; cursor = 0; selected = nil }
                    .disabled(cursor == 0 && position == original)
                SharePositionButton(position: position)
                if let message { Text(message).font(.footnote).foregroundStyle(.red) }
            }.padding()
        }
        .modifier(AppSurface()).navigationTitle("Analysis")
        .toolbar { if showsSettings { SettingsButton() } }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            visible = true
            if scenePhase == .active { engine.analyze(position) }
        }
        .onChange(of: position.fen) { _, _ in
            selected = nil; promotions = []; message = nil
            if visible && scenePhase == .active { engine.analyze(position) }
        }
        .task(id: NotationRequest(fen: position.fen, lines: liveLines)) {
            let root = position, lines = liveLines
            // SAN involves legal-move generation; keep it off the UI/engine callback queue.
            let worker = Task.detached(priority: .userInitiated) { () -> [Int: [NotatedMove]] in
                var result: [Int: [NotatedMove]] = [:]
                for line in lines {
                    if Task.isCancelled { return [:] }
                    if let moves = try? ChessNotation.variation(line.moves, from: root) { result[line.rank] = moves }
                }
                return result
            }
            let formatted = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
            guard !Task.isCancelled else { return }
            notation = formatted; notationFEN = root.fen
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && visible { engine.analyze(position) } else if visible { engine.stopAnalysis() }
        }
        .onDisappear { visible = false; engine.stopAnalysis() }
        .sheet(isPresented: Binding(get: { !promotions.isEmpty }, set: { if !$0 { promotions = [] } })) {
            PromotionPicker(side: position.turn, kinds: promotions.compactMap(\.promotion)) { kind in
                if let move = promotions.first(where: { $0.promotion == kind }) { play(move) }
                promotions = []
            }
        }
    }
    private func advance() {
        if cursor + 1 < history.count { cursor += 1 }
        else if let first = moves.first { playThrough(first, line: moves, fen: position.fen) }
    }
    private func flipTurn() {
        var changed = position
        changed.turn = changed.turn.opposite
        changed.enPassant = "-"
        history = Array(history.prefix(cursor)) + [changed]
    }
    private func tapSquare(_ index: Int) {
        if let source = selected {
            if source == index { selected = nil; return }
            let choices = position.legalMoves().filter { $0.from == source && $0.to == index }
            if choices.count > 1 { promotions = choices; return }
            if let move = choices.first { play(move); return }
        }
        selected = position.squares[index]?.side == position.turn ? index : nil
    }
    private func play(_ move: ChessMove) {
        do {
            let next = try position.playing(move)
            history = Array(history.prefix(cursor + 1)) + [next]; cursor += 1; selected = nil
        } catch { message = error.localizedDescription }
    }
    private func playThrough(_ target: NotatedMove, line: [NotatedMove], fen: String) {
        guard fen == position.fen else { return }
        do {
            var board = position
            var continuation: [Position] = []
            for step in line.prefix(target.id + 1) { board = try board.playing(step.move); continuation.append(board) }
            history = Array(history.prefix(cursor + 1)) + continuation; cursor += continuation.count; selected = nil
        } catch { message = error.localizedDescription }
    }
}

private struct VariationTable: View {
    var moves: [NotatedMove]
    var rootFEN: String
    var onSelect: (NotatedMove, [NotatedMove], String) -> Void
    private var numbers: [Int] { Array(Set(moves.map(\.number))).sorted() }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("#").frame(width: 30, alignment: .leading)
                Text("White").frame(maxWidth: .infinity, alignment: .leading)
                Text("Black").frame(maxWidth: .infinity, alignment: .leading)
            }.font(.caption.bold()).foregroundStyle(.secondary).padding(.vertical, 9)
            Divider()
            ForEach(numbers, id: \.self) { number in
                HStack(spacing: 8) {
                    Text(String(number)).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 30, alignment: .leading)
                    cell(moves.first { $0.number == number && $0.side == .white })
                    cell(moves.first { $0.number == number && $0.side == .black })
                }.padding(.vertical, 7)
                Divider().opacity(0.5)
            }
            if moves.isEmpty { Text("Waiting for a continuation…").font(.footnote).foregroundStyle(.secondary).padding(.vertical, 14) }
        }
    }
    @ViewBuilder private func cell(_ move: NotatedMove?) -> some View {
        if let move {
            Button { onSelect(move, moves, rootFEN) } label: {
                Text(move.san).font(.body.monospaced()).frame(maxWidth: .infinity, minHeight: 30, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Move \(move.number), \(move.side.title), \(move.san)")
        } else { Text("—").foregroundStyle(.tertiary).frame(maxWidth: .infinity, minHeight: 30, alignment: .leading) }
    }
}


private struct HistorySwipeBar: View {
    var current: Int
    var total: Int
    var canAdvance: Bool
    var back: () -> Void
    var forward: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Button(action: back) { Image(systemName: "chevron.left") }.disabled(current == 0).accessibilityLabel("Previous position")
            VStack(spacing: 4) {
                Text("Swipe through the game · \(current)/\(total)").font(.caption2).foregroundStyle(.secondary)
                GeometryReader { geometry in
                    Capsule().fill(Color.gray.opacity(0.18))
                        .overlay(alignment: .leading) { Capsule().fill(Color.accentColor).frame(width: geometry.size.width * CGFloat(current) / CGFloat(max(1, total))) }
                }.frame(height: 5)
            }
            Button(action: forward) { Image(systemName: "chevron.right") }.disabled(!canAdvance).accessibilityLabel("Next position")
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 18).onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height) else { return }
            if value.translation.width < 0 && canAdvance { forward() }
            else if value.translation.width > 0 && current > 0 { back() }
        })
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analysis-history-bar")
    }
}
