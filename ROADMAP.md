# TOTL Project Plan

Unified plan for the business, the app, and the fundraising. These tracks move together: the app is the competitive league's engine *and* the fundraising demo, and the business plan supplies the rules the app enforces. Last updated 2026-10-21 (iteration 12). History lives in `ITERATIONS.md`.

**End state:** a funded, opened TOTL gym running its Competitive league on this app.
**Near-term goal (MVP):** a proof-of-concept ranked league on rented courts in San Antonio, with the app as the main selling point, plus a website and social media. See the MVP section below. It builds the proof of demand that fundraising needs.

---

## Decisions

| # | Decision | Status |
|---|---|---|
| D1 | Which stats earn RP | **Decided:** all 5 (points, rebounds, assists, blocks, steals). |
| D2 | RP per level | **Decided:** 50 for now. |
| D3 | Season structure | **Decided:** 3-month seasons, soft reset, placement games. Implemented with these defaults: drop 3 tiers at reset, 5 placement games at 2× RP, staff start each new season. |
| D4 | RP formula | **Decided:** winners all gain; only the losing team's best player (SVP) can gain, and only a little; MVP for winners, SVP for losers; if everyone plays badly and loses, everyone loses RP including the SVP. Implemented and rebalanced 2026-10-21 (see D8): win +10, loss −15, SVP −7 (great game up to +5), MVP +5, underdog win +5 per metal (max +10), stats ±2 per unit at half weight. All tunable in `CompetitiveRules.swift`. |
| D5 | Backend / sync | **Now needed for the MVP** (players use the app on their own phones; website shows the same schedule and leaderboard). Recommended: Supabase. Gailan to choose. |
| D6 | Funding mix | **Deferred.** Focus is the app for now. |
| D7 | Launch format | **Decided:** start small, likely a rented 2-court gym, not a 6-court build. |
| D8 | Tune the starting numbers in D3/D4 | **Rebalanced 2026-10-21** against RP inflation (larger loss penalty, smaller for the SVP, symmetric stat scoring; drift +5.6 → +0.3 RP per player-game in simulation). Final tuning with pilot-league data. |
| D9 | Included coaching format (1-on-1, group clinics, or paid add-on) | Open, not needed for the MVP. At 1-on-1, Competitive members barely cover their own coaching (see cost model, Facility Monthly §1). |
| D10 | Launch path | **Decided 2026-10-21:** start with a proof of concept on rented courts. Coaching, merch and the 6-court facility are the end goal, not the MVP. Gailan keeps the TrueLoyal job meanwhile. |
| D11 | MVP success gates | Open. Suggested: 2 seasons in a row with 60+ paid players, 60%+ returning, 500+ audience. |

---

## MVP: Proof-of-concept league on rented courts (current focus, set 2026-10-21)

**Goal:** run a real ranked TOTL league on rented courts in San Antonio, with the app as the main selling point, and use it to build an audience and the proof that fundraising needs.

**In scope:** the app, rented courts, a website, social media, the minimum legal and operations setup, and fundraising prep (audience, footage, testimonials).
**Out of scope until after the POC:** coaching sessions, merch beyond the jersey, food and drink, memberships, and our own facility (the 6-court gym stays the end goal).

**Success gates.** Decide these numbers before season 1 so the pilot answers a clear question. Suggested: 2 seasons in a row with 60+ paid players, 60%+ of players returning, 500+ on the email/social audience.

### M1. App (the main selling point)
The app works today, but only on one device with local data. To run a real league, every player needs it on their own phone. So the backend (D5) is no longer deferred.
- [ ] **Backend + accounts (D5).** Move players, seasons, matches and games to a hosted database with real sign-in, so each player sees their own rank, stats and history. Recommended: Supabase (Postgres, Swift and JavaScript SDKs, free tier), since the website reads the same data. Firebase is the alternative. Keep `RankSystem`/`MatchScoring` as the single scoring source.
- [ ] **Game Nights.** New `Venue` (name, address, map link, notes like parking or entrance) and `GameNight` (date, start and end time, venue, courts, capacity, status: scheduled, full, cancelled). Players see upcoming nights with where and when, open the address in Maps, and add the night to their calendar. Matches belong to a game night.
- [ ] **RSVP / check-in.** Players RSVP for a night (with a capacity cap and a waitlist). Staff check players in and build balanced teams from the RSVP list by tier.
- [ ] **Notifications.** Reminder the day before and when a night changes or is cancelled. Results and rank-ups after stats are confirmed.
- [ ] **Waiver at sign-up.** Players accept the liability waiver in the app before they can RSVP (store version and timestamp).
- [ ] **Robustness.** Password reset, registration validation, decide on the owner auto-admin path, staff MVP/SVP override, season history.
- [ ] **Distribution.** TestFlight for the pilot (external testers need a beta review), then the App Store. Apple Developer account under the LLC.
- [ ] **Android players.** The app is iPhone-only, so the website must show the schedule, the leaderboard and each player's rank, so nobody is shut out.
- Payments stay outside the app for the MVP: league fees go through a Square or Stripe payment link on the website. League fees are a real-world service, so Apple's in-app purchase rules don't apply to them.

