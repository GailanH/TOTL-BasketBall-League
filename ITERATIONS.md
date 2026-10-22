# TOTL Iteration Log

One entry per working session or meaningful change, newest first. Covers **both tracks**: the app (code) and the business (plan, funding, research). Every Claude session should append an entry before it ends.

Entry format:

```
## Iteration N: YYYY-MM-DD: short title
Track: App | Business | Funding | Both
Changed: what was actually done (files, docs, decisions)
Decided: decisions Gailan made (or "none")
Open: what's left / next step
```

---

## Iteration 13: 2026-10-21: Underdog wins
Track: App
Changed:
- Underdog bonus: if every winner is in a lower metal (Rookie, Bronze, Silver, Gold, Diamond, Elite) than every loser, each winner gets +5 per metal of gap, capped at +10 (`underdogBonusPerMetal`, `underdogBonusCap`). Favorites lose only the normal amount. The results popup says "Underdog win!".
- Sample league gained G41 (Oct 18): three Silvers beat rico_s, jaylen_w and dev_o.
Decided: underdog bonus only with a full metal gap between the teams (Gailan): 3 Silvers vs 3 Golds qualifies; 2 Silvers + 1 Gold vs 3 Golds doesn't.
Decided (follow-up): favorites don't lose extra (losing is already tough); a 2+ metal gap pays +10, never more.
Open: none.

## Iteration 12: 2026-10-21: MVP scope: proof-of-concept league on rented courts
Track: Both
Changed:
- Added the MVP section to `ROADMAP.md` (app, courts, website, social, legal/ops, fundraising prep, cost, order of work) and updated `CLAUDE.md` next steps.
- Researched San Antonio venues: City of SA community-center gyms (Ramirez $30/hr; Garza, Hamilton, Woodlawn Lake $50–90/hr), Alamo City All-Stars Sportsplex (Universal City, $90–100 per full court/hr, multiple courts), Factory of Champions (call), Order On The Court ($36/hr, 1 basketball court). Northside ISD is out (youth non-profits only).
Decided: MVP first. Start by renting courts for a proof of concept. The app is the main selling point, with fundraising and marketing alongside. Coaching, merch and the full 6-court facility are the end goal. Game times and places go on social media and in the app (D10).
Also: wrote `APP_MVP_BRIEF.md` (standalone brief for the app session) with a new notifications section for game locations and times; ROADMAP M1 now points to it.
Open: Gailan exploring Supabase before choosing the backend (D5); set success gates (D11); call venues; TrueLoyal agreement check; name clearance and LLC.

## Iteration 11: 2026-10-21: Anti-inflation rebalance, Your Standing card
Track: App
Changed:
- Fixed the crash when opening the Leaderboard after the Rank Timeline: rebuilt the journey chart from plain Swift Charts (unique ids, axis labels instead of RuleMark annotations). Confirmed by Gailan on the simulator.
- Sample league: 40 games, about 15 per player.
- Rebalanced scoring (simulated): old rules drifted +5.6 RP per player-game (about +83 a season) because winners always gained while losers barely lost, and below-average stats cost half what above-average stats earned. New rules: result-led, with win +10, loss -15, SVP -7 (a great game can still reach +5), MVP +5, winner minimum +3, stat score at half weight, stats ±2 per unit both ways. Drift is now about +0.3 per game. On the sample season, league-wide inflation fell from +1,416 to +367 RP (about 220 of that is placements), with 16 demotions instead of 4.
- Leaderboard: every placed player gets a "Your Standing" card (place of total, tier progress bar, RP to next tier, gaps to the players above and below). The top 3 keep the celebration and also show their gaps. Players in placement get a note. When the card scrolls off it collapses into a pinned bar; tapping the bar jumps to your row.
Decided: larger loss penalties, smaller for the SVP (Gailan). Inflation is handled in the scoring itself, with the season soft reset still re-spreading the ladder each season.
Open: tune with pilot data (D8); consider an underdog adjustment (beating a higher-ranked team pays more).

