# TOTL Project Plan

Unified plan for the business, the app, and the fundraising. These tracks move together: the app is the competitive league's engine *and* the fundraising demo, and the business plan supplies the rules the app enforces. Last updated 2026-10-18 (iteration 7). History lives in `ITERATIONS.md`.

**End state:** a funded, opened TOTL gym running its Competitive league on this app.
**Near-term goal:** a credible fundraising package: a business plan with real numbers, a working demo app, proof of demand, and a campaign ready to launch.

---

## Decisions

| # | Decision | Status |
|---|---|---|
| D1 | Which stats earn RP | **Decided:** all 5 (points, rebounds, assists, blocks, steals). |
| D2 | RP per level | **Decided:** 50 for now. |
| D3 | Season structure | **Decided:** 3-month seasons, soft reset, placement games. Implemented with these defaults: drop 3 tiers at reset, 5 placement games at 2× RP, staff start each new season. |
| D4 | RP formula | **Decided:** winners all gain; only the losing team's best player (SVP) can gain, and only a little; MVP for winners, SVP for losers; if everyone plays badly and loses, everyone loses RP including the SVP. Implemented: winner minimum +5, MVP +10, SVP max +5, per-stat cap +15/−10, game cap +50/−20, averages rise with tier. All tunable in `CompetitiveRules.swift`. |
| D5 | Backend / sync | **Deferred** until the app and fundraising have traction. |
| D6 | Funding mix | **Deferred.** Focus is the app for now. |
| D7 | Launch format | **Decided:** start small, likely a rented 2-court gym, not a 6-court build. |
| D8 | Tune the starting numbers in D3/D4 | **Rebalanced 2026-10-21** against RP inflation (larger loss penalty, smaller for the SVP, symmetric stat scoring; drift +5.6 → +0.3 RP per player-game in simulation). Final tuning with pilot-league data. |
| D9 | Included coaching format (1-on-1, group clinics, or paid add-on) | Open. At 1-on-1, Competitive members barely cover their own coaching (see cost model, Facility Monthly §1). |
| D10 | Launch path | **Proposed 2026-10-21 (Gailan to confirm):** pilot league on rented courts first; lease own space only after pilot success gates are met. Gailan keeps the TrueLoyal job meanwhile. |

---

## Phase 0: Housekeeping (now)
- [x] **App:** commit and push the Aug–Sep work (`a105fb1`, 2026-10-18). CI green since `9c11591`.
- [x] **Both:** refresh CLAUDE.md and ROADMAP.md, start ITERATIONS.md (2026-10-18).
- [ ] **Business:** confirm the business plan docx is the current version, then keep it in sync with decisions made here.

## Phase 1: Lock the competitive rules and finish the core app
**App**
- [x] Implement D1–D4: win/loss scoring, MVP/SVP, per-stat and per-game caps, monotonic tier averages (`CompetitiveRules`, `RankSystem`, `MatchScoring`).
- [x] Seasons: `Season` entity, staff Seasons screen, soft reset, placement games, season-scoped leaderboard (`SeasonManager`).
- [x] Games recorded as two teams with a winner (`Match` entity, Record Game screen, team-based CSV import). Edits and deletes re-score the whole game (`MatchRecorder`).
- [x] Tests for the rules, recorder, and seasons. Remove the `Item` entity. Gate `print()`s.
- [x] CI builds the app and passes all unit tests (fixed the CI workflow, `9c11591`).
- [ ] Click through on the Simulator: record a game, start a season, and check that existing data migrated.
- [ ] Decide whether to keep the owner-username auto-admin path (anyone registering "GailanH" on a fresh install becomes admin).
- [ ] Staff override for MVP/SVP, if referees should pick them rather than the stats.
- [ ] Season history views: past-season final standings, per-season stats for each player.

**Business**
- [ ] Write the competitive rulebook: game format, team balancing by tier, referee/statistician process, disputes, stat-confirmation window (2 days per the plan).
- [ ] Settle membership details: coaching overage pricing and the Meal Ticket add-on (yes/no).

## Phase 2: Numbers and market
**Business**
- [x] Startup cost model v1 (2026-10-21): `Project Comp-B/TOTL Startup Cost Model.xlsx`. Pilot league + own 2-court facility, break-even, 36-month projection, launch checklist. F&B kitchen and the 6-court facility left out for now.
- [ ] Replace the yellow estimates with real quotes (court rental, insurance, lease NNN, contractor).
- [ ] Close the facility gap: decide D9, test youth-club rentals, pricing, smaller/shared space.
- [ ] Revenue model: memberships (Casual $35/$400, Competitive $45/$500), coaching, F&B, merchandise/jerseys, events/rentals, spectators. Include break-even member count and a 3-year projection.
- [ ] San Antonio market research: comparable gyms and leagues, pricing, lease rates for warehouse/flex space, demand signals.
- [ ] Legal/admin: business entity (e.g. LLC), name/trademark check for "TOTL", bank account, insurance, liability waivers.
- [ ] Brand: what TOTL stands for, logo, colors, and jersey tier tags.

