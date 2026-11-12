# Validation status — five-tab expansion

Target: Xcode 16+, Swift 5 language mode, iOS 17+. Work executed in Debian Linux, with official Swift 6.0.3 and GCC 14. No Xcode/iOS SDK, Simulator or physical iPhone is attached.

## Passed here

- **58 portable Swift XCTest tests**, zero failures. Includes all 2,000 unique puzzles, every solution ply, all 3,865 opening lines/position keys, adaptive-rating behavior, PGN/SAN parsing, result aggregation, transpositions, invalid-import atomicity, repertoire branch matching, persistence codecs, variant FEN/pocket/counter parsing, prior FEN/grid/recognition tests and 585 SAN references across 159 positions.
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

The estimated puzzle and computer strengths are not calibrated Chess.com ratings. The 2,000-puzzle source difficulty proxy is documented. No playing-strength experiment against users or variant-specific Elo calibration was performed.

## Mac / iPhone checks to run

1. `bash Scripts/test-mac.sh`: portable tests followed by real hosted model/data/persistence/engine and UI tests on an installed iPhone simulator. Inspect the fresh `.xcresult`; resolve SDK/compiler/runtime failures before claiming a verified app build.
2. Launch all five tabs; verify both blindfold visibility modes, Crazyhouse pockets/promotions, 3-Check counters and KOTH/Horde endings, side selection, requested openings and save/resume. Inspect centered Analysis title, swipe bar and tapped turn changes; verify a tab switch never steals another tab's engine.
3. Try public profiles from both services and both color filters, cancellation, 404/rate-limit behavior, empty/large archives and complete archive coverage. Compare a few branches with source games.
4. Solve/skip/hint multi-ply puzzles and verify one rating update per attempt, progress restoration and estimated difficulty selection. Enter overlapping White/Black repertoire lines, train branches/transpositions and restart the app.
5. On iPhone verify camera recognition/cancellation, memory/thermal behavior, icon appearance, board-image sharing and current recognition limitations. Obtain held-out labeled photos for remaining king/bishop and missed-piece failures.
6. Review GPL/AGPL corresponding-source, public-service terms and App Store/privacy requirements before any production distribution. GitHub source publication does not mean the application has been released or approved for a store.

## Version 0.5 checks

All 960 Chess960 layouts matched python-chess piece placement and legal start moves. Five sampled histories matched legal moves and exercised five castling moves. Real app-model workflows passed all 13 styles, including a random Chess960 game, replies, takebacks, persistence and return to standard Analysis. Settings and generated audio have structural/resource/privacy checks; playback, SwiftUI appearance, screen readers, and iPhone layouts still require Xcode/device verification.

## SwiftUI type-checking fix

The recognition screen is split into separate screen, starting options, progress overlay and editor builders. The progress label is an explicit String rendered with Text(verbatim:), outside the large view-builder expression. Toolbar items are explicit; board cells, colors and accessibility labels also have separate type-checking boundaries. Swift syntax parsing and project/resource checks passed. The reported Xcode type-checking timeout cannot be reproduced or confirmed resolved on Linux; a full Xcode build is still required. No new chess-rule behavior was introduced.

## Version 0.6 crash investigation and deep checks

Reproduced native assertions with assertions enabled (ENGINE_ASSERTIONS=1). The first was in PieceSet pop_lsb during optimized startup; the integration lacked upstream's required -fno-strict-aliasing. After adding that flag, a separate legal/TT-move assertion appeared during variant switching. Clearing transposition/search state with ucinewgame before the readiness barrier resolved that regression. No assertion was disabled to make these checks pass.

Passed with assertions enabled: native smoke/perft and controller replacement/cancellation; 1,366 independent rule positions and 11 endings across seven variants; all 960 Chess960 starts plus sampled castling histories; all 13 real computer-game models, no-kings Pawn Wars, takebacks, save/reload and Analysis handover. The full model suite, including a multi-turn 3-Check game, also passed with Clang. Portable Swift tests: 58 passed; all 2,000 puzzles and every solution ply validated. All original 1,000 puzzle IDs remain present.

