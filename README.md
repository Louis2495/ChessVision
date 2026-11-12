# NovaChess for iPhone

A native SwiftUI chess app with five bottom tabs: **Analysis**, **Play**, **Puzzles**, **Openings**, and **Clock**. Camera recognition, training, saved repertoire and computer games run locally. Opening explorer downloads public games only when you enter a username and request an import. Local analysis and training need no account. Optional player profiles/friends/public spectating use iCloud/CloudKit; correspondence invitations use Game Center. No subscription or paid analysis API is used.

**Build status:** prepared for Xcode 16+ and iOS 17+. This Linux environment cannot compile or launch an iOS UI. Portable Swift, actual C++/Swift engine workflows, all bundled puzzle/opening data and variant rules have been tested here. See [Validation](Documentation/VALIDATION.md) for executed versus unrun checks. Photo recognition remains experimental.

## Open on your Mac

1. Open **`NovaChess.xcodeproj`** in Xcode 16 or newer. Do not open `Package.swift` for the app; that package contains the portable core/test workflow.
2. Select **NovaChess** and an installed iPhone Simulator, then press **⌘R**. No Homebrew, CocoaPods, model downloads or project generation is needed: models, engine, artwork, 2,000 puzzles and 3,865 opening lines are bundled.
3. Press **⌘U** for hosted/unit/UI tests. These SDK/UI tests have not been run in this cloud machine.
4. For a real iPhone, connect/trust the device, enable Developer Mode if asked, select your Development Team under **Signing & Capabilities**, use a unique bundle ID if required, select the device and run. Camera capture requires a physical iPhone and camera permission.

## The app sections

### Analysis

Choose Physical board or Screen / screenshot from the camera menu, and choose whether Black is at the bottom. Photograph the whole board, or import a screenshot. Review/correct pieces as needed; orange uncertainty highlights are optional and do not block an otherwise valid position. Choose whose turn it is and explicitly set any castling/en passant state. Tap **Analyze with Stockfish**.

**Analysis** has a centered inline title, filled vector pieces, standard algebraic move notation, three candidate tabs with White/Black columns, a right-side evaluation bar and a color-to-move square. Tap that square to flip the turn (clears en passant and discards future playback). Invalid state is explained rather than sent to the engine.

Swipe the bar immediately below the board left to go forward, right to go back. It moves through recorded positions; at the latest position, forward plays the selected candidate's first move. Analysis deepens continuously, restarts whenever the position changes, and pauses when you leave the screen/app. Board moves, table moves, Previous and Return to original all refresh the evaluation automatically. **Share position** exports FEN, a rendered board image, or both.

Photo recognition uses two physical-piece models and grid validation. Last measured classifier-only sample: **92.5% correct squares, 0/5 exact positions, 7/10 kings correct**, using manual crops of five upstream photos. It is not yet reliable automatic reconstruction. See [Recognition](Documentation/RECOGNITION.md).

### Openings

Enter anyone's public **Chess.com** or **Lichess** username and load all their available public standard games. Choose White or Black, then play moves or tap a branch to see frequencies and White/draw/Black outcomes. The count shows “N games”. The tree covers the first 40 half-moves per game; site availability and rate limits apply.

Endpoints are `api.chess.com/pub/player/.../games/...` and `lichess.org/api/games/user/...`. Requests are sequential where needed, cancelable, and respect rate limits. The user-entered public username is sent only to the chosen site; private repertoire/photos are never uploaded. Live requests were blocked by this cloud instance's network policy; the actual client passed isolated HTTP fixtures, but service access needs validation on device or after enabling the saved network domains.

### Puzzles

Exactly **2,000 distinct, legally validated puzzles** are available offline, with source themes and estimated difficulty. Your training estimate starts at **1000**, rises for unassisted solutions and falls for mistakes, hints or skips. Selection follows your estimate and favors unseen puzzles. A multi-ply puzzle is graded once per attempt; opponent replies play automatically. A legal alternate checkmate is also accepted.

