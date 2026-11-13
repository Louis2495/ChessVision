import SwiftUI
import AVFoundation
import PhotosUI

@MainActor struct ContentView: View {
    @StateObject private var savedPhotos = SavedPhotoStore()
    @State private var photosPresented = false
    @State private var saveForLater = false
    @State private var photoChoice = false
    @State private var awaitingPhotoChoice = false
    @State private var pendingSavedImage: UIImage?
    @State private var pendingCaptureError: String?
    @State private var captureNotice: String?
    @AppStorage("screenRecognition") private var screenRecognition = false
    @AppStorage("recognitionBlackAtBottom") private var blackAtBottom = false
    @State private var importPhoto = false
    @State private var importedPhoto: PhotosPickerItem?
    @State private var camera = false
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
        NavigationStack() {
            screen
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 20) {
                            Menu {
                                Picker("Board type", selection: $screenRecognition) { Text("Physical board").tag(false); Text("Screen / screenshot").tag(true) }
                                Toggle("Black at bottom", isOn: $blackAtBottom)
                                Button("Import screenshot", systemImage: "photo") { importPhoto = true }

                                NavigationLink { LiveGameCameraView() } label: { Label("Record game notation", systemImage: "video") }
                                NavigationLink { SavedGamesView() } label: { Label("Saved games", systemImage: "folder") }
                                Button("Take photo", systemImage: "camera") { saveForLater = false; takePhoto() }
                                Button("Take photos for later", systemImage: "clock") { saveForLater = true; takePhoto() }
                                if position != nil { Button("Start over", systemImage: "arrow.counterclockwise", action: startOver) }
                            } label: { Image(systemName: "camera") }.accessibilityLabel("Scan board")
                            SettingsButton()
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button { savedPhotos.refresh(); photosPresented = true } label: { Label("Photos", systemImage: "photo.stack") }.accessibilityLabel("Saved photos")
                    }
                }
                .fullScreenCover(isPresented: $camera, onDismiss: {
                    if let error = pendingCaptureError { pendingCaptureError = nil; message = error }
                    else if awaitingPhotoChoice { awaitingPhotoChoice = false; photoChoice = true }
                }) {
                    CameraView(screen: screenRecognition, onPhoto: capturedPhoto, onCancel: { camera = false }).ignoresSafeArea()
                }
                .photosPicker(isPresented: $importPhoto, selection: $importedPhoto, matching: .images)
                .onChange(of: importedPhoto) { _, item in
                    guard let item else { return }
                    Task {
                        do {
                            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw RecognitionFailure(message: "The selected image could not be opened.") }
                            screenRecognition = true; let normalized = CameraView.normalized(image); lastPhoto = normalized; process(normalized)
                        } catch { message = error.localizedDescription }
                        importedPhoto = nil
                    }
                }
                .sheet(isPresented: $photosPresented, onDismiss: {
                    if let image = pendingSavedImage { pendingSavedImage = nil; lastPhoto = image; process(image) }
                }) {
                    NavigationStack { SavedPhotosView(store: savedPhotos) { image in pendingSavedImage = image; photosPresented = false }.toolbar { Button("Done") { photosPresented = false } } }
                }
                .confirmationDialog("When would you like to analyze this photo?", isPresented: $photoChoice, titleVisibility: .visible) {
                    Button("Analyze now") { if let lastPhoto { process(lastPhoto) } }
                    Button("Save for later") { saveCapturedPhoto() }
                    Button("Save and take another") { if saveCapturedPhoto() { saveForLater = true; takePhoto() } }
                    Button("Discard", role: .cancel) { lastPhoto = nil }
                }
                .safeAreaInset(edge: .bottom) {
                    if let captureNotice {
                        HStack { Text(captureNotice).font(.caption); Spacer(); Button("Take another") { saveForLater = true; takePhoto() }; Button("Done") { self.captureNotice = nil } }.padding(12).background(.regularMaterial)
                    }
                }
                .alert("NovaChess", isPresented: showingMessage) {
                    Button("OK", role: .cancel) { }
                    if lastPhoto != nil { Button("Retry recognition", action: retryRecognition) }
                } message: { Text(message ?? "") }
                .overlay {
                    if processing {
                        RecognitionProgressOverlay(progress: recognitionProgress, cancel: cancelRecognition)
                    }
                }
        }
    }
    @ViewBuilder private var screen: some View {
        if let board = position {
            ScrollView {
                EditorView(position: board, uncertain: uncertain, photo: photo,
                           onRetake: { saveForLater = false; takePhoto() }, onRecognizeAgain: retryRecognition)
                    .id(recognitionID).padding()
            }.modifier(AppSurface()).navigationTitle("Analysis").disabled(processing)
        } else {
            AnalysisView(original: .initial, showsSettings: false).disabled(processing)
        }
    }
    private var showingMessage: Binding<Bool> {
        Binding(get: { message != nil }, set: { if !$0 { message = nil } })
    }
    private func cancelRecognition() {
        recognitionTask?.cancel(); recognitionTask = nil
        processingID = UUID(); processing = false
    }
    private func startOver() {
        cancelRecognition()
        position = nil; photo = nil; uncertain = []; lastPhoto = nil
    }
    private func capturedPhoto(_ image: UIImage) {
        lastPhoto = image
        if saveForLater { _ = saveCapturedPhoto() } else { awaitingPhotoChoice = true }
        camera = false
    }
    @discardableResult private func saveCapturedPhoto() -> Bool {
        guard let lastPhoto else { return false }
        if savedPhotos.save(lastPhoto) { captureNotice = "\(CountText.value(savedPhotos.photos.count, "photo")) saved for later"; return true }
        if camera { pendingCaptureError = savedPhotos.error } else { message = savedPhotos.error }; return false
    }
    private func retryRecognition() { if let lastPhoto { process(lastPhoto) } }
    private func takePhoto() {
        captureNotice = nil
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { message="A camera is not available here. Use a physical iPhone to photograph a board. You can play on the analysis board in Simulator."; return }
        Task {
            let granted = await AVCaptureDevice.requestAccess(for:.video)
            if granted { camera=true } else { message="Camera access is required. Enable it in Settings → NovaChess → Camera." }
        }
    }
    private func process(_ image: UIImage) {
        guard !processing else {return}
        let operation = UUID()
        processingID = operation; processing = true; recognitionProgress = 0
        let useScreen = screenRecognition, flipped = blackAtBottom
        recognitionTask = Task {
            let worker = Task.detached(priority: .userInitiated) {
                try BoardRecognizer().recognize(image, screen: useScreen, blackAtBottom: flipped, progress: { count in
                    Task { @MainActor in
                        if processingID == operation && processing { recognitionProgress = Double(count) / 64 }
                    }
                })
            }
            do {
                let result = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
                guard !Task.isCancelled && processingID == operation else { return }
                position = result.position; uncertain = result.uncertain; photo = result.image; recognitionID = UUID()
            } catch {
                if !Task.isCancelled && processingID == operation { message = error.localizedDescription }
            }
            if processingID == operation { processing = false; recognitionTask = nil }
        }
    }
}

