import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import NovaChess
#endif
final class StatisticsAndDeveloperTests: XCTestCase {
    func testCountsColorsResultsCategoriesAndDeduplicates() {
        var bot = SavedComputerGame(mode: .normal, human: .white, targetRating: 2407)
        bot.source = "bot"; bot.developerBot = true; bot.opponentName = "Developer"
        var online = SavedComputerGame(mode: .normal, human: .black, targetRating: 1000)
        online.source = "correspondence"; online.opponentCountry = "US"
        var timed = SavedComputerGame(mode: .normal, human: .black, targetRating: 1000)
        timed.timeControlSeconds = 180; timed.timeControlIncrement = 2
        let a = CompletedGame(game: bot, result: "white"), b = CompletedGame(game: online, result: "draw"), c = CompletedGame(game: timed, result: "white")
        let stats = GameStatistics(history: [a,b,c,a])
        XCTAssertEqual(stats.total, 3); XCTAssertEqual(stats.white, 1); XCTAssertEqual(stats.black, 2)
        XCTAssertEqual(stats.wins, 1); XCTAssertEqual(stats.draws, 1); XCTAssertEqual(stats.losses, 1)
        XCTAssertEqual(stats.categories[.untimed], 1); XCTAssertEqual(stats.categories[.correspondence], 1)
        XCTAssertEqual(stats.categoryBlack[.blitz], 1); XCTAssertEqual(stats.countries, ["US"])
    }
    func testMovePairsAndTimeBoundaries() {
        XCTAssertEqual(GameStatistics.moveCount(plies: 52), 26)
        XCTAssertEqual(GameStatistics.moveCount(plies: 53), 27)
        XCTAssertEqual(GameStatistics.moveCount(plies: 0), 0)
        XCTAssertEqual(TimeCategory.classify(seconds: 60), .bullet)
        XCTAssertEqual(TimeCategory.classify(seconds: 600), .rapid)
        XCTAssertEqual(TimeCategory.classify(seconds: 1800), .classical)
        XCTAssertEqual(TimeCategory.classify(seconds: nil), .untimed)
        var namedBot = SavedComputerGame(mode: .normal, human: .white, targetRating: 1000)
        namedBot.source = "bot"; namedBot.opponentName = "Other bot"
        XCTAssertEqual(GameStatistics(history: [CompletedGame(game: namedBot, result: "draw")]).categories[.untimed], 1)
    }
    func testDeveloperBookStaysLegalAndRespondsToBothPawnStarts() throws {
        func legal(_ board: Position) -> [VariantMove] { board.legalMoves().map { VariantMove(uci: $0.uci, san: "") } }
        XCTAssertEqual(DeveloperOpeningBook.move(history: [], side: .white, legal: legal(.initial)), "e2e4")
        var e4 = Position.initial; try e4.apply(uci: "e2e4")
        XCTAssertEqual(DeveloperOpeningBook.move(history: ["e2e4"], side: .black, legal: legal(e4)), "e7e5")
        var d4 = Position.initial; try d4.apply(uci: "d2d4")
        XCTAssertEqual(DeveloperOpeningBook.move(history: ["d2d4"], side: .black, legal: legal(d4)), "g8f6")
        XCTAssertNil(DeveloperOpeningBook.move(history: [], side: .white, legal: []))
        var sicilian = Position.initial; try sicilian.apply(uci: "e2e4"); try sicilian.apply(uci: "c7c5")
        XCTAssertEqual(DeveloperOpeningBook.move(history: ["e2e4","c7c5"], side: .white, legal: legal(sicilian)), "b1c3")
    }
    func testCountryValidationAndAchievementOrdering() {
        XCTAssertEqual(Countries.valid("us"), "US"); XCTAssertNil(Countries.valid("not a country"))
        XCTAssertEqual(Achievement.ordered.first, .firstGame)
        XCTAssertEqual(Achievement.ordered.last, .tenThousandGames)
        XCTAssertEqual(Set(Achievement.ordered).count, Achievement.allCases.count)
    }
}
