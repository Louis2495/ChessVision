import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import NovaChess
#endif
final class LearningContentTests: XCTestCase {
    func testLearningResourcesHaveUniqueShortSourcedEntries() throws {
        let content = try TrainingAssets.learning()
        XCTAssertGreaterThanOrEqual(content.facts.count, 50)
        XCTAssertGreaterThanOrEqual(content.milestones.count, 20)
        XCTAssertEqual(Set(content.facts.map(\.id)).count, content.facts.count)
        XCTAssertEqual(Set(content.milestones.map(\.id)).count, content.milestones.count)
        for fact in content.facts {
            XCTAssertLessThan(fact.detail.count, 190, fact.id)
            XCTAssertEqual(URL(string: fact.source)?.scheme, "https")
            if let kind = fact.diagram { XCTAssertTrue(["n","r","b","q","k"].contains(kind)) }
        }
    }
    func testChampionChronologySeparatesSplitAndDoesNotInventEarlyRatings() throws {
        let content = try TrainingAssets.learning()
        let main = content.champions.filter { $0.track == "main" }
        let split = content.champions.filter { $0.track == "split" }
        XCTAssertEqual(Set(main.map(\.name)).count, 18)
        XCTAssertEqual(split.count, 6)
        XCTAssertEqual(Set(content.champions.map(\.id)).count, content.champions.count)
        XCTAssertEqual(main.first?.start, 1886); XCTAssertEqual(main.last?.start, 2024)
        for pair in zip(main, main.dropFirst()) { XCTAssertLessThanOrEqual(pair.0.end ?? 9999, pair.1.start) }
        for champion in content.champions {
            XCTAssertEqual(URL(string: champion.source)?.scheme, "https")
            if let elo = champion.elo {
                XCTAssertTrue((2500...3000).contains(elo))
                let year = try XCTUnwrap(champion.ratingYear)
                XCTAssertGreaterThanOrEqual(year, 1971)
                XCTAssertGreaterThanOrEqual(year, champion.start)
                XCTAssertLessThanOrEqual(year, champion.end ?? content.coverageThrough)
            } else { XCTAssertNil(champion.ratingYear) }
            if (champion.end ?? content.coverageThrough) < 1971 { XCTAssertNil(champion.elo) }
        }
    }
    func testMovementDiagramsAgreeWithEmptyBoardGeometry() {
        for (piece, count) in [("n",8),("r",14),("b",13),("q",27),("k",8)] {
            let destinations = LearningDiagram.targets(for: piece)
            XCTAssertEqual(destinations.count, count); XCTAssertFalse(destinations.contains(27))
            XCTAssertTrue(destinations.allSatisfy { (0..<64).contains($0) })
        }
        XCTAssertEqual(LearningDiagram.targets(for: "n", origin: 0).count, 2)
        XCTAssertTrue(LearningDiagram.targets(for: "unknown").isEmpty)
    }
    func testMoreOpeningChoicesAreLegalAndDistinct() throws {
        let lessons = OpeningLessons.curated(in: try TrainingAssets.openings())
        print("Expanded Learn: \(lessons.count) opening lessons")
        XCTAssertGreaterThanOrEqual(lessons.count, 45)
        XCTAssertEqual(Set(lessons.map(\.id)).count, lessons.count)
        for lesson in lessons {
            XCTAssertTrue((16...40).contains(lesson.moves.count))
            var board = Position.initial
            for uci in lesson.moves { try board.apply(uci: uci) }
            XCTAssertEqual(board.openingKey, lesson.key)
        }
    }
    func testSharedTimeControlPresetsAndFirstPressIncrement() {
        XCTAssertTrue(ClockTimeControl.presets.contains(ClockTimeControl(seconds: 60, increment: 1)))
        XCTAssertFalse(ClockTimeControl.presets.contains(ClockTimeControl(seconds: 300, increment: 3)))
        XCTAssertFalse(ClockTimeControl.presets.contains(ClockTimeControl(seconds: 600, increment: 5)))
        var clock = ChessClock(control: ClockTimeControl(seconds: 60, increment: 1))
        clock.press(.white, at: 0)
        XCTAssertEqual(clock.remaining(for: .white, at: 0), 61)
    }
}
