import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import NovaChess
#endif

final class RatingPolicyTests: XCTestCase {
    func testProvisionalPerformanceApproximation() {
        var win = PlayerRating(), draw = PlayerRating(), loss = PlayerRating()
        XCTAssertEqual(win.record(score: 1, opponent: 1200, standard: true), 600)
        XCTAssertEqual(draw.record(score: 0.5, opponent: 1200, standard: true), 200)
        XCTAssertEqual(loss.record(score: 0, opponent: 1200, standard: true), -200)
        win.record(score: 0, opponent: 1200, standard: true)
        XCTAssertEqual(win.value, 1200) // balanced results vs the same opponent
        XCTAssertTrue(win.provisional)
    }
    func testEstablishedFormulaUsesEffectiveGamesAndPublishedHighRatingCap() {
        XCTAssertEqual(RatingPolicy.effectiveGames(rating: 2400, games: 100), 50)
        XCTAssertEqual(RatingPolicy.effectiveGames(rating: 2400, games: 8), 8)
        XCTAssertEqual(RatingPolicy.effectiveGames(rating: 1000, games: 100), 11.514987935, accuracy: 0.000001)
        // R=2400, N'=50, m=1, E=0.5: +800/51 * 0.5, no one-game bonus.
        XCTAssertEqual(RatingPolicy.standardEstimate(rating: 2400, games: 100, score: 1, opponent: 2400), 2407.84313725, accuracy: 0.000001)
        XCTAssertEqual(RatingPolicy.standardEstimate(rating: 2400, games: 100, score: 0.5, opponent: 2400), 2400)
        var rating = PlayerRating(); rating.games = 25
        XCTAssertTrue(rating.provisional); rating.games = 26; XCTAssertFalse(rating.provisional)
    }
    func testInvalidResultsDoNotChangeRatingAndMinimumIs100() {
        var rating = PlayerRating()
        XCTAssertEqual(rating.record(score: .nan, opponent: 1000, standard: true), 0)
        XCTAssertEqual(rating.record(score: 1, opponent: -20, standard: true), 0)
        XCTAssertEqual(rating.games, 0)
        rating.record(score: 0, opponent: 100, standard: true)
        XCTAssertEqual(rating.value, 100)
    }
    func testAdaptiveAndUnsupportedTargetsCannotEarnRatingEvenWithRatedFlag() {
        for mode in [GameMode.normal, .threeCheck] {
            for target in [100, 4000, 10000] {
                var progress = PlayProgress(), game = SavedComputerGame(mode: mode, human: .white, targetRating: target)
                game.rated = true
                XCTAssertNil(progress.finish(game, result: "white"))
                XCTAssertEqual(progress.rating(for: mode).games, 0)
            }
            var progress = PlayProgress(), game = SavedComputerGame(mode: mode, human: .white, targetRating: 1000)
            game.rated = true; game.adaptive = true
            XCTAssertNil(progress.finish(game, result: "white"))
        }
        XCTAssertTrue(RatingPolicy.ratedBotRange(for: .normal).contains(3190))
        XCTAssertFalse(RatingPolicy.ratedBotRange(for: .threeCheck).contains(3190))
    }
    func testLegacyStandardRatingsRebuildOnceWithoutChangingAchievementsOrHistory() throws {
        var state = LibraryState(), prior = PlayerRating()
        prior.record(score: 1, opponent: 1200); prior.record(score: 0, opponent: 1200)
        state.playProgress.ratings[GameMode.normal.rawValue] = prior
        state.playProgress.achievements[Achievement.firstWin.rawValue] = Date(timeIntervalSince1970: 123)
        var first = SavedComputerGame(mode: .normal, human: .white, targetRating: 1200); first.rated = true
        var second = SavedComputerGame(mode: .normal, human: .black, targetRating: 1200); second.rated = true
        state.history = [CompletedGame(game: second, result: "white", now: Date(timeIntervalSince1970: 2)),
                         CompletedGame(game: first, result: "white", now: Date(timeIntervalSince1970: 1))]
        XCTAssertTrue(state.updateStandardRatings())
        XCTAssertEqual(state.playProgress.rating(for: .normal).value, 1200)
        XCTAssertEqual(state.history[1].ratingChange, 600); XCTAssertEqual(state.history[0].ratingChange, -400)
        XCTAssertEqual(state.history.count, 2)
        XCTAssertNotNil(state.playProgress.achievements[Achievement.firstWin.rawValue])
        let restored = try JSONDecoder().decode(LibraryState.self, from: JSONEncoder().encode(state))
        var twice = restored; XCTAssertFalse(twice.updateStandardRatings())
        XCTAssertEqual(twice.playProgress.rating(for: .normal).value, 1200)
    }
    func testIncompleteHistoryPreservesLegacySeedRatherThanInventingResults() {
        var state = LibraryState(), old = PlayerRating(); old.value = 1800; old.games = 50
        state.playProgress.ratings[GameMode.normal.rawValue] = old
        XCTAssertTrue(state.updateStandardRatings())
        XCTAssertEqual(state.playProgress.rating(for: .normal).value, 1800)
        XCTAssertEqual(state.playProgress.rating(for: .normal).legacySeed, true)
        XCTAssertFalse(state.updateStandardRatings())
    }
    func testMigrationRemovesInflatedUnsupportedOpponentPoints() {
        var state = LibraryState(), old = PlayerRating(); old.games = 1; old.value = 1064
        state.playProgress.ratings[GameMode.normal.rawValue] = old
        var game = SavedComputerGame(mode: .normal, human: .white, targetRating: 10000); game.rated = true
        state.history = [CompletedGame(game: game, result: "white")]; state.history[0].ratingChange = 64
        XCTAssertTrue(state.updateStandardRatings())
        XCTAssertEqual(state.playProgress.rating(for: .normal).games, 0)
        XCTAssertNil(state.history[0].ratingChange)
    }
    func testPuzzleScaleMigrationIsOneTimeAndKeepsCompletedIDs() throws {
        let old = Data(#"{"rating":1600,"attempts":80,"solved":60,"completed":["saved"],"placementAttempts":40}"#.utf8)
        let migrated = try JSONDecoder().decode(PuzzleProgress.self, from: old)
        XCTAssertEqual(migrated.rating, 2000); XCTAssertEqual(migrated.completed, ["saved"])
        XCTAssertEqual(migrated.attempts, 80); XCTAssertEqual(migrated.placementAttempts, 0)
        let restored = try JSONDecoder().decode(PuzzleProgress.self, from: JSONEncoder().encode(migrated))
        XCTAssertEqual(restored.rating, 2000); XCTAssertEqual(restored.scaleVersion, 1)
    }
}