The estimated Chess.com-style difficulty is a heuristic: 0.8 × source Lichess puzzle rating, rounded to 50. It has not been calibrated against Chess.com users and is not an official Chess.com rating. This distinction is shown in the app. IDs, source rating, FEN, solution and original game URL remain available in the bundled data; see `Vendor/ChessData/PROVENANCE.json`.

### My Repertoire

Add a named White/Black line by playing both sides on the board or pasting moves/PGN. The importer preserves the main line, ignores comments/side variations and rejects illegal moves. Add separate saved lines for branches. Swipe a saved line to delete it; open it to review and train.

**Train** plays the opponent's replies, then asks you for your next move. Any saved branch reaching the same position is accepted, including transpositions, while the selected line is preferred when branches share a move. Wrong moves leave the board unchanged. Hints, results and due dates support spaced review. Repertoire and progress persist in the device's private Application Support directory with atomic writes and corrupt-file backup handling.

### Play computer

Choose your color and requested rating, then choose one of:

- Normal chess.
- Blindfold with visible squares but hidden pieces/hints.
- Blindfold text-only, with no board or pieces and SAN/UCI move entry.
- 3-Check: give check three times (or mate).
- King of the Hill: safely bring the king to a central square.
- Horde: White's pawn horde versus Black's regular army.
- Crazyhouse: captured-piece pockets and legal drops, including promoted-piece reversion to pawns.
- Duck, Atomic, Fog of War, Pawn Wars (kings on by default, optional pawn race), and Antichess.

Official **Stockfish 19 with its exact default NNUE network** handles standard-chess analysis, review and computer opponents rated 1320 or higher. **Fairy-Stockfish** handles variant rules/searches and weaker standard opponents. Targets from 1 to 10,000 may be entered, but they are approximate rather than measured Chess.com Elo. The official engine's calibrated range is 1320–3190; higher requests use full strength. All analysis and review use full strength regardless of the selected playing rating. The 98.5 MB neural network is bundled for offline use; no model download or external analysis service is needed.

For **Normal** only, **Request an opening** searches 3,865 named lines. The computer follows that book line while your moves match it, then returns to normal play when you deviate or leave the line. You are not forced to play the requested moves. Games persist, can be resumed, taken back or resigned. Switching tabs pauses their engine work.

The home-screen icon is new original artwork of a simple ivory chess-knight silhouette on a forest-green background. The 1024px opaque asset is checked in; its original is preserved in `Artwork/`.

## Validation commands

```sh
swift test
bash Scripts/test-engine.sh
bash Scripts/test-controller.sh
bash Scripts/test-features.sh
bash Scripts/test-mac.sh
```

`test-mac.sh` selects an available iPhone simulator (`SIMULATOR_ID=<UDID>` overrides it) and produces a fresh `.xcresult`. The controller/feature harnesses run actual Swift app models and the real C++ engine. On Linux only Combine observation is shimmed; no SwiftUI rendering is simulated. Mac runs use real Combine.

For independent variant comparisons, optionally install `chess==1.11.2` in a virtual environment and run `python Scripts/test-variants.py`. Rebuilding bundled data is optional; see [Training and profile details](Documentation/TRAINING.md). Source files and the checked-in Xcode project are ready to open without those developer tools.

## Licensing and release status

The combined app remains **AGPL-3.0-or-later**. Fairy-Stockfish/Stockfish and piece artwork retain their GPL notices. Puzzles and opening facts are CC0; provenance and notices accompany the project. Source, model conversion/training code and artwork sources are included. See [Third-party details](Documentation/THIRD_PARTY.md).

No App Store submission or distribution approval is implied. SDK/device validation, recognition improvements, exact public-service terms and GPL/AGPL corresponding-source/App Store compatibility still need review before a production release. GitHub source updates do not establish a successful Xcode build or published app.

## Version 0.4

