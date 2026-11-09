import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct GameImport: Sendable { var games: [OpeningGame]; var skipped: Int; var fetched: Int }
final class PublicGameService: @unchecked Sendable {
    private let session: URLSession
    init(session override: URLSession? = nil) {
        if let override { session = override; return }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.httpAdditionalHeaders = ["User-Agent": "ChessVision/0.3 (https://github.com/Louis2495/ChessVision)"]
        session = URLSession(configuration: configuration)
    }
    private func data(_ url: URL, ndjson: Bool = false, pgn: Bool = false) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(pgn ? "application/x-chess-pgn" : ndjson ? "application/x-ndjson" : "application/json", forHTTPHeaderField: "Accept")
        for attempt in 0..<3 {
            try Task.checkCancellation()
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw ChessError.invalid("The server returned an unreadable response.") }
            if response.statusCode == 429 {
                let retry = response.value(forHTTPHeaderField: "Retry-After") ?? "5"
                let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
                let delay = max(1, Double(retry) ?? formatter.date(from: retry)?.timeIntervalSinceNow ?? 5)
                if delay > 60 { throw ChessError.invalid("The site requested a cooldown of \(Int(delay)) seconds. Please retry later.") }
                if attempt < 2 { try await Task.sleep(for: .seconds(delay)); continue }
                throw ChessError.invalid("The site is limiting requests. Please retry later.")
            }
            if response.statusCode == 404 { throw ChessError.invalid("That public profile was not found. Check the username and site.") }
            guard (200..<300).contains(response.statusCode) else { throw ChessError.invalid("The site returned HTTP \(response.statusCode). No account credentials are needed; try again later.") }
            guard data.count <= 80_000_000 else { throw ChessError.invalid("This export is too large. Try this profile again later.") }
            return data
        }
        throw ChessError.invalid("The server is busy. Try again later.")
    }
    func load(site: PublicChessSite, username: String, limit: Int, progress: @escaping @Sendable (String) -> Void) async throws -> GameImport {
        guard PublicGames.validUsername(username), [200, 1000, 5000].contains(limit) else { throw ChessError.invalid("Enter a valid public username.") }
        var games: [OpeningGame] = [], skipped = 0, fetched = 0
        if site == .lichess {
            var components = URLComponents(string: "https://lichess.org/api/games/user/\(username)")!
            components.queryItems = [URLQueryItem(name: "max", value: String(limit)), URLQueryItem(name: "moves", value: "true"), URLQueryItem(name: "clocks", value: "false"), URLQueryItem(name: "evals", value: "false"), URLQueryItem(name: "opening", value: "false"), URLQueryItem(name: "sort", value: "dateDesc")]
            progress("Downloading up to \(limit) public games…")
            let bytes = try await data(components.url!, ndjson: true)
            for line in bytes.split(separator: 10) where !line.isEmpty {
                try Task.checkCancellation(); fetched += 1
                do {
                    let raw = try JSONDecoder().decode(PublicGames.LichessGame.self, from: Data(line))
                    if let game = try raw.openingGame(), !game.moves.isEmpty { games.append(game) } else { skipped += 1 }
                } catch is CancellationError { throw CancellationError() } catch { skipped += 1 }
            }
        } else {
            progress("Finding public monthly archives…")
            let archives = try JSONDecoder().decode(PublicGames.ChessComArchive.self, from: await data(URL(string: "https://api.chess.com/pub/player/\(username.lowercased())/games/archives")!))
            for archive in archives.archives.reversed() {
                try Task.checkCancellation()
                guard fetched < limit else { break }
                guard let source = URLComponents(string: archive), source.scheme == "https", source.host == "api.chess.com" else { throw ChessError.invalid("The archive server returned an unexpected address.") }
                progress("Downloading \(source.path.split(separator: "/").suffix(2).joined(separator: "/")) · \(fetched) games…")
                let monthBytes = try await data(source.url!)
                let month = try? JSONDecoder().decode(PublicGames.ChessComMonth.self, from: monthBytes)
                let records: [PublicGames.ChessComMonth.Game]
                if let month, month.games.contains(where: { $0.pgn?.isEmpty == false }) {
                    records = month.games
                    skipped += month.unreadable; fetched += month.unreadable
                } else {
                    // The documented PGN endpoint also works when the JSON archive omits game exports.
                    progress("Loading the monthly PGN export…")
                    let bytes = try await data(source.url!.appendingPathComponent("pgn"), pgn: true)
                    guard let text = String(data: bytes, encoding: .utf8) else { throw ChessError.invalid("The monthly PGN export could not be read.") }
                    let separator = try NSRegularExpression(pattern: #"(?m)(?=^\[Event\s)"#)
                    let starts = separator.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { Range($0.range, in: text)?.lowerBound }
                    records = starts.enumerated().map { offset, start in
                        let end = offset + 1 < starts.count ? starts[offset + 1] : text.endIndex
                        return PublicGames.ChessComMonth.Game(pgn: String(text[start..<end]), rules: "chess")
                    }
                }
                for raw in records.reversed() {
                    guard fetched < limit else { break }
                    fetched += 1
                    do {
                        if let game = try PublicGames.chessComGame(raw), !game.moves.isEmpty, game.result != .unknown { games.append(game) } else { skipped += 1 }
                    } catch is CancellationError { throw CancellationError() } catch { skipped += 1 }
                }
            }
        }
        guard !games.isEmpty else { throw ChessError.invalid("No completed standard games could be imported for this profile. Try the other site or a profile with recent public standard games.") }
        return GameImport(games: games, skipped: skipped, fetched: fetched)
    }
}