HTTP fixture regressions imported 1,200 games across multiple Chess.com months and 1,005 Lichess games without a max parameter, alongside missing-record, PGN fallback and 404 cases. The Apple streaming transport and live remote services still require macOS/device verification. Updated UI tests cover direct first-board moves; no iOS UI or audio/device test was run in this Linux workspace. These checks reduce known failure risks; they cannot guarantee the absence of all future errors.

## Version 0.7 appearance checks

All 36 added vector piece assets have verified original SVG hashes and complete white/black king, queen, rook, bishop, knight and pawn membership. A contact sheet of all four sets was inspected for intact rendering and distinct silhouettes. Icon dimensions/opacity, duck asset presence, resource paths and Swift syntax are checked. The glyph-based renderer and old analysis heading are absent. Native iOS appearance, settings migration, navigation/tab bars, and device layout still require Xcode verification; the contact sheet is an artwork check, not an iOS screenshot.

The existing portable core suite passed all 58 tests after adding the appearance catalog. Engine/rules code is unchanged by this appearance update.

## Version 0.8 clock and game-flow checks

63 portable Swift tests passed, including new elapsed-time/increment, inactive taps, pause/resume, flagging without increment resurrection, background elapsed time, and Duck preview castling/en-passant/promotion regressions. The real app-model suite passed with native assertions enabled: all 13 game styles, multi-turn 3-Check, measured half-second computer Duck staging, cancellation during the preview and safe resumption without a half-saved turn. UI tests were updated for four-tab navigation, combined opening destinations and the clock. These iOS UI tests, idle-timer behavior and visual layouts remain unrun on Linux.

## Version 0.9 assessment and game recording

68 portable tests passed. New tests cover pins/open files, independent pawn-structure findings, pawn forks, engine-plan wording, ordinary opening priorities, custom-start move numbers, branching and a recording reset after a manual turn edit. Existing recognition, legal move, puzzle and clock tests also pass. iOS tests now decode a generated GIF, check frame count, distinct frames, looping/timing, and exercise the notation toggle/GIF menu. Those Apple ImageIO/UIKit/UI tests remain unrun in Linux; only source syntax and project/resource checks can run here.

After adding dead-material and 50-move-claim assessment, the focused 10-test insight suite also passed. GIF frame creation and rendering still require the prepared native test on a Mac.

## Version 0.10 history and game review

77 portable tests passed, including backward-compatible library decoding without history/game IDs, personalized seventh-move corrections, accepted alternate repertoire branches, Black-perspective evaluation losses, suppression of small/no-loss corrections, missed-mate and variant-goal labels, repertoire cache signatures and history/review serialization. The focused review suite also passed after the final count helper was added.

Assertion-enabled Clang/native app-model tests passed all 13 game styles plus natural checkmate and resignation archival, duplicate protection, separate history identity after takeback, repertoire-first review, engine correction of a real Qxf7 mate oversight, review checkpoint/cancel/resume, and persistent replay/review data. Reviews were exercised under Chess960, 3-check, Duck, Crazyhouse and Antichess. Continuous-analysis controller cancellation/replacement/regression checks also passed with the new finite review requests.

A prepared iOS UI test checks automatic review after resignation and the Game history entry point. It remains unrun here. SDK compilation, modal transitions, board replay layouts, app background/foreground behavior and accessibility still require Xcode/device verification. Engine feedback is a quick comparison, not an exhaustive proof of every mistake or concept.

## Version 0.13 polish verification

94 portable Swift core tests passed, including new Chess960 king-to-rook/stationary-king projection and diagonal pawn projection regressions. Assertion-enabled feature checks cover opening import cancel/restart, previous-result preservation on failure, stale error recovery, all thirteen single-board game modes, linked Bughouse, premoves, reviews, clocks and persistence. Project regeneration, asset membership, source parsing and whitespace checks passed. The new mallard PNG was visually inspected with its transparent background and copied unchanged into the asset and artwork source directory.