## Iteration 10: 2026-10-21: Startup cost model, staged launch plan
Track: Business
Changed:
- Built `~/Documents/Project Comp-B/TOTL Startup Cost Model.xlsx` (formulas, all inputs on one Assumptions tab with sources). Tabs: Summary, Assumptions, Pilot League, Facility Monthly, Facility Startup, 3-Year Projection, Launch Checklist, Sources.
- Researched San Antonio inputs: court rental ($36/hr Order On The Court; $50–90/hr City of SA Woodlawn Lake gym), CBRE Q1 2026 warehouse rent ($7.84/sf NNN), SA league prices (YMCA $70–100/team; Sportskind $125 free agent / $925 team), flooring and goal costs, insurance medians, Texas LLC ($300), USPTO ($350/class), SBA 7(a) basics.
- Base-case results: business setup ~$4k. Pilot season (1 night, 60 players, $150 fee) loses ~$1.4k; ~69 players breaks even; ~$17k worst-case cash to launch. Own 2-court facility (15,000 sf warehouse): ~$680k cash to open (~$136k owner/crowdfunding + ~$544k loan at 20% equity), ~$48k/month fixed incl. loan.
- Findings: (1) included coaching as 1-on-1 makes Competitive members worth ~$1/month after coaching cost; break-even 2,700 members. As group clinics: ~1,080 members. (2) Even with group clinics, the facility needs ~$310k more than the startup total during the ramp at 40 net members/month. (3) Texas Health Spa Act: annual plans or auto-pay require SOS registration ($100) + $20–50k security.
Decided: open to renting court time or leasing a 2-court space ("whichever is possible"); takes it in steps. Running TOTL alongside the TrueLoyal job; no set cap on personal investment.
Open: confirm D10 staged launch (proposed); D9 coaching format; get real quotes (court rental, insurance, lease NNN, contractor); set pilot success gates; check TrueLoyal employment agreement for outside-business/IP clauses; levers to close the facility gap (youth club rentals, pricing, smaller/shared space).

