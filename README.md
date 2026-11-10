# ChessVision for iPhone

A native SwiftUI chess app with five bottom tabs: **Analysis**, **Play**, **Puzzles**, **Openings**, and **Clock**. Camera recognition, training, saved repertoire and computer games run locally. Opening explorer downloads public games only when you enter a username and request an import. No account, subscription or paid API is required.

**Build status:** prepared for Xcode 16+ and iOS 17+. This Linux environment cannot compile or launch an iOS UI. Portable Swift, actual C++/Swift engine workflows, all bundled puzzle/opening data and variant rules have been tested here. See [Validation](Documentation/VALIDATION.md) for executed versus unrun checks. Photo recognition remains experimental.

## Open on your Mac

1. Open **`ChessVision.xcodeproj`** in Xcode 16 or newer. Do not open `Package.swift` for the app; that package contains the portable core/test workflow.
2. Select **ChessVision** and an installed iPhone Simulator, then press **⌘R**. No Homebrew, CocoaPods, model downloads or project generation is needed: models, engine, artwork, 2,000 puzzles and 3,865 opening lines are bundled.
3. Press **⌘U** for hosted/unit/UI tests. These SDK/UI tests have not been run in this cloud machine.
4. For a real iPhone, connect/trust the device, enable Developer Mode if asked, select your Development Team under **Signing & Capabilities**, use a unique bundle ID if required, select the device and run. Camera capture requires a physical iPhone and camera permission.

## The app sections

### Analysis

Photograph a physical chessboard directly overhead with White's home rank at the bottom. Review/correct pieces as needed; orange uncertainty highlights are optional and do not block an otherwise valid position. Choose whose turn it is and explicitly set any castling/en passant state. Tap **Analyze with Stockfish**.

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

A real **Fairy-Stockfish** engine handles the rules and computer moves. Targets from 1 to 10,000 may be entered; its built-in limited-strength control spans 500–2850, lower requests use the weakest setting and higher requests full strength. These are approximate targets, affected by hardware/variant/classical evaluation, not guaranteed measured Elo. The pinned engine uses classical evaluation with NNUE disabled, so there are no network weights or external services.

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
