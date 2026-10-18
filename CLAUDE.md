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
- **Ask before any git commit or push.**
- Keep replies concise and direct.
- Prioritize correctness and robustness over new features, unless a feature is needed for the demo or the fundraising plan.
- Keep business rules in one place in code: `RankSystem.swift` (tiers, averages, RP math), `AppConstants.swift` (roles, memberships), `GameStatBounds.swift` (stat sanity limits). Never duplicate them in views.
- Sources of truth if they disagree: Gailan's latest stated decision > `ROADMAP.md` decisions log > business plan docx > code.

## Repo / build state

- GitHub: `GailanH/TOTL-BasketBall-League`, branch `main`. Commits `cd49512` and `1e70268` are pushed.
- **About a month of work (Aug 11 – Sep 13) is uncommitted locally.** That includes the 14-tier ladder, staff approval roles, CSV import, game editing, the test target, and new files (`EditGameView`, `GameStatBounds`, `SessionStore`, `PasswordField`, `CardStyle`, `Tests/`, `Info.plist`). Committing it is step 1 in the roadmap (with Gailan's OK).
- `project.yml` (XcodeGen) generates `Project_Comp_B.xcodeproj`. Run `xcodegen generate` after adding or removing files. The generated project currently exists locally.
- CI (`.github/workflows/ios.yml`) runs `xcodebuild test` on GitHub macOS runners.
- `.claude/settings.local.json` is local tool permissions and shouldn't be committed.

## Data model (`Project_Comp_B.xcdatamodeld`)

- **Player**: username, email, password (hash), passwordSalt, role, membership, rankPoints, lastRank, profileImage. Relationships: games, coachingSessions, rankChanges.
- **Game**: points, rebounds, assists, blocks, steals, rpDelta, date. Relationship: player.
- **CoachingSession**: title, coachName, date, isBooked. Relationship: player.
- **RankChange**: id, newRank, date. Relationship: player.
- **Item**: leftover Xcode template entity. Remove it.
- Roles: `player`, `employee_pending`, `employee`, `administrator`. Memberships: `Casual`, `Competitive`, `Deactivated`. Only Competitive members are ranked.
- **No Season entity yet.** Rank is all-time, but the competitive concept is per-season.

## Competitive system as built (`RankSystem.swift`)

14 tiers, each 50 RP wide: Rookie (0–100), Bronze III–I, Silver III–I, Gold III–I, Diamond III–I, Elite (701+, uncapped). A game's 5 stats are compared to the player's current-tier averages. Above average earns +2 per unit. Below average costs −1 per unit. Per-stat cap is +50/−20, and the per-game total cap is also +50/−20.

Known conflicts with the business intent (see ROADMAP decisions D1–D4):
- Project instructions say RP comes from **points, rebounds, assists**. The business plan and code use **5 stats**.
- The business plan says **100 RP per level**. The code uses 50.
- The per-stat cap equals the total cap, so a single stat can max out a game.
- Tier averages aren't monotonic. Silver III is easier than Bronze I, and Gold II/Gold I are easier than Gold III on some stats.

## Next steps

Full plan is in `ROADMAP.md`. Short version, in order:
1. Commit the uncommitted Aug–Sep work and get CI green.
2. Gailan decides D1–D4 (scoring stats, RP per level, season structure, caps).
3. App: add Seasons, fix the RP formula and averages to match the decisions, expand tests, and clean up (remove `Item`, gate `print`s).
4. Business: build the startup-cost and revenue model, and research the San Antonio market (comparable gyms, lease rates).
5. Decide the backend (CloudKit vs. hosted, e.g. Supabase/Firebase) before real members use the app.
6. Prepare a demo build: seeded data, branding, TestFlight.
7. Plan a pop-up ranked league pilot to prove demand and gather campaign footage.
8. Pick the funding strategy and build the campaign: platform, goal, rewards, video, pitch deck.
