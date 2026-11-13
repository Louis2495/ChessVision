# Endgame training and Home navigation (0.28)

## Home

Home is now the first/default tab. The five tabs are Home, Analysis, Play, Puzzles, Openings. Clock is launched from Home as a full-screen utility, replacing its old bottom tab. The Home view owns the clock session so closing/reopening its screen during the same app session does not create a new clock. Existing face-to-start behavior, first-press increment, custom delay, pause, reset and time-control setup remain intact. Clock state is held in memory, not restored after terminating the app.

The daily puzzle also launches from Home, using the existing saved first-attempt/completion record. Its replay does not award duplicate rating points. Puzzles remains the independent adaptive trainer and no longer displays the daily card or offline-puzzle-count caption.

## Endgames

Learn adds an Endgames entry. Its 17 curated positions cover queen/rook mates, two bishops, bishop-and-knight mate, pawn promotion, king support, passed/connected pawns, a pawn race, bridge building, third-rank rook defense and material-based drawing tasks. Every start is a legal, nonterminal position, independently checked with python-chess and the Swift rules.

Students play legal moves on the normal draggable board, including explicit promotion choices. Stockfish 19 supplies full-strength finite-search replies from the exercise FEN and complete move history. Hints are requested manually and return SAN without playing a move. Technique tips are collapsed by default. The engine and its full neural evaluation model are unchanged; no tablebase-perfect-play guarantee is made.

Goals are explicit:

- Checkmate: mate the defending king.
- Promote: complete a pawn promotion, including underpromotion. This is a promotion objective, not a claim that every resulting position is a win.
- Hold the draw: reach a real drawn position or valid draw claim; winning also succeeds. The trainer does not award an arbitrary “draw” for surviving a chosen number of moves.

Checkmate/stalemate, insufficient mating material, fivefold repetition and the automatic 75-move rule are handled. The player may claim a draw at a qualifying current threefold position or 50-move count. Checkmate takes precedence over the 75-move threshold. Completion is saved separately from game history/ratings; old libraries default to an empty completed-endgame set. Views pause only their own search on exit/background and resume pending replies on return. Restart cancels stale results.

## Interface refinements

Analysis shows “Stockfish 19 - Depth N” with the actual search depth. Removing the NNUE label does not remove or weaken the engine model. The separate turn square and Swipe text are gone; the theme-filled navigation pill has a white/black turn outline. Its visible pill is 26 points high, with 44-point arrow controls.

New game defaults to Current Rating, then lists Adaptive difficulty, Play the Developer and Custom as exclusive choices. Rated remains separate and adaptive stays unrated. About ratings routes/page are removed. Game options, game type, live move list, technique expanders and shared disclosure groups reverse their chevrons when open. Standard's Offer draw, Take back and Resign controls share one row with orange/yellow/red backgrounds and contrasting text. Openings hub captions are removed.

Learn now retains all 65 previous curated choices and appends 46 more, for 111 legal lessons of 8–20 full moves. CountText selects singular/plural units across move/game/photo/premove/country/session/time labels and progress messages; the old literal “file(s)” insight is also corrected.
