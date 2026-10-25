import Foundation
import CoreData
import SwiftUI

/// Data access for venues and game nights. Screens talk to this protocol only, so the Core Data
/// implementation below can be replaced by a hosted backend (D5) without changing any views.
protocol GameNightStore {
    func venues(includeInactive: Bool) throws -> [VenueRecord]
    /// Creates or updates (by id).
    func saveVenue(_ venue: VenueRecord) throws

    /// Upcoming nights for players, soonest first: everything that hasn't ended, plus cancelled
    /// nights starting within `LeagueSettings.showCancelledWithin` so nobody shows up to one.
    func upcomingGameNights(now: Date) throws -> [GameNightRecord]
    /// Every night, newest first (staff view).
    func allGameNights() throws -> [GameNightRecord]
    func gameNight(id: UUID) throws -> GameNightRecord?

    /// Creates or updates (by id). Reports what changed that players need to hear about (empty
    /// for a new night) and anyone moved up from the waitlist by a capacity increase, for the
    /// notifications in build step 3.
    @discardableResult
    func saveGameNight(_ night: GameNightRecord, createdBy username: String?) throws -> GameNightSaveResult
    @discardableResult
    func cancelGameNight(id: UUID) throws -> GameNightSaveResult

    // MARK: RSVPs, waitlist, check-in (build step 2)

    /// Confirmed players (RSVP order, walk-ins last) and the waitlist (first in line first).
    func roster(nightID: UUID) throws -> Roster
    func myRSVP(nightID: UUID, username: String) throws -> MyRSVPState
    /// RSVPs the player: confirmed while there's room, otherwise waitlisted.
    @discardableResult
    func rsvp(nightID: UUID, username: String, now: Date) throws -> RSVPStatus
    /// Cancels the player's RSVP and moves the next waitlisted player up if a spot opened.
    /// Returns the usernames moved up.
    @discardableResult
    func cancelRSVP(nightID: UUID, username: String, now: Date) throws -> [String]
    /// Staff check-in (or undo) for a confirmed player.
    func setCheckedIn(_ checkedIn: Bool, nightID: UUID, username: String, now: Date) throws
    /// Staff add a Competitive member who didn't RSVP, if there's room. Checked in right away.
    func addWalkIn(nightID: UUID, username: String, now: Date) throws
    /// Members staff could add as walk-ins: eligible, not already on the confirmed list.
    func walkInCandidates(nightID: UUID) throws -> [MemberSummary]
    /// Closes a night that has started: confirmed players who never checked in become no-shows
    /// and the night is marked completed. Returns the turnout.
    @discardableResult func closeGameNight(id: UUID, now: Date) throws -> AttendanceSummary
    /// Undoes closing (no-shows go back to confirmed), so staff can fix check-ins.
    func reopenGameNight(id: UUID) throws
    /// How many recorded games each player has played at this night, by username (for rotation).
    func gamesPlayed(nightID: UUID) throws -> [String: Int]
}

struct GameNightSaveResult: Equatable {
    var changes: GameNightRecord.MaterialChanges = []
    /// Waitlisted players confirmed because the capacity went up.
    var promoted: [String] = []
}

/// A member, as shown in pickers.
struct MemberSummary: Identifiable, Equatable {
    var username: String
    var rankPoints: Int64
    var id: String { username }
    var rank: String { RankSystem.rankName(for: rankPoints) }
}

enum GameNightStoreError: LocalizedError {
    case invalid(String)
    case notFound
    case unknownPlayer(String)
    case notOnList(String)
    case refused(RSVPPolicy.Refusal)

    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        case .notFound: return "That game night no longer exists."
        case .unknownPlayer(let name): return "No member named \(name)."
        case .notOnList(let name): return "\(name) isn't confirmed for this night."
        case .refused(let refusal): return refusal.localizedDescription
        }
    }
}

// MARK: - Core Data implementation

final class CoreDataGameNightStore: GameNightStore {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: Venues

    func venues(includeInactive: Bool) throws -> [VenueRecord] {
        let request: NSFetchRequest<Venue> = Venue.fetchRequest()
        if !includeInactive { request.predicate = NSPredicate(format: "isActive == YES") }
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return try context.fetch(request).map(Self.record)
    }

