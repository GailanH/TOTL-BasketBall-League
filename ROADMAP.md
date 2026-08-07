# Roadmap

## Where this is going

The end goal isn't just a finished app — it's the tech foundation for a physical basketball gym business with two sides:

- **Casual side**: members show up, shoot around, train, and play at their own pace. No ranking pressure.
- **Competitive side**: this app tracks points earned per game (points, rebounds, assists, steals, blocks) against per-rank averages, moves players through 10 ranked tiers (Rookie through Gold I), and gives the gym a ladder/season structure to build a league around.

The data model already anticipates this — `Player.membership` is `"Casual"`, `"Competitive"`, or `"Deactivated"`, set by employees via Edit Player Accounts. The immediate priority is finishing the app to a genuinely production-ready state. The business plan (pricing, membership structure, physical space, staffing, etc.) comes after that.

## Status: pre-production

This is a working prototype — SwiftUI + local Core Data, single device, no backend. Below is what's between here and something you could actually run a gym on.

## Done

- [x] Core Data model: Player, Game, CoachingSession, RankChange
- [x] Login / registration flow, employee vs. player roles, employee secret-key gate
- [x] Rank tier system (Rookie → Gold I) with per-tier stat averages and RP gain/loss on game submission
- [x] Rank change history + timeline chart view
- [x] Leaderboard, player overview (last 5 games), dashboard navigation
- [x] Coaching session creation (employee) and booking (player), one session per player
- [x] Employee tools: add games, edit player accounts (membership + role), edit player detail
- [x] Profile editing with photo picker
- [x] Passwords are now salted + hashed (SHA-256 via CryptoKit) instead of stored in plaintext — `PasswordHasher.swift`, `Player.passwordSalt` added to the model, login/register updated accordingly
- [x] Rank-tier logic consolidated into `RankSystem.swift` (single source of truth for thresholds, averages, and ordering) — removed 4 duplicated/inconsistent copies from `AddGameView`, `DashboardView`, `LeaderboardView`, `PlayerOverviewView`, and `RankHistoryTimelineView`. Also fixed a real bug in the process: any player above 550 RP previously fell through every bracket and displayed as "Unranked" — Gold I is now uncapped at the top.

## Known issues / tech debt

- **Employee secret key is a hardcoded plaintext string** (`AppConstants.employeeSecretKey = "CompB"`) baked into the shipped app binary — anyone can decompile and find it. Needs to move server-side or be replaced with a real employee invite/approval flow.
- **No password reset / forgot-password flow.** Since passwords are now hashed, there's also no way to recover a forgotten password without an admin path — needs one before real users are on this.
- **Local-only storage.** Everything lives in on-device Core Data with no sync. That means no multi-device login, no way for a front-desk employee's phone/iPad and a player's phone to see the same data, and total data loss risk if the device is lost. This is the biggest blocker to "production" — needs a backend (CloudKit sync, or a real server + API) before this can run a real gym.
- **Debug `print()` statements left in shipped code paths** (e.g. `PlayerOverviewView.onAppear`) — fine for dev, should be stripped or gated behind a debug flag before release.
- **No automated tests.** Nothing currently verifies the RP scoring math, rank thresholds, or login/registration logic.
- **No input validation** on registration (no email format check, no password strength requirement, no username constraints).
- **Placeholder app icon/assets** — `Assets.xcassets` has a default icon, no real branding yet.

## Suggested next milestones

1. ~~Add an Xcode project.~~ Done via `project.yml` (XcodeGen) + `.github/workflows/ios.yml` — see "Building & testing" below. One remaining step: run `xcodegen generate` on your Mac, open in Xcode, set your signing Team, and confirm it builds.
2. **Pick a backend/sync strategy** (CloudKit is the lowest-lift option for an all-Apple app; a custom server API is more work but platform-independent if an Android app or web dashboard is ever wanted).
3. **Harden auth**: password reset flow, replace the hardcoded employee secret key with a real approval flow, basic input validation.
4. **Strip debug output, add basic unit tests** around the RP/rank math since that's the core of the product.
5. **Real app icon + basic branding pass** once the business name/identity is settled.
6. **Payments/membership billing** — not started; needed before this can actually charge members for Casual vs. Competitive tiers.

## Building & testing

This is a native iOS app (SwiftUI + Core Data), so it can only actually be **run** — tapped through, logged into, visually checked — in Xcode's iOS Simulator or on a physical device. There's no way around that; nothing web-based substitutes for it.

What GitHub *can* do: `.github/workflows/ios.yml` runs on GitHub's macOS runners on every push/PR. It installs XcodeGen, regenerates the Xcode project from `project.yml`, and runs `xcodebuild build` headlessly to catch anything that fails to compile — before you even open Xcode. Once a unit test target exists, this same workflow can run `xcodebuild test` to automatically check the RP/rank math (`RankSystem`) and password hashing (`PasswordHasher`) on every commit. That's real, automated regression testing — it just can't click through login screens for you; that's what XCUITest (also runnable in this same CI) or manual testing in the Simulator is for.

Local setup (one-time, on your Mac):
1. `brew install xcodegen`
2. `xcodegen generate` in this repo folder — produces `Project_Comp_B.xcodeproj` (gitignored, regenerate anytime the file list changes)
3. Open the generated project in Xcode, set your Team under Signing & Capabilities, run on Simulator

## Out of scope for now

Business planning (pricing, lease/location, staffing, marketing) is intentionally deferred until the app is functionally complete — tracked here only as a reminder that it's the next phase, not a current task.
