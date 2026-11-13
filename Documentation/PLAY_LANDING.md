# Play landing and puzzle streaks (0.29)

The first visit to Play in an app session opens the New game landing page directly. It contains Start game, Game options and the community/progress links previously below the computer board: Players & friends, correspondence, saved games, Stats & world map, Achievements & ratings. The same page is used by the existing New game action during play. After starting/resuming, switching tabs returns to the current board rather than forcing another setup.

A saved game is prepared without playing computer moves behind the landing page. Resume game preserves its identity/history; completed saved games use View last game. Starting another game preserves the existing rated-game resignation/settlement behavior. The Start control waits for a saved rated position to be validated, preventing it from being silently overwritten during load. Opening training uses the same passive preparation path. Social publishing/review presentation waits for the board to be opened.

The Standard Offer draw button now has a purple background. Puzzle Hint uses bright cyan with a contrasting foreground. Both foreground/background pairs pass a 4.5:1 contrast check. Puzzles no longer displays the Lichess difficulty row, turn badge, or visible White/Black to move caption. Board orientation and legal-move restrictions remain unchanged; side-to-move information remains available through the board’s accessibility value.

The solved-total block now includes a small `🔥 N` streak underneath. A full unassisted solve increments it; the first wrong answer, hint or explicit skip resets it. Later retries within that attempt do not earn another score. Daily replays are unscored, so they neither inflate nor reset the streak again. Streak and solved totals are saved locally. Older libraries keep their existing totals and start streak at zero because past answer order cannot be reconstructed reliably.

Core and native workflow verification is described in VALIDATION.md. The added UI tests still require macOS/Xcode to execute.