Cleaner screens, an info button for privacy/licenses, illustrated promotion choices, faster provisional puzzle placement, a repertoire-training evaluation bar, and a new knight-and-lens icon. Play has a linked rating slider/number field and adds Duck, Atomic, Fog of War, Pawn Wars (kings optional, on by default), and Antichess. Opening imports tolerate incomplete records and can fall back to monthly PGN exports. See [training details](Documentation/TRAINING.md) for variant rules and limitations.

## Version 0.5

Analysis opens without a photograph: tap **Start analysis** to play from the normal starting position. Scanning remains available. Candidate lines are expandable; optional **Position insights** explains attacked/undefended pieces and bishops boxed in by friendly pawns. These are conservative board observations, not engine-proven tactical explanations.

The gear button opens saved settings for system/light/dark display, Forest/Ocean/Plum accents, warm/cool/default backgrounds, Classic/Walnut/Slate boards and illustrated/traditional pieces. Optional music plays a bundled original classical-style piano prelude, loops quietly, mixes with other audio, and pauses outside the foreground. Regeneration source: `Scripts/generate-music.py`; no streaming or external recording is used.

Play ordering: Normal, Crazyhouse, Fog of War, Chess960, 3-Check, King of the Hill, Atomic, Duck, Horde, Pawn Wars, Antichess, then both blindfold modes. Chess960 selects one of all 960 layouts for each new game and preserves it when saved. To castle in Chess960, move the king onto its rook.

## Version 0.6

The Analysis tab immediately shows the playable starting position, continuous evaluation and optional insights. The camera button opens board scanning; there is no example-editor link. Opening explorer imports every available public standard game: all monthly Chess.com archives, or an uncapped streaming Lichess export. The result count is simply “N games”; site rate limits and export availability still apply.

Puzzle training includes 2,000 unique puzzles, retains every original puzzle ID, and has larger Hint/Next/Skip controls without theme-keyword clutter. Board-based Play modes use taps and promotion pictures; typed moves are available only in the two blindfold modes. Duck chess uses a bundled cartoon rubber duck. The updated home-screen mark is an ivory knight with a mint diamond.

Engine integration now follows upstream's no-strict-aliasing requirement and clears search state when switching variants. The native checks can run with assertions enabled using `ENGINE_ASSERTIONS=1`; CI uses that mode to catch assertion failures instead of masking them.

## Version 0.7 appearance

Settings now offers 12 board palettes, 8 color themes and 11 backgrounds, including subtle Aurora/Sunset gradients and a grid. Accents, navigation bars, tab bars, backgrounds, list cards, secondary pages, sheets and board selections follow the chosen appearance. Shared board headers also use the selected theme. Semantic warning/error colors remain distinct.

Piece choices are Illustrated, Merida, Sculpted and Fantasy, each with complete vector artwork for both sides. The font-based piece option is removed; old selections migrate to Illustrated. Existing board and theme preferences remain valid. The analysis screen has no “Find your next move” heading. The home-screen icon is now an ivory rook on navy, and the cartoon duck has a small highlighted eye and a gentler face.

The additional sets retain their creators’ licenses and source attribution; see Documentation/THIRD_PARTY.md.

## Version 0.8 navigation, clock and game flow

The bottom bar is now **Analysis → Play → Openings → Clock**. Openings contains two large cards: **Your Repertoire** above **Research** (the former opening explorer). Puzzle training remains available from the top of Play; its Hint text and bulb are yellow.

Clock includes 1+0, 2+1, 3+0, 3+2, 5+0, 5+3, 10+0, 10+5, 15+10 and 30+0 presets, plus custom minutes, seconds and increment. Start begins White's timer; tapping a face before starting begins the opponent's timer. During play, tap the running face after moving to add increment and switch sides. Pause/resume and confirmed reset are available. Elapsed system uptime keeps the clock accurate when changing tabs or briefly backgrounding. The clock screen stays awake while running; the session resets if the app is terminated.

Finished computer games display a large **White wins / Black wins / Draw** button on the board; tapping it opens new-game setup. Blindfold text-only games show the same large result without revealing a board. Computer Duck turns visibly move the piece, wait half a second, then place the duck. Interrupted previews are canceled without partially saving a turn.

