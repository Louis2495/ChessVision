import SwiftUI

struct RatingsInfoView: View {
    var body: some View {
        List {
            Section("Standard") {
                Text("Your Standard rating is a local estimate using the published US Chess approximation: provisional performance for the first eight games, then expected score with a rating-dependent effective-games factor. It is marked provisional through 25 games.")
                Text("Bots have not been tested against a USCF-rated human population. This number is not an official USCF rating or a validated USCF equivalent. Official US Chess ratings come from eligible reported events, with additional rules for floors, initial ratings and event processing.")
            }.listRowBackground(ThemeCardBackground())
            Section("Computer strength & variants") {
                Text("Computer strength is an engine target. Stockfish 19's range is based approximately on CCRL Blitz computer ratings, not USCF. Weaker opponents and variants use Fairy-Stockfish; variant strength is also uncalibrated.")
                Text("Variant and blindfold ratings stay in separate local Elo pools. Adaptive games are unrated. Targets outside the engines' supported ranges can be played unrated but cannot earn rating points.")
                Text("Developer's 2407 is its configured engine target, not a measured USCF rating.")
            }.listRowBackground(ThemeCardBackground())
            Section("Puzzles & review") {
                Text("Puzzle difficulty uses the original Lichess puzzle rating. Your puzzle estimate tracks practice results on that scale; puzzle performance has no reliable direct conversion to USCF. Older training estimates are rescaled when the library is loaded, preserving solved puzzles.")
                Text("Game reviews show move assessments and average centipawn loss instead of deriving a human rating from one game.")
            }.listRowBackground(ThemeCardBackground())
            Section("References") {
                Link("US Chess rating system", destination: URL(string: "https://new.uschess.org/sites/default/files/media/documents/the-us-chess-rating-system-revised-september-2020.pdf")!)
                Link("Approximating formulas · Mark Glickman", destination: URL(string: "https://www.glicko.net/ratings/approx.pdf")!)
            }.listRowBackground(ThemeCardBackground())
        }.modifier(AppSurface()).navigationTitle("About ratings").navigationBarTitleDisplayMode(.inline)
    }
}
