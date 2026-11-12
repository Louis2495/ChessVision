import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject private var library: LibraryStore
    var body: some View {
        List {
            Section("Your bot ratings") {
                Text("Local ratings for rated games against the computer. These are separate from Chess.com, Lichess and your puzzle estimate.").font(.caption).foregroundStyle(.secondary)
                ForEach(GameMode.allCases.filter { library.state.playProgress.rating(for: $0).games > 0 }) { mode in
                    let rating = library.state.playProgress.rating(for: mode)
                    HStack { Text(mode.title); Spacer(); Text("\(String(Int(rating.value.rounded()))) · \(rating.games) games").monospacedDigit() }
                }
                if library.state.playProgress.ratings.isEmpty { Text("Your starting rating is 1000. Enable Rated game in New game to begin.").foregroundStyle(.secondary) }
            }.listRowBackground(ThemeCardBackground())
            Section("Achievements") {
                ForEach(Achievement.allCases, id: \.rawValue) { achievement in
                    let date = library.state.playProgress.achievements[achievement.rawValue]
                    HStack(spacing: 14) {
                        Image(systemName: date == nil ? "lock" : "medal.fill").foregroundStyle(date == nil ? Color.secondary : Color.accentColor).frame(width: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(achievement.title).font(.headline)
                            Text(achievement.detail).font(.caption).foregroundStyle(.secondary)
                            if let date { Text(date, style: .date).font(.caption2).foregroundStyle(.secondary) }
                        }
                    }.padding(.vertical, 5)
                }
            }.listRowBackground(ThemeCardBackground())
        }.modifier(AppSurface()).navigationTitle("Achievements & ratings")
    }
}

extension MoveQuality {
    var color: Color {
        switch self {
        case .best, .excellent, .good: return .green
        case .book: return .blue
        case .inaccuracy: return .yellow
        case .mistake: return .orange
        case .blunder: return .red
        }
    }
}
