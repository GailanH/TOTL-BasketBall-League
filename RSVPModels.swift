import Foundation

// RSVPs, the waitlist, check-in and team suggestions. Plain value types and pure rules, so the
// logic is unit-tested and moves to a backend (D5) unchanged.

enum RSVPStatus: String {
    case confirmed
    case waitlisted
    case cancelled
    /// Confirmed but never checked in; set when staff close the night.
    case noShow
}

struct RSVPRecord: Identifiable, Equatable {
    var id: UUID
    var username: String
    var membership: String?
    var rankPoints: Int64
    var placementGamesRemaining: Int16
    var status: RSVPStatus
    /// When they RSVP'd. Sets the waitlist order (first come, first served).
    var createdAt: Date
    var checkedInAt: Date?
    var isWalkIn: Bool
    /// Earlier nights this player RSVP'd to and didn't show up for (filled in by the store).
    var pastNoShows: Int = 0

    var isCheckedIn: Bool { checkedInAt != nil }
    var rank: String { RankSystem.rankName(for: rankPoints) }
}

/// A night's RSVP list, split the way staff and players see it.
struct Roster: Equatable {
    /// Confirmed players, in RSVP order (walk-ins last).
    var confirmed: [RSVPRecord]
    /// Waitlisted players, first in line first.
    var waitlist: [RSVPRecord]
    /// Players marked no-show when the night was closed.
    var noShows: [RSVPRecord] = []

    var checkedIn: [RSVPRecord] { confirmed.filter(\.isCheckedIn) }

    static let empty = Roster(confirmed: [], waitlist: [])
}

/// The viewer's own RSVP state for one night.
enum MyRSVPState: Equatable {
    case none
    case confirmed(checkedIn: Bool)
    case waitlisted(position: Int)
    case noShow
}

/// A closed night's turnout, for staff and (later) investor-facing numbers.
struct AttendanceSummary: Hashable {
    var attended = 0
    var walkIns = 0
    var noShows = 0
    var stillWaitlisted = 0
    var gamesRecorded = 0
    var capacity: Int16 = 0

    /// Of the players who had a confirmed spot (RSVP'd, not walk-ins), how many showed up.
    var showRate: Double {
        let rsvpd = attended - walkIns + noShows
        return rsvpd == 0 ? 0 : Double(attended - walkIns) / Double(rsvpd)
    }

    var text: String {
        var parts = ["\(attended) attended"]
        if walkIns > 0 { parts.append("\(walkIns) walk-in\(walkIns == 1 ? "" : "s")") }
        parts.append("\(noShows) no-show\(noShows == 1 ? "" : "s")")
        parts.append("\(gamesRecorded) game\(gamesRecorded == 1 ? "" : "s")")
        return parts.joined(separator: " · ")
    }
}

enum RSVPPolicy {

    enum Refusal: LocalizedError, Equatable {
        case cancelledNight
        case nightOver
        case closed
        case notCompetitive
        case alreadyIn
        case nightFull
        case nightClosed
        case notStarted

        var errorDescription: String? {
            switch self {
            case .cancelledNight: return "This game night is cancelled."
            case .nightOver: return "This game night has already happened."
            case .closed:
                let hours = Int(LeagueSettings.rsvpCutoff / 3600)
                return "RSVPs closed \(hours) hour\(hours == 1 ? "" : "s") before the start. Check with staff at the venue."
            case .notCompetitive: return "Game nights are ranked play, for Competitive members."
            case .alreadyIn: return "You're already on the list for this night."
            case .nightFull: return "The night is full."
            case .nightClosed: return "This night is closed. Reopen it to make changes."
            case .notStarted: return "A night can be closed once it has started."
            }
        }
    }

    /// When RSVPs close for a night.
    static func rsvpDeadline(for night: GameNightRecord) -> Date {
        night.startDate.addingTimeInterval(-LeagueSettings.rsvpCutoff)
    }

    /// Why a player can't RSVP right now, or nil if they can.
    static func refusalToRSVP(night: GameNightRecord, membership: String?, alreadyActive: Bool, now: Date) -> Refusal? {
        if night.status == .cancelled { return .cancelledNight }
        if night.status == .completed || night.endDate < now { return .nightOver }
        if now >= rsvpDeadline(for: night) { return .closed }
        if LeagueSettings.rsvpRequiresCompetitive && !AppConstants.isRanked(membership) { return .notCompetitive }
        if alreadyActive { return .alreadyIn }
        return nil
    }

