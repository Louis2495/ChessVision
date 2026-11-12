import SwiftUI

@MainActor struct ChessClockView: View {
    @State private var clock = ChessClock()
    @State private var visible = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var setup = false
    @State private var resumeAfterSetup = false
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
                ToolbarItem(placement: .topBarTrailing) { SettingsButton() }
            }
            .onAppear { visible = true; updateScreenAwake() }
            .onDisappear { visible = false; UIApplication.shared.isIdleTimerDisabled = false }
            .onChange(of: clock.phase) { _, _ in updateScreenAwake() }
            .onChange(of: scenePhase) { _, _ in updateScreenAwake() }
            .sheet(isPresented: $setup, onDismiss: {
                if resumeAfterSetup && clock.phase == .paused { clock.start(at: ProcessInfo.processInfo.systemUptime) }
                resumeAfterSetup = false
            }) {
                ClockSetupView { control in
                    clock = ChessClock(control: control)
                    clock.start(at: ProcessInfo.processInfo.systemUptime)
                }
            }
            .confirmationDialog("Reset both clocks?", isPresented: $resetting, titleVisibility: .visible) {
                Button("Reset clock", role: .destructive) { clock = ChessClock(control: clock.control) }
            }
        }
    }
    private func changeTimeControl() {
        resumeAfterSetup = clock.phase == .running
        clock.pause(at: ProcessInfo.processInfo.systemUptime); setup = true
    }
    private func updateScreenAwake() {
        UIApplication.shared.isIdleTimerDisabled = visible && scenePhase == .active && clock.phase == .running && clock.flagged(at: ProcessInfo.processInfo.systemUptime) == nil
    }
    private func face(_ side: Side, now: Double) -> some View {
        let flagged = clock.flagged(at: now)
        let active = clock.phase == .running && clock.active == side && flagged == nil
        return Button { clock.press(side, at: ProcessInfo.processInfo.systemUptime) } label: {
            VStack(spacing: 12) {
                Text(time(clock.remaining(for: side, at: now))).font(.system(size: 74, weight: .bold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.45).lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).padding(20)
            .foregroundStyle(side == .white ? Color.black : Color.white)
            .background(side == .white ? Color(white: 0.97) : Color(white: 0.12), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(flagged == side ? Color.red : active ? Color.accentColor : Color.gray.opacity(0.35), lineWidth: active || flagged == side ? 4 : 1))
        }.buttonStyle(.plain)
            .accessibilityLabel("\(side.title), \(time(clock.remaining(for: side, at: now)))\(active ? ", running" : "")")
            .accessibilityIdentifier("clock-\(side.rawValue)")
    }
    private var resetButton: some View {
        Button("Reset", systemImage: "arrow.counterclockwise") { resetting = true }
    }
    private var runButton: some View {
        Button(clock.phase == .running ? "Pause" : clock.phase == .ready ? "Start" : "Resume", systemImage: clock.phase == .running ? "pause.fill" : "play.fill") {
            let time = ProcessInfo.processInfo.systemUptime
            if clock.phase == .running { clock.pause(at: time) } else { clock.start(at: time) }
        }.disabled(clock.flagged(at: ProcessInfo.processInfo.systemUptime) != nil)
    }
    private func controlTitle(now: Double) -> some View {
        VStack(spacing: 4) {
            Button(action: changeTimeControl) { Label(clock.control.title, systemImage: "slider.horizontal.3").font(.headline.monospacedDigit()).frame(minHeight: 44) }.accessibilityLabel("Time control")
            if clock.flagged(at: now) != nil { Text("Time expired").font(.caption.bold()) }
        }
    }
    private func controls(now: Double) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack { resetButton; Spacer(); controlTitle(now: now); Spacer(); runButton }
            VStack(spacing: 8) {
                controlTitle(now: now)
                HStack { resetButton; Spacer(); runButton }
            }
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
                        Button {
                            let control = custom ? ClockTimeControl(seconds: minutes * 60 + seconds, increment: increment) : ClockTimeControl.presets[selected]
                            apply(control); dismiss()
                        } label: {
                            Text("Start").font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                        }.buttonStyle(.borderedProminent).controlSize(.large).disabled(custom && minutes * 60 + seconds == 0)
                    }
                }.listRowBackground(ThemeCardBackground())
            }.modifier(AppSurface()).navigationTitle("Time control").toolbar { Button("Cancel") { dismiss() } }
        }
    }
}
