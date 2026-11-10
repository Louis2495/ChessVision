import SwiftUI

struct MoveBoard: View {
    var position: Position
    var enabled = true
    var flipped = false
    var hidePieces = false
    var onMove: (ChessMove) -> Void
    @State private var selected: Int?
    @State private var promotions: [ChessMove] = []
    private var legal: [ChessMove] { enabled ? position.legalMoves() : [] }
    var body: some View {
        BoardView(position: position, selected: hidePieces ? nil : selected,
                  legalTargets: hidePieces ? [] : Set(legal.filter { $0.from == selected }.map(\.to)),
                  flipped: flipped, hidePieces: hidePieces) { index in
            guard enabled else { return }
            if let from = selected {
                if from == index { selected = nil; return }
                let choices = legal.filter { $0.from == from && $0.to == index }
                if choices.count > 1 { promotions = choices; return }
                if let move = choices.first { selected = nil; onMove(move); return }
            }
            selected = position.squares[index]?.side == position.turn ? index : nil
        }
        .onChange(of: position.fen) { _, _ in selected = nil; promotions = [] }
        .sheet(isPresented: Binding(get: { !promotions.isEmpty }, set: { if !$0 { promotions = [] } })) {
            PromotionPicker(side: position.turn, kinds: promotions.compactMap(\.promotion)) { kind in
                if let move = promotions.first(where: { $0.promotion == kind }) { selected = nil; onMove(move) }
                promotions = []
            }
        }
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