An iOS UI regression for the new Saved photos entry point is included but has not run here. This Linux environment cannot compile SwiftUI against the iOS SDK or validate actual iPhone layouts, VoiceOver, camera presentation, clock sheets or orientation. Those checks remain for Xcode/device testing.

## Version 0.14 engine upgrade

Official Stockfish 19 (sf_19, commit edb0d9db6731067ec50ce619ff372b463bc4dd5d) is linked in an isolated namespace alongside Fairy-Stockfish. Its full default network nn-1a298aa575a0.nnue has the independently verified 98,511,183-byte size and SHA-256 1a298aa575a085434d29027978dc36867fe9c5bcea9376654b7a8eba1e52dfc2.

The embedded bridge matched the official Linux release's exact move **and** score at fixed depth 12 in five positions: start, tactical middlegame, forced mate, pawn ending, and Black to move after e4. Settings were one thread, 16 MiB hash, MultiPV 1, full strength, fresh process. Expected results and origin are checked in at Tests/modern-engine-reference.json. Missing and malformed networks return an engine error through the bridge instead of terminating the host process. These checks are not an Elo measurement or a proof of universal move accuracy.

94 portable core tests passed. Assertion-enabled controller tests passed continuous analysis, latest-position replacement, cancellation, terminal handling, restart, NNUE routing, strength reset after rated play and one/three-line searches. Assertion-enabled app workflows passed all ordinary variants, linked Bughouse, premoves, history, longer engine reviews, repertoire-first corrections and persistence. Project/source membership and network hash checks passed.

Linux checks cannot compile the iOS SDK, measure iPhone thermal/memory behavior, or verify Apple NEON execution. The checked-in macOS CI now runs the network/reference checks before the native and Xcode tests; device performance and Xcode build remain to be verified there.

## Version 0.15 analysis and game navigation

Source/project checks verify the complete Chessnut/Celtic vector assets and their original SVG SHA-256 values, bringing the additional sets to 60 verified pieces. A board-scale contact sheet of both new sets was visually checked for complete rendering, recognizable silhouettes and both colors.

The iOS regression suite now covers a Candidate lines switch, no engine continuation through forward arrows/swipes, back/forward through played moves, dismissing a finished-game banner, and pushing a full New game screen without a sheet. These screen tests cannot run in this Linux environment and remain for Xcode/Simulator. Portable core tests and Swift source parsing remain available here.

## Version 0.15.1 background overload audit

Corrected both invalid `.background(ThemeCardBackground(), in: ...)` calls in AppCard and GameReviewView. Both now use a view-builder background and clip that view to the existing rounded shape. Audited all remaining background, fill, stroke and foreground-style calls, including all ThemeCardBackground references, for the same View/ShapeStyle mismatch.

Project/asset validation, Swift source parsing and whitespace checks passed. The full macOS test script was attempted here and stopped because Xcode is not installed in this Linux environment. It cannot establish iOS SDK type checking locally. The GitHub macOS workflow now performs a simulator SDK build first, before the model/native tests, so SwiftUI type errors surface earlier.

The 94 portable core tests passed with zero failures. Assertion-enabled native app workflows also passed: all thirteen single-board modes, linked Bughouse, premoves, import fixtures, history, personalized reviews, persistence and analysis handover. These native checks do not replace SwiftUI SDK compilation.

## Version 0.16 progression and correspondence

New portable tests cover Elo updates and duplicate protection, separate per-mode ratings, adaptive adjustments/bounds, legacy-library migration, three queued premoves canceling one at a time, actual pawn-mate recognition and promotion exclusions, Black-perspective move grading, summary sample limits, correspondence move/turn validation, mate/resignation, malformed payload rejection and stable archive IDs. Native app-model checks cover rated settlement, disabled rated takebacks, persistent adaptive strength, and grading both sides with the mating blunder identified.

