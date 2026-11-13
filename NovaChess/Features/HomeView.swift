import SwiftUI

@MainActor struct HomeView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.scenePhase) private var phase
    @StateObject private var clock = ClockSession()
    @State private var showingClock = false
    @State private var today = Date()
    private var dayKey: String { DailyPuzzle.key(for: today) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Button { showingClock = true } label: {
                        AppCard {
                            HStack(spacing: 16) {
                                Image(systemName: "clock.fill").font(.largeTitle).foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Clock").font(.title2.bold()).foregroundStyle(.primary)
                                    Text(clock.clock.control.title).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                                }
                                Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }.padding(.vertical, 14)
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("home-clock")
                    NavigationLink { PuzzleTrainingView(dailyDay: dayKey) } label: {
                        AppCard {
                            HStack(spacing: 16) {
                                Image(systemName: "calendar").font(.largeTitle).foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Daily puzzle").font(.title2.bold()).foregroundStyle(.primary)
                                    Text(today, style: .date).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: library.state.dailyPuzzles[dayKey]?.completed == true ? "checkmark.seal.fill" : "chevron.right")
                                    .foregroundStyle(library.state.dailyPuzzles[dayKey]?.completed == true ? Color.yellow : Color.secondary)
                            }.padding(.vertical, 14)
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("daily-puzzle")
                }.padding()
            }.modifier(AppSurface()).navigationTitle("Home").toolbar { SettingsButton() }
                .fullScreenCover(isPresented: $showingClock) { ChessClockView(session: clock) }
                .onAppear { today = Date() }
                .onChange(of: phase) { _, value in if value == .active { today = Date() } }
        }
    }
}
