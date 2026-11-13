# Version 0.26 checklist

| Request | Current implementation |
| --- | --- |
| Brighter colors and premoves | More vibrant nine-theme palette, brighter dark-mode accents, stronger cyan premove fill and blue stroke; primary text still chooses an AA-contrast foreground. |
| Final Standard analysis | Final board and bar already present; now also seeds the score from a valid cached final-position search when available. Otherwise ordinary positions search in the background; terminal results display immediately. |
| Research identity | Already present: imported username/opponent identifies move options; description “Explore an account.” |
| Developer bot | Already present: configured target 2407, Italian as White, e5 vs e4 and Nf6 vs d4. This remains an engine target, not a measured USCF rating. |
| Learn | 27 curated lessons, 16–40 half-moves (8–20 full moves); three additional legal London, Scandinavian and Modern lines. Search also filters to this range. |
| Achievements | Existing difficulty order retained; King tucked away is absent; includes 10000 games. |
| Stats | Completed game totals, color breakdown, results and time-category bars; improvement patterns aggregated from reviewed games. Unknown time controls remain Untimed. |
| Profiles and countries | Existing profile pictures/countries, friend search and country collection retained; online features use the configured Game Center/CloudKit services. |
| World map | Country fill retained; pinch zoom 1–6×, bounded pan while zoomed, double-tap/reset button and accessibility zoom actions added. “Countries fill in” text removed. |
| Play / New game | Existing separate centered page, collapsed Game options below Start, exclusive opponent choices and distinct Settings/New game buttons retained. |
| Train an opening | Already present immediately after Your Repertoire in Openings. |
| Puzzle button contrast | Existing darker-green skip/next button with white text retained. |
| Move counts | Full-move pairs, rounding up after White's move, retained. Live move section now shows “[N] moves” with a downward chevron underneath. |
| Bughouse information | Existing shortened setup/rotation screen retained; necessary state/results still shown. |
| Game type | Existing prominent menu button retained; descriptive paragraph absent. |
| Analysis navigation | Latest request takes precedence: solid white/black swipe bar by side to move. Existing hold-to-promote/demote/delete branches retained. |
| Music | Existing approximately 400-second quiet Field/Burgmüller score-based collection retained; earlier familiar themes remain removed. |
| Daily puzzle | Offline day-based selection, saved completion and first-result grading, replay without earning duplicate rating points. |
| Take back / Resign | Solid yellow / red action backgrounds with contrasting text. Existing rated-game takeback restrictions retained. |
| Insights | Local view state defaults off; enabling one analysis view no longer globally enables others through saved preferences. |
| Review progress | “Reviewing move [N]” only, without the half-move counter. |
| Review display | About review removed; compact icon/color/SAN corrections; gold star before the exact top move, otherwise star “Top: [move]” on the right. |
| Game estimates | Separate heuristic estimates for White/Black after enough assessed moves; explicitly not calibrated USCF equivalents. See RATINGS.md. |

Linux checks cover core rules/data/persistence and native game models. SwiftUI device layout, gestures and UI test execution still require Xcode on macOS.
