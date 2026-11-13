import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var library: LibraryStore
    var body: some View {
        let stats = GameStatistics(history: library.state.history)
        let improvements = ImprovementStatistics(history: library.state.history)
        let countries = stats.countries.union(library.state.visitedCountries.compactMap(Countries.valid))
        return List {
            Section("Games played") {
                Text(CountText.value(stats.total, "game")).font(.title2.bold().monospacedDigit())
                StatisticsBar(title: "White", count: stats.white, total: max(1, stats.total), color: .white)
                StatisticsBar(title: "Black", count: stats.black, total: max(1, stats.total), color: .black)
            }
            Section("Results") {
                StatisticsBar(title: "Wins", count: stats.wins, total: max(1, stats.total), color: .green)
                StatisticsBar(title: "Draws", count: stats.draws, total: max(1, stats.total), color: .blue)
                StatisticsBar(title: "Losses", count: stats.losses, total: max(1, stats.total), color: .red)
            }
            Section("Time categories") {
                HStack { circleKey("White", color: .white); circleKey("Black", color: .black); Spacer() }.font(.caption)
                ForEach(TimeCategory.allCases, id: \.self) { category in
                    categoryBar(category, stats: stats)
                }
            }
            Section("Areas for improvement") {
                if improvements.ordered.isEmpty { Text("Review a game to see patterns here.").font(.subheadline).foregroundStyle(.secondary) }
                ForEach(improvements.ordered, id: \.self) { concept in
                    DisclosureGroup {
                        Text(concept.practice).font(.subheadline).foregroundStyle(.secondary)
                    } label: {
                        StatisticsBar(title: concept.title, count: improvements.counts[concept, default: 0], total: max(1, improvements.counts.values.max() ?? 1), color: .orange)
                    }
                }
            }
            Section("Your world map") {
                CountryWorldMap(visited: countries).frame(height: 250)
                Text("\(CountText.value(countries.count, "country", plural: "countries")) played").font(.headline)
                ForEach(countries.sorted { Countries.name($0) < Countries.name($1) }, id: \.self) { code in
                    Label(Countries.name(code), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
        }.modifier(AppSurface()).navigationTitle("Stats")
    }
    private func circleKey(_ label: String, color: Color) -> some View {
        HStack(spacing: 5) { Circle().fill(color).overlay(Circle().stroke(Color.gray, lineWidth: 1)).frame(width: 10, height: 10); Text(label) }
    }
    private func categoryBar(_ category: TimeCategory, stats: GameStatistics) -> some View {
        let white = stats.categoryWhite[category, default: 0], black = stats.categoryBlack[category, default: 0]
        let maximum = max(1, stats.categories.values.max() ?? 1)
        return VStack(alignment: .leading, spacing: 7) {
            HStack { Text(category.rawValue); Spacer(); Text(String(white + black)).monospacedDigit().foregroundStyle(.secondary) }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.14))
                    HStack(spacing: 0) {
                        Rectangle().fill(Color.white).frame(width: geometry.size.width * CGFloat(white) / CGFloat(maximum))
                        Rectangle().fill(Color.black).frame(width: geometry.size.width * CGFloat(black) / CGFloat(maximum))
                    }.clipShape(Capsule()).overlay(Capsule().strokeBorder(Color.gray.opacity(0.5), lineWidth: 1))
                }
            }.frame(height: 16)
        }.padding(.vertical, 4).accessibilityElement(children: .ignore)
            .accessibilityLabel("\(category.rawValue): \(white) White, \(black) Black, \(white + black) total")
    }
}
private struct StatisticsBar: View {
    var title: String
    var count: Int
    var total: Int
    var color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(title); Spacer(); Text(String(count)).monospacedDigit().foregroundStyle(.secondary) }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.14))
                    Capsule().fill(color).frame(width: geometry.size.width * CGFloat(min(1, Double(count) / Double(max(1, total)))))
                        .overlay(Capsule().strokeBorder(Color.gray.opacity(0.45), lineWidth: count == 0 ? 0 : 1))
                }
            }.frame(height: 16)
        }.padding(.vertical, 4).accessibilityElement(children: .ignore).accessibilityLabel("\(title): \(count)")
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
    @State private var zoom: CGFloat = 1
    @State private var offset = CGSize.zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var translation = CGSize.zero
    private func bounded(_ value: CGSize, size: CGSize, scale: CGFloat) -> CGSize {
        let x = size.width * (scale - 1) / 2, y = size.height * (scale - 1) / 2
        return CGSize(width: min(x, max(-x, value.width)), height: min(y, max(-y, value.height)))
    }
    private func reset() { zoom = 1; offset = .zero }
    var body: some View {
        GeometryReader { geometry in
            let scale = max(1, min(6, zoom * pinch))
            let pan = bounded(CGSize(width: offset.width + translation.width, height: offset.height + translation.height), size: geometry.size, scale: scale)
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
            }.scaleEffect(scale).offset(pan)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(Color.blue.opacity(0.10)).clipped().contentShape(Rectangle())
                .simultaneousGesture(MagnificationGesture().updating($pinch) { value, state, _ in state = value }.onEnded { value in
                    zoom = max(1, min(6, zoom * value)); offset = bounded(offset, size: geometry.size, scale: zoom)
                })
                .gesture(DragGesture().updating($translation) { value, state, _ in state = value.translation }.onEnded { value in
                    offset = bounded(CGSize(width: offset.width + value.translation.width, height: offset.height + value.translation.height), size: geometry.size, scale: zoom)
                }, including: zoom > 1 ? .all : .subviews)
                .onTapGesture(count: 2) { reset() }
                .overlay(alignment: .topTrailing) {
                    if zoom > 1 { Button { reset() } label: { Image(systemName: "arrow.counterclockwise").padding(10).background(.regularMaterial, in: Circle()) }.padding(6).accessibilityLabel("Reset map zoom") }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("World map. Countries played: " + visited.map(Countries.name).sorted().joined(separator: ", "))
                .accessibilityValue("\(Int(zoom.rounded()))×")
                .accessibilityIdentifier("country-world-map")
                .accessibilityHint("Pinch to zoom, drag to pan, double-tap to reset.")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: zoom = min(6, zoom + 1)
                    case .decrement: zoom = max(1, zoom - 1)
                    @unknown default: break
                    }
                    offset = bounded(offset, size: geometry.size, scale: zoom)
                }
        }
    }
}
