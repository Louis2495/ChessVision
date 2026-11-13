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
                ToolbarItem(placement: .topBarLeading) {
                    if clock.phase == .running && clock.flagged(at: ProcessInfo.processInfo.systemUptime) == nil {
                        Button("Pause", systemImage: "pause.fill") { clock.pause(at: ProcessInfo.processInfo.systemUptime) }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { resetButton }
            }
            .onAppear { visible = true; updateScreenAwake() }
            .onDisappear { visible = false; UIApplication.shared.isIdleTimerDisabled = false }
            .onChange(of: clock.phase) { _, _ in updateScreenAwake() }
            .onChange(of: scenePhase) { _, _ in updateScreenAwake() }
            .sheet(isPresented: $setup) {
                ClockSetupView { control in
                    clock = ChessClock(control: control)
                }
            }
            .confirmationDialog("Reset both clocks?", isPresented: $resetting, titleVisibility: .visible) {
                Button("Reset clock", role: .destructive) { clock = ChessClock(control: clock.control) }
            }
        }
    }
    private func changeTimeControl() {
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
    private func controlTitle(now: Double) -> some View {
        VStack(spacing: 4) {
            Button(action: changeTimeControl) { Label(clock.control.title, systemImage: "slider.horizontal.3").font(.headline.monospacedDigit()).frame(minHeight: 44) }.accessibilityLabel("Time control")
            if clock.flagged(at: now) != nil { Text("Time expired").font(.caption.bold()) }
        }
    }
    @ViewBuilder private func controls(now: Double) -> some View {
        if clock.phase != .running || clock.flagged(at: now) != nil {
            controlTitle(now: now).frame(maxWidth: .infinity).buttonStyle(.bordered).controlSize(.large)
        }
    }
    private func time(_ seconds: Double) -> String {
        let rounded = Int(ceil(max(0, seconds)))
        return String(format: "%d:%02d", rounded / 60, rounded % 60)
    }
}

private struct ClockSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected = ClockTimeControl.presets.firstIndex(of: ClockTimeControl(seconds: 300)) ?? 0
    @State private var custom = false
    @AppStorage("clockMinutes") private var minutes = 5
    @AppStorage("clockSeconds") private var seconds = 0
    @AppStorage("clockIncrement") private var increment = 0
    @AppStorage("clockDelay") private var delay = 0
    let apply: (ClockTimeControl) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("Time control") {
                    Toggle("Custom time control", isOn: $custom)
                    if custom {
                        Stepper("Minutes: \(minutes)", value: $minutes, in: 0...180)
                        Stepper("Seconds: \(seconds)", value: $seconds, in: 0...59)
                        Stepper("Increment: \(increment) \(increment == 1 ? "second" : "seconds")", value: $increment, in: 0...60)
                        Stepper("Delay: \(delay) \(delay == 1 ? "second" : "seconds")", value: $delay, in: 0...60)
                    } else {
                        Picker("Time control", selection: $selected) {
                            ForEach(Array(ClockTimeControl.presets.enumerated()), id: \.offset) { index, preset in Text(preset.title).tag(index) }
                        }.pickerStyle(.inline)
                    }
                }.listRowBackground(ThemeCardBackground())
                Section {
                    HStack {
                        Button {
                            let control = custom ? ClockTimeControl(seconds: minutes * 60 + seconds, increment: increment, delay: delay) : ClockTimeControl.presets[selected]
                            apply(control); dismiss()
                        } label: {
                            Text("Apply").font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                        }.buttonStyle(ThemeActionButtonStyle()).controlSize(.large).disabled(custom && minutes * 60 + seconds == 0)
                    }
                }.listRowBackground(ThemeCardBackground())
            }.modifier(AppSurface()).navigationTitle("Time control").toolbar { Button("Cancel") { dismiss() } }
        }
    }
}
