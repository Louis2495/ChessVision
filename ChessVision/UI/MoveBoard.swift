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
        .confirmationDialog("Promote pawn", isPresented: Binding(get: { !promotions.isEmpty }, set: { if !$0 { promotions = [] } }), titleVisibility: .visible) {
            ForEach(promotions, id: \.self) { move in
                Button(String(move.promotion ?? "q").uppercased()) { selected = nil; onMove(move); promotions = [] }
            }
        }
    }
}