### M2. Courts
Book a 12-week block at one venue, one night a week. Prefer a venue with 2 courts in the same building.
| Venue | Area | Price | Notes |
|---|---|---|---|
| Ramirez Community Center (City of SA), 1011 Gillette Blvd | South (78224) | $30/hr, 2-hr min | Cheapest found. Basketball/volleyball rentals only. |
| Garza Community Center (City of SA), 1450 Mira Vista | West (78228) | $50–90/hr, 2-hr min, $100 deposit | Large and small gym. Higher rate "with admission". |
| Hamilton Community Center (City of SA), 10700 Nacogdoches Rd | Northeast (78217) | $50–90/hr, 2-hr min, $100 deposit | Large gym. |
| Woodlawn Lake Park Gym (City of SA) | Near downtown / west | $50–90/hr, 2-hr min, $100 deposit | |
| Alamo City All-Stars Sportsplex, 11471 E Loop 1604 N, Universal City | Northeast (78148) | Full court $90–100/hr peak; leagues $100/court | Several courts in one building. Leagues need 8+ hours per court. Best fit for 2 courts at once. |
| Factory of Champions, 8227 Broadway | Alamo Heights (78209) | Call (210-832-9300) | Private multi-sport facility with court rentals. |
| Order On The Court, 4343 Industrial Center | Northeast (78217) | $36/hr | Only one court (Court 5) can be set up for basketball. |
- City gyms: book online through SA Parks (210-207-7275). Before booking, ask whether a paid adult league is allowed, which rate applies (charging a league fee probably counts as "with admission"), whether recurring weekly bookings are possible, and what insurance they require.
- School districts are out: Northside ISD rents athletic facilities only to youth non-profits and bans for-profit use.
- The cost model assumes $75/court-hour. City gyms at $30–90 make the pilot cheaper.

### M3. Website
- [ ] Domain (once the name is cleared) and a simple site: what TOTL is, how the ranked ladder works, upcoming game nights with where and when, the leaderboard, sign-up (waiver + payment link), and an email waitlist.
- [ ] Schedule and leaderboard read live from the same backend as the app, so they are entered once.
- [ ] Hosting on a free static host (GitHub Pages, Netlify or Vercel).

### M4. Social media
- [ ] Claim the same handle on Instagram, TikTok, and YouTube (Facebook optional). The link in bio goes to the website schedule.
- [ ] Weekly rhythm: a game-night post (where, when, spots left), game clips and highlights, rank-ups and MVPs after stats are confirmed, and a weekly leaderboard.
- [ ] A group chat or Discord for registered players, for last-minute changes.
- [ ] Later: the app generates the game-night and leaderboard graphics, so posting takes a minute.

### M5. Legal and operations (minimum for local scale)
- [ ] Check the TrueLoyal employment agreement (outside business, IP).
- [ ] Clear the name, form the Texas LLC, get an EIN, open a business bank account, and assign the app IP to the LLC.
- [ ] Attorney-written liability waiver; league liability insurance (venues will want a certificate naming them as additional insured).
- [ ] Texas sales tax permit if jerseys are sold separately.
- [ ] Rulebook: game format, team balancing by tier, ref/stat process, disputes, 2-day stat confirmation.
- [ ] Game-night crew: 1 ref per game, 1 statistician per court (or Gailan in season 1). Train statisticians on the app.
- [ ] Kit: game balls, reversible jerseys with rank tags, first aid kit, camera and tripod.
- [ ] Game-night run sheet: setup, check-in, teams, games, stat entry, cleanup.

### M6. Fundraising and marketing prep
- [ ] Build the audience from day one: email waitlist, social following, player testimonials.
- [ ] Film every game. Footage serves stat checks, highlights and the campaign video.
- [ ] After season 1, decide the campaign (D6) using real numbers: players, return rate, audience size.

### Rough cost to start
About $4k one-time setup plus $5–12k per season, depending on the venue. See `Project Comp-B/TOTL Startup Cost Model.xlsx`, Pilot League tab. App running costs are small: $99/yr for Apple, $0–25/mo for the backend, about $20/yr for the domain.

### Order of work
1. Decisions and legal (weeks 1–3): TrueLoyal check, name, LLC, backend choice, success gates.
2. App backend + Game Nights + RSVP (weeks 2–10), with the website built alongside it from the same data.
3. Social accounts live and posting from about 8 weeks before season 1: build-up content, app previews, the waitlist.
4. Venue booked and insurance bound about 6 weeks before. Sign-ups open about 4 weeks before.
5. Season 1: 12 weeks, film everything, track the success gates.

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
| 2026-10-21 | Underdog win: +5 per metal of gap per winner, capped at +10, when every winner is a full metal below every loser. Favorites lose the normal amount. |
| 2026-10-21 | D10: MVP is a proof-of-concept league on rented courts; the app is the main selling point. Backend (D5) moves into the MVP. Cost model v1 built. |
| 2026-10-21 | D8 rebalanced against RP inflation: win +10, loss -15, SVP -7, MVP +5, stats ±2 both ways at half weight. |
| 2026-10-18 | D1: all 5 stats. D2: 50 RP per level. D3: 3-month seasons, soft reset, placement. D4: win/loss scoring with MVP/SVP. D5/D6 deferred. D7: start with a rented 2-court gym. Focus on the app for now. |
| 2026-10-18 | Project scope is the business plan, prototype app, and fundraising plan, developed in parallel. Business planning is no longer deferred. |
| 2026-08 | Only Competitive members are ranked. Ladder expanded to 14 tiers (Diamond, Elite) per the business plan. |
| 2026-08 | Employee access is by staff approval, not a shared secret key. |
