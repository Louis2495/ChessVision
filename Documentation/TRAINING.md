# Training, opening data and public profiles

## Bundled assets

`ChessVision/Core/Resources/Puzzles.json` has exactly 1,000 puzzle records. Each has its original Lichess ID, FEN, full solution, source rating, estimated difficulty, themes and game URL. The first solution ply is the opponent's setup move; the app applies it before asking the learner to solve. Every source FEN and every solution ply was checked with python-chess and the Swift legal-move engine. Popularity, play-count and deviation filters exclude poorly established examples. Difficulty sampling spans the available source distribution rather than duplicating positions.

The primary database domain was blocked in this cloud task, so public facts were read from a pinned GitHub mirror, not from its Flask application/API. No mirror application code is bundled. The exact commit, source-file SHA-256 and sampling recipe are in `Vendor/ChessData/PROVENANCE.json`. Original Lichess puzzle data is released under CC0; source reference: https://database.lichess.org/#puzzles.

`Openings.json` contains 3,865 legal named opening lines from lichess-org/chess-openings, with ECO, UCI, name and normalized board key. The upstream CC0 license is preserved. Canonical position keys include turn/castling, exclude clocks and suppress irrelevant en passant targets, so transpositions share an explorer node.

To reproduce optionally (Python 3.12, chess==1.11.2):

```sh
git clone https://github.com/Ali-Raza764/chess_puzzles_api.git /tmp/chessvision-puzzles
git -C /tmp/chessvision-puzzles checkout 94e65c36af8358a04d3c835984435845fc638fe3
git clone https://github.com/lichess-org/chess-openings.git /tmp/chessvision-openings
git -C /tmp/chessvision-openings checkout 3ba6b20d31b2e6125cb0e6a2e792f400717d9d39
python Scripts/build-training-data.py /tmp/chessvision-puzzles/puzzles_10000.csv /tmp/chessvision-openings
```

Verify the source hash in provenance before regenerating. These commands are for data maintenance, not required to build/open the Xcode project.

## Difficulty and adaptive selection

Estimated difficulty = max(200, round-half-up(source Lichess rating × 0.8 / 50) × 50). This is an explicitly uncalibrated Chess.com-style proxy. There is no evidence that it equals a player's Chess.com game or puzzle rating. Learner estimate starts at 1000 and updates with a K=40 Elo-style expected-score rule. First mistake/hint/skip grades the attempt incorrect; an entirely unassisted multi-ply solve grades it correct. Retries within the same attempt do not multiply rating changes. Selection chooses nearby unseen difficulties, then repeats the library once exhausted. Progress stores attempt/solve counts and used IDs locally.

## Personal repertoire

The PGN importer accepts SAN or legal UCI, tags, move numbers, annotations, comments and main lines. Variations/comments are skipped; separate saved lines represent repertoire branches. Board input always uses legal standard-chess moves and supports promotion. A training line must contain at least one move for its chosen side. Training accepts any saved branch at a matching canonical position and preserves the chosen branch when identical initial moves overlap. Opponent moves are automatic. Successful completed lines move their due date out; helped/incorrect completions remain due. Data is local JSON with atomic writes and a retained backup before recovery from corruption.

## Public profile import

Chess.com: fetch archive index, then newest monthly public exports sequentially until the requested sample is filled. Lichess: fetch NDJSON with SAN moves and no clocks/evals. Both normalize into legal opening histories; non-standard games, custom starts, incomplete or malformed games are skipped and counted. Samples are capped at the explicit UI choices 200/1,000/5,000 recent games; opening trees cover 40 half-moves. Only the user-entered public name is sent to the selected service. HTTPS/TLS remain enabled; no passwords, API tokens, private games or cloud backend are required.

Tree insertion validates an entire game before mutating statistics. Each position counts at most once per game, so repeated knight shuffles do not inflate frequencies. Results show White wins, draws and Black wins; filters select which side the queried player played. Imported profile identity remains attached to results when the search field is edited. Imports are cancellable and rate-limit responses honor Retry-After; long requested cooldowns are reported instead of retried early.

The cloud policy prevented live API/database connections. A network draft adding api.chess.com, lichess.org and database.lichess.org was saved, but remained unapplied at last check. Actual endpoint access and API compatibility still require live validation. The real client was exercised with isolated representative HTTP/JSON/NDJSON/error fixtures; this is not evidence of live connectivity. These cloud restrictions do not configure networking on the user's iPhone.

## Engine and variants

Fairy-Stockfish fairy_sf_14, commit f3e6969d11d1bec17eba26e7ae0e629ad4af71dd, is compiled into the app with NNUE disabled. It owns actual game legality, SAN, drop pockets, check counters and terminal conditions. The bridge reconstructs a position from the official variant start and validates each history move, rather than accepting arbitrary FEN into native code. Swift waits for variant-ready and bestmove barriers before changing rule tables or replacing searches.

Engine requests have identities and cancellation continuations. A departing analysis screen cancels only its own analysis kind, so it cannot cancel a newly opened computer tab. CPU play uses single-PV finite searches and target-strength options; analysis restores full-strength three-PV infinite search. Typed blindfold moves are matched to the current legal SAN/UCI list; hidden board mode also removes piece names from accessibility labels. Crazyhouse drops can be entered in notation or by selecting a pocket piece and target square.

Ratings are approximate requests. The engine exposes UCI_Elo 500–2850; sub-500 requests use its minimum skill, over-2850 requests use full strength. No calibration experiments against Chess.com users or each variant have been performed. Full strength is limited by the pinned classical engine and per-move think time.
