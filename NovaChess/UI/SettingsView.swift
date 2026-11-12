import SwiftUI
import AVFoundation

@MainActor final class ClassicalMusic {
    static let shared = ClassicalMusic()
    private var player: AVAudioPlayer?
    func setEnabled(_ enabled: Bool) {
        if !enabled { player?.pause(); try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation); return }
        if let player {
            try? AVAudioSession.sharedInstance().setActive(true)
            if !player.isPlaying { player.play() }
            return
        }
        guard let url = Bundle.main.url(forResource: "ClassicalPrelude", withExtension: "wav") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let audio = try AVAudioPlayer(contentsOf: url); audio.numberOfLoops = -1; audio.volume = 0.3
            audio.prepareToPlay(); audio.play(); player = audio
        } catch { player = nil }
    }
}

struct SettingsButton: View {
    @State private var showing = false
    var body: some View {
        Button { showing = true } label: { Image(systemName: "gearshape") }
            .accessibilityLabel("Settings")
            .sheet(isPresented: $showing) { NavigationStack { SettingsView() } }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("theme") private var theme = "Forest"
    @AppStorage("background") private var background = "Default"
    @AppStorage("boardStyle") private var board = "Classic"
    @AppStorage("pieceStyle") private var pieces = "Illustrated"
    @AppStorage("premoves") private var premoves = true
    @AppStorage("autoQueen") private var autoQueen = false
    @AppStorage("classicalMusic") private var music = false
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Display", selection: $appearance) { ForEach(["System", "Light", "Dark"], id: \.self) { Text($0) } }
                Picker("Theme", selection: $theme) { ForEach(AppTheme.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) } }
                Picker("Background", selection: $background) { ForEach(AppBackdrop.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) } }
            }.listRowBackground(ThemeCardBackground())
            Section("Chessboard") {
                Picker("Board", selection: $board) { ForEach(BoardStyle.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) } }
                Picker("Pieces", selection: $pieces) { ForEach(PieceStyle.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) } }
                BoardView(position: .initial).frame(maxWidth: 240).frame(maxWidth: .infinity).padding(.vertical, 8)
            }.listRowBackground(ThemeCardBackground())
            Section("Analysis") {
                Text("Stockfish 19 · NNUE").font(.headline)
            }.listRowBackground(ThemeCardBackground())
            Section("Moves") {
                Toggle("Premoves", isOn: $premoves)
                Text("Tap an unrelated square to cancel the last premove; tap again to cancel another.").font(.caption).foregroundStyle(.secondary)
                Toggle("Auto-queen", isOn: $autoQueen)
            }.listRowBackground(ThemeCardBackground())
            Section("Sound") {
                Toggle("Classical music", isOn: $music)
            }.listRowBackground(ThemeCardBackground())
            Section { NavigationLink("Privacy & licenses") { AppInfoView() } }.listRowBackground(ThemeCardBackground())
        }.modifier(AppSurface()).navigationTitle("Settings").toolbar { Button("Done") { dismiss() } }
    }
}

struct AppAppearance: ViewModifier {
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("theme") private var theme = "Forest"
    @AppStorage("background") private var background = "Default"
    @AppStorage("classicalMusic") private var music = false
    @Environment(\.scenePhase) private var phase
    @AppStorage("pieceStyle") private var pieces = "Illustrated"
    @Environment(\.colorScheme) private var scheme
    private var tint: Color {
        let base = Color(hex: (AppTheme(rawValue: theme) ?? .forest).hex)
        return (appearance == "Dark" || (appearance == "System" && scheme == .dark)) ? Color(uiColor: UIColor(base).withAdjustedBrightness()) : base
    }
    func body(content: Content) -> some View {
        content.accentColor(tint).tint(tint).preferredColorScheme(appearance == "Light" ? .light : appearance == "Dark" ? .dark : nil)
            .background { AppCanvas().ignoresSafeArea() }
            .onAppear {
                if PieceStyle(rawValue: pieces) == nil { pieces = PieceStyle.illustrated.rawValue }
                ClassicalMusic.shared.setEnabled(music && phase == .active)
            }
            .onChange(of: music) { _, enabled in ClassicalMusic.shared.setEnabled(enabled && phase == .active) }
            .onChange(of: phase) { _, value in ClassicalMusic.shared.setEnabled(music && value == .active) }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

struct AppCanvas: View {
    @AppStorage("background") private var background = "Default"
    @AppStorage("theme") private var theme = "Forest"
    @Environment(\.colorScheme) private var scheme
    private var backdrop: AppBackdrop { AppBackdrop(rawValue: background) ?? .standard }
    private var accent: Color { Color(hex: (AppTheme(rawValue: theme) ?? .forest).hex) }
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            if let hex = backdrop.hex { Color(hex: hex).opacity(scheme == .dark ? 0.10 : 0.07) }
            if backdrop == .theme { accent.opacity(scheme == .dark ? 0.10 : 0.06) }
            if backdrop == .aurora {
                LinearGradient(colors: [accent.opacity(0.16), Color.purple.opacity(0.10), Color.teal.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            if backdrop == .sunset {
                LinearGradient(colors: [Color.orange.opacity(0.12), Color.pink.opacity(0.12)], startPoint: .top, endPoint: .bottom)
            }
            if backdrop == .grid {
                Canvas { context, size in
                    var lines = Path()
                    for x in stride(from: CGFloat.zero, to: size.width, by: 28) { lines.move(to: CGPoint(x: x, y: 0)); lines.addLine(to: CGPoint(x: x, y: size.height)) }
                    for y in stride(from: CGFloat.zero, to: size.height, by: 28) { lines.move(to: CGPoint(x: 0, y: y)); lines.addLine(to: CGPoint(x: size.width, y: y)) }
                    context.stroke(lines, with: .color(accent.opacity(0.07)), lineWidth: 0.5)
                }
            }
        }
    }
}

struct ThemeCardBackground: View {
    var body: some View {
        Color(uiColor: .secondarySystemGroupedBackground).overlay(Color.accentColor.opacity(0.05))
    }
}

struct AppSurface: ViewModifier {
    @AppStorage("theme") private var theme = "Forest"
    @Environment(\.colorScheme) private var scheme
    private var bar: Color {
        Color(hex: (AppTheme(rawValue: theme) ?? .forest).hex).opacity(scheme == .dark ? 0.18 : 0.08)
    }
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden)
            .background { AppCanvas().ignoresSafeArea() }
            .toolbarBackground(bar, for: .navigationBar, .tabBar)
            .toolbarBackground(.visible, for: .navigationBar, .tabBar)
    }
}

private extension UIColor {
    func withAdjustedBrightness() -> UIColor {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return self }
        return UIColor(hue: hue, saturation: min(saturation, 0.55), brightness: max(brightness, 0.94), alpha: alpha)
    }
}