The artwork has been refreshed to a cream king on teal and a soft yellow baby duckling.

## Version 0.9 assessment, notation and animated sharing

The bottom bar is **Analysis → Play → Puzzles → Openings → Clock**. Puzzles is a dedicated tab again. Clock setup has a small centered **Start** button without the explanatory paragraph.

Position insights now assess material, checks and mate, attacked/loose pieces, pins, skewers and double attacks, isolated/doubled/passed pawns, promotion races, central pawn space, the bishop pair, limited mobility, rook files and seventh-rank activity, knight outposts, pawn shelter, development/castling and endgame king activity. Current Stockfish evaluation and its main continuation provide additional context. Observations are ranked; the top six appear immediately and the rest are expandable. They are board-based observations and engine context, not a claim that every geometric threat wins material.

**Show notation** displays the actual played line up to the selected position in White/Black columns, separately from engine candidates. It respects the current branch, move numbers and custom starts. A manual position/turn edit starts a fresh notation segment.

After playing a move, **Share position → Share game GIF** exports an animated GIF of the recorded positions through the current point. It loops, pauses at the beginning/end, follows the selected board/piece styles, supports cancellation, and removes temporary files when sharing finishes. Still-image and FEN sharing remain available. GIF export uses Apple's ImageIO and awaits native Xcode tests; it cannot be executed in Linux.

## Version 0.10 game history and personalized review

Completed games in Play are archived automatically and open a post-game review. Use the **Game history** button at the top left of Play to replay past games and reopen saved reviews. Resignations and natural finishes are saved once; taking back a finished game creates a new game identity and preserves its archived result.

For standard chess (including the blindfold modes), each of your positions is compared with all saved repertoire branches, including transpositions. Any saved continuation is accepted. A deviation shows the expected move(s), the actual move number and the repertoire line name, with a direct training link. It is labeled as repertoire recall rather than an objective engine mistake. Positions outside your repertoire use quick full-strength engine comparisons before and after your move. Variants always use their own rules; Chess960, Duck, 3-check, Crazyhouse and Antichess reviews have native workflow coverage.

The **Areas for improvement** section groups the actual suggestions from that game into themes such as opening recall, king safety, mating patterns, tactics/material, pawn decisions, piece activity, endgame technique, calculation and variant goals. Each area names its example moves; each suggestion can jump to its replay position. Engine labels are provisional at the displayed search depth, with about 250ms spent on each before/after position. No official accuracy or rating claim is made.

Reviews save progress, support pause/resume and reuse completed results. Changing repertoire moves or names refreshes the personalized review; training dates alone do not invalidate it. Existing puzzle progress, repertoire and active games migrate without resetting. History and reviews remain on this device; no external account or analysis service is used.

## Version 0.11 Bughouse

Choose **Bughouse → Set up Bughouse** in Play, then turn the device sideways. You control board A; three computers fill the remaining seats. Set all four displayed player ratings (your own is descriptive; the other three control computer strength), choose your color, and select a preset or custom time control. Strength is approximate.

Captures supply the same-color partner on the other board, including captured promoted pieces reverting to pawns. Select a pocket piece and a highlighted square to drop it. Both boards run simultaneously with four increment clocks. A decisive board result, resignation or first flag ends the team match. Pause, leaving the screen, backgrounding, or rotating upright pauses both boards; saved matches resume paused. Bughouse requires landscape, while other screens retain portrait orientation.

Finished matches automatically open review and appear in Game history, with both boards available for replay. Review assesses your moves on board A using Bughouse engine rules and groups suggestions into areas for improvement. Partner-board consequences are not fully evaluated by the engine. Existing games continue to receive automatic personalized post-game reviews.

Validation: 81 portable Swift core tests and assertion-enabled native feature checks, including pocket transfers, drops, promoted captures, check-blocking drops, three AI seats, four clocks, persistence, flagging and two-board review. iOS compilation, rotation and layout require macOS/Xcode validation.

## Version 0.12 premoves and deferred photos