    func saveVenue(_ record: VenueRecord) throws {
        if let problem = record.validationError { throw GameNightStoreError.invalid(problem) }
        let venue = try fetchVenue(id: record.id) ?? Venue(context: context)
        venue.id = record.id
        venue.name = record.name.trimmingCharacters(in: .whitespaces)
        venue.address = record.address.trimmingCharacters(in: .whitespaces)
        venue.latitude = record.latitude.map(NSNumber.init(value:))
        venue.longitude = record.longitude.map(NSNumber.init(value:))
        venue.mapURL = (record.mapURL?.isEmpty ?? true) ? nil : record.mapURL
        venue.courtCount = record.courtCount
        venue.notes = record.notes
        venue.isActive = record.isActive
        try save()
    }

    // MARK: Game nights

    func upcomingGameNights(now: Date) throws -> [GameNightRecord] {
        let request: NSFetchRequest<GameNight> = GameNight.fetchRequest()
        let cancelledCutoff = now.addingTimeInterval(LeagueSettings.showCancelledWithin)
        request.predicate = NSPredicate(
            format: "(status != %@ AND endDate >= %@) OR (status == %@ AND startDate >= %@ AND startDate <= %@)",
            GameNightStatus.cancelled.rawValue, now as NSDate,
            GameNightStatus.cancelled.rawValue, now as NSDate, cancelledCutoff as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
        return try context.fetch(request).compactMap(Self.record)
    }

    func allGameNights() throws -> [GameNightRecord] {
        let request: NSFetchRequest<GameNight> = GameNight.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        return try context.fetch(request).compactMap(Self.record)
    }

    func gameNight(id: UUID) throws -> GameNightRecord? {
        try fetchNight(id: id).flatMap(Self.record)
    }

    @discardableResult
    func saveGameNight(_ record: GameNightRecord, createdBy username: String?) throws -> GameNightSaveResult {
        let existing = try fetchNight(id: record.id)
        let old = existing.flatMap(Self.record)
        if let problem = record.validationError(isNew: existing == nil) {
            throw GameNightStoreError.invalid(problem)
        }
        guard let venue = try fetchVenue(id: record.venue.id) else {
            throw GameNightStoreError.invalid("Pick a venue for this game night.")
        }

        let night = existing ?? GameNight(context: context)
        night.id = record.id
        night.venue = venue
        night.startDate = record.startDate
        night.endDate = record.endDate
        night.courtsInUse = record.courtsInUse
        night.capacity = record.capacity
        night.status = record.status.rawValue
        night.notes = record.notes
        night.updatedAt = Date()
        if existing == nil {
            night.season = SeasonManager.activeSeason(in: context)
            if let username { night.createdBy = try fetchPlayer(username: username) }
        }
        // A capacity increase can open spots for the waitlist; the status follows the count.
        let promoted = promoteFromWaitlist(night, now: Date())
        try save()
        return GameNightSaveResult(changes: old.map { record.materialChanges(from: $0) } ?? [], promoted: promoted)
    }

    @discardableResult
    func cancelGameNight(id: UUID) throws -> GameNightSaveResult {
        guard let night = try fetchNight(id: id), let old = Self.record(night) else { throw GameNightStoreError.notFound }
        night.status = GameNightStatus.cancelled.rawValue
        night.updatedAt = Date()
        try save()
        var updated = old
        updated.status = .cancelled
        return GameNightSaveResult(changes: updated.materialChanges(from: old))
    }

    // MARK: RSVPs

    func roster(nightID: UUID) throws -> Roster {
        guard let night = try fetchNight(id: nightID) else { throw GameNightStoreError.notFound }
        let all = activeRSVPs(of: night)
        return Roster(
            confirmed: all.filter { $0.status == RSVPStatus.confirmed.rawValue }
                .sorted(by: Self.rosterOrder).compactMap(Self.record),
            waitlist: all.filter { $0.status == RSVPStatus.waitlisted.rawValue }
                .sorted(by: Self.rosterOrder).compactMap(Self.record),
            noShows: all.filter { $0.status == RSVPStatus.noShow.rawValue }
                .sorted(by: Self.rosterOrder).compactMap(Self.record)
        )
    }

    func myRSVP(nightID: UUID, username: String) throws -> MyRSVPState {
        let roster = try roster(nightID: nightID)
        if let mine = roster.confirmed.first(where: { $0.username.caseInsensitiveCompare(username) == .orderedSame }) {
            return .confirmed(checkedIn: mine.isCheckedIn)
        }
        if let index = roster.waitlist.firstIndex(where: { $0.username.caseInsensitiveCompare(username) == .orderedSame }) {
            return .waitlisted(position: index + 1)
        }
        if roster.noShows.contains(where: { $0.username.caseInsensitiveCompare(username) == .orderedSame }) {
            return .noShow
        }
        return .none
    }

    @discardableResult
    func rsvp(nightID: UUID, username: String, now: Date) throws -> RSVPStatus {
        guard let night = try fetchNight(id: nightID), let record = Self.record(night) else { throw GameNightStoreError.notFound }
        guard let player = try fetchPlayer(username: username) else { throw GameNightStoreError.unknownPlayer(username) }
        let active = activeRSVPs(of: night)
        let alreadyActive = active.contains { $0.player == player }
        if let refusal = RSVPPolicy.refusalToRSVP(night: record, membership: player.membership,
                                                  alreadyActive: alreadyActive, now: now) {
            throw GameNightStoreError.refused(refusal)
        }
        let confirmed = active.filter { $0.status == RSVPStatus.confirmed.rawValue }.count
        let status = RSVPPolicy.statusForNewRSVP(confirmedCount: confirmed, capacity: Int(night.capacity))

        // Reuse a cancelled RSVP row if they cancelled earlier; they go to the back of the line.
        let rsvp = allRSVPs(of: night).first { $0.player == player } ?? RSVP(context: context)
        rsvp.id = rsvp.id ?? UUID()
        rsvp.player = player
        rsvp.gameNight = night
        rsvp.status = status.rawValue
        rsvp.createdAt = now
        rsvp.updatedAt = now
        rsvp.checkedInAt = nil
        rsvp.isWalkIn = false
        updateStatus(night)
        try save()
        return status
    }

    @discardableResult
    func cancelRSVP(nightID: UUID, username: String, now: Date) throws -> [String] {
        guard let night = try fetchNight(id: nightID) else { throw GameNightStoreError.notFound }
        if night.status == GameNightStatus.completed.rawValue { throw GameNightStoreError.refused(.nightClosed) }
        guard let player = try fetchPlayer(username: username),
              let rsvp = activeRSVPs(of: night).first(where: { $0.player == player }) else {
            return []
        }
        rsvp.status = RSVPStatus.cancelled.rawValue
        rsvp.checkedInAt = nil
        rsvp.updatedAt = now
        let promoted = promoteFromWaitlist(night, now: now)
        try save()
        return promoted
    }

    func setCheckedIn(_ checkedIn: Bool, nightID: UUID, username: String, now: Date) throws {
        guard let night = try fetchNight(id: nightID) else { throw GameNightStoreError.notFound }
        if night.status == GameNightStatus.completed.rawValue { throw GameNightStoreError.refused(.nightClosed) }
        guard let rsvp = activeRSVPs(of: night).first(where: {
            $0.status == RSVPStatus.confirmed.rawValue
                && ($0.player?.username ?? "").caseInsensitiveCompare(username) == .orderedSame
        }) else { throw GameNightStoreError.notOnList(username) }
        rsvp.checkedInAt = checkedIn ? now : nil
        rsvp.updatedAt = now
        try save()
    }

    func addWalkIn(nightID: UUID, username: String, now: Date) throws {
        guard let night = try fetchNight(id: nightID), let record = Self.record(night) else { throw GameNightStoreError.notFound }
        guard let player = try fetchPlayer(username: username) else { throw GameNightStoreError.unknownPlayer(username) }
        if record.status == .cancelled { throw GameNightStoreError.refused(.cancelledNight) }
        if record.status == .completed { throw GameNightStoreError.refused(.nightClosed) }
        if LeagueSettings.rsvpRequiresCompetitive && !AppConstants.isRanked(player.membership) {
            throw GameNightStoreError.refused(.notCompetitive)
        }
        let active = activeRSVPs(of: night)
        if let existing = active.first(where: { $0.player == player }) {
            if existing.status == RSVPStatus.confirmed.rawValue { throw GameNightStoreError.refused(.alreadyIn) }
        }
        let confirmed = active.filter { $0.status == RSVPStatus.confirmed.rawValue }.count
        guard confirmed < Int(night.capacity) else { throw GameNightStoreError.refused(.nightFull) }

        // A waitlisted player who shows up takes the open spot directly (not a walk-in: they
        // RSVP'd). Anyone else is a walk-in, including someone who RSVP'd and then cancelled.
        let wasWaitlisted = active.contains { $0.player == player && $0.status == RSVPStatus.waitlisted.rawValue }
        let rsvp = allRSVPs(of: night).first { $0.player == player } ?? RSVP(context: context)
        rsvp.id = rsvp.id ?? UUID()
        rsvp.player = player
        rsvp.gameNight = night
        rsvp.status = RSVPStatus.confirmed.rawValue
        rsvp.isWalkIn = !wasWaitlisted
        rsvp.createdAt = wasWaitlisted ? (rsvp.createdAt ?? now) : now
        rsvp.checkedInAt = now
        rsvp.updatedAt = now
        updateStatus(night)
        try save()
    }

    func walkInCandidates(nightID: UUID) throws -> [MemberSummary] {
        guard let night = try fetchNight(id: nightID) else { throw GameNightStoreError.notFound }
        let confirmedPlayers = Set(activeRSVPs(of: night)
            .filter { $0.status == RSVPStatus.confirmed.rawValue }
            .compactMap { $0.player?.objectID })
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        if LeagueSettings.rsvpRequiresCompetitive {
            request.predicate = NSPredicate(format: "membership == %@", AppConstants.competitiveMembership)
        }
        request.sortDescriptors = [NSSortDescriptor(key: "username", ascending: true)]
        return try context.fetch(request)
            .filter { !confirmedPlayers.contains($0.objectID) }
            .map { MemberSummary(username: $0.username ?? "", rankPoints: $0.rankPoints) }
    }

    @discardableResult
    func closeGameNight(id: UUID, now: Date) throws -> AttendanceSummary {
        guard let night = try fetchNight(id: id), let record = Self.record(night) else { throw GameNightStoreError.notFound }
        if let refusal = RSVPPolicy.refusalToClose(night: record, now: now) { throw GameNightStoreError.refused(refusal) }
        for rsvp in activeRSVPs(of: night) where rsvp.status == RSVPStatus.confirmed.rawValue && rsvp.checkedInAt == nil {
            rsvp.status = RSVPStatus.noShow.rawValue
            rsvp.updatedAt = now
        }
        night.status = GameNightStatus.completed.rawValue
        night.updatedAt = now
        try save()
        return Self.attendance(of: night)
    }

    func reopenGameNight(id: UUID) throws {
        guard let night = try fetchNight(id: id) else { throw GameNightStoreError.notFound }
        guard night.status == GameNightStatus.completed.rawValue else { return }
        for rsvp in allRSVPs(of: night) where rsvp.status == RSVPStatus.noShow.rawValue {
            rsvp.status = RSVPStatus.confirmed.rawValue
            rsvp.updatedAt = Date()
        }
        night.status = GameNightStatus.scheduled.rawValue
        updateStatus(night)
        night.updatedAt = Date()
        try save()
    }

    static func attendance(of night: GameNight) -> AttendanceSummary {
        let rsvps = (night.rsvps as? Set<RSVP>) ?? []
        let attended = rsvps.filter { $0.status == RSVPStatus.confirmed.rawValue && $0.checkedInAt != nil }
        return AttendanceSummary(
            attended: attended.count,
            walkIns: attended.filter(\.isWalkIn).count,
            noShows: rsvps.filter { $0.status == RSVPStatus.noShow.rawValue }.count,
            stillWaitlisted: rsvps.filter { $0.status == RSVPStatus.waitlisted.rawValue }.count,
            gamesRecorded: (night.matches as? Set<Match>)?.count ?? 0,
            capacity: night.capacity
        )
    }

    func gamesPlayed(nightID: UUID) throws -> [String: Int] {
        guard let night = try fetchNight(id: nightID) else { throw GameNightStoreError.notFound }
        var counts: [String: Int] = [:]
        for match in (night.matches as? Set<Match>) ?? [] {
            for game in (match.games as? Set<Game>) ?? [] {
                if let name = game.player?.username { counts[name, default: 0] += 1 }
            }
        }
        return counts
    }

    // MARK: RSVP helpers

    private func allRSVPs(of night: GameNight) -> [RSVP] {
        Array((night.rsvps as? Set<RSVP>) ?? [])
    }

    private func activeRSVPs(of night: GameNight) -> [RSVP] {
        allRSVPs(of: night).filter { $0.status != RSVPStatus.cancelled.rawValue }
    }

    /// First come, first served; walk-ins after everyone who RSVP'd.
    private static func rosterOrder(_ lhs: RSVP, _ rhs: RSVP) -> Bool {
        if lhs.isWalkIn != rhs.isWalkIn { return !lhs.isWalkIn }
        return (lhs.createdAt ?? .distantPast) < (rhs.createdAt ?? .distantPast)
    }

    /// Fills open spots from the front of the waitlist and updates the night's status. Doesn't
    /// save. Returns the usernames moved up.
    private func promoteFromWaitlist(_ night: GameNight, now: Date) -> [String] {
        guard night.status != GameNightStatus.cancelled.rawValue,
              night.status != GameNightStatus.completed.rawValue else { return [] }
        let active = activeRSVPs(of: night)
        let confirmed = active.filter { $0.status == RSVPStatus.confirmed.rawValue }.count
        let waitlist = active.filter { $0.status == RSVPStatus.waitlisted.rawValue }.sorted(by: Self.rosterOrder)
        let count = RSVPPolicy.promotions(confirmedCount: confirmed, capacity: Int(night.capacity),
                                          waitlistCount: waitlist.count)
        let moving = waitlist.prefix(count)
        for rsvp in moving {
            rsvp.status = RSVPStatus.confirmed.rawValue
            rsvp.updatedAt = now
        }
        updateStatus(night)
        return moving.compactMap { $0.player?.username }
    }

    private func updateStatus(_ night: GameNight) {
        guard let record = Self.record(night) else { return }
        let confirmed = activeRSVPs(of: night).filter { $0.status == RSVPStatus.confirmed.rawValue }.count
        night.status = RSVPPolicy.status(for: record, confirmedCount: confirmed).rawValue
    }

    static func record(_ rsvp: RSVP) -> RSVPRecord? {
        guard let id = rsvp.id, let player = rsvp.player, let username = player.username,
              let status = RSVPStatus(rawValue: rsvp.status ?? "") else { return nil }
        return RSVPRecord(id: id, username: username, membership: player.membership,
                          rankPoints: player.rankPoints, placementGamesRemaining: player.placementGamesRemaining,
                          status: status, createdAt: rsvp.createdAt ?? .distantPast,
                          checkedInAt: rsvp.checkedInAt, isWalkIn: rsvp.isWalkIn,
                          pastNoShows: ((player.rsvps as? Set<RSVP>) ?? [])
                              .filter { $0 != rsvp && $0.status == RSVPStatus.noShow.rawValue }.count)
    }

    // MARK: Helpers

    private func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func fetchVenue(id: UUID) throws -> Venue? {
        let request: NSFetchRequest<Venue> = Venue.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fetchNight(id: UUID) throws -> GameNight? {
        let request: NSFetchRequest<GameNight> = GameNight.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fetchPlayer(username: String) throws -> Player? {
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        request.predicate = NSPredicate(format: "username ==[c] %@", username)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    static func record(_ venue: Venue) -> VenueRecord {
        VenueRecord(
            id: venue.id ?? UUID(),
            name: venue.name ?? "",
            address: venue.address ?? "",
            latitude: venue.latitude?.doubleValue,
            longitude: venue.longitude?.doubleValue,
            mapURL: venue.mapURL,
            courtCount: venue.courtCount,
            notes: venue.notes ?? "",
            isActive: venue.isActive
        )
    }

    static func record(_ night: GameNight) -> GameNightRecord? {
        guard let id = night.id, let venue = night.venue, let start = night.startDate, let end = night.endDate else {
            return nil
        }
        return GameNightRecord(
            id: id,
            venue: record(venue),
            startDate: start,
            endDate: end,
            courtsInUse: night.courtsInUse,
            capacity: night.capacity,
            status: GameNightStatus(rawValue: night.status ?? "") ?? .scheduled,
            notes: night.notes ?? "",
            seasonName: night.season?.name,
            createdByUsername: night.createdBy?.username,
            confirmedCount: ((night.rsvps as? Set<RSVP>) ?? []).filter { $0.status == RSVPStatus.confirmed.rawValue }.count,
            waitlistCount: ((night.rsvps as? Set<RSVP>) ?? []).filter { $0.status == RSVPStatus.waitlisted.rawValue }.count,
            attendance: night.status == GameNightStatus.completed.rawValue ? attendance(of: night) : nil
        )
    }
}

// MARK: - Environment

private struct GameNightStoreKey: EnvironmentKey {
    static let defaultValue: GameNightStore = CoreDataGameNightStore(
        context: PersistenceController.shared.container.viewContext
    )
}

extension EnvironmentValues {
    /// The game night store screens use. Set at the app root; tests and previews can swap it.
    var gameNightStore: GameNightStore {
        get { self[GameNightStoreKey.self] }
        set { self[GameNightStoreKey.self] = newValue }
    }
}
