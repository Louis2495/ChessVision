import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var library: LibraryStore
    var body: some View {
        let stats = GameStatistics(history: library.state.history)
        let countries = stats.countries.union(library.state.visitedCountries.compactMap(Countries.valid))
        return List {
            Section("Games played") {
                row("", "White", "Black", "Total").font(.caption.bold())
                row("All games", String(stats.white), String(stats.black), String(stats.total))
                Text("\(String(stats.wins)) wins · \(String(stats.draws)) draws · \(String(stats.losses)) losses").font(.caption).foregroundStyle(.secondary)
            }
            Section("Time categories") {
                row("", "White", "Black", "Total").font(.caption.bold())
                ForEach(TimeCategory.allCases, id: \.self) { category in
                    row(category.rawValue, String(stats.categoryWhite[category, default: 0]), String(stats.categoryBlack[category, default: 0]), String(stats.categories[category, default: 0]))
                }
                Text("Completed games only. Games without a recorded time control are Untimed.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Your world map") {
                CountryWorldMap(visited: countries).frame(height: 210)
                Text("\(String(countries.count)) countries played").font(.headline)
                if countries.isEmpty { Text("Countries fill in when you play another player who has chosen a country in their profile.").font(.caption).foregroundStyle(.secondary) }
                ForEach(countries.sorted { Countries.name($0) < Countries.name($1) }, id: \.self) { code in
                    Label(Countries.name(code), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
        }.modifier(AppSurface()).navigationTitle("Stats")
    }
    private func row(_ name: String, _ white: String, _ black: String, _ total: String) -> some View {
        HStack {
            Text(name).frame(maxWidth: .infinity, alignment: .leading)
            Text(white).frame(width: 48); Text(black).frame(width: 48); Text(total).frame(width: 48)
        }.font(.subheadline).monospacedDigit()
    }
}
private struct CountryShape: Decodable, Sendable {
    var code: String
    var polygons: [[[Double]]]
    static let all: [CountryShape] = {
        guard let url = Bundle.main.url(forResource: "Countries", withExtension: "json"), let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([CountryShape].self, from: data)) ?? []
    }()
}
struct CountryWorldMap: View {
    let visited: Set<String>
    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            for country in CountryShape.all {
                var path = Path()
                for polygon in country.polygons {
                    let points = polygon.filter { $0.count == 2 }.map { point in
                        CGPoint(x: (point[0]+180)/360*size.width, y: (85-point[1])/145*size.height)
                    }
                    guard let first = points.first else { continue }
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                    path.closeSubpath()
                }
                context.fill(path, with: .color(visited.contains(country.code) ? .green : .gray.opacity(0.25)), style: FillStyle(eoFill: true))
                context.stroke(path, with: .color(.primary.opacity(0.35)), lineWidth: 0.4)
            }
        }.background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 10)).clipped()
        .accessibilityLabel("World map. Countries played: " + visited.map(Countries.name).sorted().joined(separator: ", "))
    }
}
