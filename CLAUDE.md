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
- **Commit and push as you go** (Gailan decided 2026-10-21 for the MVP build): each push runs CI and is how the Mac gets updates. Keep `main` green.
- Keep replies concise and direct.
- Prioritize correctness and robustness over new features, unless a feature is needed for the demo or the fundraising plan.
- Keep business rules in one place in code: `CompetitiveRules.swift` (tunable numbers), `RankSystem.swift`/`MatchScoring.swift` (scoring), `AppConstants.swift` (roles, memberships), `GameStatBounds.swift` (stat sanity limits). Never duplicate them in views.
- **`DebugTools/` is testing-only** (Debug builds, `#if DEBUG`): demo launch arguments and the "Load Sample League" button. Never build real features on it, and never create real accounts outside sign-up. Real members choose their own password. Removal steps: `DebugTools/README.md`.
- Sources of truth if they disagree: Gailan's latest stated decision > `ROADMAP.md` decisions log > business plan docx > code.

## Repo / build state

- GitHub: `GailanH/TOTL-BasketBall-League`, branch `main`. Pushing works from Claude sessions with GitHub connected. The Mac's own shell has no GitHub credentials.
- `project.yml` (XcodeGen) generates `Project_Comp_B.xcodeproj` (gitignored). Run `xcodegen generate` after adding or removing files.
- UI tests (`UITests/`) walk the real screens using DebugTools launch arguments. CI publishes their screenshots to the `ui-screenshots` branch and the generated Xcode project to `generated-xcodeproj` (fetch with git; artifact downloads are blocked from Claude sessions).
- CI (`.github/workflows/ios.yml`) runs `xcodebuild test` on GitHub macOS runners with the default Xcode and an available iPhone simulator. On failure, compiler errors and failed tests appear as a job annotation (readable via `gh api .../check-runs/<job>/annotations`, since raw logs may be blocked).
- `.claude/` and `build/` are gitignored.

## Data model (`Project_Comp_B.xcdatamodeld`, versioned, current = v5)

- **Player**: username, email, password (hash), passwordSalt, role, membership, rankPoints, lastRank, placementGamesRemaining, profileImage. Relationships: games, coachingSessions, rankChanges, rsvps, seasonResults.
- **Match**: one played game. id, date, winningTeam ("A"/"B"). Relationships: season, games (one per player, cascade).
- **Game**: one player's line in a Match. points, rebounds, assists, blocks, steals, team, won, award ("MVP"/"SVP"), isPlacement, rpDelta, date. Relationships: player, match. Older games have no match.
- **Season**: number, name, startDate, endDate, isActive. Relationships: matches, rankChanges, gameNights, results.
- **SeasonResult** (v5): finalRankPoints, finalRank, position (0 = unplaced), rankedPlayerCount, wasInPlacement, recordedAt. Saved for every ranked player by `SeasonHistory.snapshot` when staff start a new season, before the soft reset. Per-season stats are computed from games (`SeasonStats`, `SeasonHistory`), not stored.
- **RankChange**: id, newRank, date, reason ("game"/"seasonReset"). Relationships: player, season.
- **CoachingSession**: title, coachName, date, isBooked. Relationship: player.
- **Venue** (v3): id, name, address, latitude/longitude (optional), mapURL, courtCount, notes, isActive. Relationship: gameNights.
- **GameNight** (v3): id, startDate, endDate (absolute/UTC), courtsInUse, capacity, status (scheduled/full/cancelled/completed), notes, updatedAt. Relationships: venue, season, createdBy (Player), matches, rsvps. `Match.gameNight` is optional (set when a game is recorded from a night's roster). Staff close a night (status completed) once it starts; unchecked RSVPs become no-shows.
- **RSVP** (v4): id, status (confirmed/waitlisted/cancelled/noShow), createdAt (sets waitlist order), checkedInAt, isWalkIn, updatedAt. Relationships: gameNight, player. Rules live in `RSVPPolicy` and `TeamBalancer` (`RSVPModels.swift`); RSVP settings in `LeagueSettings`.
- Venues and game nights are accessed only through `GameNightStore` (protocol) with plain records (`GameNightModels.swift`); `CoreDataGameNightStore` is today's implementation. League ops settings (time zone America/Chicago, defaults) live in `LeagueSettings.swift`.
- Roles: `player`, `employee_pending`, `employee`, `administrator`. Memberships: `Casual`, `Competitive`, `Deactivated`. Only Competitive members are ranked.
- **Schema changes:** add a new model version (never edit the current one in place) so existing data migrates.

## Competitive system (decided 2026-10-18, see ROADMAP D1–D4)

- 14 tiers, 50 RP each: Rookie (0–100) through Elite (701+, uncapped). Tier averages rise with rank.
- All 5 stats count. Each stat vs. the player's tier average: ±2 per unit, capped ±15 per stat; the game's stat score is clamped to +50/−20 and counts at half weight.
- Result-led scoring (rebalanced 2026-10-21 against RP inflation): win +10 (never below +3), MVP +5 more, loss −15 (never a gain), SVP −7 (a great game can still earn up to +5). Underdog win (every winner a full metal below every loser): +5 per metal of gap per winner, capped at +10; favorites lose the normal amount. Typical: win +10, MVP +20, loss −17, SVP −4.
- 3-month seasons. Staff start each new season: everyone drops 3 tiers to the bottom of that tier, then plays 5 placement games at 2× RP. Players in placement are hidden from the leaderboard.
- Numbers live in `CompetitiveRules.swift`. Logic lives in `RankSystem.swift` and `MatchScoring.swift` (pure, unit-tested). All RP changes go through `MatchRecorder.swift`, and seasons through `SeasonManager.swift`.

## Next steps

Current focus is the **MVP** (decided 2026-10-21): a proof-of-concept ranked league on rented courts in San Antonio, with the app as the main selling point, plus a website and social media. Coaching, merch and the 6-court facility are the end goal, not the MVP. Full plan: the MVP section of `ROADMAP.md`. **App work follows `APP_MVP_BRIEF.md`.**
1. Backend + real accounts (D5): Gailan is exploring Supabase; don't integrate a backend until he decides. Build new features behind a store protocol.
2. Game Nights: venues, dates and times, RSVP with capacity, check-in, reminders. Waiver acceptance at sign-up.
3. Robustness: password reset, registration validation, owner auto-admin decision, staff MVP/SVP override, season history.
4. Website reading the same backend: schedule, leaderboard, sign-up, waitlist.
5. TestFlight for pilot players.