Game Center integration is source-parsed only in Linux, not SDK type-checked or tested against Apple services. API names/nullability were cross-checked against GameKit headers; iOS compilation and two-account/device invitation, acceptance, timeout and reply testing remain required. The app entitlement is included, but enabling Game Center on the developer app ID and App Store Connect record requires the owner's Apple developer setup. A three-day timeout is sent to Game Center for every handed-over turn; the first invitation/move uses Game Center's initial matchmaking lifecycle. Multiplayer ratings are not claimed or implemented; saved ratings are for bot games.

The final portable run passed 108 tests with zero failures. Assertion-enabled app-model workflows passed all variants, rated-result settlement/duplicate prevention, rated takeback protection, adaptive assessment persistence, and complete two-sided review grades. Controller tests passed continuous full-strength SF19 analysis and the restored three-line mode. The enlarged clock Start control has an added iOS screen regression, not executed here.

## Version 0.17 NovaChess/social/screen recognition

The rename regenerates the NovaChess project/scheme, targets, hosted test imports, bundle identity, app/storage/export names and all first-party paths. Original upstream model/source metadata and the existing GitHub repository URL are retained; the only legacy source name is the explicitly tested old-container backup migration path.

Portable tests cover canonical/reserved usernames, copy-only old-library/photo migration, digital-template/empty-square recognition, and malformed public-board data. A hosted iOS test constructs a borderless 2D board inside screenshot UI and also tests Black-at-bottom rotation. CloudKit and GameKit API names were cross-checked against SDK headers/interfaces. Linux cannot SDK-type-check SwiftUI/CloudKit or run Vision/Core ML; the hosted screenshot test and real two-account player/friend/consent/invitation tests remain unexecuted here. See PLAYERS_AND_SPECTATING.md for schema, permissions, deployment and owner setup.

Final portable run: 112 tests passed. Assertion-enabled native app workflows passed under the NovaChess source paths, including variant/bughouse play, rated/adaptive games, premoves, two-sided reviews and persistence. All 144 project references, entitlements, network/source hashes and Swift syntax checks passed. Screen photographs and live CloudKit friend/consent flows are not validated by these portable/native checks. The privacy manifest now declares optional user identifiers and user-published content for app functionality, without tracking.


## Version 0.18 recording, folders and automatic spectating

Portable suite: 115 tests passed; the subsequent focused camera suite passed all four tests after adding manual recovery. Coverage includes repeat-frame legal-move acceptance, uncertainty resetting stability, missed-move rejection, undo, manual SAN recovery, saved folders round-tripping and older-library defaults. Engine controller checks passed with actual Stockfish 19 NNUE. Assertion-enabled native feature checks exercise all variants, Bughouse, rated/adaptive play, premoves, reviews and persistence. Swift syntax, project membership, entitlements and bundled-network hash checks passed.

The camera pipeline uses AVFoundation on a serial queue, throttles recognition to one observation per two seconds, pauses on background/disappearance and stops a pending permission request from starting capture after dismissal. Recognition and notation remain local. This does not establish real-world camera recognition accuracy: angled-board occlusion, physical-device lifecycle, SwiftUI/AVFoundation SDK type checking and live CloudKit publication require Xcode and signed-device testing. Linux has no Apple SDK or simulator, so a completely error-free iOS build cannot be certified here. Existing CloudKit schema must still be deployed by the Apple account owner; NCConsent is no longer used.


## Bughouse 0.18.1

Six focused portable Bughouse tests passed, including increased deliberation/search in critical positions and bounded timing in severe time pressure. Assertion-enabled native Bughouse checks passed for transfers, drops, promoted captures, four clocks, three AI seats, consecutive premoves, pause/resume, save/resume, flagging and two-board review. Swift syntax and project/hash validation passed. The landscape layout reserves narrow side columns for clocks and populated pockets and no longer sends move/premove targets to BoardView. Visual sizing and touch interactions still require Xcode/iPhone verification because this environment has no Apple SDK or simulator.


## Version 0.19 drag, Standard and delay

All 120 portable tests passed, including new first-turn/later-turn delay, increment interaction, deadline and pause/resume checks. The complete assertion-enabled native feature suite passed, including thirteen game styles, Bughouse, Standard consecutive premoves and invalid-queue cancellation, rated/adaptive games, reviews and persistence. Swift syntax and project/hash checks passed. The clock UI test now expects Apply rather than Start on the time-control form.

