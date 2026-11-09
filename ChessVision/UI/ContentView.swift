import SwiftUI
import AVFoundation

@MainActor struct ContentView: View {
    @State private var camera = false
    @State private var path: [String] = []
    @State private var processing = false
    @State private var recognitionTask: Task<Void, Never>?
    @State private var processingID = UUID()
    @State private var recognitionProgress = 0.0
    @State private var position: Position?
    @State private var uncertain: Set<Int> = []
    @State private var photo: UIImage?
    @State private var message: String?
    @State private var lastPhoto: UIImage?
    @State private var recognitionID = UUID()
    var body: some View {
        NavigationStack(path:$path) {
            ScrollView {
                VStack(alignment:.leading,spacing:24) {
                    if let board = position {
                        EditorView(position:board, uncertain:uncertain, photo:photo, onRetake:takePhoto, onRecognizeAgain:{ if let lastPhoto {process(lastPhoto)} }).id(recognitionID)
                    } else {
                        VStack(alignment:.leading,spacing:12) {
                            Image(systemName:"camera.macro").font(.system(size:44)).foregroundStyle(.tint)
                            Text("Your board.\nA clearer next move.").font(.largeTitle.bold())
                            Text("Photograph a physical chessboard from above, review the position, then analyze privately on your iPhone.").foregroundStyle(.secondary)
                        }.padding(.top,24)
                        BoardView(position:.initial).accessibilityLabel("Example starting position")
                        Button(action:takePhoto) { Label("Take Pic of Board",systemImage:"camera.fill").frame(maxWidth:.infinity).padding(10) }.buttonStyle(.borderedProminent).controlSize(.large).disabled(processing)
                        Text("Include every corner • Keep the phone level • Avoid glare").font(.footnote).foregroundStyle(.secondary)
                        Text("Recognition is experimental. Correct pieces if needed. Photographs stay on your iPhone.").font(.footnote).foregroundStyle(.secondary)
                        NavigationLink("Privacy & open-source licenses") {
                            ScrollView {
                                VStack(alignment:.leading,spacing:16) {
                                    Text("Private by design").font(.title.bold())
                                    Text("ChessVision does not upload photos, collect analytics, or require an account. Your photographs remain in memory on this device. Sharing a board image or FEN is an explicit action using the system share sheet. Opening explorer contacts the chosen chess site with the public username you enter. Puzzle progress, repertoire and computer games are stored only on this device.")
                                    Text(licenseText).font(.caption.monospaced()).textSelection(.enabled)
                                }.padding()
                            }.navigationTitle("Privacy & licenses")
                        }
                        NavigationLink("Explore the board editor with an example",value:"example")
                    }
                }.padding().disabled(processing)
            }.navigationTitle("ChessVision")
            .navigationDestination(for:String.self) { _ in ScrollView { EditorView(position:.initial,uncertain:[],photo:nil,onRetake:takePhoto).padding() } }
            .toolbar { if position != nil { Button("Start over") { recognitionTask?.cancel(); recognitionTask=nil; processingID=UUID(); processing=false; position = nil; photo = nil; uncertain = []; lastPhoto = nil } } }
            .fullScreenCover(isPresented:$camera) { CameraView(onPhoto:{ image in camera=false; lastPhoto=image; process(image) },onCancel:{camera=false}).ignoresSafeArea() }
            .alert("ChessVision",isPresented:Binding(get:{message != nil},set:{if !$0 { message=nil }})) { Button("OK",role:.cancel) {} ; if lastPhoto != nil { Button("Retry recognition") { if let lastPhoto { process(lastPhoto) } } } } message:{Text(message ?? "")}
            .overlay {
                if processing {
                    ZStack {
                        Color.black.opacity(0.16).ignoresSafeArea()
                        VStack(spacing: 14) {
                            ProgressView(value: recognitionProgress)
                            Text(recognitionProgress == 0 ? "Finding the board…" : "Recognizing squares: \(Int(recognitionProgress * 64))/64")
                                .font(.subheadline)
                            Button("Cancel") {
                                recognitionTask?.cancel(); recognitionTask = nil
                                processingID = UUID(); processing = false
                            }
                        }.padding(24).frame(maxWidth: 310).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
            }
        }
    }
    private var licenseText: String {
        guard let url=Bundle.main.url(forResource:"ThirdPartyNotices",withExtension:"txt"),let text=try? String(contentsOf:url,encoding:.utf8) else {return "License files accompany the project."}
        return text
    }
    private func takePhoto() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { message="A camera is not available here. Use a physical iPhone to photograph a board. The example editor works in Simulator."; return }
        Task {
            let granted = await AVCaptureDevice.requestAccess(for:.video)
            if granted { camera=true } else { message="Camera access is required. Enable it in Settings → ChessVision → Camera." }
        }
    }
    private func process(_ image: UIImage) {
        guard !processing else {return}
        let operation = UUID()
        processingID = operation; processing = true; recognitionProgress = 0
        recognitionTask = Task {
            let worker = Task.detached(priority: .userInitiated) {
                try BoardRecognizer().recognize(image, progress: { count in
                    Task { @MainActor in
                        if processingID == operation && processing { recognitionProgress = Double(count) / 64 }
                    }
                })
            }
            do {
                let result = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
                guard !Task.isCancelled && processingID == operation else { return }
                position = result.position; uncertain = result.uncertain; photo = result.image; recognitionID = UUID(); path = []
            } catch {
                if !Task.isCancelled && processingID == operation { message = error.localizedDescription }
            }
            if processingID == operation { processing = false; recognitionTask = nil }
        }
    }
}

struct EditorView: View {
    @State var position: Position
    @State var uncertain: Set<Int>
    var photo: UIImage?
    var onRetake: () -> Void
    var onRecognizeAgain: (() -> Void)? = nil
    @State private var selected: Int?
    @State private var showAnalysis = false
    @State private var movingFrom: Int?
    @State private var editingSquare: Int?
    private var issues: [String] { position.problems }
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Your position").font(.title2.bold())
            Text("White's home rank is at the bottom. Tap a square to correct it, or analyze the position now.").font(.subheadline).foregroundStyle(.secondary)
            BoardView(position:position,uncertain:uncertain,selected:selected) { index in
                if let source = movingFrom { if source == index { movingFrom=nil; selected=nil; return }; position.squares[index]=position.squares[source]; position.squares[source]=nil; uncertain.remove(source); uncertain.remove(index); movingFrom=nil; selected=nil }
                else { selected=index; editingSquare=index }
            }
            if let photo {
                DisclosureGroup("Compare with the corrected photograph") { Image(uiImage:photo).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius:12)) }

            }
            if !uncertain.isEmpty { Text("\(uncertain.count) uncertain squares are highlighted. You can analyze now, or tap a square to correct it.").foregroundStyle(.orange) }
            Picker("Whose turn?",selection:$position.turn) { ForEach(Side.allCases,id:\.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
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
            Button { showAnalysis=true } label:{Label("Analyze with Stockfish",systemImage:"sparkle.magnifyingglass").frame(maxWidth:.infinity).padding(8)}.buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!issues.isEmpty)
            SharePositionButton(position:position)
            Text(position.fen).font(.caption.monospaced()).textSelection(.enabled)
            if let onRecognizeAgain {Button("Recognize photo again",action:onRecognizeAgain)}
            Button("Retake photograph",action:onRetake)
        }
        .sheet(isPresented:Binding(get:{editingSquare != nil},set:{if !$0 {editingSquare=nil}})) {
            if let index = editingSquare {
                VStack(spacing:20) {
                    Text("Correct \(Position.name(index))").font(.title2.bold())
                    LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:6)) {
                        ForEach(Array("KQRBNPkqrbnp"),id:\.self) { symbol in
                            Button { position.squares[index]=Piece(symbol); uncertain.remove(index); editingSquare=nil; selected=nil } label: { PieceView(piece:Piece(symbol)).frame(width:42,height:48) }.accessibilityLabel(Piece(symbol).name)
                        }
                    }
                    Button("Empty square") {position.squares[index]=nil; uncertain.remove(index); editingSquare=nil; selected=nil}
                    if position.squares[index] != nil { Button("Move this piece…") {movingFrom=index; editingSquare=nil} }
                    Button("Cancel",role:.cancel) {editingSquare=nil; selected=nil}
                }.padding().presentationDetents([.medium])
            }
        }
        .navigationDestination(isPresented:$showAnalysis) { AnalysisView(original:position) }
    }
}
