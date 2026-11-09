import SwiftUI
import AVFoundation

@MainActor struct ContentView: View {
    @State private var camera = false
    @State private var processing = false
    @State private var position: Position?
    @State private var uncertain: Set<Int> = []
    @State private var photo: UIImage?
    @State private var message: String?
    @State private var lastPhoto: UIImage?
    @State private var turnConfirmed = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:24) {
                    if let board = position {
                        EditorView(position:board, uncertain:uncertain, photo:photo, onRetake:takePhoto)
                    } else {
                        VStack(alignment:.leading,spacing:12) {
                            Image(systemName:"camera.macro").font(.system(size:44)).foregroundStyle(.tint)
                            Text("Your board.\nA clearer next move.").font(.largeTitle.bold())
                            Text("Photograph a physical chessboard from above, review the position, then analyze privately on your iPhone.").foregroundStyle(.secondary)
                        }.padding(.top,24)
                        BoardView(position:.initial).accessibilityLabel("Example starting position")
                        Button(action:takePhoto) { Label("Take Pic of Board",systemImage:"camera.fill").frame(maxWidth:.infinity).padding(10) }.buttonStyle(.borderedProminent).controlSize(.large).disabled(processing)
                        Text("Include every corner • Keep the phone level • Avoid glare").font(.footnote).foregroundStyle(.secondary)
                        Text("Recognition is experimental. Review every piece before analysis. Photographs stay on your iPhone.").font(.footnote).foregroundStyle(.secondary)
                        NavigationLink("Explore the board editor with an example") { ScrollView { EditorView(position:.initial,uncertain:[],photo:nil,onRetake:takePhoto).padding() } }
                    }
                    if processing { ProgressView("Finding board and recognizing pieces…").frame(maxWidth:.infinity) }
                }.padding()
            }.navigationTitle("ChessVision")
            .toolbar { if position != nil { Button("Start over") { position = nil; photo = nil; uncertain = [] } } }
            .fullScreenCover(isPresented:$camera) { CameraView(onPhoto:{ image in camera=false; lastPhoto=image; process(image) },onCancel:{camera=false}).ignoresSafeArea() }
            .alert("ChessVision",isPresented:Binding(get:{message != nil},set:{if !$0 { message=nil }})) { Button("OK",role:.cancel) {} ; if lastPhoto != nil { Button("Retry recognition") { if let lastPhoto { process(lastPhoto) } } } } message:{Text(message ?? "")}
        }
    }
    private func takePhoto() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { message="A camera is not available here. Use a physical iPhone to photograph a board. The example editor works in Simulator."; return }
        Task {
            let granted = await AVCaptureDevice.requestAccess(for:.video)
            if granted { camera=true } else { message="Camera access is required. Enable it in Settings → ChessVision → Camera." }
        }
    }
    private func process(_ image: UIImage) {
        processing=true
        Task {
            do {
                let result = try await Task.detached(priority:.userInitiated) { try BoardRecognizer().recognize(image) }.value
                position=result.position; uncertain=result.uncertain; photo=result.image
            } catch { message=error.localizedDescription }
            processing=false
        }
    }
}

