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