    /// A new RSVP is confirmed while there's room, otherwise it joins the waitlist.
    static func statusForNewRSVP(confirmedCount: Int, capacity: Int) -> RSVPStatus {
        confirmedCount < capacity ? .confirmed : .waitlisted
    }

    /// How many waitlisted players move up when spots open (after a cancellation or a
    /// capacity increase). Never negative; never more than are waiting.
    static func promotions(confirmedCount: Int, capacity: Int, waitlistCount: Int) -> Int {
        max(0, min(capacity - confirmedCount, waitlistCount))
    }

    /// The stored night status that follows from the confirmed count. A cancelled night stays
    /// cancelled.
    static func status(for night: GameNightRecord, confirmedCount: Int) -> GameNightStatus {
        if night.status == .cancelled || night.status == .completed { return night.status }
        return confirmedCount >= Int(night.capacity) ? .full : .scheduled
    }

    static func spotsLeft(capacity: Int16, confirmedCount: Int) -> Int {
        max(0, Int(capacity) - confirmedCount)
    }

    /// Whether staff can check players in right now.
    static func checkInIsOpen(night: GameNightRecord, now: Date) -> Bool {
        night.status != .cancelled
            && now >= night.startDate.addingTimeInterval(-LeagueSettings.checkInOpensBefore)
            && now <= night.endDate
    }

    /// Why staff can't close a night yet, or nil if they can.
    static func refusalToClose(night: GameNightRecord, now: Date) -> Refusal? {
        if night.status == .cancelled { return .cancelledNight }
        if night.status == .completed { return .nightClosed }
        if now < night.startDate { return .notStarted }
        return nil
    }

    /// "12 of 24 spots left", "Full · 3 waiting", and so on.
    static func availabilityText(capacity: Int16, confirmedCount: Int, waitlistCount: Int) -> String {
        let left = spotsLeft(capacity: capacity, confirmedCount: confirmedCount)
        if left > 0 { return "\(left) of \(capacity) spots left" }
        return waitlistCount > 0 ? "Full · \(waitlistCount) waiting" : "Full"
    }
}

/// Splits players into two teams with RP totals as close as possible.
enum TeamBalancer {

    struct Player: Equatable {
        let id: String
        let rankPoints: Int64
    }

    struct Split: Equatable {
        let teamA: [Player]
        let teamB: [Player]
        var totalA: Int64 { teamA.reduce(0) { $0 + $1.rankPoints } }
        var totalB: Int64 { teamB.reduce(0) { $0 + $1.rankPoints } }
        var difference: Int64 { abs(totalA - totalB) }
    }

    /// Teams differ in size by at most one. Starts from a greedy deal (strongest player to the
    /// weaker team, while sizes allow), then improves it by swapping pairs until no swap helps.
    /// Deterministic: ties keep input order, so the same players always give the same teams.
    static func suggest(_ players: [Player]) -> Split {
        let sorted = players.enumerated()
            .sorted { $0.element.rankPoints != $1.element.rankPoints ? $0.element.rankPoints > $1.element.rankPoints : $0.offset < $1.offset }
            .map(\.element)
        let sizeA = (sorted.count + 1) / 2
        let sizeB = sorted.count / 2

        var a: [Player] = [], b: [Player] = []
        var totalA: Int64 = 0, totalB: Int64 = 0
        for player in sorted {
            let aHasRoom = a.count < sizeA, bHasRoom = b.count < sizeB
            if aHasRoom && (!bHasRoom || totalA <= totalB) {
                a.append(player); totalA += player.rankPoints
            } else {
                b.append(player); totalB += player.rankPoints
            }
        }

        // Pair swaps: keep the best improving swap until none improves the difference.
        var improved = true
        while improved {
            improved = false
            var best: (Int, Int, Int64)? = nil
            let current = abs(totalA - totalB)
            for i in a.indices {
                for j in b.indices {
                    let newA = totalA - a[i].rankPoints + b[j].rankPoints
                    let newB = totalB - b[j].rankPoints + a[i].rankPoints
                    let diff = abs(newA - newB)
                    if diff < current && diff < (best?.2 ?? current) { best = (i, j, diff) }
                }
            }
            if let (i, j, _) = best {
                totalA += b[j].rankPoints - a[i].rankPoints
                totalB += a[i].rankPoints - b[j].rankPoints
                (a[i], b[j]) = (b[j], a[i])
                improved = true
            }
        }
        return Split(teamA: a, teamB: b)
    }
}
