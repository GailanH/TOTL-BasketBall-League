# TOTL Project Plan

Unified plan for the business, the app, and the fundraising. These tracks move together: the app is the competitive league's engine *and* the fundraising demo, and the business plan supplies the rules the app enforces. Last updated 2026-10-18. History lives in `ITERATIONS.md`.

**End state:** a funded, opened TOTL gym running its Competitive league on this app.
**Near-term goal:** a credible fundraising package: a business plan with real numbers, a working demo app, proof of demand, and a campaign ready to launch.

---

## Open decisions (need Gailan)

| # | Decision | Options / notes | Blocks |
|---|---|---|---|
| D1 | Which stats earn RP? | (a) Points, rebounds, assists, per the project brief. (b) All 5 including blocks and steals, per the business plan and current code. Statisticians would still log all 5 either way. | RP formula, tests |
| D2 | RP needed per level | 50 (code) vs. 100 (business plan). This sets how many games it takes to climb. | RankSystem tiers |
| D3 | Season structure | Season length (e.g. 8–12 weeks), and whether RP fully resets or soft-resets (e.g. drop a few tiers). Also whether to run placement games for new players. | Season model |
| D4 | RP formula and caps | Per-stat cap vs. per-game cap (currently both 50, so one stat can max a game). Stat weighting. Whether a win/loss bonus applies. Averages must increase with tier. | RankSystem, tests |
| D5 | Backend / sync | CloudKit (Apple-only, cheapest) vs. a hosted backend like Supabase/Firebase (supports a web/Android/front-desk dashboard). | Multi-device, real users |
| D6 | Funding mix | See the Funding track below. | Campaign planning |
| D7 | Launch format | Go straight to a 6-court facility, or start with a smaller pilot (rented courts, pop-up league) and fund the full build later. | Cost model, funding goal |

Record each answer in the Decisions log at the bottom.

---

## Phase 0: Housekeeping (now)
- [ ] **App:** commit the uncommitted Aug–Sep work (staff roles, 14 tiers, CSV import, game edit, tests) and push. Confirm CI passes.
- [x] **Both:** refresh CLAUDE.md and ROADMAP.md, start ITERATIONS.md (2026-10-18).
- [ ] **Business:** confirm the business plan docx is the current version, then keep it in sync with decisions made here.

## Phase 1: Lock the competitive rules and finish the core app
**App**
- [ ] Implement D1–D4 in `RankSystem.swift`: scoring stats, RP per level, differentiated caps, monotonic tier averages.
- [ ] Add a `Season` entity (name, start/end, active flag). Games and RankChanges belong to a season. Reset RP per D3. Add leaderboard and history filters by season.
- [ ] Add unit tests for every rule above (boundaries, caps, season reset, Casual players never ranked).
- [ ] Cleanup: remove the `Item` entity and its preview seed, gate `print()`s behind `#if DEBUG`, and decide whether to keep the owner-username auto-admin path (anyone registering "GailanH" on a fresh install becomes admin).
- [ ] Data correctness: verify that editing or deleting a game re-derives RP and rank history.

**Business**
- [ ] Write the competitive rulebook: game format, team balancing by tier, referee/statistician process, disputes, stat-confirmation window (2 days per the plan).
- [ ] Settle membership details: coaching overage pricing and the Meal Ticket add-on (yes/no).

## Phase 2: Numbers and market
**Business**
- [ ] Startup cost model: lease/build-out, courts and flooring, equipment, F&B kitchen, POS/software, insurance, permits, pre-opening payroll. Do two scenarios, a pilot and the full 6-court facility.
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

**Built:** login/registration with hashed passwords. Roles: player, employee_pending, employee, administrator, with staff approval. Casual/Competitive/Deactivated memberships, and only Competitive members are ranked. 14-tier ladder with RP from stats vs. tier averages. Manual and CSV game entry, plus game editing. Rank history timeline, leaderboard, player overview, coaching sessions (staff create, players book), profile editing, and unit tests with CI.

**Known issues:**
- Local-only Core Data: no sync or multi-device support, and data is lost if the device is lost (D5).
- No seasons (Phase 1).
- RP rules conflict with the brief and the business plan (D1, D2, D4). Tier averages aren't monotonic.
- No password reset and no input validation on registration.
- The leftover `Item` entity and some ungated `print()`s.
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
| 2026-10-18 | Project scope is the business plan, prototype app, and fundraising plan, developed in parallel. Business planning is no longer deferred. |
| 2026-08 | Only Competitive members are ranked. Ladder expanded to 14 tiers (Diamond, Elite) per the business plan. |
| 2026-08 | Employee access is by staff approval, not a shared secret key. |
