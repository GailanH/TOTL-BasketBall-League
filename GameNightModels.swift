import Foundation

// Plain value types for venues and game nights. Screens and the store protocol use these, never
// Core Data objects, so a hosted backend can replace the Core Data store later (D5) without
// touching the views. IDs are UUIDs; dates are absolute (UTC) and shown in league time.

struct VenueRecord: Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var address: String = ""
    var latitude: Double? = nil
    var longitude: Double? = nil
    /// Optional link to a specific map pin; otherwise Maps searches the address.
    var mapURL: String? = nil
    var courtCount: Int16 = 1
    /// Parking, entrance, "use the side door", and so on.
    var notes: String = ""
    var isActive: Bool = true

    /// A short address for notifications and lists: the street line only.
    var shortAddress: String {
        address.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? address
    }

    /// The URL that opens this venue in Apple Maps.
    var mapsURL: URL? {
        if let mapURL, let url = URL(string: mapURL), url.scheme != nil { return url }
        var components = URLComponents(string: "https://maps.apple.com/")!
        var items = [URLQueryItem(name: "q", value: name)]
        if let latitude, let longitude {
            items.append(URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"))
        }
        if !address.isEmpty {
            items.append(URLQueryItem(name: "address", value: address))
        }
        components.queryItems = items
        return components.url
    }

    /// A human-readable problem, or nil if the venue can be saved.
    var validationError: String? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty { return "Give the venue a name." }
        if address.trimmingCharacters(in: .whitespaces).isEmpty { return "Add the venue's address so players can find it." }
        if courtCount < 1 { return "A venue needs at least 1 court." }
        if let mapURL, !mapURL.isEmpty, URL(string: mapURL)?.scheme == nil {
            return "The map link should start with https://."
        }
        return nil
    }
}

enum GameNightStatus: String, CaseIterable {
    case scheduled
    case full
    case cancelled
    case completed

    var label: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .full: return "Full"
        case .cancelled: return "Cancelled"
        case .completed: return "Completed"
        }
    }
}

struct GameNightRecord: Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var venue: VenueRecord
    var startDate: Date
    var endDate: Date
    var courtsInUse: Int16 = LeagueSettings.defaultCourtsInUse
    var capacity: Int16 = LeagueSettings.defaultCapacity
    var status: GameNightStatus = .scheduled
    var notes: String = ""
    var seasonName: String? = nil
    var createdByUsername: String? = nil
    /// Read-only counts filled in by the store (not saved from here).
    var confirmedCount: Int = 0
    var waitlistCount: Int = 0

    var spotsLeft: Int { RSVPPolicy.spotsLeft(capacity: capacity, confirmedCount: confirmedCount) }
    var availabilityText: String {
        RSVPPolicy.availabilityText(capacity: capacity, confirmedCount: confirmedCount, waitlistCount: waitlistCount)
    }

    /// The status players should see right now: a scheduled or full night whose end has passed
    /// reads as completed even before staff mark it.
    func displayStatus(now: Date = Date()) -> GameNightStatus {
        if (status == .scheduled || status == .full) && endDate < now { return .completed }
        return status
    }

    var isCancelled: Bool { status == .cancelled }

    /// A new night with the league defaults: the given day at 7 PM league time, two hours long.
    static func newNight(on day: Date, at venue: VenueRecord) -> GameNightRecord {
        let calendar = LeagueSettings.calendar
        let start = calendar.date(bySettingHour: LeagueSettings.defaultStartHour, minute: 0, second: 0, of: day) ?? day
        return GameNightRecord(venue: venue, startDate: start,
                               endDate: start.addingTimeInterval(LeagueSettings.defaultDuration),
                               courtsInUse: min(LeagueSettings.defaultCourtsInUse, max(1, venue.courtCount)))
    }

    /// A human-readable problem, or nil if the night can be saved.
    func validationError(now: Date = Date(), isNew: Bool) -> String? {
        if !venue.isActive { return "\(venue.name) is inactive. Pick an active venue." }
        if endDate <= startDate { return "The end time has to be after the start time." }
        if endDate.timeIntervalSince(startDate) > LeagueSettings.maxDuration { return "A game night can't be longer than 8 hours." }
        if isNew && startDate < now { return "New game nights have to start in the future." }
        if !LeagueSettings.capacityRange.contains(capacity) {
            return "Capacity has to be between \(LeagueSettings.capacityRange.lowerBound) and \(LeagueSettings.capacityRange.upperBound) players."
        }
        if courtsInUse < 1 { return "Use at least 1 court." }
        if courtsInUse > venue.courtCount { return "\(venue.name) only has \(venue.courtCount) court\(venue.courtCount == 1 ? "" : "s")." }
        return nil
    }

    /// What changed between two versions of a night that players need to hear about
    /// (used by the notifications in build step 3).
    struct MaterialChanges: OptionSet, Equatable {
        let rawValue: Int
        static let time = MaterialChanges(rawValue: 1 << 0)
        static let venue = MaterialChanges(rawValue: 1 << 1)
        static let cancelled = MaterialChanges(rawValue: 1 << 2)
    }

    func materialChanges(from old: GameNightRecord) -> MaterialChanges {
        var changes: MaterialChanges = []
        if startDate != old.startDate || endDate != old.endDate { changes.insert(.time) }
        if venue.id != old.venue.id { changes.insert(.venue) }
        if status == .cancelled && old.status != .cancelled { changes.insert(.cancelled) }
        return changes
    }
}

/// Formatting for game nights, always in league time (America/Chicago) regardless of the
/// phone's own time zone.
enum GameNightFormat {

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = LeagueSettings.timeZone
        formatter.dateFormat = format
        return formatter
    }

    /// "Tue, Oct 28"
    static func day(_ date: Date) -> String { formatter("EEE, MMM d").string(from: date) }

    /// "7:00 PM"
    static func time(_ date: Date) -> String { formatter("h:mm a").string(from: date) }

    /// "Tue, Oct 28 · 7:00 – 9:00 PM" (or "7:00 PM – 1:00 AM" across midnight)
    static func dayAndTimes(_ night: GameNightRecord) -> String {
        let start = time(night.startDate), end = time(night.endDate)
        let sameHalf = start.suffix(2) == end.suffix(2)
        let startShown = sameHalf ? String(start.dropLast(3)) : start
        return "\(day(night.startDate)) · \(startShown) – \(end)"
    }

    /// The text players share to social media or group chats: when and where.
    static func shareText(_ night: GameNightRecord) -> String {
        var lines = ["TOTL Game Night", dayAndTimes(night), "\(night.venue.name), \(night.venue.address)"]
        if night.isCancelled { lines.insert("CANCELLED", at: 1) }
        if let url = night.venue.mapsURL { lines.append(url.absoluteString) }
        return lines.joined(separator: "\n")
    }
}