**App**
- [ ] Decide and implement the backend (D5). Needed before any real members use the app.
- [ ] Harden auth: password reset, email/password validation, staff invites.

## Phase 3: Demo-ready prototype and proof of demand
**App**
- [ ] Demo mode with seeded realistic data (a season in progress, leaderboard, rank-ups).
- [ ] Branding pass (icon, colors, name) and a TestFlight build that testers can install.
- [ ] Screen recordings for the campaign video.

**Business**
- [ ] **Pop-up ranked league pilot.** Rent court time for a few weeks, run ranked games with a statistician entering stats into the app, and charge a small entry fee. This proves demand, tests the RP rules with real players, and produces campaign footage and testimonials.
- [ ] Waitlist / landing page with email capture.

## Phase 4: Fundraising
Options (can be combined):
- **Rewards crowdfunding (Kickstarter/Indiegogo).** Pre-sell founding memberships, jerseys, launch-event access, and named courts or lockers. On Kickstarter it's all-or-nothing, the platform fee is about 5%, and payment processing is about 3–5% more. This works best for proving demand and funding a pilot. It's unlikely to fund a full facility build on its own.
- **Equity crowdfunding (Reg CF via Wefunder, StartEngine, etc.).** Up to $5M per 12 months from the public. It requires SEC filings (Form C) and financial statements, and investors get equity or SAFEs.
- **Debt:** SBA loans for build-out and equipment, usually needing a business plan, financials, and some owner equity.
- **Partners/sponsors:** local businesses, F&B operator (e.g. a smoothie brand), sporting-goods sponsors.

Campaign package to build: funding goal (from the cost model), reward tiers, campaign video (pilot footage plus app demo), pitch deck, FAQ, launch timeline, and a pre-launch audience (waitlist, pilot players, social media).

## Phase 5: Launch
- [ ] Production app: backend live, payments/membership billing, check-in, staff tools, App Store release.
- [ ] Site secured, build-out, hiring and training (referees, statisticians, front desk), opening season.

---

## App: current state and known issues

**Built:** seasons with soft reset and placement; team games with win/loss, MVP/SVP. Login/registration with hashed passwords. Roles: player, employee_pending, employee, administrator, with staff approval. Casual/Competitive/Deactivated memberships, and only Competitive members are ranked. 14-tier ladder with RP from stats vs. tier averages. Manual and CSV game entry, plus game editing. Rank history timeline, leaderboard, player overview, coaching sessions (staff create, players book), profile editing, and unit tests with CI.

**Known issues:**
- Local-only Core Data: no sync or multi-device support, and data is lost if the device is lost (D5, deferred).
- Editing or deleting an older game re-scores it against current ranks; later games aren't replayed.
- Games from finished seasons are locked (can't be edited).
- No self-service password reset and no input validation on registration.
- No payments or check-in.

## Building and testing
1. `brew install xcodegen` (one-time)
2. `xcodegen generate` in the repo root (after any file add/remove)
3. Open `Project_Comp_B.xcodeproj`, set the signing Team, and run on Simulator. Run tests with ⌘U.

CI runs `xcodebuild test` on every push/PR.

---

## Decisions log
| Date | Decision |
|---|---|
| 2026-10-21 | Underdog win: +5 per winner when every winner is a full metal below every loser. |
| 2026-10-21 | Cost model v1 built. D10 (staged launch) proposed. |
| 2026-10-21 | D8 rebalanced against RP inflation: win +10, loss -15, SVP -7, MVP +5, stats ±2 both ways at half weight. |
| 2026-10-18 | D1: all 5 stats. D2: 50 RP per level. D3: 3-month seasons, soft reset, placement. D4: win/loss scoring with MVP/SVP. D5/D6 deferred. D7: start with a rented 2-court gym. Focus on the app for now. |
| 2026-10-18 | Project scope is the business plan, prototype app, and fundraising plan, developed in parallel. Business planning is no longer deferred. |
| 2026-08 | Only Competitive members are ranked. Ladder expanded to 14 tiers (Diamond, Elite) per the business plan. |
| 2026-08 | Employee access is by staff approval, not a shared secret key. |