private struct RecognitionProgressOverlay: View {
    let progress: Double
    let cancel: () -> Void
    private var status: String {
        if progress <= 0 { return "Finding the board…" }
        let squares = Int(min(1, max(0, progress)) * 64)
        return "Recognizing squares: \(squares)/64"
    }
    var body: some View {
        ZStack {
            Color.black.opacity(0.16).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView(value: progress)
                Text(verbatim: status).font(.subheadline)
                Button("Cancel", action: cancel)
            }
            .padding(24)
            .frame(maxWidth: 310)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
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
            BoardView(position:position,uncertain:uncertain,selected:selected, onDragMove: { source, target in
                position.squares[target] = position.squares[source]; position.squares[source] = nil
                uncertain.remove(source); uncertain.remove(target); movingFrom = nil; selected = nil; editingSquare = nil
            }) { index in
                if let source = movingFrom { if source == index { movingFrom=nil; selected=nil; return }; position.squares[index]=position.squares[source]; position.squares[source]=nil; uncertain.remove(source); uncertain.remove(index); movingFrom=nil; selected=nil }
                else { selected=index; editingSquare=index }
            }
            if let photo {
                DisclosureGroup("Compare with the corrected photograph") { Image(uiImage:photo).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius:12)) }

            }
            if !uncertain.isEmpty { Text("\(CountText.value(uncertain.count, "uncertain square")) \(uncertain.count == 1 ? "is" : "are") highlighted. You can analyze now, or tap a square to correct it.").foregroundStyle(.orange) }
            Picker("Whose turn?",selection:$position.turn) { ForEach(Side.allCases,id:\.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            gameDetails
            if !issues.isEmpty { VStack(alignment:.leading,spacing:6) { ForEach(issues,id:\.self) { Text($0).font(.footnote).foregroundStyle(.red) } } }
            Button { showAnalysis=true } label:{Label("Analyze with Stockfish",systemImage:"sparkle.magnifyingglass").frame(maxWidth:.infinity).padding(8)}.buttonStyle(ThemeActionButtonStyle()).controlSize(.large)
                .disabled(!issues.isEmpty)
            SharePositionButton(position:position)
            Text(position.fen).font(.caption.monospaced()).textSelection(.enabled)
            if let onRecognizeAgain {Button("Recognize photo again",action:onRecognizeAgain)}
            Button("Retake photograph",action:onRetake)
        }
        .sheet(isPresented: editingPresented) { correctionSheet }
        .navigationDestination(isPresented:$showAnalysis) { AnalysisView(original:position) }
    }
    private var editingPresented: Binding<Bool> {
        Binding(get: { editingSquare != nil }, set: { if !$0 { editingSquare = nil } })
    }
    @ViewBuilder private var correctionSheet: some View {
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
            }.padding().modifier(AppSurface()).presentationDetents([.medium])
        }
    }
    private var gameDetails: some View {
        DisclosureGroup("Game details: castling and en passant") {
            Text("A photograph cannot establish these rights. All castling rights start off after recognition.").font(.caption).foregroundStyle(.secondary)
            ForEach(["K","Q","k","q"],id:\.self) { right in
                Toggle(["K":"White kingside", "Q":"White queenside", "k":"Black kingside", "q":"Black queenside"][right]!,isOn:Binding(get:{position.castling.contains(right)},set:{ enabled in position.castling.removeAll{String($0)==right}; if enabled {position.castling += right} }))
            }
            TextField("En passant target, or -",text:$position.enPassant).textInputAutocapitalization(.never).autocorrectionDisabled()
            Stepper("Halfmove clock: \(position.halfmove)",value:$position.halfmove,in:0...150)
            Stepper("Fullmove: \(position.fullmove)",value:$position.fullmove,in:1...999)
        }
    }

}
