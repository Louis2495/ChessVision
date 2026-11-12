import SwiftUI

struct MoveBoard: View {
    var position: Position
    var enabled = true
    var flipped = false
    var hidePieces = false
    var premoveSide: Side? = nil
    var onMove: (ChessMove) -> Void
    @AppStorage("premoves") private var premovesEnabled = true
    @AppStorage("autoQueen") private var autoQueen = false
    @State private var selected: Int?
    @State private var promotions: [ChessMove] = []
    @State private var queue = PremoveQueue()
    @State private var composer = PremoveComposer()
    @State private var queuePromotion = false
    private var legal: [ChessMove] { enabled ? position.legalMoves() : [] }
    private var queuing: Bool { premovesEnabled && premoveSide != nil && (!enabled || !queue.moves.isEmpty || composer.selected != nil) }
    private var shown: Position { queuing ? queue.projected(position, side: premoveSide ?? position.turn) : position }
    var body: some View {
        BoardView(position: shown, selected: hidePieces ? nil : (queuing ? composer.selected : selected),
                  legalTargets: hidePieces ? [] : queuing ? Set(queue.moves.compactMap { VariantMove(uci: $0, san: "").to }) : Set(legal.filter { $0.from == selected }.map(\.to)),
                  flipped: flipped, hidePieces: hidePieces, onDragMove: drag, onTap: tap)
        .onChange(of: position.fen) { _, _ in if let square = selected, position.squares[square]?.side != (premoveSide ?? position.turn) { selected = nil }; if let square = composer.selected, shown.squares[square]?.side != premoveSide { composer.selected = nil }; if !queuePromotion { promotions = [] }; flush() }
        .onChange(of: premovesEnabled) { _, enabled in if !enabled { queue.clear(); composer = PremoveComposer() } }
        .onChange(of: premoveSide) { _, side in if side == nil { queue.clear(); composer = PremoveComposer() } }
        .onDisappear { queue.clear(); composer = PremoveComposer() }
        .sheet(isPresented: Binding(get: { !promotions.isEmpty }, set: { if !$0 { promotions = [] } })) {
            PromotionPicker(side: queuePromotion ? (premoveSide ?? position.turn) : position.turn, kinds: promotions.compactMap(\.promotion)) { kind in
                if let move = promotions.first(where: { $0.promotion == kind }) {
                    if queuePromotion { composer.complete(move.uci, duck: false, queue: &queue); queuePromotion = false; flush() }
                    else { selected = nil; onMove(move) }
                }
                promotions = []
            }
        }
    }
    private func drag(_ source: Int, _ target: Int) {
        guard shown.squares[source]?.side == (premoveSide ?? position.turn) else { return }
        if queuing { composer.selected = source; composer.drop = nil }
        else { selected = source }
        tap(target)
    }
    private func tap(_ index: Int) {
            if queuing {
                composer.tap(index, board: shown, side: premoveSide ?? position.turn, duck: false, queue: &queue)
                if !composer.promotions.isEmpty {
                    queuePromotion = true
                    promotions = composer.promotions.compactMap { move in
                        guard let from = move.from, let to = move.to else { return nil }
                        return ChessMove(from: from, to: to, promotion: move.promotion)
                    }
                }
                flush(); return
            }
            guard enabled else { selected = position.squares[index]?.side == premoveSide ? index : nil; return }
            if let from = selected {
                if from == index { selected = nil; return }
                let choices = legal.filter { $0.from == from && $0.to == index }
                if choices.count > 1 {
                    if autoQueen, let queen = choices.first(where: { $0.promotion == "q" }) { selected = nil; onMove(queen) }
                    else { queuePromotion = false; promotions = choices }; return
                }
                if let move = choices.first { selected = nil; onMove(move); return }
            }
            selected = position.squares[index]?.side == position.turn ? index : nil
    }
    private func flush() {
        guard enabled, position.turn == premoveSide, premovesEnabled else { return }
        let moves = legal.map { VariantMove(uci: $0.uci, san: "") }
        if let next = queue.take(legal: moves), let move = legal.first(where: { $0.uci == next.uci }) { onMove(move) }
    }
}

struct PromotionPicker: View {
    var side: Side
    var kinds: [Character]
    var choose: (Character) -> Void
    var body: some View {
        VStack(spacing: 24) {
            Text("Promote pawn").font(.title2.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], spacing: 12) {
                ForEach(Array("qrbnk").filter { kinds.contains($0) }, id: \.self) { kind in
                    let piece = Piece(side == .white ? Character(kind.uppercased()) : kind)
                    Button { choose(kind) } label: {
                        PieceView(piece: piece).frame(width: 44, height: 54).padding(8)
                            .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain).accessibilityLabel(piece.name)
                }
            }
        }.padding().modifier(AppSurface()).presentationDetents([.height(kinds.count > 4 ? 320 : 220)])
    }
}