struct EditorView: View {
    @State var position: Position
    @State var uncertain: Set<Int>
    var photo: UIImage?
    var onRetake: () -> Void
    @State private var selected: Int?
    @State private var turnConfirmed = false
    @State private var seconds = 5
    @State private var showAnalysis = false
    @State private var acknowledgedBoundary = false
    @State private var movingFrom: Int?
    @State private var editingSquare: Int?
    private var issues: [String] { position.problems }
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Review position").font(.title2.bold())
            Text("White's home rank is at the bottom. Tap a square to correct it. Orange squares need your review.").font(.subheadline).foregroundStyle(.secondary)
            BoardView(position:position,uncertain:uncertain,selected:selected) { index in
                if let source = movingFrom { position.squares[index]=position.squares[source]; position.squares[source]=nil; uncertain.remove(source); uncertain.remove(index); movingFrom=nil; selected=nil }
                else { selected=index; editingSquare=index }
            }
            if let photo {
                DisclosureGroup("Compare with the corrected photograph") { Image(uiImage:photo).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius:12)) }
                Toggle("The detected crop contains exactly the 8 × 8 playing squares",isOn:$acknowledgedBoundary)
                Text("Check the crop carefully: a rectangular table edge or board border can be mistaken for the playing area.").font(.caption).foregroundStyle(.secondary)
                Button("Rotate recognized board 180°") { position.squares.reverse(); uncertain=Set(uncertain.map{63-$0}) }
            }
            if !uncertain.isEmpty { Text("\(uncertain.count) squares need review. Tap each highlighted square and choose its correct piece or Empty.").foregroundStyle(.orange) }
            Picker("Whose turn?",selection:$position.turn) { ForEach(Side.allCases,id:\.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            Toggle("I confirm whose turn it is",isOn:$turnConfirmed)
            DisclosureGroup("Game details: castling and en passant") {
                Text("A photograph cannot establish these rights. All castling rights start off after recognition.").font(.caption).foregroundStyle(.secondary)
                ForEach(["K","Q","k","q"],id:\.self) { right in
                    Toggle(["K":"White kingside", "Q":"White queenside", "k":"Black kingside", "q":"Black queenside"][right]!,isOn:Binding(get:{position.castling.contains(right)},set:{ enabled in position.castling.removeAll{String($0)==right}; if enabled {position.castling += right} }))
                }
                TextField("En passant target, or -",text:$position.enPassant).textInputAutocapitalization(.never).autocorrectionDisabled()
                Stepper("Halfmove clock: \(position.halfmove)",value:$position.halfmove,in:0...150)
                Stepper("Fullmove: \(position.fullmove)",value:$position.fullmove,in:1...999)
            }
            if !issues.isEmpty { VStack(alignment:.leading,spacing:6) { ForEach(issues,id:\.self) { Text($0).font(.footnote).foregroundStyle(.red) } } }
            Picker("Analysis time",selection:$seconds) { Text("3 seconds").tag(3);Text("5 seconds").tag(5);Text("15 seconds").tag(15) }
            Button { showAnalysis=true } label:{Label("Analyze with Stockfish",systemImage:"sparkle.magnifyingglass").frame(maxWidth:.infinity).padding(8)}.buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!issues.isEmpty || !uncertain.isEmpty || !turnConfirmed || (photo != nil && !acknowledgedBoundary))
            ShareLink(item:position.fen) { Label("Share FEN",systemImage:"square.and.arrow.up") }
            Text(position.fen).font(.caption.monospaced()).textSelection(.enabled)
            Button("Retake photograph",action:onRetake)
        }
        .sheet(isPresented:Binding(get:{editingSquare != nil},set:{if !$0 {editingSquare=nil}})) {
            if let index = editingSquare {
                VStack(spacing:20) {
                    Text("Correct \(Position.name(index))").font(.title2.bold())
                    LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:6)) {
                        ForEach(Array("KQRBNPkqrbnp"),id:\.self) { symbol in
                            Button { position.squares[index]=Piece(symbol); uncertain.remove(index); editingSquare=nil; selected=nil } label: { Text(Piece(symbol).glyph).font(.system(size:36)).frame(minHeight:48) }.accessibilityLabel(Piece(symbol).name)
                        }
                    }
                    Button("Empty square") {position.squares[index]=nil; uncertain.remove(index); editingSquare=nil; selected=nil}
                    if position.squares[index] != nil { Button("Move this piece…") {movingFrom=index; editingSquare=nil} }
                    Button("Cancel",role:.cancel) {editingSquare=nil; selected=nil}
                }.padding().presentationDetents([.medium])
            }
        }
        .navigationDestination(isPresented:$showAnalysis) { AnalysisView(original:position,seconds:seconds) }
    }
}
