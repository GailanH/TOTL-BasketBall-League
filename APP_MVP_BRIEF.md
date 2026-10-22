# TOTL App: MVP Brief

For the Claude session building the iOS app. Read `CLAUDE.md` first for the working rules and code layout. This brief covers **what the app needs for the MVP** and in what order. Written 2026-10-21.

## Context

TOTL is starting with a **proof-of-concept league on rented courts** in San Antonio: one or two nights a week, at a city rec-center gym or a private facility. There's no TOTL building yet. **The app is the main selling point.** It's what makes this a ranked league instead of another pickup run, and it's the demo for fundraising.

Not in the MVP: coaching sessions, merch, memberships/billing, food and drink. Existing coaching screens can stay, but don't build on them.

What changes for the MVP: today the app runs on one device with local Core Data. In the MVP, **every player uses the app on their own phone**: sign up, see when and where the next game night is, RSVP, get notified, and see their rank after games. Staff record games at the venue.

## Open decision: backend (D5)

Gailan is exploring **Supabase** before deciding (Firebase and CloudKit are the alternatives). **Don't pick or integrate a backend yet.**

Until then, build the new features so the backend can be swapped in later:
- Put data access for the new entities behind a small protocol (e.g. `GameNightStore`) with a Core Data implementation for now. Views talk to the protocol, never to Core Data directly.
- Keep IDs as UUIDs and store all dates in UTC. Display them in the venue's time zone (America/Chicago).
- Anything that needs a server is marked **[needs backend]** below. Design it now, build it after D5.
- The website will read the same data (schedule, leaderboard), so keep the models simple and relational.

## 1. Venues and Game Nights

**Venue**: id, name, address, latitude/longitude (optional), map URL, number of courts, notes (parking, entrance, "use the side door"), isActive.

**GameNight**: id, venue, start date/time, end time, courts in use, player capacity, status (`scheduled`, `full`, `cancelled`, `completed`), notes, season (optional), createdBy. A `Match` belongs to a game night (optional, so older matches still work).

**Staff (employee/administrator):**
- Create, edit and cancel venues and game nights. Editing time or venue, or cancelling, triggers the change notification (section 3).
- See the RSVP list and waitlist for a night.

**Players:**
- An "Upcoming" list on the dashboard: next game nights with date, time, venue name and address, spots left, and the player's RSVP status.
- Game night detail: everything above plus venue notes, **Open in Maps**, **Add to Calendar** (EventKit, or an .ics share), and **Share** (a text with when, where, and later a website link) for posting to social media or group chats.

Acceptance: a staff member creates a venue and a game night; a player sees it on the dashboard with the correct local time, opens the address in Maps and adds it to their calendar.

## 2. RSVP, waitlist and check-in

- Players RSVP or cancel their RSVP. When capacity is reached, the night shows `full` and new RSVPs join a waitlist in order.
- If someone cancels, the first person on the waitlist moves up and gets notified (section 3).
- RSVP closes at a set time before start (put the cutoff in `CompetitiveRules.swift` or a new league-settings file, not in views).
- At the venue, staff check players in from the RSVP list (plus walk-ins if there's room). Check-in feeds team building: suggest two balanced teams from the checked-in players by tier/RP. Staff can adjust the teams, then go to the existing Record Game flow.
- Only Competitive players count toward the ranked ladder (existing `AppConstants.isRanked` rule).

Acceptance: with capacity 10, the 11th RSVP is waitlisted; when one player cancels, the waitlisted player becomes confirmed; staff check in 10 players and get two suggested teams.

## 3. Notifications (game locations and times)

Every notification about a game night says **when and where**: day, start time, venue name, and short address. Tapping it opens that game night's detail screen (deep link).

| Notification | When it fires | Who gets it | How |
|---|---|---|---|
| New game night posted | Staff publishes a night | Players who opted in | Push **[needs backend]** |
| RSVP confirmed | Player RSVPs | That player | In-app confirmation; offer Add to Calendar |
| Reminder: tomorrow | 24 hours before start | Confirmed players | Local notification |
| Reminder: today | 2 hours before start (time in league settings) | Confirmed players | Local notification, includes venue notes such as parking |
| Time or venue changed | Staff edits time or venue | Confirmed + waitlisted players | Push **[needs backend]**; reschedule local reminders |
| Game night cancelled | Staff cancels | Confirmed + waitlisted players | Push **[needs backend]**; remove local reminders |
| Spot opened up | Waitlisted player moves up | That player | Push **[needs backend]** |
| RSVP closing soon | A few hours before the RSVP cutoff, if spots are left | Opted-in players who haven't RSVP'd | Push **[needs backend]**, optional |
| Results posted | Stats confirmed for a night | Players who played | Push **[needs backend]**: RP change, MVP/SVP, rank-up |
| Night is full / RSVP count | Night fills | Staff | Push **[needs backend]**, optional |

**Build now (no backend needed):**
- A `NotificationScheduler` (one place for all notification logic, no scheduling code in views) using `UNUserNotificationCenter`.
- Schedule both reminders when a player RSVPs; reschedule when the night's time or venue changes; cancel them when the player cancels or the night is cancelled. Use the game night's ID in the notification identifiers so updates replace old ones.
- Deep link from a notification tap to the game night detail screen.
- Ask for notification permission **after the player's first RSVP** (with a short explanation), not at first launch.
- A Notifications section in profile settings with per-type toggles: new game nights, reminders, changes/cancellations (on by default), results.
- Unit tests for the scheduler: the right triggers at the right times, and reschedule/cancel behavior.

**After the backend (D5):** remote push through APNs (needs the Apple Developer account and an APNs key). The device token is stored per player; the server sends change, cancellation, waitlist and results pushes. Local reminders stay on the device.

## 4. Accounts and waiver

- Sign-up: username, email, password chosen by the player, membership type (Casual/Competitive). Real accounts only come from sign-up (existing rule; never through `DebugTools/`).
- **Waiver:** players must accept the current liability waiver before their first RSVP. Store the waiver version and acceptance time. When the waiver version changes, ask again. (Gailan will provide the final text from an attorney; use placeholder text marked clearly as a placeholder.)
- Password reset and email validation **[needs backend]** for reset by email; build the screens and validation now.
- Decide the owner auto-admin path with Gailan before shipping to testers.

## 5. Robustness and demo readiness

- Staff MVP/SVP override, season history (final standings, per-season stats).
- Empty states everywhere a new player will look first (no game nights yet, no games played yet).
- Keep the CI green and add tests for every new rule (RSVP/waitlist logic, team balancing, notification scheduling).
- Demo data in `DebugTools/` (Debug builds only): a few venues and upcoming game nights with RSVPs, so screenshots and the campaign video show a living league.

## 6. Distribution

- TestFlight for pilot players (external testers need a beta app review). The app should be on testers' phones about 4 weeks before season 1.
- Android players can't use the app. The website will show the schedule, the leaderboard and ranks for them, so nothing in the app should be the only place a player can find when and where games are.

## Build order

1. Venue + GameNight models (new Core Data model version), store protocol, staff create/edit, player Upcoming list and detail with Maps/Calendar/Share.
2. RSVP, waitlist, check-in, balanced-team suggestion into Record Game.
3. Local notifications: scheduler, reminders, permission prompt, settings toggles, deep links.
4. Waiver at sign-up, password reset screens, validation.
5. Demo data, robustness items, TestFlight.
6. After D5: backend integration, remote push, password reset by email.

Log each session in `ITERATIONS.md` and ask Gailan before any commit or push (see `CLAUDE.md`).
