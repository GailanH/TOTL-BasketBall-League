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

    /// Creates or updates (by id). Returns what changed that players need to hear about
    /// (empty for a new night), for the change notifications in build step 3.
    @discardableResult
    func saveGameNight(_ night: GameNightRecord, createdBy username: String?) throws -> GameNightRecord.MaterialChanges
    @discardableResult
    func cancelGameNight(id: UUID) throws -> GameNightRecord.MaterialChanges
}

enum GameNightStoreError: LocalizedError {
    case invalid(String)
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        case .notFound: return "That game night no longer exists."
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
    func saveGameNight(_ record: GameNightRecord, createdBy username: String?) throws -> GameNightRecord.MaterialChanges {
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
        try save()
        return old.map { record.materialChanges(from: $0) } ?? []
    }

    @discardableResult
    func cancelGameNight(id: UUID) throws -> GameNightRecord.MaterialChanges {
        guard let night = try fetchNight(id: id), let old = Self.record(night) else { throw GameNightStoreError.notFound }
        night.status = GameNightStatus.cancelled.rawValue
        night.updatedAt = Date()
        try save()
        var updated = old
        updated.status = .cancelled
        return updated.materialChanges(from: old)
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
            createdByUsername: night.createdBy?.username
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
