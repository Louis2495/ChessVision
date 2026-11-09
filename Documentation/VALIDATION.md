# Validation status — five-tab expansion

Target: Xcode 16+, Swift 5 language mode, iOS 17+. Work executed in Debian Linux, with official Swift 6.0.3 and GCC 14. No Xcode/iOS SDK, Simulator or physical iPhone is attached.

## Passed here

- **54 portable Swift XCTest tests**, zero failures. Includes all 1,000 unique puzzles, every solution ply, all 3,865 opening lines/position keys, adaptive-rating behavior, PGN/SAN parsing, result aggregation, transpositions, invalid-import atomicity, repertoire branch matching, persistence codecs, variant FEN/pocket/counter parsing, prior FEN/grid/recognition tests and 585 SAN references across 159 positions.
- **1,366 native variant positions** compared with python-chess for standard, 3-Check, King of the Hill, Horde, Crazyhouse, Atomic and Antichess. Legal moves, move spelling, positions, castling, check counters and pockets matched. Includes 103 drops, 11 completed variant games and an explicit promoted-queen capture reverting to a pawn in Crazyhouse.
- Actual Swift app models with real embedded Fairy-Stockfish passed: twelve game styles plus the no-kings Pawn Wars option, computer replies, White/Black play, takebacks, rating targets including below/above the limited-strength range, requested opening replies, persistent save/reload and transfer back to continuous Analysis. Linux shims only Combine observation; controller/model/rules/client source executes unchanged. No SwiftUI UI is emulated.
- Duck compound turns (640 start moves, neutral blocker), no-kings pawn-race finish and Fog-of-War king capture passed native regressions. Atomic/Antichess SAN suffix conventions differ from python-chess; their move spelling and legal sets were compared independently of those suffixes.
- The real public-game client passed isolated Chess.com archive/PGN, Lichess NDJSON, non-standard-game filtering and missing-profile HTTP fixtures, incomplete-record handling and monthly PGN fallback. A recorded public Chess.com game also passed the parser regression. No credentials or live connections were used for these checks.
- Actual controller/engine tests passed readiness, increasing analysis depth, last-request-wins replacement, stale-result clearing, cancellation, checkmate/stalemate, restart and cancellation ownership across Analysis/computer play.
- Native engine smoke checks passed UCI/MultiPV, no-legal-move handling, infinite-search cancellation and standard perft(3)=8,902. Portable perft references also cover Kiwipete and an en passant position.
- Both recognition artifacts/source checksums remain bundled. Prior classifier-only benchmark remains **296/320 correct squares (92.5%), 0/5 exact positions, 7/10 kings correct**; this expansion makes no new recognition-accuracy claim.
- New app-icon export is opaque RGB 1024×1024; original generated artwork is preserved. Swift syntax, all project paths/source membership, model/data assets, engine flags, shared scheme and plist structure were checked.

## Not verified here

**The updated iOS UI has not been compiled, launched or visually exercised in Xcode.** Swift parsing, Foundation model compilation and C++ checks cannot establish SDK type correctness or on-device layouts. Hosted/native/UI tests and macOS CI are prepared but unrun here.

Live Chess.com/Lichess API and database access was blocked by the current cloud domain allowlist. The network draft was saved but the running policy still had no custom domains at last check. Source data was obtained from allowed public GitHub mirrors. Live public exports, service rate limits and real-profile coverage remain unverified; fixture tests are separate evidence.

The estimated puzzle and computer strengths are not calibrated Chess.com ratings. The 1,000-puzzle source difficulty proxy is documented. No playing-strength experiment against users or variant-specific Elo calibration was performed.

## Mac / iPhone checks to run

1. `bash Scripts/test-mac.sh`: portable tests followed by real hosted model/data/persistence/engine and UI tests on an installed iPhone simulator. Inspect the fresh `.xcresult`; resolve SDK/compiler/runtime failures before claiming a verified app build.
2. Launch all five tabs; verify both blindfold visibility modes, Crazyhouse pockets/promotions, 3-Check counters and KOTH/Horde endings, side selection, requested openings and save/resume. Inspect centered Analysis title, swipe bar and tapped turn changes; verify a tab switch never steals another tab's engine.
3. Try public profiles from both services and both color filters, cancellation, 404/rate-limit behavior, empty/large archives and the explicit sample cap. Compare a few branches with source games.
4. Solve/skip/hint multi-ply puzzles and verify one rating update per attempt, progress restoration and estimated difficulty selection. Enter overlapping White/Black repertoire lines, train branches/transpositions and restart the app.
5. On iPhone verify camera recognition/cancellation, memory/thermal behavior, icon appearance, board-image sharing and current recognition limitations. Obtain held-out labeled photos for remaining king/bishop and missed-piece failures.
6. Review GPL/AGPL corresponding-source, public-service terms and App Store/privacy requirements before any production distribution. GitHub source publication does not mean the application has been released or approved for a store.
