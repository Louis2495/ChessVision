import SwiftUI

@MainActor struct ChessClockView: View {
    @State private var clock = ChessClock()
    @State private var visible = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var setup = false
    @State private var resetting = false
    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                let now = ProcessInfo.processInfo.systemUptime
                VStack(spacing: 16) {
                    face(.black, now: now).rotationEffect(.degrees(180))
                    controls(now: now)
                    face(.white, now: now)
                }.padding().onChange(of: clock.flagged(at: now)) { _, _ in updateScreenAwake() }
            }
            .modifier(AppSurface()).navigationTitle("Clock").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Time control") { setup = true } }
                ToolbarItem(placement: .topBarTrailing) { SettingsButton() }
            }
            .onAppear { visible = true; updateScreenAwake() }
            .onDisappear { visible = false; UIApplication.shared.isIdleTimerDisabled = false }
            .onChange(of: clock.phase) { _, _ in updateScreenAwake() }
            .onChange(of: scenePhase) { _, _ in updateScreenAwake() }
            .sheet(isPresented: $setup) { ClockSetupView { control in clock = ChessClock(control: control) } }
            .confirmationDialog("Reset both clocks?", isPresented: $resetting, titleVisibility: .visible) {
                Button("Reset clock", role: .destructive) { clock = ChessClock(control: clock.control) }
            }
        }
    }
    private func updateScreenAwake() {
        UIApplication.shared.isIdleTimerDisabled = visible && scenePhase == .active && clock.phase == .running && clock.flagged(at: ProcessInfo.processInfo.systemUptime) == nil
    }
    private func face(_ side: Side, now: Double) -> some View {
        let flagged = clock.flagged(at: now)
        let active = clock.phase == .running && clock.active == side && flagged == nil
        return Button { clock.press(side, at: ProcessInfo.processInfo.systemUptime) } label: {
            VStack(spacing: 12) {
                Text(side.title).font(.headline)
                Text(time(clock.remaining(for: side, at: now))).font(.system(size: 74, weight: .bold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.45).lineLimit(1)
                Text(flagged == side ? "Time expired" : active ? "Your clock is running · tap after your move" : clock.phase == .ready ? "Tap to start your opponent's clock" : " ").font(.caption)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).padding(20)
            .foregroundStyle(side == .white ? Color.black : Color.white)
            .background(side == .white ? Color(white: 0.97) : Color(white: 0.12), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(flagged == side ? Color.red : active ? Color.accentColor : Color.gray.opacity(0.35), lineWidth: active || flagged == side ? 4 : 1))
        }.buttonStyle(.plain)
            .accessibilityLabel("\(side.title), \(time(clock.remaining(for: side, at: now)))\(active ? ", running" : "")")
            .accessibilityIdentifier("clock-\(side.rawValue)")
    }
    private func controls(now: Double) -> some View {
        HStack {
            Button("Reset", systemImage: "arrow.counterclockwise") { resetting = true }
            Spacer()
            VStack(spacing: 4) {
                Text(clock.control.title).font(.headline.monospacedDigit())
                if let loser = clock.flagged(at: now) { Text("\(loser.opposite.title) wins on time").font(.caption.bold()) }
            }
            Spacer()
            Button(clock.phase == .running ? "Pause" : clock.phase == .ready ? "Start" : "Resume", systemImage: clock.phase == .running ? "pause.fill" : "play.fill") {
                let time = ProcessInfo.processInfo.systemUptime
                if clock.phase == .running { clock.pause(at: time) } else { clock.start(at: time) }
            }.disabled(clock.flagged(at: now) != nil)
        }.buttonStyle(.bordered).controlSize(.large)
    }
    private func time(_ seconds: Double) -> String {
        let rounded = Int(ceil(max(0, seconds)))
        return String(format: "%d:%02d", rounded / 60, rounded % 60)
    }
}

private struct ClockSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected = 4
    @State private var custom = false
    @AppStorage("clockMinutes") private var minutes = 5
    @AppStorage("clockSeconds") private var seconds = 0
    @AppStorage("clockIncrement") private var increment = 0
    let apply: (ClockTimeControl) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("Time control") {
                    Toggle("Custom time control", isOn: $custom)
                    if custom {
                        Stepper("Minutes: \(minutes)", value: $minutes, in: 0...180)
                        Stepper("Seconds: \(seconds)", value: $seconds, in: 0...59)
                        Stepper("Increment: \(increment) seconds", value: $increment, in: 0...60)
                    } else {
                        Picker("Preset · minutes + increment", selection: $selected) {
                            ForEach(Array(ClockTimeControl.presets.enumerated()), id: \.offset) { index, preset in Text(preset.title).tag(index) }
                        }.pickerStyle(.inline)
                    }
                }.listRowBackground(ThemeCardBackground())
                Section {
                    HStack {
                        Spacer()
                        Button("Start") {
                            let control = custom ? ClockTimeControl(seconds: minutes * 60 + seconds, increment: increment) : ClockTimeControl.presets[selected]
                            apply(control); dismiss()
                        }.buttonStyle(.borderedProminent).controlSize(.small).disabled(custom && minutes * 60 + seconds == 0)
                        Spacer()
                    }
                }.listRowBackground(ThemeCardBackground())
            }.modifier(AppSurface()).navigationTitle("Time control").toolbar { Button("Cancel") { dismiss() } }
        }
    }
}
