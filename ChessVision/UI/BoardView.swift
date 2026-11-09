import SwiftUI
struct BoardView: View {
    var position: Position
    var uncertain: Set<Int> = []
    var selected: Int? = nil
    var flipped = false
    var onTap: ((Int) -> Void)? = nil
    var body: some View {
        GeometryReader { geometry in
            let cell = geometry.size.width/8
            VStack(spacing:0) {
                ForEach(0..<8,id: \.self) { row in
                    HStack(spacing:0) {
                        ForEach(0..<8,id: \.self) { col in
                            let index = flipped ? 63-(row*8+col) : row*8+col
                            Button { onTap?(index) } label: {
                                ZStack(alignment:.bottomLeading) {
                                    Rectangle().fill((index/8+index%8).isMultiple(of:2) ? Color(red:0.89,green:0.87,blue:0.79) : Color(red:0.36,green:0.47,blue:0.40))
                                    if let p = position.squares[index] {
                                        Text(p.glyph).font(.system(size:cell*0.79)).foregroundStyle(p.side == .white ? Color.white : Color.black).shadow(color:p.side == .white ? .black : .white.opacity(0.5),radius:1)
                                            .frame(width:cell,height:cell)
                                    }
                                    if uncertain.contains(index) { Rectangle().strokeBorder(Color.orange,lineWidth:3) }
                                    if selected == index { Rectangle().strokeBorder(Color.cyan,lineWidth:4) }
                                    if col == 0 || row == 7 { Text(Position.name(index)).font(.system(size:max(8,cell*0.17),weight:.semibold)).foregroundStyle(.black.opacity(0.65)).padding(2) }
                                }.frame(width:cell,height:cell)
                            }.buttonStyle(.plain).accessibilityLabel("\(Position.name(index)), \(position.squares[index]?.name ?? "empty")\(uncertain.contains(index) ? ", needs review" : "")")
                        }
                    }
                }
            }
        }.aspectRatio(1,contentMode:.fit).clipShape(RoundedRectangle(cornerRadius:12))
    }
}