Settings → Moves has **Premoves** (on by default) and **Auto-queen** (off by default). Queue multiple moves while the computer thinks, including repeated moves by the same piece. Tap an unrelated board square to remove the last queued move, once per tap. Blindfold text input accepts coordinate premoves such as `g1f3` or `a7a8q`, and a cancel button is available when the board is hidden. Every queued turn must match the native legal moves when it is due; an illegal intent clears the remaining dependent queue. Pausing, leaving a game, taking back, resigning or starting another game clears premoves.

Premoves work in every computer variant, including two-stage Duck turns and pocket drops in Crazyhouse/Bughouse, and during puzzle/repertoire opponent replies. Analysis and repertoire editing play immediately because they have no opponent waiting phase. Auto-queen applies to board promotion gestures throughout the app; with it off the piece picker remains available, including king promotions in Antichess.

The Analysis camera menu offers **Take photo · choose afterward**, **Take photos for later**, and **Saved photos**. Choose immediate recognition or save the image without recognition. Continue with **Take another** to collect multiple positions during a game. Saved JPEGs remain in the app's protected local storage across relaunches; open them individually for analysis afterward or swipe to delete. No Photos library permission or upload is needed.

The analysis history control is now a thicker bar with arrows and **Swipe** inside. Clock setup no longer shows the tap-to-start sentence, and starting by pressing a clock face now awards the first completed move's increment. Research now says “Explore games on a chess.com or lichess account.”

## Version 0.13 interface polish and reliability

Analysis, Research, Play setup and puzzle stats now use consistent themed cards. Opening navigation has clearer icons and chevrons; game notation and review details expand on demand. Analysis has a direct Photos button, a simpler camera menu and a helpful saved-photo empty state. Board selection and legal targets have better contrast across palettes; VoiceOver now identifies the duck and selected square, and static board previews no longer advertise tappable squares. The duck is an original mallard illustration with natural coloring and proportions.

New-game setup pauses the existing computer game and resumes on dismissal, including after backgrounding; Bughouse setup no longer restarts the other game behind the sheet. Clock setup pauses the timer, restores it on cancel, and starts White when a new control is confirmed. Clock controls adapt to wider text. Opening imports isolate canceled requests, retain previous results on failure, and clear obsolete errors on filtering. Chess960 castling and diagonal pawn premove previews preserve the correct pieces.

Validation includes full portable core tests, assertion-enabled native game/review/import workflows and project/source checks. These do not replace iPhone/Xcode checks for layout, VoiceOver, camera presentation or rotation.

## Version 0.14 official Stockfish 19 NNUE

The Analysis tab now uses the latest official stable Stockfish release (`sf_19`, verified 2026-11-10), with its **full default nn-1a298aa575a0.nnue model**. The previous standard search used Fairy-Stockfish with neural evaluation disabled. The engine uses up to four search threads when available and a 192 MiB hash table. Analysis always runs at full strength continuously; the opponent rating never weakens it.

Settings → Analysis offers one candidate line (default, deepest search) or three alternatives. The best move is visible without opening the continuation. Search depth and engine/model identity appear beside the board. Different engines, depths, multi-PV counts, castling/en-passant rights and search histories can still produce different scores; this upgrade does not claim perfect analysis or equal results at unequal budgets.

Standard post-game reviews allow up to **3 seconds on each before/after position**. Stable Stockfish searches can finish sooner after depth 20; completed identical requests are cached. Existing saved reviews are invalidated by an engine/model/search-policy version so they refresh automatically when opened. Progress/pause/resume and repertoire-first suggestions remain available. Full games consequently take longer to review. Variants retain Fairy-Stockfish because official Stockfish does not implement their rules, and low-rated standard opponents retain its weaker settings.

The bundled NNUE is 98,511,183 bytes, SHA-256 `1a298aa575a085434d29027978dc36867fe9c5bcea9376654b7a8eba1e52dfc2`. Builds verify that hash. No LFS setup, model conversion or internet is required to build on a Mac. The app displays a model-loading failure rather than silently using classical evaluation. See Vendor/Stockfish19/NOVACHESS.md and Scripts/test-modern-engine.py for provenance and fixed-depth comparisons against the official release.