## Iteration 9: 2026-10-21: Podium celebration, rank journey timeline
Track: App
Changed:
- Leaderboard: players in 1st–3rd get a celebration header (medal, "You're #1!", one-time confetti, skipped with Reduce Motion). Top-3 rows show medals and a gold/silver/bronze outline for everyone. A "You" tag marks the viewer.
- Rank Timeline is now a season journey: RP after every ranked game, plotted by date with tier boundaries, plus a start → now summary and the list of rank changes. Players who never change tier now see their season too (the old chart needed two tier changes).
- Record Game: "Add Player" opens a searchable player list instead of a menu (scales to many members; the menu never opened in UI tests).
- Sample league backdates the season start to the first sample game. New `-loadSampleLeague` launch argument for UI tests.
Decided: top 3 get a celebratory leaderboard (Gailan's idea); podium medals are visible to everyone.
Open: confirm the look on the simulator; tune copy and animation.

## Iteration 8: 2026-10-18 → 10-21: Running it on the Mac, UI tests, test tooling
Track: App
Changed:
- Ran the app on Gailan's Mac (Xcode, iPhone 17 Pro Max simulator). It launched cleanly on the v2 data model. CI now publishes the generated Xcode project to the `generated-xcodeproj` branch, since the Mac has no XcodeGen.
- UI tests (`UITests/LeagueFlowUITests`): record a game end to end, leaderboard rules, season reset, player view, sign-up. Screenshots go to the `ui-screenshots` branch.
- Games CSV import (real staff feature) gained an optional `date` column and records games oldest first. Shared `CSVTable` reader and `AccountValidation` rules (sign-up uses them).
- `DebugTools/` (Debug builds only, removable): demo launch arguments, plus "Load Sample League" on Edit Player Accounts (18 test players and 18 games, built in because simulator file drag-and-drop didn't work). A test-account CSV import was built and then removed: the sample league covers testing, and real members only come from sign-up.
- The games CSV logic moved out of the Record Game screen into `GameCSVImporter`, shared by the file import and the sample league.
Decided: no member/account import at all (removed; Gailan sees no future need); real accounts always come from sign-up with a user-chosen password; nothing builds on DebugTools.
Open: Gailan to try the sample league; UI test for game flow to confirm green.

## Iteration 7: 2026-10-18: Seasons, win/loss scoring, MVP/SVP
Track: App
Changed:
- Committed and pushed the Aug–Sep work as `a105fb1`.
- Core Data model v2 (versioned, migrates automatically): new `Season` and `Match` entities. `Game` gained team, won, award, isPlacement. `Player` gained placementGamesRemaining. `RankChange` gained season and reason. Removed the template `Item` entity.
- `CompetitiveRules.swift` holds every tunable number. `RankSystem` has rebuilt tier averages that rise with rank, plus per-stat caps. `MatchScoring` handles win/loss, MVP/SVP, and placement.
- `MatchRecorder` is the single path for recording, editing, and deleting games. `SeasonManager` creates seasons and runs the soft reset.
- UI: Record Game (two teams plus winner), team-based CSV import, Seasons screen, placement status on dashboard and overview, a season-scoped leaderboard that hides players in placement, and W/L and MVP/SVP in game lists.
- Tests: RankSystemTests rewritten; new MatchScoringTests and MatchRecorderTests.
- CI fixed: it had been failing since August because of a hard-coded Xcode 16 and iPhone 16 simulator. It now builds and passes all tests (`9c11591`).
Decided: D1 all 5 stats. D2 50 RP per level. D3 3-month seasons with soft reset and placement. D4 winners gain, only the SVP can gain on the losing team, MVP/SVP awards. D5/D6 deferred. D7 start with a rented 2-court gym. Focus on the app.
Open: click through on the Simulator; tune the starting numbers with real games (D8); consider a staff MVP/SVP override and season history views.

## Iteration 6: 2026-10-18: Unified project plan + iteration log
Track: Both
Changed:
- Re-surveyed both source folders (`TOTL-BasketBall-League` repo, `Project Comp-B` business docs). Found the local repo far ahead of GitHub: ~1 month of uncommitted work (see Iteration 5) and stale README/ROADMAP/CLAUDE.md.
- Rewrote `CLAUDE.md` with the new project goal: build the business plan, the prototype app, and the fundraising plan **in parallel**. Business planning is no longer deferred.
- Rewrote `ROADMAP.md` as the unified project plan (App, Business, and Funding tracks, phased, with open decisions).
- Created this log. Mirrored a short version into Claude project memory.
- README rank list updated from 10 tiers to the current 14.
Decided: Project scope = business plan + prototype app + crowdfunding raise, developed together.
Open: commit the uncommitted work; settle the RP open decisions (D1–D4 in ROADMAP.md); start the startup-cost model.

## Iteration 5: 2026-08-11 → 2026-09-13: Staff roles, CSV import, tests (local, UNCOMMITTED)
Track: App
Changed (reconstructed from file timestamps and diff; not yet committed to git):
- Ranked ladder expanded from 10 to 14 tiers (Diamond III–I and Elite) to match the business plan. Elite is the uncapped top tier.
- `RankSystem.rpGain` became the single scoring function for manual entry, CSV import, and game edits. `Game.rpDelta` stores each game's RP effect.
- Ranked play limited to Competitive members (`AppConstants.isRanked`).
- Employee self-registration now requests `employee_pending` and needs approval by existing staff. The hardcoded employee secret key is gone. Added the `administrator` role, and the owner username auto-registers as admin.
- New: `EditGameView` (edit/delete games), CSV batch game upload in `AddGameView`, `GameStatBounds` (stat sanity limits), `SessionStore`, `PasswordField`, `CardStyle`, AppBackground color, app icon.
- Unit test target with `RankSystemTests`, `PasswordHasherTests`, `AppConstantsTests`. CI switched from `xcodebuild build` to `xcodebuild test`.
- Business plan rewritten as `TOTL Business Plan.docx` (2026-08-21) from the original "Project Comp-B" draft.

## Iteration 4: 2026-08-06: Hashing, rank consolidation, XcodeGen + CI (pushed)
Track: App
Changed: commits `cd49512` (passwords salted/hashed via CryptoKit, rank logic consolidated into `RankSystem.swift`, >550 RP "Unranked" bug fixed, vision docs) and `1e70268` (`project.yml` XcodeGen spec, GitHub Actions CI). Both are now on `origin/main`.

## Iteration 3: date unclear (claude.ai chat, against the pre-August code): Bug audit
Track: App
Changed: 7-bug audit produced a `RankUtils.swift` approach and fixes to rank boundaries, timeline chart, RP caps, leaderboard filtering, Unranked comparisons, coaching swipe-to-delete. Most of these were later addressed differently in the repo (`RankSystem.swift`, `isRanked`). **The per-stat vs. total RP cap fix was NOT carried over** (both are still 50).

## Iteration 2: 2026-06-07: Code uploaded to GitHub
Track: App
Changed: initial SwiftUI + Core Data app uploaded (Player/Game/CoachingSession/RankChange, login, dashboard, leaderboard, coaching, rank timeline).

## Iteration 1: 2025-04-19: "Project Comp-B" first draft
Track: Business
Changed: original business concept PDF covering facility layout, staff roles, Casual/Competitive memberships and pricing, two-pronged marketing, and the ranked competitive system.
