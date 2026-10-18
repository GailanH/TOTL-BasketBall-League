# Project context for Claude

Read this first, then `ROADMAP.md` (the unified project plan) and the top of `ITERATIONS.md` (what changed last). Last updated 2026-10-18.

## The project

**TOTL**: a basketball gym business with a **Casual** side (play, train, take coaching at your own pace) and a **Competitive** side (a ranked ladder where per-game stats earn or lose Ranked Points (RP) and move players through tiers each season).

The project has **three deliverables, developed in parallel**:
1. **Business plan.** Facility, memberships, staffing, marketing, competitive rules, financials. Living doc: `~/Documents/Project Comp-B/TOTL Business Plan.docx`. The original 2025 concept is `Project Comp-B.pdf` in the same folder.
2. **Prototype app.** This repo: SwiftUI + Core Data iOS app (Xcode project `Project_Comp_B`). It runs the competitive league and member/staff workflows, and doubles as the demo for fundraising.
3. **Fundraising plan.** Most likely crowdfunding (Kickstarter or similar), possibly combined with equity crowdfunding and/or loans. Includes everything needed to run a campaign.

Business planning is **not** deferred anymore. When an app decision depends on a business rule (or vice versa), surface it as a decision in `ROADMAP.md` instead of guessing.

## Working rules

- **Log every iteration.** Before ending a session, append an entry to the top of `ITERATIONS.md` (format is in that file). Also mirror a one-line summary into the Claude project memory iteration log when available.
- **Ask before any git commit or push.** (Gailan OK'd commits/pushes for iterations 6–7.)
- Keep replies concise and direct.
- Prioritize correctness and robustness over new features, unless a feature is needed for the demo or the fundraising plan.
- Keep business rules in one place in code: `CompetitiveRules.swift` (tunable numbers), `RankSystem.swift`/`MatchScoring.swift` (scoring), `AppConstants.swift` (roles, memberships), `GameStatBounds.swift` (stat sanity limits). Never duplicate them in views.
- Sources of truth if they disagree: Gailan's latest stated decision > `ROADMAP.md` decisions log > business plan docx > code.

## Repo / build state

- GitHub: `GailanH/TOTL-BasketBall-League`, branch `main`. Pushing works from Claude sessions with GitHub connected. The Mac's own shell has no GitHub credentials.
- `project.yml` (XcodeGen) generates `Project_Comp_B.xcodeproj` (gitignored). Run `xcodegen generate` after adding or removing files.
- CI (`.github/workflows/ios.yml`) runs `xcodebuild test` on GitHub macOS runners with the default Xcode and an available iPhone simulator. On failure, compiler errors and failed tests appear as a job annotation (readable via `gh api .../check-runs/<job>/annotations`, since raw logs may be blocked).
- `.claude/` and `build/` are gitignored.

## Data model (`Project_Comp_B.xcdatamodeld`, versioned, current = v2)

- **Player**: username, email, password (hash), passwordSalt, role, membership, rankPoints, lastRank, placementGamesRemaining, profileImage. Relationships: games, coachingSessions, rankChanges.
- **Match**: one played game. id, date, winningTeam ("A"/"B"). Relationships: season, games (one per player, cascade).
- **Game**: one player's line in a Match. points, rebounds, assists, blocks, steals, team, won, award ("MVP"/"SVP"), isPlacement, rpDelta, date. Relationships: player, match. Older games have no match.
- **Season**: number, name, startDate, endDate, isActive. Relationships: matches, rankChanges.
- **RankChange**: id, newRank, date, reason ("game"/"seasonReset"). Relationships: player, season.
- **CoachingSession**: title, coachName, date, isBooked. Relationship: player.
- Roles: `player`, `employee_pending`, `employee`, `administrator`. Memberships: `Casual`, `Competitive`, `Deactivated`. Only Competitive members are ranked.
- **Schema changes:** add a new model version (never edit the current one in place) so existing data migrates.

## Competitive system (decided 2026-10-18, see ROADMAP D1–D4)

- 14 tiers, 50 RP each: Rookie (0–100) through Elite (701+, uncapped). Tier averages rise with rank.
- All 5 stats count. Each stat vs. the player's tier average: +2 per unit above (cap +15), −1 per unit below (cap −10). Per-game base is capped at +50/−20.
- Winners all gain (min +5). The MVP (best winner vs. own tier) gets +10. Losers can't gain, except the SVP (best loser), who can gain up to +5. If the SVP played below average, they lose RP too.
- 3-month seasons. Staff start each new season: everyone drops 3 tiers to the bottom of that tier, then plays 5 placement games at 2× RP. Players in placement are hidden from the leaderboard.
- Numbers live in `CompetitiveRules.swift`. Logic lives in `RankSystem.swift` and `MatchScoring.swift` (pure, unit-tested). All RP changes go through `MatchRecorder.swift`, and seasons through `SeasonManager.swift`.

## Next steps

Full plan is in `ROADMAP.md`. Focus is the app (business and funding work is paused by Gailan's choice). Launch target is a rented 2-court gym.
1. Click through on the Simulator (`xcodegen generate`, open, run): record a game, start a season, check migration. CI already builds and passes the unit tests.
2. Run a sample season in the Simulator and tune `CompetitiveRules` (D8).
3. Staff MVP/SVP override; season history (final standings, per-season stats).
4. Robustness: registration validation, password reset, handling of the owner-username auto-admin.
5. Demo readiness: seeded demo data, branding, TestFlight.
6. Later (deferred): backend/sync (D5), funding strategy (D6).