## Version 0.15 played-move navigation and game setup

Analysis has a **Candidate lines** toggle next to Position insights and Show notation. Turning it off hides the suggestions without stopping analysis. The swipe bar and arrows navigate only existing played history: forward is disabled at the last position, even when the engine has a continuation. Choosing a suggestion explicitly can still play it on the board.

**New game** pushes a full options screen in Play, with normal back navigation and the complete rating/color/variant/opening controls. The finished-game result rectangle now dismisses when tapped, leaving the final board visible. It never opens setup, and tapping it also suppresses a pending automatic review presentation. Review game and the separate New game action remain available.

Settings now includes two more conventional piece sets, **Chessnut** and **Celtic**, with 24 additional vector pieces. Existing styles and selections remain available. All asset source hashes and licenses are included; no conversion or download is required on a Mac.

## Version 0.15.1 SwiftUI build correction

The shared card and game-review suggestion backgrounds now use SwiftUI's view-builder background overload, with rounded clipping. This fixes the compiler error requiring ThemeCardBackground to conform to ShapeStyle. The remaining custom-background usages were audited; list row backgrounds accept views, and the remaining background-in-shape calls use colors or materials. GitHub's macOS workflow now compiles the iOS app before its longer native checks.

## Version 0.16 play progression, reviews and friends

Clock faces display only the times. Tap the centered time-control button to change controls; setup has a larger Start button. Puzzles now say simply “White to move” / “Black to move.” Research says “Explore games on a chess.com or lichess account.” Sharing offers separate FEN/image actions and **Share GIF**; the combined image+FEN action is removed. Candidate lines always has three tabs again; hiding the Candidate lines section does not reduce the engine search to one line.

**Rated bot games** save a separate local rating per game mode, starting at 1000, using an Elo update (K64 for the first ten games, K32 afterward). Use my rating sets the bot target to your current rating. Results settle once; rated takebacks are disabled, and starting another game forfeits an unfinished rated game. These ratings are local bot ratings, not Chess.com/Lichess ratings. Adaptive difficulty is a separate unrated option: a short engine comparison after each human move raises/lowers the bot's target. Its target and last assessed turn are saved so pause/resume does not apply the same adjustment twice.

Normal games keep the most recently identified opening name visible as play continues. **Rematch** lets you select White or Black before starting; rated rematches use your updated rating. Multiple premoves remain queued in order, with one unrelated-square tap canceling the most recent entry; a three-entry cancellation regression covers this explicitly.

**Game reviews** grade both players' moves as Best, Excellent, Good, Inaccuracy, Mistake, Blunder or Book. The replay shows an icon at the last moved piece and a text grade. Game summary shows counts, rated-game changes and a rough move-quality rating estimate after at least eight assessed non-book moves. This estimate is not a calibrated platform Elo. Engine comparisons are cached across adjacent positions to avoid searching the same position twice; reviews remain incremental and can pause/resume. Old reviews refresh under the new assessment version.

**Achievements & ratings** in Play shows unlocked/locked goals, including a genuine unpromoted-pawn checkmate, knight mate, promotion, castling, milestones and variant exploration. Bot results and completed correspondence games contribute; online matches remain unrated.

**Play with friends · Correspondence** uses Apple's Game Center turn-based service, including its native invitation picker, invitation acceptance, reply syncing, multiple simultaneous games and a 259,200-second timeout for each handed-over turn. Refresh or return to the app to sync; turn events are listened for while connected. Opening an invitation accepts it. Every received move history is replayed and validated before use. Completed games are archived locally and can be reviewed. The initial invitation/first-move phase follows Game Center's matchmaking lifecycle; three-day reply deadlines start when a turn is handed over. No app-owned server or player-message access is needed.

### Enable Game Center before testing invitations

