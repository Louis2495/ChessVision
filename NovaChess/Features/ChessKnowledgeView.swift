import SwiftUI

@MainActor struct ChessFactsView: View {
    @State private var content: ChessLearningContent?
    @State private var error: String?
    @State private var category = "All"
    @State private var search = ""
    private var facts: [ChessFact] {
        (content?.facts ?? []).filter { (category == "All" || $0.category == category) && (search.isEmpty || ($0.title + " " + $0.detail).localizedCaseInsensitiveContains(search)) }
    }
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let content {
                    Picker("Category", selection: $category) {
                        Text("All").tag("All")
                        ForEach(Array(Set(content.facts.map(\.category))).sorted(), id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(facts) { fact in FactCard(fact: fact) }
                    if facts.isEmpty { ContentUnavailableView.search(text: search) }
                } else if let error { Text(error).foregroundStyle(.red) }
                else { ProgressView() }
            }.padding()
        }.modifier(AppSurface()).navigationTitle("Fun facts").searchable(text: $search, prompt: "Find a fact")
            .task { do { content = try TrainingAssets.learning() } catch { self.error = error.localizedDescription } }
    }
}
private struct FactCard: View {
    var fact: ChessFact
    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: 14) {
                if let metric = fact.metric { Text(metric).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(.tint).minimumScaleFactor(0.6).frame(minWidth: 55, maxWidth: 110) }
                else { Image(systemName: fact.symbol).font(.system(size: 30)).foregroundStyle(.tint).frame(width: 50, height: 50) }
                VStack(alignment: .leading, spacing: 7) {
                    Text(fact.title).font(.headline)
                    Text(fact.detail).font(.subheadline).foregroundStyle(.secondary)
                    Text(fact.category).font(.caption2.weight(.semibold)).foregroundStyle(.tint)
                }
            }
            if let kind = fact.diagram { PieceReachDiagram(kind: kind).frame(maxWidth: 220).frame(maxWidth: .infinity) }
        }.contextMenu { if let url = URL(string: fact.source) { Link("Source", destination: url) } }
    }
}
private struct PieceReachDiagram: View {
    var kind: String
    private var board: Position {
        var result = Position()
        result.squares[27] = Piece(kind.uppercased().first ?? "N")
        return result
    }
    var body: some View {
        BoardView(position: board, legalTargets: LearningDiagram.targets(for: kind)).allowsHitTesting(false)
            .accessibilityElement(children: .ignore).accessibilityLabel("Empty-board movement diagram: \(CountText.value(LearningDiagram.targets(for: kind).count, "destination"))")
    }
}

@MainActor struct ChessHistoryView: View {
    @State private var content: ChessLearningContent?
    @State private var error: String?
    @State private var page = "Champions"
    @State private var track = "main"
    private var champions: [ChessChampion] { (content?.champions ?? []).filter { $0.track == track } }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Picker("Explore history", selection: $page) {
                    ForEach(["Milestones", "Champions", "Ratings"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.segmented)
                if let content {
                    Text("Through \(String(content.coverageThrough))").font(.caption).foregroundStyle(.secondary)
                    if page == "Milestones" {
                        ForEach(content.milestones) { milestone in MilestoneCard(event: milestone) }
                    } else {
                        Picker("Title branch", selection: $track) {
                            Text("Open title").tag("main"); Text("FIDE split").tag("split")
                        }.pickerStyle(.segmented)
                        if track == "split" { Label("1993–2006 · separate FIDE title", systemImage: "arrow.triangle.branch").font(.caption).foregroundStyle(.secondary) }
                        if page == "Champions" {
                            ForEach(champions) { champion in ChampionCard(champion: champion) }
                            Text("— No title-era rating supplied. Early titles predate published FIDE lists.").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("Recorded event Elo").font(.title3.bold())
                            Text("Dated snapshots, not peaks or direct cross-era comparisons.").font(.caption).foregroundStyle(.secondary)
                            ForEach(champions.filter { $0.elo != nil }) { champion in ChampionRatingBar(champion: champion) }
                        }
                    }
                } else if let error { Text(error).foregroundStyle(.red) }
                else { ProgressView() }
            }.padding()
        }.modifier(AppSurface()).navigationTitle("History").navigationBarTitleDisplayMode(.inline)
            .task { do { content = try TrainingAssets.learning() } catch { self.error = error.localizedDescription } }
    }
}
private struct MilestoneCard: View {
    var event: ChessMilestone
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 7) {
                Image(systemName: event.symbol).foregroundStyle(.tint).font(.title2).frame(width: 42, height: 42).background(Color.accentColor.opacity(0.12), in: Circle())
                Rectangle().fill(Color.accentColor.opacity(0.25)).frame(width: 2, height: 60)
            }
            AppCard {
                Text((event.year < 1000 ? "c. " : "") + String(event.year)).font(.title.bold().monospacedDigit()).foregroundStyle(.tint)
                Text(event.title).font(.headline)
                Text(event.detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }.contextMenu { if let url = URL(string: event.source) { Link("Source", destination: url) } }
    }
}
private struct ChampionCard: View {
    var champion: ChessChampion
    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 8) {
                    Image(systemName: "crown.fill").font(.title2).foregroundStyle(champion.track == "split" ? Color.orange : Color.yellow)
                    Rectangle().fill(Color.accentColor.opacity(0.35)).frame(width: 3, height: 42)
                }.frame(width: 32)
                VStack(alignment: .leading, spacing: 7) {
                    Text(champion.reign).font(.caption.bold().monospacedDigit()).foregroundStyle(.tint)
                    Text(champion.name).font(.headline)
                    Text(champion.highlight).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(champion.elo.map { String($0) } ?? "—").font(.title3.bold().monospacedDigit())
                    Text(champion.ratingYear.map { "Elo · " + String($0) } ?? "Pre-FIDE lists").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }.contextMenu { if let url = URL(string: champion.source) { Link("Source", destination: url) } }
    }
}
private struct ChampionRatingBar: View {
    var champion: ChessChampion
    var body: some View {
        AppCard {
            HStack {
                Text(champion.name).font(.headline)
                Spacer()
                Text(champion.elo.map { String($0) } ?? "—").font(.headline.monospacedDigit())
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.15))
                    Capsule().fill(Color.accentColor).frame(width: geometry.size.width * CGFloat(champion.elo ?? 0) / 3000)
                }
            }.frame(height: 18)
            HStack { Text(champion.ratingYear.map { "Event · " + String($0) } ?? ""); Spacer(); Text("0–3000") }.font(.caption2).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine)
            .contextMenu { if let url = URL(string: champion.source) { Link("Rating source", destination: url) } }
    }
}