The shared interactive BoardView maps drag points through the current board orientation and uses the same legal-move/premove handlers as taps. Editor dragging relocates pieces directly. Pocket drag payloads are validated and then passed through existing drop legality. These SwiftUI gestures, visual contrast, clock toolbar layout and final-position evaluation UI still require Xcode/simulator and signed-device verification; Linux has no Apple SDK. The app cannot be certified free of every potential error from these checks.

A dedicated native draw workflow passed early rejection, engine-based balanced-position acceptance, archive result, duplicate protection and persisted restoration. Run it with `bash Scripts/test-draws.sh`; CI includes it after the normal feature checks.


## GameKit SDK nullability fix (0.19.1)

CorrespondenceService, its screens and friend invitations now use explicit match-property accessors. Match ID is explicitly promoted to String?, participant arrays to [GKTurnBasedParticipant]? before applying a fallback, and creation dates to Date? before applying a fallback. This handles SDK imports with either nullable or nonnullable declarations without conditional-binding errors, redundant nil-coalescing warnings, or force unwraps. Actual optional containers (selected match, current participant, player, callback data/errors) retain their checks.

Four correspondence core tests passed. The production accessor file type-checked with warnings treated as errors against two small synthetic GameKit interface modules, one declaring these properties nullable and the other nonnullable. This verifies the compatibility contract, not the entire Apple SDK. All Swift sources parsed, project membership and asset/hash validation passed, and git diff checks were clean. A full Xcode SDK build remains unverified in this Linux environment; the macOS CI workflow builds the iOS target before running other checks.


## Version 0.20 analysis continuity and clock/music polish

Eight focused clock tests passed, including resuming from the inactive face without completing a move or resetting delay. Native controller checks passed with additional assertions for same-position search retention, immediate cached candidate restoration, rapid-request cache isolation, and exact review-cache reuse. The full assertion-enabled feature suite passed, including all ordinary variants, Bughouse, rated/adaptive games, Standard premoves, history and reviews. Source parsing and project/resource/hash validation passed. The generated mono soundtrack is 189.9 seconds and is bundled with its original composition/synthesis source.

New review early termination requires depth 20, at least 0.8 seconds, stable three-ply PV and evaluation agreement across increasing depths; mate scores do not use this shortcut. The time limit remains three seconds for harder standard review positions. Results remain subject to search uncertainty. Analysis continues across tab changes; true iOS background execution may be suspended by the OS. The UI, audio listening quality and device thermal behavior require Xcode/iPhone verification, unavailable in this Linux environment.


## Version 0.20.1 Bughouse waiting, premove recaptures and harder achievements

The initial full portable run passed 125 tests; the subsequent focused run passed 35 tests after adding pawn recapture and existing-progress milestone migration coverage. These cover queen/pawn recaptures onto currently friendly squares, rejecting the queued move when the opponent does not capture, the exact 10000-game threshold, duplicate protection, tougher wins/variant requirements, and preservation of earned dates.

The assertion-enabled full native feature suite passed with blockable-rook waiting, real interposition, and adjacent/knight/double-check mate cases. The additional Bughouse workflow covers bishop checks, both colors, actual partner capture transferring a knight, recovery from a waiting position, and post-game review with the partner-dependent move left ungraded. Swift syntax, project membership and resource/hash checks passed. Xcode compilation and physical-device UI checks remain unavailable in this Linux environment.


## Version 0.21 profiles, statistics, Developer and interaction polish

The portable suite passed 127 tests before adding new targeted coverage. Fifteen targeted statistics/progression tests passed, followed by the final four statistics/Developer tests after tightening explicit bot-source classification. Coverage includes color/result/category totals, duplicate game IDs, ungrouped counts, 52→26 and 53→27 move-pair counts, time boundaries, country validation, achievement order/removal and legal Developer book moves. Assertion-enabled Developer model checks passed the Italian White sequence and both specified Black replies at target rating 2407. The full native app-feature suite passed across ordinary variants, Bughouse, ratings/adaptive play, premoves, history and review.