Game Center requires an Apple Developer app ID with Game Center enabled, matching bundle ID/signing team, and Game Center enabled for the app in App Store Connect. In Xcode, select your team in Signing & Capabilities and ensure the Game Center capability is active; the entitlement is included. Sign into Game Center on two supported devices/accounts to test an invitation and a reply. A Personal Team may not support this capability; bot-only builds can omit the entitlement, but online matches will then be unavailable. Cloud Linux checks cannot authenticate Apple accounts or exercise the live service.

## Version 0.17 NovaChess, players and screen boards

The app, source directory, Xcode project/scheme, targets, tests, user-visible text, export filenames and bundle ID are now **NovaChess** (`com.novachess.app`). Open `NovaChess.xcodeproj`. This deliberately creates a separate Apple app identity; the former app's Game Center matches do not transfer, and a new app sandbox cannot read the old installed app's files. If an old app-container backup is restored into the new container, the storage helper copies its legacy library/photo folder without deleting the original. The GitHub repository URL remains Louis2495/ChessVision; its hosted repository name is not changed by a source/project rename.

Play → **Players & friends** supports unique iCloud-backed usernames, prefix search, friend requests, accept/decline, a friend list, and Game Center invitations to linked friends. Player profiles and **Watch public games** provide read-only, periodically refreshed spectator boards. Game boards publish automatically for signed-in NovaChess profiles, without spectator approval controls. Camera recordings and saved folders stay local.

The social features require CloudKit container `iCloud.com.novachess.app`, its record types/indexes/permissions, and the new Game Center app ID to be configured by the owner. **Read [Players and spectating setup](Documentation/PLAYERS_AND_SPECTATING.md)** before testing or distributing these features. The source and entitlements are included; Apple account setup and live service verification cannot be performed from this Linux environment. Local bot/training features do not contact CloudKit unless social/publication is used.

The camera menu now has **Physical board** and **Screen / screenshot** modes, **Black at bottom**, and **Import screenshot**. Screen mode accepts edge-to-edge boards, broader perspective candidates and padded search windows around a board inside surrounding UI. It compares square images with all six bundled vector sets at multiple scales, falling back to the existing classifier and flagging uncertain matches. This supports common 2D screen styles; unusual graphics, glare, moiré and severe perspective can still require corrections. Saved photos expose the same source/orientation settings. The actual screen pipeline has a hosted iOS screenshot/orientation regression, which requires Xcode to run.


## Version 0.18 recording and folders

Analysis → camera menu → **Record game notation** watches a physical board from a fixed phone beside the board. Keep all four corners visible, orient White/Black nearest the camera before starting, and begin at the normal position. Each completed move must remain unobstructed for at least two observations (roughly four seconds). Only a unique legal next move with no uncertain squares is recorded. Pause to undo a false observation or enter missed moves in SAN, then resume. Very low side angles that hide pieces cannot be reconstructed reliably. This records notation, not a video file.

Use **Save game** in Analysis, **Save** in the recorder, or swipe a History game to save it. **Saved games** contains local replayable games. Create custom folders and long-press a game to move it. Deleting a folder keeps its games under Unfiled. Saved-game data is included in the existing atomic local library file; older libraries load with empty folders.

Spectating no longer uses consent switches or records. CloudKit/Game Center still require the Apple account and schema setup in Documentation/PLAYERS_AND_SPECTATING.md.


Bughouse 0.18.1 uses full-height landscape boards with compact clocks/pockets alongside them. Empty pocket types are omitted on both sides, and move/premove target dots are hidden. Bots spend at least 1.4 seconds on routine moves and 2.8 seconds when in check, facing promotions or multiple tactical options, with a smaller allowance under time pressure. Real engine search also gets a larger budget in critical positions; pause, flagging and transferred-piece revision checks still interrupt or invalidate pending decisions.


## Version 0.19 interaction and clock updates

