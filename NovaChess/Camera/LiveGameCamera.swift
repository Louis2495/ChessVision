import SwiftUI
import AVFoundation
import UIKit

/// Capture and recognition stay on a serial queue; the UI receives completed observations only.
final class LiveBoardCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.novachess.record-board")
    private let context = CIContext()
    private var lastFrame = Date.distantPast
    private var active = false
    private let lock = NSLock()
    private var requested = false
    private func wantsCapture() -> Bool { lock.lock(); defer { lock.unlock() }; return requested }
    private var callback: (@Sendable (RecognitionResult?, String?) -> Void)?
    private var bottomIsBlack = false
    var observation: (@Sendable (RecognitionResult?, String?) -> Void)? {
        get { lock.lock(); defer { lock.unlock() }; return callback }
        set { lock.lock(); callback = newValue; lock.unlock() }
    }
    var blackAtBottom: Bool {
        get { lock.lock(); defer { lock.unlock() }; return bottomIsBlack }
        set { lock.lock(); bottomIsBlack = newValue; lock.unlock() }
    }
    func start() {
        lock.lock(); requested = true; lock.unlock()
        AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
            guard let self else { return }
            guard allowed else { self.observation?(nil, "Allow camera access in Settings to record a board."); return }
            self.queue.async {
                guard self.wantsCapture() else { return }
                do {
                    if self.session.inputs.isEmpty {
                        self.session.beginConfiguration()
                        self.session.sessionPreset = .photo
                        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { self.session.commitConfiguration(); throw ChessError.invalid("No rear camera is available.") }
                        let input = try AVCaptureDeviceInput(device: camera)
                        let output = AVCaptureVideoDataOutput(); output.alwaysDiscardsLateVideoFrames = true
                        guard self.session.canAddInput(input), self.session.canAddOutput(output) else { self.session.commitConfiguration(); throw ChessError.invalid("The camera could not be configured.") }
                        self.session.addInput(input); self.session.addOutput(output)
                        output.setSampleBufferDelegate(self, queue: self.queue)
                        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
                        self.session.commitConfiguration()
                    }
                    self.active = true; self.session.startRunning()
                } catch { self.observation?(nil, error.localizedDescription) }
            }
        }
    }
    func stop() { lock.lock(); requested = false; callback = nil; lock.unlock(); queue.async { self.active = false; self.session.stopRunning() } }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard active, Date().timeIntervalSince(lastFrame) >= 2, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrame = Date()
        let image = CIImage(cvPixelBuffer: buffer)
        guard let cg = context.createCGImage(image, from: image.extent) else { return }
        do { observation?(try BoardRecognizer().recognize(UIImage(cgImage: cg), blackAtBottom: blackAtBottom), nil) }
        catch { observation?(nil, "Keep all 64 squares visible and wait until hands are clear.") }
    }
}
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    final class Preview: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
    func makeUIView(context: Context) -> Preview { let view = Preview(); view.preview.session = session; view.preview.videoGravity = .resizeAspect; return view }
    func updateUIView(_ uiView: Preview, context: Context) {}
}
struct LiveGameCameraView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.scenePhase) private var phase
    @State private var capture = LiveBoardCapture()
    @State private var tracker = CameraGameTracker()
    @State private var recording = false
    @State private var blackAtBottom = false
    @State private var message = "Place the phone beside the board with all four corners visible. Start from the normal starting position."
    @State private var save = false
    @State private var title = "Recorded game"
    @State private var manualMove = ""
    @State private var savedID: UUID?
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CameraPreview(session: capture.session).frame(height: 280).clipShape(RoundedRectangle(cornerRadius: 16))
                Text(message).font(.callout).foregroundStyle(.secondary)
                Toggle("Black nearest camera", isOn: $blackAtBottom).disabled(recording)
                HStack {
                    Button(recording ? "Pause" : "Record", systemImage: recording ? "pause.fill" : "record.circle") {
                        if recording { stop() } else { start() }
                    }.buttonStyle(ThemeActionButtonStyle())
                    Button("Undo last move") { tracker.undo() }.disabled(recording || tracker.notation.isEmpty)
                    Button("Save", systemImage: "folder.badge.plus") { stop(); save = true }.disabled(tracker.notation.isEmpty)
                }
                if !recording {
                    HStack {
                        TextField("Recover a missed move (e4, Nf3…)", text: $manualMove).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button("Add") {
                            do { try tracker.recordManual(manualMove.trimmingCharacters(in: .whitespacesAndNewlines)); manualMove = "" }
                            catch { message = error.localizedDescription }
                        }.disabled(manualMove.isEmpty)
                    }
                }
                BoardView(position: tracker.board).aspectRatio(1, contentMode: .fit)
                Text(tracker.notation.enumerated().map { i, move in (i % 2 == 0 ? "\(i / 2 + 1). " : "") + move }.joined(separator: " ")).frame(maxWidth: .infinity, alignment: .leading)
                NavigationLink("Saved games") { SavedGamesView() }
            }.padding()
        }.navigationTitle("Record game").modifier(AppSurface())
        .onDisappear { stop(); UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: recording) { _, active in UIApplication.shared.isIdleTimerDisabled = active }
        .onChange(of: phase) { _, value in if value != .active { stop() } }
        .alert("Save game", isPresented: $save) {
            TextField("Game name", text: $title)
            Button("Save") {
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                var game = SavedBoardGame(title: trimmed.isEmpty ? "Recorded game" : String(trimmed.prefix(100)), positions: tracker.positions.map(\.fen), notation: tracker.notation)
                if let savedID { game.id = savedID }
                library.state.savedGames.removeAll { $0.id == game.id }; library.state.savedGames.insert(game, at: 0); savedID = game.id
                message = "Saved. Open Saved games to organize it into a folder."
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    private func stop() { recording = false; capture.stop() }
    private func start() {
        capture.blackAtBottom = blackAtBottom
        capture.observation = { result, error in
            Task { @MainActor in
                guard recording else { return }
                if let result {
                    do {
                        if try tracker.observe(result.position.squares, uncertain: result.uncertain) { message = "Recorded \(tracker.notation.last ?? ""). \(tracker.board.turn.title) to move." }
                        else { message = "Watching for the next legal move. Leave each completed move visible for a few seconds." }
                    } catch { message = error.localizedDescription }
                } else {
                    message = error ?? "Waiting for the board."
                    if !capture.session.isRunning { stop() }
                }
            }
        }
        recording = true; capture.start()
    }
}