All Swift sources parsed and project/hash/resource checks passed, including offline geometry for at least 230 regions and major-country codes. Hosted UI expectations now check final evaluation before explicitly opening review. Avatar/country CloudKit fields, photo selection/rendering, Canvas map drawing, auto-scroll, premove coloring and layout need Xcode/iPhone verification; this Linux environment cannot SDK-compile or simulate those APIs. The new NCProfile schema fields must be deployed by the Apple account owner before production profile edits will work. Country choice is self-reported, not device location or verified residence.


## Version 0.21.1 puzzle expansion

Added 2000 puzzles for 4000 total, retaining every previous record and ID unchanged. The pinned source CSV SHA-256 matched provenance. Python-chess verified every source FEN, full solution and uniqueness of all normalized post-setup solving positions. All 19 Swift ExpansionTests passed, including legal replay of every solution ply in the 4000-puzzle asset, adaptive selection and progress behavior. Project/resource/hash checks and git diff checks passed. No puzzle-rating history reset or app API change was required.


## Version 0.22 review prefetch and persistent evaluations

Twelve targeted checkpoint, review-logic and grading tests passed. The actual Swift/native controller suite and full assertion-enabled feature workflows passed with idle review prefetch enabled, including ratings, adaptive play, premoves, variant and Bughouse reviews, cancellation, history and pause/resume. A dedicated workflow used separate OS processes to rebuild a four-ply review from persisted evaluations, launched zero new engine searches, and reproduced every grade/loss/depth. It also verified that idle evaluation does not play a move, yields to play, prunes takeback branches, transfers scores on game end, and retains all reviews while bounding persisted raw caches to 64 entries.

Resource-size estimates use measured source bytes and DEFLATE compression, not a signed iOS archive. Device review performance, energy/thermal behavior and actual App Store size require a Release Xcode build and an iPhone. The full Stockfish 19 NNUE asset and normal review search budget remain unchanged.


## Version 0.23 analysis branches and setup/clock changes

All 137 portable tests passed after updating the earlier Black-first clock expectation to the user's clarified increment rule. New tests cover retaining alternate analysis continuations, promotion/demotion, subtree deletion, root protection, replaying existing continuations without duplication, saved variation codecs, first presses by either color at 3+2, resumed clock presses and existing delay/flag rules. The assertion-enabled native feature suite passed across game variants, Bughouse, ratings/adaptive play, premoves, history and review. Project/resources, 4000-puzzle membership, model hashes and all Swift syntax checks passed.

The 209.9-second generated mono WAV has valid headers and uses app-generated arrangements of public-domain themes. Subjective audio quality, the pink palette, menus/disclosures, notation long-press actions, variation replay selection and opening lessons require Xcode/iPhone verification; Linux cannot compile the Apple UI SDK or run the simulator. Core tree/clock behavior is executed in the portable suite. Existing CloudKit profile deployment requirements remain unchanged.

## Version 0.24 rating checks

`swift test`: 145 tests, zero failures. New checks cover provisional wins/draws/losses, the effective-games formula and high-rating cap, minimum and invalid-input handling, through-25 provisional status, adaptive/out-of-range eligibility, complete-history recalculation, incomplete legacy seeds, unsupported-opponent point removal, and one-time puzzle-scale migration. All 4000 difficulty values were independently matched to the original pinned upstream CSV; IDs, solutions and all other retained puzzle facts were unchanged.

The assertion-enabled native feature suite passed, including all ordinary modes, bughouse, persistent rated/adaptive games, premoves, history and review. Project/resource validation and Swift syntax parsing passed. The focused native rating workflow verifies that LibraryStore persists migration exactly once and that ComputerGameModel rejects unsupported rated targets before creating a game. These checks establish implementation behavior, **not** statistical calibration against USCF-rated humans. iOS SDK type-checking and device UI checks require macOS/Xcode, unavailable in this environment.