Interactive boards support dragging as well as tapping, including flipped boards, analysis, puzzles, repertoire, the photo editor and live games. Crazyhouse and Bughouse pocket pieces can be dragged onto squares; the normal legal-move/premove checks still decide whether a move can execute. Read-only history and spectator boards do not move pieces. Selecting your piece during the opponent's turn keeps that selection after their reply unless the piece was captured. Standard supports consecutive premoves; assertion-enabled native checks exercise them across multiple computer replies.

Normal is now labeled **Standard** without changing stored game identifiers. Standard computer games have **Offer draw**: bots decline before move 11 and accept a later offer only when the engine reports a balanced position (within 0.80 pawns, no mate score). Agreed draws persist, archive once and count as draws. Finished Standard games show a final-position evaluation bar and score immediately, with the review available from its button. Checkmate/stalemate/draw scores are handled without waiting for an engine search.

Research identifies whether the displayed choices belong to the imported username or the opponent, alongside White/Black. Theme accents are brighter in dark appearance and background tints are softer to improve contrast.

Clock has Reset in the top bar, no Settings or Start button, and starts by tapping a clock face. Its centered time-control button opens setup; Apply returns to a ready clock. Custom controls now offer delay as well as increment. Delay applies afresh each turn, including the first turn, and pausing preserves only the unused part of that turn's delay.


## Version 0.20 analysis continuity, clock and music

Analysis actions are a single bottom row: Share, Save, Reset. Rating text uses ungrouped decimal strings throughout the app. Settings retain only premove cancellation instructions; the Stockfish and classical-music descriptions were removed.

Leaving the Analysis tab no longer stops its search. Re-entering the same active position does not submit a new search. Up to 32 positions retain candidate results in memory, restored immediately after another engine feature interrupts analysis; resumed searches retain the engine's transposition table and do not replace a deeper displayed result with a shallower one. iOS may suspend execution when the app is backgrounded, and process termination clears these session caches. No background execution entitlement is requested.

Completed review evaluations are memoized for up to 256 exact variant/history/budget requests. Stockfish review searches retain their three-second maximum but may stop after at least 0.8 seconds and depth 20 when successive deeper iterations agree on the first three moves and evaluation within 0.10 pawns. Mate searches retain the full budget. Hard positions keep searching to the time limit. This remains a heuristic search, not a guarantee that deeper analysis will agree. SAN conversion no longer restarts for depth-only updates, and insight generation is less frequent. The engine remains official Stockfish 19 with its full NNUE network.

The original piano soundtrack now lasts approximately 190 seconds, with four contrasting sections, varied melody/accompaniment, dynamics and a resolved cadence. Foreground playback resumes from its previous time rather than restarting the opening phrase.

Clock uses a top-left Pause control and resumes from either face without switching sides or adding increment. The time-control button is hidden during active play and available before starting, while paused, or after flagging. Increment and delay use singular “second” for a value of 1.


## Version 0.20.1 achievements, recaptures and Bughouse waiting

New game milestones cover 100, 500, 1000 and **10000 completed games**; win milestones cover 100 and 1000 wins. Variant explorer now requires eight different game modes. Previously earned achievements are retained, and existing saved totals unlock newly qualifying milestones when the library loads. Finished-game IDs still prevent duplicate counting.

Premoves can target a square occupied by a friendly piece, allowing the opponent to capture it before the queued recapture. Movement geometry is checked when planning; the real rules engine checks legality when execution is due. If the opponent does something else and the friendly piece remains, the premove is canceled rather than capturing it.

In Bughouse, having no legal move in check does not end the match if a future piece drop could interpose. The bridge tests a hypothetical non-pawn drop using native legality; it does not add that piece to the actual pocket. The board waits, its clock keeps running, and the partner board can supply a real piece. Bots skip waiting boards rather than requesting an impossible move. Adjacent attacks, knight attacks and unblockable double checks still produce genuine mate. Blockable checks use '+' rather than '#'. Queued responses are retained while a board has no legal move.

Single-board reviews cannot evaluate future partner deliveries. Checking moves that leave a board waiting for material are explicitly left ungraded rather than labeled mate; the review explains any such omissions. Run `bash Scripts/test-bughouse.sh` for the linked-delivery and review workflow.
