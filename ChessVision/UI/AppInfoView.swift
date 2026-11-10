import SwiftUI

struct AppInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy").font(.title2.bold())
                Text("Photos stay on your iPhone. ChessVision does not collect analytics or require an account. Sharing a board uses the system share sheet. Opening explorer contacts the chosen site with the public username you enter. Your repertoire, puzzle progress and games are saved on this device.")
                DisclosureGroup("Chess engines") {
                    Text("Standard chess uses official Stockfish 19 and its bundled NNUE network nn-1a298aa575a0. Analysis runs at full strength until you leave or change the position. Variants use Fairy-Stockfish with their own rules. Scores can differ with search time, engine version, candidate-line count and position rights.").font(.footnote)
                }
                DisclosureGroup("Ratings") {
                    Text("Puzzle levels are estimates based on Lichess source ratings, not official Chess.com ratings. Computer strength is approximate and varies with hardware and variant.").font(.footnote)
                }
                DisclosureGroup("Open-source licenses & acknowledgments") {
                    Text(notices).font(.caption.monospaced()).textSelection(.enabled)
                }
            }.padding()
        }.modifier(AppSurface()).navigationTitle("About ChessVision")
    }
    private var notices: String {
        guard let url = Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "License files accompany the project." }
        return text
    }
}
